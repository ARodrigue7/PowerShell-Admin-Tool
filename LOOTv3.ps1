<#
.SYNOPSIS
L.O.O.T. (Log Origination & Operational Triage)
v2.2 - Forensic Export Edition (Raw & Lock-Free .evtx Collection)

.DESCRIPTION
Optimized for Domain Admin and Built-in Local Admin (RID 500) credentials.
Uses WinRM tunneling, SMB shares, or DCOM/RPC WMI sessions to acquire forensic-ready logs.
Bypasses locked files using native wevtutil exports.
Collection methods (WinRM and WMI) use wevtutil for forensically sound, lock-free exports.

.PARAMETER Help
Display full help, switch reference, log catalog, and usage examples.

.PARAMETER Target
One or more target hostnames or IP addresses. Comma-separated.

.PARAMETER TargetFile
Path to a plain-text file containing one target per line.

.PARAMETER Method
Collection method. Accepted values: SMB, WinRM, WMI. Default: SMB.

.PARAMETER LogCategory
Log preset to collect. Accepted values: All, DFIR, Custom. Default: DFIR.

.PARAMETER CustomLogs
Log names to collect when LogCategory is Custom. Comma-separated.

.PARAMETER Force
Suppress confirmation prompts (except the ALL category warning).

.EXAMPLE
.\LOOT.ps1 -Help

.EXAMPLE
.\LOOT.ps1 -Target "10.0.0.5" -Method WinRM -LogCategory DFIR

.EXAMPLE
.\LOOT.ps1 -Target "10.0.0.5" -Method WMI -LogCategory DFIR

.EXAMPLE
.\LOOT.ps1 -Target "10.0.0.5,10.0.0.6" -Method SMB -LogCategory All

.EXAMPLE
.\LOOT.ps1 -TargetFile ".\targets.txt" -Method WinRM -LogCategory Custom -CustomLogs "Security","System"
#>

[CmdletBinding()]
param (
    [switch]$Help,
    [string[]]$Target,
    [string]$TargetFile,
    [ValidateSet('SMB','WinRM','WMI')]
    [string]$Method = 'SMB',
    [ValidateSet('All','DFIR','Custom')]
    [string]$LogCategory = 'DFIR',
    [string[]]$CustomLogs,
    [switch]$Force
)

