param(
  [Parameter(Mandatory = $true)]
  [string]$BackupPath,
  [string]$ComposeFile = "docker-compose.prod.yml",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not $Force) {
  throw "Restore is destructive. Re-run with -Force after confirming BackupPath and target database."
}

if (-not (Test-Path $BackupPath)) {
  throw "Backup file not found: $BackupPath"
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is not installed or not available on PATH."
}

Write-Host "Restoring database from $BackupPath"
Get-Content -Encoding Byte -Path $BackupPath | docker compose -f $ComposeFile exec -T postgres pg_restore -U massage -d massage_vn --clean --if-exists --no-owner
Write-Host "Restore completed."
