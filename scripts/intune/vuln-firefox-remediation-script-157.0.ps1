# EML - Firefox forced reinstall - REMEDIATION
# Run as: SYSTEM
# PowerShell: 64-bit
#
# Purpose:
#   - Stop Firefox
#   - Remove MSI-based Firefox installations
#   - Remove machine-wide Firefox EXE installations
#   - Remove per-user Firefox installations
#   - Preserve Firefox user profiles in AppData\Roaming
#   - Remove orphaned Firefox uninstall registry entries
#   - Clear Intune Win32 app retry state for specified Firefox apps
#   - Restart the Intune Management Extension
#
# IMPORTANT:
#   Replace the placeholder App IDs below with the real Intune Win32 App IDs.

$FirefoxAppIds = @(
    'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Mozilla Firefox (AU)
    'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Mozilla Firefox (EU)
    'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Mozilla Firefox (US)
)

$ErrorActionPreference = 'SilentlyContinue'

$LogPath = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\EML-Firefox-Reinstall.log'

function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $Entry = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') $Message"

    Add-Content -Path $LogPath -Value $Entry -ErrorAction SilentlyContinue
    Write-Output $Message
}

function Wait-PathGone {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [int]$TimeoutSeconds = 120
    )

    $Elapsed = 0

    while ((Test-Path $Path) -and ($Elapsed -lt $TimeoutSeconds)) {
        Start-Sleep -Seconds 5
        $Elapsed += 5
    }

    if (Test-Path $Path) {
        Write-Log "WARNING: Path still exists after timeout: $Path"
        return $false
    }

    return $true
}

Write-Log '========== Firefox remediation started =========='


# -------------------------------------------------------------------
# 1. Stop Firefox processes
# -------------------------------------------------------------------

$FirefoxProcesses = Get-Process -Name 'firefox' -ErrorAction SilentlyContinue

if ($FirefoxProcesses) {

    $FirefoxProcesses | Stop-Process -Force -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 3

    Write-Log 'Firefox processes stopped.'

}
else {

    Write-Log 'No running Firefox processes found.'
}


# -------------------------------------------------------------------
# 2. Find and remove MSI-registered Firefox installations
# -------------------------------------------------------------------

$UninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$MSIInstalls = Get-ItemProperty $UninstallKeys -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DisplayName -like 'Mozilla Firefox*' -and
        $_.PSChildName -match '^\{[0-9A-Fa-f-]+\}$'
    }

foreach ($Install in $MSIInstalls) {

    $ProductCode = $Install.PSChildName
    $DisplayName = $Install.DisplayName
    $DisplayVersion = $Install.DisplayVersion

    Write-Log "Removing MSI installation: $DisplayName $DisplayVersion [$ProductCode]"

    $Process = Start-Process `
        -FilePath 'msiexec.exe' `
        -ArgumentList "/x $ProductCode /qn /norestart" `
        -Wait `
        -PassThru `
        -ErrorAction SilentlyContinue

    if ($null -ne $Process) {
        Write-Log "MSI uninstall finished with exit code $($Process.ExitCode): $DisplayName"
    }
    else {
        Write-Log "WARNING: Unable to start MSI uninstall for: $DisplayName"
    }
}


# -------------------------------------------------------------------
# 3. Remove machine-wide Firefox EXE installations
# -------------------------------------------------------------------

$MachineFirefoxPaths = @(
    "$env:ProgramFiles\Mozilla Firefox"
)

if (${env:ProgramFiles(x86)}) {
    $MachineFirefoxPaths += "${env:ProgramFiles(x86)}\Mozilla Firefox"
}

foreach ($FirefoxDirectory in $MachineFirefoxPaths) {

    if (-not (Test-Path $FirefoxDirectory)) {
        continue
    }

    Write-Log "Machine-wide Firefox installation found: $FirefoxDirectory"

    $Helper = Join-Path $FirefoxDirectory 'uninstall\helper.exe'
    $FirefoxExe = Join-Path $FirefoxDirectory 'firefox.exe'

    if (Test-Path $Helper) {

        Write-Log "Running Firefox uninstaller: $Helper"

        Start-Process `
            -FilePath $Helper `
            -ArgumentList '/S' `
            -Wait `
            -ErrorAction SilentlyContinue

        Wait-PathGone -Path $FirefoxExe -TimeoutSeconds 120 | Out-Null
    }

    if (Test-Path $FirefoxDirectory) {

        Remove-Item `
            -Path $FirefoxDirectory `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue

        if (-not (Test-Path $FirefoxDirectory)) {
            Write-Log "Leftover Firefox directory removed: $FirefoxDirectory"
        }
        else {
            Write-Log "WARNING: Could not completely remove: $FirefoxDirectory"
        }
    }
}


# -------------------------------------------------------------------
# 4. Remove per-user Firefox installations
#
# IMPORTANT:
# This targets AppData\Local\Mozilla Firefox only.
# AppData\Roaming\Mozilla\Firefox profiles are NOT deleted.
# -------------------------------------------------------------------

$PerUserFirefox = Get-ChildItem `
    -Path 'C:\Users\*\AppData\Local\Mozilla Firefox' `
    -Directory `
    -ErrorAction SilentlyContinue

foreach ($UserInstall in $PerUserFirefox) {

    $UserFirefoxDirectory = $UserInstall.FullName
    $Helper = Join-Path $UserFirefoxDirectory 'uninstall\helper.exe'
    $FirefoxExe = Join-Path $UserFirefoxDirectory 'firefox.exe'

    Write-Log "Per-user Firefox installation found: $UserFirefoxDirectory"

    if (Test-Path $Helper) {

        Start-Process `
            -FilePath $Helper `
            -ArgumentList '/S' `
            -Wait `
            -ErrorAction SilentlyContinue

        Wait-PathGone -Path $FirefoxExe -TimeoutSeconds 60 | Out-Null
    }

    if (Test-Path $UserFirefoxDirectory) {

        Remove-Item `
            -Path $UserFirefoxDirectory `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path $UserFirefoxDirectory)) {
        Write-Log "Per-user Firefox installation removed: $UserFirefoxDirectory"
    }
    else {
        Write-Log "WARNING: Could not completely remove per-user installation: $UserFirefoxDirectory"
    }
}