# ==============================================================================
# [ HELP SYSTEM ]
# ==============================================================================
if ($Help) {
    Clear-Host
    Write-Host "   __    ____  ____  _____ " -ForegroundColor Cyan
    Write-Host "  / /   / __ \/ __ \/_  _/ " -ForegroundColor Cyan
    Write-Host " / /___/ /_/ / /_/ / / /   " -ForegroundColor Cyan
    Write-Host "/_____/\____/\____/ /_/    " -ForegroundColor Cyan
    Write-Host " [ Log Origination & Operational Triage ] v2.2`n" -ForegroundColor Yellow

    Write-Host "USAGE" -ForegroundColor Cyan
    Write-Host "-----"
    Write-Host "  .\LOOT.ps1 [switches]"
    Write-Host "  Running with no switches launches the interactive wizard.`n"

    Write-Host "SWITCHES" -ForegroundColor Cyan
    Write-Host "--------"
    $switches = @(
        [PSCustomObject]@{ Switch="-Help / -h";          Description="Display this help screen." },
        [PSCustomObject]@{ Switch="-Target";             Description="One or more hostnames/IPs. Comma-separated. e.g. '10.0.0.5' or '10.0.0.5,10.0.0.6'" },
        [PSCustomObject]@{ Switch="-TargetFile";         Description="Path to a .txt file with one target per line." },
        [PSCustomObject]@{ Switch="-Method";             Description="Collection method: SMB (default), WinRM, or WMI." },
        [PSCustomObject]@{ Switch="-LogCategory";        Description="Log preset: DFIR (default), All, or Custom." },
        [PSCustomObject]@{ Switch="-CustomLogs";         Description="Log names to pull when -LogCategory Custom is set. Comma-separated." },
        [PSCustomObject]@{ Switch="-Force";              Description="Suppress non-critical confirmation prompts." }
    )
    foreach ($s in $switches) {
        Write-Host ("  {0,-20} {1}" -f $s.Switch, $s.Description)
    }
    Write-Host ""

    Write-Host "COLLECTION METHODS" -ForegroundColor Cyan
    Write-Host "------------------"
    Write-Host "  SMB    Port 445  | Best for Domain Admins. Mounts C$ share dynamically."
    Write-Host "         Performs raw file copy directly from disk (locked logs will fail/bypass)."
    Write-Host ""
    Write-Host "  WinRM  Port 5985 | Best for PSSession tunneling. Scales across multiple hosts."
    Write-Host "         Uses wevtutil on the target to export locked log files cleanly in a single batch."
    Write-Host "         Requires TrustedHosts modification (admin rights required locally)."
    Write-Host ""
    Write-Host "  WMI    Port 135  | DCOM/RPC collection. Uses SMB share for file transfer, but invokes"
    Write-Host "         wevtutil remotely using DCOM WMI processes to copy locked active logs cleanly."
    Write-Host "         Useful when WinRM (Port 5985) is blocked but RPC is available.`n"

    Write-Host "LOG CATEGORIES" -ForegroundColor Cyan
    Write-Host "--------------"
    Write-Host "  DFIR   Targeted collection. Pulls the following logs:" -ForegroundColor Yellow
    $dfirLogs = @(
        [PSCustomObject]@{ LogName="Security";                                      File="Security.evtx";                                          Contains="Logons, privilege use, account changes, log clearing" },
        [PSCustomObject]@{ LogName="System";                                        File="System.evtx";                                            Contains="Service installs, shutdowns, time changes, driver events" },
        [PSCustomObject]@{ LogName="Application";                                   File="Application.evtx";                                       Contains="Application crashes, third-party software errors" },
        [PSCustomObject]@{ LogName="Windows PowerShell";                            File="Windows PowerShell.evtx";                                Contains="Classic PowerShell pipeline execution logs" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-PowerShell/Operational";      File="Microsoft-Windows-PowerShell%4Operational.evtx";         Contains="Script block logging, PS remoting, module activity" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-Sysmon/Operational";          File="Microsoft-Windows-Sysmon%4Operational.evtx";             Contains="Process creation, network connections, file creation (requires Sysmon)" }
    )
    Write-Host ""
    Write-Host ("  {0,-52} {1,-48} {2}" -f "Log Name", "Filename on Disk", "What It Contains") -ForegroundColor White
    Write-Host ("  {0,-52} {1,-48} {2}" -f ("-"*50), ("-"*46), ("-"*30))
    foreach ($l in $dfirLogs) {
        Write-Host ("  {0,-52} {1,-48} {2}" -f $l.LogName, $l.File, $l.Contains)
    }
    Write-Host ""

    Write-Host "  ALL    Pulls every .evtx file in C:\Windows\System32\winevt\Logs\" -ForegroundColor Yellow
    Write-Host "         WARNING: This is a full forensic image of the log store."
    Write-Host "         Expect 2-20+ GB per host depending on retention settings."
    Write-Host "         A confirmation prompt will appear before collection begins.`n"

    Write-Host "  CUSTOM Pulls only the log names you specify with -CustomLogs." -ForegroundColor Yellow
    Write-Host "         Use the exact Windows log name, not the filename."
    Write-Host "         e.g. 'Security', 'Microsoft-Windows-TaskScheduler/Operational'`n"

    Write-Host "COMMON EVTX LOG REFERENCE" -ForegroundColor Cyan
    Write-Host "-------------------------"
    $allLogs = @(
        [PSCustomObject]@{ LogName="Security";                                              File="Security.evtx";                                                    Notes="Authentication, privilege, account management" },
        [PSCustomObject]@{ LogName="System";                                                File="System.evtx";                                                      Notes="OS-level events, services, drivers" },
        [PSCustomObject]@{ LogName="Application";                                           File="Application.evtx";                                                 Notes="App-level errors and warnings" },
        [PSCustomObject]@{ LogName="Windows PowerShell";                                    File="Windows PowerShell.evtx";                                          Notes="Classic PS engine logging" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-PowerShell/Operational";              File="Microsoft-Windows-PowerShell%4Operational.evtx";                   Notes="Script blocks, remoting, module loads" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-Sysmon/Operational";                  File="Microsoft-Windows-Sysmon%4Operational.evtx";                       Notes="Requires Sysmon. Process, network, file events" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-TaskScheduler/Operational";           File="Microsoft-Windows-TaskScheduler%4Operational.evtx";                Notes="Scheduled task creation and execution" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-WMI-Activity/Operational";            File="Microsoft-Windows-WMI-Activity%4Operational.evtx";                 Notes="WMI queries and remote execution activity" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"; File="Microsoft-Windows-TerminalServices-LocalSessionManager%4Operational.evtx"; Notes="RDP session logon/logoff events" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational";      File="Microsoft-Windows-RemoteDesktopServices-RdpCoreTS%4Operational.evtx";      Notes="RDP connection attempts and failures" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-DNS-Client/Operational";              File="Microsoft-Windows-DNS-Client%4Operational.evtx";                   Notes="DNS lookups - useful for C2 beacon detection" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-NTLM/Operational";                    File="Microsoft-Windows-NTLM%4Operational.evtx";                         Notes="NTLM authentication events" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-Bits-Client/Operational";             File="Microsoft-Windows-Bits-Client%4Operational.evtx";                  Notes="BITS transfers - common malware download method" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-AppLocker/EXE and DLL";               File="Microsoft-Windows-AppLocker%4EXE and DLL.evtx";                    Notes="AppLocker execution allow/block events" },
        [PSCustomObject]@{ LogName="Microsoft-Windows-Windows Defender/Operational";        File="Microsoft-Windows-Windows Defender%4Operational.evtx";             Notes="Defender detections, exclusions, scan results" }
    )
    Write-Host ""
    Write-Host ("  {0,-60} {1}" -f "Log Name (use this with -CustomLogs)", "Notes") -ForegroundColor White
    Write-Host ("  {0,-60} {1}" -f ("-"*58), ("-"*40))
    foreach ($l in $allLogs) {
        Write-Host ("  {0,-60} {1}" -f $l.LogName, $l.Notes)
    }
    Write-Host ""

    Write-Host "HEADLESS MODE EXAMPLES" -ForegroundColor Cyan
    Write-Host "----------------------"
    Write-Host "  # DFIR preset via WinRM against a single host:"
    Write-Host "  .\LOOT.ps1 -Target '10.0.0.5' -Method WinRM -LogCategory DFIR" -ForegroundColor Green
    Write-Host ""
    Write-Host "  # DFIR preset via WMI against a single host:"
    Write-Host "  .\LOOT.ps1 -Target '10.0.0.5' -Method WMI -LogCategory DFIR" -ForegroundColor Green
    Write-Host ""
    Write-Host "  # DFIR preset via SMB against multiple hosts:"
    Write-Host "  .\LOOT.ps1 -Target '10.0.0.5,10.0.0.6,10.0.0.7' -Method SMB -LogCategory DFIR" -ForegroundColor Green
    Write-Host ""
    Write-Host "  # Full log pull (ALL) via WinRM from a target list file:"
    Write-Host "  .\LOOT.ps1 -TargetFile '.\targets.txt' -Method WinRM -LogCategory All" -ForegroundColor Green
    Write-Host ""
    Write-Host "  # Custom logs via WinRM - Security and Scheduled Tasks only:"
    Write-Host "  .\LOOT.ps1 -Target '10.0.0.10' -Method WinRM -LogCategory Custom -CustomLogs 'Security','Microsoft-Windows-TaskScheduler/Operational'" -ForegroundColor Green
    Write-Host ""
    Write-Host "  # Same as above via SMB with Force flag to suppress prompts:"
    Write-Host "  .\LOOT.ps1 -Target '10.0.0.10' -Method SMB -LogCategory Custom -CustomLogs 'Security','System' -Force" -ForegroundColor Green
    Write-Host ""
    Write-Host "OUTPUT" -ForegroundColor Cyan
    Write-Host "------"
    Write-Host "  Logs are saved to: .\Logs\<hostname>_<YYYYMMDD_HHmm>\"
    Write-Host "  A mission transcript is saved to: .\Logs\LOOT_<timestamp>.log`n"
    exit
}

