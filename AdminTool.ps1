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

#region Constants
# UI Layout and styling constants
$UIConstants = @{
    WindowTitle          = "PowerShell Remote Admin Tool v4.3 (Best Practices)"
    WindowHeight         = 800
    WindowWidth          = 1000
    LeftPanelWidth       = 350
    ComputerListHeight   = 125
    OutputConsoleHeight  = 250
    OutputConsoleMinHeight = 100
    ConsoleFont          = "Consolas"
}

# Color constants for output messages
$ColorConstants = @{
    Success        = "Green"
    Error          = "Red"
    Warning        = "OrangeRed"
    Info           = "Black"
    Highlight      = "Blue"
    Subtle         = "Gray"
    Section        = "DarkBlue"
    UserAction     = "Orange"
}

# Regular expression patterns
$RegexPatterns = @{
    PowerShellCodeBlock = '(?s)```powershell\s*(.*?)\s*```'
    BoldText            = '\*\*(.*?)\*\*'
}

# Supported file extensions for scripts
$SupportedExtensions = @('.ps1', '.md')

# XML and file operation constants
$FileConstants = @{
    ScriptsXmlName        = "scripts.xml"
    RootElement           = "scripts"
    ScriptElement         = "script"
    ScriptNameElement     = "name"
    ScriptPathElement     = "path"
    DefaultXmlContent     = '<scripts></scripts>'
    FileFilterAddScript   = "Supported Scripts (*.md, *.ps1)|*.md;*.ps1|All files (*.*)|*.*"
    FileFilterImport      = "Text Files (*.txt)|*.txt|CSV Files (*.csv)|*.csv|All files (*.*)|*.*"
}
#endregion

#region Helper Functions

function Add-OutputLine {
    <#
    .SYNOPSIS
        Adds a colored line of text to the main output console.
    .DESCRIPTION
        This function safely handles UI updates from any thread by using the window's Dispatcher. 
        It creates a new paragraph in the RichTextBox for each line. The function validates
        the color parameter to prevent WPF color conversion errors.
    .PARAMETER Text
        The string of text to add to the console. Required.
    .PARAMETER Color
        The color of the text as a named color (Red, Green, Black, etc.). Defaults to Black.
        Invalid colors will fall back to Black to prevent UI errors.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Text,

        [ValidateNotNullOrEmpty()]
        [string]$Color = $ColorConstants.Info
    )

    # Validate color by attempting conversion; fall back to black if invalid.
    $validColor = $Color
    try {
        [System.Windows.Media.ColorConverter]::ConvertFromString($validColor) | Out-Null
    }
    catch {
        Write-Verbose "Invalid color '$Color' specified; using default."
        $validColor = $ColorConstants.Info
    }

    # The Dispatcher ensures UI components are updated only on the main UI thread.
    $ui.Window.Dispatcher.Invoke([Action] {
        $paragraph = [System.Windows.Documents.Paragraph]::new()
        $run = [System.Windows.Documents.Run]::new($Text)
        $run.Foreground = [System.Windows.Media.SolidColorBrush]::new(
            [System.Windows.Media.ColorConverter]::ConvertFromString($validColor)
        )
        $paragraph.Inlines.Add($run)
        $ui.OutputConsole.Document.Blocks.Add($paragraph)
        $ui.OutputConsole.ScrollToEnd()
    })
}

