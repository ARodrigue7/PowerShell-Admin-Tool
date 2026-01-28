<#
.SYNOPSIS
    A graphical tool for remote PowerShell script execution and management.
.DESCRIPTION
    This tool provides a WPF-based user interface to manage a library of custom scripts 
    and execute them against target computers using default or alternate credentials.
    
    This script has been refactored to align with the PowerShell Practice and Style guide,
    emphasizing structure, readability, proper function design, and maintainability.
.NOTES
    Author: Gemini Enterprise (Refactored by an Expert PowerShell Developer)
    Version: 4.3 (Fixed null reference error in UI object initialization)
#>

#region XAML Data
Add-Type -AssemblyName PresentationFramework
# XAML is defined as here-strings. It will be cast to [xml] inside a try-catch block for safety.

$XAML_MainWindow = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerShell Remote Admin Tool v4.3 (Best Practices)" Height="800" Width="1000" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="5" />
            <RowDefinition Height="250" MinHeight="100" />
        </Grid.RowDefinitions>
        <TabControl Grid.Row="0" Name="MainTabControl">
            <TabItem Header="Remote Computer Info">
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="350" /><ColumnDefinition Width="*" /></Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Margin="10">
                        <Label Content="Target Computers" FontWeight="Bold" />
                        <TextBox Name="ComputerInputTextBox" ToolTip="Enter computer names, comma-separated." />
                        <Button Name="ImportFromFileButton" Content="Import from File..." Margin="0,5,0,0" />
                        <ListView Name="ComputerListView" Height="125" SelectionMode="Multiple" ScrollViewer.HorizontalScrollBarVisibility="Disabled" Margin="0,5,0,0">
                            <ListView.ItemsPanel><ItemsPanelTemplate><WrapPanel /></ItemsPanelTemplate></ListView.ItemsPanel>
                            <ListView.ItemTemplate><DataTemplate>
                                <Border BorderBrush="CornflowerBlue" Background="AliceBlue" BorderThickness="1" CornerRadius="3" Margin="3" Padding="6,3"><TextBlock Text="{Binding}" /></Border>
                            </DataTemplate></ListView.ItemTemplate>
                        </ListView>
                        <Separator Margin="0,15,0,5" />
                        <Label Content="Alternate Credentials (Optional)" FontWeight="Bold" />
                        <Grid>
                             <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*" /></Grid.ColumnDefinitions>
                             <Grid.RowDefinitions><RowDefinition /><RowDefinition /></Grid.RowDefinitions>
                             <Label Grid.Row="0" Grid.Column="0" Content="Username:" VerticalAlignment="Center"/>
                             <TextBox Grid.Row="0" Grid.Column="1" Name="UsernameTextBox" Margin="5" VerticalAlignment="Center"/>
                             <Label Grid.Row="1" Grid.Column="0" Content="Password:" VerticalAlignment="Center"/>
                             <PasswordBox Grid.Row="1" Grid.Column="1" Name="PasswordInputBox" Margin="5" VerticalAlignment="Center"/>
                        </Grid>
                        <Separator Margin="0,15,0,5" />
                        <Label Content="Select &amp; Run Action" FontWeight="Bold" />
                        <ComboBox Name="ScriptSelectionComboBox" DisplayMemberPath="Name" Margin="0,5,0,0" />
                        <Button Name="GetInfoButton" Content="Get Info" FontWeight="Bold" Margin="0,10,0,0" />
                        <Button Name="RunScriptButton" Content="Run Selected Script" FontWeight="Bold" Margin="0,10,0,0" />
                    </StackPanel>
                    <Border Grid.Column="1" Margin="10" BorderBrush="LightGray" BorderThickness="1">
                        <Grid>
                            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*" /></Grid.RowDefinitions>
                            <Label Grid.Row="0" FontWeight="Bold" Background="LightGray" Padding="5" Content="Script Preview"/>
                            <FlowDocumentScrollViewer Grid.Row="1" Name="ScriptDescriptionViewer" Padding="5"/>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>
            <TabItem Header="Script Library">
                <Grid Margin="10">
                    <Grid.RowDefinitions><RowDefinition Height="*" /><RowDefinition Height="Auto" /></Grid.RowDefinitions>
                    <ListView Name="ScriptLibraryListView" Grid.Row="0">
                        <ListView.View><GridView>
                            <GridViewColumn Header="Script Name" Width="300" DisplayMemberBinding="{Binding Name}" />
                            <GridViewColumn Header="File Path" Width="450" DisplayMemberBinding="{Binding Path}" />
                        </GridView></ListView.View>
                    </ListView>
                    <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
                        <Button Name="AddScriptButton" Content="Add New Script..." Width="120" Margin="5" />
                        <Button Name="RemoveScriptButton" Content="Remove Selected" Width="120" Margin="5" />
                    </StackPanel>
                </Grid>
            </TabItem>
        </TabControl>
        <GridSplitter Grid.Row="1" Height="5" HorizontalAlignment="Stretch" Background="LightGray" />
        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
            <RichTextBox Name="OutputConsole" IsReadOnly="True" VerticalScrollBarVisibility="Auto" FontFamily="Consolas" />
            <Button Name="ClearConsoleButton" Content="Clear Console" Grid.Column="1" VerticalAlignment="Top" Margin="5,0,0,0" />
        </Grid>
    </Grid>
