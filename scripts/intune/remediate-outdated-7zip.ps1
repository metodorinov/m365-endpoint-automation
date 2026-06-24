#
.SYNOPSIS
    Removes outdated 7-Zip installations.

.DESCRIPTION
    Finds installed 7-Zip versions and removes them if they are below the required version.

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
        Select-Object DisplayName, DisplayVersion, UninstallString
    }

    if (-not $apps) {
        Write-Output "7-Zip not installed"
        exit 0
    }

    foreach ($app in $apps) {
        try {
            $version = [version]$app.DisplayVersion

            if ($version -lt $minimumVersion) {
                Write-Output "Removing outdated version: $($app.DisplayVersion)"

                $uninstall = $app.UninstallString

                if ($uninstall -match "msiexec") {
                    if ($uninstall -match "\{.*\}") {
                        $productCode = $matches[0]
                        Start-Process "msiexec.exe" -ArgumentList "/x $productCode /qn /norestart" -Wait
                    }
                }
                else {
                    Start-Process -FilePath $uninstall -ArgumentList "/S" -Wait
                }
            }
        }
        catch {
            Write-Output "Failed processing app"
        }
    }

    Write-Output "Remediation completed"
    exit 0
}
catch {
    Write-Output "Error: $($_.Exception.Message)"
    exit 1
}
