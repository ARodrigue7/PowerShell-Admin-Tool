# Processes

In PowerShell, there are several methods to retrieve running processes from a machine, notably through the `Get-Process` and `Get-WmiObject win32_Process` cmdlets. Our chosen approach utilizes Get-WmiObject win32_Process for its capability to access comprehensive process details, including parent and grandparent process information—an essential factor for host analysts investigating the origin of processes. This data is pivotal when determining whether a process has been initiated from a trustworthy source, as Get-Process lacks the ability to provide parent process details. Furthermore, our function enhances the investigation by extracting the grandparent process information and computing a hash of the executable path, offering a more detailed forensic insight into running processes.  Listed below, you can see the function along with an example of its use.

```powershell
function Get-WmiProcess {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
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
        $processes = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $processes = Get-WmiObject win32_Process
            $processLookup = @{}

            # Create a lookup table for process IDs and names
            foreach ($process in $processes) {
                $processLookup[$process.ProcessID] = $process.Name
            }

            $results = @()

            foreach ($process in $processes) {
                $parentProcessID = $process.ParentProcessID
                $parentProcessName = $processLookup[$parentProcessID] -as [string]

                $grandparentProcessName = $null
                $grandparentProcessID = $null

                if ($parentProcessName) {
                    $grandparentProcessID = (Get-WmiObject win32_Process -Filter "ProcessID = $parentProcessID" |
                        Select-Object -ExpandProperty ParentProcessID) -as [uint32]

                    if ($grandparentProcessID -ne 0) {
                        $grandparentProcessName = $processLookup[$grandparentProcessID] -as [string]
                    }
                }

                $lineageHash = [System.Security.Cryptography.MD5]::Create().ComputeHash(
                    [System.Text.Encoding]::UTF8.GetBytes("$grandparentProcessName|$parentProcessName|$($process.Name)")
                )
                $lineageHashString = [System.BitConverter]::ToString($lineageHash).Replace("-", "")

                # Hash the program if possible
                if ((Get-Command Get-FileHash -ErrorAction SilentlyContinue) -and $process.Path)
                {
                    $filehash = (Get-FileHash -Path $process.Path -Algorithm SHA1).Hash
                }
                else
                {
                    $filehash = ""
                }

                $results += [PSCustomObject]@{
                    "CSName"                 = $process.CSName
                    "ProcessName"            = $process.Name
                    "ProcessID"              = $process.ProcessID
                    "ParentProcessName"      = $parentProcessName
                    "ParentProcessID"        = $parentProcessID
                    "GrandParentProcessName" = $grandparentProcessName
                    "GrandParentProcessID"   = $grandparentProcessID
                    "HandleCount"            = $process.HandleCount
                    "ThreadCount"            = $process.ThreadCount
                    "Path"                   = $process.Path
                    "FileHash"               = $filehash
                    "CommandLine"            = $process.CommandLine
                    "PSComputerName"         = $process.PSComputerName
                    "RunspaceId"             = $process.RunspaceId
                    "PSShowComputerName"     = $true
                    "Time"                   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    "UTCTime"                = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    "LineageHash"            = $lineageHashString
                }
            }

            $results
        }

        $processes
    }
}
```

## Get-WmiProcess Usage Example

```powershell
# Change creds as needed
$username = 'Administrator'
$password = 'P@55w0rd!!'

# Create Credential Object
[SecureString]$secureString = $password | ConvertTo-SecureString -AsPlainText -Force
[PSCredential]$creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureString

# Define Targets
$comps = ’192.168.1.2’, ‘192.168.1.3’, ‘192.168.1.4’

# Process function
$process = Get-WmiProcess -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "ProcessList.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$process | Select CSName, PSComputerName, ProcessName, ProcessID, Path, FileHash, CommandLine, ParentProcessName, ParentProcessID, GrandParentProcessName, GrandParentProcessID, HandleCount, ThreadCount | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "Process list saved to: $tempPath" 
```

## Get-WmiProcess Sample Output
Listed below is sample output in the **ProcessList.csv** file that is created after running the script.
![Get-WmiProcess](images/get-wmi-process.png)