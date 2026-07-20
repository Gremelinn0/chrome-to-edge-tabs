<#
.SYNOPSIS
  Creates Chrome tab groups in Microsoft Edge using CDP + a temporary MV3 extension.
  Reads groups from %TEMP%\chrome_groups_final.json (produced by 1-extract-chrome-groups.ps1).

.NOTES
  - Requires Microsoft Edge 88+ (Chromium-based)
  - Default: targets Florent's REAL Edge profile (stays signed in, groups land where he'll see
    them). This closes and relaunches Edge (--restore-last-session brings back existing
    windows/tabs). Hardened 2026-07-18 after the throwaway-profile default caused confusion
    ("ce n'est pas le bon Edge") - do NOT revert this default without a proven reason.
  - Pass -UseTempProfile for a disposable profile instead (no sign-in, but tabs need re-login;
    useful for testing this script without touching Florent's real browser).
  - Extension ID is deterministic based on the extension path: ojneegljainpehijglgglcpjjapabcjo
  - Validated on Edge 140 / Chrome 135+ (2026-04-23). Real-profile + restore-last-session
    verified live 2026-07-20 (3 windows / 42 tabs restored correctly).
#>

param(
    [string]$JsonPath = "$env:TEMP\chrome_groups_final.json",
    [int]$DebugPort = 9223,
    [switch]$UseTempProfile,
    [string]$UserDataDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data",
    [string]$ProfileDirectory = "Default"
)

if ($UseTempProfile) { $UserDataDir = "$env:TEMP\edge-fresh-profile"; $ProfileDirectory = "" }

$extPath       = "$env:TEMP\tab-group-ext"
$edgeBin       = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$extId         = "ojneegljainpehijglgglcpjjapabcjo"
$isTempProfile = [bool]$UseTempProfile

# -- 1. Read groups JSON --------------------------------------------------------

if (-not (Test-Path $JsonPath)) {
    Write-Error "Groups JSON not found: $JsonPath - run 1-extract-chrome-groups.ps1 first"
    exit 1
}
$groups = Get-Content $JsonPath -Raw | ConvertFrom-Json
Write-Host "Groups to create: $($groups.Count)"

# -- 2. Write extension files --------------------------------------------------

New-Item -ItemType Directory $extPath -Force | Out-Null

Set-Content "$extPath\manifest.json" -Encoding utf8 -Value @'
{
  "manifest_version": 3,
  "name": "Tab Group Creator",
  "version": "1.0",
  "description": "Creates tab groups programmatically via CDP",
  "permissions": ["tabs", "tabGroups"],
  "options_page": "options.html",
  "background": { "service_worker": "background.js" },
  "action": {}
}
'@

Set-Content "$extPath\options.html" -Encoding utf8 -Value @'
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Tab Group Creator</title></head>
<body><div id="status">Ready</div><script src="options.js"></script></body></html>
'@

Set-Content "$extPath\background.js" -Encoding utf8 -Value @'
console.log('[Tab Group Creator] Service worker ready');
'@

Set-Content "$extPath\options.js" -Encoding utf8 -Value @'
window.createTabGroup = async function(urls, groupName, color) {
  const tabIds = [];
  for (const url of urls) {
    const tab = await chrome.tabs.create({ url, active: false });
    tabIds.push(tab.id);
  }
  // Merge into an existing group with the same title (case-insensitive) instead of creating a
  // sibling duplicate (incident 2026-07-20: "banque" created next to a pre-existing "BANQUE").
  const existing = (await chrome.tabGroups.query({})).find(
    g => (g.title || "").toLowerCase() === (groupName || "").toLowerCase()
  );
  let groupId, merged = false;
  if (existing) {
    groupId = await chrome.tabs.group({ tabIds, groupId: existing.id });
    merged = true;
  } else {
    groupId = await chrome.tabs.group({ tabIds });
    if (chrome.tabGroups) {
      await chrome.tabGroups.update(groupId, { title: groupName, color: color || "cyan" });
    }
  }
  return { groupId, tabIds, groupName, merged };
};
window.createAllGroups = async function(groups) {
  const results = [];
  for (const g of groups) {
    try {
      const r = await window.createTabGroup(g.tabs.map(t => t.url), g.name, g.edgeColor || "cyan");
      results.push({ name: g.name, ok: true, groupId: r.groupId, count: r.tabIds.length, merged: r.merged });
    } catch (e) {
      results.push({ name: g.name, ok: false, error: e.message });
    }
  }
  return results;
};
'@

Write-Host "Extension written to: $extPath"

# -- 3. Kill any existing Edge debug instance on this port ---------------------

$existing = Get-Process msedge -ErrorAction SilentlyContinue | Where-Object {
    (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine -like "*$DebugPort*"
}
if ($existing) { $existing | Stop-Process -Force; Start-Sleep -Seconds 2 }

# -- 4. Launch Edge with extension ---------------------------------------------

if ($isTempProfile) { New-Item -ItemType Directory $UserDataDir -Force | Out-Null }
$edgeArgs = "--remote-debugging-port=$DebugPort --user-data-dir=`"$UserDataDir`" --load-extension=`"$extPath`" --no-first-run"
if ($ProfileDirectory) { $edgeArgs += " --profile-directory=`"$ProfileDirectory`"" }
if ($isTempProfile) { $edgeArgs += " --disable-sync about:blank" }
if (-not $isTempProfile) { $edgeArgs += " --restore-last-session" }
Start-Process $edgeBin -ArgumentList $edgeArgs
Write-Host "Edge launched, waiting 8s..."
Start-Sleep -Seconds 8

# Check CDP
try {
    $targets = Invoke-RestMethod "http://localhost:$DebugPort/json" -TimeoutSec 5
    Write-Host "CDP ready - $($targets.Count) targets"
} catch {
    Write-Error "CDP not responding on port ${DebugPort}: $_"
    exit 1
}

# -- 5. Navigate about:blank -> options page ------------------------------------

function Connect-Cdp {
    param([string]$WsUrl)
    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    $ws.ConnectAsync($WsUrl, [System.Threading.CancellationToken]::None).Wait(8000) | Out-Null
    return $ws
}

function Send-Cdp {
    param($Ws, [string]$Message)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Message)
    $Ws.SendAsync([System.ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait(5000) | Out-Null
    $buf = New-Object byte[] 1048576
    $sb = New-Object System.Text.StringBuilder
    do {
        $cts = New-Object System.Threading.CancellationTokenSource(120000)
        $result = $Ws.ReceiveAsync([System.ArraySegment[byte]]::new($buf), $cts.Token).GetAwaiter().GetResult()
        $sb.Append([System.Text.Encoding]::UTF8.GetString($buf, 0, $result.Count)) | Out-Null
    } while (-not $result.EndOfMessage)
    return $sb.ToString()
}

# Create a dedicated new tab directly at the extension options page instead of
# hijacking whatever "page" target happens to be first (avoids clobbering a real tab).
$optTarget = Invoke-RestMethod "http://localhost:$DebugPort/json/new?chrome-extension://$extId/options.html" -Method PUT
if (-not $optTarget.webSocketDebuggerUrl) {
    Write-Error "Could not create options page tab"
    exit 1
}
Start-Sleep -Seconds 2

# -- 6. Connect to options page + call createAllGroups -------------------------

$cdp2 = Connect-Cdp -WsUrl $optTarget.webSocketDebuggerUrl

# Convert PSCustomObject groups back to JSON string for injection
$groupsJsonStr = ConvertTo-Json -InputObject @($groups) -Depth 10 -Compress
$script = "(async function() { const groups = $groupsJsonStr; return JSON.stringify(await window.createAllGroups(groups)); })()"
$payload = "{`"id`":2,`"method`":`"Runtime.evaluate`",`"params`":{`"expression`":$(($script | ConvertTo-Json)),`"returnByValue`":true,`"awaitPromise`":true}}"

Write-Host "Calling createAllGroups..."
$result = Send-Cdp -Ws $cdp2 -Message $payload

# Parse and display result
try {
    $parsed = $result | ConvertFrom-Json
    $inner = $parsed.result.result.value | ConvertFrom-Json
    Write-Host "`nResult:"
    $inner | ForEach-Object {
        $status = if ($_.ok) { "OK" } else { "FAIL $($_.error)" }
        $mergedNote = if ($_.merged) { " [merged into existing group]" } else { "" }
        Write-Host "  $status $($_.name): $($_.count) tabs (groupId=$($_.groupId))$mergedNote"
    }
} catch {
    Write-Host "Raw result: $result"
}
