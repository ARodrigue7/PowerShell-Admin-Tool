# Important Windows Events

Return high-signal event log activity from a chosen log and event ID set.

```script-inputs
[
  {
    "Name": "LogName",
    "Label": "Log name",
    "Type": "text",
    "Default": "Security",
    "Required": true,
    "Help": "Use a classic event log such as Security, System, or Application."
  },
  {
    "Name": "Days",
    "Label": "Days to search",
    "Type": "int",
    "Default": 7,
    "Required": true,
    "Help": "Look back this many days."
  },
  {
    "Name": "EventIds",
    "Label": "Event IDs",
    "Type": "text",
    "Default": "4624,4625,4688,4698,4702,4740,5156,5157,1102,4104",
    "Help": "Comma-separated event IDs to collect."
  }
]
```

```powershell
param(
    [string]$LogName = 'Security',
    [int]$Days = 7,
    [string]$EventIds = '4624,4625,4688,4698,4702,4740,5156,5157,1102,4104'
)

$parsedIds = @(
    $EventIds -split ',' |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ } |
    ForEach-Object { [int]$_ }
)

$startTime = (Get-Date).AddDays(-1 * $Days)
Get-WinEvent -FilterHashtable @{
    LogName   = $LogName
    Id        = $parsedIds
    StartTime = $startTime
} -ErrorAction SilentlyContinue | ForEach-Object {
    [xml]$xml = $_.ToXml()
    $eventData = @{}

    foreach ($node in $xml.Event.EventData.Data) {
        if ($node.Name) {
            $eventData[$node.Name] = $node.'#text'
        }
    }

    [PSCustomObject]@{
        CSName            = $_.MachineName
        Id                = $_.Id
        LogName           = $_.LogName
        ProviderName      = $_.ProviderName
        TimeCreated       = $_.TimeCreated
        RecordId          = $_.RecordId
        TargetUserName    = $eventData.TargetUserName
        SubjectUserName   = $eventData.SubjectUserName
        ProcessName       = $eventData.ProcessName
        WorkstationName   = $eventData.WorkstationName
        IpAddress         = $eventData.IpAddress
        Message           = $_.Message
    }
}
```