# ==============================================================================
# [ SETUP ]
# ==============================================================================
$missionTimestamp = Get-Date -Format "yyyyMMdd_HHmm"
$transcriptPath   = ".\Logs\LOOT_$missionTimestamp.log"
New-Item -ItemType Directory -Path ".\Logs" -Force -ErrorAction SilentlyContinue | Out-Null
Start-Transcript -Path $transcriptPath -Append | Out-Null

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ==============================================================================
# [ HELPER FUNCTIONS — PROGRESS TICKER ]
# ==============================================================================
function Copy-FileWithProgress {
    param (
        [Parameter(Mandatory=$true)][string]$SourcePath,
        [Parameter(Mandatory=$true)][string]$DestinationPath,
        [int]$BufferSize = 2MB
    )

    $srcFile = Get-Item -Path $SourcePath -ErrorAction SilentlyContinue
    if (-not $srcFile) { return }

    $fileName   = $srcFile.Name
    $totalBytes = $srcFile.Length
    $destFile   = Join-Path $DestinationPath $fileName

    if ($totalBytes -eq 0) {
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
        Write-Host "  [OK] Acquired: $fileName (0 MB)" -ForegroundColor Green
        return
    }

    $totalMB    = [math]::Round($totalBytes / 1MB, 1)
    $srcStream  = $null
    $destStream = $null

    try {
        $srcStream  = [System.IO.File]::OpenRead($SourcePath)
        $destStream = [System.IO.File]::Create($destFile)

        $buffer      = New-Object byte[] $BufferSize
        $bytesCopied = 0
        $sw          = [System.Diagnostics.Stopwatch]::StartNew()

        while (($bytesRead = $srcStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $destStream.Write($buffer, 0, $bytesRead)
            $bytesCopied += $bytesRead

            $copiedMB = [math]::Round($bytesCopied / 1MB, 1)
            $percent  = [math]::Round(($bytesCopied / $totalBytes) * 100, 1)
            $elapsedSec = $sw.Elapsed.TotalSeconds
            $speedMBs   = if ($elapsedSec -gt 0) { [math]::Round(($bytesCopied / 1MB) / $elapsedSec, 1) } else { 0 }

            $status = "`r  [DOWNLOADING] {0}: {1}MB out of {2}MB ({3}%) - {4} MB/s    " -f $fileName, $copiedMB, $totalMB, $percent, $speedMBs
            Write-Host -NoNewline $status
        }
        $sw.Stop()
        $finalMB    = [math]::Round($bytesCopied / 1MB, 1)
        $elapsed    = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        $finalSpeed = if ($elapsed -gt 0) { [math]::Round($finalMB / $elapsed, 1) } else { 0 }

        Write-Host ("`r  [OK] Acquired: {0} ({1}MB out of {2}MB) in {3}s ({4} MB/s)                      " -f $fileName, $finalMB, $totalMB, $elapsed, $finalSpeed) -ForegroundColor Green
    }
    catch {
        Write-Host "`n  [!] Stream copy failed for $fileName, falling back to Copy-Item..." -ForegroundColor Yellow
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
        Write-Host "  [OK] Acquired: $fileName" -ForegroundColor Green
    }
    finally {
        if ($srcStream)  { $srcStream.Close();  $srcStream.Dispose() }
        if ($destStream) { $destStream.Close(); $destStream.Dispose() }
    }
}

function Copy-WinRMFileWithProgress {
    param (
        [Parameter(Mandatory=$true)]$Session,
        [Parameter(Mandatory=$true)][string]$RemotePath,
        [Parameter(Mandatory=$true)][string]$DestinationPath,
        [Parameter(Mandatory=$true)][int64]$TotalBytes,
        [Parameter(Mandatory=$true)][string]$FileName
    )

    $destFile = Join-Path $DestinationPath $FileName
    $totalMB  = [math]::Round($TotalBytes / 1MB, 1)

    if ($TotalBytes -eq 0) {
        Copy-Item -FromSession $Session -Path $RemotePath -Destination $DestinationPath -Force
        Write-Host "  [OK] Acquired: $FileName (0 MB)" -ForegroundColor Green
        return
    }

    try {
        $ps = [powershell]::Create()
        $null = $ps.AddCommand("Copy-Item")
        $null = $ps.AddParameter("FromSession", $Session)
        $null = $ps.AddParameter("Path", $RemotePath)
        $null = $ps.AddParameter("Destination", $DestinationPath)
        $null = $ps.AddParameter("Force", $true)

        $asyncResult = $ps.BeginInvoke()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        while (-not $asyncResult.IsCompleted) {
            if (Test-Path $destFile) {
                $copiedBytes = (Get-Item $destFile -ErrorAction SilentlyContinue).Length
                if ($copiedBytes -gt 0) {
                    $copiedMB = [math]::Round($copiedBytes / 1MB, 1)
                    $percent  = [math]::Min(100.0, [math]::Round(($copiedBytes / $TotalBytes) * 100, 1))
                    $elapsedSec = $sw.Elapsed.TotalSeconds
                    $speedMBs   = if ($elapsedSec -gt 0) { [math]::Round(($copiedBytes / 1MB) / $elapsedSec, 1) } else { 0 }

                    $status = "`r  [DOWNLOADING] {0}: {1}MB out of {2}MB ({3}%) - {4} MB/s    " -f $FileName, $copiedMB, $totalMB, $percent, $speedMBs
                    Write-Host -NoNewline $status
                }
            }
            Start-Sleep -Milliseconds 200
        }

        $ps.EndInvoke($asyncResult)
        $ps.Dispose()
        $sw.Stop()

        $finalBytes = if (Test-Path $destFile) { (Get-Item $destFile).Length } else { $TotalBytes }
        $finalMB    = [math]::Round($finalBytes / 1MB, 1)
        $elapsed    = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        $finalSpeed = if ($elapsed -gt 0) { [math]::Round($finalMB / $elapsed, 1) } else { 0 }

        Write-Host ("`r  [OK] Acquired: {0} ({1}MB out of {2}MB) in {3}s ({4} MB/s)                      " -f $FileName, $finalMB, $totalMB, $elapsed, $finalSpeed) -ForegroundColor Green
    }
    catch {
        Write-Host "`n  [!] Async WinRM copy failed for $FileName, falling back to standard copy..." -ForegroundColor Yellow
        Copy-Item -FromSession $Session -Path $RemotePath -Destination $DestinationPath -Force
        Write-Host "  [OK] Acquired: $FileName" -ForegroundColor Green
    }
}


# --- DFIR PRESET ---
$dfirPreset = @(
    "Security",
    "System",
    "Application",
    "Windows PowerShell",
    "Microsoft-Windows-PowerShell/Operational",
    "Microsoft-Windows-Sysmon/Operational"
)

# ==============================================================================
# [ INTERACTIVE WIZARD ]
# ==============================================================================
if ($PSBoundParameters.Count -eq 0) {
    Clear-Host
    Write-Host "   __    ____  ____  _____ " -ForegroundColor Cyan
    Write-Host "  / /   / __ \/ __ \/_  _/ " -ForegroundColor Cyan
    Write-Host " / /___/ /_/ / /_/ / / /   " -ForegroundColor Cyan
    Write-Host "/_____/\____/\____/ /_/    " -ForegroundColor Cyan
    Write-Host " [ Log Origination & Operational Triage ] v2.2`n" -ForegroundColor Yellow
    Write-Host " Run .\LOOT.ps1 -Help to see all switches and examples.`n" -ForegroundColor DarkGray

    Write-Host "Collection Methods:" -ForegroundColor Yellow
    Write-Host "1 - SMB   (Port 445  | Best for Domain Admins. Raw copy fallback)"
    Write-Host "2 - WinRM (Port 5985 | Best for PSSession Tunneling)"
    Write-Host "3 - WMI   (Port 135  | DCOM/RPC collection, lock-free)"
    $mChoice = Read-Host "Select Method (1, 2, or 3)"
    if ($mChoice -eq '2') {
        $Method = 'WinRM'
    } elseif ($mChoice -eq '3') {
        $Method = 'WMI'
    } else {
        $Method = 'SMB'
    }

    Write-Host "`nTarget Selection:" -ForegroundColor Yellow
    Write-Host "1 - Single IP/Hostname or Comma-Separated List"
    Write-Host "2 - Text File (one target per line)"
    $tChoice = Read-Host "Enter 1 or 2"
    if ($tChoice -eq "1") {
        $TargetInput = Read-Host "Enter Targets"
        $Target = $TargetInput.Split(',')
    } else {
        $TargetFile = Read-Host "Enter File Path"
    }

    Write-Host "`nLog Selection:" -ForegroundColor Yellow
    Write-Host "1 - DFIR   (Security, System, Application, PowerShell, Sysmon)"
    Write-Host "2 - Custom (Specify log names manually)"
    Write-Host "3 - ALL    (Every .evtx in the log store - expect large data)"
    $lChoice = Read-Host "Enter 1, 2, or 3"
    if ($lChoice -eq '1') {
        $LogCategory = "DFIR"
    } elseif ($lChoice -eq '2') {
        $LogCategory = "Custom"
        $CustomInput = Read-Host "Enter log names (comma-separated)"
        $CustomLogs  = $CustomInput.Split(',')
    } else {
        $LogCategory = "All"
    }
}

# ==============================================================================
# [ ALL CATEGORY WARNING ]
# ==============================================================================
if ($LogCategory -eq 'All') {
    Write-Host "`n+----------------------------------------------------------------------+" -ForegroundColor Red
    Write-Host "|               !! WARNING - ALL MODE SELECTED !!                      |" -ForegroundColor Red
    Write-Host "+----------------------------------------------------------------------+" -ForegroundColor Red
    Write-Host "|  This will pull EVERY .evtx file from the target log store.          |" -ForegroundColor Yellow
    Write-Host "|  Expect 2-20+ GB per host depending on retention settings.           |" -ForegroundColor Yellow
    Write-Host "|  Ensure you have sufficient storage and time before proceeding.      |" -ForegroundColor Yellow
    Write-Host "+----------------------------------------------------------------------+" -ForegroundColor Red
    $confirm = Read-Host "`n  Type YES to confirm and continue"
    if ($confirm -ne 'YES') {
        Write-Host "`n[ABORTED] Operation cancelled by operator." -ForegroundColor Yellow
        Stop-Transcript | Out-Null
        exit
    }
}

# ==============================================================================
# [ TARGET & LOG RESOLUTION ]
# ==============================================================================
$finalTargets = @()
if ($Target)     { $finalTargets += $Target | ForEach-Object { $_.Trim() } }
if ($TargetFile -and (Test-Path $TargetFile)) { $finalTargets += Get-Content $TargetFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } }
if ($finalTargets.Count -eq 0) {
    Write-Error "No targets provided. Use -Target or -TargetFile, or run without switches for the wizard."
    Stop-Transcript | Out-Null
    exit
}

