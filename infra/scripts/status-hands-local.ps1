param(
  [string]$RepoRoot = "C:\dev\massage-vn-workspace\repo"
)

$ErrorActionPreference = "Stop"

$statePath = Join-Path $RepoRoot "logs\hands-local\state.json"
if (-not (Test-Path $statePath)) {
  Write-Host "HANDS local services are not started"
  exit 0
}

$state = Get-Content -Raw $statePath | ConvertFrom-Json

$apiProcess = Get-Process -Id $state.apiPid -ErrorAction SilentlyContinue
$adminProcess = Get-Process -Id $state.adminPid -ErrorAction SilentlyContinue

[pscustomobject]@{
  appName = $state.appName
  coverage = $state.coverage
  repoRoot = $state.repoRoot
  apiPort = $state.apiPort
  adminPort = $state.adminPort
  apiRunning = [bool]$apiProcess
  adminRunning = [bool]$adminProcess
  startedAt = $state.startedAt
  apiHealth = "http://localhost:$($state.apiPort)/api/health"
  adminUrl = "http://localhost:$($state.adminPort)"
} | ConvertTo-Json -Depth 5
