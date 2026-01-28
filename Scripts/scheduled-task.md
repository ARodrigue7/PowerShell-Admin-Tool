# Scheduled Tasks

The **Get-SchTask** function is designed to collect and present detailed information about scheduled tasks from one or more remote Windows computers, utilizing PowerShell remoting to execute **Get-ScheduledTask** and **Get-ScheduledTaskInfo** on target machines. By aggregating data such as task name, author, execution path, and last run details into a custom object, this function provides a comprehensive overview of the automated tasks set up across a networked environment.

Analyzing scheduled tasks is crucial for cybersecurity because attackers often utilize this feature to persistently execute malicious software without user interaction. By establishing or modifying scheduled tasks, malware can ensure it remains active, bypasses user-based controls, and reinitiates after reboots or logouts, often without being detected by traditional antivirus software. For defenders, regularly reviewing scheduled tasks helps identify unauthorized or suspicious tasks that could indicate a compromise, enabling timely remediation and strengthening of security postures. This function aids in such analyses by offering visibility into the scheduled tasks configured on a system, including those that might be leveraged by attackers for persistence, privilege escalation, or lateral movement within a network.

### Get-SchTask Function

```powershell
function Get-SchTask
{
    [cmdletbinding()]
    Param
    (
        [Parameter(ValueFromPipeline=$true)]
        [string[]]
        $ComputerName,
        [pscredential]
        $Credential
    )
    Begin
    {
        If (!$Credential) {$Credential = Get-Credential}
    }
    Process
    {
        $tasks = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $schtasks = (Get-ScheduledTask)
            $taskInfoList = @()
            foreach ($task in $schtasks)
            {
                $taskinfo = Get-ScheduledTaskInfo -TaskPath $task.TaskPath -TaskName $task.TaskName
                $taskInfoList += [PSCustomObject]@{
                    CSName         = $env:COMPUTERNAME
                    PSComputerName = $task.PSComputerName
                    TaskName       = $task.TaskName
                    Author         = $task.Author
                    Date           = $task.Date
                    URI            = $task.URI
                    State          = $task.State
                    TaskPath       = $task.TaskPath
                    LastRunTime    = $taskinfo.LastRunTime
                    LastRunTimeUTC = ($taskinfo.LastRunTime).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    LastTaskResult = $taskinfo.LastTaskResult
                    NextRunTime    = $taskinfo.NextRunTime
                    Time           = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    UTCTime        = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }
            $taskInfoList
        }
        $tasks
    }   
}
```

### Get-SchTask Usage Example

```powershell
# Change creds as needed
$username = 'Administrator'
$password = 'P@55w0rd!!'

# Create Credential Object
[SecureString]$secureString = $password | ConvertTo-SecureString -AsPlainText -Force
[PSCredential]$creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureString

# Define Targets
$comps = ’192.168.1.2’, ‘192.168.1.3’, ‘192.168.1.4’

# Schtasks function
$schTasks = Get-SchTask -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "ScheduledTaskList.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$schTasks | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "Scheduled Task Info list saved to: $tempPath"
```

### Get-SchTask Sample Output
Listed below is sample output in the **ScheduledTaskList.csv** file that is created after running the script.
![Get-SchTask](images/get-schtask.png)