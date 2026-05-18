param(
  [switch]$WithServices,
  [switch]$SkipBuild
)

$ErrorActionPreference = "Continue"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$results = @()
$knownToolPaths = @(
  "C:\Program Files\Git\cmd",
  "C:\Program Files\Docker\Docker\resources\bin",
  "C:\tools\flutter\bin"
)

foreach ($toolPath in $knownToolPaths) {
  if ((Test-Path $toolPath) -and -not ($env:Path.Split(";") -contains $toolPath)) {
    $env:Path = "$toolPath;$env:Path"
  }
}
$localGitConfig = Join-Path $root "logs\gitconfig-codex"
New-Item -ItemType Directory -Force (Split-Path $localGitConfig) | Out-Null
@"
[safe]
	directory = C:/tools/flutter
	directory = $($root.Path.Replace("\", "/"))
"@ | Set-Content -LiteralPath $localGitConfig -NoNewline
$env:GIT_CONFIG_GLOBAL = $localGitConfig

function Add-Result {
  param(
    [string]$Name,
    [string]$Status,
    [string]$Detail
  )

  $script:results += [pscustomobject]@{
    Check = $Name
    Status = $Status
    Detail = $Detail
  }
}

function Test-CommandExists {
  param([string]$Command)
  return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-DirectoryWritable {
  param([string]$Directory)

  try {
    if (-not (Test-Path $Directory)) {
      return $false
    }
    $probe = Join-Path $Directory ".codex-write-test"
    Set-Content -LiteralPath $probe -Value "ok" -NoNewline -ErrorAction Stop
    Remove-Item -LiteralPath $probe -Force -ErrorAction Stop
    return $true
  } catch {
    return $false
  }
}

function Invoke-Check {
  param(
    [string]$Name,
    [string]$Command,
    [string]$WorkingDirectory = $root
  )

  Push-Location $WorkingDirectory
  try {
    Write-Host "Running: $Name"
    Invoke-Expression $Command
    if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
      Add-Result $Name "PASS" $Command
    } else {
      Add-Result $Name "FAIL" "Exit code $LASTEXITCODE - $Command"
    }
  } catch {
    Add-Result $Name "FAIL" $_.Exception.Message
  } finally {
    Pop-Location
    $global:LASTEXITCODE = 0
  }
}

function Invoke-SmokeWithApi {
  $job = Start-Job -ScriptBlock {
    Set-Location $using:root
    $env:DATABASE_URL = "postgresql://massage:massage@localhost:5432/massage_vn?schema=public"
    $env:REDIS_URL = "redis://localhost:6379"
    $env:NODE_ENV = "development"
    $env:API_PORT = "3000"
    $env:JWT_ACCESS_SECRET = "dev-access-secret"
    $env:JWT_REFRESH_SECRET = "dev-refresh-secret"
    $env:DEV_OTP = "123456"
    $env:S3_ENDPOINT = "http://localhost:9000"
    $env:S3_REGION = "auto"
    $env:S3_BUCKET = "massage-vn"
    $env:S3_ACCESS_KEY = "minioadmin"
    $env:S3_SECRET_KEY = "minioadmin"
    $env:S3_PUBLIC_BASE_URL = "http://localhost:9000/massage-vn"
    node apps/api/dist/main.js
  }

  try {
    $ready = $false
    for ($i = 0; $i -lt 20; $i++) {
      Start-Sleep -Seconds 1
      try {
        Invoke-RestMethod http://localhost:3000/api/health | Out-Null
        $ready = $true
        break
      } catch {}
    }

    if (-not $ready) {
      Receive-Job $job -Keep
      Add-Result "api smoke against local services" "FAIL" "API did not become healthy."
      return
    }

    Invoke-Check "api readiness against local services" "Invoke-RestMethod http://localhost:3000/api/health/ready | ConvertTo-Json -Depth 5"
    Invoke-Check "api smoke against local services" "node infra\scripts\api-smoke.mjs"
  } finally {
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
  }
}

Push-Location $root

Write-Host "== Development Environment =="
try {
  powershell -ExecutionPolicy Bypass -File .\infra\scripts\check-dev-env.ps1
  if ($LASTEXITCODE -eq 0) {
    Add-Result "dev environment" "PASS" "All required tools are available."
  } else {
    Add-Result "dev environment" "WARN" "Some required tools are missing. See table above."
  }
} catch {
  Add-Result "dev environment" "FAIL" $_.Exception.Message
}
$global:LASTEXITCODE = 0

Invoke-Check "script syntax: api smoke" "node --check infra\scripts\api-smoke.mjs"
Invoke-Check "script syntax: env check" "node --check infra\scripts\check-env.mjs"
Invoke-Check "script syntax: seed" "node --check apps\api\prisma\seed.js"
Invoke-Check "env example" "node infra\scripts\check-env.mjs .env.example"
Invoke-Check "prisma validate" "`$env:DATABASE_URL='postgresql://massage:massage@localhost:5432/massage_vn?schema=public'; npx.cmd prisma validate --schema apps/api/prisma/schema.prisma"
Invoke-Check "api typecheck" "npm.cmd run typecheck --workspace @massage-vn/api"
Invoke-Check "admin typecheck" "npm.cmd run typecheck --workspace @massage-vn/admin-web"

if (-not $SkipBuild) {
  Invoke-Check "api build" "npm.cmd run build --workspace @massage-vn/api"
  Invoke-Check "admin build" "npm.cmd run build --workspace @massage-vn/admin-web"
} else {
  Add-Result "api build" "SKIP" "SkipBuild was set."
  Add-Result "admin build" "SKIP" "SkipBuild was set."
}

if (Test-CommandExists "git") {
  if (-not (Test-Path (Join-Path $root ".git"))) {
    Add-Result "git status" "SKIP" "Git is installed, but this folder is not initialized as a Git repository."
  } else {
  Invoke-Check "git status" "git status --short"
  }
} else {
  Add-Result "git status" "SKIP" "Git is not installed or not on PATH."
}

if (Test-CommandExists "docker") {
  Invoke-Check "docker compose config" "docker compose config --quiet"
  docker info --format "{{.ServerVersion}}" *> $null
  $dockerReady = $LASTEXITCODE -eq 0
  $global:LASTEXITCODE = 0

  if ($WithServices -and $dockerReady) {
    Invoke-Check "docker compose up" "docker compose up -d"
    Invoke-Check "prisma migrate deploy" "`$env:DATABASE_URL='postgresql://massage:massage@localhost:5432/massage_vn?schema=public'; npx.cmd prisma migrate deploy --schema apps/api/prisma/schema.prisma"
    Invoke-Check "prisma seed" "`$env:DATABASE_URL='postgresql://massage:massage@localhost:5432/massage_vn?schema=public'; npm.cmd run prisma:seed --workspace @massage-vn/api"
    Invoke-SmokeWithApi
  } elseif ($WithServices) {
    Add-Result "docker compose up" "SKIP" "Docker CLI is installed, but Docker Desktop daemon is not ready or access is denied."
    Add-Result "api smoke against local services" "SKIP" "Needs a ready Docker daemon and local API services."
  } else {
    Add-Result "docker compose up" "SKIP" "Run with -WithServices after Docker Desktop is installed and running."
    Add-Result "api smoke against local services" "SKIP" "Needs Docker services or an already running API."
  }
} else {
  Add-Result "docker compose config" "SKIP" "Docker is not installed or not on PATH."
  Add-Result "docker compose up" "SKIP" "Docker is not installed or not on PATH."
  Add-Result "api smoke against local services" "SKIP" "Docker/API services are not available."
}

$flutterCache = "C:\tools\flutter\bin\cache"
if ((Test-CommandExists "flutter") -and (Test-DirectoryWritable $flutterCache)) {
  Invoke-Check "customer flutter pub get" "flutter pub get" "$root\apps\customer_app"
  Invoke-Check "customer flutter analyze" "flutter analyze" "$root\apps\customer_app"
  Invoke-Check "provider flutter pub get" "flutter pub get" "$root\apps\provider_app"
  Invoke-Check "provider flutter analyze" "flutter analyze" "$root\apps\provider_app"
} elseif (Test-CommandExists "flutter") {
  Add-Result "customer flutter pub get" "SKIP" "Flutter is installed, but $flutterCache is not writable by this user."
  Add-Result "customer flutter analyze" "SKIP" "Flutter is installed, but $flutterCache is not writable by this user."
  Add-Result "provider flutter pub get" "SKIP" "Flutter is installed, but $flutterCache is not writable by this user."
  Add-Result "provider flutter analyze" "SKIP" "Flutter is installed, but $flutterCache is not writable by this user."
} else {
  Add-Result "customer flutter pub get" "SKIP" "Flutter is not installed or not on PATH."
  Add-Result "customer flutter analyze" "SKIP" "Flutter is not installed or not on PATH."
  Add-Result "provider flutter pub get" "SKIP" "Flutter is not installed or not on PATH."
  Add-Result "provider flutter analyze" "SKIP" "Flutter is not installed or not on PATH."
}

Write-Host ""
Write-Host "== Local Verification Summary =="
$results | Format-Table -AutoSize

$failed = $results | Where-Object { $_.Status -eq "FAIL" }
Pop-Location

if ($failed.Count -gt 0) {
  exit 1
}

exit 0
