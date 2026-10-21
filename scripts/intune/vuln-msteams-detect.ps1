# A02-T2-DETECT
# Detects Microsoft Teams Personal only.
# Does not target the MSTeams managed work client.
# Intended context: SYSTEM, 64-bit PowerShell.

$ErrorActionPreference = 'Stop'

$Name   = 'MicrosoftTeams'
$Family = 'MicrosoftTeams_8wekyb3d8bbwe'

try {
    # Check active registrations for all users.
    $Installed = @(
        Get-AppxPackage `
            -AllUsers `
            -Name $Name `
            -ErrorAction Stop |
        Where-Object {
            $_.PackageFamilyName -eq $Family
        }
    )

    # Check whether Teams Personal is provisioned for users.
    $Provisioned = @(
        Get-AppxProvisionedPackage `
            -Online `
            -ErrorAction Stop |
        Where-Object {
            $_.DisplayName -eq $Name
        }
    )

    if (
        $Installed.Count -eq 0 -and
        $Provisioned.Count -eq 0
    ) {
        Write-Output 'COMPLIANT A02: MicrosoftTeams Personal is not installed or provisioned.'
        exit 0
    }

    $DetectedItems = @(
        $Installed.PackageFullName
        $Provisioned.PackageName
    ) |
    Where-Object { $_ } |
    Sort-Object -Unique

    Write-Output "NON-COMPLIANT A02: MicrosoftTeams Personal detected: $($DetectedItems -join '; ')"
    exit 1
}
catch {
    # Fail closed so an inventory error is not reported as compliant.
    Write-Output "DETECTION ERROR A02: $($_.Exception.Message)"
    exit 1
}
