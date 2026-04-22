# System Info

Collect a concise hardware and operating system inventory from the selected computers.

```script-inputs
[
  {
    "Name": "IncludeBiosDetails",
    "Label": "Include BIOS details",
    "Type": "bool",
    "Default": true,
    "Help": "Turn this off when you only need operating system and processor data."
  }
]
```

```powershell
param(
    [bool]$IncludeBiosDetails = $true
)

$os = Get-CimInstance -ClassName Win32_OperatingSystem
$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$properties = [ordered]@{
    CSName                 = $env:COMPUTERNAME
    OperatingSystem        = $os.Caption
    OperatingSystemVersion = $os.Version
    Manufacturer           = $os.Manufacturer
    RegisteredOwner        = $os.RegisteredUser
    InstallDate            = $os.InstallDate
    LastBootTime           = $os.LastBootUpTime
    SerialNumber           = $os.SerialNumber
    CPUName                = $cpu.Name
    CPUStatus              = $cpu.Status
    CPUManufacturer        = $cpu.Manufacturer
    CPUCores               = $cpu.NumberOfCores
    CPUCurrentClockSpeed   = $cpu.CurrentClockSpeed
    Time                   = Get-Date
}

if ($IncludeBiosDetails) {
    $bios = Get-CimInstance -ClassName Win32_BIOS | Select-Object -First 1
    $properties.BIOSName = $bios.Name
    $properties.BIOSStatus = $bios.Status
    $properties.BIOSManufacturer = $bios.Manufacturer
    $properties.BIOSVersion = ($bios.SMBIOSBIOSVersion -join ', ')
}

[PSCustomObject]$properties
```