function Update-ScriptLibraryView {
    <#
    .SYNOPSIS
        Loads scripts from the scripts.xml file and populates the UI controls.
    .DESCRIPTION
        Reads the scripts.xml file from the script's root directory. If the file doesn't exist,
        it creates a new one. The function then populates the ListView in the "Script Library" tab
        and the ComboBox in the main tab. Handles XML parsing errors gracefully.
    .NOTES
        This function accesses global $ui and $ScriptsXmlPath variables.
    #>
    [CmdletBinding()]
    param()

    try {
        # Create scripts.xml if it doesn't exist.
        if (-not (Test-Path -Path $ScriptsXmlPath)) {
            Add-OutputLine -Text "scripts.xml not found. Creating a new one." -Color $ColorConstants.Warning
            [System.IO.File]::WriteAllText($ScriptsXmlPath, $FileConstants.DefaultXmlContent)
        }

        # Load XML with error handling for malformed files.
        [xml]$scriptsXml = Get-Content -Path $ScriptsXmlPath -ErrorAction Stop

        # Validate that the root element exists.
        if ($null -eq $scriptsXml.DocumentElement) {
            throw "XML file is empty or malformed."
        }

        # Clear existing items to prevent duplication on reload.
        $ui.ScriptLibraryListView.ItemsSource = $null
        $ui.ScriptSelectionComboBox.ItemsSource = $null

        # Build array of script objects from XML nodes.
        $scriptObjects = @()
        foreach ($node in $scriptsXml.scripts.script) {
            # Validate that both name and path are present.
            if ([string]::IsNullOrWhiteSpace($node.name) -or [string]::IsNullOrWhiteSpace($node.path)) {
                Write-Verbose "Skipping script with missing name or path."
                continue
            }

            $scriptObjects += [PSCustomObject]@{
                Name = $node.name
                Path = $node.path
            }
        }

        # Populate UI controls with scripts.
        $ui.ScriptLibraryListView.ItemsSource = $scriptObjects
        $ui.ScriptSelectionComboBox.ItemsSource = $scriptObjects

        # Select the first item if scripts exist.
        if ($scriptObjects.Count -gt 0) {
            $ui.ScriptSelectionComboBox.SelectedIndex = 0
        }

        Update-ScriptDescriptionView
    }
    catch {
        Add-OutputLine -Text "Error loading script library: $($_.Exception.Message)" -Color $ColorConstants.Error
    }
}

