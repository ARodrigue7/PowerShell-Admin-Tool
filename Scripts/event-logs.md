### Event Logs

The **Get-EVTX** and **Get-ImportantEvent** functions form an integral part of a security analysis toolkit designed for PowerShell, tailored to extract, process, and analyze Windows event logs from local or remote systems. The **Get-EVTX** function is engineered to remotely fetch event logs based on a specified time window and log name, utilizing PowerShell remoting and credentials for secure access, and then saving the logs to a local or specified path for further examination. Following the extraction, **the Get-ImportantEvent** function sifts through the fetched event logs, focusing on a curated list of security-relevant event IDs. It enriches the raw log data by extracting detailed information from each event's message content using regular expressions, such as account names, domains, logon IDs, and process information, which are crucial for detailed forensic analysis or real-time security monitoring.

These functions are paramount for security for several reasons. Firstly, they enable security cyber operators to efficiently gather and filter through vast amounts of log data across multiple systems, focusing on events critical for security postures like authentication successes and failures, process creation, and network activities, which are pivotal for identifying suspicious behaviors or confirming the scope of a security incident. Secondly, by automating the extraction and initial analysis phase, these tools significantly reduce the time to detect and respond to potential threats, a critical factor in mitigating damage in cyber incidents. Lastly, the detailed enrichment of event data aids in a deeper understanding of the context around each event, facilitating more informed decision-making in threat hunting, incident response, and compliance reporting tasks.

### Get-EVTX Function

