<#
.SYNOPSIS
  Extracts Chrome tab groups from the active session (SNSS) and/or saved groups (LevelDB).
  Outputs a JSON file ready for use with 2-create-edge-groups.ps1.

.OUTPUTS
  %TEMP%\chrome_groups_final.json
#>

$outputPath = "$env:TEMP\chrome_groups_final.json"

# ── Phase A: Active session via SNSS ──────────────────────────────────────────
# Chrome 120+: "Current Session" = most recent Session_* file (not Tabs_* which is exclusively locked)

$sessDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Sessions"
$sessFile = Get-ChildItem $sessDir -Filter "Session_*" |
    Where-Object { $_.Length -gt 1000 } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $sessFile) {
    Write-Error "No Chrome session file found in $sessDir"
    exit 1
}

Write-Host "Reading session: $($sessFile.FullName) ($($sessFile.Length) bytes)"

$fs = [System.IO.File]::Open($sessFile.FullName, 'Open', 'Read', 'ReadWrite')
$bytes = New-Object byte[] $fs.Length
$fs.Read($bytes, 0, $bytes.Length) | Out-Null
$fs.Close()

# Parse SNSS commands: 2-byte size (includes type byte) + 1-byte type + data
$pos = 8
$allCmds = @()
while ($pos + 3 -le $bytes.Length) {
    $size = [BitConverter]::ToUInt16($bytes, $pos)
    $type = $bytes[$pos + 2]
    if ($size -eq 0 -or ($pos + 2 + $size) -gt $bytes.Length) { $pos++; continue }
    $dataLen = $size - 1
    $dataBytes = if ($dataLen -gt 0) { $bytes[($pos + 3)..($pos + 1 + $size)] } else { @() }
    $allCmds += [PSCustomObject]@{ Pos = $pos; Type = $type; Size = $size; DataLen = $dataLen; Data = $dataBytes }
    $pos += 2 + $size
}
Write-Host "Total SNSS commands: $($allCmds.Count)"

# Type 27 → group metadata (UUID bytes 4-19, name length at byte 20, name UTF-16 LE at byte 24)
$groupMap = @{}
$allCmds | Where-Object { $_.Type -eq 27 } | ForEach-Object {
    $d = $_.Data
    if ($d.Length -lt 24) { return }
    $key = ($d[4..19] | ForEach-Object { $_.ToString("X2") }) -join ""
    $nameLen = [BitConverter]::ToUInt32($d, 20) * 2
    if ($nameLen -gt 0 -and 24 + $nameLen -le $d.Length) {
        $name = [Text.Encoding]::Unicode.GetString($d, 24, $nameLen)
        if (-not $groupMap.ContainsKey($key)) { $groupMap[$key] = $name }
    }
}

# Type 25 → tab token (bytes 0-3) → group UUID (bytes 8-23)
$tabToGroup = @{}
$allCmds | Where-Object { $_.Type -eq 25 -and $_.DataLen -ge 24 } | ForEach-Object {
    $d = $_.Data
    $tabToken = ($d[0..3] | ForEach-Object { $_.ToString("X2") }) -join ""
    $groupKey = ($d[8..23] | ForEach-Object { $_.ToString("X2") }) -join ""
    if ($groupMap.ContainsKey($groupKey)) { $tabToGroup[$tabToken] = $groupMap[$groupKey] }
}

# Type 6 → current URL (token bytes 4-7, URL length bytes 12-15, URL UTF-8 at byte 16)
$tabToUrl = @{}
$allCmds | Where-Object { $_.Type -eq 6 -and $_.DataLen -ge 20 } | ForEach-Object {
    $d = $_.Data
    if ($d.Length -lt 16) { return }
    $tabToken = ($d[4..7] | ForEach-Object { $_.ToString("X2") }) -join ""
    $urlLen = [BitConverter]::ToUInt32($d, 12)
    if ($urlLen -gt 0 -and $urlLen -lt 4096 -and 16 + $urlLen -le $d.Length) {
        $url = [Text.Encoding]::UTF8.GetString($d, 16, $urlLen)
        if ($url -match '^https?://') { $tabToUrl[$tabToken] = $url }
    }
}

# Build group → URLs map
$groupUrls = @{}
$tabToGroup.GetEnumerator() | ForEach-Object {
    $url = $tabToUrl[$_.Key]
    if ($url -and $url -notmatch '^chrome://') {
        if (-not $groupUrls.ContainsKey($_.Value)) { $groupUrls[$_.Value] = @() }
        $groupUrls[$_.Value] += $url
    }
}

# ── Phase B: Saved groups via LevelDB Sync ────────────────────────────────────
# Fallback: reads saved_tab_group-dt-<uuid> entries from Chrome Sync LevelDB

$ldbPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Sync Data\LevelDB"
if (Test-Path $ldbPath) {
    Write-Host "Also scanning LevelDB for saved groups..."
    $allText = ""
    foreach ($f in Get-ChildItem $ldbPath -Filter "*.ldb") {
        try {
            $fss = [System.IO.File]::Open($f.FullName, 'Open', 'Read', 'ReadWrite')
            $b = New-Object byte[] $fss.Length
            $fss.Read($b, 0, $b.Length) | Out-Null
            $fss.Close()
            $allText += [Text.Encoding]::GetEncoding('iso-8859-1').GetString($b)
        } catch { }
    }
    $pat = '\$([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})[^\$]{0,50}(https?://[^\x00-\x1F\x7F"<>\s\\]{8,})"([^"\x00-\x1F]{3,80})'
    [regex]::Matches($allText, $pat) | ForEach-Object {
        $groupId = $_.Groups[1].Value
        $url = $_.Groups[2].Value
        $title = $_.Groups[3].Value
        # Only add URLs not already captured from active session
        $alreadyCaptured = $groupUrls.Values | ForEach-Object { $_ } | Where-Object { $_ -eq $url }
        if (-not $alreadyCaptured) {
            $groupKey = "saved-$groupId"
            if (-not $groupUrls.ContainsKey($groupKey)) { $groupUrls[$groupKey] = @() }
            $groupUrls[$groupKey] += $url
        }
    }
}

# ── Output ────────────────────────────────────────────────────────────────────

$output = @()
foreach ($entry in $groupUrls.GetEnumerator()) {
    $output += @{
        name     = $entry.Key
        edgeColor = "cyan"
        tabs     = @($entry.Value | Sort-Object -Unique | ForEach-Object { @{ url = $_ } })
    }
}

$output | ConvertTo-Json -Depth 10 | Out-File $outputPath -Encoding utf8
Write-Host "`nGroups extracted: $($output.Count)"
$output | ForEach-Object { Write-Host "  - $($_.name): $($_.tabs.Count) tabs" }
Write-Host "JSON saved to: $outputPath"
