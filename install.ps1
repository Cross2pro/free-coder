$ErrorActionPreference = 'Stop'

$Repo = if ($env:FREE_CODE_REPO) { $env:FREE_CODE_REPO } else { 'Cross2pro/free-coder' }
$Version = if ($env:FREE_CODE_VERSION) { $env:FREE_CODE_VERSION } else { 'latest' }
$InstallRoot = if ($env:FREE_CODE_HOME) { $env:FREE_CODE_HOME } else { Join-Path $HOME 'AppData\Local\free-code' }
$BinDir = if ($env:FREE_CODE_BIN_DIR) { $env:FREE_CODE_BIN_DIR } else { Join-Path $InstallRoot 'bin' }
$SourceDir = Join-Path $InstallRoot 'src'
$BunMinVersion = '1.3.11'

function Write-Info($Message) { Write-Host "[*] $Message" -ForegroundColor Cyan }
function Write-Ok($Message) { Write-Host "[+] $Message" -ForegroundColor Green }
function Write-Warn($Message) { Write-Host "[!] $Message" -ForegroundColor Yellow }
function Fail($Message) { throw $Message }

function Get-Arch {
  $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
  switch ($arch) {
    'x64' { return 'x64' }
    'arm64' { return 'arm64' }
    default { Fail "Unsupported Windows architecture: $arch" }
  }
}

function Get-AssetName {
  $arch = Get-Arch
  return "free-code-windows-$arch.zip"
}

function Get-ReleaseUrl {
  param([string]$AssetName)

  if ($Version -eq 'latest') {
    return "https://github.com/$Repo/releases/latest/download/$AssetName"
  }

  return "https://github.com/$Repo/releases/download/$Version/$AssetName"
}

function Ensure-UserPath {
  if (-not (Test-Path -LiteralPath $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
  }

  $currentUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $pathParts = @()
  if ($currentUserPath) {
    $pathParts = $currentUserPath -split ';' | Where-Object { $_ }
  }

  if ($pathParts -contains $BinDir) {
    return
  }

  $newUserPath = if ($currentUserPath) { "$currentUserPath;$BinDir" } else { $BinDir }
  [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
  Write-Warn "$BinDir was added to your user PATH. Open a new terminal after install."
}

function Install-FromRelease {
  $assetName = Get-AssetName
  $url = Get-ReleaseUrl -AssetName $assetName
  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("free-code-install-" + [guid]::NewGuid().ToString('N'))
  $archivePath = Join-Path $tempRoot $assetName
  $extractPath = Join-Path $tempRoot 'extract'

  New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

  try {
    Write-Info "Downloading prebuilt package..."
    Invoke-WebRequest -Uri $url -OutFile $archivePath

    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force

    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $extractPath 'free-code\free-code.exe') -Destination (Join-Path $BinDir 'free-code.exe') -Force

    Set-Content -LiteralPath (Join-Path $BinDir 'free-code.cmd') -Value "@echo off`r`n""%~dp0\free-code.exe"" %*`r`n" -NoNewline
    Set-Content -LiteralPath (Join-Path $BinDir 'free-code.ps1') -Value '$exe = Join-Path $PSScriptRoot ''free-code.exe''; & $exe @args; exit $LASTEXITCODE' -NoNewline

    Write-Ok "Installed prebuilt binary to $BinDir\free-code.exe"
    return $true
  } catch {
    Write-Warn "Prebuilt download failed: $($_.Exception.Message)"
    return $false
  } finally {
    if (Test-Path -LiteralPath $tempRoot) {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
  }
}

function Version-Gte {
  param([string]$A, [string]$B)
  $versionA = [version]($A -replace '[^0-9\.].*$', '')
  $versionB = [version]($B -replace '[^0-9\.].*$', '')
  return $versionA -ge $versionB
}

function Ensure-Bun {
  $bun = Get-Command bun -ErrorAction SilentlyContinue
  if ($bun) {
    $version = (& $bun.Source --version).Trim()
    if (Version-Gte -A $version -B $BunMinVersion) {
      Write-Ok "bun: v$version"
      return
    }

    Write-Warn "bun v$version is too old. Upgrading..."
  } else {
    Write-Info 'Bun not found. Installing for source fallback...'
  }

  irm https://bun.sh/install.ps1 | iex
  $env:PATH = "$HOME\.bun\bin;$env:PATH"

  if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Fail 'Bun installation completed but bun is not on PATH.'
  }
}

function Install-FromSource {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail 'git is required for source fallback but was not found.'
  }

  Ensure-Bun

  if (Test-Path -LiteralPath (Join-Path $SourceDir '.git')) {
    Write-Info 'Updating existing source checkout...'
    try {
      git -C $SourceDir pull --ff-only origin main | Out-Host
    } catch {
      Write-Warn 'git pull failed, using existing source checkout.'
    }
  } else {
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    Write-Info 'Cloning source repository...'
    git clone --depth 1 "https://github.com/$Repo.git" $SourceDir | Out-Host
  }

  Push-Location $SourceDir
  try {
    Write-Info 'Building from source...'
    bun install --frozen-lockfile 2>$null
    if ($LASTEXITCODE -ne 0) {
      bun install | Out-Host
    }
    bun run build:dev:full | Out-Host
  } finally {
    Pop-Location
  }

  New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $SourceDir 'cli-dev.exe') -Destination (Join-Path $BinDir 'free-code.exe') -Force
  Set-Content -LiteralPath (Join-Path $BinDir 'free-code.cmd') -Value "@echo off`r`n""%~dp0\free-code.exe"" %*`r`n" -NoNewline
  Set-Content -LiteralPath (Join-Path $BinDir 'free-code.ps1') -Value '$exe = Join-Path $PSScriptRoot ''free-code.exe''; & $exe @args; exit $LASTEXITCODE' -NoNewline
  Write-Ok "Installed source-built binary to $BinDir\free-code.exe"
}

Write-Host ''
Write-Host 'free-code Windows installer' -ForegroundColor Cyan
Write-Host ''

if (-not (Install-FromRelease)) {
  Write-Warn 'Falling back to source build.'
  Install-FromSource
}

Ensure-UserPath

Write-Host ''
Write-Host 'Installation complete.' -ForegroundColor Green
Write-Host "Run: $BinDir\free-code.exe"
Write-Host 'Then set ANTHROPIC_API_KEY and launch free-code.'
