param(
  [switch]$ClearChocolateyLocks
)

$ErrorActionPreference = "Stop"

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
  Write-Error "Run this script from PowerShell opened with 'Run as Administrator'."
}

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Write-Error "Chocolatey is not available on PATH. Install Chocolatey first: https://chocolatey.org/install"
}

if ($ClearChocolateyLocks) {
  $lockFiles = Get-ChildItem "C:\ProgramData\chocolatey\lib" -Filter "*.lock" -ErrorAction SilentlyContinue
  if ($lockFiles.Count -gt 0) {
    Write-Host "Removing stale Chocolatey lock files:"
    $lockFiles | ForEach-Object {
      Write-Host "- $($_.FullName)"
      Remove-Item -LiteralPath $_.FullName -Force
    }
  }
}

$packages = @(
  "git",
  "docker-desktop",
  "flutter"
)

foreach ($package in $packages) {
  Write-Host "Installing $package..."
  choco install $package -y --no-progress
}

Write-Host ""
Write-Host "Install commands finished."
Write-Host "Next steps:"
Write-Host "1. Restart PowerShell."
Write-Host "2. Start Docker Desktop once and finish any WSL 2 prompts."
Write-Host "3. Run: npm.cmd run verify:local"
Write-Host "4. Run with services: powershell -ExecutionPolicy Bypass -File .\infra\scripts\verify-local.ps1 -WithServices"
