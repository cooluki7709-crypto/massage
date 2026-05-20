param(
  [string]$RepoRoot = "C:\dev\massage-vn-workspace\repo"
)

$ErrorActionPreference = "Stop"

$statePath = Join-Path $RepoRoot "logs\hands-local\state.json"
if (-not (Test-Path $statePath)) {
  Write-Host "No HANDS local state file found at $statePath"
  exit 0
}

$state = Get-Content -Raw $statePath | ConvertFrom-Json
foreach ($processId in @($state.apiPid, $state.adminPid)) {
  if (-not $processId) {
    continue
  }

  $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
  if ($process) {
    Stop-Process -Id $processId -Force
  }
}

Remove-Item $statePath -Force
Write-Host "HANDS local services stopped"
