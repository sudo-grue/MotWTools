<#
.SYNOPSIS
  Installs MotW CLI tools for managing Mark-of-the-Web metadata.

.DESCRIPTION
  Installs MotW.ps1 to %USERPROFILE%\Tools\MotW and optionally:
  - Adds to user PATH
  - Creates "Send To" context menu shortcut (with interactive zone selection)
  - Sets execution policy to RemoteSigned
  - Detects environment capabilities (SendTo, Context Menu, .NET Runtime)

  Version 1.1.0

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
    [bool]$SetExecutionPolicy = $true,
    [switch]$NonInteractive
)

$Script:Version = "1.1.0"
$ErrorActionPreference = 'Stop'

$ToolRoot = Join-Path $env:USERPROFILE 'Tools\MotW'
$ScriptPath = Join-Path $ToolRoot 'MotW.ps1'
$SendToScriptPath = Join-Path $ToolRoot 'MotW-SendTo.ps1'
$LogPath = Join-Path $env:LOCALAPPDATA "MotW\install.log"
$LogDir = Split-Path $LogPath -Parent
$SendToDir = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo'
$SendToLnk = Join-Path $SendToDir 'MotW - Reassign.lnk'

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

# Environment detection functions
function Test-SendToAvailable {
    try {
        if (-not (Test-Path $SendToDir)) {
            New-Item -ItemType Directory -Force -Path $SendToDir -ErrorAction Stop | Out-Null
        }

        $testFile = Join-Path $SendToDir ".motw-test-$(Get-Random)"
        Set-Content -Path $testFile -Value "test" -ErrorAction Stop
        Remove-Item -Path $testFile -ErrorAction SilentlyContinue

        return $true
    }
    catch {
        return $false
    }
}

function Test-ContextMenuAvailable {
    try {
        $testKey = "HKCU:\Software\Classes\.motw-test-$(Get-Random)"
        New-Item -Path $testKey -Force -ErrorAction Stop | Out-Null
        Remove-Item -Path $testKey -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        return $false
    }
}

function Test-DotNetRuntime {
    param([string]$MinVersion = "9.0")

    try {
        $dotnetOutput = & dotnet --list-runtimes 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        $hasRuntime = $dotnetOutput | Where-Object {
            $_ -match "Microsoft\.WindowsDesktop\.App\s+(\d+\.\d+)" -and
            [Version]$matches[1] -ge [Version]$MinVersion
        }

        return $null -ne $hasRuntime
    }
    catch {
        return $false
    }
}

function Show-EnvironmentDetection {
    Write-Host "`nEnvironment Detection:" -ForegroundColor Cyan

    $sendToAvailable = Test-SendToAvailable
    $contextMenuAvailable = Test-ContextMenuAvailable
    $dotNetAvailable = Test-DotNetRuntime -MinVersion "9.0"

    $sendToStatus = if ($sendToAvailable) { "Available" } else { "Restricted" }
    $sendToColor = if ($sendToAvailable) { "Green" } else { "Yellow" }
    Write-Host ("  Send To Menu:        {0,-12}" -f $sendToStatus) -ForegroundColor $sendToColor

    $contextStatus = if ($contextMenuAvailable) { "Available" } else { "Restricted" }
    $contextColor = if ($contextMenuAvailable) { "Green" } else { "Yellow" }
    Write-Host ("  Context Menu:        {0,-12}" -f $contextStatus) -ForegroundColor $contextColor

    $dotNetStatus = if ($dotNetAvailable) { ".NET 9+ Found" } else { "Not Found" }
    $dotNetColor = if ($dotNetAvailable) { "Green" } else { "Yellow" }
    Write-Host ("  .NET Runtime:        {0,-12}" -f $dotNetStatus) -ForegroundColor $dotNetColor

    Write-Host ""

    return @{
        SendToAvailable      = $sendToAvailable
        ContextMenuAvailable = $contextMenuAvailable
        DotNetAvailable      = $dotNetAvailable
    }
}

Write-InstallLog -Level "INFO" -Message "MotW Installer v$Script:Version started"

# Show environment detection
$envCapabilities = Show-EnvironmentDetection
Write-InstallLog -Level "INFO" -Message "Environment - SendTo: $($envCapabilities.SendToAvailable), Context: $($envCapabilities.ContextMenuAvailable), .NET: $($envCapabilities.DotNetAvailable)"