function Get-ScriptCodeFromFile {
    <#
    .SYNOPSIS
        Extracts executable PowerShell code from a script file.
    .DESCRIPTION
        For .ps1 files, returns the entire raw content.
        For .md files, extracts the content from the first ```powershell code block using regex.
        Performs validation to ensure the file exists and contains valid PowerShell code.
    .PARAMETER FilePath
        The full path to the .ps1 or .md file. Required.
    .OUTPUTS
        [string] The extracted PowerShell code.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    # Validate file existence.
    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        throw "Script file not found: $FilePath"
    }

    # Validate file extension.
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if ($extension -notin $SupportedExtensions) {
        throw "Unsupported file extension: $extension. Supported: $($SupportedExtensions -join ', ')"
    }

    try {
        $fileContent = Get-Content -Path $FilePath -Raw -ErrorAction Stop
    }
    catch {
        throw "Failed to read script file: $($_.Exception.Message)"
    }

    # For PowerShell files, return content as-is.
    if ($extension -eq '.ps1') {
        return $fileContent
    }

    # For Markdown files, extract PowerShell code block.
    $codeBlockRegex = $RegexPatterns.PowerShellCodeBlock
    $match = [regex]::Match($fileContent, $codeBlockRegex, 'IgnoreCase')

    if ($match.Success) {
        # Extract the code block content (Group 1 is the captured content).
        return $match.Groups[1].Value.Trim()
    }
    else {
        throw "No PowerShell code block found. Expected: \`\`\`powershell...\`\`\`"
    }
}

function Update-ComputerListView {
    <#
    .SYNOPSIS
        Updates the target computer list view from the main input textbox.
    .DESCRIPTION
        Parses comma-separated computer names from ComputerInputTextBox, trims each entry,
        validates against common naming patterns, and populates the ListView.
        The @() wrapper ensures a single computer name is treated as a list with one item.
    .NOTES
        This function accesses the global $ui variable.
    #>
    [CmdletBinding()]
    param()

    try {
        # Split, trim, and filter empty entries.
        $computers = @(
            $ui.ComputerInputTextBox.Text.Split(',') |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        # Validate computer names: must not contain invalid characters.
        # Valid: alphanumeric, hyphens, dots, underscores; 1-253 characters.
        $invalidComputerNames = $computers | Where-Object {
            -not ($_ -match '^[a-zA-Z0-9._-]{1,253}$')
        }

        if ($invalidComputerNames.Count -gt 0) {
            Write-Verbose "Invalid computer names found: $($invalidComputerNames -join ', ')"
        }

        # Update UI with the list (invalid entries still shown for user awareness).
        $ui.ComputerListView.ItemsSource = $computers
    }
    catch {
        Write-Verbose "Error updating computer list view: $($_.Exception.Message)"
    }
}

function Update-ScriptDescriptionView {
    <#
    .SYNOPSIS
        Displays a formatted preview of the selected script file.
    .DESCRIPTION
        Acts as a mini-Markdown renderer for the FlowDocument viewer. Renders headers (#, ##, ###),
        bold text (**text**), and PowerShell code blocks (```powershell...```) with distinct styling.
        For .ps1 files, displays raw code in a code block style. Handles errors gracefully.
    .NOTES
        This function accesses the global $ui variable.
    #>
    [CmdletBinding()]
    param()

    $selectedScript = $ui.ScriptSelectionComboBox.SelectedItem
    $doc = [System.Windows.Documents.FlowDocument]::new()

    # Handle no script selected.
    if ($null -eq $selectedScript) {
        $noScriptRun = [System.Windows.Documents.Run]::new("No script selected.")
        $noScriptPara = [System.Windows.Documents.Paragraph]::new($noScriptRun)
        $doc.Blocks.Add($noScriptPara)
        $ui.ScriptDescriptionViewer.Document = $doc
        return
    }

    try {
        # Validate script file still exists.
        if (-not (Test-Path -Path $selectedScript.Path -PathType Leaf)) {
            throw "Script file no longer exists: $($selectedScript.Path)"
        }

        $fileContent = Get-Content -Path $selectedScript.Path -Raw -ErrorAction Stop

        # Handle .ps1 files: display as code block.
        $extension = [System.IO.Path]::GetExtension($selectedScript.Path).ToLower()
        if ($extension -eq '.ps1') {
            $codeParagraph = [System.Windows.Documents.Paragraph]::new()
            $codeParagraph.FontFamily = $UIConstants.ConsoleFont
            $codeParagraph.Background = [System.Windows.Media.Brushes]::LightGray
            $codeParagraph.Padding = "5"
            $codeParagraph.Inlines.Add([System.Windows.Documents.Run]::new($fileContent))
            $doc.Blocks.Add($codeParagraph)
            $ui.ScriptDescriptionViewer.Document = $doc
            return
        }

        # Handle .md files: parse for formatting.
        $codeBlockRegex = $RegexPatterns.PowerShellCodeBlock
        $codeBlockMatch = [regex]::Match($fileContent, $codeBlockRegex)

        if ($codeBlockMatch.Success) {
            # Extract sections before and after code block.
            $beforeCode = $fileContent.Substring(0, $codeBlockMatch.Index)
            $codeContent = $codeBlockMatch.Groups[1].Value.Trim()
            $afterCode = $fileContent.Substring($codeBlockMatch.Index + $codeBlockMatch.Length)

            # Process markdown before code block.
            Convert-MarkdownToFlowDocument -Content $beforeCode -Document $doc

            # Add formatted code block.
            $codeParagraph = [System.Windows.Documents.Paragraph]::new()
            $codeParagraph.FontFamily = $UIConstants.ConsoleFont
            $codeParagraph.Background = [System.Windows.Media.Brushes]::LightGray
            $codeParagraph.Padding = "5"
            $codeParagraph.Margin = "0,10,0,10"
            $codeParagraph.Inlines.Add([System.Windows.Documents.Run]::new($codeContent))
            $doc.Blocks.Add($codeParagraph)

            # Process markdown after code block.
            Convert-MarkdownToFlowDocument -Content $afterCode -Document $doc
        }
        else {
            # No code block found; treat entire file as markdown.
            Convert-MarkdownToFlowDocument -Content $fileContent -Document $doc
        }
    }
    catch {
        $errorRun = [System.Windows.Documents.Run]::new("Error reading script file: $($_.Exception.Message)")
        $errorRun.Foreground = [System.Windows.Media.Brushes]::Red
        $errorPara = [System.Windows.Documents.Paragraph]::new($errorRun)
        $doc.Blocks.Add($errorPara)
    }

    $ui.ScriptDescriptionViewer.Document = $doc
}

function Convert-MarkdownToFlowDocument {
    <#
    .SYNOPSIS
        Parses a block of Markdown text into formatted FlowDocument elements.
    .DESCRIPTION
        A lightweight Markdown parser that handles:
        - Headers (#, ##, ###) with appropriate font sizes
        - Bold text (**text**) with bold formatting
        - Line-by-line processing to maintain structure
        Not a full Markdown implementation, but covers common use cases for script documentation.
    .PARAMETER Content
        The raw string content to parse. Can be null or empty.
    .PARAMETER Document
        The FlowDocument object to which parsed elements should be added. Required.
    #>
    [CmdletBinding()]
    param(
        [string]$Content = [string]::Empty,
        [Parameter(Mandatory = $true)]
        [System.Windows.Documents.FlowDocument]$Document
    )

    # Return early if content is empty to avoid processing blank lines.
    if ([string]::IsNullOrWhiteSpace($Content)) {
        return
    }

    # Process each line separately to preserve structure.
    $Content.Split([Environment]::NewLine) | ForEach-Object {
        $line = $_
        $paragraph = [System.Windows.Documents.Paragraph]::new()
        $paragraph.Margin = "0"  # Tight spacing between paragraphs

        # Determine header level and adjust formatting.
        if ($line.StartsWith("###")) {
            $paragraph.FontSize = 14
            $paragraph.FontWeight = "Bold"
            $line = $line.Substring(3).Trim()
        }
        elseif ($line.StartsWith("##")) {
            $paragraph.FontSize = 16
            $paragraph.FontWeight = "Bold"
            $line = $line.Substring(2).Trim()
        }
        elseif ($line.StartsWith("#")) {
            $paragraph.FontSize = 20
            $paragraph.FontWeight = "Bold"
            $line = $line.Substring(1).Trim()
        }

        # Parse bold text (**text**) and interleave with normal text.
        $boldRegex = $RegexPatterns.BoldText
        $matches = [regex]::Matches($line, $boldRegex)

        if ($matches.Count -eq 0) {
            # No bold formatting; add line as-is.
            $paragraph.Inlines.Add([System.Windows.Documents.Run]::new($line))
        }
        else {
            # Split line at bold markers and rebuild with formatting.
            $lastIndex = 0
            foreach ($match in $matches) {
                # Add text before the bold section.
                if ($match.Index -gt $lastIndex) {
                    $beforeText = $line.Substring($lastIndex, $match.Index - $lastIndex)
                    $paragraph.Inlines.Add([System.Windows.Documents.Run]::new($beforeText))
                }

                # Add the bold text (Group 1 is the captured content inside **).
                $boldText = $match.Groups[1].Value
                $boldRun = [System.Windows.Documents.Run]::new($boldText)
                $boldRun.FontWeight = "Bold"
                $paragraph.Inlines.Add($boldRun)

                $lastIndex = $match.Index + $match.Length
            }

            # Add any remaining text after the last bold section.
            if ($lastIndex -lt $line.Length) {
                $afterText = $line.Substring($lastIndex)
                $paragraph.Inlines.Add([System.Windows.Documents.Run]::new($afterText))
            }
        }

        $Document.Blocks.Add($paragraph)
    }
}

function New-PSCredentialFromUI {
    <#
    .SYNOPSIS
        Creates a PSCredential object from UI username and password fields.
    .DESCRIPTION
        Checks if both username and password fields are populated in the UI.
        If both are present, creates and returns a PSCredential object.
        If either is empty, returns $null to indicate default credentials should be used.
        
        The PasswordBox control already provides a SecureString, which is more secure
        than ConvertTo-SecureString with -AsPlainText.
    .OUTPUTS
        [System.Management.Automation.PSCredential] or $null if credentials are not provided.
    .NOTES
        This function accesses the global $ui variable.
    #>
    [CmdletBinding()]
    param()

    # Validate that both username and password are provided.
    if ([string]::IsNullOrWhiteSpace($ui.UsernameTextBox.Text)) {
        return $null
    }

    if ($ui.PasswordInputBox.SecurePassword.Length -eq 0) {
        return $null
    }

    try {
        $username = $ui.UsernameTextBox.Text
        $securePassword = $ui.PasswordInputBox.SecurePassword

        Add-OutputLine -Text "Using alternate credentials for user: $username" -Color $ColorConstants.UserAction

        return [System.Management.Automation.PSCredential]::new($username, $securePassword)
    }
    catch {
        Add-OutputLine -Text "Error creating credential object: $($_.Exception.Message)" -Color $ColorConstants.Error
        return $null
    }
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
    $openFileDialog.Filter = $FileConstants.FileFilterImport
    $openFileDialog.Title = "Import Target Computers"

    if ($openFileDialog.ShowDialog() -eq $true) {
        try {
            # Validate file exists before attempting to read.
            if (-not (Test-Path -Path $openFileDialog.FileName -PathType Leaf)) {
                throw "File not found: $($openFileDialog.FileName)"
            }

            # Read and parse computer names from file.
            $computers = @(
                Get-Content -Path $openFileDialog.FileName -ErrorAction Stop |
                ForEach-Object { $_.Trim() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )

            if ($computers.Count -eq 0) {
                Add-OutputLine -Text "No computer names found in the selected file." -Color $ColorConstants.Warning
                return
            }

            # Update UI and provide feedback.
            $ui.ComputerInputTextBox.Text = $computers -join ", "
            Update-ComputerListView
            Add-OutputLine -Text "Successfully imported $($computers.Count) computer(s)." -Color $ColorConstants.Success
        }
        catch {
            Add-OutputLine -Text "Error importing computers: $($_.Exception.Message)" -Color $ColorConstants.Error
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

    # Validate that target computers are specified.
    if (-not $computers -or $computers.Count -eq 0) {
        Add-OutputLine -Text "No target computers specified. Please enter computer names." -Color $ColorConstants.Error
        return
    }

    Add-OutputLine -Text "Starting 'Get Info' operation..." -Color $ColorConstants.Highlight
    $window.Dispatcher.Invoke([Action] {}, "Background")

    # ScriptBlock to gather system information from remote computers.
    $getInfoScriptBlock = {
        try {
            $osInfo = Get-WmiObject -ClassName Win32_OperatingSystem -ErrorAction Stop
            $csInfo = Get-WmiObject -ClassName Win32_ComputerSystem -ErrorAction Stop

            # Calculate uptime from last boot time.
            $bootTime = $osInfo.ConvertToDateTime($osInfo.LastBootUpTime)
            $uptime = (Get-Date) - $bootTime
            $uptimeString = "{0:N0} days, {1:D2}h:{2:D2}m:{3:D2}s" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds

            return [PSCustomObject]@{
                OS     = $osInfo.Caption
                Model  = $csInfo.Model
                Uptime = $uptimeString
            }
        }
        catch {
            throw "Failed to retrieve system info: $_"
        }
    }

    $credential = New-PSCredentialFromUI

    # Build parameters for Invoke-Command.
    $invokeParams = @{
        ScriptBlock = $getInfoScriptBlock
        ErrorAction = 'Stop'
    }
    if ($credential) {
        $invokeParams.Add("Credential", $credential)
    }

    # Query each target computer.
    foreach ($computer in $computers) {
        Add-OutputLine -Text "--- Querying $computer ---" -Color $ColorConstants.Section
        try {
            $invokeParams["ComputerName"] = $computer
            $result = Invoke-Command @invokeParams
            Add-OutputLine -Text "  OS:     $($result.OS)"
            Add-OutputLine -Text "  Model:  $($result.Model)"
            Add-OutputLine -Text "  Uptime: $($result.Uptime)"
        }
        catch {
            Add-OutputLine -Text "  ERROR: $($_.Exception.Message)" -Color $ColorConstants.Error
        }
    }
    Add-OutputLine -Text "--- 'Get Info' operation complete. ---" -Color $ColorConstants.Highlight
})

$ui.RunScriptButton.add_Click({
    $computers = $ui.ComputerListView.ItemsSource
    $selectedScript = $ui.ScriptSelectionComboBox.SelectedItem

    # Validate inputs.
    if (-not $computers -or $computers.Count -eq 0) {
        Add-OutputLine -Text "No target computers specified. Please enter computer names." -Color $ColorConstants.Error
        return
    }
    if (-not $selectedScript) {
        Add-OutputLine -Text "No script selected from the library. Please choose a script." -Color $ColorConstants.Error
        return
    }

    Add-OutputLine -Text "Starting script '$($selectedScript.Name)'..." -Color $ColorConstants.Highlight
    $window.Dispatcher.Invoke([Action] {}, "Background")

    # Extract script code from file.
    try {
        $scriptCode = Get-ScriptCodeFromFile -FilePath $selectedScript.Path
    }
    catch {
        Add-OutputLine -Text "Fatal error reading script file: $($_.Exception.Message)" -Color $ColorConstants.Error
        return
    }

    # Create scriptblock and prepare invocation parameters.
    try {
        $scriptBlockToRun = [scriptblock]::Create($scriptCode)
    }
    catch {
        Add-OutputLine -Text "Fatal error parsing script code: $($_.Exception.Message)" -Color $ColorConstants.Error
        return
    }

    $credential = New-PSCredentialFromUI

    $invokeParams = @{
        ScriptBlock = $scriptBlockToRun
        ErrorAction = 'Stop'
    }
    if ($credential) {
        $invokeParams.Add("Credential", $credential)
    }

    # Execute script on each target computer.
    foreach ($computer in $computers) {
        Add-OutputLine -Text "--- Executing on $computer ---" -Color $ColorConstants.Section
        try {
            $invokeParams["ComputerName"] = $computer
            $output = Invoke-Command @invokeParams

            if ($output) {
                # Format and display output line by line.
                $outputLines = $output | Out-String
                $outputLines.Split("`n") |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object { Add-OutputLine -Text $_.Trim() }
            }
            else {
                Add-OutputLine -Text "(Script executed successfully with no output)" -Color $ColorConstants.Subtle
            }
        }
        catch {
            Add-OutputLine -Text "Remote execution error: $($_.Exception.Message)" -Color $ColorConstants.Error
        }
    }
    Add-OutputLine -Text "--- Script execution complete. ---" -Color $ColorConstants.Highlight
})

