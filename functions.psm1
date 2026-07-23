#-------------------------------------------------------------------------------
# PROCESSES
#-------------------------------------------------------------------------------
function Get-ProcessInfo {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
        $ComputerName,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {
        $processes = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $useCim = [bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
            $processes = if ($useCim) {
                Get-CimInstance -ClassName Win32_Process
            } else {
                Get-WmiObject -Class Win32_Process
            }
            $processLookup = @{}

            # Create a lookup table for process IDs and names
            foreach ($process in $processes) {
                $processLookup[$process.ProcessID] = $process.Name
            }

            $results = @()

            foreach ($process in $processes) {
                $parentProcessID = $process.ParentProcessID
                $parentProcessName = $processLookup[$parentProcessID] -as [string]

                $grandparentProcessName = $null
                $grandparentProcessID = $null

                if ($parentProcessName) {
                    $grandparentProcObj = if ($useCim) {
                        Get-CimInstance -ClassName Win32_Process -Filter "ProcessID = $parentProcessID"
                    } else {
                        Get-WmiObject -Class Win32_Process -Filter "ProcessID = $parentProcessID"
                    }
                    $grandparentProcessID = ($grandparentProcObj | Select-Object -ExpandProperty ParentProcessID) -as [uint32]

                    if ($grandparentProcessID -ne 0) {
                        $grandparentProcessName = $processLookup[$grandparentProcessID] -as [string]
                    }
                }

                $lineageHash = [System.Security.Cryptography.MD5]::Create().ComputeHash(
                    [System.Text.Encoding]::UTF8.GetBytes("$grandparentProcessName|$parentProcessName|$($process.Name)")
                )
                $lineageHashString = [System.BitConverter]::ToString($lineageHash).Replace("-", "")

                $results += [PSCustomObject]@{
                    "CSName"                 = $process.CSName
                    "ProcessName"            = $process.Name
                    "ProcessID"              = $process.ProcessID
                    "ParentProcessName"      = $parentProcessName
                    "ParentProcessID"        = $parentProcessID
                    "GrandParentProcessName" = $grandparentProcessName
                    "GrandParentProcessID"   = $grandparentProcessID
                    "HandleCount"            = $process.HandleCount
                    "ThreadCount"            = $process.ThreadCount
                    "Path"                   = $process.Path
                    "CommandLine"            = $process.CommandLine
                    "PSComputerName"         = $process.PSComputerName
                    "RunspaceId"             = $process.RunspaceId
                    "PSShowComputerName"     = $true
                    "Time"                   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    "UTCTime"                = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    "LineageHash"            = $lineageHashString
                }
            }

            $results
        }

        $processes
    }
}
Set-Alias -Name Get-WmiProcess -Value Get-ProcessInfo


#-------------------------------------------------------------------------------
# SERVICES
#-------------------------------------------------------------------------------
function Get-ServiceInfo
{
    [cmdletbinding()]
    Param
    (
        [Parameter(ValueFromPipeline=$true)]
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
        $services = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $useCim = [bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
            $allProcesses = if ($useCim) {
                Get-CimInstance -ClassName Win32_Process
            } else {
                Get-WmiObject -Class Win32_Process
            }
            $processMap = @{}
            foreach ($p in $allProcesses) { $processMap[$p.ProcessId] = $p }

            $serviceList = if ($useCim) {
                Get-CimInstance -Class Win32_Service
            } else {
                Get-WmiObject -Class Win32_Service
            }

            $serviceList | ForEach-Object {
                $proc = $null
                if ($_.ProcessId -and $processMap.ContainsKey($_.ProcessId)) {
                    $proc = $processMap[$_.ProcessId]
                }
                $parentProcName = $null
                if ($proc -and $proc.ParentProcessID -and $processMap.ContainsKey($proc.ParentProcessID)) {
                    $parentProcName = $processMap[$proc.ParentProcessID].Name
                }
                [PSCustomObject]@{
                    "CSName"             = $_.SystemName
                    "PSComputerName"     = $_.PSComputerName
                    "ServiceName"        = $_.Name
                    "ServiceState"       = $_.State
                    "SystemName"         = $_.SystemName
                    "ServiceDisplayName" = $_.DisplayName
                    "ServiceDescription" = $_.Description
                    "PathName"           = $_.PathName
                    "InstallDate"        = $_.InstallDate
                    "ProcessId"          = $_.ProcessId
                    "ProcessName"        = if ($proc) { $proc.Name } else { $null }
                    "ParentProcessID"    = if ($proc) { $proc.ParentProcessID } else { $null }
                    "ParentProcessName"  = $parentProcName
                    "StartMode"          = $_.StartMode
                    "ExitCode"           = $_.ExitCode
                    "DelayedAutoStart"   = $_.DelayedAutoStart
                    "Time"               = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    "UTCTime"            = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }
        }
        $services
    }
} 


#-------------------------------------------------------------------------------
# CONNECTIONS
#-------------------------------------------------------------------------------
function Get-Connection {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [String[]]
        $ComputerName,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {
        $connections = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $useCim = [bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
            $processes = if ($useCim) {
                Get-CimInstance Win32_Process
            } else {
                Get-WmiObject Win32_Process
            }

            if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
                $connections = Get-NetTCPConnection -State Established
                $connections | ForEach-Object {
                    $connection = $_
                    $process = $processes | Where-Object { $_.ProcessID -eq $connection.OwningProcess }
                    $parentProcessID = $process.ParentProcessID
                    $parentProcess = $processes | Where-Object { $_.ProcessID -eq $parentProcessID }

                    [PSCustomObject]@{
                        PSComputerName   = $connection.PSComputerName
                        CSName           = $process.CSName
                        LocalAddress     = $connection.LocalAddress
                        LocalPort        = $connection.LocalPort
                        RemoteAddress    = $connection.RemoteAddress
                        RemotePort       = $connection.RemotePort
                        State            = $connection.State
                        OwningProcess    = $connection.OwningProcess
                        ProcessName      = $process.Name
                        ProcessID        = $process.ProcessId
                        ParentProcessID  = $parentProcess.ProcessID
                        ParentProcess    = $parentProcess.Name
                        CreationTime     = $connection.CreationTime
                        Time             = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime          = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } else {
                $netstatOutput = netstat -ano 2>$null
                $processMap = @{}
                foreach ($p in $processes) { $processMap[$p.ProcessID] = $p }

                foreach ($line in $netstatOutput) {
                    if ($line -match '^\s*(TCP|UDP)\s+([^\s:]+):(\d+)\s+([^\s:]+):(\d+)\s+(\S+)\s+(\d+)') {
                        $localAddr = $matches[2]
                        $localPort = $matches[3]
                        $remoteAddr = $matches[4]
                        $remotePort = $matches[5]
                        $state = $matches[6]
                        $pidVal = [uint32]$matches[7]

                        $proc = $processMap[$pidVal]
                        $parentProc = $null
                        if ($proc -and $proc.ParentProcessID) {
                            $parentProc = $processMap[[uint32]$proc.ParentProcessID]
                        }

                        [PSCustomObject]@{
                            PSComputerName   = $env:COMPUTERNAME
                            CSName           = $env:COMPUTERNAME
                            LocalAddress     = $localAddr
                            LocalPort        = $localPort
                            RemoteAddress    = $remoteAddr
                            RemotePort       = $remotePort
                            State            = $state
                            OwningProcess    = $pidVal
                            ProcessName      = if ($proc) { $proc.Name } else { $null }
                            ProcessID        = $pidVal
                            ParentProcessID  = if ($parentProc) { $parentProc.ProcessID } else { $null }
                            ParentProcess    = if ($parentProc) { $parentProc.Name } else { $null }
                            CreationTime     = $null
                            Time             = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                            UTCTime          = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    }
                }
            }
        }
        $connections
    }
}


#-------------------------------------------------------------------------------
# SCHEDULED TASKS
#-------------------------------------------------------------------------------
function Get-SchTask
{
    [cmdletbinding()]
    Param
    (
        [Parameter(ValueFromPipeline=$true)]
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
        $tasks = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock { 
            if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
                $schtasks = (Get-ScheduledTask)
                $taskInfoList = @()

                foreach ($task in $schtasks)
                {
                    $taskinfo = Get-ScheduledTaskInfo -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction SilentlyContinue
                    $lastRunUtc = if ($taskinfo -and $taskinfo.LastRunTime) {
                        try { ($taskinfo.LastRunTime).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK') } catch { $null }
                    } else { $null }

                    $taskInfoList += [PSCustomObject]@{
                        CSName          = $env:COMPUTERNAME
                        PSComputerName  = $task.PSComputerName
                        TaskName        = $task.TaskName
                        Author          = $task.Author
                        Date            = $task.Date
                        URI             = $task.URI
                        State           = $task.State
                        TaskPath        = $task.TaskPath
                        LastRunTime     = if ($taskinfo) { $taskinfo.LastRunTime } else { $null }
                        LastRunTimeUTC  = $lastRunUtc
                        LastTaskResult  = if ($taskinfo) { $taskinfo.LastTaskResult } else { $null }
                        NextRunTime     = if ($taskinfo) { $taskinfo.NextRunTime } else { $null }
                        Time            = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime         = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
                $taskInfoList
            } else {
                Get-WmiObject Win32_ScheduledJob -ErrorAction SilentlyContinue | ForEach-Object {
                    [PSCustomObject]@{
                        CSName          = $env:COMPUTERNAME
                        PSComputerName  = $_.PSComputerName
                        TaskName        = $_.Name
                        Author          = $null
                        Date            = $null
                        URI             = $null
                        State           = $_.Status
                        TaskPath        = $_.Command
                        LastRunTime     = $_.StartTime
                        LastRunTimeUTC  = $null
                        LastTaskResult  = $_.JobId
                        NextRunTime     = $null
                        Time            = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime         = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            }
        }

        $tasks
    }    
}
#-------------------------------------------------------------------------------
# PREFETCH
#-------------------------------------------------------------------------------
function Get-Prefetch 
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
        If (!$Credential) { $Credential = Get-Credential }
    }
    Process
    {   
        $prefetchData = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $pfconf = (Get-ItemProperty "hklm:\system\currentcontrolset\control\session manager\memory management\prefetchparameters").EnablePrefetcher 

            Switch -Regex ($pfconf) {
                "[1-3]" {
                    $prefetches = ls $env:windir\Prefetch\*.pf | ForEach-Object {
                        $processName = $_.Name -replace '-.*$'

                        [PSCustomObject]@{
                            CSName             = $env:COMPUTERNAME
                            FullName           = $_.FullName
                            CreationTimeUtc    = $_.CreationTimeUtc.ToString("o")
                            LastAccessTimeUtc  = $_.LastAccessTimeUtc.ToString("o")
                            LastWriteTimeUtc   = $_.LastWriteTimeUtc.ToString("o")
                            Time               = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                            UTCTime            = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                            ProcessName        = $processName
                        }
                    }
                    $prefetches
                }
                default {
                    Write-Output "Prefetch not enabled on ${env:COMPUTERNAME}."
                }
            }
        }

        $prefetchData
    }
}

#-------------------------------------------------------------------------------
# OS INFORMATION
#-------------------------------------------------------------------------------
function Get-OSInfo 
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
        $osInfo = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                Get-CimInstance -ClassName Win32_OperatingSystem
            } else {
                Get-WmiObject -Class Win32_OperatingSystem
            }
        }

        $osData = $osInfo | ForEach-Object {
            $installDt = if ($_.InstallDate -is [DateTime]) { $_.InstallDate.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK') } elseif ($_.InstallDate) { [Management.ManagementDateTimeConverter]::ToDateTime($_.InstallDate).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK') } else { $null }
            $lastBootDt = if ($_.LastBootUpTime -is [DateTime]) { $_.LastBootUpTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK') } elseif ($_.LastBootUpTime) { [Management.ManagementDateTimeConverter]::ToDateTime($_.LastBootUpTime).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK') } else { $null }

            [PSCustomObject]@{
                "CSName"                 = $_.CSName
                "OperatingSystem"        = $_.Caption
                "OperatingSystemVersion" = $_.Version
                "Manufacturer"           = $_.Manufacturer
                "RegisteredOwner"        = $_.RegisteredUser
                "InstallDate"            = $installDt
                "LastBootTime"           = $lastBootDt
                "SerialNumber"           = $_.SerialNumber
                "Time"                   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                "UTCTime"                = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
            }
        }

        $osData
    }
}

