<#
.SYNOPSIS
    Generates a comprehensive baseline of host and network configurations.
.DESCRIPTION
    Imports the functions.psm1 module and runs all administrative, network, and security
    baseline functions against target computers. Outputs are saved as organized CSV files.
.PARAMETER ComputerName
    An array of target computer names or IP addresses. Defaults to 'localhost'.
.PARAMETER Credential
    Optional PSCredential object for alternate authentication.
.PARAMETER OutputFolder
    The folder where baseline CSV files will be stored. Defaults to 'Baselines_yyyyMMdd_HHmmss' in the script directory.
.EXAMPLE
    .\New-Baseline.ps1 -ComputerName "server1", "server2" -Credential (Get-Credential)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromPipeline = $true)]
    [string[]]$ComputerName = @("localhost"),

    [Parameter(Position = 1)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Position = 2)]
    [string]$OutputFolder
)

Begin {
    # Resolve and import the functions.psm1 module
    $moduleName = "functions.psm1"
    $modulePath = Join-Path $PSScriptRoot $moduleName
    if (-not (Test-Path $modulePath)) {
        $modulePath = Join-Path (Get-Location) $moduleName
    }
    
    if (-not (Test-Path $modulePath)) {
        Write-Error "CRITICAL: '$moduleName' not found. Cannot proceed."
        return
    }

    Write-Host "Importing module '$moduleName'..." -ForegroundColor Blue
    Import-Module $modulePath -Force

    # Override Get-Credential inside the module scope to prevent prompting
    $module = Get-Module -Name functions
    if ($module) {
        & $module {
            function Get-Credential { return $null }
        }
    }

    # Initialize the output folder
    if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $OutputFolder = Join-Path $PSScriptRoot "Baselines_$timestamp"
    }

    # Resolve output path to absolute path
    $OutputFolder = [System.IO.Path]::GetFullPath($OutputFolder)

    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }
    Write-Host "Baselines will be saved in: $OutputFolder" -ForegroundColor Green
}

Process {
    foreach ($computer in $ComputerName) {
        $compNameClean = $computer -replace '[^a-zA-Z0-9.-]', '_'
        Write-Host "`n=================== Baselining Target: $computer ===================" -ForegroundColor Cyan

        # 1. Test Connection
        Write-Host "Checking remote connection status using WSMan..." -ForegroundColor Gray
        $isReady = Test-ComputerConnection -ComputerNames $computer -Credential $Credential
        if (-not $isReady) {
            Write-Warning "WSMan connection test failed for target '$computer'. Skipping baselining."
            continue
        }
        Write-Host "Connection verified successfully!" -ForegroundColor Green

        # Helper function to run a baseline function, catch errors, and export to CSV
        function Run-AndExportBaseline {
            param(
                [string]$Name,
                [scriptblock]$ScriptBlock
            )
            Write-Host "Running '$Name'..." -ForegroundColor Gray
            try {
                $data = & $ScriptBlock
                if ($data) {
                    $csvPath = Join-Path $OutputFolder "${Name}_${compNameClean}.csv"
                    $data | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
                    Write-Host "-> Successfully exported to: $csvPath" -ForegroundColor Green
                } else {
                    Write-Host "-> No data returned." -ForegroundColor DarkGray
                }
            }
            catch {
                Write-Warning "Failed to run baseline '$Name': $($_.Exception.Message)"
            }
        }

        # 2. Run Host Network State Queries
        Run-AndExportBaseline -Name "OSInfo" -ScriptBlock { Get-OSInfo -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "Processes" -ScriptBlock { Get-WmiProcess -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "Services" -ScriptBlock { Get-ServiceInfo -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "Connections" -ScriptBlock { Get-Connection -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "Shares" -ScriptBlock { Get-ShareInfo -ComputerName $computer -Credential $Credential }

        # 3. Run Persistence & Security Auditing Queries
        Run-AndExportBaseline -Name "RegistryRun" -ScriptBlock { Get-RegistryRun -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "StartupFolders" -ScriptBlock { Get-StartupFolders -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "ScheduledTasks" -ScriptBlock { Get-SchTask -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "LogonHistory" -ScriptBlock { Get-LogOnHistory -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "LocalGroupMembers" -ScriptBlock { Get-LGroupMembers -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "RegistryUserShellFolders" -ScriptBlock { Get-RegistryUserShellFolders -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "Prefetches" -ScriptBlock { Get-Prefetch -ComputerName $computer -Credential $Credential }

        # 4. Active Directory & Domain Queries (Gracefully handle failures if AD context is unavailable)
        Run-AndExportBaseline -Name "ADDomainController" -ScriptBlock { Get-DomainController -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "ADDomainUser" -ScriptBlock { Get-DomainUser -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "ADDomainGroup" -ScriptBlock { Get-DomainGroup -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "ADDomainGroupMembership" -ScriptBlock { Get-DomainGroupMembership -ComputerName $computer -Credential $Credential }
        Run-AndExportBaseline -Name "ADGPOInfo" -ScriptBlock { Get-GPOInfo -ComputerName $computer -Credential $Credential }
    }
}

End {
    Write-Host "`nBaselining run completed. All generated files are in: $OutputFolder" -ForegroundColor Cyan
}
