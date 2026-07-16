<#
.SYNOPSIS
    Wrapper script to generate a comprehensive baseline of host and network configurations.
.DESCRIPTION
    Imports the functions.psm1 module and executes Get-HostBaseline.
.PARAMETER ComputerName
    An array of target computer names. Defaults to 'localhost'.
.PARAMETER Credential
    Optional PSCredential object for alternate authentication.
.PARAMETER OutputFolder
    The directory where baseline files will be stored. Defaults to 'Baselines_yyyyMMdd_HHmmss' in the current working directory.
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
    $modulePath = Join-Path $PSScriptRoot "functions.psm1"
    if (-not (Test-Path $modulePath)) {
        $modulePath = Join-Path (Get-Location) "functions.psm1"
    }

    if (-not (Test-Path $modulePath)) {
        Write-Error "CRITICAL: 'functions.psm1' not found. Cannot proceed."
        return
    }

    Write-Host "Importing module 'functions.psm1'..." -ForegroundColor Blue
    Import-Module $modulePath -Force

    # Override Get-Credential inside the module scope to prevent prompting
    $module = Get-Module -Name functions
    if ($module) {
        & $module {
            function Get-Credential { return $null }
        }
    }
}

Process {
    Get-HostBaseline -ComputerName $ComputerName -Credential $Credential -OutputFolder $OutputFolder
}