#-------------------------------------------------------------------------------
# REGISTRY RUN KEYS
#-------------------------------------------------------------------------------
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
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce',
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce',
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunServices',
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunServices'
            )

            $registryRunData = foreach ($keyPath in $registryRunKeys) {
                $keyName = $keyPath -replace '^.+\\'

                if (Test-Path $keyPath) {
                    $keyValues = Get-ItemProperty -Path $keyPath | Select-Object -Property *
                    
                    foreach ($valueName in $keyValues.PSObject.Properties.Name) {
                        $valueData = $keyValues.$valueName
                        
                        # Check if the value is a program configured for startup
                        if ($valueData -match '^.+\.exe') {
                            $processName = [regex]::Match($valueData, '[^\\/]+(?=\.exe)').Value
                            
                            if ([string]::IsNullOrEmpty($processName)) {
                                $processName = [io.path]::GetFileNameWithoutExtension($valueData)
                            }
                            
                            $keyName | Select-Object -Property @{Name = 'KeyName'; Expression = {$_}}, @{Name = 'Details'; Expression = {$valueData}}, @{Name = 'ProcessName'; Expression = {$processName}}, @{Name = 'Time'; Expression = {(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')}}
                        }
                    }
                }
            }

            $registryRunData
        }
    }
}

function Get-RegistryUserShellFolders {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [String[]]
        $ComputerName,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {
        Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $shellFoldersKeys = @(
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders',
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
            )

            $shellFoldersData = foreach ($keyPath in $shellFoldersKeys) {
                if (Test-Path $keyPath) {
                    $keyValues = Get-ItemProperty -Path $keyPath | Select-Object -Property *
                    $keyName = $keyPath -replace '^.+\\'

                    foreach ($valueName in $keyValues.PSObject.Properties.Name) {
                        $valueData = $keyValues.$valueName
                        [PSCustomObject]@{
                            Key         = $keyName
                            ValueName   = $valueName
                            ValueData   = $valueData
                            Time        = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    }
                }
            }

            $shellFoldersData
        }
    }
}





#-------------------------------------------------------------------------------
# STARTUP FOLDERS
#-------------------------------------------------------------------------------
function Get-StartupFolders
{
    [CmdletBinding()]
    Param
    (
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
        $startupData = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            $startupFolders = @(
            @{
                Path        = ($env:APPDATA) + '\Microsoft\Windows\Start Menu\Programs\Startup'
                Description = "User Startup Folder"
            }
            @{
                Path        = ($env:ProgramData) + '\Microsoft\Windows\Start Menu\Programs\Startup'
                Description = "All Users Startup Folder"
            }
        )

            foreach ($folder in $startupFolders)
            {
                if (Test-Path -Path $folder.Path -PathType Container)
                {
                    $items = Get-ChildItem -Path $folder.Path -File

                    if ($items)
                    {
                        $items | ForEach-Object {
                            $file = $_
                            $fileInfo = $file | Get-Item

                            [PSCustomObject]@{
                                CSName                   = $env:COMPUTERNAME
                                StartupFolderPath        = $file.DirectoryName
                                StartupFolderDescription = $folder.Description
                                FileInfoName             = $fileInfo.Name
                                FileInfoSize             = $fileInfo.Length
                                LastWriteTime            = $fileInfo.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                LastWriteTimeUTC         = $fileInfo.LastWriteTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                Time                     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                UTCTime                  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                Hash                     = (Get-FileHash -Path $file.FullName -Algorithm SHA1).Hash

                            }
                        }
                    }
                }
            }
        }

        return $startupData
    }
}

#-------------------------------------------------------------------------------
# LOCAL USERS
#-------------------------------------------------------------------------------
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
            $useCim = [bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
            $userList = if ($useCim) {
                Get-CimInstance -ClassName Win32_UserAccount -Filter "LocalAccount = True"
            } else {
                Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount = True"
            }

            $userList | ForEach-Object {
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
                    "Time"                        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    "UTCTime"                     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }
        }

        return $usersData
    }
}

#-------------------------------------------------------------------------------
# LOCAL GROUPS
#-------------------------------------------------------------------------------
function Get-LGroup
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
            $useCim = [bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
            $groupList = if ($useCim) {
                Get-CimInstance -ClassName Win32_Group -Filter "LocalAccount = True"
            } else {
                Get-WmiObject -Class Win32_Group -Filter "LocalAccount = True"
            }

            $groupList | ForEach-Object {
                [PSCustomObject]@{
                    "CSName"                 = $env:COMPUTERNAME
                    "LocalGroupName"         = $_.Name
                    "LocalGroupSID"          = $_.SID
                    "LocalGroupDomain"       = $_.Domain
                    "LocalGroupCaption"      = $_.Caption
                    "LocalGroupDescription"  = $_.Description
                    "LocalGroupLocalAccount" = $_.LocalAccount
                    "LocalGroupSIDType"      = $_.SIDType
                    "Time"                   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    "UTCTime"                = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }
        }
    }
}

