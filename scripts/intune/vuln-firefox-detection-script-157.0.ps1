# EML - Firefox forced reinstall - DETECTION
# Flags:
#   - Firefox below minimum version
#   - Any 32-bit Firefox installation
#   - Any per-user Firefox installation

$MinVersion = [version]'157.0.0'
$bad = @()

# Machine-wide Firefox installations
$keys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

Get-ItemProperty $keys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like 'Mozilla Firefox*' } |
    ForEach-Object {

        $FirefoxVersion = $null

        try {
            $FirefoxVersion = ($_.DisplayVersion -replace '[^\d.]', ''.Trim('.'))
        }
        catch {
            $bad += "$($_.DisplayName) - invalid version: $($_.DisplayVersion)"
            return
        }

        # Below required version
        if ($FirefoxVersion -lt $MinVersion) {
            $bad += "$($_.DisplayName) $($_.DisplayVersion) - below minimum $MinVersion"
        }

        # 32-bit Firefox on a 64-bit device
        if ($_.PSPath -like '*WOW6432Node*') {
            $bad += "$($_.DisplayName) $($_.DisplayVersion) - 32-bit installation"
        }
    }

# Per-user Firefox installations
Get-ChildItem 'C:\Users\*\AppData\Local\Mozilla Firefox\firefox.exe' `
    -ErrorAction SilentlyContinue |
    ForEach-Object {
        $bad += "Per-user installation: $($_.FullName)"
    }

if ($bad.Count -gt 0) {
    Write-Output ($bad -join ' || ')
    exit 1
}

Write-Output "Compliant or no Firefox detected. Minimum version: $MinVersion"
exit 0