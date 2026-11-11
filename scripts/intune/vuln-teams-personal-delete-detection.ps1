$ErrorActionPreference = 'Stop'

$PackageName = 'MicrosoftTeams'
$Root = 'C:\Program Files\WindowsApps\DeletedAllUserPackages'
$ResiduePattern = 'MicrosoftTeams_*_x64__8wekyb3d8bbwe'

try {
    $InstalledPackages = @(
        Get-AppxPackage `
            -AllUsers `
            -Name $PackageName `
            -ErrorAction SilentlyContinue
    )

    $ProvisionedPackages = @(
        Get-AppxProvisionedPackage -Online -ErrorAction Stop |
            Where-Object {
                $_.DisplayName -eq $PackageName -or
                $_.PackageName -like "${PackageName}_*"
            }
    )

    $ResidueItems = @()

    if (Test-Path -LiteralPath $Root -PathType Container) {
        $ResidueItems = @(
            Get-ChildItem `
                -LiteralPath $Root `
                -Directory `
                -Force `
                -ErrorAction Stop |
                Where-Object {
                    $_.Name -like $ResiduePattern
                }
        )
    }

    if (
        $InstalledPackages.Count -gt 0 -or
        $ProvisionedPackages.Count -gt 0 -or
        $ResidueItems.Count -gt 0
    ) {
        foreach ($Package in $InstalledPackages) {
            Write-Output "NON-COMPLIANT: Registered package found: $($Package.PackageFullName)"
        }

        foreach ($Package in $ProvisionedPackages) {
            Write-Output "NON-COMPLIANT: Provisioned package found: $($Package.PackageName)"
        }

        foreach ($Item in $ResidueItems) {
            Write-Output "NON-COMPLIANT: OS-managed package residue found: $($Item.FullName)"
        }

        exit 1
    }

    Write-Output 'COMPLIANT: No registered, provisioned, or scoped MicrosoftTeams package residue was found.'
    exit 0
}
catch {
    Write-Output "DETECTION ERROR: $($_.Exception.Message)"
    exit 1
}


	
