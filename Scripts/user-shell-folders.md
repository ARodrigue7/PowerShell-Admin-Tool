# User Shell Folders

Inspect registry-backed shell folder locations that are often abused for persistence or redirection.

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

$shellFoldersKeys = @(
    @{ Hive = 'HKCU'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' },
    @{ Hive = 'HKCU'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' },
    @{ Hive = 'HKLM'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' },
    @{ Hive = 'HKLM'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' }
)

if ($Hive -ne 'All') {
    $shellFoldersKeys = $shellFoldersKeys | Where-Object { $_.Hive -eq $Hive }
}

foreach ($entry in $shellFoldersKeys) {
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
