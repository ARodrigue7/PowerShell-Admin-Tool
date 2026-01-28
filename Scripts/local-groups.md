# Local Groups

The **Get-LGroup** function is a PowerShell script designed to extract and report on local group information across specified remote Windows computers, leveraging the **Get-WmiObject** cmdlet to query the **Win32_Group** class. This function plays a critical role in cybersecurity practices by enabling cyber operators to audit local group memberships and configurations efficiently.

### Get-LGroup Function

```powershell
function Get-LGroup
{
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline = $true)]
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
        Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            Get-WmiObject -Class Win32_Group
        } | ForEach-Object {
            [PSCustomObject]@{
                "CSName"                 = $env:COMPUTERNAME
                "LocalGroupName"         = $_.Name
                "LocalGroupSID"          = $_.SID
                "LocalGroupDomain"       = $_.Domain
                "LocalGroupCaption"      = $_.Caption
                "LocalGroupDescription"  = $_.Description
                "LocalGroupLocalAccount" = $_.LocalAccount
                "LocalGroupSIDType"      = $_.SIDType
            
            }
        }
    }
}
```

### Get-LGroup Example Usage

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
$localGroups = Get-LGroup -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "LocalGroupsList.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$localGroups | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "Local groups list saved to: $tempPath"
```

### Get-LGroup Sample Output
Listed below is sample output in the LocalGroupsList.csv file that is created after running the script.
![Get-LGroup](images/get-lgroup.png)