```powershell
function Get-EVTX
{

 [cmdletbinding()]
 Param
 (
    [Parameter(ValueFromPipeline=$true,Mandatory=$true)]
    [string]
    $ComputerName,

    [Parameter(Mandatory=$true)]
    [pscredential]
    $Credential,

    [Parameter(Mandatory=$false)]
    [string]
    $LogName='Security',

    [Parameter(Mandatory=$false)]
    [string]
    $StartDate = (Get-Date).AddDays(-2),

    [Parameter(Mandatory=$false)]
    [string]
    $EndDate = (Get-Date),

    [Parameter(Mandatory=$false)]
    [string]
    $LocalPath = "$env:USERPROFILE\AppData\Local\Temp\" + $LogName + ".evtx"

)

Begin
{
    If (!$Credential) {$Credential = Get-Credential}
}

Process
{ 
    $export_path = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {"$env:USERPROFILE\AppData\Local\Temp\$using:LogName" + "_Exported.evtx"}

    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {

    # create time frame
    function GetMilliseconds ($date) {
        $ts = New-TimeSpan -Start $date -End (Get-Date)
        $ts.Ticks / 10000 # Divide by 10,000 to convert ticks to milliseconds
        } 

     $StartMilliseconds = GetMilliseconds $using:StartDate
     $EndMilliseconds = GetMilliseconds $using:EndDate

    # Event Log Query
    $query = "*[System[TimeCreated[timediff(@SystemTime) <= $StartMilliseconds and timediff(@SystemTime) >= $EndMilliseconds]]]"

    # Create the EventLogSession Object
    $EventSession = New-Object System.Diagnostics.Eventing.Reader.EventLogSession

     # Test if destination file already exists
    if(Test-Path -Path $using:export_path)
    {
       return Write-Error -Message "File already exists"
    }


    # Export the log and messages
    $EventSession.ExportLogAndMessages($using:LogName, [System.Diagnostics.Eventing.Reader.PathType]::LogName,$query, $using:export_path)


}#End of Script Block


# Create a session with the remote machine
$session = New-PSSession -ComputerName $ComputerName -Credential $Credential

# Copy the file from the remote machine to your local machine
Copy-Item -Path $export_path -Destination $LocalPath -FromSession $session

# Remove event log from remote machine
Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock { Remove-Item -Path $using:export_path }

}#End of Process
}



function Get-ImportantEvent {
    [CmdletBinding()]
    Param (
        
        [Parameter(Mandatory=$true)]
        [String]
        $EventLogPath

    )

    Process {
        
        # List of Event IDs to capture
        $eventIDs = @( 4624, 4634, 4688, 4698, 4702, 4740, 4625, 5152, 5154, 5155, 5156, 
        5157, 4648, 4672, 4673, 4769, 4771, 5140, 1102, 4104)

        $query = @(
        "Event/System[EventID=" + ($eventIDs -join " or EventID=") + "]"
         ) -join " and "
    
        # Fetch all relevant events at once
        $Events = Get-WinEvent -Path $EventLogPath -FilterXPath $query -ErrorAction Ignore
        
        # Enrich the event log
        foreach ($event in $Events) {
            $eventMessage = $event.Message

            # Regular expressions to extract field values
            $accountNamePattern = "Account Name:\s+(.+)"
            $accountDomainPattern = "Account Domain:\s+(.+)"
            $logonIDPattern = "Logon ID:\s+(0x[A-Fa-f0-9]+)"
            $logonTypePattern = "Logon Type:\s+(.+)"
            $processIDPattern = "Process ID:\s+0x([A-Fa-f0-9]+)\b"
            $processNamePattern = "Process Name:\s+(.+)"
            $workstationNamePattern = "Workstation Name:\s+(.+)"
            $sourceNetworkAddressPattern = "Source Network Address:\s+(.+)"
            $sourcePortPattern = "Source Port:\s+(.+)"
            $logonProcessPattern = "Logon Process:\s+(.+)"
            $parentProcessPattern = "Creator Process Name:\s+(.+)"
            $parentProcessIDPattern = "Creator Process ID:\s+0x([A-Fa-f0-9]+)\b"

            # Extract field values using regular expressions
            $accountName = [regex]::Match($eventMessage, $accountNamePattern).Groups[1].Value
            $accountDomain = [regex]::Match($eventMessage, $accountDomainPattern).Groups[1].Value
            $logonIDHexMatch = [regex]::Match($eventMessage, $logonIDPattern)
            $logonIDHex = $logonIDHexMatch.Groups[1].Value
            $logonType = [regex]::Match($eventMessage, $logonTypePattern).Groups[1].Value
            $processIDHexMatch = [regex]::Match($eventMessage, $processIDPattern)
            $processIDHex = $processIDHexMatch.Groups[1].Value
            $processPath = [regex]::Match($eventMessage, $processNamePattern).Groups[1].Value
            $workstationName = [regex]::Match($eventMessage, $workstationNamePattern).Groups[1].Value
            $sourceNetworkAddress = [regex]::Match($eventMessage, $sourceNetworkAddressPattern).Groups[1].Value
            $sourcePort = [regex]::Match($eventMessage, $sourcePortPattern).Groups[1].Value
            $logonProcess = [regex]::Match($eventMessage, $logonProcessPattern).Groups[1].Value
            $parentProcessPath = [regex]::Match($eventMessage, $parentProcessPattern).Groups[1].Value
            $parentProcessIDHexMatch = [regex]::Match($eventMessage, $parentProcessIDPattern)
            $parentProcessIDHex = $parentProcessIDHexMatch.Groups[1].Value


            # Convert LogonID from hexadecimal to decimal
            $logonID = 0
            if ($logonIDHexMatch.Success) {
                $logonID = [bigint]::Parse($logonIDHex.Substring(2), 'HexNumber')
            } else {$logonID = [PSCustomObject]@{logonID = $null}}

            # Convert ProcessID from hexadecimal to decimal
            $processID = 0
            if ($processIDHexMatch.Success) {
                $processID = [convert]::ToInt32($processIDHex, 16)
            }

            # Convert ParentProcessID from hexadecimal to decimal
            $parentProcessID = 0
            if ($parentProcessIDHexMatch.Success) {
                $parentProcessID = [convert]::ToInt32($parentProcessIDHex, 16)
            }

            # EventID to Description Mapping
            $EventIdDescriptionMapping = @{
            4624 = "An account was successfully logged on."
            4634 = "An account was logged off."
            4688 = "A new process has been created."
            4698 = "A scheduled task was created."
            4702 = "A scheduled task was updated."
            4740 = "A user account was locked out."
            4625 = "An account failed to log on."
            5152 = "The Windows Filtering Platform blocked a packet."
            5154 = "The Windows Filtering Platform has permitted an application or service to listen on a port for incoming connections."
            5155 = "The Windows Filtering Platform has blocked an application or service from listening on a port for incoming connections."
            5156 = "The Windows Filtering Platform has allowed a connection."
            5157 = "The Windows Filtering Platform has blocked a connection."
            4648 = "A logon was attempted using explicit credentials."
            4672 = "Special privileges assigned to a new logon."
            4673 = "A privileged service was called."
            4769 = "A Kerberos service ticket was requested."
            4771 = "Kerberos pre-authentication failed."
            5140 = "A network share object was accessed."
            1102 = "The audit log was cleared."
            4104 = "PowerShell Remote Command Execution"
        }

            # Create custom object with the extracted field values
            $eventData = [PSCustomObject]@{
                CSName               = $event.MachineName
                Id                   = $event.Id
                TimeCreated          = $event.TimeCreated.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                UTCTimeCreated       = $event.TimeCreated.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                Description          = $EventIdDescriptionMapping[$event.Id]
                LogName              = $event.LogName
                MachineName          = $event.MachineName
                RecordId             = $event.RecordId
                Time                 = (Get-Date).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
                Message              = $event.Message
                AccountName          = $accountName
                AccountDomain        = $accountDomain
                LogonID              = $logonID
                LogonType            = $logonType
                ProcessID            = $processID
                ProcessName          = if($ProcessPath) {Split-Path $ProcessPath -Leaf} else {$null}
                ProcessPath          = $processPath
                ParentProcessID      = $parentProcessID
                ParentProcessName    = if($ParentProcessPath) {Split-Path $ParentProcessPath -Leaf} else {$null}
                ParentProcessPath    = $parentProcessPath
                WorkstationName      = $workstationName
                SourceNetworkAddress = $sourceNetworkAddress
                SourcePort           = $sourcePort
                LogonProcess         = $logonProcess
            }

            $eventData
        }
    }
} 
```

