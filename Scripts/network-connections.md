# Network Connections

In the pursuit of monitoring and securing network activities within a Windows environment, it's imperative to gain visibility into both inbound and outbound connections. The **Get-Connection** function emerges as a critical tool for this purpose, leveraging PowerShell to collect data on established TCP connections with pertinent process details. This function utilizes the **Get-NetTCPConnection** cmdlet to enumerate active connections and couples it with the **Get-CimInstance Win32_Process** cmdlet to fetch process information, thereby offering a holistic view of network interactions.

### Get-Connection Function

```powershell
function Get-Connection {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [String[]]
        $ComputerName,
        [PSCredential]
        $Credential
    )
    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }
    Process {
        $connections = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $processes = Get-CimInstance Win32_Process
            $connections = Get-NetTCPConnection -State Established
            $connections | ForEach-Object {
                $connection = $_
                $process = $processes | Where-Object { $_.ProcessID -eq $connection.OwningProcess }
                $parentProcessID = $process.ParentProcessID
                $parentProcess = $processes | Where-Object { $_.ProcessID -eq $parentProcessID }
                [PSCustomObject]@{
                    PSComputerName   = $connection.PSComputerName
                    CSName           = $process.CSName
                    LocalAddress     = $connection.LocalAddress
                    LocalPort        = $connection.LocalPort
                    RemoteAddress    = $connection.RemoteAddress
                    RemotePort       = $connection.RemotePort
                    State            = $connection.State
                    OwningProcess    = $connection.OwningProcess
                    ProcessName      = $process.Name
                    ProcessID        = $process.ProcessId
                    ParentProcessID  = $parentProcess.ProcessID
                    ParentProcess    = $parentProcess.Name
                    CreationTime     = $connection.CreationTime
                    Time             = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    UTCTime          = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }
        }
        $connections
    }
}
```

### Get-Connection Usage Example

```powershell
# Change creds as needed
$username = 'Administrator'
$password = 'P@55w0rd!!'

# Create Credential Object
[SecureString]$secureString = $password | ConvertTo-SecureString -AsPlainText -Force
[PSCredential]$creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureString

# Define Targets
$comps = ’192.168.1.2’, ‘192.168.1.3’, ‘192.168.1.4’

# Connections function
$connections = Get-Connection -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "ConnectionList.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$connections | Select CSName, PSComputerName, LocalAddress, LocalPort, RemoteAddress, RemotePort, State, ProcessName, ProcessID, ParentProcess, ParentProcessID, CreationTime  | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "Connection list saved to: $tempPath"
```

### Get-Connection Sample Output
Listed below is sample output in the **ConnectionsList.csv** file that is created after running the script.
![Get-Connection](images/get-connection.png)