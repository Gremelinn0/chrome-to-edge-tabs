<#
.SYNOPSIS
  Extracts Chrome tab groups (name + current tab URLs) from the active session (SNSS).
  Outputs a JSON file ready for use with 2-create-edge-groups.ps1.

.NOTES
  - SNSS-ONLY by design. The old LevelDB Sync regex fallback was REMOVED (2026-07-15):
    it injected raw binary bytes into URLs (e.g. "https://app.n%rd.com/...") and produced
    garbage. SNSS (the active session file) holds clean current URLs per tab.
  - Group NAME comes from SNSS command type 27 (group metadata). Group<->tab from type 25.
    Current URL per tab from type 6 (last navigation wins).
  - LIMITATION: reads a snapshot on disk, not the live browser. If Florent is actively
    reshuffling the group RIGHT NOW, re-run after Chrome rewrites the session (a few seconds),
    and ALWAYS confirm the URL list with him before creating in Edge (skill RULE N.1).

.OUTPUTS
  %TEMP%\chrome_groups_final.json   (array of { name, edgeColor, tabs:[{url}] })
#>

$outputPath = "$env:TEMP\chrome_groups_final.json"

$sessDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Sessions"
$candidates = Get-ChildItem $sessDir -Filter "Session_*" |
    Where-Object { $_.Length -gt 1000 } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 5

if (-not $candidates) { Write-Error "No Chrome session file found in $sessDir"; exit 1 }