### Get-EVTX Sample Usage

```powershell
# Change creds as needed
$username = 'Administrator'
$password = 'P@55w0rd!!'

# Create Credential Object
[SecureString]$secureString = $password | ConvertTo-SecureString -AsPlainText -Force
[PSCredential]$creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureString

# Define Targets
$comps = ’192.168.1.2’, ‘192.168.1.3’, ‘192.168.1.4’
# Define the number of days to go back in event history
$daysBack = -30

# LogName
$logName = 'Security'

# Loop through each computer in the list
foreach ($comp in $comps) {
    # Where the exported event log will be stored on the local computer
    $localPath = Join-Path -Path $env:TEMP -ChildPath "${comp}_${logName}.evtx"

    # Call Get-EVTX to export the event log from the remote computer
    Get-EVTX -ComputerName $comp -Credential $creds -LogName 'Security' -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date) -LocalPath $localPath

    # Check if the exported event log exists
    if (Test-Path $localPath) {
        # Enrich the event log data
        $enrichedData = Get-ImportantEvent -EventLogPath $localPath

        # Export data to CSV
        $enrichedData | Export-CSv -Path (Join-Path -Path $env:TEMP -ChildPath "${comp}_${logName}.csv") -NoTypeInformation

        # Export data to XML
        $enrichedData | Export-Clixml -Path (Join-Path -Path $env:TEMP -ChildPath "${comp}_${logName}.xml")

        # Delete the event log file after processing
        Remove-Item -Path $localPath -Force
    }
    else {
        Write-Warning "Failed to retrieve or export event log for $computerName."
    }
}
```

### Get-EVTX Sample Output
Listed below is a sample output of using the **Get-ImportantEvent** function.
![Get-EVTX](images/get-evtx.png)
