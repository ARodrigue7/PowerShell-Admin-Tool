# Local Group Members

Enumerate members of local groups, either for a specific group or for every local group.

```script-inputs
[
  {
    "Name": "GroupName",
    "Label": "Group name",
    "Type": "text",
    "Default": "",
    "Help": "Leave blank to enumerate every local group."
  }
]
```

```powershell
param(
    [string]$GroupName = ''
)

$groups = Get-WmiObject -Class Win32_Group -Filter "LocalAccount='True'"
if ($GroupName) {
    $groups = $groups | Where-Object { $_.Name -like "*$GroupName*" }
}

foreach ($group in $groups) {
    $members = @()

    try {
        $members = Get-LocalGroupMember -Group $group.Name -ErrorAction Stop | ForEach-Object {
            $_.Name
        }
    }
    catch {
        $adsiGroup = [ADSI]"WinNT://$env:COMPUTERNAME/$($group.Name),group"
        $members = @($adsiGroup.psbase.Invoke('Members')) | ForEach-Object {
            $_.GetType().InvokeMember('Name', 'GetProperty', $null, $_, $null)
        }
    }

    if ($members.Count -eq 0) {
        [PSCustomObject]@{
            CSName    = $env:COMPUTERNAME
            GroupName = $group.Name
            Member    = $null
            Time      = Get-Date
        }
        continue
    }

    foreach ($member in $members) {
        [PSCustomObject]@{
            CSName    = $env:COMPUTERNAME
            GroupName = $group.Name
            Member    = $member
            Time      = Get-Date
        }
    }
}
```
