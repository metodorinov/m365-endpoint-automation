# Azure CLI Detection
# Intune Remediations | SYSTEM | 64-bit PowerShell

$TargetVersion = [version]'2.92.0'
$CliRoot       = 'C:\Program Files\Microsoft SDKs\Azure\CLI2'
$AzPath        = Join-Path $CliRoot 'wbin\az.cmd'
$PythonPath    = Join-Path $CliRoot 'python.exe'

# Azure CLI x64 isn't installed in the approved location
if (-not (Test-Path $AzPath)) {
    Write-Output "NON-COMPLIANT: Azure CLI x64 not found at $AzPath"
    exit 1
}

try {
    # Get Azure CLI version
    $VersionJson = & $AzPath version --output json 2>$null | ConvertFrom-Json

    if (-not $VersionJson.'azure-cli') {
        throw 'Azure CLI version could not be determined.'
    }

    $InstalledVersion = [version]$VersionJson.'azure-cli'

    # Embedded Python is informational
    if (Test-Path $PythonPath) {
        $PythonVersion = (& $PythonPath --version 2>&1)
    }
    else {
        $PythonVersion = 'Embedded Python not found'
    }

    Write-Output "FOUND: Azure CLI $InstalledVersion; $PythonVersion"

    if ($InstalledVersion -ge $TargetVersion) {
        Write-Output "COMPLIANT: Azure CLI $InstalledVersion >= $TargetVersion"
        exit 0
    }
    else {
        Write-Output "NON-COMPLIANT: Azure CLI $InstalledVersion < $TargetVersion"
        exit 1
    }
}
catch {
    Write-Output "NON-COMPLIANT: Unable to determine Azure CLI version. $($_.Exception.Message)"
    exit 1
}