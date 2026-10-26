<#
.SYNOPSIS
    Parses Get-HostBaseline CSV output folders and ships telemetry to Elastic Stack / Security Onion.

.DESCRIPTION
    Reads the 12 CSV datasets produced by Get-HostBaseline (./Output/Baselines/HostBaselines_<timestamp>/<host>/*.csv),
    transforms each row into the Elastic Stack / Security Onion schema matching the Windows Ansible playbooks,
    and ships documents via the Elasticsearch _bulk API (default) or single-document /_doc POSTs (-UseSingleDoc).

.EXAMPLE
    .\Ship-HostBaseline.ps1 -ElasticUrl "https://10.0.0.10:9200" -User "elastic" -Password "changeme"

.EXAMPLE
    .\Ship-HostBaseline.ps1 -BaselinePath ".\Output\Baselines\HostBaselines_20261026_103000" -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$BaselinePath,

    [Parameter()]
    [string]$ElasticUrl = $env:ES_URL,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter()]
    [string]$User = $env:ES_USER,

    [Parameter()]
    [string]$Password = $env:ES_PASS,

    [Parameter()]
    [string]$SecurityOnionUrl = $env:SO_URL,

    [Parameter()]
    [string]$DatasetPrefix = "admintool.windows",

    [Parameter()]
    [string]$ModuleName = "admintool",

    [Parameter()]
    [int]$BatchSize = 500,

    [Parameter()]
    [switch]$UseSingleDoc,

    [Parameter()]
    [switch]$UseIngestTimestamp,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PropValue {
    param([object]$Row, [string]$Name, [string]$Default = "")
    if ($null -eq $Row) { return $Default }
    $prop = $Row.PSObject.Properties[$Name]
    if ($null -ne $prop -and $null -ne $prop.Value -and [string]$prop.Value -ne "") {
        return [string]$prop.Value
    }
    return $Default
}

function Resolve-Timestamp {
    param([object]$Row, [bool]$ForceIngest)
    $nowUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    if ($ForceIngest -or $null -eq $Row) { return $nowUtc }

    foreach ($col in @('UTCTime', 'Time', 'LastWriteTimeUTC', 'CreationTimeUtc')) {
        $raw = Get-PropValue -Row $Row -Name $col
        if ($raw) {
            try {
                return ([DateTimeOffset]::Parse($raw)).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            } catch {}
        }
    }
    return $nowUtc
}

function Convert-BaselineRowToDocument {
    param(
        [string]$CsvName,
        [object]$Row,
        [string]$HostName,
        [string]$Prefix,
        [string]$Module,
        [bool]$ForceIngestTime
    )

    $ts = Resolve-Timestamp -Row $Row -ForceIngest $ForceIngestTime
    $resolvedHost = Get-PropValue -Row $Row -Name "CSName" -Default (Get-PropValue -Row $Row -Name "PSComputerName" -Default $HostName)

    switch ($CsvName) {
        "OSInfo" {
            $osName = Get-PropValue $Row "OperatingSystem"
            $osVer  = Get-PropValue $Row "OperatingSystemVersion"
            return @{
                Suffix   = "osinfo"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "OS Information: $osName ($osVer)"
                    event        = @{ dataset = "$Prefix.osinfo"; module = $Module }
                    os_release   = [ordered]@{
                        cs_name          = Get-PropValue $Row "CSName"
                        name             = $osName
                        version          = $osVer
                        manufacturer     = Get-PropValue $Row "Manufacturer"
                        registered_owner = Get-PropValue $Row "RegisteredOwner"
                        install_date     = Get-PropValue $Row "InstallDate"
                        last_boot_time   = Get-PropValue $Row "LastBootTime"
                        serial_number    = Get-PropValue $Row "SerialNumber"
                        time             = Get-PropValue $Row "Time"
                        utc_time         = Get-PropValue $Row "UTCTime"
                    }
                }
            }
        }
        "Processes" {
            $pName  = Get-PropValue $Row "ProcessName" "unknown"
            $procId = Get-PropValue $Row "ProcessID" "unknown"
            return @{
                Suffix   = "processes"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "Process: $pName (PID: $procId)"
                    event        = @{ dataset = "$Prefix.processes"; module = $Module }
                    process      = [ordered]@{
                        name                  = Get-PropValue $Row "ProcessName"
                        pid                   = Get-PropValue $Row "ProcessID"
                        parent                = @{ pid = Get-PropValue $Row "ParentProcessID"; name = Get-PropValue $Row "ParentProcessName" }
                        grandparent           = @{ pid = Get-PropValue $Row "GrandParentProcessID"; name = Get-PropValue $Row "GrandParentProcessName" }
                        path                  = Get-PropValue $Row "Path"
                        command_line          = Get-PropValue $Row "CommandLine"
                        handle_count          = Get-PropValue $Row "HandleCount"
                        thread_count          = Get-PropValue $Row "ThreadCount"
                        ps_computer_name      = Get-PropValue $Row "PSComputerName"
                        runspace_id           = Get-PropValue $Row "RunspaceId"
                        ps_show_computer_name = Get-PropValue $Row "PSShowComputerName"
                        lineage_hash          = Get-PropValue $Row "LineageHash"
                    }
                }
            }
        }
        "Services" {
            $sName  = Get-PropValue $Row "ServiceName" "unknown"
            $sState = Get-PropValue $Row "ServiceState" "unknown"
            return @{
                Suffix   = "services"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "Service: $sName (State: $sState)"
                    event        = @{ dataset = "$Prefix.services"; module = $Module }
                    service      = [ordered]@{
                        name                = Get-PropValue $Row "ServiceName"
                        state               = Get-PropValue $Row "ServiceState"
                        display_name        = Get-PropValue $Row "ServiceDisplayName"
                        description         = Get-PropValue $Row "ServiceDescription"
                        path                = Get-PropValue $Row "PathName"
                        start_mode          = Get-PropValue $Row "StartMode"
                        pid                 = Get-PropValue $Row "ProcessId"
                        process_name        = Get-PropValue $Row "ProcessName"
                        parent_pid          = Get-PropValue $Row "ParentProcessID"
                        parent_process_name = Get-PropValue $Row "ParentProcessName"
                        system_name         = Get-PropValue $Row "SystemName"
                        install_date        = Get-PropValue $Row "InstallDate"
                        exit_code           = Get-PropValue $Row "ExitCode"
                        delayed_auto_start  = Get-PropValue $Row "DelayedAutoStart"
                    }
                }
            }
        }
        "Connections" {
            $lAddr = Get-PropValue $Row "LocalAddress"
            $lPort = Get-PropValue $Row "LocalPort"
            $rAddr = Get-PropValue $Row "RemoteAddress"
            $rPort = Get-PropValue $Row "RemotePort"
            $state = Get-PropValue $Row "State"
            return @{
                Suffix   = "network"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "Connection: ${lAddr}:${lPort} -> ${rAddr}:${rPort} ($state)"
                    event        = @{ dataset = "$Prefix.network"; module = $Module }
                    connection   = [ordered]@{
                        local_address  = $lAddr
                        local_port     = $lPort
                        remote_address = $rAddr
                        remote_port    = $rPort
                        state          = $state
                        pid            = Get-PropValue $Row "OwningProcess"
                        process_name   = Get-PropValue $Row "ProcessName"
                        parent_pid     = Get-PropValue $Row "ParentProcessID"
                        parent_process = Get-PropValue $Row "ParentProcess"
                        creation_time  = Get-PropValue $Row "CreationTime"
                    }
                }
            }
        }
        "Shares" {
            $shName = Get-PropValue $Row "Name"
            return @{
                Suffix   = "shares"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "SMB Share: $shName"
                    event        = @{ dataset = "$Prefix.shares"; module = $Module }
                    share        = [ordered]@{
                        name    = $shName
                        account = Get-PropValue $Row "AccountName"
                        control = Get-PropValue $Row "AccessControlType"
                        right   = Get-PropValue $Row "AccessRight"
                    }
                }
            }
        }
        "RegistryRun" {
            $kName   = Get-PropValue $Row "KeyName"
            $vName   = Get-PropValue $Row "ValueName"
            $details = Get-PropValue $Row "Details"
            return @{
                Suffix   = "registryrunkeys"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "Registry Run: [$kName] $vName = $details"
                    event        = @{ dataset = "$Prefix.registryrunkeys"; module = $Module }
                    registry     = [ordered]@{
                        key          = $kName
                        value_name   = $vName
                        value_data   = $details
                        process_name = Get-PropValue $Row "ProcessName"
                        time         = Get-PropValue $Row "Time"
                    }
                }
            }
        }
        "StartupFolders" {
            $desc = Get-PropValue $Row "StartupFolderDescription"
            $fName = Get-PropValue $Row "FileInfoName"
            return @{
                Suffix   = "startup"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "Startup File: [$desc] $fName"
                    event        = @{ dataset = "$Prefix.startup"; module = $Module }
                    startup_file = [ordered]@{
                        path         = Get-PropValue $Row "StartupFolderPath"
                        description  = $desc
                        name         = $fName
                        size         = Get-PropValue $Row "FileInfoSize"
                        modified     = Get-PropValue $Row "LastWriteTime"
                        modified_utc = Get-PropValue $Row "LastWriteTimeUTC"
                        hash         = Get-PropValue $Row "Hash"
                    }
                }
            }
        }
        "ScheduledTasks" {
            $tName = Get-PropValue $Row "TaskName" "unknown"
            return @{
                Suffix   = "tasks"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "Scheduled Task: $tName"
                    event        = @{ dataset = "$Prefix.tasks"; module = $Module }
                    task         = [ordered]@{
                        name         = Get-PropValue $Row "TaskName"
                        author       = Get-PropValue $Row "Author"
                        date         = Get-PropValue $Row "Date"
                        uri          = Get-PropValue $Row "URI"
                        state        = Get-PropValue $Row "State"
                        path         = Get-PropValue $Row "TaskPath"
                        last_run     = Get-PropValue $Row "LastRunTime"
                        last_run_utc = Get-PropValue $Row "LastRunTimeUTC"
                        last_result  = Get-PropValue $Row "LastTaskResult"
                        next_run     = Get-PropValue $Row "NextRunTime"
                    }
                }
            }
        }
        "LogonHistory" {
            $lUser   = Get-PropValue $Row "LogonUser" "unknown"
            $lDomain = Get-PropValue $Row "LogonDomain" "unknown"
            $lId     = Get-PropValue $Row "LogonId" "unknown"
            $lType   = Get-PropValue $Row "LogonType" "unknown"
            return @{
                Suffix   = "logon"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "Logon: $lUser (Domain: $lDomain, ID: $lId, Type: $lType)"
                    event        = @{ dataset = "$Prefix.logon"; module = $Module }
                    logon        = [ordered]@{
                        id             = Get-PropValue $Row "LogonId"
                        type_id        = Get-PropValue $Row "LogonTypeId"
                        type           = Get-PropValue $Row "LogonType"
                        domain         = Get-PropValue $Row "LogonDomain"
                        user           = Get-PropValue $Row "LogonUser"
                        start_time     = Get-PropValue $Row "StartTime"
                        start_time_utc = Get-PropValue $Row "StartTimeUTC"
                    }
                }
            }
        }
        "LocalGroupMembers" {
            $gName = Get-PropValue $Row "GroupName"
            $rawMembers = Get-PropValue $Row "Member"
            $memberList = @(
                if ($rawMembers) {
                    $rawMembers -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                }
            )
            return @{
                Suffix   = "groupmembers"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "Local Group Member: $gName"
                    event        = @{ dataset = "$Prefix.groupmembers"; module = $Module }
                    group        = [ordered]@{
                        name   = $gName
                        member = $memberList
                    }
                }
            }
        }
        "RegistryUserShellFolders" {
            $vName = Get-PropValue $Row "ValueName"
            $vData = Get-PropValue $Row "ValueData"
            return @{
                Suffix   = "registryshellfolders"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "User Shell Folder: $vName = $vData"
                    event        = @{ dataset = "$Prefix.registryshellfolders"; module = $Module }
                    shell_folder = [ordered]@{
                        key        = Get-PropValue $Row "Key"
                        value_name = $vName
                        value_data = $vData
                        time       = Get-PropValue $Row "Time"
                    }
                }
            }
        }
        "Prefetches" {
            $fullName = Get-PropValue $Row "FullName"
            if (-not $fullName) { return $null } # Skip "Prefetch not enabled" string-length row
            return @{
                Suffix   = "prefetch"
                Document = [ordered]@{
                    hostname     = $resolvedHost
                    "@timestamp" = $ts
                    message      = "Prefetch file: $fullName"
                    event        = @{ dataset = "$Prefix.prefetch"; module = $Module }
                    prefetch     = [ordered]@{
                        path         = $fullName
                        created      = Get-PropValue $Row "CreationTimeUtc"
                        accessed     = Get-PropValue $Row "LastAccessTimeUtc"
                        modified     = Get-PropValue $Row "LastWriteTimeUtc"
                        process_name = Get-PropValue $Row "ProcessName"
                    }
                }
            }
        }
        default { return $null }
    }
}

$HuntMetadata = [ordered]@{
    osinfo               = @{ Fields = "os_release.name+os_release.version+os_release.manufacturer+os_release.serial_number"; GroupBy = @("os_release.name") }
    processes            = @{ Fields = "process.grandparent.name+process.parent.name+process.name+process.path+process.command_line"; GroupBy = @("process.name", "process.path") }
    services             = @{ Fields = "service.name+service.display_name+service.state+service.start_mode"; GroupBy = @("service.name", "service.state") }
    network              = @{ Fields = "connection.process_name+connection.local_address+connection.local_port+connection.remote_address+connection.remote_port+connection.state"; GroupBy = @("connection.process_name", "connection.remote_address") }
    shares               = @{ Fields = "share.name+share.account+share.control+share.right"; GroupBy = @("share.name") }
    registryrunkeys      = @{ Fields = "registry.key+registry.value_name+registry.value_data"; GroupBy = @("registry.value_name") }
    startup              = @{ Fields = "startup_file.name+startup_file.path+startup_file.description"; GroupBy = @("startup_file.name") }
    tasks                = @{ Fields = "task.name+task.path+task.state+task.uri"; GroupBy = @("task.name", "task.path") }
    logon                = @{ Fields = "logon.user+logon.type+logon.start_time+logon.domain"; GroupBy = @("logon.user", "logon.type") }
    groupmembers         = @{ Fields = "group.name+group.member"; GroupBy = @("group.name", "group.member") }
    registryshellfolders = @{ Fields = "shell_folder.key+shell_folder.value_name+shell_folder.value_data"; GroupBy = @("shell_folder.value_name") }
    prefetch             = @{ Fields = "prefetch.process_name+prefetch.path+prefetch.created+prefetch.modified"; GroupBy = @("prefetch.process_name") }
}

function Invoke-SelfTest {
    $samples = @{
        OSInfo                   = [PSCustomObject]@{ CSName = 'SRV01'; OperatingSystem = 'Windows Server 2022'; OperatingSystemVersion = '10.0.20348'; Manufacturer = 'Microsoft'; UTCTime = '2026-10-26T10:00:00.0000000Z' }
        Processes                = [PSCustomObject]@{ CSName = 'SRV01'; ProcessName = 'powershell.exe'; ProcessID = '1234'; ParentProcessID = '500'; ParentProcessName = 'explorer.exe'; LineageHash = 'ABC' }
        Services                 = [PSCustomObject]@{ CSName = 'SRV01'; ServiceName = 'WinRM'; ServiceState = 'Running'; StartMode = 'Auto' }
        Connections              = [PSCustomObject]@{ CSName = 'SRV01'; LocalAddress = '10.0.0.5'; LocalPort = '5985'; RemoteAddress = '10.0.0.1'; RemotePort = '51234'; State = 'Established'; OwningProcess = '4' }
        Shares                   = [PSCustomObject]@{ Name = 'C$'; AccountName = 'BUILTIN\Administrators'; AccessControlType = 'Allow'; AccessRight = 'Full' }
        RegistryRun              = [PSCustomObject]@{ KeyName = 'Run'; Details = 'C:\app.exe'; ProcessName = 'app'; Time = '2026-10-26T10:00:00.0000000Z' }
        StartupFolders           = [PSCustomObject]@{ CSName = 'SRV01'; StartupFolderPath = 'C:\Startup'; StartupFolderDescription = 'All Users'; FileInfoName = 'autorun.lnk'; Hash = '123' }
        ScheduledTasks           = [PSCustomObject]@{ CSName = 'SRV01'; TaskName = 'Updater'; State = 'Ready'; TaskPath = '\' }
        LogonHistory             = [PSCustomObject]@{ CSName = 'SRV01'; LogonId = '999'; LogonType = 'Network'; LogonDomain = 'CORP'; LogonUser = 'admin' }
        LocalGroupMembers        = [PSCustomObject]@{ CSName = 'SRV01'; GroupName = 'Administrators'; Member = 'CORP\Domain Admins, SRV01\Administrator' }
        RegistryUserShellFolders = [PSCustomObject]@{ Key = 'Shell Folders'; ValueName = 'Startup'; ValueData = 'C:\Startup'; Time = '2026-10-26T10:00:00.0000000Z' }
        Prefetches               = [PSCustomObject]@{ CSName = 'SRV01'; FullName = 'C:\Windows\Prefetch\CMD.EXE-123.pf'; ProcessName = 'CMD.EXE'; CreationTimeUtc = '2026-10-26T10:00:00Z' }
    }

    foreach ($k in $samples.Keys) {
        $res = Convert-BaselineRowToDocument -CsvName $k -Row $samples[$k] -HostName 'SRV01' -Prefix $DatasetPrefix -Module $ModuleName -ForceIngestTime $false
        if ($null -eq $res -or -not $res.Suffix -or $res.Document.hostname -ne 'SRV01' -or $res.Document.event.dataset -ne "$DatasetPrefix.$($res.Suffix)") {
            throw "SelfTest failed on dataset '$k'."
        }
    }

    # Verify disabled-prefetch string row is ignored
    $disabledPf = [PSCustomObject]@{ Length = 34 }
    if ($null -ne (Convert-BaselineRowToDocument -CsvName "Prefetches" -Row $disabledPf -HostName 'SRV01' -Prefix $DatasetPrefix -Module $ModuleName -ForceIngestTime $false)) {
        throw "SelfTest failed: disabled prefetch row was not filtered."
    }

    # Verify end-to-end CSV export -> Import-Csv -> JSON serialization
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "HostBaselines_SelfTest_$PID"
    $tempHost = Join-Path $tempRoot "SRV01"
    New-Item -ItemType Directory -Path $tempHost -Force | Out-Null
    try {
        foreach ($k in $samples.Keys) {
            $samples[$k] | Export-Csv -Path (Join-Path $tempHost "$k.csv") -NoTypeInformation -Encoding UTF8
        }
        foreach ($csvFile in (Get-ChildItem -Path $tempHost -Filter "*.csv" -File)) {
            $rows = @(Import-Csv -Path $csvFile.FullName -Encoding UTF8)
            $mapped = Convert-BaselineRowToDocument -CsvName $csvFile.BaseName -Row $rows[0] -HostName "SRV01" -Prefix $DatasetPrefix -Module $ModuleName -ForceIngestTime $false
            $json = $mapped.Document | ConvertTo-Json -Depth 6 -Compress
            if (-not $json.Contains('"@timestamp"')) { throw "Missing @timestamp in $($csvFile.BaseName) JSON." }
        }
    } finally {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Output "[OK] All 12 Get-HostBaseline dataset parsers and CSV round-trips passed self-test."
}

if ($SelfTest) {
    Invoke-SelfTest
    return
}

# 1. Resolve BaselinePath
$toolRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if ([string]::IsNullOrWhiteSpace($BaselinePath)) {
    $baselinesRoot = Join-Path $toolRoot "Output/Baselines"
    $latest = if (Test-Path $baselinesRoot) {
        Get-ChildItem -Path $baselinesRoot -Directory -Filter "HostBaselines_*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    } else { $null }

    if (-not $latest) {
        throw "No -BaselinePath specified and no 'HostBaselines_*' folders found under '$baselinesRoot'."
    }
    $BaselinePath = $latest.FullName
}

if (-not (Test-Path $BaselinePath -PathType Container)) {
    throw "Baseline path not found: '$BaselinePath'"
}
$BaselinePath = (Resolve-Path $BaselinePath).Path

# Support passing either HostBaselines_<timestamp> root OR a single <computer> subfolder
$directCsvs = @(Get-ChildItem -Path $BaselinePath -Filter "*.csv" -File -ErrorAction SilentlyContinue)
$hostFolders = @(
    if ($directCsvs.Count -gt 0) {
        Get-Item -Path $BaselinePath
    } else {
        Get-ChildItem -Path $BaselinePath -Directory -ErrorAction SilentlyContinue
    }
)

if ($hostFolders.Count -eq 0) {
    throw "No host baseline folders or CSV files found in '$BaselinePath'."
}

# 2. Validate & prepare Elasticsearch connection
$headers = @{ Accept = 'application/json' }
$skipCertParam = @{}

if (-not $DryRun) {
    if ([string]::IsNullOrWhiteSpace($ElasticUrl)) {
        $ElasticUrl = Read-Host "Enter Elasticsearch URL (e.g. https://10.0.0.10:9200)"
    }
    $ElasticUrl = $ElasticUrl.Trim().TrimEnd('/')
    if ([string]::IsNullOrWhiteSpace($ElasticUrl)) {
        throw "ElasticUrl is required unless -DryRun or -SelfTest is used."
    }

    if ($Credential) {
        $User = $Credential.UserName
        $Password = $Credential.GetNetworkCredential().Password
    }
    if (-not [string]::IsNullOrWhiteSpace($User) -and $null -ne $Password) {
        $pair = "${User}:${Password}"
        $headers['Authorization'] = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
    }

    # Disable certificate verification for self-signed Elastic / Security Onion certs (PS 5.1 & PS 7+)
    if ((Get-Command Invoke-RestMethod).Parameters.ContainsKey('SkipCertificateCheck')) {
        $skipCertParam['SkipCertificateCheck'] = $true
    } else {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        } catch {}
    }
}

Write-Output "=================== Shipping Host Baseline ==================="
Write-Output "Source Path    : $BaselinePath"
Write-Output "Dataset Prefix : $DatasetPrefix (Module: $ModuleName)"
Write-Output "Mode           : $(if ($DryRun) { 'DRY RUN (No HTTP calls)' } elseif ($UseSingleDoc) { 'Single Document POST (/_doc)' } else { "Bulk API (/_bulk, BatchSize=$BatchSize)" })"

$shippedSuffixes = [System.Collections.Generic.HashSet[string]]::new()
$totalShipped = 0

foreach ($hostDir in $hostFolders) {
    $hostName = $hostDir.Name
    $csvFiles = @(Get-ChildItem -Path $hostDir.FullName -Filter "*.csv" -File | Sort-Object Name)
    if ($csvFiles.Count -eq 0) { continue }

    Write-Output "`n--- Host: $hostName ($($csvFiles.Count) CSV file(s)) ---"

    foreach ($csvFile in $csvFiles) {
        $csvBaseName = $csvFile.BaseName
        $rows = @(Import-Csv -Path $csvFile.FullName -Encoding UTF8)
        if ($rows.Count -eq 0) { continue }

        $docs = [System.Collections.Generic.List[object]]::new()
        $suffix = $null

        foreach ($row in $rows) {
            $mapped = Convert-BaselineRowToDocument `
                -CsvName $csvBaseName `
                -Row $row `
                -HostName $hostName `
                -Prefix $DatasetPrefix `
                -Module $ModuleName `
                -ForceIngestTime ([bool]$UseIngestTimestamp)

            if ($null -ne $mapped) {
                $suffix = $mapped.Suffix
                $docs.Add($mapped.Document)
            }
        }

        if ($docs.Count -eq 0 -or -not $suffix) {
            Write-Output "  [$csvBaseName] Skipped (no shippable records)."
            continue
        }

        $indexName = "logs-$DatasetPrefix.$suffix-default"
        [void]$shippedSuffixes.Add($suffix)

        if ($DryRun) {
            Write-Output "  [$csvBaseName] Parsed $($docs.Count) doc(s) -> $indexName"
            $totalShipped += $docs.Count
            continue
        }

        if ($UseSingleDoc) {
            $docUrl = "$ElasticUrl/$indexName/_doc"
            $ok = 0
            foreach ($doc in $docs) {
                $bodyJson = $doc | ConvertTo-Json -Depth 6 -Compress
                try {
                    $null = Invoke-RestMethod -Method Post -Uri $docUrl -Headers $headers -Body $bodyJson -ContentType "application/json; charset=utf-8" @skipCertParam
                    $ok++
                } catch {
                    Write-Warning "  [$csvBaseName] Failed POST to $docUrl : $($_.Exception.Message)"
                }
            }
            Write-Output "  [$csvBaseName] Shipped $ok / $($docs.Count) doc(s) -> $indexName/_doc"
            $totalShipped += $ok
        } else {
            $bulkUrl = "$ElasticUrl/$indexName/_bulk"
            $sent = 0
            for ($i = 0; $i -lt $docs.Count; $i += $BatchSize) {
                $end = [Math]::Min($i + $BatchSize - 1, $docs.Count - 1)
                $sb = [System.Text.StringBuilder]::new()
                for ($j = $i; $j -le $end; $j++) {
                    [void]$sb.AppendLine('{"create":{}}')
                    [void]$sb.AppendLine(($docs[$j] | ConvertTo-Json -Depth 6 -Compress))
                }
                try {
                    $resp = Invoke-RestMethod -Method Post -Uri $bulkUrl -Headers $headers -Body $sb.ToString() -ContentType "application/x-ndjson; charset=utf-8" @skipCertParam
                    $batchCount = ($end - $i + 1)
                    if ($resp -and $resp.errors) {
                        $failedItems = @($resp.items | Where-Object { $_.create.error }).Count
                        $sent += ($batchCount - $failedItems)
                        Write-Warning "  [$csvBaseName] Bulk batch had $failedItems error(s)."
                    } else {
                        $sent += $batchCount
                    }
                } catch {
                    Write-Warning "  [$csvBaseName] Bulk POST failed to $bulkUrl : $($_.Exception.Message)"
                }
            }
            Write-Output "  [$csvBaseName] Shipped $sent / $($docs.Count) doc(s) -> $indexName/_bulk"
            $totalShipped += $sent
        }
    }
}

Write-Output "`n=================== Summary ==================="
Write-Output "Total Documents $(if ($DryRun) { 'Parsed' } else { 'Shipped' }): $totalShipped"

if ($shippedSuffixes.Count -gt 0) {
    $soBase = if (-not [string]::IsNullOrWhiteSpace($SecurityOnionUrl)) {
        $SecurityOnionUrl.Trim().TrimEnd('/')
    } elseif (-not [string]::IsNullOrWhiteSpace($ElasticUrl)) {
        try {
            $u = [Uri]$ElasticUrl
            "https://$($u.Host)"
        } catch { "https://securityonion" }
    } else {
        "https://securityonion"
    }

    Write-Output "`n--- Security Onion Hunt Links ---"
    foreach ($suf in $HuntMetadata.Keys) {
        if (-not $shippedSuffixes.Contains($suf)) { continue }
        $meta = $HuntMetadata[$suf]
        $dataset = "$DatasetPrefix.$suf"
        $groupPart = ($meta.GroupBy | ForEach-Object { "+|+groupby+%22$_%22" }) -join ""
        $huntUrl = "$soBase/#/hunt?q=event.dataset:+%22$dataset%22+|+table+soc_timestamp+$($meta.Fields)$groupPart&z=America/New_York&el=100&gl=10&rt=24&rtu=hours"
        Write-Output "[$dataset] $huntUrl"
    }
}
