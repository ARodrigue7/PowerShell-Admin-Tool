# PowerShell Remote Admin Tool — User Guide

A graphical Windows PowerShell WPF application designed for system administrators, forensic analysts, and incident responders to perform remote investigation, baselining, and threat containment across Windows hosts.

---

## 🚀 Quick Start

1. Open PowerShell on your managing machine.
2. Allow local script execution if needed:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. Launch the application:
   ```powershell
   .\AdminTool.ps1
   ```

---

## 📖 Operator How-To Guide

### 1. Adding & Managing Target Hosts
* **Manual Input**: Type comma-separated IP addresses or hostnames into the **Target Computers** box (e.g., `192.168.1.50, DC01, Server02`).
* **Import from File**: Click **Import from File...** to load targets from a `.txt` or `.csv` file.
* **Quick Host Controls**: Use **Remove Selected** or **Clear All** under the target chip list to modify your target list on the fly.
* **Target Indicator Banners**: The blue and red banners on the action tabs display the currently active host count and target names so you always know which computers are targeted before running any command.

### 2. Setting Credentials
* **Default Session Context**: Leave **Username** and **Password** blank to execute commands using your current Windows session credentials.
* **Alternate Domain Credentials**: Enter administrative credentials into **Username** and **Password**, then click **Apply Credentials**.

### 3. Running Investigative Queries (`Run Functions` tab)
1. Switch to the **Run Functions** tab.
2. Use the **Search / Filter Functions** box to quickly find a function by name.
3. Select the function from the dropdown list (e.g., `Get-HostBaseline`, `Get-ProcessInfo`, `Get-EVTX`).
4. If a function requires options (such as `Get-EVTX` log categories or `Get-CriticalEventXML` date ranges), complete the interactive popup dialog.
5. Click **Execute Function** to start the job asynchronously.
6. Click **Get Quick OS Info** at any time for instant OS details, model, and system uptime.

### 4. Executing Threat Containment Actions (`⚠ Contain / Clear` tab)
> ⚠️ **Caution**: Actions in this tab modify remote target hosts. Always verify active targets before executing.

1. Switch to the red-styled **⚠ Contain / Clear** tab.
2. Check the **Active Targets** banner to confirm the intended hosts.
3. Use the **Search / Filter Actions** box to find a containment action:
   * **`Get-RemoteArtifact`**: Pull remote files, directories, or executables (auto-zipped with password protection). Supports post-transfer remote deletion (`-CleanRemote`).
   * **`Reset-ADUserPassword`**: Force-reset compromised Active Directory user passwords with ADSI LDAP fallback, auto-generate strong passwords, unlock accounts, and set mandatory password change flags.
   * **`Stop-RemoteProcess`**: Kill malicious processes by Name or PID.
   * **`Stop-RemoteService` / `Remove-RemoteService`**: Stop or permanently delete service registrations.
   * **`Remove-RemoteScheduledTask`**: Delete persistent scheduled tasks.
   * **`Remove-RemoteItem`**: Delete files or folders recursively.
   * **`Remove-RemoteRegistryKey`**: Purge registry run keys or specific value properties.
   * **`Add-RemoteFirewallRule`**: Add host-based firewall rules to block malicious IPs or ports.
4. Click **⚠ Execute Containment Action** and confirm the red safety confirmation dialog.

### 5. Monitoring & Exporting Results
* **Console Streaming**: Job results stream live into the console window upon completion.
* **Filter Console by Host**: Select a specific host from the **Filter Console Host** dropdown to view output for that single machine, or select **All Hosts**.
* **Exporting Results**: Click **Export Results...** to save complete output as CSV, JSON, or plain text logs.
* **Canceling Jobs**: Click **Cancel Jobs** to immediately terminate running background tasks.

---

## ⚙️ Endpoint WinRM Setup

Ensure target Windows hosts have WinRM enabled for remote management:
```powershell
Enable-PSRemoting -Force
```

If managing non-domain endpoints from your workstation, add targets to TrustedHosts:
```powershell
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
```
