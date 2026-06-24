
<#
.SYNOPSIS
    Exports inactive users from Microsoft Entra ID.

.DESCRIPTION
    Retrieves users from Microsoft Graph and identifies those
    who have not signed in within a defined period.

.NOTES
    Author: Metodi Todorinov
#>

param(
    [int]$InactiveDays = 90,
    [string]$OutputPath = ".\inactive-users.csv"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All" | Out-Null

    $cutoffDate = (Get-Date).AddDays(-$InactiveDays)

    Write-Host "Retrieving users..."
    $users = Get-MgUser -All -Property "DisplayName,UserPrincipalName,SignInActivity"

    $inactiveUsers = foreach ($user in $users) {
        $lastSignIn = $user.SignInActivity.LastSignInDateTime

        if (-not $lastSignIn -or ([datetime]$lastSignIn -lt $cutoffDate)) {
            [PSCustomObject]@{
                DisplayName       = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                LastSignIn        = $lastSignIn
            }
        }
    }

    Write-Host "Exporting results..."
    $inactiveUsers | Export-Csv -Path $OutputPath -NoTypeInformation

    Write-Host "Done. Inactive users exported to $OutputPath"
}
catch {
    Write-Error $_
}

