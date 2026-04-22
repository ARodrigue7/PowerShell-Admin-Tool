# Shares

Review SMB shares and their access assignments from the selected computer.

```script-inputs
[
  {
    "Name": "NameFilter",
    "Label": "Share name contains",
    "Type": "text",
    "Default": "",
    "Help": "Leave blank to return every share."
  },
  {
    "Name": "IncludeAdminShares",
    "Label": "Include admin shares",
    "Type": "bool",
    "Default": false,
    "Help": "Turn this on to include shares such as C$, ADMIN$, and IPC$."
  }
]
```

```powershell
param(
    [string]$NameFilter = '',
    [bool]$IncludeAdminShares = $false
)

$shares = Get-SmbShare

if ($NameFilter) {
    $shares = $shares | Where-Object { $_.Name -like "*$NameFilter*" }
}

if (-not $IncludeAdminShares) {
    $shares = $shares | Where-Object { $_.Special -ne $true }
}

foreach ($share in $shares) {
    foreach ($access in Get-SmbShareAccess -Name $share.Name) {
        [PSCustomObject]@{
            CSName            = $env:COMPUTERNAME
            Name              = $share.Name
            Path              = $share.Path
            Description       = $share.Description
            AccountName       = $access.AccountName
            AccessControlType = $access.AccessControlType
            AccessRight       = $access.AccessRight
            Time              = Get-Date
        }
    }
}
```
