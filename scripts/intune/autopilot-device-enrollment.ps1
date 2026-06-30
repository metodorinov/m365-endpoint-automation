<#
.SYNOPSIS
    Collects device information and uploads to Windows Autopilot.

.DESCRIPTION
    Uses the Get-WindowsAutopilotInfo script to register a device for Autopilot
    using application-based authentication.

.NOTES
    Author: Metodi Todorinov

    IMPORTANT:
    - Do NOT store real Tenant ID, App ID, or App Secret in source control
    - Replace placeholders with secure values before use
#>

# Allow script execution for current process
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Install required package provider
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Install Autopilot script
Install-Script -Name Get-WindowsAutopilotInfo -Force

# Define parameters (PLACEHOLDERS - replace in production)
$TenantId  = "YOUR-TENANT-ID"
$AppId     = "YOUR-APP-ID"
$AppSecret = "YOUR-APP-SECRET"
$GroupTag  = "YOUR-GROUP-TAG"

# Run Autopilot registration
Get-WindowsAutopilotInfo `
    -Online `
    -TenantId $TenantId `
    -AppId $AppId `
    -AppSecret $AppSecret `
    -GroupTag $GroupTag
