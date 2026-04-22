# Services

Review services, their current state, startup mode, and related process lineage.

```script-inputs
[
  {
    "Name": "NameFilter",
    "Label": "Service name contains",
    "Type": "text",
    "Default": "",
    "Help": "Leave blank to return every service."
  },
  {
    "Name": "State",
    "Label": "State",
    "Type": "choice",
    "Default": "All",
    "Options": ["All", "Running", "Stopped"],
    "Help": "Filter the results by current service state."
  }
]
```

```powershell
param(
    [string]$NameFilter = '',
    [string]$State = 'All'
)

$services = Get-CimInstance -ClassName Win32_Service
$processLookup = @{}

foreach ($process in Get-CimInstance -ClassName Win32_Process) {
    $processLookup[[int]$process.ProcessId] = $process
}

if ($NameFilter) {
    $services = $services | Where-Object {
        $_.Name -like "*$NameFilter*" -or $_.DisplayName -like "*$NameFilter*"
    }
}

if ($State -ne 'All') {
    $services = $services | Where-Object { $_.State -eq $State }
}

$services | ForEach-Object {
    $process = $processLookup[[int]$_.ProcessId]
    $parentProcess = $null

    if ($process -and $processLookup.ContainsKey([int]$process.ParentProcessId)) {
        $parentProcess = $processLookup[[int]$process.ParentProcessId]
    }

    [PSCustomObject]@{
        CSName             = $env:COMPUTERNAME
        ServiceName        = $_.Name
        ServiceDisplayName = $_.DisplayName
        ServiceDescription = $_.Description
        ServiceState       = $_.State
        StartMode          = $_.StartMode
        ProcessId          = $_.ProcessId
        ProcessName        = if ($process) { $process.Name } else { $null }
        ParentProcessId    = if ($parentProcess) { $parentProcess.ProcessId } else { $null }
        ParentProcessName  = if ($parentProcess) { $parentProcess.Name } else { $null }
        PathName           = $_.PathName
        ExitCode           = $_.ExitCode
        DelayedAutoStart   = $_.DelayedAutoStart
        Time               = Get-Date
    }
}
```
