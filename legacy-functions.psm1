# PowerShell Admin Tool - Legacy Functions Module (WMI & DCOM / ADSI)
# For legacy environments (Windows XP, Windows Server 2003/2008)

#-----------------------------LEGACY WMI PROCESSES--------------------------------------------------
function Get-LegacyWmiProcess {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) { $Credential = Get-Credential }
    }

    Process {
        foreach ($computer in $ComputerName) {
            try {
                $wmiParams = @{ ComputerName = $computer; Class = "Win32_Process"; ErrorAction = "Stop" }
                if ($Credential) { $wmiParams['Credential'] = $Credential }
                
                $procs = Get-WmiObject @wmiParams | ForEach-Object {
                    [PSCustomObject]@{
                        ProcessName     = $_.Name
                        ProcessId       = $_.ProcessId
                        ParentProcessId = $_.ParentProcessId
                        ExecutablePath  = $_.ExecutablePath
                        CommandLine     = $_.CommandLine
                        CreationDate    = if ($_.CreationDate) { [Management.ManagementDateTimeConverter]::ToDateTime($_.CreationDate).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK') } else { $null }
                        Time            = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime         = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
                $procs
            } catch {
                Write-Error "Failed to query legacy processes on $($computer): $($_.Exception.Message)"
            }
        }
    }
}

#-----------------------------LEGACY SERVICES--------------------------------------------------
function Get-LegacyServiceInfo {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) { $Credential = Get-Credential }
    }

    Process {
        foreach ($computer in $ComputerName) {
            try {
                $wmiParams = @{ ComputerName = $computer; Class = "Win32_Service"; ErrorAction = "Stop" }
                if ($Credential) { $wmiParams['Credential'] = $Credential }
                
                Get-WmiObject @wmiParams | ForEach-Object {
                    [PSCustomObject]@{
                        Name        = $_.Name
                        DisplayName = $_.DisplayName
                        State       = $_.State
                        StartMode   = $_.StartMode
                        StartName   = $_.StartName
                        PathName    = $_.PathName
                        Time        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } catch {
                Write-Error "Failed to query legacy services on $($computer): $($_.Exception.Message)"
            }
        }
    }
}

#-----------------------------LEGACY OS INFO--------------------------------------------------
function Get-LegacyOSInfo {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) { $Credential = Get-Credential }
    }

    Process {
        foreach ($computer in $ComputerName) {
            try {
                $wmiParams = @{ ComputerName = $computer; Class = "Win32_OperatingSystem"; ErrorAction = "Stop" }
                if ($Credential) { $wmiParams['Credential'] = $Credential }
                
                Get-WmiObject @wmiParams | ForEach-Object {
                    $lastBoot = if ($_.LastBootUpTime) { [Management.ManagementDateTimeConverter]::ToDateTime($_.LastBootUpTime) } else { $null }
                    $uptime = if ($lastBoot) { (Get-Date) - $lastBoot } else { $null }
                    
                    [PSCustomObject]@{
                        ComputerName    = $computer
                        Caption         = $_.Caption
                        OSVersion       = $_.Version
                        ServicePack     = $_.CSDVersion
                        Architecture    = $_.OSArchitecture
                        InstallDate     = if ($_.InstallDate) { [Management.ManagementDateTimeConverter]::ToDateTime($_.InstallDate).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK') } else { $null }
                        LastBootUpTime  = if ($lastBoot) { $lastBoot.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK') } else { $null }
                        Uptime          = if ($uptime) { "{0:N0} days, {1:D2}h:{2:D2}m:{3:D2}s" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds } else { $null }
                        Time            = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime         = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } catch {
                Write-Error "Failed to query legacy OS info on $($computer): $($_.Exception.Message)"
            }
        }
    }
}

#-----------------------------LEGACY SHARES--------------------------------------------------
function Get-LegacyShareInfo {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) { $Credential = Get-Credential }
    }

    Process {
        foreach ($computer in $ComputerName) {
            try {
                $wmiParams = @{ ComputerName = $computer; Class = "Win32_Share"; ErrorAction = "Stop" }
                if ($Credential) { $wmiParams['Credential'] = $Credential }
                
                Get-WmiObject @wmiParams | ForEach-Object {
                    [PSCustomObject]@{
                        Name        = $_.Name
                        Path        = $_.Path
                        Description = $_.Description
                        Type        = $_.Type
                        Time        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } catch {
                Write-Error "Failed to query legacy shares on $($computer): $($_.Exception.Message)"
            }
        }
    }
}

#-----------------------------LEGACY CONNECTIONS--------------------------------------------------
function Get-LegacyConnection {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) { $Credential = Get-Credential }
    }

    Process {
        foreach ($computer in $ComputerName) {
            try {
                $wmiParams = @{ ComputerName = $computer; Class = "Win32_NetworkConnection"; ErrorAction = "Stop" }
                if ($Credential) { $wmiParams['Credential'] = $Credential }
                
                Get-WmiObject @wmiParams | ForEach-Object {
                    [PSCustomObject]@{
                        LocalName   = $_.LocalName
                        RemoteName  = $_.RemoteName
                        Status      = $_.ConnectionState
                        ResourceType= $_.ResourceType
                        Time        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } catch {
                Write-Error "Failed to query legacy connections on $($computer): $($_.Exception.Message)"
            }
        }
    }
}

#-----------------------------LEGACY NETWORK ADAPTERS--------------------------------------------------
function Get-LegacyNetworkAdapters {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) { $Credential = Get-Credential }
    }

    Process {
        foreach ($computer in $ComputerName) {
            try {
                $wmiParams = @{ ComputerName = $computer; Class = "Win32_NetworkAdapterConfiguration"; Filter = "IPEnabled = True"; ErrorAction = "Stop" }
                if ($Credential) { $wmiParams['Credential'] = $Credential }
                
                Get-WmiObject @wmiParams | ForEach-Object {
                    [PSCustomObject]@{
                        Description  = $_.Description
                        MACAddress   = $_.MACAddress
                        IPAddress    = ($_.IPAddress) -join ', '
                        IPSubnet     = ($_.IPSubnet) -join ', '
                        DefaultGateway = ($_.DefaultIPGateway) -join ', '
                        DNSServer    = ($_.DNSServerSearchOrder) -join ', '
                        DHCPEnabled  = $_.DHCPEnabled
                        Time         = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime      = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } catch {
                Write-Error "Failed to query legacy network adapters on $($computer): $($_.Exception.Message)"
            }
        }
    }
}

#-----------------------------LEGACY STARTUP COMMANDS--------------------------------------------------
function Get-LegacyStartupFolders {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) { $Credential = Get-Credential }
    }

    Process {
        foreach ($computer in $ComputerName) {
            try {
                $wmiParams = @{ ComputerName = $computer; Class = "Win32_StartupCommand"; ErrorAction = "Stop" }
                if ($Credential) { $wmiParams['Credential'] = $Credential }
                
                Get-WmiObject @wmiParams | ForEach-Object {
                    [PSCustomObject]@{
                        Name        = $_.Name
                        Command     = $_.Command
                        Location    = $_.Location
                        User        = $_.User
                        Time        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } catch {
                Write-Error "Failed to query legacy startup commands on $($computer): $($_.Exception.Message)"
            }
        }
    }
}

#-----------------------------LEGACY SCHEDULED JOBS--------------------------------------------------
function Get-LegacySchTask {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) { $Credential = Get-Credential }
    }

    Process {
        foreach ($computer in $ComputerName) {
            try {
                $wmiParams = @{ ComputerName = $computer; Class = "Win32_ScheduledJob"; ErrorAction = "Stop" }
                if ($Credential) { $wmiParams['Credential'] = $Credential }
                
                Get-WmiObject @wmiParams | ForEach-Object {
                    [PSCustomObject]@{
                        JobId       = $_.JobId
                        Name        = $_.Name
                        Command     = $_.Command
                        StartTime   = $_.StartTime
                        Status      = $_.Status
                        Time        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } catch {
                Write-Error "Failed to query legacy scheduled jobs on $($computer): $($_.Exception.Message)"
            }
        }
    }
}

#-----------------------------LEGACY LOCAL USERS--------------------------------------------------
function Get-LegacyLUser {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) { $Credential = Get-Credential }
    }

    Process {
        foreach ($computer in $ComputerName) {
            try {
                $wmiParams = @{ ComputerName = $computer; Class = "Win32_UserAccount"; Filter = "LocalAccount = True"; ErrorAction = "Stop" }
                if ($Credential) { $wmiParams['Credential'] = $Credential }
                
                Get-WmiObject @wmiParams | ForEach-Object {
                    [PSCustomObject]@{
                        Name        = $_.Name
                        Caption     = $_.Caption
                        Disabled    = $_.Disabled
                        Lockout     = $_.Lockout
                        PasswordRequired = $_.PasswordRequired
                        Time        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } catch {
                Write-Error "Failed to query legacy local users on $($computer): $($_.Exception.Message)"
            }
        }
    }
}

#-----------------------------LEGACY LOCAL GROUPS--------------------------------------------------
function Get-LegacyLGroup {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) { $Credential = Get-Credential }
    }

    Process {
        foreach ($computer in $ComputerName) {
            try {
                $wmiParams = @{ ComputerName = $computer; Class = "Win32_Group"; Filter = "LocalAccount = True"; ErrorAction = "Stop" }
                if ($Credential) { $wmiParams['Credential'] = $Credential }
                
                Get-WmiObject @wmiParams | ForEach-Object {
                    [PSCustomObject]@{
                        Name        = $_.Name
                        Caption     = $_.Caption
                        SID         = $_.SID
                        Description = $_.Description
                        Time        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } catch {
                Write-Error "Failed to query legacy local groups on $($computer): $($_.Exception.Message)"
            }
        }
    }
}

#-----------------------------LEGACY LOGON HISTORY--------------------------------------------------
function Get-LegacyLogOnHistory {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Begin {
        if (!$Credential) { $Credential = Get-Credential }
    }

    Process {
        foreach ($computer in $ComputerName) {
            try {
                # Event 528 (Successful Logon) and 540 (Successful Network Logon) for WinXP / 2003
                $wmiParams = @{
                    ComputerName = $computer
                    Class        = "Win32_NTLogEvent"
                    Filter       = "Logfile = 'Security' AND (EventCode = 528 OR EventCode = 540 OR EventCode = 4624)"
                    ErrorAction  = "Stop"
                }
                if ($Credential) { $wmiParams['Credential'] = $Credential }
                
                Get-WmiObject @wmiParams | ForEach-Object {
                    [PSCustomObject]@{
                        EventCode   = $_.EventCode
                        TimeGenerated = if ($_.TimeGenerated) { [Management.ManagementDateTimeConverter]::ToDateTime($_.TimeGenerated).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK') } else { $null }
                        User        = $_.User
                        Message     = $_.Message
                        Time        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } catch {
                Write-Error "Failed to query legacy logon history on $($computer): $($_.Exception.Message)"
            }
        }
    }
}

#-----------------------------LEGACY AD DOMAIN CONTROLLERS--------------------------------------------------
function Get-LegacyDomainController {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Process {
        try {
            $searcher = [adsisearcher]'(&(objectCategory=computer)(primaryGroupID=516))'
            $searcher.FindAll() | ForEach-Object {
                $props = $_.Properties
                [PSCustomObject]@{
                    Name               = $props["name"] -as [string]
                    DNSHostName        = $props["dnshostname"] -as [string]
                    OperatingSystem    = $props["operatingsystem"] -as [string]
                    OperatingSystemVer = $props["operatingsystemversion"] -as [string]
                    DistinguishedName  = $props["distinguishedname"] -as [string]
                    Time               = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    UTCTime            = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }
        } catch {
            Write-Error "Failed to query legacy domain controllers: $($_.Exception.Message)"
        }
    }
}

#-----------------------------LEGACY AD DOMAIN USERS--------------------------------------------------
function Get-LegacyDomainUser {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Process {
        try {
            $searcher = [adsisearcher]'(&(objectCategory=user)(objectClass=user))'
            $searcher.PropertiesToLoad.AddRange(@('samaccountname', 'name', 'userprincipalname', 'logoncount', 'description', 'distinguishedname'))
            $searcher.FindAll() | ForEach-Object {
                $props = $_.Properties
                [PSCustomObject]@{
                    Username          = $props['samaccountname'] -as [string]
                    Name              = $props['name'] -as [string]
                    UserPrincipalName = $props['userprincipalname'] -as [string]
                    LogonCount        = $props['logoncount'] -as [string]
                    Description       = $props['description'] -as [string]
                    DistinguishedName = $props['distinguishedname'] -as [string]
                    Time              = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    UTCTime           = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }
        } catch {
            Write-Error "Failed to query legacy domain users: $($_.Exception.Message)"
        }
    }
}

#-----------------------------LEGACY AD DOMAIN GROUPS--------------------------------------------------
function Get-LegacyDomainGroup {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [PSCredential]$Credential
    )

    Process {
        try {
            $searcher = [adsisearcher]'(objectCategory=group)'
            $searcher.PropertiesToLoad.AddRange(@('name', 'grouptype', 'samaccountname', 'distinguishedname'))
            $searcher.FindAll() | ForEach-Object {
                $props = $_.Properties
                [PSCustomObject]@{
                    GroupName         = $props['name'] -as [string]
                    GroupType         = $props['grouptype'] -as [int]
                    SamAccountName    = $props['samaccountname'] -as [string]
                    DistinguishedName = $props['distinguishedname'] -as [string]
                    Time              = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    UTCTime           = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }
        } catch {
            Write-Error "Failed to query legacy domain groups: $($_.Exception.Message)"
        }
    }
}

#-----------------------------LEGACY HOST BASELINE--------------------------------------------------
function Get-LegacyHostBaseline {
    <#
    .SYNOPSIS
        Generates a baseline of legacy host configurations using WMI over DCOM/RPC.
    .DESCRIPTION
        Runs WMI baseline queries against target legacy computers (e.g. Windows XP / Server 2003) and exports CSV files into per-computer subfolders.
    .PARAMETER ComputerName
        Target computer names. Defaults to 'localhost'.
    .PARAMETER Credential
        Optional PSCredential object.
    .PARAMETER OutputFolder
        Output directory path. Defaults to 'LegacyBaselines_yyyyMMdd_HHmmss'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [string]$OutputFolder
    )

    Begin {
        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
            $OutputFolder = Join-Path (Get-Location) "LegacyBaselines_$timestamp"
        }
        $OutputFolder = [System.IO.Path]::GetFullPath($OutputFolder)

        if (-not (Test-Path $OutputFolder)) {
            New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
        }
        Write-Output "Legacy baselines will be saved in: $OutputFolder"
    }

    Process {
        foreach ($computer in $ComputerName) {
            $compNameClean = $computer -replace '[^a-zA-Z0-9.-]', '_'
            Write-Output "=================== Baselining Legacy Target: $computer ==================="

            $targetFolder = Join-Path $OutputFolder $compNameClean
            if (-not (Test-Path $targetFolder)) {
                New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
            }

            # Helper function to run and export WMI baseline
            function Run-AndExportLegacy {
                param([string]$Name, [scriptblock]$ScriptBlock)
                Write-Output "Running '$Name'..."
                try {
                    $data = & $ScriptBlock
                    if ($data) {
                        $csvPath = Join-Path $targetFolder "${Name}.csv"
                        $data | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
                        Write-Output "-> Successfully exported to: $csvPath"
                    } else {
                        Write-Output "-> No data returned."
                    }
                } catch {
                    Write-Output "WARNING: Failed to run legacy baseline '$Name': $($_.Exception.Message)"
                }
            }

            Run-AndExportLegacy -Name "OSInfo" -ScriptBlock { Get-LegacyOSInfo -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "Processes" -ScriptBlock { Get-LegacyWmiProcess -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "Services" -ScriptBlock { Get-LegacyServiceInfo -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "Connections" -ScriptBlock { Get-LegacyConnection -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "Shares" -ScriptBlock { Get-LegacyShareInfo -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "NetworkAdapters" -ScriptBlock { Get-LegacyNetworkAdapters -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "StartupCommands" -ScriptBlock { Get-LegacyStartupFolders -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "ScheduledJobs" -ScriptBlock { Get-LegacySchTask -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "LocalUsers" -ScriptBlock { Get-LegacyLUser -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "LocalGroups" -ScriptBlock { Get-LegacyLGroup -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "LogonHistory" -ScriptBlock { Get-LegacyLogOnHistory -ComputerName $computer -Credential $Credential }
        }
    }

    End {
        Write-Output "Legacy baselining run completed. All generated files are in: $OutputFolder"
    }
}

#-----------------------------LEGACY DOMAIN BASELINE--------------------------------------------------
function Get-LegacyDomainBaseline {
    <#
    .SYNOPSIS
        Generates a baseline of legacy domain and host configurations using WMI and ADSI LDAP.
    .DESCRIPTION
        Runs WMI baseline queries plus legacy Active Directory queries against legacy Domain Controllers (e.g. Windows Server 2003 / 2008).
    .PARAMETER ComputerName
        Target computer names. Defaults to 'localhost'.
    .PARAMETER Credential
        Optional PSCredential object.
    .PARAMETER OutputFolder
        Output directory path. Defaults to 'LegacyDomainBaselines_yyyyMMdd_HHmmss'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [string]$OutputFolder
    )

    Begin {
        if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
            $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
            $OutputFolder = Join-Path (Get-Location) "LegacyDomainBaselines_$timestamp"
        }
        $OutputFolder = [System.IO.Path]::GetFullPath($OutputFolder)

        if (-not (Test-Path $OutputFolder)) {
            New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
        }
        Write-Output "Legacy domain baselines will be saved in: $OutputFolder"
    }

    Process {
        foreach ($computer in $ComputerName) {
            $compNameClean = $computer -replace '[^a-zA-Z0-9.-]', '_'
            Write-Output "=================== Baselining Legacy Domain Target: $computer ==================="

            $targetFolder = Join-Path $OutputFolder $compNameClean
            if (-not (Test-Path $targetFolder)) {
                New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
            }

            function Run-AndExportLegacy {
                param([string]$Name, [scriptblock]$ScriptBlock)
                Write-Output "Running '$Name'..."
                try {
                    $data = & $ScriptBlock
                    if ($data) {
                        $csvPath = Join-Path $targetFolder "${Name}.csv"
                        $data | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
                        Write-Output "-> Successfully exported to: $csvPath"
                    } else {
                        Write-Output "-> No data returned."
                    }
                } catch {
                    Write-Output "WARNING: Failed to run legacy baseline '$Name': $($_.Exception.Message)"
                }
            }

            # WMI Host Queries
            Run-AndExportLegacy -Name "OSInfo" -ScriptBlock { Get-LegacyOSInfo -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "Processes" -ScriptBlock { Get-LegacyWmiProcess -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "Services" -ScriptBlock { Get-LegacyServiceInfo -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "Connections" -ScriptBlock { Get-LegacyConnection -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "Shares" -ScriptBlock { Get-LegacyShareInfo -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "NetworkAdapters" -ScriptBlock { Get-LegacyNetworkAdapters -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "StartupCommands" -ScriptBlock { Get-LegacyStartupFolders -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "ScheduledJobs" -ScriptBlock { Get-LegacySchTask -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "LocalUsers" -ScriptBlock { Get-LegacyLUser -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "LocalGroups" -ScriptBlock { Get-LegacyLGroup -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "LogonHistory" -ScriptBlock { Get-LegacyLogOnHistory -ComputerName $computer -Credential $Credential }

            # ADSI Domain Queries
            Run-AndExportLegacy -Name "ADDomainController" -ScriptBlock { Get-LegacyDomainController -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "ADDomainUser" -ScriptBlock { Get-LegacyDomainUser -ComputerName $computer -Credential $Credential }
            Run-AndExportLegacy -Name "ADDomainGroup" -ScriptBlock { Get-LegacyDomainGroup -ComputerName $computer -Credential $Credential }
        }
    }

    End {
        Write-Output "Legacy domain baselining run completed. All generated files are in: $OutputFolder"
    }
}
