### User Shell Folders

The **Get-RegistryUserShellFolders** function is crafted to query specific Windows Registry keys related to User Shell and Shell Folders on specified remote computers. It inspects both the **Current User (HKCU)** and **Local Machine (HKLM)** hives for entries that dictate the paths to various system and user-specific directories, such as startup programs, templates, and document folders. By collecting and analyzing this data, the function aids cyber operators in identifying potentially malicious redirections or modifications. Malware and attackers often manipulate these registry keys to persistently execute malicious payloads, redirect document saving paths to monitored folders, or obscure files in unexpected directories. By monitoring these keys for unauthorized changes, security teams can detect signs of compromise early, prevent data leakage, and ensure that essential shell folders have not been tampered with. This proactive stance is crucial for maintaining the integrity of user environments and protecting against sophisticated persistence mechanisms employed by attackers.

### Get-RegistryUserShellFolders Function
```powershell
function Get-RegistryUserShellFolders {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
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
        Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $shellFoldersKeys = @(
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders',
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
            )

            $shellFoldersData = foreach ($keyPath in $shellFoldersKeys) {
                if (Test-Path $keyPath) {
                    $keyValues = Get-ItemProperty -Path $keyPath | Select-Object -Property *
                    $keyName = $keyPath -replace '^.+\\'

                    foreach ($valueName in $keyValues.PSObject.Properties.Name) {
                        $valueData = $keyValues.$valueName
                        [PSCustomObject]@{
                            KeyPath     = $keyPath
                            Key         = $keyName
                            ValueName   = $valueName
                            ValueData   = $valueData
                            Time        = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
                        }
                    }
                }
            }

            $shellFoldersData
        }
    }
} 
```

### Get-RegistryUserShellFolders Sample Usage

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
$userShell = Get-RegistryUserShellFolders -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "UserShell.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$userShell | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "User shell list saved to: $tempPath"
```

### Get-RegistryUserShellFolders Sample Output
Listed below is sample output in the **UserShell.csv** file that is created after running the script.
![Get-RegistryUserShellFolders](images/get-registry-user-shell-folders.png)