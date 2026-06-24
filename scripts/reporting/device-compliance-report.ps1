<#
.SYNOPSIS
    Exports device compliance report from Microsoft Intune.

.DESCRIPTION
    Retrieves managed devices and exports basic compliance information.

.NOTES
    Author: Metodi Todorinov
#>

param(
    [string]$OutputPath = ".\device-compliance.csv"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" | Out-Null

    Write-Host "Retrieving devices..."
    $devices = Get-MgDeviceManagementManagedDevice -All

    $report = foreach ($device in $devices) {
        [PSCustomObject]@{
            DeviceName       = $device.DeviceName
            UserPrincipalName = $device.UserPrincipalName
            OperatingSystem  = $device.OperatingSystem
            ComplianceState  = $device.ComplianceState
            LastSyncDateTime = $device.LastSyncDateTime
        }
    }

    Write-Host "Exporting report..."
    $report | Export-Csv -Path $OutputPath -NoTypeInformation

    Write-Host "Report exported to $OutputPath"
}
catch {
    Write-Error $_
}
