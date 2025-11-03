<#
.SYNOPSIS
  Installs MotW CLI tools for managing Mark-of-the-Web metadata.

.DESCRIPTION
  Installs MotW.ps1 to %USERPROFILE%\Tools\MotW and optionally:
  - Adds to user PATH
  - Creates "Send To" context menu shortcut
  - Sets execution policy to RemoteSigned

  Version 1.0.0

.PARAMETER NoSendTo
  Skip creating the "Send To" shortcut

.PARAMETER NoPath
  Skip adding to user PATH

.PARAMETER SetExecutionPolicy
  Whether to set execution policy to RemoteSigned (default: $true)

.EXAMPLE
  .\Install-MotWContext.ps1
  Standard installation with all features

.EXAMPLE
  .\Install-MotWContext.ps1 -NoSendTo -NoPath
  Minimal installation without PATH or SendTo integration
#>

[CmdletBinding()]
param(
    [switch]$NoSendTo,
    [switch]$NoPath,
    [bool]$SetExecutionPolicy = $true
)

$Script:Version = "1.0.0"
$ErrorActionPreference = 'Stop'

$ToolRoot = Join-Path $env:USERPROFILE 'Tools\MotW'
$ScriptPath = Join-Path $ToolRoot 'MotW.ps1'
$LogPath = Join-Path $env:LOCALAPPDATA "MotW\install.log"
$LogDir = Split-Path $LogPath -Parent
$SendToDir = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo'
$SendToLnk = Join-Path $SendToDir 'MotW - Unblock.lnk'

