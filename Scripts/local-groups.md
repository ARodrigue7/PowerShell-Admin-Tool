# Local Groups

List local groups from the selected computer and filter them by name when needed.

```script-inputs
[
  {
    "Name": "NameFilter",
    "Label": "Group name contains",
    "Type": "text",
    "Default": "",
    "Help": "Leave blank to return every local group."
  }
]
```

```powershell
param(
    [string]$NameFilter = ''
)

$groups = Get-WmiObject -Class Win32_Group -Filter "LocalAccount='True'"
if ($NameFilter) {
    $groups = $groups | Where-Object { $_.Name -like "*$NameFilter*" }
}

$groups | ForEach-Object {
    [PSCustomObject]@{
        CSName                 = $env:COMPUTERNAME
        LocalGroupName         = $_.Name
        LocalGroupSID          = $_.SID
        LocalGroupDomain       = $_.Domain
        LocalGroupCaption      = $_.Caption
        LocalGroupDescription  = $_.Description
        LocalGroupLocalAccount = $_.LocalAccount
        LocalGroupSIDType      = $_.SIDType
        Time                   = Get-Date
    }
}
```
