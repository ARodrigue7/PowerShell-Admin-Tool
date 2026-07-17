<#
.SYNOPSIS
    PowerShell Remote Admin Tool (Module-Based)
.DESCRIPTION
    A graphical tool for remote execution of PowerShell functions loaded dynamically from a local module.
    Runs tasks asynchronously in background processes using Start-Job.
.NOTES
    Author: Gemini Enterprise & ChatGPT (Consolidated)
    Version: 6.0 Module Pivot
#>

#region XAML Data
Add-Type -AssemblyName PresentationFramework

$XAML_MainWindow = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerShell Remote Admin Tool (Module-Based)" Height="800" Width="1000" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="5" />
            <RowDefinition Height="250" MinHeight="100" />
        </Grid.RowDefinitions>
        <Grid Grid.Row="0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="350" />
                <ColumnDefinition Width="*" />
            </Grid.ColumnDefinitions>
            <TabControl Grid.Column="0" Margin="5">
                <TabItem Header="Targets &amp; Auth">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="10">
                            <Label Content="Target Computers" FontWeight="Bold" />
                            <TextBox Name="ComputerInputTextBox" ToolTip="Enter computer names, comma-separated." />
                            <Button Name="ImportFromFileButton" Content="Import from File..." Margin="0,5,0,0" />
                            <ListView Name="ComputerListView" Height="150" SelectionMode="Multiple" ScrollViewer.HorizontalScrollBarVisibility="Disabled" Margin="0,5,0,0">
                                <ListView.ItemsPanel><ItemsPanelTemplate><WrapPanel /></ItemsPanelTemplate></ListView.ItemsPanel>
                                <ListView.ItemTemplate><DataTemplate>
                                    <Border BorderBrush="CornflowerBlue" Background="AliceBlue" BorderThickness="1" CornerRadius="3" Margin="3" Padding="6,3"><TextBlock Text="{Binding}" /></Border>
                                </DataTemplate></ListView.ItemTemplate>
                            </ListView>
                            
                            <Separator Margin="0,15,0,10" />
                            
                            <Label Content="Alternate Credentials (Optional)" FontWeight="Bold" />
                            <Grid>
                                 <Grid.ColumnDefinitions>
                                     <ColumnDefinition Width="Auto"/>
                                     <ColumnDefinition Width="*" />
                                 </Grid.ColumnDefinitions>
                                 <Grid.RowDefinitions>
                                     <RowDefinition />
                                     <RowDefinition />
                                 </Grid.RowDefinitions>
                                 <Label Grid.Row="0" Grid.Column="0" Content="Username:" VerticalAlignment="Center"/>
                                 <TextBox Grid.Row="0" Grid.Column="1" Name="UsernameTextBox" Margin="5" VerticalAlignment="Center"/>
                                 <Label Grid.Row="1" Grid.Column="0" Content="Password:" VerticalAlignment="Center"/>
                                 <PasswordBox Grid.Row="1" Grid.Column="1" Name="PasswordInputBox" Margin="5" VerticalAlignment="Center"/>
                            </Grid>
                            <Button Name="ApplyCredentialsButton" Content="Apply Credentials" Margin="0,5,0,0" />
                        </StackPanel>
                    </ScrollViewer>
                </TabItem>
                
                <TabItem Header="Run Functions">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="10">
                            <Label Content="Select &amp; Run Function" FontWeight="Bold" />
                            <ComboBox Name="ScriptSelectionComboBox" DisplayMemberPath="Name" Margin="0,5,0,0" />
                            <Label Content="Function Arguments / Path (Optional)" FontWeight="Bold" Margin="0,10,0,0" />
                            <TextBox Name="ArgumentsTextBox" ToolTip="Enter arguments or paths for the function (e.g. C:\Windows\System32\drivers\etc\hosts)" Height="25" />
                            <Button Name="GetInfoButton" Content="Get Quick OS Info" FontWeight="Bold" Margin="0,15,0,0" Height="30" />
                            <Button Name="RunScriptButton" Content="Execute Function" FontWeight="Bold" Margin="0,10,0,0" Height="35" />
                        </StackPanel>
                    </ScrollViewer>
                </TabItem>
            </TabControl>
            <Border Grid.Column="1" Margin="10" BorderBrush="LightGray" BorderThickness="1">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*" />
                    </Grid.RowDefinitions>
                    <Label Grid.Row="0" FontWeight="Bold" Background="LightGray" Padding="5" Content="Function Source Code Preview"/>
                    <FlowDocumentScrollViewer Grid.Row="1" Name="ScriptDescriptionViewer" Padding="5"/>
                </Grid>
            </Border>
        </Grid>
        <GridSplitter Grid.Row="1" Height="5" HorizontalAlignment="Stretch" Background="LightGray" />
        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
            </Grid.ColumnDefinitions>
            <RichTextBox Name="OutputConsole" IsReadOnly="True" VerticalScrollBarVisibility="Auto" FontFamily="Consolas" />
            <StackPanel Grid.Column="1" VerticalAlignment="Top" Margin="5,0,0,0">
                <Button Name="ClearConsoleButton" Content="Clear Console" Width="100" Margin="0,0,0,5" />
                <Button Name="CancelJobsButton" Content="Cancel Jobs" Width="100" Margin="0,0,0,5" />
                <Button Name="ExportResultsButton" Content="Export Results..." Width="100" />
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@
#endregion

