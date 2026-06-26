<#
.SYNOPSIS
    Exports risky users from Microsoft Entra ID.

.DESCRIPTION
    Retrieves users flagged as risky by Microsoft Entra ID (Identity Protection)
    and exports key information for review.

.NOTES
    Author: Metodi Todorinov
#>

param(
    [string]$OutputPath = ".\risky-users-report.csv"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "IdentityRiskyUser.Read.All","User.Read.All" | Out-Null

    Write-Host "Retrieving risky users..."
    $riskyUsers = Get-MgRiskyUser -All

    if (-not $riskyUsers) {
        Write-Host "No risky users found"
        exit 0
    }

    $report = foreach ($user in $riskyUsers) {

        [PSCustomObject]@{
            UserPrincipalName = $user.UserPrincipalName
            RiskLevel         = $user.RiskLevel
            RiskState         = $user.RiskState
            RiskDetail        = $user.RiskDetail
            LastUpdated       = $user.RiskLastUpdatedDateTime
        }
    }

    Write-Host "Exporting report..."
    $report | Export-Csv -Path $OutputPath -NoTypeInformation

    Write-Host "Done. Risky users exported to $OutputPath"
}
catch {
    Write-Error $_.Exception.Message
}
