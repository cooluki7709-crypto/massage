param(
  [string]$Root = "C:\dev\massage-vn-workspace"
)

$ErrorActionPreference = "Stop"

$repoSource = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$workspaceBase = Split-Path $repoSource.Path -Parent
$repoTarget = Join-Path $Root "repo"
$secretsTarget = Join-Path $Root "secrets"
$apkTarget = Join-Path $Root "references\apk"
$analysisTarget = Join-Path $Root "references\analysis"

$serviceAccountSource = Join-Path $workspaceBase "local-secrets\massage-vn-firebase-adminsdk.json"
$xapkSource = "C:\Users\laboy\Downloads\Glow+-+Massage+&+Spa+24_7_3.11.4_apkcombo.com.xapk"
$blackboxSource = Join-Path $workspaceBase "apk_blackbox_results_glow"

New-Item -ItemType Directory -Force -Path $repoTarget | Out-Null
New-Item -ItemType Directory -Force -Path $secretsTarget | Out-Null
New-Item -ItemType Directory -Force -Path $apkTarget | Out-Null
New-Item -ItemType Directory -Force -Path $analysisTarget | Out-Null

$excludeDirs = @(
  "node_modules",
  "build",
  ".dart_tool",
  ".next",
  "dist",
  "coverage",
  "logs"
)

$repoArguments = @(
  $repoSource.Path,
  $repoTarget,
  "/E",
  "/R:2",
  "/W:1",
  "/XD"
) + $excludeDirs

Write-Host "Syncing repo to $repoTarget"
robocopy @repoArguments | Out-Host
$repoCode = $LASTEXITCODE
if ($repoCode -ge 8) {
  throw "robocopy repo sync failed with exit code $repoCode"
}

if (Test-Path $serviceAccountSource) {
  Copy-Item -LiteralPath $serviceAccountSource -Destination (Join-Path $secretsTarget "massage-vn-firebase-adminsdk.json") -Force
}

if (Test-Path $xapkSource) {
  Copy-Item -LiteralPath $xapkSource -Destination (Join-Path $apkTarget (Split-Path $xapkSource -Leaf)) -Force
}

if (Test-Path $blackboxSource) {
  $analysisArguments = @(
    $blackboxSource,
    (Join-Path $analysisTarget "apk_blackbox_results_glow"),
    "/E",
    "/R:2",
    "/W:1"
  )
  Write-Host "Syncing analysis results to $analysisTarget"
  robocopy @analysisArguments | Out-Host
  $analysisCode = $LASTEXITCODE
  if ($analysisCode -ge 8) {
    throw "robocopy analysis sync failed with exit code $analysisCode"
  }
}

$envPath = Join-Path $repoTarget ".env"
if (Test-Path $envPath) {
  $envText = Get-Content -Raw $envPath
  $escapedRoot = [Regex]::Escape($serviceAccountSource)
  $updated = $envText -replace $escapedRoot, "C:\dev\massage-vn-workspace\secrets\massage-vn-firebase-adminsdk.json"
  if ($updated -ne $envText) {
    Set-Content -Path $envPath -Value $updated -Encoding utf8
  }
}

$summaryPath = Join-Path $Root "README_LOCAL.txt"
$summary = @"
Massage VN local workspace

repo:
  $repoTarget

secrets:
  $secretsTarget

reference apk:
  $apkTarget

analysis:
  $analysisTarget
"@
Set-Content -Path $summaryPath -Value $summary -Encoding utf8

Write-Host "Workspace organized at $Root"