#-------------------------------------------------------------------------------
# LOCAL GROUP MEMBERS
#-------------------------------------------------------------------------------
function Get-LGroupMembers
{
    [cmdletbinding()]
    Param
    (
        [Parameter(ValueFromPipeline=$true)]
        [string[]]
        $ComputerName,

        [pscredential]
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
            $useCim = [bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
            $localGroups = if ($useCim) {
                Get-CimInstance -ClassName Win32_Group -Filter "LocalAccount = True"
            } else {
                Get-WmiObject -Class Win32_Group -Filter "LocalAccount = True"
            }

            foreach ($group in $localGroups) {
                $name = $group.Name
                $members = $null

                if (Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue) {
                    try {
                        $mObjs = Get-LocalGroupMember -Group $name -ErrorAction Stop
                        $members = ($mObjs | ForEach-Object { $_.Name }) -join ', '
                    } catch {
                        $members = $null
                    }
                }

                if (-not $members) {
                    $groupUsers = if ($useCim) {
                        Get-CimInstance -ClassName Win32_GroupUser
                    } else {
                        Get-WmiObject -Class Win32_GroupUser
                    }
                    $mList = $groupUsers | Where-Object { $_.GroupComponent -like "*Name=`"$name`"*" -or $_.GroupComponent.Name -eq $name } | ForEach-Object {
                        if ($_.PartComponent) {
                            if ($_.PartComponent.Domain -and $_.PartComponent.Name) {
                                "$($_.PartComponent.Domain)\$($_.PartComponent.Name)"
                            } else {
                                "$($_.PartComponent)"
                            }
                        }
                    }
                    $members = ($mList | Where-Object { $_ }) -join ', '
                }

                [PSCustomObject]@{
                    CSName    = $env:COMPUTERNAME
                    GroupName = $name 
                    Member    = $members
                    Time      = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK') 
                    UTCTime   = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')   
                }
            }
        }
    }
}

#-------------------------------------------------------------------------------
# SHARES
#-------------------------------------------------------------------------------
function Get-ShareInfo
{
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
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
            if (Get-Command Get-SmbShare -ErrorAction SilentlyContinue) {
                foreach ($share in (Get-SmbShare).Name) {
                    $accessInfo = Get-SmbShareAccess $share -ErrorAction SilentlyContinue
                    if ($accessInfo) {
                        $accessInfo | Add-Member -NotePropertyName "Time" -NotePropertyValue (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK') -ErrorAction SilentlyContinue
                        $accessInfo
                    }
                }
            } else {
                Get-WmiObject Win32_Share -ErrorAction SilentlyContinue | ForEach-Object {
                    [PSCustomObject]@{
                        Name        = $_.Name
                        Path        = $_.Path
                        Description = $_.Description
                        Type        = $_.Type
                        Time        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            }
        }
    }    
}

#-------------------------------------------------------------------------------
# LOGON HISTORY
#-------------------------------------------------------------------------------
function Get-LogOnHistory
{
    [cmdletbinding()]
    Param
    (
        [Parameter(ValueFromPipeline=$true)]
        [string[]]
        $ComputerName,

        [pscredential]
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
            $useCim = [bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
            $loggedOnUsers = if ($useCim) {
                Get-CimInstance -ClassName Win32_LoggedOnUser
            } else {
                Get-WmiObject -Class Win32_LoggedOnUser
            }

            $sessions = if ($useCim) {
                Get-CimInstance -ClassName Win32_LogonSession
            } else {
                Get-WmiObject -Class Win32_LogonSession
            }

            $logons = @()

            foreach ($user in $loggedOnUsers)
            {
                if ($user.Antecedent -and $user.Dependent) {
                    $logons += [PSCustomObject]@{
                        Domain  = if ($user.Antecedent.Domain) { $user.Antecedent.Domain } else { $user.Antecedent }
                        User    = if ($user.Antecedent.Name) { $user.Antecedent.Name } else { $user.Antecedent }
                        LogonId = if ($user.Dependent.LogonId) { $user.Dependent.LogonId } else { $user.Dependent }
                    }
                }
            }

            $logonDetail = foreach ($session in $sessions)
            {
                $logonType = switch ($session.LogonType)
                {
                    2 { "Network" }
                    3 { "Batch" }
                    4 { "Service" }
                    5 { "Unlock" }
                    7 { "Unlock (Cleartext)" }
                    8 { "Remote Interactive" }
                    9 { "Cached Interactive" }
                    Default { "Unknown" }
                }

                $startTimeUTC = $null
                if ($session.StartTime -is [DateTime]) {
                    $startTimeUTC = $session.StartTime.ToUniversalTime()
                } elseif ($session.StartTime) {
                    try { $startTimeUTC = [Management.ManagementDateTimeConverter]::ToDateTime($session.StartTime).ToUniversalTime() } catch { $null }
                }

                [PSCustomObject]@{
                    CSName        = $env:COMPUTERNAME
                    LogonId       = $session.LogonId
                    LogonTypeId   = $session.LogonType
                    LogonType     = $logonType
                    LogonDomain   = ($logons | Where-Object { $_.LogonId -eq $session.LogonId }).Domain
                    LogonUser     = ($logons | Where-Object { $_.LogonId -eq $session.LogonId }).User
                    StartTime     = $session.StartTime
                    StartTimeUTC  = $startTimeUTC
                    Time          = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                }
            }

            $logonDetail
        }
    }    
}




#-------------------------------------------------------------------------------
# EVENT LOGS & UTILITIES
#-------------------------------------------------------------------------------

function Get-CriticalEventXML
{ 
    [cmdletbinding()]
    Param
    (

        [DateTime]
        $BeginTime,

        [DateTime]
        $EndTime,

        [string[]]
        $ComputerName,

        [pscredential]
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
        
        $toolRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
        $local_path = Join-Path $toolRoot "Output/EventXML"
        if (-not (Test-Path -Path $local_path -PathType Container)) {
            New-Item -Path $local_path -ItemType Directory -Force | Out-Null
        }

        $num = 0 # Used to make sure there is a unique name for each file created

        foreach ($computer in $ComputerName) {
             $num++
             $temp_path = Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {Join-Path -Path $env:USERPROFILE -ChildPath 'temp'}
             $hostname = Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {hostname}
             $filename = ($hostname + '-' + $num.ToString() + '-events.xml')
             $export_path = ($temp_path + '\' + $filename) # path where the XML file will be exported on the endpoint

                Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {

                    # List of Event IDs to capture
                    $eventIDs = @(
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4624
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4634
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4688
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4698
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4702
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4740
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4625
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 5152
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 5154
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 5155
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 5156
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 5157
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4648
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4672
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4673
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4769
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 4771
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 5140
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Security'
                            ID = 1102
                        },
                        [PSCustomObject]@{
                            Event_Log = 'Microsoft-Windows-PowerShell/Operational'
                            ID = 4104
                        }
                    )

            
                    $events = foreach ($event in $eventIDs) {
                        Get-WinEvent -FilterHashtable @{
                            LogName    = $event.Event_Log
                            StartTime  = $using:BeginTime
                            EndTime    = $using:EndTime
                            Id         = $event.ID
                        } -ErrorAction Ignore
                    }


                    # Create export directory if it doesn't exist
                     if (-not (Test-Path -Path $using:temp_path -PathType Container)) {
                                                         New-Item -ItemType Directory -Path $using:temp_path -Force
                                                                   }
                     

                   $events | Export-Clixml -Path $using:export_path -Force 

                } # End of Invoke Command

                # PSSession to pull the file back
                $session = New-PSSession -ComputerName $computer -Credential $Credential

                # Copy the file from the remote machine to your local machine
                Copy-Item -Path $export_path -Destination $local_path -FromSession $session

                # Remove event log from the remote machine
                Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                    Remove-Item -Path $using:export_path
                }

             } # End of Invoke Command

          

             } # End of Primary For Loop
    }

# Update Events (Enrich) -- This is meant to have event objects passed to it
function Update-Event {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [Array]
        $Events
    )

    Process {
        foreach ($event in $Events) {
            $eventMessage = $event.Message

            # Regular expressions to extract field values
            $accountNamePattern = "Account Name:\s+(.+)"
            $accountDomainPattern = "Account Domain:\s+(.+)"
            $logonIDPattern = "Logon ID:\s+(0x[A-Fa-f0-9]+)"
            $logonTypePattern = "Logon Type:\s+(.+)"
            $processIDPattern = "Process ID:\s+0x([A-Fa-f0-9]+)\b"
            $processNamePattern = "Process Name:\s+(.+)"
            $workstationNamePattern = "Workstation Name:\s+(.+)"
            $sourceNetworkAddressPattern = "Source Network Address:\s+(.+)"
            $sourcePortPattern = "Source Port:\s+(.+)"
            $logonProcessPattern = "Logon Process:\s+(.+)"
            $parentProcessPattern = "Creator Process Name:\s+(.+)"
            $parentProcessIDPattern = "Creator Process ID:\s+0x([A-Fa-f0-9]+)\b"

            # Extract field values using regular expressions
            $accountName = [regex]::Match($eventMessage, $accountNamePattern).Groups[1].Value
            $accountDomain = [regex]::Match($eventMessage, $accountDomainPattern).Groups[1].Value
            $logonIDHexMatch = [regex]::Match($eventMessage, $logonIDPattern)
            $logonIDHex = $logonIDHexMatch.Groups[1].Value
            $logonType = [regex]::Match($eventMessage, $logonTypePattern).Groups[1].Value
            $processIDHexMatch = [regex]::Match($eventMessage, $processIDPattern)
            $processIDHex = $processIDHexMatch.Groups[1].Value
            $processPath = [regex]::Match($eventMessage, $processNamePattern).Groups[1].Value
            $workstationName = [regex]::Match($eventMessage, $workstationNamePattern).Groups[1].Value
            $sourceNetworkAddress = [regex]::Match($eventMessage, $sourceNetworkAddressPattern).Groups[1].Value
            $sourcePort = [regex]::Match($eventMessage, $sourcePortPattern).Groups[1].Value
            $logonProcess = [regex]::Match($eventMessage, $logonProcessPattern).Groups[1].Value
            $parentProcessPath = [regex]::Match($eventMessage, $parentProcessPattern).Groups[1].Value
            $parentProcessIDHexMatch = [regex]::Match($eventMessage, $parentProcessIDPattern)
            $parentProcessIDHex = $parentProcessIDHexMatch.Groups[1].Value


            # Convert LogonID from hexadecimal to decimal
            $logonID = 0
            if ($logonIDHexMatch.Success) {
                $logonID = [bigint]::Parse($logonIDHex.Substring(2), 'HexNumber')
            } else {$logonID = [PSCustomObject]@{logonID = $null}}

            # Convert ProcessID from hexadecimal to decimal
            $processID = 0
            if ($processIDHexMatch.Success) {
                $processID = [convert]::ToInt32($processIDHex, 16)
            }

            # Convert ParentProcessID from hexadecimal to decimal
            $parentProcessID = 0
            if ($parentProcessIDHexMatch.Success) {
                $parentProcessID = [convert]::ToInt32($parentProcessIDHex, 16)
            }

            # EventID to Description Mapping
            $EventIdDescriptionMapping = @{
            4624 = "An account was successfully logged on."
            4634 = "An account was logged off."
            4688 = "A new process has been created."
            4698 = "A scheduled task was created."
            4702 = "A scheduled task was updated."
            4740 = "A user account was locked out."
            4625 = "An account failed to log on."
            5152 = "The Windows Filtering Platform blocked a packet."
            5154 = "The Windows Filtering Platform has permitted an application or service to listen on a port for incoming connections."
            5155 = "The Windows Filtering Platform has blocked an application or service from listening on a port for incoming connections."
            5156 = "The Windows Filtering Platform has allowed a connection."
            5157 = "The Windows Filtering Platform has blocked a connection."
            4648 = "A logon was attempted using explicit credentials."
            4672 = "Special privileges assigned to a new logon."
            4673 = "A privileged service was called."
            4769 = "A Kerberos service ticket was requested."
            4771 = "Kerberos pre-authentication failed."
            5140 = "A network share object was accessed."
            1102 = "The audit log was cleared."
            4104 = "PowerShell Remote Command Execution"
        }

            # Create custom object with the extracted field values
            $eventData = [PSCustomObject]@{
                CSName               = $event.MachineName
                Id                   = $event.Id
                TimeCreated          = $event.TimeCreated.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                UTCTimeCreated       = $event.TimeCreated.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                Description          = $EventIdDescriptionMapping[$event.Id]
                LogName              = $event.LogName
                MachineName          = $event.MachineName
                RecordId             = $event.RecordId
                Time                 = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                Message              = $event.Message
                AccountName          = $accountName
                AccountDomain        = $accountDomain
                LogonID              = $logonID
                LogonType            = $logonType
                ProcessID            = $processID
                ProcessName          = if($ProcessPath) {Split-Path $ProcessPath -Leaf} else {$null}
                ProcessPath          = $processPath
                ParentProcessID      = $parentProcessID
                ParentProcessName    = if($ParentProcessPath) {Split-Path $ParentProcessPath -Leaf} else {$null}
                ParentProcessPath    = $parentProcessPath
                WorkstationName      = $workstationName
                SourceNetworkAddress = $sourceNetworkAddress
                SourcePort           = $sourcePort
                LogonProcess         = $logonProcess
            }

            $eventData
        }
    }
}

# Function that exports event logs to an EVTX file and copies it back to your machine
# Function that exports event logs to EVTX files using LOOT multi-protocol forensic collection (SMB, WinRM, WMI, Auto)
function Get-EVTX
{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [ValidateSet('Auto','SMB','WinRM','WMI')]
        [string]$Method = 'Auto',

        [Parameter()]
        [ValidateSet('DFIR','All','Custom')]
        [string]$LogCategory = 'DFIR',

        [Parameter()]
        [string[]]$CustomLogs,

        [Parameter()]
        [string]$OutputFolder
    )

    Begin {
        if (!$Credential) {
            $Credential = $null
        }

        $dfirPreset = @(
            "Security",
            "System",
            "Application",
            "Windows PowerShell",
            "Microsoft-Windows-PowerShell/Operational",
            "Microsoft-Windows-Sysmon/Operational"
        )

        $logsToPull = @()
        if ($LogCategory -eq 'DFIR') {
            $logsToPull = $dfirPreset
        } elseif ($LogCategory -eq 'Custom' -and $CustomLogs) {
            $logsToPull = $CustomLogs | ForEach-Object { $_.Trim() }
        }
    }

    Process {
        $missionTimestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $remoteTemp = "C:\Windows\Temp\LOOT_Export"

        foreach ($computer in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($computer)) { continue }

            $compNameClean = $computer -replace '[^a-zA-Z0-9.-]', '_'
            $targetOutput = if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
                Join-Path (Get-Location) "Output/EVTX_Logs/${compNameClean}_${missionTimestamp}"
            } else {
                Join-Path $OutputFolder "${compNameClean}_${missionTimestamp}"
            }

            if (-not (Test-Path $targetOutput)) {
                New-Item -ItemType Directory -Path $targetOutput -Force | Out-Null
            }

            Write-Output "=================== EVTX Log Collection Target: $computer ==================="
            Write-Output "Target Folder: $targetOutput"
            Write-Output "Log Preset   : $LogCategory"
            Write-Output "Method       : $Method"

            # Determine protocol execution order
            $methodsToTry = if ($Method -eq 'Auto') { @('SMB', 'WinRM', 'WMI') } else { @($Method) }
            $collected = $false

            foreach ($currentMethod in $methodsToTry) {
                if ($collected) { break }

                try {
                    # --- SMB METHOD ---
                    if ($currentMethod -eq 'SMB') {
                        Write-Output "  [SMB] Attempting administrative C`$ share connection..."
                        $drv = $null
                        foreach ($l in (90..68 | ForEach-Object { [char]$_ })) {
                            if (-not (Get-PSDrive -Name $l -ErrorAction SilentlyContinue)) {
                                $drv = $l
                                break
                            }
                        }
                        if ($null -eq $drv) { throw "No available drive letters to mount SMB share." }

                        $mountArgs = @{ Name = $drv; PSProvider = 'FileSystem'; Root = "\\${computer}\C$" }
                        if ($Credential) { $mountArgs['Credential'] = $Credential }
                        New-PSDrive @mountArgs -ErrorAction Stop | Out-Null
                        Write-Output "  [SMB] Connected to \\${computer}\C`$ on drive ${drv}:\"

                        if ($LogCategory -eq 'All') {
                            Write-Output "  [SMB] Copying all .evtx files directly from disk..."
                            $filesToCopy = Get-ChildItem -Path "${drv}:\Windows\System32\winevt\Logs\*.evtx" -File -ErrorAction SilentlyContinue
                            foreach ($file in $filesToCopy) {
                                Copy-Item -Path $file.FullName -Destination $targetOutput -Force
                            }
                        } else {
                            foreach ($log in $logsToPull) {
                                $evtxName   = ($log -replace "/", "%4") + ".evtx"
                                $sourcePath = "${drv}:\Windows\System32\winevt\Logs\${evtxName}"
                                if (Test-Path $sourcePath) {
                                    Copy-Item -Path $sourcePath -Destination $targetOutput -Force
                                    Write-Output "  [SMB] Acquired: $evtxName"
                                }
                            }
                        }

                        Remove-PSDrive -Name $drv -Force | Out-Null
                        Write-Output "  [SMB] Collection complete. Share unmounted."
                        $collected = $true
                    }

                    # --- WINRM METHOD ---
                    elseif ($currentMethod -eq 'WinRM') {
                        Write-Output "  [WinRM] Establishing PSSession..."
                        $sessionParams = @{ ComputerName = $computer }
                        if ($Credential) { $sessionParams['Credential'] = $Credential }
                        $session = New-PSSession @sessionParams -ErrorAction Stop

                        Write-Output "  [WinRM] Batch exporting locked logs via wevtutil..."
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

                        Write-Output "  [WinRM] Downloading exported EVTX files..."
                        $remoteFiles = Invoke-Command -Session $session -ScriptBlock {
                            Get-ChildItem -Path $args[0] -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
                        } -ArgumentList $remoteTemp

                        if ($remoteFiles) {
                            foreach ($rFileName in $remoteFiles) {
                                Copy-Item -FromSession $session -Path "$remoteTemp\$rFileName" -Destination $targetOutput -Force
                                Write-Output "  [WinRM] Acquired: $rFileName"
                            }
                        }

                        # Cleanup remote temp
                        Invoke-Command -Session $session -ScriptBlock { Remove-Item -Path $args[0] -Recurse -Force -ErrorAction SilentlyContinue } -ArgumentList $remoteTemp | Out-Null
                        Remove-PSSession -Session $session
                        Write-Output "  [WinRM] Collection complete. Session closed and remote temp cleaned."
                        $collected = $true
                    }

                    # --- WMI METHOD (DCOM/RPC) ---
                    elseif ($currentMethod -eq 'WMI') {
                        Write-Output "  [WMI] Mounting SMB drive for file transfer..."
                        $drv = $null
                        foreach ($l in (90..68 | ForEach-Object { [char]$_ })) {
                            if (-not (Get-PSDrive -Name $l -ErrorAction SilentlyContinue)) {
                                $drv = $l
                                break
                            }
                        }
                        if ($null -eq $drv) { throw "No available drive letters to mount SMB share." }

                        $mountArgs = @{ Name = $drv; PSProvider = 'FileSystem'; Root = "\\${computer}\C$" }
                        if ($Credential) { $mountArgs['Credential'] = $Credential }
                        New-PSDrive @mountArgs -ErrorAction Stop | Out-Null

                        Write-Output "  [WMI] Establishing remote DCOM CIM session..."
                        $cimOption = New-CimSessionOption -Protocol DCOM
                        $cimParams = @{ ComputerName = $computer; SessionOption = $cimOption }
                        if ($Credential) { $cimParams['Credential'] = $Credential }
                        $cimSession = New-CimSession @cimParams -ErrorAction Stop

                        $createDirCmd = "cmd.exe /c mkdir $remoteTemp"
                        $null = Invoke-CimMethod -CimSession $cimSession -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $createDirCmd }

                        if ($LogCategory -eq 'All') {
                            $psCmd = "powershell -NoProfile -Command `"[System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.GetLogNames() | ForEach-Object { wevtutil epl `"`$_`" `"$remoteTemp\(\`$_ -replace '[/\\ ]', '_').evtx`" /overwrite:true 2>`$null }`""
                            $null = Invoke-CimMethod -CimSession $cimSession -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $psCmd }
                            Start-Sleep -Seconds 3
                        } else {
                            foreach ($log in $logsToPull) {
                                $exportName = ($log -replace "[/\\ ]", "_") + ".evtx"
                                $exportCmd = "wevtutil epl `"$log`" `"$remoteTemp\$exportName`" /overwrite:true"
                                $null = Invoke-CimMethod -CimSession $cimSession -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $exportCmd }
                            }
                        }

                        $checkPath = "${drv}:\Windows\Temp\LOOT_Export"
                        Start-Sleep -Seconds 2
                        if (Test-Path $checkPath) {
                            $filesToCopy = Get-ChildItem -Path "$checkPath\*.evtx" -File -ErrorAction SilentlyContinue
                            foreach ($file in $filesToCopy) {
                                Copy-Item -Path $file.FullName -Destination $targetOutput -Force
                                Write-Output "  [WMI] Acquired: $($file.Name)"
                            }
                            $cleanCmd = "cmd.exe /c rmdir /s /q $remoteTemp"
                            $null = Invoke-CimMethod -CimSession $cimSession -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cleanCmd }
                        }

                        Remove-CimSession -Session $cimSession
                        Remove-PSDrive -Name $drv -Force | Out-Null
                        Write-Output "  [WMI] Collection complete. WMI session closed."
                        $collected = $true
                    }
                }
                catch {
                    Write-Output "  [!] Method $currentMethod failed for $computer : $($_.Exception.Message)"
                    if ($Method -ne 'Auto') {
                        Write-Error "EVTX collection failed using method $currentMethod : $($_.Exception.Message)"
                    }
                }
            }

            if (-not $collected) {
                Write-Error "Failed to collect EVTX logs from $computer using any available protocol."
            }
        }
    }
}

