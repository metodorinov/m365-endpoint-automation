$regPath = [PATH]
$name = "DisabledComponents"
$value = 0xffffffff # 4294967295

if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force
}
Set-ItemProperty -Path $regPath -Name $name -Value $value -Type DWord
