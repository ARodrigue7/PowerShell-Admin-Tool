# Startup Folders

The **Get-StartupFolders** function is meticulously designed to audit startup folders on specified remote Windows computers, identifying every script and executable set to run upon user login. This is achieved through PowerShell's **Invoke-Command**, which remotely accesses both the common startup folder (affecting all users) and the individual user's startup folder. For each item found, it gathers detailed information, including the file's name, size, last modification time, and a SHA1 hash of its contents. This level of detail is crucial for security purposes because startup folders are common targets for malware aiming to achieve persistence on a system. By analyzing the contents of these folders and monitoring for unexpected changes or unknown applications, cyber operators can detect and mitigate unauthorized or malicious software that seeks to execute at system startup. Furthermore, the SHA1 hash provides a means to verify the integrity of each file, facilitating the identification of tampering or unauthorized modifications. This proactive approach is essential for maintaining system integrity, ensuring that only legitimate and approved applications run at startup, thereby enhancing the overall security posture of an organization's IT infrastructure.

### Get-StartupFolders Function

```powershell
function Get-StartupFolders
{
    [CmdletBinding()]
    Param
    (
        [String[]]
        $ComputerName,
        [PSCredential]
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
        $startupData = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $startupFolders = @(
            @{
                Path        = ($env:APPDATA) + '\\Microsoft\\Windows\\Start Menu\\Programs\\Startup'
                Description = "User Startup Folder"
            }
            @{
                Path        = ($env:ProgramData) + '\\Microsoft\\Windows\\Start Menu\\Programs\\Startup'
                Description = "All Users Startup Folder"
            }
        )
            foreach ($folder in $startupFolders)
            {
                if (Test-Path -Path $folder.Path -PathType Container)
                {
                    $items = Get-ChildItem -Path $folder.Path -File
                    if ($items)
                    {
                        $items | ForEach-Object {
                            $file = $_
                            $fileInfo = $file | Get-Item
                            [PSCustomObject]@{
                                CSName                   = $env:COMPUTERNAME
                                StartupFolderPath        = $file.DirectoryName
                                StartupFolderDescription = $folder.Description
                                FileInfoName             = $fileInfo.Name
                                FileInfoSize             = $fileInfo.Length
                                LastWriteTime            = $fileInfo.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                LastWriteTimeUTC         = $fileInfo.LastWriteTime.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
                                Hash                     = (Get-FileHash -Path $file.FullName -Algorithm SHA1).Hash
                            }
                        }
                    }
                }
            }
        }
        return $startupData
    }
}
```

### Get-StartupFolders Example Usage

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
$startUps = Get-StartupFolders -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "StartupFolderList.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$startUps | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "Startup Folder list saved to: $tempPath"
```

### Get-StartupFolders Sample Output
Listed below is sample output in the StartupFolderList.csv file that is created after running the script.
![Get-StartupFolders](images/get-startup-folders.png)
