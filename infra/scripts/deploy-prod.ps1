param(
  [string]$EnvFile = ".env",
  [switch]$SkipBuild,
  [switch]$SkipSeed,
  [switch]$SkipSmoke
)

$ErrorActionPreference = "Stop"

function Run-Step {
  param(
    [string]$Name,
    [scriptblock]$Command
  )

  Write-Host ""
  Write-Host "==> $Name"
  & $Command
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is not installed or not available on PATH."
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "Node.js is not installed or not available on PATH."
}

Run-Step "Validate environment" {
  node infra/scripts/check-env.mjs $EnvFile
}

$compose = @("compose", "-f", "docker-compose.prod.yml")

if ($SkipBuild) {
  Run-Step "Start production compose" {
    docker @compose up -d
  }
} else {
  Run-Step "Build and start production compose" {
    docker @compose up -d --build
  }
}

Run-Step "Run Prisma migrations" {
  docker @compose exec api npx prisma migrate deploy --schema apps/api/prisma/schema.prisma
}

if (-not $SkipSeed) {
  Run-Step "Seed demo data" {
    docker @compose exec api npm run prisma:seed --workspace @massage-vn/api
  }
}

if (-not $SkipSmoke) {
  Run-Step "Run E2E smoke script" {
    $env:API_BASE_URL = "http://localhost/api"
    node infra/scripts/api-smoke.mjs
  }
}

Write-Host ""
Write-Host "Deployment flow completed."
