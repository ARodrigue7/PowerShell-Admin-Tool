# System Info

The **Get-SystemInfo** function is a PowerShell tool designed to aggregate and present a comprehensive overview of critical system information from one or more remote computers. By **leveraging Get-CimInstance** cmdlets for querying system components such as the **OS**, **CPU**, and **BIOS**, it constructs a detailed snapshot encompassing various hardware and software aspects.

### Get-SystemInfo Function

```powershell
function Get-SystemInfo
{
    [cmdletbinding()]
    Param
    (
        [Parameter()]
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
        $systemInfo = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $cpu = Get-CimInstance -ClassName Win32_Processor
        $bios = Get-CimInstance -ClassName Win32_BIOS
        [PSCustomObject]@{
                "CSName"                 = $os.CSName
                "OperatingSystem"        = $os.Caption
                "OperatingSystemVersion" = $os.Version
                "Manufacturer"           = $os.Manufacturer
                "RegisteredOwner"        = $os.RegisteredUser
                "InstallDate"            = $os.InstallDate.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                "LastBootTime"           = $os.LastBootUpTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                "SerialNumber"           = $os.SerialNumber
                "CPUName"                = $cpu.Name
                "CPUStatus"              = $cpu.Status
                "CPUManufacturer"        = $cpu.Manufacturer
                "CPUCores"               = $cpu.NumberOfCores
                "CPUCurrentClockSpeed"   = $cpu.CurrentClockSpeed
                "BIOSName"               = $bios.Name
                "BIOSStatus"             = $bios.Status
                "BIOSManufacturer"       = $bios.Manufacturer
                
            }
        }
        $systemInfo
    }
      
}
```

### Get-SystemInfo Usage Example

```powershell
# Change creds as needed
$username = 'Administrator'
$password = 'P@55w0rd!!'

# Create Credential Object
[SecureString]$secureString = $password | ConvertTo-SecureString -AsPlainText -Force
[PSCredential]$creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureString

# Define Targets
$comps = ’192.168.1.2’, ‘192.168.1.3’, ‘192.168.1.4’

# System Information function
$sysInfo = Get-SystemInfo -ComputerName $comps -Credential $creds

# Define the path to save the file
$fileName = "SystemInfoList.csv"
$tempPath = Join-Path -Path $env:TEMP -ChildPath $fileName

#Export the process information to a CSV file
$sysinfo | Export-Csv -Path $tempPath  -NoTypeInformation

# Tell user where file is saved
Write-Host "SystemInfo list saved to: $tempPath"
```

### Get-SystemInfo Sample Output
Listed below is sample output in the SystemInfoList.csv file that is created after running the script.
![Get-SystemInfo](images/get-systeminfo.png)