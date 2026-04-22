# Registry Run Keys

Inspect common autorun registry locations for persistence entries.

```script-inputs
[
  {
    "Name": "Hive",
    "Label": "Hive",
    "Type": "choice",
    "Default": "All",
    "Options": ["All", "HKLM", "HKCU"],
    "Help": "Choose which hive to inspect."
  }
]
```

```powershell
param(
    [string]$Hive = 'All'
)

$runKeyMap = @(
    @{ Hive = 'HKLM'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' },
    @{ Hive = 'HKLM'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' },
    @{ Hive = 'HKCU'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
    @{ Hive = 'HKCU'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' }
)

if ($Hive -ne 'All') {
    $runKeyMap = $runKeyMap | Where-Object { $_.Hive -eq $Hive }
}

foreach ($entry in $runKeyMap) {
    if (-not (Test-Path -Path $entry.Path)) {
        continue
    }

    $keyValues = Get-ItemProperty -Path $entry.Path
    foreach ($property in $keyValues.PSObject.Properties) {
        if ($property.Name -in @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) {
            continue
        }

        [PSCustomObject]@{
            CSName    = $env:COMPUTERNAME
            Hive      = $entry.Hive
            KeyPath   = $entry.Path
            ValueName = $property.Name
            ValueData = $property.Value
            Time      = Get-Date
        }
    }
}
```