#region Globals & Helper Functions
$Global:ActiveJobs = @{}
$Global:ModulePath = ""
$Global:LastJobResults = $null

function Add-OutputLine {
    [CmdletBinding()]
    param([string]$Text, [string]$Color = "Black")
    $ui.Window.Dispatcher.Invoke([Action]{
        $paragraph = [System.Windows.Documents.Paragraph]::new()
        $run = [System.Windows.Documents.Run]::new($Text)
        $run.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString($Color))
        $paragraph.Inlines.Add($run)
        $ui.OutputConsole.Document.Blocks.Add($paragraph)
        $ui.OutputConsole.ScrollToEnd()
    })
}

function Update-ComputerListView {
    $computers = @($ui.ComputerInputTextBox.Text.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $ui.ComputerListView.ItemsSource = $computers
}

function Update-ScriptDescriptionView {
    $selectedScript = $ui.ScriptSelectionComboBox.SelectedItem
    $doc = [System.Windows.Documents.FlowDocument]::new()
    if ($null -eq $selectedScript) {
        $doc.Blocks.Add([System.Windows.Documents.Paragraph]::new([System.Windows.Documents.Run]::new("No function selected.")))
        $ui.ScriptDescriptionViewer.Document = $doc
        return
    }
    try {
        $cmd = Get-Command -Name $selectedScript.Name -ErrorAction SilentlyContinue
        if ($cmd) {
            $definitionText = "function $($cmd.Name) {`r`n$($cmd.Definition)`r`n}"
        } else {
            $definitionText = "Function source not available."
        }
        $cp = [System.Windows.Documents.Paragraph]::new()
        $cp.FontFamily = "Consolas"
        $cp.FontSize = 12
        $cp.Inlines.Add([System.Windows.Documents.Run]::new($definitionText))
        $doc.Blocks.Add($cp)
    } catch {
        $run = [System.Windows.Documents.Run]::new("Error reading function definition: $($_.Exception.Message)")
        $run.Foreground = [System.Windows.Media.Brushes]::Red
        $doc.Blocks.Add([System.Windows.Documents.Paragraph]::new($run))
    }
    $ui.ScriptDescriptionViewer.Document = $doc
}

function New-PSCredentialFromUI {
    if (-not [string]::IsNullOrWhiteSpace($ui.UsernameTextBox.Text) -and -not [string]::IsNullOrWhiteSpace($ui.PasswordInputBox.Password)) {
        return [System.Management.Automation.PSCredential]::new($ui.UsernameTextBox.Text, $ui.PasswordInputBox.SecurePassword)
    }
    return $null
}
#endregion

#region Initialization
if ($PSScriptRoot) { $ScriptPath = $PSScriptRoot } else { $ScriptPath = Get-Location }
$Global:ModulePath = Join-Path $ScriptPath "functions.psm1"

try {
    [xml]$xaml = $XAML_MainWindow
    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $ui = @{}
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object { $ui[$_.Name] = $window.FindName($_.Name) }
    $ui['Window'] = $window
} catch {
    Write-Error "CRITICAL: Failed to load UI. Error: $($_.Exception.Message)"
    return
}
#endregion

#region Event Handlers
$ui.ImportFromFileButton.add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = "Text Files (*.txt)|*.txt|CSV Files (*.csv)|*.csv|All files (*.*)|*.*"
    if ($dlg.ShowDialog() -eq $true) {
        try {
            $comps = @(Get-Content $dlg.FileName | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $ui.ComputerInputTextBox.Text = $comps -join ", "
            Update-ComputerListView
            Add-OutputLine -Text "Successfully imported $($comps.Count) computers." -Color "Green"
        } catch { Add-OutputLine -Text "Error reading file: $($_.Exception.Message)" -Color "Red" }
    }
})

