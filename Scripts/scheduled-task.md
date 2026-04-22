# Scheduled Tasks

Inspect scheduled tasks and filter by task name when needed.

```script-inputs
[
  {
    "Name": "TaskNameFilter",
    "Label": "Task name contains",
    "Type": "text",
    "Default": "",
    "Help": "Leave blank to return every scheduled task."
  },
  {
    "Name": "IncludeDisabled",
    "Label": "Include disabled tasks",
    "Type": "bool",
    "Default": true,
    "Help": "Turn this off to limit results to enabled tasks."
  }
]
```

```powershell
param(
    [string]$TaskNameFilter = '',
    [bool]$IncludeDisabled = $true
)

$tasks = Get-ScheduledTask

if ($TaskNameFilter) {
    $tasks = $tasks | Where-Object { $_.TaskName -like "*$TaskNameFilter*" }
}

if (-not $IncludeDisabled) {
    $tasks = $tasks | Where-Object { $_.State -ne 'Disabled' }
}

$tasks | ForEach-Object {
    $taskInfo = Get-ScheduledTaskInfo -TaskPath $_.TaskPath -TaskName $_.TaskName

    [PSCustomObject]@{
        CSName         = $env:COMPUTERNAME
        TaskName       = $_.TaskName
        TaskPath       = $_.TaskPath
        Author         = $_.Author
        Description    = $_.Description
        URI            = $_.URI
        State          = $_.State
        LastRunTime    = $taskInfo.LastRunTime
        LastTaskResult = $taskInfo.LastTaskResult
        NextRunTime    = $taskInfo.NextRunTime
        Time           = Get-Date
    }
}
```
