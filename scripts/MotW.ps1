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
