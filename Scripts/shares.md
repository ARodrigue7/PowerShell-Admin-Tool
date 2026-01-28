### Shares

The **Get-ShareInfo** function utilizes PowerShell to remotely gather and report on the configuration and access permissions of SMB shares across specified Windows computers. By leveraging the **Get-SmbShare** and **Get-SmbShareAccess** cmdlets within a script block executed via Invoke-Command, it efficiently compiles a list of shares and their corresponding access controls, enriching this data with a timestamp for when the information was retrieved. This function is critically important for security because SMB shares are a common vector for data exfiltration, malware spread, and lateral movement within a network. Misconfigured shares with overly permissive access rights can inadvertently expose sensitive data to unauthorized users or attackers. By systematically auditing SMB share permissions, cyber operators can ensure that only intended users have access, identify potential vulnerabilities, and mitigate risks associated with open or misconfigured network shares. This proactive approach helps maintain the confidentiality, integrity, and availability of shared resources, aligning with best practices for network security and data protection.

### Get-ShareInfo Function

```powershell
function Get-ShareInfo
{
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
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
            foreach ($share in (Get-SmbShare).Name) {
                $accessInfo = Get-SmbShareAccess $share
                $accessInfo | Add-Member -NotePropertyName "Time" -NotePropertyValue (Get-Date).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
                $accessInfo
            }
        }
    }    
} 
```

### Get-ShareInfo Example Usage

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
$shares = Get-ShareInfo -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "Shares.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$shares | Select PSComputerName, Name, AccountName, AccessControlType, AccessRight | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "Shares list saved to: $tempPath" 
```

### Get-ShareInfo Sample Output
Listed below is sample output in the **Shares.csv** file that is created after running the script.
![Get-ShareInfo](images/get-share-info.png)