$ErrorActionPreference = 'Stop'

$Id = 'A02'
$PackageName = 'MicrosoftTeams'
$Root = 'C:\Program Files\WindowsApps\DeletedAllUserPackages'
$ResiduePattern = 'MicrosoftTeams_*_x64__8wekyb3d8bbwe'
$LogDirectory = 'C:\ProgramData\VulnRemediation'
$Log = Join-Path -Path $LogDirectory -ChildPath "$Id.log"

New-Item `
    -ItemType Directory `
    -Path $LogDirectory `
    -Force `
    -ErrorAction Stop |
    Out-Null

function Write-RemediationLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $Entry = "{0} {1}" -f (Get-Date -Format 's'), $Message

    $Entry |
        Tee-Object -FilePath $Log -Append |
        Write-Output
}

try {
    Write-RemediationLog 'Starting MicrosoftTeams package remediation.'

    $InstalledPackages = @(
        Get-AppxPackage `
            -AllUsers `
            -Name $PackageName `
            -ErrorAction SilentlyContinue
    )

    foreach ($Package in $InstalledPackages) {
        if ($Package.NonRemovable) {
            Write-RemediationLog "SKIPPED non-removable package: $($Package.PackageFullName)"
            continue
        }

        Remove-AppxPackage `
            -Package $Package.PackageFullName `
            -AllUsers `
            -Confirm:$false `
            -ErrorAction Stop

        Write-RemediationLog "UNINSTALLED registered package: $($Package.PackageFullName)"
    }

    $ProvisionedPackages = @(
        Get-AppxProvisionedPackage -Online -ErrorAction Stop |
            Where-Object {
                $_.DisplayName -eq $PackageName -or
                $_.PackageName -like "${PackageName}_*"
            }
    )

    foreach ($Package in $ProvisionedPackages) {
        $Result = Remove-AppxProvisionedPackage `
            -Online `
            -PackageName $Package.PackageName `
            -ErrorAction Stop

        if ($Result.RestartNeeded) {
            Write-RemediationLog "DEPROVISIONED package; Windows reports restart needed: $($Package.PackageName)"
        }
        else {
            Write-RemediationLog "DEPROVISIONED package: $($Package.PackageName)"
        }
    }

    # Verify registered packages.
    $RemainingInstalled = @(
        Get-AppxPackage `
            -AllUsers `
            -Name $PackageName `
            -ErrorAction SilentlyContinue
    )

    # Verify provisioned packages.
    $RemainingProvisioned = @(
        Get-AppxProvisionedPackage -Online -ErrorAction Stop |
            Where-Object {
                $_.DisplayName -eq $PackageName -or
                $_.PackageName -like "${PackageName}_*"
            }
    )

    # Report OS-managed residue, but do not manually delete WindowsApps content.
    $RemainingResidue = @()

    if (Test-Path -LiteralPath $Root -PathType Container) {
        $RemainingResidue = @(
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

    foreach ($Package in $RemainingInstalled) {
        Write-RemediationLog "FAILED verification: Registered package remains: $($Package.PackageFullName)"
    }

    foreach ($Package in $RemainingProvisioned) {
        Write-RemediationLog "FAILED verification: Provisioned package remains: $($Package.PackageName)"
    }

    foreach ($Item in $RemainingResidue) {
        Write-RemediationLog "WARNING: OS-managed residue remains and was not manually deleted: $($Item.FullName)"
    }

    if (
        $RemainingInstalled.Count -gt 0 -or
        $RemainingProvisioned.Count -gt 0
    ) {
        Write-RemediationLog 'FAILED: One or more registered or provisioned packages remain.'
        exit 1
    }

    if ($RemainingResidue.Count -gt 0) {
        Write-RemediationLog 'SUPPORTED removal completed, but DeletedAllUserPackages residue remains. A restart or later Windows servicing may be required.'
        exit 1
    }

    Write-RemediationLog 'COMPLIANT: No registered, provisioned, or scoped residue was found.'
    exit 0
}
catch {
    Write-RemediationLog "FAILED: $($_.Exception.Message)"
    exit 1
}