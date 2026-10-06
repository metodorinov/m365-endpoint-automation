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
# 4. Remove per-user 