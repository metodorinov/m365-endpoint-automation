<#
.SYNOPSIS
    Detects Visual Studio Python runtime.

.DESCRIPTION
    Checks if the Visual Studio Python runtime exists on the device.
    Used as a detection script for Intune proactive remediation.

    Exit code:
    0 = compliant (not present)
    1 = non-compliant (present)

.NOTES
    Author: Metodi Todorinov
#>

$pythonExe = "C:\Program Files (x86)\Microsoft Visual Studio\Shared\Python39_64\pythonw.exe"

try {
    if (Test-Path $pythonExe) {
        Write-Output "Visual Studio Python runtime detected"
        exit 1
    }

    Write-Output "Python runtime not present"
    exit 0
}
catch {
    Write-Output "Detection failed: $($_.Exception.Message)"
    exit 1
}
