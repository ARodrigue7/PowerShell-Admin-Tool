# Logon History

Query recent security logon activity from the Security event log.

```script-inputs
[
  {
    "Name": "Days",
    "Label": "Days to search",
    "Type": "int",
    "Default": 7,
    "Required": true,
    "Help": "Look back this many days in the Security event log."
  },
  {
    "Name": "UserName",
    "Label": "Target user name contains",
    "Type": "text",
    "Default": "",
    "Help": "Leave blank to return logons for every user."
  }
]
```

```powershell
param(
    [int]$Days = 7,
    [string]$UserName = ''
)

$eventIds = @(4624, 4625, 4634)
$startTime = (Get-Date).AddDays(-1 * $Days)
$events = Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    Id        = $eventIds
    StartTime = $startTime
} -ErrorAction SilentlyContinue

$descriptionLookup = @{
    4624 = 'Successful logon'
    4625 = 'Failed logon'
    4634 = 'Logoff'
}

foreach ($event in $events) {
    [xml]$xml = $event.ToXml()
    $eventData = @{}

    foreach ($node in $xml.Event.EventData.Data) {
        if ($node.Name) {
            $eventData[$node.Name] = $node.'#text'
        }
    }

    $targetUser = $eventData.TargetUserName
    if ($UserName -and $targetUser -notlike "*$UserName*") {
        continue
    }

    [PSCustomObject]@{
        CSName               = $event.MachineName
        EventId              = $event.Id
        Activity             = $descriptionLookup[$event.Id]
        TimeCreated          = $event.TimeCreated
        TargetUserName       = $targetUser
        TargetDomainName     = $eventData.TargetDomainName
        LogonType            = $eventData.LogonType
        LogonProcessName     = $eventData.LogonProcessName
        AuthenticationPackage= $eventData.AuthenticationPackageName
        WorkstationName      = $eventData.WorkstationName
        IpAddress            = $eventData.IpAddress
        IpPort               = $eventData.IpPort
        SubjectUserName      = $eventData.SubjectUserName
        Message              = $event.Message
    }
}
```
