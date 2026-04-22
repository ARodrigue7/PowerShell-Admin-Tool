# Event Logs

Pull raw Windows event log entries from a chosen log and time window.

```script-inputs
[
  {
    "Name": "LogName",
    "Label": "Log name",
    "Type": "text",
    "Default": "Security",
    "Required": true,
    "Help": "Examples: Security, System, Application, Microsoft-Windows-PowerShell/Operational."
  },
  {
    "Name": "Days",
    "Label": "Days to search",
    "Type": "int",
    "Default": 2,
    "Required": true,
    "Help": "Look back this many days in the selected log."
  },
  {
    "Name": "MaxEvents",
    "Label": "Max events",
    "Type": "int",
    "Default": 200,
    "Required": true,
    "Help": "Limit the number of returned events."
  }
]
```

```powershell
param(
    [string]$LogName = 'Security',
    [int]$Days = 2,
    [int]$MaxEvents = 200
)

$startTime = (Get-Date).AddDays(-1 * $Days)
Get-WinEvent -FilterHashtable @{
    LogName   = $LogName
    StartTime = $startTime
} -MaxEvents $MaxEvents -ErrorAction SilentlyContinue | ForEach-Object {
    [PSCustomObject]@{
        CSName         = $_.MachineName
        Id             = $_.Id
        LevelDisplayName = $_.LevelDisplayName
        LogName        = $_.LogName
        ProviderName   = $_.ProviderName
        TaskDisplayName= $_.TaskDisplayName
        TimeCreated    = $_.TimeCreated
        RecordId       = $_.RecordId
        Message        = $_.Message
    }
}
```
