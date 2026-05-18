param(
  [switch]$Install
)

$ErrorActionPreference = "Stop"

$tools = @(
  @{
    Name = "Node.js"
    Command = "node"
    Args = @("--version")
    Required = $true
    Choco = "nodejs-lts"
  },
  @{
    Name = "npm"
    Command = "npm.cmd"
    Args = @("--version")
    Required = $true
    Choco = $null
  },
  @{
    Name = "Git"
    Command = "git"
    Args = @("--version")
    Required = $true
    Choco = "git"
    FallbackCommands = @("C:\Program Files\Git\cmd\git.exe")
  },
  @{
    Name = "Docker"
    Command = "docker"
    Args = @("--version")
    Required = $true
    Choco = "docker-desktop"
    FallbackCommands = @("C:\Program Files\Docker\Docker\resources\bin\docker.exe")
  },
  @{
    Name = "Flutter"
    Command = "flutter"
    Args = @("--version")
    Required = $true
    Choco = "flutter"
    FallbackCommands = @("C:\tools\flutter\bin\flutter.bat")
    DetectOnlyFallback = $true
  },
  @{
    Name = "Dart"
    Command = "dart"
    Args = @("--version")
    Required = $true
    Choco = $null
    FallbackCommands = @("C:\tools\flutter\bin\cache\dart-sdk\bin\dart.exe")
    PreferFallback = $true
  },
  @{
    Name = "Java"
    Command = "java"
    Args = @("-version")
    Required = $false
    Choco = "temurin17"
  },
  @{
    Name = "Android Studio"
    Command = "studio64.exe"
    Args = @()
    Required = $false
    Choco = "androidstudio"
  }
)

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-CommandVersion {
  param(
    [string]$Command,
    [string[]]$CommandArgs
  )

  $found = Get-Command $Command -ErrorAction SilentlyContinue
  if (-not $found) {
    return $null
  }

  try {
    $output = & $Command @CommandArgs 2>&1 | Select-Object -First 1
    return ($output | Out-String).Trim()
  } catch {
    return "found at $($found.Source)"
  }
}

function Get-ToolVersion {
  param(
    [hashtable]$Tool
  )

  $fallbackCommands = @()
  if ($Tool.ContainsKey("FallbackCommands")) {
    $fallbackCommands = $Tool.FallbackCommands
  }

  if ($Tool.ContainsKey("DetectOnlyFallback") -and $Tool.DetectOnlyFallback) {
    foreach ($fallback in $fallbackCommands) {
      if (Test-Path $fallback) {
        return "installed at $fallback; PATH/permissions may need attention"
      }
    }
  }

  if (-not ($Tool.ContainsKey("PreferFallback") -and $Tool.PreferFallback)) {
    $version = Get-CommandVersion -Command $Tool.Command -CommandArgs $Tool.Args
    if ($version) {
      return $version
    }
  }

  foreach ($fallback in $fallbackCommands) {
    if (-not (Test-Path $fallback)) {
      continue
    }

    try {
      $output = & $fallback @($Tool.Args) 2>&1 | Select-Object -First 1
      return "$(($output | Out-String).Trim()) (found at $fallback; PATH may need restart)"
    } catch {
      return "installed at $fallback, but not runnable: $($_.Exception.Message)"
    }
  }

  if ($Tool.ContainsKey("PreferFallback") -and $Tool.PreferFallback) {
    $version = Get-CommandVersion -Command $Tool.Command -CommandArgs $Tool.Args
    if ($version) {
      return $version
    }
  }

  return $null
}

$missing = @()
$rows = @()

foreach ($tool in $tools) {
  $version = Get-ToolVersion -Tool $tool
  $status = if ($version) { "OK" } elseif ($tool.Required) { "MISSING" } else { "OPTIONAL_MISSING" }
  if (-not $version -and $tool.Required) {
    $missing += $tool
  }
  $rows += [pscustomobject]@{
    Tool = $tool.Name
    Status = $status
    Version = if ($version) { $version } else { "-" }
    InstallWithChocolatey = if ($tool.Choco) { "choco install $($tool.Choco) -y" } else { "-" }
  }
}

$rows | Format-Table -AutoSize

if ($missing.Count -eq 0) {
  Write-Host "Development environment check passed."
  exit 0
}

Write-Host ""
Write-Host "Missing required tools:"
foreach ($tool in $missing) {
  Write-Host "- $($tool.Name)"
}

if (-not $Install) {
Write-Host ""
Write-Host "To install missing Chocolatey-managed tools, open PowerShell as Administrator and run:"
Write-Host "powershell -ExecutionPolicy Bypass -File .\infra\scripts\check-dev-env.ps1 -Install"
  exit 1
}

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Write-Error "Chocolatey is not available on PATH. Install Chocolatey or install the missing tools manually."
}

if (-not (Test-IsAdministrator)) {
  Write-Error "Installation requires an Administrator PowerShell session."
}

foreach ($tool in $missing) {
  if (-not $tool.Choco) {
    Write-Warning "No direct Chocolatey package configured for $($tool.Name). Install it through its parent SDK."
    continue
  }

  Write-Host "Installing $($tool.Name) with Chocolatey..."
  choco install $tool.Choco -y
}

Write-Host ""
Write-Host "Install step finished. Restart PowerShell, then run:"
Write-Host ".\infra\scripts\check-dev-env.ps1"