$ui.AddScriptButton.add_Click({
    # Load and parse the Add Script dialog XAML.
    try {
        $dialogReader = [System.Xml.XmlNodeReader]::new($AddScriptDialogXAML)
        $dialogWindow = [Windows.Markup.XamlReader]::Load($dialogReader)
    }
    catch {
        Add-OutputLine -Text "Error loading Add Script dialog: $($_.Exception.Message)" -Color $ColorConstants.Error
        return
    }

    # Map dialog controls to hashtable for easy access.
    $dialogUi = @{}
    $AddScriptDialogXAML.SelectNodes("//*[@Name]") |
    ForEach-Object { $dialogUi[$_.Name] = $dialogWindow.FindName($_.Name) }

    $dialogWindow.Owner = $ui.Window

    # Browse button opens file dialog.
    $dialogUi.BrowseButton.add_Click({
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = $FileConstants.FileFilterAddScript
        $openFileDialog.Title = "Select Script File"
        if ($openFileDialog.ShowDialog() -eq $true) {
            $dialogUi.ScriptPathTextBox.Text = $openFileDialog.FileName
        }
    })

    $dialogUi.OkButton.add_Click({ $dialogWindow.DialogResult = $true })

    # Show dialog and process results.
    if ($dialogWindow.ShowDialog() -eq $true) {
        $newScriptName = $dialogUi.ScriptNameTextBox.Text
        $newScriptPath = $dialogUi.ScriptPathTextBox.Text

        # Validate inputs.
        if ([string]::IsNullOrWhiteSpace($newScriptName)) {
            Add-OutputLine -Text "Script name cannot be empty." -Color $ColorConstants.Error
            return
        }
        if ([string]::IsNullOrWhiteSpace($newScriptPath)) {
            Add-OutputLine -Text "Script path cannot be empty." -Color $ColorConstants.Error
            return
        }
        if (-not (Test-Path -Path $newScriptPath -PathType Leaf)) {
            Add-OutputLine -Text "Script file does not exist: $newScriptPath" -Color $ColorConstants.Error
            return
        }

        # Validate file extension.
        $extension = [System.IO.Path]::GetExtension($newScriptPath).ToLower()
        if ($extension -notin $SupportedExtensions) {
            Add-OutputLine -Text "Unsupported file type. Supported: $($SupportedExtensions -join ', ')" -Color $ColorConstants.Error
            return
        }

        # Add script to XML library.
        try {
            [xml]$scriptsXml = Get-Content -Path $ScriptsXmlPath -ErrorAction Stop

            # Check for duplicate script names.
            $existingScript = $scriptsXml.SelectSingleNode("//script[name='$newScriptName']") | Select-Object -First 1
            if ($null -ne $existingScript) {
                Add-OutputLine -Text "A script with the name '$newScriptName' already exists." -Color $ColorConstants.Warning
                return
            }

            # Create and append script element.
            $scriptElement = $scriptsXml.CreateElement($FileConstants.ScriptElement)
            $nameElement = $scriptsXml.CreateElement($FileConstants.ScriptNameElement)
            $nameElement.InnerText = $newScriptName
            $pathElement = $scriptsXml.CreateElement($FileConstants.ScriptPathElement)
            $pathElement.InnerText = $newScriptPath

            $scriptElement.AppendChild($nameElement) | Out-Null
            $scriptElement.AppendChild($pathElement) | Out-Null
            $scriptsXml.DocumentElement.AppendChild($scriptElement) | Out-Null

            $scriptsXml.Save($ScriptsXmlPath)
            Add-OutputLine -Text "Added script '$newScriptName' to library." -Color $ColorConstants.Success
            Update-ScriptLibraryView
        }
        catch {
            Add-OutputLine -Text "Error saving script to library: $($_.Exception.Message)" -Color $ColorConstants.Error
        }
    }
})