# The single most recent Session_* file can be actively being appended to by Chrome right now
# (exclusively locked while it grows) - fall back to the next-most-recent candidate instead of
# hard-failing. A few minutes of staleness is fine: RULE N.1 confirms the list with Florent anyway.
$sessFile = $null; $bytes = $null
foreach ($cand in $candidates) {
    try {
        $fs = [System.IO.File]::Open($cand.FullName, 'Open', 'Read', ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        $b = New-Object byte[] $fs.Length
        $fs.Read($b, 0, $b.Length) | Out-Null
        $fs.Close()
        $sessFile = $cand; $bytes = $b
        break
    } catch {
        Write-Host "Skipping $($cand.Name): locked by Chrome (actively writing) - trying next"
    }
}
if (-not $sessFile) { Write-Error "All recent session files are locked by Chrome - close a tab and retry"; exit 1 }
Write-Host "Reading session: $($sessFile.Name) ($($sessFile.Length) bytes, $($sessFile.LastWriteTime))"

# Parse SNSS commands: 2-byte size (includes type byte) + 1-byte type + data
$pos = 8; $cmds = @()
while ($pos + 3 -le $bytes.Length) {
    $size = [BitConverter]::ToUInt16($bytes, $pos)
    $type = $bytes[$pos + 2]
    if ($size -eq 0 -or ($pos + 2 + $size) -gt $bytes.Length) { $pos++; continue }
    $dataLen = $size - 1
    $d = if ($dataLen -gt 0) { $bytes[($pos + 3)..($pos + 1 + $size)] } else { @() }
    $cmds += [PSCustomObject]@{ Pos = $pos; Type = $type; Data = $d }
    $pos += 2 + $size
}
Write-Host "Total SNSS commands: $($cmds.Count)"

# Type 27 -> group metadata: UUID bytes 4-19, name length at 20 (x2 UTF-16), name at 24. Last wins.
$groupName = @{}
foreach ($c in ($cmds | Where-Object { $_.Type -eq 27 })) {
    $d = $c.Data
    if ($d.Length -lt 24) { continue }
    $uuid = ($d[4..19] | ForEach-Object { $_.ToString("X2") }) -join ""
    $nameLen = [BitConverter]::ToUInt32($d, 20) * 2
    if ($nameLen -gt 0 -and 24 + $nameLen -le $d.Length) {
        $groupName[$uuid] = [Text.Encoding]::Unicode.GetString($d, 24, $nameLen)
    }
}

# Type 25 -> tab id bytes 0-3, group UUID bytes 8-23. Last wins.
$tabGroup = @{}
foreach ($c in ($cmds | Where-Object { $_.Type -eq 25 })) {
    $d = $c.Data
    if ($d.Length -lt 24) { continue }
    $tab = ($d[0..3] | ForEach-Object { $_.ToString("X2") }) -join ""
    $tabGroup[$tab] = ($d[8..23] | ForEach-Object { $_.ToString("X2") }) -join ""
}

# Type 7 -> SetSelectedNavigationIndex: tab id bytes 0-3, selected nav index bytes 4-7. Last wins.
# CRITICAL (2026-07-15): a tab with back/forward history has several type-6 nav entries; the
# CURRENT url is the one at the SELECTED index, NOT the last-written entry. Ignoring this put a
# "went-there-then-came-back" URL in Edge (antigravity instead of pastry-chef-rachel).
$tabSel = @{}
foreach ($c in ($cmds | Where-Object { $_.Type -eq 7 })) {
    $d = $c.Data
    if ($d.Length -lt 8) { continue }
    $tab = ($d[0..3] | ForEach-Object { $_.ToString("X2") }) -join ""
    $tabSel[$tab] = [BitConverter]::ToInt32($d, 4)
}

# Type 6 -> UpdateTabNavigation: tab id bytes 4-7, nav index bytes 8-11, URL len bytes 12-15, URL at 16.
# Collect per-tab: url at each nav index (last write per index wins) + the highest index seen (fallback).
$navUrls    = @{}   # tab -> @{ index -> url }
$navMaxIdx  = @{}   # tab -> highest index with a valid url
foreach ($c in ($cmds | Where-Object { $_.Type -eq 6 } | Sort-Object Pos)) {
    $d = $c.Data
    if ($d.Length -lt 16) { continue }
    $tab = ($d[4..7] | ForEach-Object { $_.ToString("X2") }) -join ""
    $navIdx = [BitConverter]::ToInt32($d, 8)
    $urlLen = [BitConverter]::ToUInt32($d, 12)
    if ($urlLen -gt 0 -and $urlLen -lt 8192 -and 16 + $urlLen -le $d.Length) {
        $url = [Text.Encoding]::UTF8.GetString($d, 16, $urlLen)
        if ($url -match '^https?://' -or $url -match '^file://') {
            if (-not $navUrls.ContainsKey($tab)) { $navUrls[$tab] = @{} }
            $navUrls[$tab][$navIdx] = $url
            if (-not $navMaxIdx.ContainsKey($tab) -or $navIdx -gt $navMaxIdx[$tab]) { $navMaxIdx[$tab] = $navIdx }
        }
    }
}

# Resolve each tab's CURRENT url: url at selected index; fall back to highest index if selected missing.
$tabUrl = @{}
foreach ($tab in $navUrls.Keys) {
    $entries = $navUrls[$tab]
    $chosen = $null
    if ($tabSel.ContainsKey($tab) -and $entries.ContainsKey($tabSel[$tab])) { $chosen = $entries[$tabSel[$tab]] }
    elseif ($entries.ContainsKey($navMaxIdx[$tab])) { $chosen = $entries[$navMaxIdx[$tab]] }
    if ($chosen) { $tabUrl[$tab] = $chosen }
}

# Build groups: UUID -> ordered current tab URLs (tabs without a current http/file URL = closed/blank -> skipped)
$groupUrls = @{}
foreach ($tab in $tabGroup.Keys) {
    $uuid = $tabGroup[$tab]
    if (-not $tabUrl.ContainsKey($tab)) { continue }
    if (-not $groupUrls.ContainsKey($uuid)) { $groupUrls[$uuid] = @() }
    $groupUrls[$uuid] += $tabUrl[$tab]
}

# Output (name from metadata; unnamed groups keyed by short uuid)
$output = @()
foreach ($uuid in $groupUrls.Keys) {
    $name = if ($groupName.ContainsKey($uuid)) { $groupName[$uuid] } else { "group-$($uuid.Substring(0,8))" }
    $output += @{
        name      = $name
        edgeColor = "cyan"
        tabs      = @($groupUrls[$uuid] | Select-Object -Unique | ForEach-Object { @{ url = $_ } })
    }
}

# ConvertTo-Json: wrap in @() so a single group still serializes as a JSON array (script 2 expects an array)
ConvertTo-Json -InputObject @($output) -Depth 10 | Out-File $outputPath -Encoding utf8

Write-Host "`nGroups extracted: $($output.Count)"
$output | ForEach-Object { Write-Host "  - $($_.name): $($_.tabs.Count) tabs" }
Write-Host "JSON saved to: $outputPath"
Write-Host "`nRULE N.1: show this list to the user and confirm BEFORE creating in Edge."