$ui.ComputerInputTextBox.add_TextChanged({ Update-ComputerListView })
$ui.ScriptSelectionComboBox.add_SelectionChanged({ Update-ScriptDescriptionView })

$ui.GetInfoButton.add_Click({
    $Global:LastJobResults = $null
    $computers = $ui.ComputerListView.ItemsSource
    if (-not $computers) { Add-OutputLine -Text "No target computers specified." -Color "Red"; return }
    
    Add-OutputLine -Text "Starting 'Get Quick OS Info' (Asynchronous)..." -Color "Blue"
    $cred = New-PSCredentialFromUI
    $jobName = "GetInfo_$(Get-Date -Format 'HHmmss')"
    
    try {
        $job = Start-Job -Name $jobName -ScriptBlock {
            param($computers, $credential)
            
            # Global overrides inside the job process BEFORE calling Invoke-Command
            function global:Get-Credential { return $null }
            
            function global:Invoke-Command {
                [CmdletBinding(DefaultParameterSetName='Session')]
                param(
                    [Parameter(Mandatory=$true, ParameterSetName='ComputerName')]
                    [string[]]$ComputerName,

                    [Parameter(Mandatory=$true)]
                    [scriptblock]$ScriptBlock,

                    [Parameter(ParameterSetName='ComputerName')]
                    $Credential
                )
                
                $localNames = @("localhost", "127.0.0.1", "::1", $env:COMPUTERNAME.ToLower())
                
                $results = @()
                foreach ($comp in $ComputerName) {
                    if ($localNames -contains $comp.Trim().ToLower()) {
                        try {
                            $res = & $ScriptBlock
                            if ($res) {
                                foreach ($r in $res) {
                                    if ($r -and $r -is [System.Management.Automation.PSCustomObject]) {
                                        if (-not $r.PSObject.Properties['PSComputerName']) {
                                            $r | Add-Member -MemberType NoteProperty -Name "PSComputerName" -Value $env:COMPUTERNAME -Force
                                        }
                                    }
                                    $results += $r
                                }
                            }
                        } catch {
                            Write-Error "Local execution bypass failed: $($_.Exception.Message)"
                        }
                    } else {
                        $params = @{ ScriptBlock = $ScriptBlock; ComputerName = $comp }
                        if ($Credential -ne $null) { $params['Credential'] = $Credential }
                        $res = Microsoft.PowerShell.Core\Invoke-Command @params
                        if ($res) { $results += $res }
                    }
                }
                return $results
            }
            
            $infoScript = {
                $os = Get-CimInstance -ClassName Win32_OperatingSystem
                $cs = Get-CimInstance -ClassName Win32_ComputerSystem
                $uptime = (Get-Date) - $os.LastBootUpTime
                $upStr = "{0:N0} days, {1:D2}h:{2:D2}m:{3:D2}s" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
                return [PSCustomObject]@{ OS = $os.Caption; Model = $cs.Model; Uptime = $upStr }
            }
            
            Invoke-Command -ComputerName $computers -Credential $credential -ScriptBlock $infoScript
            
        } -ArgumentList $computers, $cred
        
        $Global:ActiveJobs[$job.Id] = $job
        Add-OutputLine -Text "Job '$($job.Name)' queued." -Color "Orange"
    } catch { Add-OutputLine -Text "Failed to start job: $($_.Exception.Message)" -Color "Red" }
})