</Window>
"@

$XAML_AddScriptDialog = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Add New Script" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterOwner" WindowStyle="ToolWindow">
    <StackPanel Margin="15">
        <Label Content="Friendly Script Name:" /><TextBox Name="ScriptNameTextBox" Width="300" />
        <Label Content="Path to Script File (.md or .ps1):" Margin="0,10,0,0" />
        <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
            <TextBox Name="ScriptPathTextBox" Width="300" /><Button Name="BrowseButton" Content="..." Grid.Column="1" Width="30" Margin="5,0,0,0" />
        </Grid>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
            <Button Name="OkButton" Content="OK" Width="75" Margin="5" IsDefault="True" /><Button Name="CancelButton" Content="Cancel" Width="75" Margin="5" IsCancel="True" />
        </StackPanel>
    </StackPanel>
</Window>
"@
#endregion

#region Helper Functions

function Add-OutputLine {
    <#
    .SYNOPSIS
        Adds a colored line of text to the main output console.
    .DESCRIPTION
        This function safely handles UI updates from any thread by using the window's Dispatcher. 
        It creates a new paragraph in the RichTextBox for each line.
    .PARAMETER Text
        The string of text to add to the console.
    .PARAMETER Color
        The color of the text. Can be a named color like "Red", "Green", or "Black".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text,

        [string]$Color = "Black"
    )
    # The Dispatcher is used to ensure UI components are only updated on the main UI thread.
    $ui.Window.Dispatcher.Invoke([Action]{
        $paragraph = [System.Windows.Documents.Paragraph]::new()
        $run = [System.Windows.Documents.Run]::new($Text)
        $run.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString($Color))
        $paragraph.Inlines.Add($run)
        $ui.OutputConsole.Document.Blocks.Add($paragraph)
        $ui.OutputConsole.ScrollToEnd()
    })
}

function Update-ScriptLibraryView {
    <#
    .SYNOPSIS
        Loads all scripts from the scripts.xml file and populates the UI.
    .DESCRIPTION
        Reads the scripts.xml file from the script's root directory. If the file doesn't exist,
        it creates a new one. It then populates the ListView in the "Script Library" tab
        and the ComboBox in the main tab.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-Path $ScriptsXmlPath)) { 
        Add-OutputLine -Text "scripts.xml not found. Creating a new one." -Color "OrangeRed"
        '<scripts></scripts>' | Set-Content -Path $ScriptsXmlPath
    }
    
    [xml]$scriptsXml = Get-Content -Path $ScriptsXmlPath
    
    # Clear existing items to prevent duplication on reload.
    $ui.ScriptLibraryListView.ItemsSource = $null
    $ui.ScriptSelectionComboBox.ItemsSource = $null
    
    $scriptObjects = @()
    foreach ($node in $scriptsXml.scripts.script) { 
        $scriptObjects += [PSCustomObject]@{ 
            Name = $node.name
            Path = $node.path 
        } 
    }
    
    $ui.ScriptLibraryListView.ItemsSource = $scriptObjects
    $ui.ScriptSelectionComboBox.ItemsSource = $scriptObjects
    
    if ($scriptObjects.Count -gt 0) { 
        $ui.ScriptSelectionComboBox.SelectedIndex = 0 
    }
    
    Update-ScriptDescriptionView
}

