# chrome-to-edge-tabs

Export your Chrome tab groups to Microsoft Edge — automatically, with correct group names and colors.

No external dependencies. Pure PowerShell + a temporary MV3 extension injected via CDP.

## How it works

1. **Extract** — reads Chrome's active session file (SNSS binary format) to capture all open tab groups and their URLs. Falls back to Chrome Sync LevelDB for saved groups.
2. **Create** — launches Edge in debug mode with a lightweight MV3 extension, connects via CDP WebSocket, and calls `chrome.tabGroups.update()` to recreate each group with its name and color.

```
Chrome SNSS/LevelDB  →  chrome_groups_final.json  →  Edge CDP + MV3 extension  →  grouped tabs
```

## Requirements

- Windows 10/11
- Google Chrome (any recent version)
- Microsoft Edge 88+ (Chromium-based)
- PowerShell 5.1+ (built into Windows)

## Usage

### Step 1 — Extract groups from Chrome

```powershell
.\scripts\1-extract-chrome-groups.ps1
```

Outputs `%TEMP%\chrome_groups_final.json` with all groups and their URLs.

### Step 2 — Create groups in Edge

```powershell
.\scripts\2-create-edge-groups.ps1
```

A fresh Edge window opens with all tab groups recreated.

### Export specific groups only

Edit `chrome_groups_final.json` before running step 2, or filter by name:

```powershell
# Example: export only the "INVEST" group
$all = Get-Content "$env:TEMP\chrome_groups_final.json" | ConvertFrom-Json
$filtered = $all | Where-Object { $_.name -like "*INVEST*" }
$filtered | ConvertTo-Json -Depth 10 | Out-File "$env:TEMP\chrome_groups_final.json" -Encoding utf8
.\scripts\2-create-edge-groups.ps1
```

### Available Edge colors

`yellow` · `purple` · `green` · `red` · `orange` · `blue` · `cyan` · `pink` · `grey`

To set a color, edit the `edgeColor` field in `chrome_groups_final.json`.

## Extension

The `extension/` folder contains the MV3 source. The scripts write it to `%TEMP%\tab-group-ext\` at runtime — you don't need to install it manually.

The extension ID (`ojneegljainpehijglgglcpjjapabcjo`) is deterministic based on the `%TEMP%\tab-group-ext` path on Windows.

## Known limitations

- **Chrome must be running** for SNSS extraction (session file is live). Groups must be saved in Chrome (click group name → "Save group") to appear in LevelDB.
- **Edge profile is temporary** — the fresh debug profile has no bookmarks or extensions. Tabs open correctly, but you may need to log in to sites.
- **Chrome 132+ extension install** — `--load-extension` flag works for this script's own temporary extension (developer mode not required since it uses a fresh profile). This is different from installing extensions into your main Edge profile.

## License

MIT
