<#
.SYNOPSIS
    Resets Windows Update components.

.DESCRIPTION
    Stops Windows Update services, clears the Windows Update cache,
    restarts required services, and triggers a fresh update scan.

.NOTES
    Author: Metodi Todorinov
#>

$ErrorActionPreference = "Stop"

Write-Output "Starting Windows Update remediation..."

try {

    # Services used by Windows Update
    $services = @(
        "wuauserv",   # Windows Update
        "bits",       # Background Intelligent Transfer Service
        "cryptsvc"    # Cryptographic Services
    )

    # Stop services
    foreach ($service in $services) {
        Write-Output "Stopping service: $service"
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 5

    # Clear SoftwareDistribution
    $softwareDistribution = "$env:SystemRoot\SoftwareDistribution"

    if (Test-Path $softwareDistribution) {
        Write-Output "Clearing SoftwareDistribution cache"
        Remove-Item "$softwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Clear Catroot2
    $catroot2 = "$env:SystemRoot\System32\catroot2"

    if (Test-Path $catroot2) {
        Write-Output "Clearing Catroot2 cache"
        Remove-Item "$catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Start services again
    foreach ($service in $services) {
        Write-Output "Starting service: $service"
        Start-Service -Name $service -ErrorAction SilentlyContinue
    }

    # Force update scan
    Write-Output "Triggering update scan"

    try {
        UsoClient StartScan
    }
    catch {
        Write-Output "UsoClient unavailable"
    }

    Write-Output "Windows Update remediation completed successfully."
    exit 0

}
catch {
    Write-Output "Windows Update remediation failed: $($_.Exception.Message)"
    exit 1
}
