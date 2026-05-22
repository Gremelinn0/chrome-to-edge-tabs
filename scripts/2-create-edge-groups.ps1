<#
.SYNOPSIS
  Creates Chrome tab groups in Microsoft Edge using CDP + a temporary MV3 extension.
  Reads groups from %TEMP%\chrome_groups_final.json (produced by 1-extract-chrome-groups.ps1).

.NOTES
  - Requires Microsoft Edge 88+ (Chromium-based)
  - Uses a temporary Edge profile so no sign-in is needed
  - Extension ID is deterministic based on the extension path: ojneegljainpehijglgglcpjjapabcjo
  - Validated on Edge 140 / Chrome 135+ (2026-04-23)
#>

param(
    [string]$JsonPath = "$env:TEMP\chrome_groups_final.json",
    [int]$DebugPort = 9223
)

$extPath     = "$env:TEMP\tab-group-ext"
$profilePath = "$env:TEMP\edge-fresh-profile"
$edgeBin     = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$extId       = "ojneegljainpehijglgglcpjjapabcjo"

# ── 1. Read groups JSON ────────────────────────────────────────────────────────

if (-not (Test-Path $JsonPath)) {
    Write-Error "Groups JSON not found: $JsonPath — run 1-extract-chrome-groups.ps1 first"
    exit 1
}
$groups = Get-Content $JsonPath -Raw | ConvertFrom-Json
Write-Host "Groups to create: $($groups.Count)"

# ── 2. Write extension files ──────────────────────────────────────────────────

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
  const groupId = await chrome.tabs.group({ tabIds });
  if (chrome.tabGroups) {
    await chrome.tabGroups.update(groupId, { title: groupName, color: color || "cyan" });
  }
  return { groupId, tabIds, groupName };
};
window.createAllGroups = async function(groups) {
  const results = [];
  for (const g of groups) {
    try {
      const r = await window.createTabGroup(g.tabs.map(t => t.url), g.name, g.edgeColor || "cyan");
      results.push({ name: g.name, ok: true, groupId: r.groupId, count: r.tabIds.length });
    } catch (e) {
      results.push({ name: g.name, ok: false, error: e.message });
    }
  }
  return results;
};
'@

Write-Host "Extension written to: $extPath"

# ── 3. Kill any existing Edge debug instance on this port ─────────────────────

$existing = Get-Process msedge -ErrorAction SilentlyContinue | Where-Object {
    (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine -like "*$DebugPort*"
}
if ($existing) { $existing | Stop-Process -Force; Start-Sleep -Seconds 2 }

# ── 4. Launch Edge with extension ─────────────────────────────────────────────

New-Item -ItemType Directory $profilePath -Force | Out-Null
$edgeArgs = "--remote-debugging-port=$DebugPort --user-data-dir=`"$profilePath`" --load-extension=`"$extPath`" --no-first-run --disable-sync about:blank"
Start-Process $edgeBin -ArgumentList $edgeArgs
Write-Host "Edge launched, waiting 5s..."
Start-Sleep -Seconds 5

# Check CDP
try {
    $targets = Invoke-RestMethod "http://localhost:$DebugPort/json" -TimeoutSec 5
    Write-Host "CDP ready — $($targets.Count) targets"
} catch {
    Write-Error "CDP not responding on port $DebugPort: $_"
    exit 1
}

# ── 5. Navigate about:blank → options page ────────────────────────────────────

Add-Type -TypeDefinition @"
using System; using System.Net.WebSockets; using System.Text; using System.Threading;
public class TabGroupCdp {
    private ClientWebSocket _ws = new ClientWebSocket();
    public bool Connect(string wsUrl, out string err) {
        err = "";
        try { _ws.ConnectAsync(new Uri(wsUrl), CancellationToken.None).Wait(8000); return _ws.State == WebSocketState.Open; }
        catch (AggregateException ae) { err = ae.InnerException != null ? ae.InnerException.Message : ae.Message; return false; }
    }
    public string Send(string msg) {
        var bytes = Encoding.UTF8.GetBytes(msg);
        _ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None).Wait(5000);
        var buf = new byte[1048576]; var sb = new System.Text.StringBuilder(); WebSocketReceiveResult r;
        do { var cts = new CancellationTokenSource(120000); r = _ws.ReceiveAsync(new ArraySegment<byte>(buf), cts.Token).GetAwaiter().GetResult(); sb.Append(Encoding.UTF8.GetString(buf, 0, r.Count)); } while (!r.EndOfMessage);
        return sb.ToString();
    }
}
"@

$pageTarget = (Invoke-RestMethod "http://localhost:$DebugPort/json") | Where-Object { $_.type -eq "page" } | Select-Object -First 1
$cdp1 = New-Object TabGroupCdp
$e1 = ""; $cdp1.Connect($pageTarget.webSocketDebuggerUrl, [ref]$e1) | Out-Null
$cdp1.Send("{`"id`":1,`"method`":`"Page.navigate`",`"params`":{`"url`":`"chrome-extension://$extId/options.html`"}}") | Out-Null
Start-Sleep -Seconds 3

# ── 6. Connect to options page + call createAllGroups ─────────────────────────

$optTarget = (Invoke-RestMethod "http://localhost:$DebugPort/json") | Where-Object { $_.url -like "*options.html*" } | Select-Object -First 1
if (-not $optTarget) {
    Write-Error "Options page not found after navigation"
    exit 1
}

$cdp2 = New-Object TabGroupCdp
$e2 = ""; $cdp2.Connect($optTarget.webSocketDebuggerUrl, [ref]$e2) | Out-Null

# Convert PSCustomObject groups back to JSON string for injection
$groupsJsonStr = $groups | ConvertTo-Json -Depth 10 -Compress
$script = "(async function() { const groups = $groupsJsonStr; return JSON.stringify(await window.createAllGroups(groups)); })()"
$payload = "{`"id`":2,`"method`":`"Runtime.evaluate`",`"params`":{`"expression`":$(($script | ConvertTo-Json)),`"returnByValue`":true,`"awaitPromise`":true}}"

Write-Host "Calling createAllGroups..."
$result = $cdp2.Send($payload)

# Parse and display result
try {
    $parsed = $result | ConvertFrom-Json
    $inner = $parsed.result.result.value | ConvertFrom-Json
    Write-Host "`nResult:"
    $inner | ForEach-Object {
        $status = if ($_.ok) { "✅" } else { "❌ $($_.error)" }
        Write-Host "  $status $($_.name): $($_.count) tabs (groupId=$($_.groupId))"
    }
} catch {
    Write-Host "Raw result: $result"
}
