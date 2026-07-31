# Guidance for AI Agents Working on PowerShell Remote Admin Tool

## Architecture Overview

1. **Unified Module (`functions.psm1`)**:
   - Contains all remote administrative, auditing, baselining, and containment functions.
   - On startup, exported functions are categorized into investigative functions (`ScriptSelectionComboBox`) and destructive remediation actions (`ContainActionComboBox`).

2. **Graphical Interface (`AdminTool.ps1`)**:
   - Built with WPF (PresentationFramework) via XAML.
   - Dynamically loads `functions.psm1` on startup into dual ComboBoxes (`ScriptSelectionComboBox` and `ContainActionComboBox`).
   - Features active target host indicator banners on action tabs, real-time function search/filter textboxes (`FunctionFilterTextBox`, `ContainFilterTextBox`), quick target host management buttons (`Remove Selected`, `Clear All`), and host-filtered console output (`ConsoleHostFilterComboBox`).
   - Executes administrative queries asynchronously in background jobs (`Start-Job`) monitored by a `DispatcherTimer`.

3. **Legacy Host Compatibility & WMI/CIM Fallback Pattern**:
   - Targets may run older Windows Server OS (e.g. 2008 R2, 2012) with PowerShell 2.0/3.0.
   - Core functions running remote `ScriptBlock`s MUST check CIM availability and fall back to WMI:
     ```powershell
     $useCim = [bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
     if ($useCim) {
         Get-CimInstance -ClassName Win32_Class ...
     } else {
         Get-WmiObject -Class Win32_Class ...
     }
     ```
   - **Performance Critical**: Always cache `$useCim = [bool](Get-Command Get-CimInstance ...)` ONCE at the top of the remote `ScriptBlock`, rather than calling `Get-Command` inside loops.

4. **Baselining Functions**:
   - `Get-HostBaseline`: Queries host network state, processes, services, connections, shares, persistence (registry run keys, startup folders, scheduled tasks), logon history, local group members, shell folders, and prefetches. Default output path: `./Output/Baselines/HostBaselines_<timestamp>`.
   - `Get-DomainBaseline`: Invokes `Get-HostBaseline` first, then runs Active Directory queries (domain controllers, users, groups, memberships, GPOs, protected users, service accounts, and AD event logs). Default output path: `./Output/Baselines/DomainBaselines_<timestamp>`.
   - Use `Invoke-BaselineExport` to handle standard CSV output generation for baseline queries.

5. **Unified Output Directory Structure (`./Output/`)**:
   - All exported data, logs, baselines, and artifacts MUST be saved relative to the current tool location under `./Output/`:
     - EVTX Logs (`Get-EVTX`): `./Output/EVTX_Logs/<hostname>_<timestamp>/`
     - Host Baselines (`Get-HostBaseline`): `./Output/Baselines/HostBaselines_<timestamp>/`
     - Domain Baselines (`Get-DomainBaseline`): `./Output/Baselines/DomainBaselines_<timestamp>/`
     - Remote Artifacts (`Get-RemoteArtifact`): `./Output/Artifacts/`

6. **EVTX Forensic Log Collection & Protocol Fallback**:
   - `Get-EVTX` incorporates LOOT multi-protocol forensic extraction (`Method = Auto|SMB|WinRM|WMI`).
   - `Auto` method sequence attempts `SMB` (Port 445) first for speed, then `WinRM` (Port 5985), and finally `WMI` (DCOM/RPC Port 135).
   - Supports presets: `DFIR` (Security, System, Application, PowerShell, Sysmon), `All` (winevt log store), or `Custom`.
   - Uses remote `wevtutil epl` to export active logs cleanly without file lock failures.

7. **Interactive GUI Modal Dialogs & Dedicated Containment Tab**:
   - `AdminTool.ps1` features a dedicated, red-styled **"Contain / Clear"** tab for destructive incident response actions (`Get-RemoteArtifact`, `Reset-ADUserPassword`, `Stop-RemoteProcess`, `Stop-RemoteService`, `Remove-RemoteService`, `Remove-RemoteScheduledTask`, `Remove-RemoteItem`, `Remove-RemoteRegistryKey`, `Add-RemoteFirewallRule`), keeping investigative queries safely separated.
   - All containment actions enforce interactive modal popup dialogs with operator confirmation warnings before execution.
   - Console warning output uses high-contrast `DarkGoldenrod` foreground text for high readability against the white background.
   - `Get-RemoteArtifact` supports artifact modes (`Auto`, `File`, `Executable`, `Directory`). Executables are zipped and password-protected (default `infected` or custom prompt) on target before transfer. Directories are compressed into `.zip` packages. Supports `-CleanRemote` post-acquisition target removal.
   - `Reset-ADUserPassword` resets compromised AD account passwords with ADSI LDAP fallback, auto-generates 20-character complex passwords, unlocks locked accounts, and sets `pwdLastSet = 0`.

8. **Timestamp Standard**:
   - All timestamp properties in output custom objects MUST use the standard ISO 8601 format:
     - Local: `(Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')`
     - UTC: `(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')`

9. **Credential Handling**:
   - Functions accept `[PSCredential]$Credential` parameter.
   - When running via `AdminTool.ps1` or background jobs, explicit UI credentials or `$null` (for default WSMan session context) are passed down. Avoid interactive prompts inside remote scriptblocks.

10. **Documentation Separation Standard**:
    - **`AGENTS.md`**: Dedicated to developer guidelines, AI agent instructions, system architecture, fallback patterns, and technical rules.
    - **`README.md`**: Dedicated strictly to human operators as a clean User Guide & Operator How-To Manual.


