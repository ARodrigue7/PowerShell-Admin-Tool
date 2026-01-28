# Local Group Members

The **Get-LGroupMembers** function is a sophisticated PowerShell tool designed for querying and enumerating the members of local groups across specified remote Windows systems. This function executes a remote command to retrieve each group's membership details by initially attempting to use the **Get-LocalGroupMember** cmdlet and, if that fails (e.g., due to compatibility issues), falling back to querying **Win32_GroupUser** associations via **Get-WmiObject**. This dual-method approach ensures broader compatibility across different versions of Windows. From a security standpoint, understanding the composition of local groups is paramount, as it allows security professionals to audit access controls and verify that only authorized users are members of sensitive or privileged groups. This is critical for enforcing the principle of least privilege, detecting potential insider threats, and ensuring compliance with security policies and regulations. By automating the collection of group membership information, the **Get-LGroupMembers** function facilitates routine security audits, streamlines incident response processes, and aids in the quick identification of configuration drifts or unauthorized changes that could indicate security breaches or policy violations.

### Get-LGroupMembers Function

```powershell
function Get-LGroupMembers
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
            try
            {
                foreach ($name in (Get-WmiObject -Class Win32_Group).Name) {
                    [PSCustomObject]@{
                        CSName    = $env:COMPUTERNAME
                        GroupName = $name
                        Member    = (Get-LocalGroupMember $name)
        
                                                
                    }
                }
            }
            catch
            {
                foreach ($name in (Get-WmiObject -Class Win32_Group).Name) {
                    [PSCustomObject]@{
                        CSName    = $env:COMPUTERNAME
                        GroupName = $name
                        Member    = Get-WmiObject win32_groupuser | Where-Object {$_.groupcomponent -like "*$name*"} | ForEach-Object { 
                            $_.partcomponent –match ".+Domain\\=(.+)\\,Name\\=(.+)$" > $null 
                            $matches.trim('"') + "\\" + $matches.trim('"') 
                        }
                          
                    }
                }
            }
        }
    }
}
```

### Get-LGroupMembers Example Usage

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
$localGroupMembers = Get-LGroupMembers -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "LocalGroupMembersList.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$localGroupMembers | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "Local group members list saved to: $tempPath"
```

### Get-LGroupMembers Sample Output
Listed below is sample output in the LocalGroupMembersList.csv file that is created after running the script.
![Get-LGroupMembers](images/get-lgroup-members.png)