# Interactive component selection (if not in non-interactive mode and no explicit flags)
if (-not $NonInteractive -and -not $PSBoundParameters.ContainsKey('NoSendTo') -and -not $PSBoundParameters.ContainsKey('NoPath')) {
    Write-Host "Installation Options:" -ForegroundColor Cyan
    Write-Host "  [1] Full Installation (recommended)" -ForegroundColor Green
    Write-Host "      - PowerShell scripts to %USERPROFILE%\Tools\MotW"
    Write-Host "      - Add to PATH for global access"
    if ($envCapabilities.SendToAvailable) {
        Write-Host "      - 'Send To' menu integration with interactive prompt" -ForegroundColor Green
    }
    else {
        Write-Host "      - 'Send To' menu integration (unavailable - restricted)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  [2] Scripts + PATH (no Send To integration)"
    Write-Host "  [3] Scripts Only (minimal - no PATH or Send To)"
    Write-Host "  [C] Cancel installation"
    Write-Host ""

    $choice = Read-Host "Your choice [1/2/3/C]"

    switch ($choice.ToUpper()) {
        '1' {
            Write-InstallLog -Level "INFO" -Message "User selected: Full Installation"
            # NoSendTo and NoPath remain $false (default)
        }
        '2' {
            Write-InstallLog -Level "INFO" -Message "User selected: Scripts + PATH"
            $NoSendTo = $true
        }
        '3' {
            Write-InstallLog -Level "INFO" -Message "User selected: Scripts Only"
            $NoSendTo = $true
            $NoPath = $true
        }
        'C' {
            Write-Host "`nInstallation cancelled by user." -ForegroundColor Yellow
            Write-InstallLog -Level "INFO" -Message "Installation cancelled by user"
            return
        }
        default {
            Write-Host "`nInvalid choice. Installation cancelled." -ForegroundColor Red
            Write-InstallLog -Level "WARN" -Message "Installation cancelled - invalid choice: $choice"
            return
        }
    }
    Write-Host ""
}

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
  View/Add/Reassign/Remove Mark-of-the-Web (Zone.Identifier) on files.

.DESCRIPTION
  Manages the NTFS Zone.Identifier alternate data stream that marks files
  as downloaded from the Internet or other security zones. Version 1.1.0

  RECOMMENDED: Use 'reassign' instead of 'unblock' to move files between zones
  rather than removing MotW entirely. This is the preferred approach for
  handling files from improperly configured IT policies.

.USAGE
  MotW.ps1 reassign *.pdf               # Progressive (zone 3→2, 2→1, 1→0, 0→remove)
  MotW.ps1 reassign *.pdf -TargetZone 2 # Direct reassign to Trusted Sites
  MotW.ps1 reassign . -Recurse          # Progressive wash recursively
  MotW.ps1 reassign *.exe -WhatIf       # Preview changes
  MotW.ps1 add *.pdf                    # Add MotW (Zone 3 - Internet)
  MotW.ps1 status .                     # Check MotW status
  MotW.ps1 unblock *.pdf                # Remove MotW entirely
#>

[CmdletBinding(PositionalBinding = $false, SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('reassign', 'unblock', 'add', 'status')]
    [string]$Action = 'reassign',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsRest,

    [ValidateRange(0, 4)]
    [int]$TargetZone = -1,

    [switch]$Recurse
)

$Script:Version = "1.1.0"
$Script:LogPath = Join-Path $env:LOCALAPPDATA "MotW\motw.log"
$Script:LogDir = Split-Path $Script:LogPath -Parent

# RFC 5424 (Syslog Protocol) standard logging levels
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('EMERG', 'ALERT', 'CRIT', 'ERROR', 'WARN', 'NOTICE', 'INFO', 'DEBUG')]
        [string]$Level,
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

# RFC 5424 standard logging functions
function Write-LogEmergency { param([string]$Message) Write-Log -Level "EMERG" -Message $Message }
function Write-LogAlert { param([string]$Message) Write-Log -Level "ALERT" -Message $Message }
function Write-LogCritical { param([string]$Message) Write-Log -Level "CRIT" -Message $Message }
function Write-LogError { param([string]$Message) Write-Log -Level "ERROR" -Message $Message }
function Write-LogWarning { param([string]$Message) Write-Log -Level "WARN" -Message $Message }
function Write-LogNotice { param([string]$Message) Write-Log -Level "NOTICE" -Message $Message }
function Write-LogInfo { param([string]$Message) Write-Log -Level "INFO" -Message $Message }
function Write-LogDebug { param([string]$Message) Write-Log -Level "DEBUG" -Message $Message }

