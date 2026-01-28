# Local Users

The **Get-LUser** function is crafted to collect detailed information about local user accounts on one or multiple remote Windows computers, leveraging PowerShell's **Get-WmiObject** cmdlet to query the **Win32_UserAccount** class for accounts that are local to those systems. It retrieves a wealth of information about each user, including the username, security identifier (SID), account type, description, whether the account is disabled or locked out, password policies, and more, all of which are crucial for security analysis and compliance auditing. From a cybersecurity perspective, analyzing local user accounts is essential because it helps identify unauthorized accounts, accounts with weak or non-expiring passwords, and accounts that shouldn't be active or are potentially compromised. This information is foundational for ensuring that only authorized users have access to systems and that user account policies comply with security best practices, thereby reducing the attack surface and mitigating potential insider threats.

### Get-LUser Function

```powershell
function Get-LUser
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
        $usersData = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount='True'" | ForEach-Object {
                [PSCustomObject]@{
                    "CSName"                      = $env:COMPUTERNAME
                    "LocalUserName"               = $_.Name
                    "LocalUserSID"                = $_.SID
                    "LocalUserStatus"             = $_.Status
                    "LocalUserAccountType"        = $_.AccountType
                    "LocalUserCaption"            = $_.Caption
                    "LocalUserDescription"        = $_.Description
                    "LocalUserDomain"             = $_.Domain
                    "LocalUserDisabled"           = $_.Disabled
                    "LocalAccount"                = $_.LocalAccount
                    "LocalUserLockout"            = $_.Lockout
                    "LocalUserPasswordChangeable" = $_.PasswordChangeable
                    "LocalUserPasswordExpires"    = $_.PasswordExpires
                    "LocalUserPasswordRequired"   = $_.PasswordRequired
                    "LocalUserSIDType"            = $_.SIDType
                    "LocalUserFullName"           = $_.FullName
                    "LocalUserAccountExpires"     = $_.AccountExpires
                    "Time"                        = (Get-Date).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
                    "UTCTime"                     = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
                }
            }
        }
        return $usersData
    }
}
```

### Get-LUser Example Usage

```powershell
# Change creds as needed
$username = 'Administrator'
$password = 'P@55w0rd!!'

# Create Credential Object
[SecureString]$secureString = $password | ConvertTo-SecureString -AsPlainText -Force
[PSCredential]$creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureString

# Define Targets
$comps = ’192.168.1.2’, ‘192.168.1.3’, ‘192.168.1.4’

# Local Users function
$localUsers = Get-LUser -ComputerName 'localhost' -Credential $creds

# Define the path to save the file
$fileName = "LocalUserList.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$localUsers | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "Local user list saved to: $tempPath"
```

### Get-LUser Sample Output
Listed below is sample output in the **LocalUserList.csv** file that is created after running the script.
![Get-LUser](images/get-luser.png)