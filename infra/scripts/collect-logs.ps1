param(
  [string]$ComposeFile = "docker-compose.prod.yml",
  [string]$OutputDir = "logs",
  [string]$Since = "2h"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is not installed or not available on PATH."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bundleDir = Join-Path $OutputDir "diagnostics-$timestamp"
New-Item -ItemType Directory -Force -Path $bundleDir | Out-Null

$services = @("api", "admin_web", "nginx", "postgres", "redis", "minio", "minio-init")

Write-Host "Collecting compose status"
docker compose -f $ComposeFile ps | Out-File -Encoding utf8 (Join-Path $bundleDir "compose-ps.txt")

foreach ($service in $services) {
  Write-Host "Collecting logs for $service"
  docker compose -f $ComposeFile logs --since $Since --no-color $service | Out-File -Encoding utf8 (Join-Path $bundleDir "$service.log")
}

Write-Host "Diagnostics collected: $bundleDir"
