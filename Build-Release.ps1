<#
.SYNOPSIS
  Builds release binaries and generates SHA256 checksums.

.DESCRIPTION
  Builds Framework-Dependent version of MotWUnblocker,
  copies PowerShell scripts, generates release notes and checksums.

  Version 1.0.0
#>

[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = 'Stop'

$ReleaseDir = Join-Path $PSScriptRoot "release"
$ChecksumFile = Join-Path $ReleaseDir "checksums.txt"
$ReleaseNotesFile = Join-Path $ReleaseDir "RELEASE-NOTES.md"

Write-Host "`nBuilding MotW Tools v$Version Release..." -ForegroundColor Cyan

if (Test-Path $ReleaseDir) {
    Write-Host "Cleaning existing release directory..." -ForegroundColor Yellow
    Remove-Item $ReleaseDir -Recurse -Force
}

New-Item -ItemType Directory -Path $ReleaseDir | Out-Null

Write-Host "`nBuilding FDD binary..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "MotWUnblocker")

dotnet publish -c $Configuration -p:PublishFlavor=FddSingle -nologo

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "`nCopying release assets..." -ForegroundColor Cyan

$FddExe = "MotWUnblocker\bin\$Configuration\FddSingle\MotWUnblocker-fdd.exe"

Set-Location $PSScriptRoot

Copy-Item $FddExe -Destination $ReleaseDir
Copy-Item "scripts\MotW.ps1" -Destination $ReleaseDir
Copy-Item "scripts\Install-MotWContext.ps1" -Destination $ReleaseDir
Copy-Item "scripts\Uninstall-MotWContext.ps1" -Destination $ReleaseDir

Write-Host "`nGenerating release notes..." -ForegroundColor Cyan

$releaseNotes = @"
# MotW Tools v$Version

Initial release of MotW Tools - a suite for managing Mark-of-the-Web metadata on Windows files.

## Downloads

**GUI Application**
- **MotWUnblocker-fdd.exe** (177 KB) - Requires [.NET 9 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/9.0)

**PowerShell Scripts**
- **MotW.ps1** - CLI tool for batch operations
- **Install-MotWContext.ps1** - One-click installer
- **Uninstall-MotWContext.ps1** - Clean uninstaller

**Verification**
- **checksums.txt** - SHA256 hashes for all downloads

## Features

**MotW Unblocker (GUI)**
- Batch file processing with drag-and-drop
- Real-time MotW status checking
- Keyboard shortcuts (Ctrl+A, Ctrl+U, Delete, F5, etc.)
- Comprehensive logging to %LOCALAPPDATA%\MotWUnblocker\unblocker.log
- No admin rights required

**MotW.ps1 (PowerShell)**
- Three actions: ``unblock``, ``add``, ``status``
- ``-WhatIf`` and ``-Confirm`` support for safe testing
- Recursive directory processing with ``-Recurse``
- Comprehensive logging to %LOCALAPPDATA%\MotW\motw.log
- Colored console output
- Success/failure counters

## Quick Start

**GUI**: Download ``MotWUnblocker-fdd.exe`` and run

**PowerShell**:
``````powershell
.\Install-MotWContext.ps1
MotW.ps1 *.pdf
``````

## Security

**Verify Downloads:**
``````powershell
# Windows PowerShell
Get-FileHash MotWUnblocker-fdd.exe -Algorithm SHA256
# Compare with checksums.txt
``````

## Documentation

See [README.md](https://github.com/sudo-grue/MotWTools/blob/main/README.md) for full documentation.

## System Requirements
- Windows 10 (21H2+) or Windows 11 x64
- .NET 9 Desktop Runtime - [Download here](https://dotnet.microsoft.com/download/dotnet/9.0)
"@

Set-Content -Path $ReleaseNotesFile -Value $releaseNotes -Encoding UTF8

Write-Host "`nGenerating SHA256 checksums..." -ForegroundColor Cyan

$files = Get-ChildItem -Path $ReleaseDir -File | Where-Object {
    $_.Name -ne "checksums.txt" -and $_.Name -ne "RELEASE-NOTES.md"
}

$checksums = @()
foreach ($file in $files) {
    $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
    $checksums += "$($hash.Hash.ToLower())  $($file.Name)"
    Write-Host "  $($file.Name): $($hash.Hash.ToLower())" -ForegroundColor Gray
}

Set-Content -Path $ChecksumFile -Value ($checksums -join "`n") -Encoding UTF8

Write-Host "`nRelease assets ready in: $ReleaseDir" -ForegroundColor Green
Write-Host "`nFiles included:" -ForegroundColor Cyan
Get-ChildItem -Path $ReleaseDir -File | ForEach-Object {
    $size = if ($_.Length -gt 1MB) {
        "{0:N2} MB" -f ($_.Length / 1MB)
    } else {
        "{0:N2} KB" -f ($_.Length / 1KB)
    }
    Write-Host "  $($_.Name) ($size)" -ForegroundColor White
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Review files in: $ReleaseDir"
Write-Host "  2. Commit and push code: git add . && git commit -m 'Release v$Version' && git push"
Write-Host "  3. Create GitHub release and upload all files from release/"
Write-Host "`nReady to create GitHub release!" -ForegroundColor Green