function Write-InstallLog {
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

Write-InstallLog -Level "INFO" -Message "MotW Installer v$Script:Version started"

try {
    New-Item -ItemType Directory -Force -Path $ToolRoot | Out-Null
    Write-InstallLog -Level "INFO" -Message "Created installation directory: $ToolRoot"
}
catch {
    Write-InstallLog -Level "ERROR" -Message "Failed to create installation directory: $_"
    throw
}

$motwScriptContent = $null

if (Test-Path ".\MotW.ps1" -PathType Leaf) {
    Write-InstallLog -Level "INFO" -Message "Using local MotW.ps1 from current directory"
    try {
        $motwScriptContent = Get-Content ".\MotW.ps1" -Raw -ErrorAction Stop
    }
    catch {
        Write-InstallLog -Level "WARN" -Message "Failed to read local MotW.ps1, falling back to embedded version: $_"
    }
}

if (-not $motwScriptContent) {
    Write-InstallLog -Level "INFO" -Message "Using embedded MotW.ps1 v$Script:Version"
    $motwScriptContent = @'
<#
.SYNOPSIS
  View/Add/Remove Mark-of-the-Web (Zone.Identifier) on files.

.DESCRIPTION
  Manages the NTFS Zone.Identifier alternate data stream that marks files
  as downloaded from the Internet. Version 1.0.0

.USAGE
  MotW.ps1 *.pdf                 # Unblock (default)
  MotW.ps1 unblock *.pdf
  MotW.ps1 add *.pdf
  MotW.ps1 status .
  MotW.ps1 unblock . -Recurse
  MotW.ps1 add *.exe -WhatIf     # Preview changes
#>

[CmdletBinding(PositionalBinding = $false, SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('unblock', 'add', 'status')]
    [string]$Action = 'unblock',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsRest,

    [switch]$Recurse
)

$Script:Version = "1.0.0"
$Script:LogPath = Join-Path $env:LOCALAPPDATA "MotW\motw.log"
$Script:LogDir = Split-Path $Script:LogPath -Parent

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Level,
        [Parameter(Mandatory)][string]$Message
    )

    try {
        if (-not (Test-Path $Script:LogDir)) {
            New-Item -Path $Script:LogDir -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
        $sanitizedMessage = $Message -replace "`r", '\r' -replace "`n", '\n' -replace "`t", '\t'
        $logLine = "$timestamp [$Level] $sanitizedMessage"

        Add-Content -Path $Script:LogPath -Value $logLine -ErrorAction SilentlyContinue
    }
    catch {
        Write-Debug "Logging failed: $_"
    }
}

function Write-LogInfo { param([string]$Message) Write-Log -Level "INFO" -Message $Message }
function Write-LogWarn { param([string]$Message) Write-Log -Level "WARN" -Message $Message }
function Write-LogError { param([string]$Message) Write-Log -Level "ERROR" -Message $Message }

$validActions = @('unblock', 'add', 'status')
[string[]]$Paths = @()

if ($ArgsRest -and $ArgsRest.Count -gt 0) {
    if ($ArgsRest[0] -in $validActions) {
        $Action = $ArgsRest[0]
        if ($ArgsRest.Count -gt 1) { $Paths = $ArgsRest[1..($ArgsRest.Count - 1)] }
    }
    else {
        $Paths = $ArgsRest
    }
}
else {
    Write-Error "No paths provided. Example: MotW.ps1 *.pdf  or  MotW.ps1 unblock . -Recurse"
    Write-LogError "No paths provided by user"
    return
}

Write-LogInfo "MotW.ps1 v$Script:Version started - Action: $Action, Paths: $($Paths -join ', '), Recurse: $Recurse"

function Resolve-Targets {
    param(
        [string[]]$InputPaths,
        [switch]$Recurse
    )

    $targetSet = @{}

    if (-not $InputPaths -or $InputPaths.Count -eq 0) {
        Write-Error "No paths provided"
        Write-LogError "Resolve-Targets called with no paths"
        return @()
    }

    foreach ($p in $InputPaths) {
        $resolved = @()

        if (Test-Path -LiteralPath $p -ErrorAction SilentlyContinue) {
            $resolved = @((Resolve-Path -LiteralPath $p).Path)
        }
        else {
            try {
                $resolved = @(Get-ChildItem -Path $p -File -ErrorAction Stop | ForEach-Object { $_.FullName })
            }
            catch {
                Write-Warning "Could not resolve path: $p"
                Write-LogWarn "Path resolution failed: $p - $_"
                continue
            }
        }

        foreach ($r in $resolved) {
            if (Test-Path $r -PathType Container) {
                if ($Recurse) {
                    $childItems = Get-ChildItem -LiteralPath $r -Recurse -File -Force -ErrorAction SilentlyContinue
                }
                else {
                    $childItems = Get-ChildItem -LiteralPath $r -File -Force -ErrorAction SilentlyContinue
                }

                foreach ($item in $childItems) {
                    $targetSet[$item.FullName] = $true
                }
            }
            else {
                $targetSet[$r] = $true
            }
        }
    }

    $targets = @($targetSet.Keys | Sort-Object)
    Write-LogInfo "Resolved $($targets.Count) file(s)"
    return $targets
}

function Test-HasMotW {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $null = Get-Item -LiteralPath $Path -Stream Zone.Identifier -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

$files = Resolve-Targets -InputPaths $Paths -Recurse:$Recurse
if (-not $files -or $files.Count -eq 0) {
    Write-LogWarn "No files found to process"
    return
}

$successCount = 0
$failCount = 0

switch ($Action) {
    'unblock' {
        foreach ($f in $files) {
            if ($PSCmdlet.ShouldProcess($f, "Remove Mark-of-the-Web")) {
                try {
                    if (Test-Path -LiteralPath $f) {
                        Remove-Item -LiteralPath $f -Stream Zone.Identifier -ErrorAction SilentlyContinue
                        Write-Host "Unblocked: $f" -ForegroundColor Green
                        Write-LogInfo "Unblocked: $f"
                        $successCount++
                    }
                    else {
                        Write-Warning "File not found: $f"
                        Write-LogWarn "File not found: $f"
                        $failCount++
                    }
                }
                catch {
                    Write-Warning "Failed to unblock: $f - $($_.Exception.Message)"
                    Write-LogError "Unblock failed: $f - $($_.Exception.Message)"
                    $failCount++
                }
            }
        }
    }

    'add' {
        foreach ($f in $files) {
            if ($PSCmdlet.ShouldProcess($f, "Add Mark-of-the-Web")) {
                try {
                    if (Test-Path -LiteralPath $f) {
                        Set-Content -LiteralPath $f -Stream Zone.Identifier -Value "[ZoneTransfer]`nZoneId=3`nHostUrl=about:internet" -Force
                        Write-Host "Marked (MotW added): $f" -ForegroundColor Yellow
                        Write-LogInfo "Added MotW: $f"
                        $successCount++
                    }
                    else {
                        Write-Warning "File not found: $f"
                        Write-LogWarn "File not found: $f"
                        $failCount++
                    }
                }
                catch {
                    Write-Warning "Failed to add MotW: $f - $($_.Exception.Message)"
                    Write-LogError "Add MotW failed: $f - $($_.Exception.Message)"
                    $failCount++
                }
            }
        }
    }

    'status' {
        foreach ($f in $files) {
            try {
                if (Test-Path -LiteralPath $f) {
                    $has = Test-HasMotW -Path $f
                    if ($has) {
                        Write-Host "[MotW]  $f" -ForegroundColor Red
                    }
                    else {
                        Write-Host "[clean] $f" -ForegroundColor Gray
                    }
                    $successCount++
                }
                else {
                    Write-Warning "File not found: $f"
                    Write-LogWarn "File not found: $f"
                    $failCount++
                }
            }
            catch {
                Write-Warning "Failed to read status: $f - $($_.Exception.Message)"
                Write-LogError "Status check failed: $f - $($_.Exception.Message)"
                $failCount++
            }
        }
    }
}

$summary = "Complete - Success: $successCount, Failed: $failCount"
Write-Verbose $summary
Write-LogInfo $summary
'@
}

try {
    Set-Content -Path $ScriptPath -Value $motwScriptContent -Encoding UTF8 -Force
    Write-InstallLog -Level "INFO" -Message "Installed MotW.ps1 to: $ScriptPath"
}
catch {
    Write-InstallLog -Level "ERROR" -Message "Failed to write MotW.ps1: $_"
    throw
}

if ($SetExecutionPolicy) {
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
        Write-InstallLog -Level "INFO" -Message "Set execution policy to RemoteSigned for CurrentUser"
    }
    catch {
        Write-InstallLog -Level "WARN" -Message "Could not set execution policy: $_"
    }
}

