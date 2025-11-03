<#
Removes:
  • SendTo shortcut
  • Classic context verbs
  • (Optionally) removes %USERPROFILE%\Tools\MotW from user PATH
  • Leaves MotW.ps1 by default (use -RemoveFiles to delete the folder)

Usage:
  .\Uninstall-MotWTools.ps1
  .\Uninstall-MotWTools.ps1 -KeepPath
  .\Uninstall-MotWTools.ps1 -RemoveFiles
#>

[CmdletBinding()]
param(
    [switch]$KeepPath,
    [switch]$RemoveFiles
)

$ErrorActionPreference = 'Stop'

$ToolRoot = Join-Path $env:USERPROFILE 'Tools\MotW'
$SendToDir = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo'
$SendToLnk = Join-Path $SendToDir 'MotW - Unblock.lnk'

# ──────────────────────────────────────────────────────────────────────────────
# Remove SendTo shortcut
# ──────────────────────────────────────────────────────────────────────────────
if (Test-Path $SendToLnk) {
    Remove-Item $SendToLnk -Force -ErrorAction SilentlyContinue
    Write-Host "Removed SendTo shortcut."
}

# ──────────────────────────────────────────────────────────────────────────────
# Remove from PATH (user) unless asked to keep
# ──────────────────────────────────────────────────────────────────────────────
if (-not $KeepPath) {
    $pathUser = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($pathUser) {
        $parts = $pathUser.Split(';') | Where-Object { $_ -and $_.Trim() -ne '' }
        $new = ($parts | Where-Object { $_ -ne $ToolRoot }) -join ';'
        if ($new -ne $pathUser) {
            [Environment]::SetEnvironmentVariable('Path', $new, 'User')
            Write-Host "Removed from user PATH: $ToolRoot"
        }
        else {
            Write-Host "User PATH did not contain: $ToolRoot"
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Optionally remove files
# ──────────────────────────────────────────────────────────────────────────────
if ($RemoveFiles -and (Test-Path $ToolRoot)) {
    try {
        Remove-Item $ToolRoot -Recurse -Force
        Write-Host "Removed $ToolRoot"
    }
    catch {
        Write-Warning "Could not remove ${ToolRoot}: $($_.Exception.Message)"
    }
}

Write-Host "✅ MotW tools uninstalled. Restart Terminal if PATH changed."
