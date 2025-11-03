<#
.SYNOPSIS
  Uninstalls MotW CLI tools and related integrations.

.DESCRIPTION
  Removes MotW context menu shortcuts, optionally removes from user PATH,
  and optionally deletes the installation directory.

  Version 1.0.0

.PARAMETER KeepPath
  Do not remove MotW from user PATH

.PARAMETER RemoveFiles
  Delete the installation directory (%USERPROFILE%\Tools\MotW)

.EXAMPLE
  .\Uninstall-MotWContext.ps1
  Standard uninstallation - removes shortcuts and PATH entry

.EXAMPLE
  .\Uninstall-MotWContext.ps1 -KeepPath
  Remove shortcuts only, keep PATH entry

.EXAMPLE
  .\Uninstall-MotWContext.ps1 -RemoveFiles
  Complete removal including installation directory
#>

[CmdletBinding()]
param(
    [switch]$KeepPath,
    [switch]$RemoveFiles
)

$Script:Version = "1.0.0"
$ErrorActionPreference = 'Stop'

$ToolRoot = Join-Path $env:USERPROFILE 'Tools\MotW'
$SendToDir = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo'
$SendToLnk = Join-Path $SendToDir 'MotW - Unblock.lnk'
$LogPath = Join-Path $env:LOCALAPPDATA "MotW\uninstall.log"
$LogDir = Split-Path $LogPath -Parent

function Write-UninstallLog {
    param(
        [Parameter(Mandatory)][string]$Level,
        [Parameter(Mandatory)][string]$Message
    )

    try {
        if (-not (Test-Path $LogDir)) {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
        $logLine = "$timestamp [$Level] $Message"
        Add-Content -Path $LogPath -Value $logLine -ErrorAction SilentlyContinue

        switch ($Level) {
            "INFO" { Write-Host $Message -ForegroundColor Green }
            "WARN" { Write-Warning $Message }
            "ERROR" { Write-Error $Message }
        }
    }
    catch {
        Write-Debug "Logging failed: $_"
    }
}

Write-UninstallLog -Level "INFO" -Message "MotW Uninstaller v$Script:Version started"

if ($RemoveFiles) {
    if (Test-Path $ToolRoot) {
        try {
            Remove-Item $ToolRoot -Recurse -Force -ErrorAction Stop
            Write-UninstallLog -Level "INFO" -Message "Removed installation directory: $ToolRoot"
        }
        catch {
            Write-UninstallLog -Level "ERROR" -Message "Failed to remove installation directory: $_"
            Write-UninstallLog -Level "WARN" -Message "You may need to manually delete: $ToolRoot"
        }
    }
    else {
        Write-UninstallLog -Level "INFO" -Message "Installation directory not found: $ToolRoot"
    }
}
else {
    Write-UninstallLog -Level "INFO" -Message "Keeping installation directory (use -RemoveFiles to delete)"
}

if (Test-Path $SendToLnk) {
    try {
        Remove-Item $SendToLnk -Force -ErrorAction Stop
        Write-UninstallLog -Level "INFO" -Message "Removed SendTo shortcut: $SendToLnk"
    }
    catch {
        Write-UninstallLog -Level "WARN" -Message "Failed to remove SendTo shortcut: $_"
    }
}
else {
    Write-UninstallLog -Level "INFO" -Message "SendTo shortcut not found"
}

if (-not $KeepPath) {
    try {
        $pathUser = [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not $pathUser) { $pathUser = '' }

        $pathEntries = $pathUser.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
        $wasInPath = $pathEntries | Where-Object { $_.Trim() -eq $ToolRoot }

        if ($wasInPath) {
            $newPath = ($pathEntries | Where-Object { $_.Trim() -ne $ToolRoot }) -join ';'
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
            Write-UninstallLog -Level "INFO" -Message "Removed from user PATH: $ToolRoot"
            Write-Host "  NOTE: Restart your terminal for PATH changes to take effect" -ForegroundColor Cyan
        }
        else {
            Write-UninstallLog -Level "INFO" -Message "User PATH did not contain: $ToolRoot"
        }
    }
    catch {
        Write-UninstallLog -Level "ERROR" -Message "Failed to modify PATH: $_"
    }
}
else {
    Write-UninstallLog -Level "INFO" -Message "Keeping PATH entry (use without -KeepPath to remove)"
}

Write-UninstallLog -Level "INFO" -Message "Uninstallation complete"
Write-Host "`nUninstallation Summary:" -ForegroundColor Cyan
Write-Host "  Log:      $LogPath"
if (-not $KeepPath) { Write-Host "  PATH:     Removed" }
if ($RemoveFiles) { Write-Host "  Files:    Deleted" }