# Test if WinRM and Invoke Command will work on an array of computers
function Test-ComputerConnection {
    param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
        $ComputerNames,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {
        foreach ($computer in $ComputerNames) {
            $winrmEnabled = $false
            $ready = $false
            try {
                $winrmStatus = Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock { Test-WSMan } -ErrorAction Stop
                if ($winrmStatus) {
                    $winrmEnabled = $true
                }
            } catch {
                $winrmEnabled = $false
            }

            if ($winrmEnabled) {
                Write-Host "WinRM is enabled and can connect to $computer"
                $ready = $true
            } else {
                Write-Host "WinRM is not enabled or cannot connect to $computer"
                $ready = $false
            }
        }

        return $ready
    }
}


function Publish-Data {
    param (
        [Parameter(Mandatory=$true)]
        [string]$elasticURL,

        [Parameter(Mandatory=$true)]
        [pscredential]$Credential,
        
        [Parameter(Mandatory=$true)]
        [string]$indexName,
        
        [Parameter(Mandatory=$true)]
        [array]$dataArray
    )

    # Create the Elasticsearch document endpoint URL
    $documentUrl = "$elasticURL/$indexName/_doc"

    # Iterate over the data array
    foreach ($dataItem in $dataArray) {
        $data = @{
            'hap' = $dataItem
        }

        # Convert the data to JSON
        $jsonData = $data | ConvertTo-Json

        # Ignore SSL certificate validation
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

        # Send the JSON data as the request body to create the document
        Invoke-RestMethod -Method 'POST' -Uri $documentUrl -Body $jsonData -ContentType 'application/json' -Credential $Credential
       
    }
}

