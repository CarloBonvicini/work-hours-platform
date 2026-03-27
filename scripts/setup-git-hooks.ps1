$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

git config core.hooksPath .githooks

Write-Host "Git hooks path impostato su .githooks"
Write-Host "Pre-commit attivo."
