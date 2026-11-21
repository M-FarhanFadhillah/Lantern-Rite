# Runs every pre-commit check: StyLua (format), Selene (lint) and luau-lsp (strict types).
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\check.ps1
# Downloads luau-lsp's Roblox type definitions for the pinned version on first use
# (into the git-ignored .luau-lsp/ folder).

$env:Path = "$env:USERPROFILE\.rokit\bin;$env:Path"
Set-Location (Split-Path $PSScriptRoot -Parent)
$failed = @()

stylua --check src tests
if ($LASTEXITCODE -ne 0) { $failed += "stylua" }

selene src tests
if ($LASTEXITCODE -ne 0) { $failed += "selene" }

$version = (luau-lsp --version | Select-Object -First 1).Trim()
$defs = ".luau-lsp/globalTypes.None.d.luau"
$stamp = ".luau-lsp/version.txt"
if (-not (Test-Path $defs) -or -not (Test-Path $stamp) -or ((Get-Content $stamp) -ne $version)) {
	New-Item -ItemType Directory -Force .luau-lsp | Out-Null
	Invoke-WebRequest -UseBasicParsing -OutFile $defs `
		-Uri "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$version/scripts/globalTypes.None.d.luau"
	Set-Content -Path $stamp -Value $version -Encoding ascii
}

rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json "--definitions=@roblox=$defs" "--ignore=**/_Index/**" src tests
if ($LASTEXITCODE -ne 0) { $failed += "luau-lsp" }

if ($failed.Count -gt 0) {
	Write-Host "FAILED: $($failed -join ', ')"
	exit 1
}
Write-Host "All checks passed."