function Get-ScriptCodeFromFile {
    <#
    .SYNOPSIS
        Extracts the executable PowerShell code from a script file.
    .DESCRIPTION
        If the file is a .ps1 file, it returns the entire raw content.
        If the file is a .md file, it uses a regular expression to find and extract
        the content from the first ```powershell code block.
    .PARAMETER FilePath
        The full path to the .ps1 or .md file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) { throw "File not found: $FilePath" }

    $fileContent = Get-Content -Path $FilePath -Raw

    if ($FilePath.EndsWith(".ps1", [System.StringComparison]::OrdinalIgnoreCase)) { 
        return $fileContent
    }
    
    $codeBlockRegex = '(?s)```powershell\s*(.*?)\s*```'
    $match = [regex]::Match($fileContent, $codeBlockRegex, 'IgnoreCase')
    
    if ($match.Success) { 
        return $match.Groups.Value.Trim() 
    } 
    else { 
        throw "Could not find a PowerShell code block (```powershell...```) in the specified .md file." 
    }
}

function Update-ComputerListView {
    <#
    .SYNOPSIS
        Updates the target computer list view from the main input textbox.
    .DESCRIPTION
        Parses the comma-separated text from the ComputerInputTextBox, trims each entry,
        and populates the horizontal ListView. It ensures the result is always an array
        to prevent the UI from iterating over a single string's characters.
    #>
    [CmdletBinding()]
    param()

    # The @() wrapper is critical to ensure a single computer name is treated as a list with one item.
    $computers = @($ui.ComputerInputTextBox.Text.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $ui.ComputerListView.ItemsSource = $computers
}

function Update-ScriptDescriptionView {
    <#
    .SYNOPSIS
        Parses and displays a formatted preview of the selected script file.
    .DESCRIPTION
        This function acts as a mini-Markdown renderer. It reads the selected script file and formats it
        for the FlowDocument viewer. It renders #, ##, ### as headers, **text** as bold, and ```powershell
        blocks with a distinct style. For .ps1 files, it displays the raw code in a code block style.
    #>
    [CmdletBinding()]
    param()

    $selectedScript = $ui.ScriptSelectionComboBox.SelectedItem
    $doc = [System.Windows.Documents.FlowDocument]::new()

    if ($null -eq $selectedScript) {
        $doc.Blocks.Add([System.Windows.Documents.Paragraph]::new([System.Windows.Documents.Run]::new("No script selected.")))
        $ui.ScriptDescriptionViewer.Document = $doc
        return
    }

    try {
        $fileContent = Get-Content -Path $selectedScript.Path -Raw

        # If it's a .ps1 file, just show it as a code block.
        if ($selectedScript.Path.EndsWith(".ps1", [System.StringComparison]::OrdinalIgnoreCase)) {
            $codeParagraph = [System.Windows.Documents.Paragraph]::new()
            $codeParagraph.FontFamily = "Consolas"
            $codeParagraph.Background = [System.Windows.Media.Brushes]::LightGray
            $codeParagraph.Padding = "5"
            $codeParagraph.Inlines.Add([System.Windows.Documents.Run]::new($fileContent))
            $doc.Blocks.Add($codeParagraph)
            $ui.ScriptDescriptionViewer.Document = $doc
            return
        }

        # For .md files, parse for formatting.
        $codeBlockRegex = '(?s)```powershell\s*(.*?)\s*```'
        $codeBlockMatch = [regex]::Match($fileContent, $codeBlockRegex)

        if ($codeBlockMatch.Success) {
            $beforeCode = $fileContent.Substring(0, $codeBlockMatch.Index)
            $codeContent = $codeBlockMatch.Groups.Value
            $afterCode = $fileContent.Substring($codeBlockMatch.Index + $codeBlockMatch.Length)
            
            # Process text before, the code, and text after
            Convert-MarkdownToFlowDocument -Content $beforeCode -Document $doc
            
            # Add the formatted code block
            $codeParagraph = [System.Windows.Documents.Paragraph]::new()
            $codeParagraph.FontFamily = "Consolas"; $codeParagraph.Background = [System.Windows.Media.Brushes]::LightGray
            $codeParagraph.Padding = "5"; $codeParagraph.Margin = "0,10,0,10"
            $codeParagraph.Inlines.Add([System.Windows.Documents.Run]::new($codeContent.Trim()))
            $doc.Blocks.Add($codeParagraph)
            
            Convert-MarkdownToFlowDocument -Content $afterCode -Document $doc
        } else {
            # No code block found, treat the whole file as markdown
            Convert-MarkdownToFlowDocument -Content $fileContent -Document $doc
        }

    } catch {
        $run = [System.Windows.Documents.Run]::new("Error reading script file: $($_.Exception.Message)")
        $run.Foreground = [System.Windows.Media.Brushes]::Red
        $doc.Blocks.Add([System.Windows.Documents.Paragraph]::new($run))
    }
    
    $ui.ScriptDescriptionViewer.Document = $doc
}

