<#
.SYNOPSIS
    Exports users without MFA enabled.

.DESCRIPTION
    Retrieves users and their authentication methods from Microsoft Entra ID
    and identifies accounts without MFA configured.

.NOTES
    Author: Metodi Todorinov
#>

param(
    [string]$OutputPath = ".\users-without-mfa.csv"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "User.Read.All","UserAuthenticationMethod.Read.All" | Out-Null

    Write-Host "Retrieving users..."
    $users = Get-MgUser -All -Property "Id,DisplayName,UserPrincipalName"

    $noMfaUsers = @()

    foreach ($user in $users) {

        try {
            $methods = Get-MgUserAuthenticationMethod -UserId $user.Id

            # Count MFA-capable methods (ignore password)
            $mfaMethods = $methods | Where-Object {
                $_.'@odata.type' -notlike "*passwordAuthenticationMethod"
            }

            if (-not $mfaMethods) {
                $noMfaUsers += [PSCustomObject]@{
                    DisplayName       = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                }
            }
        }
        catch {
            Write-Host "Failed to process user: $($user.UserPrincipalName)"
        }
    }

    Write-Host "Exporting results..."
    $noMfaUsers | Export-Csv -Path $OutputPath -NoTypeInformation

    Write-Host "Done. Users without MFA exported to $OutputPath"
}
catch {
    Write-Error $_.Exception.Message
}
