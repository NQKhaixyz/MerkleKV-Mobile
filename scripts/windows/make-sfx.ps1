<#!
.SYNOPSIS
  Build Flutter Windows release and package as a single self-extracting EXE (SFX) using 7-Zip.

.DESCRIPTION
  This script builds the Flutter Windows app (apps/flutter_demo) and bundles the full Release folder
  into a single .exe using the 7-Zip SFX stub (7zS.sfx). When the .exe runs, it extracts to a temp
  directory and auto-launches flutter_demo.exe. This is the most practical way to ship a "one file" app
  for Flutter on Windows.

.PARAMETER AppDir
  Path to the Flutter app directory. Default: <repo>/apps/flutter_demo

.PARAMETER Output
  Output EXE path. Default: <repo>/apps/flutter_demo/releases/MerkleKV-Mobile.exe

.PARAMETER SevenZipSfx
  Path to 7zS.sfx. Default: tries common install paths under Program Files. You can override explicitly.

.EXAMPLE
  # From repo root (PowerShell)
  ./scripts/windows/make-sfx.ps1

.EXAMPLE
  # Custom output
  ./scripts/windows/make-sfx.ps1 -Output C:\dist\MerkleKV-Mobile.exe
#>

[CmdletBinding()]
param(
  [string]$AppDir,
  [string]$Output,
  [string]$SevenZipSfx
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  # scripts/windows -> repo root is two levels up
  return (Resolve-Path (Join-Path $scriptDir '..' '..')).Path
}

function Ensure-ToolExists($name) {
  $tool = (Get-Command $name -ErrorAction SilentlyContinue)
  if (-not $tool) {
    throw "Required tool not found in PATH: $name"
  }
}

function Find-7zSfx {
  param([string]$override)
  if ($override -and (Test-Path $override)) { return (Resolve-Path $override).Path }
  $candidates = @(
    "$env:ProgramFiles\7-Zip\7zS.sfx",
    "$env:ProgramFiles(x86)\7-Zip\7zS.sfx",
    "$env:ProgramFiles\7-Zip\7z.sfx",
    "$env:ProgramFiles(x86)\7-Zip\7z.sfx"
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { return (Resolve-Path $c).Path }
  }
  throw "7z SFX stub not found. Install 7-Zip or pass -SevenZipSfx with the full path (e.g., C:\\Program Files\\7-Zip\\7zS.sfx or 7z.sfx)."
}

function New-TempWorkDir {
  $dir = Join-Path $env:TEMP ("merklekv_sfx_" + [System.Guid]::NewGuid().ToString('N'))
  return (New-Item -ItemType Directory -Force -Path $dir).FullName
}

# 1) Resolve paths
$repoRoot = Resolve-RepoRoot
if (-not $AppDir) { $AppDir = Join-Path $repoRoot 'apps/flutter_demo' }
if (-not $Output) { $Output = Join-Path $repoRoot 'apps/flutter_demo/releases/MerkleKV-Mobile.exe' }

Write-Host "RepoRoot:   $repoRoot"
Write-Host "AppDir:     $AppDir"
Write-Host "Output:     $Output"

if (-not (Test-Path $AppDir)) { throw "AppDir not found: $AppDir" }

# 2) Ensure required tools
Ensure-ToolExists 'flutter'
Ensure-ToolExists '7z'
$sfxPath = Find-7zSfx -override $SevenZipSfx
Write-Host "Using SFX stub: $sfxPath"

# 3) Build Flutter Windows release
Push-Location $AppDir
try {
  Write-Host 'Enabling Windows desktop...'
  flutter config --enable-windows-desktop | Out-Null
  Write-Host 'Resolving packages...'
  flutter pub get
  Write-Host 'Building Windows release... (this may take a while)'
  flutter build windows --release
}
finally {
  Pop-Location
}

# 4) Locate Release folder and verify binary name (auto-detect arch/layout)
$exeName = 'flutter_demo.exe' # from windows/CMakeLists.txt -> set(BINARY_NAME "flutter_demo")

$buildWindowsDir = Join-Path $AppDir 'build/windows'
if (-not (Test-Path $buildWindowsDir)) {
  throw "Build did not produce 'build/windows' directory."
}

$releaseDir = $null
$candidateDirs = @()
$candidateDirs += (Join-Path $AppDir 'build/windows/x64/runner/Release')
$candidateDirs += (Join-Path $AppDir 'build/windows/arm64/runner/Release')
$candidateDirs += (Join-Path $AppDir 'build/windows/runner/Release')

foreach ($c in $candidateDirs) { if (Test-Path $c) { $releaseDir = $c; break } }

if (-not $releaseDir) {
  # Fallback: scan for any runner/Release
  $found = Get-ChildItem -Path $buildWindowsDir -Directory -Recurse |
    Where-Object { $_.FullName -match "\\runner\\Release$" } |
    Select-Object -First 1
  if ($found) { $releaseDir = $found.FullName }
}

if (-not $releaseDir) {
  throw "Release folder not found under $buildWindowsDir. Check build output or architecture."
}

$exePath = Join-Path $releaseDir $exeName
if (-not (Test-Path $exePath)) {
  throw "Expected executable not found: $exePath"
}

Write-Host "Packaging from: $releaseDir"

# 5) Create payload archive
$work = New-TempWorkDir
$payload = Join-Path $work 'payload.7z'
$config  = Join-Path $work 'config.txt'

Write-Host 'Creating 7z payload...'
# -mx=9 max compression; quoting to ensure glob expansion by 7z
& 7z a '-mx=9' $payload (Join-Path $releaseDir '*') | Out-Null

Write-Host 'Generating SFX config...'
@"
;!@Install@!UTF-8!
Title="MerkleKV Mobile"
ExtractTitle="MerkleKV Mobile"
RunProgram="flutter_demo.exe"
;!@InstallEnd@!
"@ | Out-File -Encoding ASCII -NoNewline $config

# 6) Concatenate SFX stub + config + payload => single EXE
$outDir = Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host 'Building SFX executable...'
$copyCmd = "`"$sfxPath`"+`"$config`"+`"$payload`""
cmd /c copy /b $copyCmd "`"$Output`"" > $null

Write-Host "Created single-file EXE: $Output"

Write-Host 'Done.'