# Function to create index patterns in Elastic
function New-IndexPattern {
    param (
        [Parameter(Mandatory=$true)]
        [string]$elasticURL,

        [Parameter(Mandatory=$true)]
        [pscredential]$Credential,
        
        [Parameter(Mandatory=$true)]
        [string]$indexPattern
       
    )

     # Set the index pattern definition
        $index_payload = @{
            "title" = $indexPattern
            "timeFieldName" = "hap.Time"
        }

        # Convert the index pattern definition to JSON
        $indexPayloadJson = $index_payload | ConvertTo-Json

        $data = @{
            'type' = 'index-pattern'
            'index-pattern' = @{
                'title' = $indexPattern
                'timeFieldName' = 'hap.Time'
            }
        }

        # Convert the data to JSON
        $jsonData = $data | ConvertTo-Json

        # Set the Kibana API endpoint for creating index patterns
        $IndexPatternEndpoint = "$elasticURL/.kibana/_doc/index-pattern:$indexPattern"

        # Invoke the API to create the index pattern
        $response = Invoke-RestMethod -Method 'POST' -Uri $IndexPatternEndpoint -Body $jsonData -ContentType 'application/json' -Credential $Credential

        return $response

}

function Split-StringWithComma {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [String]$InputString
    )

    process {
        if ($InputString -match ',') {
            $InputString -split ','
        } else {
            $InputString
        }
    }
}

function Remove-Spaces {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [String]$InputString
    )

    process {
        $InputString -replace '\s', ''
    }
}

#-------------------------------------------------------------------------------
# ACTIVE DIRECTORY & DOMAIN
#-------------------------------------------------------------------------------
function Get-DomainController {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
        $ComputerName,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {
           $domainControllers = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
                $domainControllers = ([adsisearcher]'(&(objectCategory=computer)(primaryGroupID=516))').FindAll() | ForEach-Object { 
                    $properties = $_.Properties
                    [PSCustomObject]@{
                        Name                  = $properties["name"] -as [string]
                        DNShostname           = $properties["dnshostname"] -as [string]
                        OperatingSystem       = $properties["operatingsystem"] -as [string]
                        OperatingSystemVersion = $properties["operatingsystemversion"] -as [string]
                        LastLogonTimestamp    = [datetime]::FromFileTime($properties["lastlogontimestamp"][0]).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        DistinguishedName     = $properties["distinguishedname"] -as [string]
                        Time                   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime                = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }

                $domainControllers
           }
           $domainControllers
    }
}

function Get-ProtectedUsers {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
        $ComputerName,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {
           $protected_users = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {

                    $searcher = [adsisearcher]'(&(objectClass=user)(adminCount=1))'

                    # Specify the properties you want to retrieve
                    $searcher.PropertiesToLoad.AddRange(@('sAMAccountName', 'distinguishedName', 'logonCount', 'description', 'badPasswordTime', 'pwdLastSet', 'lastlogontimestamp', 'whenCreated', 'whenChanged', 'adminCount'))

                    # Execute the search
                    $results = $searcher.FindAll()

                    $protected_users = @()

                            # Loop through the results
                            foreach ($result in $results) {
                                $properties = $result.Properties
                                $protected_users += [PSCustomObject]@{
                                    Username           = $properties['samaccountname'] -as [string]
                                    DistinguishedName  = $properties['distinguishedname'] -as [string]
                                    LogonCount         = $properties['logoncount'] -as [string]
                                    Description        = $properties['description'] -as [string]
                                    BadPasswordTime    = [datetime]::FromFileTime($properties['badpasswordtime'][0] -as [long]).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                    PwdLastSet         = [datetime]::FromFileTime($properties['pwdlastset'][0] -as [long]).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                    LastLogonTimestamp = [datetime]::FromFileTime($properties['lastlogontimestamp'][0] -as [long]).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                    WhenCreated        = $properties['whencreated'][0] -as [string]
                                    WhenChanged        = $properties['whenchanged'][0] -as [string]
                                    AdminCount         = $properties['admincount'][0] -as [string]
                                    Time               = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                    UTCTime            = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                }
                            }
                    $protected_users
                }
            $protected_users
    }
}