# Backwards compatibility alias
function Write-LogWarn { param([string]$Message) Write-LogWarning -Message $Message }

$validActions = @('reassign', 'unblock', 'add', 'status')
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
    Write-Error "No paths provided. Example: MotW.ps1 reassign *.pdf  or  MotW.ps1 status . -Recurse"
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

function Get-ZoneId {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-HasMotW -Path $Path)) {
        return $null
    }

    try {
        $content = Get-Content -LiteralPath $Path -Stream Zone.Identifier -ErrorAction Stop
        foreach ($line in $content) {
            if ($line -match '^ZoneId=(\d+)') {
                return [int]$matches[1]
            }
        }
    }
    catch {
        Write-LogError "Failed to read ZoneId from $Path : $_"
    }

    return $null
}

function Set-ZoneId {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][int]$ZoneId
    )

    if ($ZoneId -lt 0 -or $ZoneId -gt 4) {
        Write-LogError "Invalid ZoneId: $ZoneId. Must be 0-4."
        return $false
    }

    try {
        $content = "[ZoneTransfer]`nZoneId=$ZoneId`nHostUrl=about:internet"
        Set-Content -LiteralPath $Path -Stream Zone.Identifier -Value $content -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-LogError "Failed to set ZoneId on $Path : $_"
        return $false
    }
}

