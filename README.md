# PowerShell Remote Admin Tool

![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1%2B-blue)

A self-contained, module-based PowerShell WPF application for remote system administration. This tool dynamically loads administrative functions from a local PowerShell module (`functions.psm1`) and executes them asynchronously as background jobs against one or multiple target computers.

## Key Features

*   **Module-Based Architecture**: Automatically imports all custom administrative functions from a unified local module (`functions.psm1`). Functions are automatically populated in the UI dropdown.
*   **Forensic EVTX Collection Engine**: Upgraded `Get-EVTX` with multi-protocol extraction (SMB -> WinRM -> WMI), log category presets (`DFIR`, `All`, `Custom`), and lock-free `wevtutil` remote exports.
*   **Interactive Modal Popups**: Smart GUI popups for `Get-EVTX` (preset picker), `Get-RemoteArtifact` (remote path prompt), and `Get-CriticalEventXML` (date-range filter), keeping operator workflow intuitive.
*   **Unified Relative Output Hierarchy**: All baselines, EVTX logs, and pulled artifacts are saved relative to the tool directory under `./Output/` (`./Output/EVTX_Logs/`, `./Output/Baselines/`, `./Output/Artifacts/`).
*   **Asynchronous Background Execution**: Run administrative queries in parallel as background processes using `Start-Job`, keeping the user interface completely responsive and preventing freezes.
*   **Real-Time Job Monitoring**: Active background jobs are monitored and collected via a dispatcher timer. Output (including remote computer names and any error records) is formatted and streamed directly to the Global Output Console upon completion.
*   **Quick OS Info**: Dedicated action to immediately query basic Operating System details, computer model, and calculating system uptime for target computers.
*   **Alternate Credentials Support**: Run functions as another user by providing credentials (username and password) via the GUI.
*   **Multi-Computer Targeting**:
    *   Enter comma-separated computer names or IP addresses.
    *   Import a list of computer targets directly from a `.txt` or `.csv` file.
*   **Control Panel Console**: All execution output, status messages, and errors are color-coded in a consolidated console. Includes quick buttons to cancel all running background jobs or clear console logs.

---

## File Structure

*   `AdminTool.ps1`: The main graphical user interface (WPF application). Handles UI layout, event loop, target resolution, background job starting, interactive popups, and result aggregation.
*   `functions.psm1`: The PowerShell script module containing all custom administrative, forensic log collection, and baselining functions.
*   `Output/`: Standardized output directory for all generated CSV baselines, exported `.evtx` log packages, and collected artifacts.
*   `.gitignore`: Prevents VS/IDE metadata from being tracked.

---

## Getting Started

### Prerequisites

*   Windows PowerShell 5.1 or later.
*   .NET Framework 4.5 or later (typically installed by default on Windows).

### Installation & Run

1.  Download `AdminTool.ps1` and `functions.psm1` and place them in the same directory.
2.  Open a PowerShell terminal and navigate to the directory.
3.  Ensure your execution policy allows running local scripts:
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```
4.  Launch the tool:
    ```powershell
    .\AdminTool.ps1
    ```

---

## Writing Functions for the Module (`functions.psm1`)

All functions exported by `functions.psm1` are automatically loaded into the select dropdown in the tool. To integrate seamlessly with the remote targeting and credential system, functions should follow this pattern:

```powershell
function Get-MyCustomStatus {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {
        # Execute commands against target computer(s)
        Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            # Target logic here
        }
    }
}
```

---

## Remote WinRM Configuration

When querying remote computers, you may need to enable and configure Windows Remote Management (WinRM). 

Run the following command on your local machine in an **Administrator PowerShell** window to add remote hosts to your `TrustedHosts` list:

```powershell
# Replace "IP_OR_HOSTNAME" with the actual IP address or name of your target machine, or use "*" for all
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "IP_OR_HOSTNAME" -Force
```

On target machines, ensure WinRM is enabled:
```powershell
Enable-PSRemoting -Force
```
