<#

Developed Intune proactive remediation scripts to address Visual Studio Python runtime vulnerabilities using update-first and fallback removal approach

.SYNOPSIS
    Remediates vulnerable Visual Studio Python runtime.

.DESCRIPTION
    Attempts to update Visual Studio to remediate Python runtime vulnerabilities.
    If the issue persists, removes the runtime as a fallback.

.NOTES
    Author: Metodi Todorinov
#>

$vsInstaller = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe"
$pythonPath  = "C:\Program Files (x86)\Microsoft Visual Studio\Shared\Python39_64"
$pythonExe   = "$pythonPath\pythonw.exe"

Write-Output "Starting Visual Studio Python remediation..."

try {
    # Step 1: Check if runtime exists
    if (-not (Test-Path $pythonExe)) {
        Write-Output "Python runtime not present. No action required."
        exit 0
    }

    # Step 2: Attempt Visual Studio update
    if (Test-Path $vsInstaller) {

        Write-Output "Triggering Visual Studio update..."

        try {
            Start-Process -FilePath $vsInstaller `
                          -ArgumentList "update --quiet --norestart" `
                          -Wait

            Write-Output "Visual Studio update completed."
        }
        catch {
            Write-Output "Visual Studio update failed: $($_.Exception.Message)"
        }
    }
    else {
        Write-Output "VS Installer not found. Skipping update step."
    }

    # Step 3: Re-check runtime after update
    Start-Sleep -Seconds 10

    if (-not (Test-Path $pythonExe)) {
        Write-Output "Python runtime removed or updated successfully."
        exit 0
    }

    # Step 4: Optional version logging
    try {
        $version = (Get-Item $pythonExe).VersionInfo.ProductVersion
        Write-Output "Detected Python version after update: $version"
    }
    catch {
        Write-Output "Unable to determine Python version."
    }

    # Step 5: Fallback removal
    Write-Output "Attempting fallback remediation (removal)..."

    try {
        Get-Process *python* -ErrorAction SilentlyContinue | Stop-Process -Force
        Remove-Item $pythonPath -Recurse -Force -ErrorAction Stop

        Write-Output "Python runtime removed successfully."
        exit 0
    }
    catch {
        Write-Output "Fallback removal failed: $($_.Exception.Message)"
        exit 1
    }

}
catch {
    Write-Output "Remediation failed: $($_.Exception.Message)"
    exit 1
}


