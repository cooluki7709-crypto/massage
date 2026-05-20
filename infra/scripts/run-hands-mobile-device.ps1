param(
  [ValidateSet("customer", "provider")]
  [string]$App,
  [string]$DeviceId,
  [string]$RepoRoot = "C:\dev\massage-vn-workspace\repo",
  [int]$ApiPort = 3100
)

$ErrorActionPreference = "Stop"

function Get-TargetDeviceId {
  param([string]$PreferredDeviceId)

  $deviceLines = (& adb devices) | Select-Object -Skip 1
  $devices = @()

  foreach ($line in $deviceLines) {
    if (-not $line.Trim()) {
      continue
    }

    $parts = $line -split "\s+"
    if ($parts.Length -ge 2 -and $parts[1] -eq "device") {
      $devices += $parts[0]
    }
  }

  if ($PreferredDeviceId) {
    if ($devices -notcontains $PreferredDeviceId) {
      throw "Requested device '$PreferredDeviceId' is not connected. Connected devices: $($devices -join ', ')"
    }

    return $PreferredDeviceId
  }

  if ($devices.Count -eq 0) {
    throw "No Android device is connected. Connect a phone with USB debugging enabled, approve the RSA prompt, then rerun this script."
  }

  if ($devices.Count -gt 1) {
    throw "Multiple Android devices are connected. Rerun with -DeviceId one of: $($devices -join ', ')"
  }

  return $devices[0]
}

$appDir = switch ($App) {
  "customer" { Join-Path $RepoRoot "apps\customer_app" }
  "provider" { Join-Path $RepoRoot "apps\provider_app" }
}

if (-not (Test-Path $appDir)) {
  throw "App directory not found: $appDir"
}

$targetDeviceId = Get-TargetDeviceId -PreferredDeviceId $DeviceId

Write-Host "Using Android device: $targetDeviceId"
Write-Host "Configuring adb reverse tcp:$ApiPort -> tcp:$ApiPort"
& adb -s $targetDeviceId reverse "tcp:$ApiPort" "tcp:$ApiPort"
if ($LASTEXITCODE -ne 0) {
  throw "adb reverse failed for device $targetDeviceId"
}

Push-Location $appDir
try {
  & flutter run -d $targetDeviceId "--dart-define=API_BASE_URL=http://127.0.0.1:$ApiPort/api" "--dart-define=SOCKET_BASE_URL=http://127.0.0.1:$ApiPort"
} finally {
  Pop-Location
}