function Convert-MarkdownToFlowDocument {
    <#
    .SYNOPSIS
        A helper function that parses a block of Markdown text into FlowDocument elements.
    .DESCRIPTION
        This is not a full Markdown parser, but it handles the most common cases:
        - Headers (#, ##, ###)
        - Bold text (**text**)
        It processes the text line by line and adds formatted Runs and Paragraphs to the document.
    .PARAMETER Content
        The raw string content to parse.
    .PARAMETER Document
        The FlowDocument object to which the parsed elements should be added.
    #>
    [CmdletBinding()]
    param(
        [string]$Content,
        [System.Windows.Documents.FlowDocument]$Document
    )
    
    $Content.Split([Environment]::NewLine) | ForEach-Object {
        $line = $_
        $paragraph = [System.Windows.Documents.Paragraph]::new()
        $paragraph.Margin = "0" # Use tight spacing for paragraphs

        # Handle Headers
        if ($line.StartsWith("###"))      { $paragraph.FontSize = 14; $paragraph.FontWeight = "Bold"; $line = $line.Substring(3).Trim() }
        elseif ($line.StartsWith("##"))   { $paragraph.FontSize = 16; $paragraph.FontWeight = "Bold"; $line = $line.Substring(2).Trim() }
        elseif ($line.StartsWith("#"))    { $paragraph.FontSize = 20; $paragraph.FontWeight = "Bold"; $line = $line.Substring(1).Trim() }
        
        # Handle Bold text using **text**
        $boldRegex = '\*\*(.*?)\*\*'
        # Split the line by the bold markers to interleave normal and bold text
        $parts = $line.Split($boldRegex)
        $matches = [regex]::Matches($line, $boldRegex)

        for ($i = 0; $i -lt $parts.Length; $i++) {
            # Add the normal text part
            if ($parts[$i]) { $paragraph.Inlines.Add([System.Windows.Documents.Run]::new($parts[$i])) }
            # Add the bold text part if it exists
            if ($i -lt $matches.Count) {
                $boldRun = [System.Windows.Documents.Run]::new($matches[$i].Groups.Value)
                $boldRun.FontWeight = "Bold"
                $paragraph.Inlines.Add($boldRun)
            }
        }
        $Document.Blocks.Add($paragraph)
    }
}

function New-PSCredentialFromUI {
    <#
    .SYNOPSIS
        Creates a PSCredential object from the Username and Password fields in the UI.
    .DESCRIPTION
        Checks if the username and password fields are populated. If they are, it creates
        and returns a standard PSCredential object. If not, it returns $null.
    #>
    [CmdletBinding()]
    param()

    if (-not [string]::IsNullOrWhiteSpace($ui.UsernameTextBox.Text) -and -not [string]::IsNullOrWhiteSpace($ui.PasswordInputBox.Password)) {
        $username = $ui.UsernameTextBox.Text
        # The password from a PasswordBox is a SecureString, so no conversion is needed.
        $securePassword = $ui.PasswordInputBox.SecurePassword
        Add-OutputLine -Text "Constructing credential for user: $username" -Color "Orange"
        return [System.Management.Automation.PSCredential]::new($username, $securePassword)
    }
    return $null
}

#endregion

# --- Main Script Execution ---

#region Script Path Initialization
# If $PSScriptRoot is not defined (e.g., when running in ISE), fall back to the current working directory.
if ($PSScriptRoot) {
    $ScriptPath = $PSScriptRoot
} else {
    $ScriptPath = Get-Location
}
$ScriptsXmlPath = Join-Path $ScriptPath "scripts.xml"
#endregion

#region UI Initialization
try {
    # It is safer to cast to [xml] inside the try block.
    [xml]$xaml = $XAML_MainWindow
    [xml]$AddScriptDialogXAML = $XAML_AddScriptDialog

    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    # Store all UI controls in a hashtable for clean access, avoiding global scope pollution.
    $ui = @{}
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object {
        $ui[$_.Name] = $window.FindName($_.Name)
    }

    # === CRITICAL FIX: Add the main window object itself to the UI hashtable. ===
    $ui['Window'] = $window
}
catch {
    # If the UI fails to load, there's nothing else we can do.
    Write-Error "CRITICAL: Failed to load the main window XAML. The application cannot start. Error: $($_.Exception.Message)"
    return
}
#endregion

#region Event Handlers
# Note: Event handlers are kept concise. They call helper functions to perform complex logic.

$ui.ImportFromFileButton.add_Click({
    $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
    $openFileDialog.Filter = "Text Files (*.txt)|*.txt|CSV Files (*.csv)|*.csv|All files (*.*)|*.*"
    if ($openFileDialog.ShowDialog() -eq $true) {
        try {
            $computers = @(Get-Content $openFileDialog.FileName | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $ui.ComputerInputTextBox.Text = $computers -join ", "
            Update-ComputerListView
            Add-OutputLine -Text "Successfully imported $($computers.Count) computers." -Color "Green"
        } catch { 
            Add-OutputLine -Text "Error reading file: $($_.Exception.Message)" -Color "Red" 
        }
    }
})

$ui.ComputerInputTextBox.add_TextChanged({ 
    Update-ComputerListView 
})

$ui.ScriptSelectionComboBox.add_SelectionChanged({ 
    Update-ScriptDescriptionView
})

$ui.GetInfoButton.add_Click({
    $computers = $ui.ComputerListView.ItemsSource
    if (-not $computers) { Add-OutputLine -Text "No target computers specified." -Color "Red"; return }
    
    Add-OutputLine -Text "Starting 'Get Info'..." -Color "Blue"
    $window.Dispatcher.Invoke([Action]{}, "Background") 

    $getInfoScriptBlock = {
        $osInfo = Get-WmiObject -ClassName Win32_OperatingSystem
        $csInfo = Get-WmiObject -ClassName Win32_ComputerSystem
        $bootTime = $osInfo.ConvertToDateTime($osInfo.LastBootUpTime)
        $uptime = (Get-Date) - $bootTime
        $uptimeString = "{0:N0} days, {1:D2}h:{2:D2}m:{3:D2}s" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
        return [PSCustomObject]@{ OS = $osInfo.Caption; Model = $csInfo.Model; Uptime = $uptimeString }
    }

    $credential = New-PSCredentialFromUI

    $invokeParams = @{ ScriptBlock = $getInfoScriptBlock; ErrorAction = 'Stop' }
    if ($credential) { $invokeParams.Add("Credential", $credential) }

    foreach ($computer in $computers) {
        Add-OutputLine -Text "--- Querying $computer ---" -Color "DarkBlue"
        try {
            $invokeParams["ComputerName"] = $computer
            $result = Invoke-Command @invokeParams
            Add-OutputLine -Text "  OS:     $($result.OS)"
            Add-OutputLine -Text "  Model:  $($result.Model)"
            Add-OutputLine -Text "  Uptime: $($result.Uptime)"
        } catch {
            Add-OutputLine -Text "  ERROR: $($_.Exception.Message)".Trim() -Color "Red"
        }
    }
    Add-OutputLine -Text "--- 'Get Info' process complete. ---" -Color "Blue"
})

$ui.RunScriptButton.add_Click({
    $computers = $ui.ComputerListView.ItemsSource
    $selectedScript = $ui.ScriptSelectionComboBox.SelectedItem
    if (-not $computers) { Add-OutputLine -Text "No target computers specified." -Color "Red"; return }
    if (-not $selectedScript) { Add-OutputLine -Text "No script selected from the library." -Color "Red"; return }
    
    Add-OutputLine -Text "Starting script '$($selectedScript.Name)'..." -Color "Blue"
    $window.Dispatcher.Invoke([Action]{}, "Background") 

    try { $scriptCode = Get-ScriptCodeFromFile -FilePath $selectedScript.Path } 
    catch { Add-OutputLine -Text "FATAL ERROR reading script file: $($_.Exception.Message)" -Color "Red"; return }

    $scriptBlockToRun = [scriptblock]::Create($scriptCode)
    $credential = New-PSCredentialFromUI

    $invokeParams = @{ ScriptBlock = $scriptBlockToRun; ErrorAction = 'Stop' }
    if ($credential) { $invokeParams.Add("Credential", $credential) }

    foreach ($computer in $computers) {
        Add-OutputLine -Text "--- Executing on $computer ---" -Color "DarkBlue"
        try {
            $invokeParams["ComputerName"] = $computer
            $output = Invoke-Command @invokeParams
            if ($output) {
                ($output | Out-String).Split("`n") | ForEach-Object { if (-not [string]::IsNullOrWhiteSpace($_)) { Add-OutputLine -Text $_.Trim() } }
            } else {
                Add-OutputLine -Text "  (Script ran successfully with no output.)" -Color "Gray"
            }
        } catch {
            Add-OutputLine -Text "  REMOTE SCRIPT ERROR: $($_.Exception.Message)".Trim() -Color "Red"
        }
    }
    Add-OutputLine -Text "--- Script execution complete. ---" -Color "Blue"
})

$ui.AddScriptButton.add_Click({
    $dialogReader = [System.Xml.XmlNodeReader]::new($AddScriptDialogXAML)
    $dialogWindow = [Windows.Markup.XamlReader]::Load($dialogReader)
    
    $dialogUi = @{}
    $AddScriptDialogXAML.SelectNodes("//*[@Name]") | ForEach-Object { $dialogUi[$_.Name] = $dialogWindow.FindName($_.Name) }
    
    $dialogWindow.Owner = $ui.Window
    
    $dialogUi.BrowseButton.add_Click({
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "Supported Scripts (*.md, *.ps1)|*.md;*.ps1|All files (*.*)|*.*"
        if ($openFileDialog.ShowDialog() -eq $true) { $dialogUi.ScriptPathTextBox.Text = $openFileDialog.FileName }
    })

    $dialogUi.OkButton.add_Click({ $dialogWindow.DialogResult = $true })
    
    if ($dialogWindow.ShowDialog() -eq $true) {
        $newScriptName = $dialogUi.ScriptNameTextBox.Text
        $newScriptPath = $dialogUi.ScriptPathTextBox.Text
        if ([string]::IsNullOrWhiteSpace($newScriptName) -or ([string]::IsNullOrWhiteSpace($newScriptPath))) {
            Add-OutputLine -Text "Script Name and Path cannot be empty." -Color "Red"; return
        }
        
        [xml]$scriptsXml = Get-Content $ScriptsXmlPath
        $scriptElement = $scriptsXml.CreateElement("script")
        $nameElement = $scriptsXml.CreateElement("name"); $nameElement.InnerText = $newScriptName
        $pathElement = $scriptsXml.CreateElement("path"); $pathElement.InnerText = $newScriptPath
        $scriptElement.AppendChild($nameElement) | Out-Null
        $scriptElement.AppendChild($pathElement) | Out-Null
        $scriptsXml.scripts.AppendChild($scriptElement) | Out-Null
        $scriptsXml.Save($ScriptsXmlPath)
        
        Add-OutputLine -Text "Added script '$newScriptName' to library." -Color "Green"
        Update-ScriptLibraryView
    }
})

$ui.RemoveScriptButton.add_Click({
    $selectedItem = $ui.ScriptLibraryListView.SelectedItem
    if (-not $selectedItem) { Add-OutputLine -Text "Please select a script from the library to remove." -Color "Red"; return }

    [xml]$scriptsXml = Get-Content $ScriptsXmlPath
    $nodeToRemove = $scriptsXml.SelectSingleNode("//script[name='$($selectedItem.Name)' and path='$($selectedItem.Path)']")
    
    if ($nodeToRemove) {
        $nodeToRemove.ParentNode.RemoveChild($nodeToRemove) | Out-Null
        $scriptsXml.Save($ScriptsXmlPath)
        Add-OutputLine -Text "Removed script '$($selectedItem.Name)'." -Color "Green"
        Update-ScriptLibraryView
    } else {
        Add-OutputLine -Text "Could not find the selected script in scripts.xml to remove it." -Color "Red"
    }
})

$ui.ClearConsoleButton.add_Click({ 
    $ui.OutputConsole.Document.Blocks.Clear() 
})
#endregion

#region Application Start
try {
    # The functions here depend on the UI being successfully created.
    Update-ScriptLibraryView
    $ui.ComputerInputTextBox.Text = $env:COMPUTERNAME
    Update-ComputerListView
    Add-OutputLine -Text "Admin Tool Ready. Local hostname pre-filled." -Color "Green"
} catch { 
    # This catch block will now only handle errors from the startup logic itself, not UI creation.
    Add-OutputLine -Text "A critical error occurred during application start: $($_.Exception.Message)" -Color "Red"
}

# Show the main window. The script will wait here until the window is closed.
# The $ui variable should exist at this point, but we check to be safe.
if ($ui.Window) {
    $null = $ui.Window.ShowDialog()
}
#endregion