$ui.RunScriptButton.add_Click({
    $Global:LastJobResults = $null
    $computers = $ui.ComputerListView.ItemsSource
    $selectedScript = $ui.ScriptSelectionComboBox.SelectedItem
    if (-not $computers) { Add-OutputLine -Text "No target computers specified." -Color "Red"; return }
    if (-not $selectedScript) { Add-OutputLine -Text "No function selected." -Color "Red"; return }
    
    Add-OutputLine -Text "Executing function '$($selectedScript.Name)' (Asynchronous)..." -Color "Blue"
    $cred = New-PSCredentialFromUI
    $funcName = $selectedScript.Name
    $modPath = $Global:ModulePath
    $argumentsText = $ui.ArgumentsTextBox.Text

    # Start the job
    $jobName = "Execute_$($funcName)_$(Get-Date -Format 'HHmmss')"
    try {
        $job = Start-Job -Name $jobName -ScriptBlock {
            param($modulePath, $functionName, $computers, $credential, $arguments)
            
            # Global overrides inside the job process BEFORE importing the module
            function global:Get-Credential { return $null }
            
            function global:Invoke-Command {
                [CmdletBinding(DefaultParameterSetName='Session')]
                param(
                    [Parameter(Mandatory=$true, ParameterSetName='ComputerName')]
                    [string[]]$ComputerName,

                    [Parameter(Mandatory=$true)]
                    [scriptblock]$ScriptBlock,

                    [Parameter(ParameterSetName='ComputerName')]
                    $Credential
                )
                
                $localNames = @("localhost", "127.0.0.1", "::1", $env:COMPUTERNAME.ToLower())
                
                $results = @()
                foreach ($comp in $ComputerName) {
                    if ($localNames -contains $comp.Trim().ToLower()) {
                        try {
                            $res = & $ScriptBlock
                            if ($res) {
                                foreach ($r in $res) {
                                    if ($r -and $r -is [System.Management.Automation.PSCustomObject]) {
                                        if (-not $r.PSObject.Properties['PSComputerName']) {
                                            $r | Add-Member -MemberType NoteProperty -Name "PSComputerName" -Value $env:COMPUTERNAME -Force
                                        }
                                    }
                                    $results += $r
                                }
                            }
                        } catch {
                            Write-Error "Local execution bypass failed: $($_.Exception.Message)"
                        }
                    } else {
                        $params = @{ ScriptBlock = $ScriptBlock; ComputerName = $comp }
                        if ($Credential -ne $null) { $params['Credential'] = $Credential }
                        $res = Microsoft.PowerShell.Core\Invoke-Command @params
                        if ($res) { $results += $res }
                    }
                }
                return $results
            }
            
            # Import module (which now resolves to our global overrides)
            Import-Module $modulePath -Force
            
            $command = Get-Command -Name $functionName -ErrorAction SilentlyContinue
            if (-not $command) {
                throw "Function '$functionName' not found in module '$modulePath'."
            }
            
            $params = @{}
            if ($computers -and $command.Parameters.ContainsKey('ComputerName')) {
                $params['ComputerName'] = $computers
            }
            if ($credential) {
                if ($command.Parameters.ContainsKey('Credential')) {
                    $params['Credential'] = $credential
                }
            }
            if ($arguments) {
                if ($command.Parameters.ContainsKey('Path')) {
                    $params['Path'] = $arguments
                }
            }
            
            & $functionName @params
        } -ArgumentList $modPath, $funcName, $computers, $cred, $argumentsText

        if ($job) {
            $Global:ActiveJobs[$job.Id] = $job
            Add-OutputLine -Text "Job '$($job.Name)' (ID: $($job.Id)) queued successfully." -Color "Orange"
        } else {
            Add-OutputLine -Text "Failed to start background job." -Color "Red"
        }
    } catch {
        Add-OutputLine -Text "Error starting job: $($_.Exception.Message)" -Color "Red"
    }
})

$ui.CancelJobsButton.add_Click({
    foreach ($jobId in @($Global:ActiveJobs.Keys)) {
        try { Stop-Job $Global:ActiveJobs[$jobId] -Force; Remove-Job $Global:ActiveJobs[$jobId] -Force } catch {}
    }
    $Global:ActiveJobs.Clear()
    Add-OutputLine -Text "All running jobs have been cancelled." -Color "OrangeRed"
})

$ui.ClearConsoleButton.add_Click({ $ui.OutputConsole.Document.Blocks.Clear() })