$ui.RemoveScriptButton.add_Click({
    $selectedItem = $ui.ScriptLibraryListView.SelectedItem

    # Validate that a script is selected.
    if (-not $selectedItem) {
        Add-OutputLine -Text "Please select a script from the library to remove." -Color $ColorConstants.Error
        return
    }

    try {
        [xml]$scriptsXml = Get-Content -Path $ScriptsXmlPath -ErrorAction Stop

        # XPath to find the exact script node by name and path.
        # Using proper XML escaping to handle special characters in names/paths.
        $nodeToRemove = $scriptsXml.SelectSingleNode(
            "//script[name='$($selectedItem.Name)' and path='$($selectedItem.Path)']"
        )

        if ($null -eq $nodeToRemove) {
            Add-OutputLine -Text "Script not found in library. It may have been removed already." -Color $ColorConstants.Warning
            Update-ScriptLibraryView
            return
        }

        # Remove the node and save.
        $nodeToRemove.ParentNode.RemoveChild($nodeToRemove) | Out-Null
        $scriptsXml.Save($ScriptsXmlPath)

        Add-OutputLine -Text "Removed script '$($selectedItem.Name)' from library." -Color $ColorConstants.Success
        Update-ScriptLibraryView
    }
    catch {
        Add-OutputLine -Text "Error removing script: $($_.Exception.Message)" -Color $ColorConstants.Error
    }
})

$ui.ClearConsoleButton.add_Click({
    # Clear all text blocks from the output console.
    try {
        $ui.OutputConsole.Document.Blocks.Clear()
    }
    catch {
        Write-Verbose "Error clearing console output: $($_.Exception.Message)"
    }
})
#endregion

#region Application Start
try {
    # Initialize the script library from the XML file.
    Update-ScriptLibraryView

    # Pre-fill the computer name field with the local machine hostname.
    $localHostname = $env:COMPUTERNAME
    if ([string]::IsNullOrWhiteSpace($localHostname)) {
        $localHostname = [System.Net.Dns]::GetHostName()
    }
    $ui.ComputerInputTextBox.Text = $localHostname
    Update-ComputerListView

    Add-OutputLine -Text "Admin Tool initialized successfully. Local hostname: $localHostname" -Color $ColorConstants.Success
}
catch {
    Add-OutputLine -Text "Critical error during initialization: $($_.Exception.Message)" -Color $ColorConstants.Error
}

# Display the main window and block until it is closed by the user.
if ($ui.Window) {
    $null = $ui.Window.ShowDialog()
}
#endregion
