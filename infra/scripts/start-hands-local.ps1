param(
  [string]$RepoRoot = "C:\dev\massage-vn-workspace\repo",
  [int]$ApiPort = 3100,
  [int]$AdminPort = 3101
)

$ErrorActionPreference = "Stop"

function Assert-PortFree {
  param([int]$Port)

  $inUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if ($inUse) {
    throw "Port $Port is already in use. Stop the existing process or choose a different port."
  }
}

function Wait-HttpReady {
  param(
    [string]$Url,
    [int]$TimeoutSeconds,
    [int[]]$AllowedStatusCodes = @(200)
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    try {
      $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
      if ($AllowedStatusCodes -contains [int]$response.StatusCode) {
        return
      }
    } catch {
      $exception = $_.Exception
      if ($exception.Response -and $AllowedStatusCodes -contains [int]$exception.Response.StatusCode.value__) {
        return
      }
    }
    Start-Sleep -Seconds 2
  } while ((Get-Date) -lt $deadline)

  throw "Timed out waiting for $Url"
}

function Ensure-WorkspaceReady {
  param([string]$Root)

  $nextBinary = Join-Path $Root "node_modules\next\dist\bin\next"
  $globModule = Join-Path $Root "node_modules\glob\dist\commonjs\glob.js"

  if (-not (Test-Path $nextBinary) -or -not (Test-Path $globModule)) {
    Write-Host "Installing npm dependencies in $Root"
    & npm.cmd ci --prefix $Root
    if ($LASTEXITCODE -ne 0) {
      throw "npm ci failed for $Root"
    }
  }

  Write-Host "Generating Prisma client in $Root"
  Push-Location $Root
  try {
    & .\node_modules\.bin\prisma.cmd generate --schema .\apps\api\prisma\schema.prisma
    if ($LASTEXITCODE -ne 0) {
      throw "Prisma generate failed for $Root"
    }
  } finally {
    Pop-Location
  }
}

function Clear-ApiDist {
  param([string]$Root)

  $apiDist = Join-Path $Root "apps\api\dist"
  if (Test-Path $apiDist) {
    Write-Host "Clearing stale API build output in $apiDist"
    Remove-Item -LiteralPath $apiDist -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$logDir = Join-Path $RepoRoot "logs\hands-local"
$statePath = Join-Path $logDir "state.json"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Assert-PortFree -Port $ApiPort
Assert-PortFree -Port $AdminPort
Ensure-WorkspaceReady -Root $RepoRoot
Clear-ApiDist -Root $RepoRoot

$apiLog = Join-Path $logDir "api.log"
$adminLog = Join-Path $logDir "admin.log"

$apiCommand = @"
Set-Location '$RepoRoot'
`$env:API_PORT='$ApiPort'
`$env:ADMIN_API_BASE_URL='http://localhost:$ApiPort/api'
npm.cmd run dev --workspace @massage-vn/api *> '$apiLog'
"@

$adminCommand = @"
Set-Location '$RepoRoot'
`$env:ADMIN_API_BASE_URL='http://localhost:$ApiPort/api'
npm.cmd run dev --workspace @massage-vn/admin-web -- --port $AdminPort *> '$adminLog'
"@

$apiProcess = Start-Process powershell -ArgumentList @(
  "-NoLogo",
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-Command",
  $apiCommand
) -WindowStyle Hidden -PassThru

$adminProcess = Start-Process powershell -ArgumentList @(
  "-NoLogo",
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-Command",
  $adminCommand
) -WindowStyle Hidden -PassThru

$state = [pscustomobject]@{
  appName = "HANDS"
  coverage = "Vietnam nationwide"
  repoRoot = $RepoRoot
  apiPort = $ApiPort
  adminPort = $AdminPort
  apiPid = $apiProcess.Id
  adminPid = $adminProcess.Id
  startedAt = (Get-Date).ToString("o")
}
$state | ConvertTo-Json | Set-Content -Path $statePath -Encoding utf8

Wait-HttpReady -Url "http://localhost:$ApiPort/api/health" -TimeoutSeconds 90
Wait-HttpReady -Url "http://localhost:$AdminPort" -TimeoutSeconds 90 -AllowedStatusCodes @(200, 307, 308, 404)

Write-Host "HANDS local services started"
Write-Host "API:   http://localhost:$ApiPort/api/health"
Write-Host "Admin: http://localhost:$AdminPort"
Write-Host "Logs:  $logDir"