if (-not $NoPath) {
    try {
        $pathUser = [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not $pathUser) { $pathUser = '' }

        $pathEntries = $pathUser.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
        $alreadyInPath = $pathEntries | Where-Object { $_.Trim() -eq $ToolRoot }

        if (-not $alreadyInPath) {
            $newPath = ($pathUser.TrimEnd(';') + ';' + $ToolRoot).TrimStart(';')
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
            Write-InstallLog -Level "INFO" -Message "Added to user PATH: $ToolRoot"
            Write-Host "  NOTE: Restart your terminal to use 'MotW.ps1' from anywhere" -ForegroundColor Cyan
        }
        else {
            Write-InstallLog -Level "INFO" -Message "User PATH already contains: $ToolRoot"
        }
    }
    catch {
        Write-InstallLog -Level "ERROR" -Message "Failed to modify PATH: $_"
        throw
    }
}

if (-not $NoSendTo) {
    try {
        New-Item -ItemType Directory -Force -Path $SendToDir -ErrorAction Stop | Out-Null

        $ws = New-Object -ComObject WScript.Shell
        $sc = $ws.CreateShortcut($SendToLnk)
        $sc.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $sc.Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" unblock `"%1`""
        $sc.IconLocation = "shell32.dll,77"
        $sc.Save()

        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($ws) | Out-Null

        Write-InstallLog -Level "INFO" -Message "Created SendTo shortcut: $SendToLnk"
    }
    catch {
        Write-InstallLog -Level "WARN" -Message "Failed to create SendTo shortcut: $_"
    }
}

Write-InstallLog -Level "INFO" -Message "Installation complete"
Write-Host "`nInstallation Summary:" -ForegroundColor Cyan
Write-Host "  Script:   $ScriptPath"
Write-Host "  Log:      $LogPath"
if (-not $NoPath) { Write-Host "  PATH:     Added" }
if (-not $NoSendTo) { Write-Host "  SendTo:   Created" }