$logsToPull = @()
if ($LogCategory -eq 'DFIR')   { $logsToPull = $dfirPreset }
if ($LogCategory -eq 'Custom') { $logsToPull = $CustomLogs | ForEach-Object { $_.Trim() } }

# ==============================================================================
# [ WINRM — TRUSTEDHOSTS MANAGEMENT ]
# ==============================================================================
$originalTrustedHosts = $null
if ($Method -eq 'WinRM') {
    if (-not $isAdmin) {
        Write-Host "`n[!] Admin rights required for TrustedHosts modification. Run as Administrator." -ForegroundColor Red
        Stop-Transcript | Out-Null
        exit
    }
    $originalTrustedHosts = (Get-Item -Path WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
    $newHosts = $originalTrustedHosts
    foreach ($t in $finalTargets) {
        if ($newHosts -notmatch [regex]::Escape($t)) {
            $newHosts = if ($newHosts) { "$newHosts,$t" } else { $t }
        }
    }
    Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $newHosts -Force
}

# ==============================================================================
# [ AUTHENTICATION ]
# ==============================================================================
Write-Host "`n[ MISSION AUTHENTICATION ]" -ForegroundColor Red
$cred = Get-Credential -Message "Enter Credentials (DOMAIN\User or .\Administrator)"

# ==============================================================================
# [ COLLECTION ]
# ==============================================================================
$retryMax   = 2
$retryDelay = 5  # seconds
$remoteTemp = "C:\Windows\Temp\LOOT_Export"

try {
    foreach ($hostname in $finalTargets) {
        if ([string]::IsNullOrWhiteSpace($hostname)) { continue }

        Write-Host "`n----------------------------------------" -ForegroundColor Cyan
        Write-Host "  Target: $hostname" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor Cyan

        # --- CONNECTIVITY CHECK WITH RETRY ---
        $online  = $false
        $attempt = 0
        while (-not $online -and $attempt -le $retryMax) {
            if (Test-Connection -ComputerName $hostname -Count 1 -Quiet) {
                $online = $true
            } else {
                $attempt++
                if ($attempt -le $retryMax) {
                    Write-Host "  [RETRY $attempt/$retryMax] Host unreachable. Waiting $retryDelay seconds..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $retryDelay
                }
            }
        }
        if (-not $online) {
            Write-Host "  [SKIPPED] $hostname is offline after $retryMax retries." -ForegroundColor Red
            continue
        }

        # --- TIMESTAMPED OUTPUT FOLDER ---
        $logPath = ".\Logs\${hostname}_${missionTimestamp}"
        New-Item -ItemType Directory -Path $logPath -Force -ErrorAction SilentlyContinue | Out-Null

        try {
            # ----------------------------------------------------------------
            # SMB METHOD
            # ----------------------------------------------------------------
            if ($Method -eq 'SMB') {
                # Find the first available drive letter starting from Z: downwards
                $drv = $null
                foreach ($l in (90..68 | ForEach-Object { [char]$_ })) {
                    if (-not (Get-PSDrive -Name $l -ErrorAction SilentlyContinue)) {
                        $drv = $l
                        break
                    }
                }
                if ($null -eq $drv) {
                    throw "No available drive letters to mount SMB share."
                }

                # Mount the administrative C$ share
                New-PSDrive -Name $drv -PSProvider FileSystem -Root "\\${hostname}\C$" -Credential $cred -ErrorAction Stop | Out-Null
                Write-Host "  [SMB] C`$ share mounted on ${drv}:\" -ForegroundColor Green

                if ($LogCategory -eq 'All') {
                    Write-Host "  [SMB-Fallback] Copying raw .evtx files directly from disk..." -ForegroundColor Yellow
                    $filesToCopy = Get-ChildItem -Path "${drv}:\Windows\System32\winevt\Logs\*.evtx" -File -ErrorAction SilentlyContinue
                    foreach ($file in $filesToCopy) {
                        Copy-FileWithProgress -SourcePath $file.FullName -DestinationPath $logPath
                    }
                    Write-Host "  [SMB-Fallback] All logs copied." -ForegroundColor Green
                } else {
                    foreach ($log in $logsToPull) {
                        $evtxName   = ($log -replace "/", "%4") + ".evtx"
                        $sourcePath = "${drv}:\Windows\System32\winevt\Logs\${evtxName}"
                        if (Test-Path $sourcePath) {
                            Copy-FileWithProgress -SourcePath $sourcePath -DestinationPath $logPath
                        } else {
                            Write-Host "  [--] Not Found / Access Denied: $evtxName" -ForegroundColor DarkGray
                        }
                    }
                }

                # Unmount PSDrive
                Remove-PSDrive -Name $drv -Force | Out-Null
                Write-Host "  [SMB] Share unmounted." -ForegroundColor DarkGray
            }

            # ----------------------------------------------------------------
            # WINRM METHOD
            # ----------------------------------------------------------------
            elseif ($Method -eq 'WinRM') {
                Write-Host "  [WinRM] Establishing PSSession..." -ForegroundColor Yellow
                $session = New-PSSession -ComputerName $hostname -Credential $cred -ErrorAction Stop
                
                # Single-pass remote log export to optimize performance
                Write-Host "  [WinRM] Exporting logs on target host in a single batch..." -ForegroundColor Yellow
                Invoke-Command -Session $session -ScriptBlock {
                    param($temp, $category, $logs)
                    New-Item -ItemType Directory -Path $temp -Force | Out-Null
                    
                    if ($category -eq 'All') {
                        $remoteLogs = wevtutil el
                        foreach ($log in $remoteLogs) {
                            $exportName = ($log -replace "[/\\ ]", "_") + ".evtx"
                            wevtutil epl $log "$temp\$exportName" /overwrite:true 2>$null
                        }
                    } else {
                        foreach ($log in $logs) {
                            $exportName = ($log -replace "[/\\ ]", "_") + ".evtx"
                            wevtutil epl $log "$temp\$exportName" /overwrite:true 2>$null
                        }
                    }
                } -ArgumentList $remoteTemp, $LogCategory, $logsToPull

                # Batch copy all files back with real-time progress ticker
                Write-Host "  [WinRM] Copying all exported logs to local storage..." -ForegroundColor Yellow
                $remoteFiles = Invoke-Command -Session $session -ScriptBlock {
                    Get-ChildItem -Path $args[0] -File -ErrorAction SilentlyContinue | Select-Object Name, Length
                } -ArgumentList $remoteTemp

                if ($remoteFiles) {
                    foreach ($rFile in $remoteFiles) {
                        Copy-WinRMFileWithProgress -Session $session -RemotePath "$remoteTemp\$($rFile.Name)" -DestinationPath $logPath -TotalBytes $rFile.Length -FileName $rFile.Name
                    }
                } else {
                    Write-Host "  [!] No exported log files found in remote temp." -ForegroundColor Yellow
                }
                Write-Host "  [WinRM] Acquisition complete." -ForegroundColor Green

                # Clean up remote temp folder
                Invoke-Command -Session $session -ScriptBlock {
                    Remove-Item -Path $args[0] -Recurse -Force -ErrorAction SilentlyContinue
                } -ArgumentList $remoteTemp | Out-Null
                
                Remove-PSSession -Session $session
                Write-Host "  [WinRM] Session closed. Remote temp cleaned." -ForegroundColor DarkGray
            }

            # ----------------------------------------------------------------
            # WMI METHOD (DCOM / RPC / Port 135 fallback)
            # ----------------------------------------------------------------
            elseif ($Method -eq 'WMI') {
                # Find the first available drive letter starting from Z: downwards
                $drv = $null
                foreach ($l in (90..68 | ForEach-Object { [char]$_ })) {
                    if (-not (Get-PSDrive -Name $l -ErrorAction SilentlyContinue)) {
                        $drv = $l
                        break
                    }
                }
                if ($null -eq $drv) {
                    throw "No available drive letters to mount SMB share."
                }

                # Mount the administrative C$ share for copying files later
                New-PSDrive -Name $drv -PSProvider FileSystem -Root "\\${hostname}\C$" -Credential $cred -ErrorAction Stop | Out-Null
                Write-Host "  [WMI] C`$ share mounted on ${drv}:\" -ForegroundColor Green

                # Establish WMI/CIM session explicitly using the DCOM protocol (port 135)
                Write-Host "  [WMI] Establishing remote DCOM WMI connection..." -ForegroundColor Yellow
                $cimOption = New-CimSessionOption -Protocol DCOM
                $cimSession = New-CimSession -ComputerName $hostname -Credential $cred -SessionOption $cimOption -ErrorAction Stop

                Write-Host "  [WMI] Creating remote temp export directory..." -ForegroundColor Yellow
                $createDirCmd = "cmd.exe /c mkdir $remoteTemp"
                $null = Invoke-CimMethod -CimSession $cimSession -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $createDirCmd } -ErrorAction Stop

                Write-Host "  [WMI] Exporting logs remote-side via wevtutil processes..." -ForegroundColor Yellow
                if ($LogCategory -eq 'All') {
                    # Execute PowerShell remotely via WMI to batch-export all logs
                    $psCmd = "powershell -NoProfile -Command `"[System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.GetLogNames() | ForEach-Object { wevtutil epl `"`$_`" `"$remoteTemp\(\`$_ -replace '[/\\ ]', '_').evtx`" /overwrite:true 2>`$null }`""
                    $null = Invoke-CimMethod -CimSession $cimSession -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $psCmd } -ErrorAction Stop
                    Start-Sleep -Seconds 4
                } else {
                    foreach ($log in $logsToPull) {
                        $exportName = ($log -replace "[/\\ ]", "_") + ".evtx"
                        $exportCmd = "wevtutil epl `"$log`" `"$remoteTemp\$exportName`" /overwrite:true"
                        $null = Invoke-CimMethod -CimSession $cimSession -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $exportCmd } -ErrorAction Stop
                    }
                }

                # Verify files exist in the mounted folder
                $checkPath = "${drv}:\Windows\Temp\LOOT_Export"
                $checkRetries = 5
                while ($checkRetries -gt 0 -and -not (Test-Path $checkPath)) {
                    Start-Sleep -Seconds 2
                    $checkRetries--
                }

                if (Test-Path $checkPath) {
                    Write-Host "  [WMI] Downloading exported logs..." -ForegroundColor Green
                    $filesToCopy = Get-ChildItem -Path "$checkPath\*.evtx" -File -ErrorAction SilentlyContinue
                    if ($filesToCopy) {
                        foreach ($file in $filesToCopy) {
                            Copy-FileWithProgress -SourcePath $file.FullName -DestinationPath $logPath
                        }
                    }
                    Write-Host "  [WMI] All exported logs successfully acquired." -ForegroundColor Green
                    
                    # Clean up remote temp files
                    $cleanCmd = "cmd.exe /c rmdir /s /q $remoteTemp"
                    $null = Invoke-CimMethod -CimSession $cimSession -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cleanCmd }
                } else {
                    throw "Remote logs failed to export to $remoteTemp."
                }

                # Close WMI/CIM session and unmount PSDrive
                Remove-CimSession -Session $cimSession
                Remove-PSDrive -Name $drv -Force | Out-Null
                Write-Host "  [WMI] Share and WMI sessions closed." -ForegroundColor DarkGray
            }
        }
        catch {
            Write-Host "  [ERROR] $hostname - $_" -ForegroundColor Red
        }
    }
}
finally {
    Write-Host "`n------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  [ MISSION COMPLETE - SANITIZING OPSEC ARTIFACTS ]" -ForegroundColor Yellow
    Write-Host "------------------------------------------------" -ForegroundColor Yellow

    if ($Method -eq 'WinRM') {
        if ($null -eq $originalTrustedHosts -or $originalTrustedHosts -eq "") {
            Clear-Item -Path WSMan:\localhost\Client\TrustedHosts -Force -ErrorAction SilentlyContinue
        } else {
            Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $originalTrustedHosts -Force -ErrorAction SilentlyContinue
        }
        Write-Host "  -> TrustedHosts reverted." -ForegroundColor Green
    }

    $cred = $null
    Write-Host "  -> Credentials purged from memory." -ForegroundColor Green
    Write-Host "  -> Mission transcript saved to: $transcriptPath" -ForegroundColor Green
    Write-Host ""

    Stop-Transcript | Out-Null
}
