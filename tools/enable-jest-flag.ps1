# Turns on FFlagEnableLoadModule for Roblox Studio so Jest Lua can load test modules
# (it needs debug.loadmodule). Each Studio update installs a new version folder and drops
# the flag, so re-run this after an update, then restart Studio:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\enable-jest-flag.ps1

$versions = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
$studio = Get-ChildItem $versions -Directory |
	Where-Object { Test-Path (Join-Path $_.FullName "RobloxStudioBeta.exe") } |
	Sort-Object LastWriteTime -Descending |
	Select-Object -First 1
if (-not $studio) { throw "No Roblox Studio install found under $versions" }

$settingsDir = Join-Path $studio.FullName "ClientSettings"
$file = Join-Path $settingsDir "ClientAppSettings.json"
New-Item -ItemType Directory -Force $settingsDir | Out-Null

# Keep any flags that are already set.
$flags = @{}
if (Test-Path $file) {
	$existing = Get-Content $file -Raw | ConvertFrom-Json
	foreach ($p in $existing.PSObject.Properties) { $flags[$p.Name] = $p.Value }
}
$flags["FFlagEnableLoadModule"] = $true

# ASCII avoids a byte-order mark, which Studio's JSON reader may reject.
($flags | ConvertTo-Json) | Set-Content -Path $file -Encoding ascii
"Wrote $file"
"Restart Roblox Studio for the flag to take effect."
