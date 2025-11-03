<#
.SYNOPSIS
  Builds release binaries and generates SHA256 checksums.

.DESCRIPTION
  Builds both Self-Contained and Framework-Dependent versions of MotWUnblocker,
  copies PowerShell scripts, and generates checksums for all release assets.

  Version 1.0.0
#>

[CmdletBinding()]
param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = 'Stop'

$ReleaseDir = Join-Path $PSScriptRoot "release"
$ChecksumFile = Join-Path $ReleaseDir "checksums.txt"

Write-Host "`nBuilding MotW Tools Release..." -ForegroundColor Cyan

if (Test-Path $ReleaseDir) {
    Write-Host "Cleaning existing release directory..." -ForegroundColor Yellow
    Remove-Item $ReleaseDir -Recurse -Force
}

New-Item -ItemType Directory -Path $ReleaseDir | Out-Null

Write-Host "`nBuilding binaries..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "MotWUnblocker")

dotnet msbuild -t:PublishBoth -p:Configuration=$Configuration -nologo

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "`nCopying release assets..." -ForegroundColor Cyan

$ScExe = "MotWUnblocker\bin\$Configuration\SelfContained\MotWUnblocker-sc.exe"
$FddExe = "MotWUnblocker\bin\$Configuration\FddSingle\MotWUnblocker-fdd.exe"

Set-Location $PSScriptRoot

Copy-Item $ScExe -Destination $ReleaseDir
Copy-Item $FddExe -Destination $ReleaseDir

Copy-Item "scripts\MotW.ps1" -Destination $ReleaseDir
Copy-Item "scripts\Install-MotWContext.ps1" -Destination $ReleaseDir
Copy-Item "scripts\Uninstall-MotWContext.ps1" -Destination $ReleaseDir

Write-Host "`nGenerating SHA256 checksums..." -ForegroundColor Cyan

$files = Get-ChildItem -Path $ReleaseDir -File | Where-Object { $_.Name -ne "checksums.txt" }

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

Write-Host "`nChecksum file: checksums.txt" -ForegroundColor Yellow
Write-Host "Ready to create GitHub release!" -ForegroundColor Green