# Processes

Inspect running processes with parent and grandparent context for quick triage.

```script-inputs
[
  {
    "Name": "NameFilter",
    "Label": "Process name contains",
    "Type": "text",
    "Default": "",
    "Help": "Leave blank to return every process."
  },
  {
    "Name": "IncludeCommandLine",
    "Label": "Include command line",
    "Type": "bool",
    "Default": true,
    "Help": "Turn this off if you only need process lineage and file path details."
  }
]
```

```powershell
param(
    [string]$NameFilter = '',
    [bool]$IncludeCommandLine = $true
)

$processes = Get-CimInstance -ClassName Win32_Process
$lookup = @{}

foreach ($process in $processes) {
    $lookup[[int]$process.ProcessId] = $process
}

if ($NameFilter) {
    $processes = $processes | Where-Object { $_.Name -like "*$NameFilter*" }
}

$processes | ForEach-Object {
    $parentProcess = $null
    $grandparentProcess = $null

    if ($lookup.ContainsKey([int]$_.ParentProcessId)) {
        $parentProcess = $lookup[[int]$_.ParentProcessId]
        if ($parentProcess -and $lookup.ContainsKey([int]$parentProcess.ParentProcessId)) {
            $grandparentProcess = $lookup[[int]$parentProcess.ParentProcessId]
        }
    }

    $fileHash = $null
    if ($_.ExecutablePath -and (Test-Path -Path $_.ExecutablePath -PathType Leaf)) {
        try {
            $fileHash = (Get-FileHash -Path $_.ExecutablePath -Algorithm SHA1 -ErrorAction Stop).Hash
        }
        catch {
            $fileHash = $null
        }
    }

    [PSCustomObject]@{
        CSName                 = $env:COMPUTERNAME
        ProcessName            = $_.Name
        ProcessId              = $_.ProcessId
        ParentProcessName      = if ($parentProcess) { $parentProcess.Name } else { $null }
        ParentProcessId        = if ($parentProcess) { $parentProcess.ProcessId } else { $null }
        GrandParentProcessName = if ($grandparentProcess) { $grandparentProcess.Name } else { $null }
        GrandParentProcessId   = if ($grandparentProcess) { $grandparentProcess.ProcessId } else { $null }
        ExecutablePath         = $_.ExecutablePath
        FileHash               = $fileHash
        CommandLine            = if ($IncludeCommandLine) { $_.CommandLine } else { $null }
        HandleCount            = $_.HandleCount
        ThreadCount            = $_.ThreadCount
        CreationDate           = $_.CreationDate
        Time                   = Get-Date
    }
}
```
