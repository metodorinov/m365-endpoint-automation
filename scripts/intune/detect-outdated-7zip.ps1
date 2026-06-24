<#
.SYNOPSIS
    Detects outdated 7-Zip installation.

.DESCRIPTION
    Checks if 7-Zip is installed and compares its version
    with a defined minimum version.

.NOTES
    Author: Metodi Todorinov
#>

$minimumVersion = [version]"24.00"

$paths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

try {
    $apps = foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*7-Zip*" } |
        Select-Object DisplayName, DisplayVersion
    }

    if (-not $apps) {
        Write-Output "7-Zip not installed"
        exit 0
    }

    foreach ($app in $apps) {
        try {
            $version = [version]$app.DisplayVersion

            if ($version -lt $minimumVersion) {
                Write-Output "Outdated version detected: $($app.DisplayVersion)"
                exit 1
            }
        }
        catch {
            Write-Output "Version check failed"
            exit 1
        }
    }

    Write-Output "7-Zip is up to date"
    exit 0
}
catch {
    Write-Output "Error occurred: $($_.Exception.Message)"
    exit 1
}