$ui.ApplyCredentialsButton.add_Click({
    $user = $ui.UsernameTextBox.Text
    $pass = $ui.PasswordInputBox.Password
    if ([string]::IsNullOrWhiteSpace($user)) {
        [System.Windows.MessageBox]::Show("Username cannot be empty when applying alternate credentials.", "Credentials Warning", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
    } else {
        Add-OutputLine -Text "Alternate credentials applied successfully for user: $user" -Color "DarkGreen"
        [System.Windows.MessageBox]::Show("Credentials successfully applied to session.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    }
})

$ui.ExportResultsButton.add_Click({
    $hasResults = ($null -ne $Global:LastJobResults -and $Global:LastJobResults.Count -gt 0)
    $textRange = New-Object System.Windows.Documents.TextRange($ui.OutputConsole.Document.ContentStart, $ui.OutputConsole.Document.ContentEnd)
    $consoleText = $textRange.Text.Trim()
    
    if (-not $hasResults -and [string]::IsNullOrWhiteSpace($consoleText)) {
        [System.Windows.MessageBox]::Show("There are no results or console output to export.", "No Data", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Title = "Export Output Results"
    
    if ($hasResults) {
        $dlg.Filter = "CSV Files (*.csv)|*.csv|JSON Files (*.json)|*.json|Text Log Files (*.txt)|*.txt|All files (*.*)|*.*"
        $dlg.DefaultExt = "csv"
    } else {
        $dlg.Filter = "Text Log Files (*.txt)|*.txt|All files (*.*)|*.*"
        $dlg.DefaultExt = "txt"
    }

    if ($dlg.ShowDialog() -eq $true) {
        try {
            $ext = [System.IO.Path]::GetExtension($dlg.FileName).ToLower()
            if ($ext -eq '.csv' -and $hasResults) {
                $Global:LastJobResults | Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding utf8
                Add-OutputLine -Text "Successfully exported job results to CSV: $($dlg.FileName)" -Color "Green"
            }
            elseif ($ext -eq '.json' -and $hasResults) {
                $json = $Global:LastJobResults | ConvertTo-Json -Depth 5
                [System.IO.File]::WriteAllText($dlg.FileName, $json, [System.Text.Encoding]::UTF8)
                Add-OutputLine -Text "Successfully exported job results to JSON: $($dlg.FileName)" -Color "Green"
            }
            else {
                [System.IO.File]::WriteAllText($dlg.FileName, $consoleText, [System.Text.Encoding]::UTF8)
                Add-OutputLine -Text "Successfully exported console log to file: $($dlg.FileName)" -Color "Green"
            }
        }
        catch {
            Add-OutputLine -Text "Failed to export results: $($_.Exception.Message)" -Color "Red"
        }
    }
})
#endregion

#region Job Monitor Timer
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    foreach ($jobId in @($Global:ActiveJobs.Keys)) {
        $job = $Global:ActiveJobs[$jobId]
        if ($job.State -ne 'Running') {
            $allResults = Receive-Job $job 2>&1
            Remove-Job $job -Force
            $Global:ActiveJobs.Remove($jobId)
            
            Add-OutputLine -Text "--- Job Completed: $($job.Name) ---" -Color "DarkBlue"
            
            if ($allResults) {
                $resultsList = [System.Collections.Generic.List[PSObject]]::new()
                foreach ($item in $allResults) {
                    $comp = if ($item.PSComputerName) { $item.PSComputerName } else { "Output" }
                    if ($item -is [System.Management.Automation.ErrorRecord]) {
                        Add-OutputLine -Text "[$comp] ERROR: $($item.Exception.Message)" -Color "Red"
                    } else {
                        $resultsList.Add($item)
                        ($item | Out-String).Split("`n") | ForEach-Object {
                            if (-not [string]::IsNullOrWhiteSpace($_)) { Add-OutputLine -Text "[$comp] $($_.Trim())" -Color "Black" }
                        }
                    }
                }
                if ($resultsList.Count -gt 0) {
                    $Global:LastJobResults = $resultsList.ToArray()
                }
            } else {
                Add-OutputLine -Text "  (Job completed with no output.)" -Color "Gray"
            }
        }
    }
})
$timer.Start()
#endregion

#region Start App
try {
    if (-not (Test-Path $Global:ModulePath)) {
        Add-OutputLine -Text "ERROR: functions.psm1 not found at path: $Global:ModulePath" -Color "Red"
    } else {
        Add-OutputLine -Text "Loading functions from module '$Global:ModulePath'..." -Color "Blue"
        Import-Module $Global:ModulePath -Force
        
        $funcs = Get-Command -Module functions -CommandType Function | Sort-Object Name
        if ($funcs) {
            $ui.ScriptSelectionComboBox.ItemsSource = $funcs
            $ui.ScriptSelectionComboBox.SelectedIndex = 0
            Add-OutputLine -Text "Loaded $($funcs.Count) functions from module." -Color "Green"
        } else {
            Add-OutputLine -Text "No functions found in module functions." -Color "Orange"
        }
    }

    $ui.ComputerInputTextBox.Text = $env:COMPUTERNAME
    Update-ComputerListView
    Add-OutputLine -Text "Remote Admin Tool Ready. Module Mode Enabled." -Color "Green"
} catch { 
    Add-OutputLine -Text "Init Error: $($_.Exception.Message)" -Color "Red" 
}

if ($ui.Window) { $null = $ui.Window.ShowDialog() }
#endregion
