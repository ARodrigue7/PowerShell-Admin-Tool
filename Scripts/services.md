# Services

In the realm of security analysis, understanding the intricacies of services running on Windows machines is crucial. The `Get-ServiceInfo` function is designed to leverage the `Get-WmiObject win32_service` cmdlet, a powerful tool that offers a comprehensive view of service-related details not readily available through Get-Service. This cmdlet's ability to list associated process information, including the process ID and the parent process details, sets it apart. Such information is vital for assessing the services' context, including their origin and behavior, which could indicate normal operations or potentially malicious activity.
The function enriches this analysis by extracting detailed attributes for each service, including its display name, description, path, and startup configuration, alongside the vital process linkage. By also identifying the parent process, the function allows for a deeper dive into the service's execution context, offering insights into how services are launched and their interdependencies. This holistic approach to gathering service information is indispensable to ensure system integrity and security.

## Get-ServiceInfo Function

```powershell
function Get-ServiceInfo
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
        $services = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            Get-CimInstance -Class Win32_Service | ForEach-Object {
                [PSCustomObject]@{
                    "CSName"             = $_.SystemName
                    "PSComputerName"     = $_.PSComputerName
                    "ServiceName"        = $_.Name
                    "ServiceState"       = $_.State
                    "SystemName"         = $_.SystemName
                    "ServiceDisplayName" = $_.DisplayName
                    "ServiceDescription" = $_.Description
                    "PathName"           = $_.PathName
                    "InstallDate"        = $_.InstallDate
                    "ProcessId"          = $_.ProcessId
                    "ProcessName"        = (Get-WmiObject -Class Win32_Process -Filter "ProcessId='$($_.ProcessId)'").Name
                    "ParentProcessID"    = (Get-WmiObject -Class Win32_Process -Filter "ProcessId='$($_.ProcessId)'").ParentProcessID
                    "ParentProcessName"  = (Get-Process -ID (Get-WmiObject -Class Win32_Process -Filter "ProcessId='$($_.ProcessId)'").ParentProcessID).Name
                    "StartMode"          = $_.StartMode
                    "ExitCode"           = $_.ExitCode
                    "DelayedAutoStart"   = $_.DelayedAutoStart
                    "Time"               = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    "UTCTime"            = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }
        }
        $services
    }
} 
```

## Get-ServiceInfo Usage Example

```powershell
# Change creds as needed
$username = 'Administrator'
$password = 'P@55w0rd!!'

# Create Credential Object
[SecureString]$secureString = $password | ConvertTo-SecureString -AsPlainText -Force
[PSCredential]$creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureString

# Define Targets
$comps = ’192.168.1.2’, ‘192.168.1.3’, ‘192.168.1.4’

# Services function
$services = Get-ServiceInfo -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "ServiceList.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$services | Select CSName, PSComputerName, ServiceName, ServiceDisplayName, ServiceDescription, ServiceState, PathName, ProcessName, ProcessId, ParentProcessName, ParentProcessId, StartMode  | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "Service list saved to: $tempPath" 
```

## Get-ServiceInfo Sample Output\
Listed below is sample output in the ServicesList.csv file that is created after running the script.
![Get-ServiceInfo](images/services.png)