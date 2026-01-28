### Utilizing the Collect-Windows-Events Script

The **collect-windows-events.ps1** script is a specialized tool crafted for cyber operators focused on the meticulous analysis and monitoring of Windows event logs. This script automates the extraction and exportation of event logs from specified Windows computers, targeting logs such as Security, Application, System, or any other specified by the user. It leverages the advanced capabilities of custom functions defined in the **collect-windows-artifacts.psm1** module to perform its tasks, particularly **Get-EVTX** for exporting event logs and **Get-ImportantEvent** for filtering and highlighting significant security events.

By requiring the user to specify target computer names along with authentication credentials (username and password), the script provides a secure and efficient means to gather event log data across multiple systems. This process is invaluable for cybersecurity incident response, compliance audits, and routine system monitoring, offering insights into activities and anomalies within the Windows operating environment.

The script introduces flexibility in its operation through parameters that allow users to specify the module path (indicating the location of the **collect-windows-artifacts.psm1** module), the output directory for saving the exported logs, the name of the log to be collected, and the time frame for the logs of interest. While default values are provided for the module path (a "Scripts" folder on the user's Desktop) and the output directory (the system's temporary folder), these can be customized to fit the user's specific needs.

To utilize the script, users need to supply the mandatory parameters---ComputerName, Username, and Password---and can optionally adjust the ModulePath, OutputDirectory, LogName, and Days parameters to refine their data collection criteria. An example usage of the script is as follows:

**.\collect-windows-events.ps1 -ComputerName "localhost" -Username "admin" -Password "password"**

This command initiates the script to collect, export, and enrich event log data, facilitating a thorough examination of system activities and security events.

This script simplifies the complex task of event log management and analysis, making it an essential asset for those tasked with safeguarding Windows environments or investigating security incidents.

### Collect-Windows-Events Script

Listed below is the **collect-windows-events.ps1** script.  This script should be located on the Desktop of the cyber operator's Windows VM in a directory called "Scripts".  It is imperative that the **collect-windows-artifacts.psm1** containing all of the custom functions remain in the Scripts directory or its location be specified using the **-ModulePath** parameter.

```powershell
<#
.SYNOPSIS
Collects and exports various Windows event logs.

.DESCRIPTION
This script collects and exports event logs specified Windows computers, including process lists, service information, etc.

.PARAMETER ComputerName
Specifies the target computer names.

.PARAMETER Username
Specifies the username for authentication.

.PARAMETER Password
Specifies the password for authentication.

.EXAMPLE
.\collect-windows-events.ps1 -ComputerName "localhost" -Username "admin" -Password "password"
#>

param (
    [Parameter(Mandatory = $true)]
    [string[]]
    $ComputerName,

    [Parameter(Mandatory = $true)]
    [string]
    $Username,

    [Parameter(Mandatory = $true)]
    [string]
    $Password,

    [Parameter(Mandatory = $false)]
    [string]
    $ModulePath = (Join-Path -Path ($env:USERPROFILE + '\Desktop\Scripts\') -ChildPath 'collect-windows-artifacts.psm1'),

    [Parameter(Mandatory = $false)]
    [string]
    $OutputDirectory = $env:TEMP,

    [Parameter(Mandatory = $false)]
    [string]
    $LogName = 'Security',

    [Parameter(Mandatory = $false)]
    [Int32]
    $Days = 30
)

Begin {
    # Import Module which contains functions for Windows artifact collection
    Import-Module $ModulePath
}

Process {

    # Define the number of days to go back in event history
    $daysBack = (-1 * $Days)

    # Loop through each computer in the list
    foreach ($comp in $ComputerName) {
        # Where the exported event log will be stored on the local computer
        $localPath = Join-Path -Path $OutputDirectory -ChildPath "${comp}_${LogName}.evtx"

        # Call Get-EVTX to export the event log from the remote computer
        Get-EVTX -ComputerName $comp -Credential $creds -LogName $LogName -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date) -LocalPath $localPath

        # Check if the exported event log exists
        if (Test-Path $localPath) {
            # Enrich the event log data
            $enrichedData = Get-ImportantEvent -EventLogPath $localPath

            # Export data to CSV
            $enrichedData | Export-CSv -Path (Join-Path -Path $env:TEMP -ChildPath "${comp}_${LogName}.csv") -NoTypeInformation

            # Export data to XML
            $enrichedData | Export-Clixml -Path (Join-Path -Path $env:TEMP -ChildPath "${comp}_${LogName}.xml")

        }
        else {
            Write-Warning "Failed to retrieve or export event log for $ComputerName."
        }
    }


    foreach ($comp in $ComputerName) {
        # Delete the event log file after processing
            $localPath = Join-Path -Path $env:TEMP -ChildPath "${comp}_${LogName}.evtx"
            Start-Process powershell.exe -ArgumentList "Remove-Item -Path '$localPath' -Force" -WindowStyle Hidden
    }



}

End {
    Write-Host "Windows event collection complete."
```