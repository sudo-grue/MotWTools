<#
.SYNOPSIS
  View/Add/Remove Mark-of-the-Web (Zone.Identifier) on files.

.USAGE
  MotW.ps1 *.pdf                 # Unblock (default)
  MotW.ps1 unblock *.pdf
  MotW.ps1 add *.pdf
  MotW.ps1 status .
  MotW.ps1 unblock . -Recurse
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    # Optional action; default is 'unblock'. Leave unnamed to keep paths positional.
    [ValidateSet('unblock', 'add', 'status')]
    [string]$Action = 'unblock',

    # Gather all remaining positional args (paths, maybe an action token)
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsRest,

    # Recurse through folders
    [switch]$Recurse
)

# ---- Flexible args shim: support both "MotW.ps1 *.pdf" and "MotW.ps1 unblock *.pdf" ----
$validActions = @('unblock', 'add', 'status')
[string[]]$Paths = @()

if ($ArgsRest -and $ArgsRest.Count -gt 0) {
    if ($ArgsRest[0] -in $validActions) {
        # Form: action first, then paths
        $Action = $ArgsRest[0]
        if ($ArgsRest.Count -gt 1) { $Paths = $ArgsRest[1..($ArgsRest.Count - 1)] }
    }
    else {
        # Form: no action token; treat all as paths and use default 'unblock'
        $Paths = $ArgsRest
    }
}
else {
    # No args supplied at all -> prompt user
    Write-Error "No paths provided. Example: MotW.ps1 *.pdf  or  MotW.ps1 unblock . -Recurse"
    return
}

function Resolve-Targets {
    param(
        [string[]]$InputPaths,
        [switch]$Recurse
    )
    $targets = @()

    if (-not $InputPaths -or $InputPaths.Count -eq 0) {
        Write-Error "No paths provided. Example: MotW.ps1 *.pdf  or  MotW.ps1 unblock . -Recurse"
        return @()
    }

    foreach ($p in $InputPaths) {
        # Resolve to files
        $resolved = @()
        try {
            $resolved = Resolve-Path -LiteralPath $p -ErrorAction Stop | ForEach-Object { $_.Path }
        }
        catch {
            # If literal resolution fails (e.g., wildcard from some callers), try wildcard enumeration
            $resolved = Get-ChildItem -Path $p -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
        }

        foreach ($r in $resolved) {
            if (Test-Path $r -PathType Container) {
                if ($Recurse) {
                    $targets += Get-ChildItem -LiteralPath $r -Recurse -File -Force | ForEach-Object { $_.FullName }
                }
                else {
                    $targets += Get-ChildItem -LiteralPath $r -File -Force | ForEach-Object { $_.FullName }
                }
            }
            else {
                $targets += $r
            }
        }
    }

    $targets | Sort-Object -Unique
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
if (-not $files -or $files.Count -eq 0) { return }

switch ($Action) {
    'unblock' {
        foreach ($f in $files) {
            try {
                # Remove ADS directly, ignore if missing
                Remove-Item -LiteralPath $f -Stream Zone.Identifier -ErrorAction SilentlyContinue

                Unblock-File -LiteralPath $f -ErrorAction SilentlyContinue
                Write-Host "Unblocked: $f"
            }
            catch {
                Write-Warning ("Failed to unblock: {0}  -> {1}" -f $f, $_.Exception.Message)
            }
        }
    }

    'add' {
        foreach ($f in $files) {
            try {
                Set-Content -LiteralPath $f -Stream Zone.Identifier -Value "[ZoneTransfer]`nZoneId=3" -Force
                Write-Host "Marked (MotW added): $f"
            }
            catch {
                Write-Warning ("Failed to add MotW: {0}  -> {1}" -f $f, $_.Exception.Message)
            }
        }
    }

    'status' {
        foreach ($f in $files) {
            try {
                $has = Test-HasMotW -Path $f
                if ($has) {
                    Write-Host ("[MotW]  {0}" -f $f)
                }
                else {
                    Write-Host ("[clean] {0}" -f $f)
                }
            }
            catch {
                Write-Warning ("Failed to read status: {0}  -> {1}" -f $f, $_.Exception.Message)
            }
        }
    }
}