function Get-ZoneName {
    param([int]$ZoneId)

    switch ($ZoneId) {
        0 { return "Local Machine" }
        1 { return "Local Intranet" }
        2 { return "Trusted Sites" }
        3 { return "Internet" }
        4 { return "Restricted Sites" }
        default { return "Unknown" }
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

    'reassign' {
        foreach ($f in $files) {
            if ($PSCmdlet.ShouldProcess($f, "Reassign zone")) {
                try {
                    if (-not (Test-Path -LiteralPath $f)) {
                        Write-Warning "File not found: $f"
                        Write-LogWarn "File not found: $f"
                        $failCount++
                        continue
                    }

                    $currentZone = Get-ZoneId -Path $f

                    if ($null -eq $currentZone) {
                        Write-Host "[Already Clean] $f" -ForegroundColor Gray
                        Write-LogInfo "File already clean: $f"
                        $successCount++
                        continue
                    }

                    # Determine target zone
                    if ($TargetZone -ge 0) {
                        # Direct reassignment to specified zone
                        $newZone = $TargetZone
                    }
                    else {
                        # Progressive mode: move down one zone level
                        $newZone = $currentZone - 1
                    }

                    # If new zone would be < 0, remove MotW entirely
                    if ($newZone -lt 0) {
                        Remove-Item -LiteralPath $f -Stream Zone.Identifier -ErrorAction Stop
                        Write-Host "Removed MotW (was Zone $currentZone): $f" -ForegroundColor Green
                        Write-LogInfo "Removed MotW from Zone $currentZone : $f"
                        $successCount++
                    }
                    else {
                        # Reassign to new zone
                        if (Set-ZoneId -Path $f -ZoneId $newZone) {
                            $currentZoneName = Get-ZoneName -ZoneId $currentZone
                            $newZoneName = Get-ZoneName -ZoneId $newZone
                            Write-Host "Reassigned Zone $currentZone → Zone $newZone ($newZoneName): $f" -ForegroundColor Cyan
                            Write-LogInfo "Reassigned Zone $currentZone → Zone $newZone : $f"
                            $successCount++
                        }
                        else {
                            Write-Warning "Failed to reassign: $f"
                            Write-LogError "Reassignment failed: $f"
                            $failCount++
                        }
                    }
                }
                catch {
                    Write-Warning "Failed to reassign: $f - $($_.Exception.Message)"
                    Write-LogError "Reassign failed: $f - $($_.Exception.Message)"
                    $failCount++
                }
            }
        }
    }

    'status' {
        foreach ($f in $files) {
            try {
                if (Test-Path -LiteralPath $f) {
                    $zoneId = Get-ZoneId -Path $f
                    if ($null -ne $zoneId) {
                        $zoneName = Get-ZoneName -ZoneId $zoneId
                        $color = switch ($zoneId) {
                            0 { 'Cyan' }
                            1 { 'Green' }
                            2 { 'Yellow' }
                            3 { 'Red' }
                            4 { 'Magenta' }
                            default { 'White' }
                        }
                        Write-Host "[Zone $zoneId - $zoneName] $f" -ForegroundColor $color
                    }
                    else {
                        Write-Host "[Clean] $f" -ForegroundColor Gray
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

# Copy MotW-SendTo.ps1 if it exists
if (Test-Path ".\MotW-SendTo.ps1" -PathType Leaf) {
    try {
        Copy-Item ".\MotW-SendTo.ps1" -Destination $SendToScriptPath -Force
        Write-InstallLog -Level "INFO" -Message "Installed MotW-SendTo.ps1 to: $SendToScriptPath"
    }
    catch {
        Write-InstallLog -Level "WARN" -Message "Failed to copy MotW-SendTo.ps1: $_"
    }
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
    if (-not $envCapabilities.SendToAvailable) {
        Write-InstallLog -Level "WARN" -Message "Send To folder is restricted in this environment - skipping shortcut creation"
        Write-Host "  Send To integration skipped (restricted environment)" -ForegroundColor Yellow
    }
    else {
        try {
            New-Item -ItemType Directory -Force -Path $SendToDir -ErrorAction Stop | Out-Null

            # Use MotW-SendTo.ps1 if available, otherwise fall back to direct MotW.ps1 call
            $sendToTarget = if (Test-Path $SendToScriptPath) { $SendToScriptPath } else { $ScriptPath }
            $sendToArgs = if (Test-Path $SendToScriptPath) {
                # Interactive wrapper - keep window visible
                "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$SendToScriptPath`" `"%1`""
            }
            else {
                # Fallback to direct reassign call
                "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" reassign `"%1`" -TargetZone 2"
            }

            $ws = New-Object -ComObject WScript.Shell
            $sc = $ws.CreateShortcut($SendToLnk)
            $sc.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
            $sc.Arguments = $sendToArgs
            $sc.IconLocation = "shell32.dll,77"
            $sc.Save()

            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($ws) | Out-Null

            Write-InstallLog -Level "INFO" -Message "Created SendTo shortcut: $SendToLnk"
            if (Test-Path $SendToScriptPath) {
                Write-InstallLog -Level "INFO" -Message "Using interactive prompt (MotW-SendTo.ps1)"
            }
            else {
                Write-InstallLog -Level "WARN" -Message "Using fallback direct reassign (MotW-SendTo.ps1 not found)"
            }
        }
        catch {
            Write-InstallLog -Level "WARN" -Message "Failed to create SendTo shortcut: $_"
        }
    }
}

Write-InstallLog -Level "INFO" -Message "Installation complete"
Write-Host "`nInstallation Summary:" -ForegroundColor Cyan
Write-Host "  Script:   $ScriptPath"
Write-Host "  Log:      $LogPath"

if (-not $NoPath) {
    Write-Host "  PATH:     Added" -ForegroundColor Green
}
else {
    Write-Host "  PATH:     Skipped" -ForegroundColor Gray
}

if (-not $NoSendTo) {
    if ($envCapabilities.SendToAvailable) {
        Write-Host "  SendTo:   Created" -ForegroundColor Green
    }
    else {
        Write-Host "  SendTo:   Restricted" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  SendTo:   Skipped" -ForegroundColor Gray
}

# Show recommendations based on environment
Write-Host "`nRecommendations:" -ForegroundColor Cyan
if (-not $envCapabilities.DotNetAvailable) {
    Write-Host "  - .NET 9+ not found. Consider installing .NET 9 Runtime for MotWasher/MotWatcher GUI tools" -ForegroundColor Yellow
    Write-Host "    Download: https://dotnet.microsoft.com/download/dotnet/9.0" -ForegroundColor Gray
}
if ($envCapabilities.ContextMenuAvailable -and -not $envCapabilities.SendToAvailable) {
    Write-Host "  - Send To restricted but registry available. Consider context menu integration (future feature)" -ForegroundColor Yellow
}
Write-Host "  - Use 'MotW.ps1 status .' to check files in current directory" -ForegroundColor Cyan
Write-Host "  - Use 'MotW.ps1 reassign file.pdf' for progressive zone washing" -ForegroundColor Cyan