# -------------------------------------------------------------------
# 5. Remove orphaned Firefox uninstall registry entries
# -------------------------------------------------------------------

$UninstallRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

foreach ($RegistryRoot in $UninstallRoots) {

    if (-not (Test-Path $RegistryRoot)) {
        continue
    }

    Get-ChildItem -Path $RegistryRoot -ErrorAction SilentlyContinue |
        ForEach-Object {

            $RegistryEntry = $_

            $Properties = Get-ItemProperty `
                -Path $RegistryEntry.PSPath `
                -ErrorAction SilentlyContinue

            if ($Properties.DisplayName -like 'Mozilla Firefox*') {

                $EntryName = $RegistryEntry.PSChildName
                $DisplayName = $Properties.DisplayName

                Remove-Item `
                    -Path $RegistryEntry.PSPath `
                    -Recurse `
                    -Force `
                    -ErrorAction SilentlyContinue

                Write-Log "Firefox uninstall entry removed: $DisplayName [$EntryName]"
            }
        }
}


# -------------------------------------------------------------------
# 6. Clear Intune Win32 app retry/cooldown state
#    ONLY for the Firefox Intune App IDs listed above
# -------------------------------------------------------------------

$IMEWin32AppsPath = 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps'

if (Test-Path $IMEWin32AppsPath) {

    $IMEUserKeys = Get-ChildItem `
        -Path $IMEWin32AppsPath `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.PSChildName -ne 'Reporting'
        }

    foreach ($IMEUserKey in $IMEUserKeys) {

        $UserKeyPath = $IMEUserKey.PSPath

        foreach ($AppId in $FirefoxAppIds) {

            if (:IsNullOrWhiteSpace($AppId) -or
                $AppId -like 'xxxxxxxx-*') {

                continue
            }


            # Remove application-specific state
            Get-ChildItem `
                -Path $UserKeyPath `
                -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.PSChildName -like "$AppId*"
                } |
                ForEach-Object {

                    Write-Log "Removing Intune app state: $($_.PSChildName)"

                    Remove-Item `
                        -Path $_.PSPath `
                        -Recurse `
                        -Force `
                        -ErrorAction SilentlyContinue
                }


            # Check GRS state
            $GRSPath = Join-Path $UserKeyPath 'GRS'

            if (Test-Path $GRSPath) {

                Get-ChildItem `
                    -Path $GRSPath `
                    -ErrorAction SilentlyContinue |
                    ForEach-Object {

                        $GRSEntry = $_

                        $Properties = Get-ItemProperty `
                            -Path $GRSEntry.PSPath `
                            -ErrorAction SilentlyContinue

                        $PropertyValues = @(
                            $Properties.PSObject.Properties |
                                Where-Object {
                                    $_.Name -notlike 'PS*'
                                } |
                                ForEach-Object {
                                    [string]$_.Value
                                }
                        )

                        $ContainsAppId = $false

                        foreach ($Value in $PropertyValues) {

                            if ($Value -match :Escape($AppId)) {
                                $ContainsAppId = $true
                                break
                            }
                        }

                        if ($ContainsAppId) {

                            Write-Log "Removing matching Intune GRS entry: $($GRSEntry.PSChildName)"

                            Remove-Item `
                                -Path $GRSEntry.PSPath `
                                -Recurse `
                                -Force `
                                -ErrorAction SilentlyContinue
                        }
                    }
            }
        }
    }

    Write-Log 'Intune retry state processing completed for specified Firefox apps.'
}
else {

    Write-Log 'WARNING: Intune Win32Apps registry path was not found.'
}


# -------------------------------------------------------------------
# 7. Restart Intune Management Extension
# -------------------------------------------------------------------

$IMEService = Get-Service `
    -Name 'IntuneManagementExtension' `
    -ErrorAction SilentlyContinue

if ($IMEService) {

    Write-Log 'Restarting Intune Management Extension...'

    Restart-Service `
        -Name 'IntuneManagementExtension' `
        -Force `
        -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 3

    $IMEService = Get-Service `
        -Name 'IntuneManagementExtension' `
        -ErrorAction SilentlyContinue

    Write-Log "Intune Management Extension status: $($IMEService.Status)"
}
else {

    Write-Log 'WARNING: Intune Management Extension service was not found.'
}


Write-Log 'Firefox removal completed. Intune reinstall is now pending.'
Write-Log '========== Firefox remediation completed =========='

exit 0