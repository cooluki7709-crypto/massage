param(
  [string]$ComposeFile = "docker-compose.prod.yml",
  [string]$OutputDir = "backups"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is not installed or not available on PATH."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = Join-Path $OutputDir "massage-vn-$timestamp.dump"

Write-Host "Creating database backup at $outputPath"
docker compose -f $ComposeFile exec -T postgres pg_dump -U massage -d massage_vn -Fc | Set-Content -Encoding Byte -Path $outputPath
Write-Host "Backup completed: $outputPath"
