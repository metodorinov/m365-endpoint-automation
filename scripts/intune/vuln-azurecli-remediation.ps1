# Azure CLI Remediation
# Intune Remediations | SYSTEM | 64-bit PowerShell

$ErrorActionPreference = 'Stop'

$TargetVersion = [version]'2.92.0'
$CliRoot       = 'C:\Program Files\Microsoft SDKs\Azure\CLI2'
$AzPath        = Join-Path $CliRoot 'wbin\az.cmd'
$PythonPath    = Join-Path $CliRoot 'python.exe'

$LogDirectory = 'C:\ProgramData\VulnRemediation'
$LogFile      = Join-Path $LogDirectory 'AzureCLI.log'

# Create logging directory
if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message
    )

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Entry = "$Timestamp | $Message"

    Add-Content -Path $LogFile -Value $Entry
    Write-Output $Message
}

try {

    # ----------------------------------------------------------
    # Determine existing Azure CLI version
    # ----------------------------------------------------------

    $OldVersion = 'Not installed'

    if (Test-Path $AzPath) {
        try {
            $VersionJson = & $AzPath version --output json 2>$null |
                ConvertFrom-Json

            if ($VersionJson.'azure-cli') {
                $OldVersion = $VersionJson.'azure-cli'
            }
        }
        catch {
            Write-Log "WARNING: Existing Azure CLI detected but version could not be determined."
        }
    }

    Write-Log "Current Azure CLI version: $OldVersion"

    # ----------------------------------------------------------
    # Locate WinGet
    # ----------------------------------------------------------

    $Winget = Get-Command winget.exe -ErrorAction SilentlyContinue

    if (-not $Winget) {
        throw 'winget.exe could not be located in the SYSTEM context.'
    }

    $WingetPath = $Winget.Source

    Write-Log "Using WinGet: $WingetPath"

    # ----------------------------------------------------------
    # Install or upgrade
    # ----------------------------------------------------------

    if (Test-Path $AzPath) {

        Write-Log 'Azure CLI detected. Starting upgrade.'

        & $WingetPath upgrade `
            --exact `
            --id Microsoft.AzureCLI `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements

        $WingetExitCode = $LASTEXITCODE
    }
    else {

        Write-Log 'Azure CLI x64 not detected. Starting installation.'

        & $WingetPath install `
            --exact `
            --id Microsoft.AzureCLI `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements

        $WingetExitCode = $LASTEXITCODE
    }

    Write-Log "WinGet exit code: $WingetExitCode"

    if ($WingetExitCode -ne 0) {
        throw "WinGet returned exit code $WingetExitCode."
    }

    # ----------------------------------------------------------
    # Wait for Azure CLI
    # ----------------------------------------------------------

    $TimeoutSeconds = 60
    $ElapsedSeconds = 0

    while (
        (-not (Test-Path $AzPath)) -and
        ($ElapsedSeconds -lt $TimeoutSeconds)
    ) {
        Start-Sleep -Seconds 2
        $ElapsedSeconds += 2
    }

    if (-not (Test-Path $AzPath)) {
        throw "Azure CLI x64 wasn't detected after installation/upgrade."
    }

    # ----------------------------------------------------------
    # Verify installed version
    # ----------------------------------------------------------

    $VersionJson = & $AzPath version --output json 2>$null |
        ConvertFrom-Json

    if (-not $VersionJson.'azure-cli') {
        throw 'Azure CLI installed but the version couldn't be determined.'
    }

    $NewVersion = [version]$VersionJson.'azure-cli'

    Write-Log "Azure CLI version after remediation: $NewVersion"

    if ($NewVersion -lt $TargetVersion) {
        throw "Installed Azure CLI $NewVersion is below required version $TargetVersion."
    }

    # Embedded Python information
    if (Test-Path $PythonPath) {
        $PythonVersion = (& $PythonPath --version 2>&1)
        Write-Log "Embedded Python: $PythonVersion"
    }
    else {
        Write-Log 'WARNING: Embedded Python executable wasn't found.'
    }

    Write-Log "SUCCESS: Azure CLI $OldVersion -> $NewVersion"
    Write-Log "COMPLIANT: Azure CLI $NewVersion >= $TargetVersion"

    exit 0
}
catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    exit 1
}