### Logon History

The **Get-LogOnHistory** function is designed to audit user logon sessions across specified Windows computers, leveraging WMI objects to fetch detailed information about each logon event, including the user's domain, username, logon ID, and the nature of the logon session (e.g., network, service, interactive). By executing this function remotely with **Invoke-Command**, it compiles data from **win32_loggedonuser** and **win32_logonsession** to present a comprehensive view of user activities, enriched with logon types and precise session start times. From a security perspective, monitoring and analyzing logon history is crucial for detecting unauthorized access, tracking user activities, and understanding the context of security incidents. It enables cyber operators to quickly identify suspicious patterns such as logons at unusual times, logons from unexpected locations, or the use of service accounts for interactive logins. By providing insights into who accessed a system and how, the function aids in forensic investigations, compliance audits, and proactive threat hunting, making it an invaluable tool for maintaining the security and integrity of Windows environments.

### Get-LogOnHistory Function

```powershell
function Get-LogOnHistory
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
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }
    Process
    {
        Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $loggedOnUsers = Get-WmiObject win32_loggedonuser
            $sessions = Get-WmiObject win32_logonsession
            $logons = @()

            foreach ($user in $loggedOnUsers)
            {
                $user.Antecedent -match '.+Domain="(.+)",Name="(.+)"$' > $null
                $domain = $matches[1]
                $username = $matches[2]
    
                $user.Dependent -match '.+LogonId="(\d+)"$' > $null
                $LogonId = $matches[1]

                $logons += [PSCustomObject]@{
                    Domain  = $domain
                    User    = $username
                    LogonId = $LogonId
                }    
            }

            $logonDetail = foreach ($session in $sessions)
            {
                $logonType = switch ($session.LogonType)
                {
                    2 { "Network" }
                    3 { "Batch" }
                    4 { "Service" }
                    5 { "Unlock" }
                    7 { "Unlock (Cleartext)" }
                    8 { "Remote Interactive" }
                    9 { "Cached Interactive" }
                    Default { "Unknown" }
                }

                $startTime = [DateTime]::ParseExact($session.StartTime.Substring(0, 14), "yyyyMMddHHmmss", $null)

                [PSCustomObject]@{
                    CSName        = $env:COMPUTERNAME
                    LogonId       = $session.LogonId
                    LogonTypeId   = $session.LogonType
                    LogonType     = $logonType
                    LogonDomain   = ($logons | Where-Object { $_.LogonId -eq $session.LogonId }).Domain
                    LogonUser     = ($logons | Where-Object { $_.LogonId -eq $session.LogonId }).User
                    StartTime     = $session.StartTime
                    StartTimeUTC  = $startTime.ToUniversalTime()
                    Time          = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }

            $logonDetail
        }
    }    
}
```

### Get-LogOnHistory Example Usage

```powershell
# Change creds as needed
$username = 'Administrator'
$password = 'P@55w0rd!!'

# Create Credential Object
[SecureString]$secureString = $password | ConvertTo-SecureString -AsPlainText -Force
[PSCredential]$creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureString

# Define Targets
$comps = ’192.168.1.2’, ‘192.168.1.3’, ‘192.168.1.4’

# Local Groups function
$logons = Get-LogOnHistory -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "LogonHistory.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$logons | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "Logon history saved to: $tempPath" 
```

### Get-LogOnHistory Sample Output
Listed below is sample output in the **LogonHistory.csv** file that is created after running the script.
![Get-LogOnHistory](images/get-logon-history.png)
