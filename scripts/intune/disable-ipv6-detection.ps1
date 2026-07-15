$regPath = "[PATH]"
$name = "DisabledComponents"
$value = "0xffffffff"

if (Test-Path $regPath) {
    $key = Get-ItemProperty -Path $regPath -Name $name -ErrorAction SilentlyContinue
    if ($key -and $key.DisabledComponents -eq [uint32]"0xffffffff") {
        Write-Output "IPv6 is disabled."
        exit 0 # Compliant
    }
}
Write-Output "IPv6 is enabled."
exit 1 # Non-compliant
