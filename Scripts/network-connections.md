# Network Connections

Review active TCP connections together with the owning process and its parent.

```script-inputs
[
  {
    "Name": "State",
    "Label": "TCP state",
    "Type": "choice",
    "Default": "Established",
    "Options": ["All", "Established", "Listen", "CloseWait", "TimeWait"],
    "Help": "Choose All to skip state filtering."
  },
  {
    "Name": "ProcessNameFilter",
    "Label": "Process name contains",
    "Type": "text",
    "Default": "",
    "Help": "Use this to narrow results to a single process family."
  }
]
```

```powershell
param(
    [string]$State = 'Established',
    [string]$ProcessNameFilter = ''
)

$connections = Get-NetTCPConnection
if ($State -ne 'All') {
    $connections = $connections | Where-Object { $_.State -eq $State }
}

$processLookup = @{}
foreach ($process in Get-CimInstance -ClassName Win32_Process) {
    $processLookup[[int]$process.ProcessId] = $process
}

$connections | ForEach-Object {
    $process = $processLookup[[int]$_.OwningProcess]
    if ($ProcessNameFilter -and $process.Name -notlike "*$ProcessNameFilter*") {
        return
    }

    $parentProcess = $null
    if ($process -and $processLookup.ContainsKey([int]$process.ParentProcessId)) {
        $parentProcess = $processLookup[[int]$process.ParentProcessId]
    }

    [PSCustomObject]@{
        CSName          = $env:COMPUTERNAME
        LocalAddress    = $_.LocalAddress
        LocalPort       = $_.LocalPort
        RemoteAddress   = $_.RemoteAddress
        RemotePort      = $_.RemotePort
        State           = $_.State
        OwningProcess   = $_.OwningProcess
        ProcessName     = if ($process) { $process.Name } else { $null }
        ProcessId       = if ($process) { $process.ProcessId } else { $null }
        ParentProcessId = if ($parentProcess) { $parentProcess.ProcessId } else { $null }
        ParentProcess   = if ($parentProcess) { $parentProcess.Name } else { $null }
        CreationTime    = $_.CreationTime
        Time            = Get-Date
    }
}
```