function Get-DomainUser {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
        $ComputerName,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {
        $users = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
                $searcher = [adsisearcher]"(&(objectCategory=user)(objectClass=user))"

                # Specify the properties to retrieve
                $searcher.PropertiesToLoad.AddRange(@('samaccountname', 'name', 'instancetype', 'userprincipalname', 'logoncount',
                'description', 'pwdlastset', 'badpwdcount', 'lastlogontimestamp', 'memberof', 'whencreated', 'adspath', 'cn', 'primarygroupid',
                'distinguishedname', 'admincount'))

                # Execute the search
                $results = $searcher.FindAll()

                # Define the number of days of inactivity
                $daysInactive = 30

                # Calculate the lastLogonTimestamp of the $daysInactive
                $inactiveTime = (Get-Date).AddDays(-$daysInactive).ToFileTime()

                $users = foreach ($result in $results) {
                    $properties = $result.Properties
                    
                    $lastLogonTimestamp = if ($properties['lastlogontimestamp']) {
                        [datetime]::FromFileTime([long]$properties['lastlogontimestamp'][0]).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }

                    $pwdLastSet = if ($properties['pwdlastset']) {
                        [datetime]::FromFileTime([long]$properties['pwdlastset'][0])
                    }

                    [PSCustomObject]@{
                        Username            = $properties['samaccountname'] -as [string]
                        Name                = $properties['name'] -as [string]
                        InstanceType        = $properties['instancetype'] -as [string]
                        UserPrincipalName   = $properties['userprincipalname'] -as [string]
                        LogonCount          = $properties['logoncount'] -as [string]
                        Description         = $properties['description'] -as [string]
                        PwdLastSet          = $pwdLastSet
                        BadPwdCount         = $properties['badpwdcount'] -as [string]
                        LastLogonTimestamp  = $lastLogonTimestamp
                        MemberOf            = $properties['memberof'] -join '; '  # Convert string array to semicolon-separated string
                        WhenCreated         = $properties['whencreated'] -as [string]
                        ADsPath             = $properties['adspath'] -as [string]
                        CN                  = $properties['cn'] -as [string]
                        PrimaryGroupId      = $properties['primarygroupid'] -as [string]
                        DistinguishedName   = $properties['distinguishedname'] -as [string]
                        AdminCount          = $properties['admincount'] -as [string]
                        Inactive            = if ($lastLogonTimestamp) { $lastLogonTimestamp -lt [datetime]::FromFileTime($inactiveTime) } else { $null }
                        Time                = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime             = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
                $users
        }
        $users
    }
    
}

function Get-DomainGroup {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
        $ComputerName,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {
        $groups = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
                # Define the LDAP query string to find all groups
                $searcher = [adsisearcher]"(objectCategory=group)"

                # Specify the properties you want to retrieve
                $searcher.PropertiesToLoad.AddRange(@('name', 'grouptype', 'memberof', 'member', 'samaccountname', 'distinguishedname'))

                # Execute the search
                $results = $searcher.FindAll()

                # Loop through the results
                foreach ($result in $results) {
                    $properties = $result.Properties
                    
                    [PSCustomObject]@{
                        GroupName         = $properties['name'] -as [string]
                        GroupType         = $properties['grouptype'] -as [int]
                        MemberOf          = $properties['memberof'] -as [string[]]
                        Members           = $properties['member'] -as [string[]]
                        SamAccountName    = $properties['samaccountname'] -as [string]
                        DistinguishedName = $properties['distinguishedname'] -as [string]
                        Time              = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime           = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            }
        $groups
    }
}



#----------------------------GROUP MEMBERSHIP-----------------------------------

function Get-DomainGroupMembership {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
        $ComputerName,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {
        $group_members = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
                # Define the LDAP query string to find all groups
                $searcher = [adsisearcher]"(objectCategory=group)"

                # Specify the properties you want to retrieve
                $searcher.PropertiesToLoad.AddRange(@('name', 'member', 'distinguishedname'))

                # Execute the search
                $results = $searcher.FindAll()

                # Loop through the results
                $groups = @()
                foreach ($result in $results) {
                    $properties = $result.Properties
                    
                    $groupName = $properties['name'] -as [string]
                    
                    # Skip if GroupName is '0' or empty
                    if ($groupName -eq '0' -or -not $groupName) { continue }
                    
                    $members = @()
                    # If the group has members, resolve their distinguished names to more friendly Common Names (CN)
                    if ($properties['member']) {
                        foreach ($memberDN in $properties['member']) {
                            $memberSearcher = [adsisearcher]"(distinguishedName=$memberDN)"
                            $memberSearcher.PropertiesToLoad.Add('cn')
                            $member = $memberSearcher.FindOne()
                            if ($member) {
                                $members += $member.Properties['cn'] -as [string]
                            }
                        }
                    }
                    
                    $groups += [PSCustomObject]@{
                        GroupName         = $groupName
                        Members           = $members -join ', '
                        DistinguishedName = $properties['distinguishedname'] -as [string]
                        Time              = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime           = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
                $groups
        }
        $group_members = $group_members | Where-Object { $_.GroupName -ne $null }
        $group_members

    }
}

#----------------------------SERVICE ACCOUNTS-----------------------------------

function Get-ServiceAccount {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
        $ComputerName,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {

        $service_accounts = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
                # Define the LDAP query string to find all users with a servicePrincipalName set
                $searcher = [adsisearcher]"(&(objectCategory=user)(servicePrincipalName=*))"

                # Specify the properties you want to retrieve
                $searcher.PropertiesToLoad.AddRange(@('samaccountname', 'serviceprincipalname', 'distinguishedname', 'logoncount', 'description', 
                'badpasswordtime', 'pwdlastset', 'whencreated', 'admincount'))

                # Execute the search
                $results = $searcher.FindAll()

                # Loop through the results
                $service_accounts = @()
                foreach ($result in $results) {
                    $properties = $result.Properties

                    $service_accounts += [PSCustomObject]@{
                        Username               = $properties['samaccountname'] -as [string]
                        ServicePrincipalNames  = ($properties['serviceprincipalname'] -as [string[]]) -join ', '
                        DistinguishedName      = $properties['distinguishedname'] -as [string]
                        LogonCount             = $properties['logoncount'] -as [int]
                        Description            = $properties['description'] -as [string]
                        BadPasswordTime        = [datetime]::FromFileTime($properties['badpasswordtime'][0] -as [long]).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        PwdLastSet             = [datetime]::FromFileTime($properties['pwdlastset'][0] -as [long]).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        WhenCreated            = $properties['whencreated'] -as [datetime]
                        AdminCount             = $properties['admincount'] -as [string]
                        Time                   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime                = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }

                $service_accounts
        }

        $service_accounts
    }

}


#----------------------------GROUP POLICY-------------------------------------

function Get-GPOInfo {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
        $ComputerName,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {

        $gpos = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {

                $searcher = [adsisearcher]"(objectClass=groupPolicyContainer)"
                $searcher.PageSize = 1000 # Adjust as needed to handle large result sets
                $results = $searcher.FindAll()

                $gpos = @()

                foreach ($result in $results) {
                    $properties = $result.Properties
                    $gpos += [PSCustomObject]@{
                        Name              = $properties['displayname'][0]
                        Id                = $properties['name'][0] # The unique identifier for the GPO
                        DistinguishedName = $properties['distinguishedname'][0]
                        WhenCreated       = ($properties['whencreated'][0]).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        WhenChanged       = ($properties['whenchanged'][0]).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        Time              = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        UTCTime           = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }

                $gpos
            
            }

        $gpos
    }

}




#----------------------------AD EVENT LOGS------------------------------------

function Get-ADEventLog {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]
        $ComputerName,

        [PSCredential]
        $Credential
    )

    Begin {
        If (!$Credential) {
            $Credential = Get-Credential
        }
    }

    Process {
        $AD_events = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {

            $eventArray = @(
                [PSCustomObject]@{
                    EventId = 216
                    Description = 'A database location change was detected'
                },
                [PSCustomObject]@{
                    EventId = 325
                    Description = 'The database engine created a new database'
                },
                [PSCustomObject]@{
                    EventId = 326
                    Description = 'The database engine attached a database'
                },
                [PSCustomObject]@{
                    EventId = 327
                    Description = 'The database engine deteached a database'
                }
            )

            $eventIds = @(216, 325, 326, 327)
            $provider = 'ESENT'

            # Using [adsisearcher] to get Domain Controllers
            $searcher = [adsisearcher]'(&(objectClass=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
            $domainControllers = $searcher.FindAll() | ForEach-Object { $_.Properties['dnshostname'][0] }

            $results = @()
            foreach ($hostname in $domainControllers) {
                foreach ($id in $eventIds) {
                    try {
                        $events = Get-WinEvent -ComputerName $hostname -FilterHashtable @{
                            LogName       = 'Application'
                            ProviderName  = $provider
                            Id            = $id
                        } -ErrorAction Stop
                        
                        foreach ($event in $events) {
                            $eventDescription = ($eventArray | Where-Object {$_.EventId -eq $event.Id}).Description
                            $results += [PSCustomObject]@{
                                DCName               = $hostname
                                EventID              = $event.Id
                                Description          = $eventDescription
                                TimeCreated          = $event.TimeCreated.ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                ProviderName         = $event.ProviderName
                                Message              = $event.Message
                                Time                 = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                                UTCTime              = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                            }
                        }
                    }
                    catch {
                        #Write-Warning "Failed to query event $id from $hostname. Error: $_"
                    }
                }
            }
            return $results
        }
        $AD_events
    }
}

#-------------------------------------------------------------------------------
# BASELINING & ARTIFACT COLLECTION
#-------------------------------------------------------------------------------

# Private helper: run a baseline function, catch errors, and export to CSV
function Invoke-BaselineExport {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock,
        [string]$TargetFolder
    )
    Write-Output "Running '$Name'..."
    try {
        $data = & $ScriptBlock
        if ($data) {
            $csvPath = Join-Path $TargetFolder "${Name}.csv"
            $data | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
            Write-Output "-> Successfully exported to: $csvPath"
        } else {
            Write-Output "-> No data returned."
        }
    }
    catch {
        Write-Output "WARNING: Failed to run baseline '$Name': $($_.Exception.Message)"
    }
}

# Get Host/Network Configuration Baseline
function Get-HostBaseline {
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
            $OutputFolder = Join-Path (Get-Location) "Output/Baselines/HostBaselines_$timestamp"
        }
        $OutputFolder = [System.IO.Path]::GetFullPath($OutputFolder)
        if (-not (Test-Path $OutputFolder)) {
            New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
        }
        Write-Output "Baselines will be saved in: $OutputFolder"
    }

    Process {
        foreach ($computer in $ComputerName) {
            $compNameClean = $computer -replace '[^a-zA-Z0-9.-]', '_'
            Write-Output "=================== Baselining Target: $computer ==================="

            $targetFolder = Join-Path $OutputFolder $compNameClean
            if (-not (Test-Path $targetFolder)) {
                New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
            }

            Write-Output "Checking remote connection status using WSMan..."
            $isReady = Test-ComputerConnection -ComputerNames $computer -Credential $Credential
            if (-not $isReady) {
                Write-Output "WARNING: WSMan connection test failed for target '$computer'. Skipping baselining."
                continue
            }
            Write-Output "Connection verified successfully!"

            # Host Network State Queries
            Invoke-BaselineExport -Name "OSInfo" -TargetFolder $targetFolder -ScriptBlock { Get-OSInfo -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "Processes" -TargetFolder $targetFolder -ScriptBlock { Get-ProcessInfo -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "Services" -TargetFolder $targetFolder -ScriptBlock { Get-ServiceInfo -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "Connections" -TargetFolder $targetFolder -ScriptBlock { Get-Connection -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "Shares" -TargetFolder $targetFolder -ScriptBlock { Get-ShareInfo -ComputerName $computer -Credential $Credential }

            # Persistence & Security Auditing Queries
            Invoke-BaselineExport -Name "RegistryRun" -TargetFolder $targetFolder -ScriptBlock { Get-RegistryRun -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "StartupFolders" -TargetFolder $targetFolder -ScriptBlock { Get-StartupFolders -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "ScheduledTasks" -TargetFolder $targetFolder -ScriptBlock { Get-SchTask -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "LogonHistory" -TargetFolder $targetFolder -ScriptBlock { Get-LogOnHistory -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "LocalGroupMembers" -TargetFolder $targetFolder -ScriptBlock { Get-LGroupMembers -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "RegistryUserShellFolders" -TargetFolder $targetFolder -ScriptBlock { Get-RegistryUserShellFolders -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "Prefetches" -TargetFolder $targetFolder -ScriptBlock { Get-Prefetch -ComputerName $computer -Credential $Credential }
        }
    }

    End {
        Write-Output "Baselining run completed. All generated files are in: $OutputFolder"
    }
}

# Get Domain/Server Configuration Baseline (Includes Host configuration and AD/Domain queries)
function Get-DomainBaseline {
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
            $OutputFolder = Join-Path (Get-Location) "Output/Baselines/DomainBaselines_$timestamp"
        }
        $OutputFolder = [System.IO.Path]::GetFullPath($OutputFolder)
        if (-not (Test-Path $OutputFolder)) {
            New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
        }
        Write-Output "Domain baselines will be saved in: $OutputFolder"
    }

    Process {
        # Run host baseline first (creates per-computer subfolders and host-level CSVs)
        Get-HostBaseline -ComputerName $ComputerName -Credential $Credential -OutputFolder $OutputFolder

        # Then add AD-specific queries for each computer
        foreach ($computer in $ComputerName) {
            $compNameClean = $computer -replace '[^a-zA-Z0-9.-]', '_'
            $targetFolder = Join-Path $OutputFolder $compNameClean

            if (-not (Test-Path $targetFolder)) {
                Write-Output "Skipping AD queries for '$computer' (host baseline was skipped)."
                continue
            }

            Write-Output "=================== Running AD Queries for: $computer ==================="
            Invoke-BaselineExport -Name "ADDomainController" -TargetFolder $targetFolder -ScriptBlock { Get-DomainController -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "ADDomainUser" -TargetFolder $targetFolder -ScriptBlock { Get-DomainUser -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "ADDomainGroup" -TargetFolder $targetFolder -ScriptBlock { Get-DomainGroup -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "ADDomainGroupMembership" -TargetFolder $targetFolder -ScriptBlock { Get-DomainGroupMembership -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "ADGPOInfo" -TargetFolder $targetFolder -ScriptBlock { Get-GPOInfo -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "ADProtectedUsers" -TargetFolder $targetFolder -ScriptBlock { Get-ProtectedUsers -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "ADServiceAccount" -TargetFolder $targetFolder -ScriptBlock { Get-ServiceAccount -ComputerName $computer -Credential $Credential }
            Invoke-BaselineExport -Name "ADEventLog" -TargetFolder $targetFolder -ScriptBlock { Get-ADEventLog -ComputerName $computer -Credential $Credential }
        }
    }

    End {
        Write-Output "Domain baselining run completed. All generated files are in: $OutputFolder"
    }
}



# Retrieve (pull) a suspected file or directory from a remote host with zipping and remote cleanup options
function Get-RemoteArtifact {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('Auto', 'File', 'Executable', 'Directory')]
        [string]$Type = 'Auto',

        [Parameter()]
        [string]$ZipPassword = 'infected',

        [Parameter()]
        [switch]$CleanRemote,

        [Parameter()]
        [string]$Destination
    )

    Begin {
        if (!$Credential) {
            $Credential = $null
        }

        # Default destination to ./Output/Artifacts relative to current path
        if ([string]::IsNullOrWhiteSpace($Destination)) {
            $Destination = Join-Path (Get-Location) "Output/Artifacts"
        }

        $Destination = [System.IO.Path]::GetFullPath($Destination)
        if (-not (Test-Path $Destination)) {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        }
    }

    Process {
        $exeExtensions = @('.exe', '.dll', '.sys', '.scr', '.bat', '.vbs', '.ps1', '.cmd', '.msi', '.jar')
        $remoteTempFolder = "C:\Windows\Temp\Artifact_Export"

        foreach ($computer in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($computer)) { continue }

            Write-Output "=================== Remote Artifact Target: $computer ==================="
            Write-Output "Remote Path : $Path"
            Write-Output "Mode / Type : $Type"
            Write-Output "Destination : $Destination"
            Write-Output "Clean Remote: $CleanRemote"

            $session = $null
            try {
                $sessionParams = @{ ComputerName = $computer }
                if ($Credential) { $sessionParams['Credential'] = $Credential }
                $session = New-PSSession @sessionParams -ErrorAction Stop

                # Resolve mode if Auto
                $resolvedMode = $Type
                if ($Type -eq 'Auto') {
                    $remoteCheck = Invoke-Command -Session $session -ScriptBlock {
                        param($targetPath, $exts)
                        if (-not (Test-Path $targetPath)) { return "NotFound" }
                        if (Test-Path $targetPath -PathType Container) { return "Directory" }
                        $ext = [System.IO.Path]::GetExtension($targetPath).ToLower()
                        if ($exts -contains $ext) { return "Executable" }
                        return "File"
                    } -ArgumentList $Path, $exeExtensions

                    if ($remoteCheck -eq "NotFound") {
                        throw "Target path '$Path' was not found on remote computer '$computer'."
                    }
                    $resolvedMode = $remoteCheck
                    Write-Output "-> Auto-detected artifact type: $resolvedMode"
                }

                $acquiredSuccess = $false
                $downloadedFile = $null

                # --- MODE: FILE (Raw copy) ---
                if ($resolvedMode -eq 'File') {
                    Write-Output "-> Copying raw file from $computer..."
                    Copy-Item -Path $Path -FromSession $session -Destination $Destination -Force -ErrorAction Stop
                    $fileName = Split-Path $Path -Leaf
                    $downloadedFile = Join-Path $Destination $fileName
                    $acquiredSuccess = $true
                    Write-Output "-> Successfully retrieved file: $downloadedFile"
                }

                # --- MODE: EXECUTABLE (Password-Protected ZIP) ---
                elseif ($resolvedMode -eq 'Executable') {
                    Write-Output "-> Creating password-protected ZIP on target machine..."
                    $zipResult = Invoke-Command -Session $session -ScriptBlock {
                        param($targetPath, $tempFolder, $password)
                        if (-not (Test-Path $targetPath)) { throw "Target file not found." }
                        New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
                        
                        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($targetPath)
                        $zipName = "Artifact_${baseName}_protected.zip"
                        $zipPath = Join-Path $tempFolder $zipName

                        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

                        # Create password protected zip via PowerShell / System.IO.Compression
                        Add-Type -AssemblyName System.IO.Compression.FileSystem
                        $tempDir = Join-Path $tempFolder "Stage_$baseName"
                        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
                        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                        Copy-Item -Path $targetPath -Destination $tempDir -Force

                        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)
                        Remove-Item $tempDir -Recurse -Force | Out-Null
                        return $zipName
                    } -ArgumentList $Path, $remoteTempFolder, $ZipPassword

                    $remoteZipPath = "$remoteTempFolder\$zipResult"
                    Write-Output "-> Downloading encrypted artifact package ($zipResult)..."
                    Copy-Item -Path $remoteZipPath -FromSession $session -Destination $Destination -Force -ErrorAction Stop
                    
                    # Clean up remote temp zip
                    Invoke-Command -Session $session -ScriptBlock { Remove-Item -Path $args[0] -Recurse -Force -ErrorAction SilentlyContinue } -ArgumentList $remoteTempFolder | Out-Null
                    
                    $downloadedFile = Join-Path $Destination $zipResult
                    $acquiredSuccess = $true
                    Write-Output "-> Successfully acquired protected executable archive: $downloadedFile (Password: $ZipPassword)"
                }

                # --- MODE: DIRECTORY (Recursive ZIP) ---
                elseif ($resolvedMode -eq 'Directory') {
                    Write-Output "-> Zipping directory recursively on target machine..."
                    $dirResult = Invoke-Command -Session $session -ScriptBlock {
                        param($targetPath, $tempFolder)
                        if (-not (Test-Path $targetPath -PathType Container)) { throw "Target directory not found." }
                        New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
                        
                        $folderName = (Get-Item $targetPath).Name
                        $zipName = "Artifact_${folderName}_folder.zip"
                        $zipPath = Join-Path $tempFolder $zipName

                        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

                        Add-Type -AssemblyName System.IO.Compression.FileSystem
                        [System.IO.Compression.ZipFile]::CreateFromDirectory($targetPath, $zipPath)
                        return $zipName
                    } -ArgumentList $Path, $remoteTempFolder

                    $remoteZipPath = "$remoteTempFolder\$dirResult"
                    Write-Output "-> Downloading directory ZIP package ($dirResult)..."
                    Copy-Item -Path $remoteZipPath -FromSession $session -Destination $Destination -Force -ErrorAction Stop
                    
                    # Clean up remote temp zip
                    Invoke-Command -Session $session -ScriptBlock { Remove-Item -Path $args[0] -Recurse -Force -ErrorAction SilentlyContinue } -ArgumentList $remoteTempFolder | Out-Null
                    
                    $downloadedFile = Join-Path $Destination $dirResult
                    $acquiredSuccess = $true
                    Write-Output "-> Successfully acquired directory archive: $downloadedFile"
                }

                # --- POST-ACQUISITION REMOTE CLEANUP (-CleanRemote) ---
                if ($acquiredSuccess -and $CleanRemote) {
                    Write-Output "-> REMEDIATION ACTION: Removing target artifact from remote host ($computer)..."
                    $cleanResult = Invoke-Command -Session $session -ScriptBlock {
                        param($targetPath)
                        try {
                            if (Test-Path $targetPath) {
                                Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                                return "Success"
                            }
                            return "NotFound"
                        } catch {
                            return "Error: $($_.Exception.Message)"
                        }
                    } -ArgumentList $Path

                    if ($cleanResult -eq "Success") {
                        Write-Output "-> REMEDIATION SUCCESS: Successfully deleted '$Path' from $computer."
                    } elseif ($cleanResult -like "Error:*") {
                        Write-Output "WARNING: Artifact acquired successfully, but remote removal failed: $cleanResult"
                    }
                }
            }
            catch {
                Write-Output "ERROR: Failed to retrieve artifact from $computer. Error: $($_.Exception.Message)"
            }
            finally {
                if ($session) {
                    Remove-PSSession $session -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

# Reset password for compromised Active Directory user accounts
function Reset-ADUserPassword {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $true)]
        [string[]]$Identity,

        [Parameter()]
        [string]$NewPassword,

        [Parameter()]
        [switch]$MustChangePassword = $true,

        [Parameter()]
        [switch]$UnlockAccount = $true
    )

    Begin {
        if (!$Credential) { $Credential = $null }

        # Auto-generate password if empty
        function New-ComplexPassword {
            $u = "ABCDEFGHJKLMNPQRSTUVWXYZ"
            $l = "abcdefghijkmnopqrstuvwxyz"
            $n = "23456789"
            $s = "!@#$%^&*()-_=+"
            $all = $u + $l + $n + $s
            $rnd = New-Object System.Random
            $pwd = @(
                $u[$rnd.Next($u.Length)],
                $l[$rnd.Next($l.Length)],
                $n[$rnd.Next($n.Length)],
                $s[$rnd.Next($s.Length)]
            )
            for ($i = 0; $i -lt 16; $i++) {
                $pwd += $all[$rnd.Next($all.Length)]
            }
            return ($pwd | Sort-Object { $rnd.Next() }) -join ''
        }

        if ([string]::IsNullOrWhiteSpace($NewPassword)) {
            $NewPassword = New-ComplexPassword
            Write-Output "-> Auto-generated complex password: $NewPassword"
        }
    }

    Process {
        foreach ($computer in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($computer)) { continue }

            Write-Output "=================== Reset AD Password Target: $computer ==================="
            
            Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                param($users, $pwd, $mustChange, $unlock)

                foreach ($user in $users) {
                    if ([string]::IsNullOrWhiteSpace($user)) { continue }
                    $cleanUser = $user.Trim()
                    try {
                        # Primary: Check if ActiveDirectory module is available
                        if (Get-Module -ListAvailable -Name ActiveDirectory) {
                            Import-Module ActiveDirectory -ErrorAction SilentlyContinue
                            $secPwd = ConvertTo-SecureString $pwd -AsPlainText -Force
                            Set-ADAccountPassword -Identity $cleanUser -NewPassword $secPwd -Reset -ErrorAction Stop
                            if ($mustChange) { Set-ADUser -Identity $cleanUser -ChangePasswordAtLogon $true -ErrorAction SilentlyContinue }
                            if ($unlock) { Unlock-ADAccount -Identity $cleanUser -ErrorAction SilentlyContinue }
                        } else {
                            # Fallback: Native ADSI LDAP searcher
                            $searcher = [adsisearcher]"(sAMAccountName=$cleanUser)"
                            $result = $searcher.FindOne()
                            if (-not $result) { throw "User '$cleanUser' not found in Active Directory." }
                            $de = $result.GetDirectoryEntry()
                            $de.SetPassword($pwd)
                            if ($mustChange) { $de.pwdLastSet = 0 }
                            if ($unlock) { $de.IsAccountLocked = $false }
                            $de.SetInfo()
                        }

                        [PSCustomObject]@{
                            Username           = $cleanUser
                            Status             = "Success"
                            NewPassword        = $pwd
                            MustChangeAtLogon = $mustChange
                            AccountUnlocked    = $unlock
                            Timestamp          = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    } catch {
                        [PSCustomObject]@{
                            Username           = $cleanUser
                            Status             = "Failed: $($_.Exception.Message)"
                            NewPassword        = $null
                            MustChangeAtLogon = $false
                            AccountUnlocked    = $false
                            Timestamp          = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    }
                }
            } -ArgumentList $Identity, $NewPassword, [bool]$MustChangePassword, [bool]$UnlockAccount
        }
    }
}

# Terminate running process on target host
function Stop-RemoteProcess {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [string]$ProcessName,

        [Parameter()]
        [int]$ProcessId,

        [Parameter()]
        [switch]$Force = $true
    )

    Process {
        foreach ($computer in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($computer)) { continue }

            Write-Output "=================== Stop Process Target: $computer ==================="
            
            Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                param($name, $pidVal, $forceKill)

                $targets = @()
                if ($pidVal -gt 0) {
                    $targets = Get-Process -Id $pidVal -ErrorAction SilentlyContinue
                } elseif (-not [string]::IsNullOrWhiteSpace($name)) {
                    $cleanName = ($name -replace '\.exe$', '').Trim()
                    $targets = Get-Process -Name $cleanName -ErrorAction SilentlyContinue
                }

                if (-not $targets) {
                    Write-Output "No matching processes found on target."
                    return
                }

                foreach ($proc in $targets) {
                    try {
                        Stop-Process -Id $proc.Id -Force:$forceKill -ErrorAction Stop
                        [PSCustomObject]@{
                            ProcessName = $proc.ProcessName
                            PID         = $proc.Id
                            Status      = "Terminated"
                            Timestamp   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    } catch {
                        # WMI / CIM fallback
                        try {
                            $useCim = [bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
                            if ($useCim) {
                                Invoke-CimMethod -Query "SELECT * FROM Win32_Process WHERE ProcessId = $($proc.Id)" -MethodName Terminate | Out-Null
                            } else {
                                (Get-WmiObject -Class Win32_Process -Filter "ProcessId = $($proc.Id)").Terminate() | Out-Null
                            }
                            [PSCustomObject]@{
                                ProcessName = $proc.ProcessName
                                PID         = $proc.Id
                                Status      = "Terminated (WMI/CIM Fallback)"
                                Timestamp   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                            }
                        } catch {
                            [PSCustomObject]@{
                                ProcessName = $proc.ProcessName
                                PID         = $proc.Id
                                Status      = "Failed: $($_.Exception.Message)"
                                Timestamp   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                            }
                        }
                    }
                }
            } -ArgumentList $ProcessName, $ProcessId, [bool]$Force
        }
    }
}

# Remove file or directory from remote target
function Remove-RemoteItem {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [switch]$Recurse = $true
    )

    Process {
        foreach ($computer in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($computer)) { continue }

            Write-Output "=================== Remove Item Target: $computer ==================="
            
            Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                param($targetPath, $doRecurse)

                if (-not (Test-Path $targetPath)) {
                    [PSCustomObject]@{
                        Path      = $targetPath
                        Status    = "NotFound"
                        Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                    return
                }

                try {
                    Remove-Item -Path $targetPath -Recurse:$doRecurse -Force -ErrorAction Stop
                    [PSCustomObject]@{
                        Path      = $targetPath
                        Status    = "Deleted"
                        Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                } catch {
                    [PSCustomObject]@{
                        Path      = $targetPath
                        Status    = "Failed: $($_.Exception.Message)"
                        Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } -ArgumentList $Path, [bool]$Recurse
        }
    }
}

# Stop a Windows service on target computer
function Stop-RemoteService {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Process {
        foreach ($computer in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($computer)) { continue }

            Write-Output "=================== Stop Service Target: $computer ==================="
            
            Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                param($serviceName)

                $cleanName = $serviceName.Trim()
                try {
                    $svc = Get-Service -Name $cleanName -ErrorAction SilentlyContinue
                    if (-not $svc) {
                        $svc = Get-Service -DisplayName $cleanName -ErrorAction SilentlyContinue
                    }
                    if (-not $svc) {
                        [PSCustomObject]@{
                            ServiceName = $cleanName
                            Status      = "NotFound"
                            Timestamp   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                        return
                    }

                    Stop-Service -Name $svc.Name -Force -ErrorAction Stop
                    [PSCustomObject]@{
                        ServiceName = $svc.Name
                        DisplayName = $svc.DisplayName
                        Status      = "Stopped"
                        Timestamp   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                } catch {
                    # WMI / CIM fallback
                    try {
                        $useCim = [bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
                        if ($useCim) {
                            Invoke-CimMethod -Query "SELECT * FROM Win32_Service WHERE Name = '$cleanName'" -MethodName StopService | Out-Null
                        } else {
                            (Get-WmiObject -Class Win32_Service -Filter "Name = '$cleanName'").StopService() | Out-Null
                        }
                        [PSCustomObject]@{
                            ServiceName = $cleanName
                            Status      = "Stopped (WMI/CIM Fallback)"
                            Timestamp   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    } catch {
                        [PSCustomObject]@{
                            ServiceName = $cleanName
                            Status      = "Failed: $($_.Exception.Message)"
                            Timestamp   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    }
                }
            } -ArgumentList $Name
        }
    }
}

# Remove/delete a Windows service from target computer
function Remove-RemoteService {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Process {
        foreach ($computer in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($computer)) { continue }

            Write-Output "=================== Remove Service Target: $computer ==================="
            
            Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                param($serviceName)

                $cleanName = $serviceName.Trim()
                try {
                    # Stop service first if running
                    $svc = Get-Service -Name $cleanName -ErrorAction SilentlyContinue
                    if ($svc -and $svc.Status -eq 'Running') {
                        Stop-Service -Name $cleanName -Force -ErrorAction SilentlyContinue
                    }

                    # Remove service via sc.exe or CIM
                    $scRes = cmd.exe /c "sc.exe delete `"$cleanName`"" 2>&1
                    [PSCustomObject]@{
                        ServiceName = $cleanName
                        Status      = "Deleted ($($scRes -join ' '))"
                        Timestamp   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                } catch {
                    [PSCustomObject]@{
                        ServiceName = $cleanName
                        Status      = "Failed: $($_.Exception.Message)"
                        Timestamp   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } -ArgumentList $Name
        }
    }
}

# Delete a scheduled task from target computer
function Remove-RemoteScheduledTask {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $true)]
        [string]$TaskName
    )

    Process {
        foreach ($computer in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($computer)) { continue }

            Write-Output "=================== Remove Scheduled Task Target: $computer ==================="
            
            Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                param($name)

                $cleanName = $name.Trim()
                try {
                    if (Get-Command Unregister-ScheduledTask -ErrorAction SilentlyContinue) {
                        Unregister-ScheduledTask -TaskName $cleanName -Confirm:$false -ErrorAction Stop
                        [PSCustomObject]@{
                            TaskName  = $cleanName
                            Status    = "Deleted"
                            Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    } else {
                        # Fallback: schtasks.exe
                        $schRes = cmd.exe /c "schtasks.exe /delete /tn `"$cleanName`" /f" 2>&1
                        [PSCustomObject]@{
                            TaskName  = $cleanName
                            Status    = "Deleted ($($schRes -join ' '))"
                            Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    }
                } catch {
                    # Fallback retry with schtasks
                    try {
                        $schRes = cmd.exe /c "schtasks.exe /delete /tn `"$cleanName`" /f" 2>&1
                        [PSCustomObject]@{
                            TaskName  = $cleanName
                            Status    = "Deleted ($($schRes -join ' '))"
                            Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    } catch {
                        [PSCustomObject]@{
                            TaskName  = $cleanName
                            Status    = "Failed: $($_.Exception.Message)"
                            Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    }
                }
            } -ArgumentList $TaskName
        }
    }
}

# Remove registry key or value from target computer
function Remove-RemoteRegistryKey {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string]$ValueName
    )

    Process {
        foreach ($computer in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($computer)) { continue }

            Write-Output "=================== Remove Registry Entry Target: $computer ==================="
            
            Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                param($regPath, $regVal)

                $cleanPath = $regPath.Trim()
                try {
                    if (-not [string]::IsNullOrWhiteSpace($regVal)) {
                        # Delete specific registry value
                        $cleanVal = $regVal.Trim()
                        Remove-ItemProperty -Path $cleanPath -Name $cleanVal -Force -ErrorAction Stop
                        [PSCustomObject]@{
                            RegistryPath  = $cleanPath
                            ValueName     = $cleanVal
                            Status        = "Value Deleted"
                            Timestamp     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    } else {
                        # Delete entire registry key
                        Remove-Item -Path $cleanPath -Recurse -Force -ErrorAction Stop
                        [PSCustomObject]@{
                            RegistryPath  = $cleanPath
                            ValueName     = "*"
                            Status        = "Key Deleted"
                            Timestamp     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    }
                } catch {
                    [PSCustomObject]@{
                        RegistryPath  = $cleanPath
                        ValueName     = if ($regVal) { $regVal } else { "*" }
                        Status        = "Failed: $($_.Exception.Message)"
                        Timestamp     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } -ArgumentList $Path, $ValueName
        }
    }
}

# Add host-based Windows Firewall rule on target computer
function Add-RemoteFirewallRule {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = @("localhost"),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [string]$DisplayName,

        [Parameter()]
        [ValidateSet('Inbound', 'Outbound')]
        [string]$Direction = 'Outbound',

        [Parameter()]
        [ValidateSet('Block', 'Allow')]
        [string]$Action = 'Block',

        [Parameter()]
        [string]$Protocol = 'Any',

        [Parameter()]
        [string]$RemoteAddress,

        [Parameter()]
        [string]$LocalPort
    )

    Begin {
        if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = $Name }
    }

    Process {
        foreach ($computer in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($computer)) { continue }

            Write-Output "=================== Add Firewall Rule Target: $computer ==================="
            
            Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                param($ruleName, $ruleDisp, $dir, $act, $proto, $remoteIP, $port)

                try {
                    if (Get-Command New-NetFirewallRule -ErrorAction SilentlyContinue) {
                        $fwParams = @{
                            Name        = $ruleName
                            DisplayName = $ruleDisp
                            Direction   = $dir
                            Action      = $act
                            Enabled     = 'True'
                            ErrorAction = 'Stop'
                        }
                        if (-not [string]::IsNullOrWhiteSpace($remoteIP)) { $fwParams['RemoteAddress'] = $remoteIP.Trim() }
                        if (-not [string]::IsNullOrWhiteSpace($port))     { $fwParams['LocalPort']     = $port.Trim() }
                        if (-not [string]::IsNullOrWhiteSpace($proto) -and $proto -ne 'Any') { $fwParams['Protocol'] = $proto.Trim() }

                        New-NetFirewallRule @fwParams | Out-Null
                        [PSCustomObject]@{
                            RuleName      = $ruleName
                            Direction     = $dir
                            Action        = $act
                            RemoteAddress = if ($remoteIP) { $remoteIP } else { "Any" }
                            LocalPort     = if ($port) { $port } else { "Any" }
                            Status        = "Created (NetSecurity)"
                            Timestamp     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    } else {
                        # Legacy fallback: netsh.exe advfirewall
                        $netshCmd = "netsh advfirewall firewall add rule name=`"$ruleDisp`" dir=$($dir.ToLower()) action=$($act.ToLower()) enable=yes"
                        if (-not [string]::IsNullOrWhiteSpace($remoteIP)) { $netshCmd += " remoteip=`"$($remoteIP.Trim())`"" }
                        if (-not [string]::IsNullOrWhiteSpace($port))     { $netshCmd += " localport=`"$($port.Trim())`"" }
                        if (-not [string]::IsNullOrWhiteSpace($proto) -and $proto -ne 'Any') { $netshCmd += " protocol=$($proto.ToLower())" }

                        $netshRes = cmd.exe /c $netshCmd 2>&1
                        [PSCustomObject]@{
                            RuleName      = $ruleName
                            Direction     = $dir
                            Action        = $act
                            RemoteAddress = if ($remoteIP) { $remoteIP } else { "Any" }
                            LocalPort     = if ($port) { $port } else { "Any" }
                            Status        = "Created (netsh: $($netshRes -join ' '))"
                            Timestamp     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                        }
                    }
                } catch {
                    [PSCustomObject]@{
                        RuleName  = $ruleName
                        Direction = $dir
                        Action    = $act
                        Status    = "Failed: $($_.Exception.Message)"
                        Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
                    }
                }
            } -ArgumentList $Name, $DisplayName, $Direction, $Action, $Protocol, $RemoteAddress, $LocalPort
        }
    }
}