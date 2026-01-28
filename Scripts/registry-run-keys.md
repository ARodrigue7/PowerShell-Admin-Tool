# Registry Run Keys

The **Get-RegistryRun** function delves into the Windows Registry on specified remote computers to identify programs configured to execute automatically upon system startup or user login. It systematically checks a list of known registry keys within both the **Current User (HKCU)** and **Local Machine (HKLM)** hives that malware and legitimate software alike use to ensure persistence. For each entry found, the function extracts and reports the path, executable details, and associated process name, providing a timestamp for when the query was conducted. This reconnaissance is paramount for security, as malicious actors frequently leverage these registry locations to maintain persistence on compromised systems. By auditing these keys, cyber operators can detect and investigate unauthorized or suspicious programs set to run automatically, a critical step in identifying potential compromises, understanding the scope of an infection, or ensuring compliance with organizational security policies. The ability to remotely and programmatically inspect these registry keys streamlines the process of securing endpoints against both sophisticated threats and common malware.

### Get-RegistryRun Function

```powershell
function Get-RegistryRun
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
            $registryRunKeys = @(
                'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run',
                'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce',
                'HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run',
                'HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce',
                'HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunServicesOnce',
                'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunServicesOnce',
                'HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunServices',
                'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunServices'
            )
            $registryRunData = foreach ($keyPath in $registryRunKeys) {
                $keyName = $keyPath -replace '^.+\\\\'
                if (Test-Path $keyPath) {
                    $keyValues = Get-ItemProperty -Path $keyPath | Select-Object -Property *
                    
                    foreach ($valueName in $keyValues.PSObject.Properties.Name) {
                        $valueData = $keyValues.$valueName
                        
                        # Check if the value is a program configured for startup
                        if ($valueData -match '^.+\\.exe') {
                            $processName = [regex]::Match($valueData, '[^\\\\/]+(?=\\.exe)').Value
                            
                            if ([string]::IsNullOrEmpty($processName)) {
                                $processName = [io.path]::GetFileNameWithoutExtension($valueData)
                            }
                            
                            $keyName | Select-Object -Property @{Name = 'KeyPath'; Expression = {$keyPath}}, @{Name = 'KeyName'; Expression = {$_}}, @{Name = 'Details'; Expression = {$valueData}}, @{Name = 'ProcessName'; Expression = {$processName}}, @{Name = 'Time'; Expression = {(Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")}}
                        }
                    }
                }
            }
            $registryRunData
        }
    }
}
```

### Get-RegistryRun Example Usage

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
$registryRun = Get-RegistryRun -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "RegistryRunList.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$registryRun | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "Registry runkey list saved to: $tempPath"
```

### Get-RegistryRun Sample Output
Listed below is sample output in the RegistryRunList.csv file that is created after running the script.
![Get-RegistryRun](images/get-registry-run.png)
