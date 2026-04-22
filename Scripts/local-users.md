# Local Users

List local accounts and highlight common security-relevant properties.

```script-inputs
[
  {
    "Name": "NameFilter",
    "Label": "User name contains",
    "Type": "text",
    "Default": "",
    "Help": "Leave blank to return every local account."
  },
  {
    "Name": "IncludeDisabled",
    "Label": "Include disabled accounts",
    "Type": "bool",
    "Default": true,
    "Help": "Turn this off to only show enabled local accounts."
  }
]
```

```powershell
param(
    [string]$NameFilter = '',
    [bool]$IncludeDisabled = $true
)

$users = Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount='True'"

if ($NameFilter) {
    $users = $users | Where-Object { $_.Name -like "*$NameFilter*" }
}

if (-not $IncludeDisabled) {
    $users = $users | Where-Object { -not $_.Disabled }
}

$users | ForEach-Object {
    [PSCustomObject]@{
        CSName                      = $env:COMPUTERNAME
        LocalUserName               = $_.Name
        LocalUserSID                = $_.SID
        LocalUserStatus             = $_.Status
        LocalUserAccountType        = $_.AccountType
        LocalUserCaption            = $_.Caption
        LocalUserDescription        = $_.Description
        LocalUserDomain             = $_.Domain
        LocalUserDisabled           = $_.Disabled
        LocalAccount                = $_.LocalAccount
        LocalUserLockout            = $_.Lockout
        LocalUserPasswordChangeable = $_.PasswordChangeable
        LocalUserPasswordExpires    = $_.PasswordExpires
        LocalUserPasswordRequired   = $_.PasswordRequired
        LocalUserSIDType            = $_.SIDType
        LocalUserFullName           = $_.FullName
        LocalUserAccountExpires     = $_.AccountExpires
        Time                        = Get-Date
    }
}
```
