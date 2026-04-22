<#
.SYNOPSIS
    Remote PowerShell script runner with a WPF interface.
.DESCRIPTION
    Manages a script library, previews script content, prompts for markdown-defined
    inputs, and runs selected scripts against one or more remote computers.
#>

#region XAML Data
Add-Type -AssemblyName PresentationFramework

$XAML_MainWindow = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerShell Remote Admin Tool" Height="900" Width="1320" MinHeight="780" MinWidth="1120"
        WindowStartupLocation="CenterScreen" Background="#F3F0E8">
    <Window.Resources>
        <SolidColorBrush x:Key="WindowBgBrush" Color="#F3F0E8" />
        <SolidColorBrush x:Key="CardBrush" Color="#FFFDF8" />
        <SolidColorBrush x:Key="CardBorderBrush" Color="#D9D1C5" />
        <SolidColorBrush x:Key="AccentBrush" Color="#1677D1" />
        <SolidColorBrush x:Key="AccentSoftBrush" Color="#DCEBFA" />
        <SolidColorBrush x:Key="MutedBrush" Color="#6B7280" />
        <SolidColorBrush x:Key="ConsoleBgBrush" Color="#171A1F" />
        <SolidColorBrush x:Key="ConsolePanelBrush" Color="#111418" />
        <Style TargetType="TextBox">
            <Setter Property="Margin" Value="0" />
            <Setter Property="Padding" Value="14,12" />
            <Setter Property="FontSize" Value="16" />
            <Setter Property="Background" Value="White" />
            <Setter Property="BorderBrush" Value="#D2D6DC" />
            <Setter Property="BorderThickness" Value="1.5" />
            <Setter Property="Foreground" Value="#1F2937" />
        </Style>
        <Style TargetType="PasswordBox">
            <Setter Property="Margin" Value="0" />
            <Setter Property="Padding" Value="14,12" />
            <Setter Property="FontSize" Value="16" />
            <Setter Property="Background" Value="White" />
            <Setter Property="BorderBrush" Value="#D2D6DC" />
            <Setter Property="BorderThickness" Value="1.5" />
            <Setter Property="Foreground" Value="#1F2937" />
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Margin" Value="0" />
            <Setter Property="Padding" Value="12,10" />
            <Setter Property="FontSize" Value="16" />
            <Setter Property="Background" Value="White" />
            <Setter Property="BorderBrush" Value="#D2D6DC" />
            <Setter Property="BorderThickness" Value="1.5" />
            <Setter Property="Foreground" Value="#111827" />
        </Style>
        <Style x:Key="PrimaryButtonStyle" TargetType="Button">
            <Setter Property="Foreground" Value="White" />
            <Setter Property="Background" Value="{StaticResource AccentBrush}" />
            <Setter Property="BorderBrush" Value="{StaticResource AccentBrush}" />
            <Setter Property="BorderThickness" Value="0" />
            <Setter Property="Padding" Value="16,12" />
            <Setter Property="FontSize" Value="16" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="16">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}" />
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButtonStyle" TargetType="Button" BasedOn="{StaticResource PrimaryButtonStyle}">
            <Setter Property="Foreground" Value="#1F2937" />
            <Setter Property="Background" Value="#F7F3EB" />
            <Setter Property="BorderBrush" Value="#D5D0C7" />
            <Setter Property="BorderThickness" Value="1.5" />
        </Style>
        <Style x:Key="GhostButtonStyle" TargetType="Button" BasedOn="{StaticResource PrimaryButtonStyle}">
            <Setter Property="Foreground" Value="#4B5563" />
            <Setter Property="Background" Value="#F7F3EB" />
            <Setter Property="BorderBrush" Value="#D5D0C7" />
            <Setter Property="BorderThickness" Value="1.5" />
        </Style>
        <Style x:Key="ConsoleButtonStyle" TargetType="Button" BasedOn="{StaticResource PrimaryButtonStyle}">
            <Setter Property="Foreground" Value="#E5E7EB" />
            <Setter Property="Background" Value="#1C222A" />
            <Setter Property="BorderBrush" Value="#2A323D" />
            <Setter Property="BorderThickness" Value="1.5" />
            <Setter Property="Padding" Value="14,10" />
        </Style>
        <Style TargetType="TabControl">
            <Setter Property="Background" Value="Transparent" />
            <Setter Property="BorderThickness" Value="0" />
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="FontSize" Value="18" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Foreground" Value="#4B5563" />
            <Setter Property="Padding" Value="22,16" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="TabBorder" Background="Transparent" BorderBrush="Transparent" BorderThickness="0,0,0,3" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" ContentSource="Header" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="TabBorder" Property="BorderBrush" Value="{StaticResource AccentBrush}" />
                                <Setter Property="Foreground" Value="{StaticResource AccentBrush}" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SectionHeadingStyle" TargetType="TextBlock">
            <Setter Property="FontSize" Value="18" />
            <Setter Property="TextWrapping" Value="Wrap" />
            <Setter Property="Foreground" Value="#3F3F46" />
            <Setter Property="Margin" Value="0,0,0,14" />
        </Style>
    </Window.Resources>
    <Border Margin="10" Background="{StaticResource WindowBgBrush}" BorderBrush="#CFC4B5" BorderThickness="1" CornerRadius="28" SnapsToDevicePixels="True">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="88" />
            <RowDefinition Height="*" />
            <RowDefinition Height="10" />
            <RowDefinition Height="320" MinHeight="180" />
        </Grid.RowDefinitions>
        <Border Grid.Row="0" Background="#FBFAF6" BorderBrush="#D8D1C5" BorderThickness="0,0,0,1" CornerRadius="28,28,0,0">
            <Grid Margin="22,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*" />
                    <ColumnDefinition Width="Auto" />
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Width="44" Height="44" Background="{StaticResource AccentBrush}" CornerRadius="12">
                        <TextBlock Text="PS" Foreground="White" FontSize="18" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Border>
                    <StackPanel Margin="14,0,0,0" VerticalAlignment="Center">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="PowerShell Admin Tool" FontSize="24" FontWeight="SemiBold" Foreground="#222222" />
                            <TextBlock Text="v4.3" FontSize="18" Foreground="#7A7A7A" Margin="18,2,0,0" />
                        </StackPanel>
                        <TextBlock Text="Remote response and script triage workspace" FontSize="13" Foreground="#7C838F" Margin="0,4,0,0" />
                    </StackPanel>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Ellipse Width="24" Height="24" Fill="#F6A11A" Margin="0,0,10,0" />
                    <Ellipse Width="24" Height="24" Fill="#77A627" Margin="0,0,10,0" />
                    <Ellipse Width="24" Height="24" Fill="#E84D48" />
                </StackPanel>
            </Grid>
        </Border>
        <Grid Grid.Row="1" Margin="0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="470" />
                <ColumnDefinition Width="*" />
            </Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="#FAF8F3" BorderBrush="#D8D1C5" BorderThickness="0,0,1,0">
                <TabControl Name="MainTabControl">
                    <TabItem Header="Remote target">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel Margin="26">
                                <TextBlock Text="TARGET COMPUTERS" Style="{StaticResource SectionHeadingStyle}" />
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*" />
                                        <ColumnDefinition Width="110" />
                                    </Grid.ColumnDefinitions>
                                    <TextBox Name="ComputerInputTextBox" ToolTip="Enter computer names separated by commas, semicolons, or new lines." Height="56" />
                                    <Button Name="AddComputerButton" Grid.Column="1" Content="Add" Style="{StaticResource SecondaryButtonStyle}" Height="56" Margin="12,0,0,0" />
                                </Grid>
                                <Border Background="#F8F5EE" BorderBrush="#D8D1C5" BorderThickness="1.5" CornerRadius="18" Padding="12" Margin="0,14,0,0">
                                    <Grid>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="*" />
                                            <RowDefinition Height="Auto" />
                                        </Grid.RowDefinitions>
                                        <ListView Name="ComputerListView" Height="160" SelectionMode="Multiple" BorderThickness="0" Background="Transparent" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                                            <ListView.ItemContainerStyle>
                                                <Style TargetType="ListViewItem">
                                                    <Setter Property="Padding" Value="0" />
                                                    <Setter Property="Margin" Value="0,0,0,10" />
                                                    <Setter Property="BorderThickness" Value="0" />
                                                    <Setter Property="Background" Value="Transparent" />
                                                </Style>
                                            </ListView.ItemContainerStyle>
                                            <ListView.ItemTemplate>
                                                <DataTemplate>
                                                    <Border Background="White" BorderBrush="#D7DCE3" BorderThickness="1.5" CornerRadius="16" Padding="16,12">
                                                        <StackPanel Orientation="Horizontal">
                                                            <Ellipse Width="12" Height="12" Fill="#6B9D2D" Margin="0,4,12,0" />
                                                            <TextBlock Text="{Binding}" FontFamily="Consolas" FontSize="15" Foreground="#1F2937" />
                                                        </StackPanel>
                                                    </Border>
                                                </DataTemplate>
                                            </ListView.ItemTemplate>
                                        </ListView>
                                        <TextBlock Name="ComputerSummaryTextBlock" Grid.Row="1" Margin="4,6,4,0" Foreground="#6B7280" Text="No target computers loaded." TextWrapping="Wrap" />
                                    </Grid>
                                </Border>
                                <Button Name="ImportFromFileButton" Content="+ Import from file (.txt / .csv)" Style="{StaticResource GhostButtonStyle}" Margin="0,16,0,0" />

                                <TextBlock Text="ALTERNATE CREDENTIALS" Style="{StaticResource SectionHeadingStyle}" Margin="0,34,0,14" />
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto" />
                                        <RowDefinition Height="Auto" />
                                    </Grid.RowDefinitions>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="140" />
                                        <ColumnDefinition Width="*" />
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="Username" VerticalAlignment="Center" FontSize="18" Foreground="#424242" Margin="0,0,14,0" />
                                    <TextBox Grid.Column="1" Name="UsernameTextBox" Height="54" />
                                    <TextBlock Grid.Row="1" Text="Password" VerticalAlignment="Center" FontSize="18" Foreground="#424242" Margin="0,18,14,0" />
                                    <PasswordBox Grid.Row="1" Grid.Column="1" Name="PasswordInputBox" Height="54" Margin="0,18,0,0" />
                                </Grid>

                                <TextBlock Text="SELECT SCRIPT" Style="{StaticResource SectionHeadingStyle}" Margin="0,34,0,14" />
                                <ComboBox Name="ScriptSelectionComboBox" DisplayMemberPath="Name" Height="58" />
                                <TextBlock Name="ScriptSummaryTextBlock" Margin="2,12,2,0" Foreground="#6B7280" TextWrapping="Wrap" Text="No script selected." />
                                <Button Name="GetInfoButton" Content="Get info" Style="{StaticResource SecondaryButtonStyle}" Margin="0,22,0,0" />
                                <Button Name="RunScriptButton" Content="Run selected script" Style="{StaticResource PrimaryButtonStyle}" Margin="0,12,0,0" />
                            </StackPanel>
                        </ScrollViewer>
                    </TabItem>
                    <TabItem Header="Script library">
                        <Grid Margin="24">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto" />
                                <RowDefinition Height="*" />
                                <RowDefinition Height="Auto" />
                            </Grid.RowDefinitions>
                            <TextBlock Text="SCRIPT LIBRARY" Style="{StaticResource SectionHeadingStyle}" />
                            <Border Grid.Row="1" Background="White" BorderBrush="#D8D1C5" BorderThickness="1.5" CornerRadius="18" Padding="10">
                                <ListView Name="ScriptLibraryListView" BorderThickness="0" Background="Transparent">
                                    <ListView.View>
                                        <GridView>
                                            <GridViewColumn Header="Script Name" Width="180" DisplayMemberBinding="{Binding Name}" />
                                            <GridViewColumn Header="File Path" Width="210" DisplayMemberBinding="{Binding Path}" />
                                        </GridView>
                                    </ListView.View>
                                </ListView>
                            </Border>
                            <Grid Grid.Row="2" Margin="0,16,0,0">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*" />
                                    <ColumnDefinition Width="*" />
                                </Grid.ColumnDefinitions>
                                <Button Name="AddScriptButton" Grid.Column="0" Content="Add new script..." Style="{StaticResource SecondaryButtonStyle}" />
                                <Button Name="RemoveScriptButton" Grid.Column="1" Content="Remove selected" Style="{StaticResource GhostButtonStyle}" Margin="12,0,0,0" />
                            </Grid>
                        </Grid>
                    </TabItem>
                </TabControl>
            </Border>
            <Border Grid.Column="1" Background="#FFFDF9">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="84" />
                        <RowDefinition Height="*" />
                    </Grid.RowDefinitions>
                    <Border Grid.Row="0" BorderBrush="#D8D1C5" BorderThickness="0,0,0,1" Background="#FBFAF6">
                        <Grid Margin="28,0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*" />
                                <ColumnDefinition Width="Auto" />
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="SCRIPT PREVIEW" VerticalAlignment="Center" FontSize="20" Foreground="#3F3F46" />
                            <Border Name="PreviewBadgeBorder" Grid.Column="1" Background="#DCEBFA" CornerRadius="18" Padding="16,8" VerticalAlignment="Center">
                                <TextBlock Name="PreviewBadgeTextBlock" Foreground="#0B5CAD" FontSize="14" FontWeight="SemiBold" Text="No script selected" />
                            </Border>
                        </Grid>
                    </Border>
                    <FlowDocumentScrollViewer Grid.Row="1" Name="ScriptDescriptionViewer" Padding="28,26,28,16" IsToolBarVisible="False" VerticalScrollBarVisibility="Auto" />
                </Grid>
            </Border>
        </Grid>
        <GridSplitter Grid.Row="2" Height="10" HorizontalAlignment="Stretch" Background="Transparent" />
        <Border Grid.Row="3" Background="{StaticResource ConsolePanelBrush}" CornerRadius="0,0,28,28">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="94" />
                    <RowDefinition Height="*" />
                    <RowDefinition Height="Auto" />
                </Grid.RowDefinitions>
                <Border Grid.Row="0" Background="{StaticResource ConsolePanelBrush}" BorderBrush="#2A2F37" BorderThickness="0,0,0,1">
                    <Grid Margin="28,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*" />
                            <ColumnDefinition Width="Auto" />
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="OUTPUT CONSOLE" VerticalAlignment="Center" FontSize="18" Foreground="#8B9098" />
                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <Button Name="ClearConsoleButton" Content="Clear" Style="{StaticResource ConsoleButtonStyle}" />
                            <Button Name="CopyConsoleButton" Content="Copy all" Style="{StaticResource ConsoleButtonStyle}" Margin="12,0,0,0" />
                        </StackPanel>
                    </Grid>
                </Border>
                <RichTextBox Name="OutputConsole" Grid.Row="1" Margin="22,18,22,16" IsReadOnly="True" VerticalScrollBarVisibility="Auto" FontFamily="Consolas" Background="{StaticResource ConsoleBgBrush}" BorderThickness="0" Foreground="#E5E7EB" />
                <Border Grid.Row="2" Margin="22,0,22,18" Padding="10,10" Background="#1C222A" BorderBrush="#2A323D" BorderThickness="1" CornerRadius="14">
                    <DockPanel>
                        <TextBlock Name="BusyStateTextBlock" DockPanel.Dock="Right" Foreground="#9AD1FF" FontWeight="Bold" Text="Idle" />
                        <TextBlock Name="StatusTextBlock" Foreground="#AAB2BE" Text="Ready." TextWrapping="Wrap" />
                    </DockPanel>
                </Border>
            </Grid>
        </Grid>
    </Grid>
    </Border>
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
    WindowTitle          = "PowerShell Remote Admin Tool"
    WindowHeight         = 900
    WindowWidth          = 1320
    LeftPanelWidth       = 470
    ComputerListHeight   = 160
    OutputConsoleHeight  = 320
    OutputConsoleMinHeight = 180
    ConsoleFont          = "Consolas"
}

# Color constants for output messages
$ColorConstants = @{
    Success        = "#5EEAD4"
    Error          = "#F87171"
    Warning        = "#FBBF24"
    Info           = "#E5E7EB"
    Highlight      = "#7DD3FC"
    Subtle         = "#9CA3AF"
    Section        = "#93C5FD"
    UserAction     = "#FDBA74"
}

$script:IsUiBusy = $false

# Regular expression patterns
$RegexPatterns = @{
    PowerShellCodeBlock = '(?s)```powershell\s*(.*?)\s*```'
    ScriptInputBlock    = '(?s)```script-inputs\s*(.*?)\s*```'
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
        Uses the UI dispatcher to append a colored line to the output console.
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

    $validColor = $Color
    try {
        [System.Windows.Media.ColorConverter]::ConvertFromString($validColor) | Out-Null
    }
    catch {
        Write-Verbose "Invalid color '$Color' specified; using default."
        $validColor = $ColorConstants.Info
    }

    $ui.Window.Dispatcher.Invoke([Action] {
        $paragraph = [System.Windows.Documents.Paragraph]::new()
        $paragraph.Margin = "0,0,0,4"
        $run = [System.Windows.Documents.Run]::new($Text)
        $run.Foreground = [System.Windows.Media.SolidColorBrush]::new(
            [System.Windows.Media.ColorConverter]::ConvertFromString($validColor)
        )
        $paragraph.Inlines.Add($run)
        $ui.OutputConsole.Document.Blocks.Add($paragraph)
        $ui.OutputConsole.ScrollToEnd()
        Update-ActionState
    })
}

function Update-ScriptLibraryView {
    <#
    .SYNOPSIS
        Loads scripts from the scripts.xml file and populates the UI controls.
    .DESCRIPTION
        Loads scripts from `scripts.xml` and refreshes the bound UI controls.
    #>
    [CmdletBinding()]
    param()

    try {
        if (-not (Test-Path -Path $ScriptsXmlPath)) {
            Add-OutputLine -Text "scripts.xml not found. Creating a new one." -Color $ColorConstants.Warning
            [System.IO.File]::WriteAllText($ScriptsXmlPath, $FileConstants.DefaultXmlContent)
        }

        [xml]$scriptsXml = Get-Content -Path $ScriptsXmlPath -ErrorAction Stop

        if ($null -eq $scriptsXml.DocumentElement) {
            throw "XML file is empty or malformed."
        }

        $ui.ScriptLibraryListView.ItemsSource = $null
        $ui.ScriptSelectionComboBox.ItemsSource = $null

        $scriptObjects = @()
        foreach ($node in $scriptsXml.scripts.script) {
            if ([string]::IsNullOrWhiteSpace($node.name) -or [string]::IsNullOrWhiteSpace($node.path)) {
                Write-Verbose "Skipping script with missing name or path."
                continue
            }

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
        Update-ActionState
    }
    catch {
        Add-OutputLine -Text "Error loading script library: $($_.Exception.Message)" -Color $ColorConstants.Error
    }
}

function Set-StatusMessage {
    <#
    .SYNOPSIS
        Updates the status message displayed in the footer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [string]$Color = $ColorConstants.Subtle
    )

    $brush = [System.Windows.Media.Brushes]::DimGray
    try {
        $brush = [System.Windows.Media.SolidColorBrush]::new(
            [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
        )
    }
    catch {
        $brush = [System.Windows.Media.Brushes]::DimGray
    }

    $ui.StatusTextBlock.Text = $Text
    $ui.StatusTextBlock.Foreground = $brush
}

function Set-PreviewBadge {
    <#
    .SYNOPSIS
        Updates the preview badge shown in the preview pane header.
    #>
    [CmdletBinding()]
    param(
        [string]$Text = "No script selected",
        [string]$Background = "#E8EEF5",
        [string]$Foreground = "#0B5CAD"
    )

    $backgroundBrush = [System.Windows.Media.Brushes]::LightGray
    $foregroundBrush = [System.Windows.Media.Brushes]::DarkBlue

    try {
        $backgroundBrush = [System.Windows.Media.SolidColorBrush]::new(
            [System.Windows.Media.ColorConverter]::ConvertFromString($Background)
        )
        $foregroundBrush = [System.Windows.Media.SolidColorBrush]::new(
            [System.Windows.Media.ColorConverter]::ConvertFromString($Foreground)
        )
    }
    catch {
        $backgroundBrush = [System.Windows.Media.Brushes]::LightGray
        $foregroundBrush = [System.Windows.Media.Brushes]::DarkBlue
    }

    $ui.PreviewBadgeTextBlock.Text = $Text
    $ui.PreviewBadgeBorder.Background = $backgroundBrush
    $ui.PreviewBadgeTextBlock.Foreground = $foregroundBrush
}

function Set-ApplicationBusy {
    <#
    .SYNOPSIS
        Toggles busy state for long-running operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$IsBusy,
        [string]$Message = "Ready."
    )

    $script:IsUiBusy = $IsBusy
    $ui.BusyStateTextBlock.Text = if ($IsBusy) { "Working..." } else { "Idle" }
    [System.Windows.Input.Mouse]::OverrideCursor = if ($IsBusy) {
        [System.Windows.Input.Cursors]::Wait
    }
    else {
        $null
    }

    Set-StatusMessage -Text $Message -Color $(if ($IsBusy) { $ColorConstants.Highlight } else { $ColorConstants.Subtle })
    Update-ActionState
}

function Get-NormalizedComputerList {
    <#
    .SYNOPSIS
        Splits and de-duplicates computer names from free-form text input.
    #>
    [CmdletBinding()]
    param(
        [string]$Text = [string]::Empty
    )

    $seen = @{}
    $computers = New-Object System.Collections.Generic.List[string]

    foreach ($entry in ($Text -split '[,\r\n;]+')) {
        $computerName = $entry.Trim()
        if ([string]::IsNullOrWhiteSpace($computerName)) {
            continue
        }

        if (-not $seen.ContainsKey($computerName)) {
            $seen[$computerName] = $true
            $computers.Add($computerName)
        }
    }

    return @($computers)
}

function Update-ActionState {
    <#
    .SYNOPSIS
        Keeps button enabled states in sync with the current UI selections.
    #>
    [CmdletBinding()]
    param()

    $computerCount = @($ui.ComputerListView.ItemsSource).Count
    $hasScript = $null -ne $ui.ScriptSelectionComboBox.SelectedItem
    $hasLibrarySelection = $null -ne $ui.ScriptLibraryListView.SelectedItem

    $ui.ImportFromFileButton.IsEnabled = -not $script:IsUiBusy
    $ui.AddScriptButton.IsEnabled = -not $script:IsUiBusy
    $ui.ClearConsoleButton.IsEnabled = -not $script:IsUiBusy
    $ui.ScriptSelectionComboBox.IsEnabled = -not $script:IsUiBusy
    $ui.GetInfoButton.IsEnabled = (-not $script:IsUiBusy) -and $computerCount -gt 0
    $ui.RunScriptButton.IsEnabled = (-not $script:IsUiBusy) -and $computerCount -gt 0 -and $hasScript
    $ui.RemoveScriptButton.IsEnabled = (-not $script:IsUiBusy) -and $hasLibrarySelection
    $ui.AddComputerButton.IsEnabled = -not $script:IsUiBusy
    $ui.CopyConsoleButton.IsEnabled = $ui.OutputConsole.Document.Blocks.Count -gt 0
}

function New-CodePreviewParagraph {
    <#
    .SYNOPSIS
        Creates a styled paragraph for code preview blocks.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $paragraph = [System.Windows.Documents.Paragraph]::new()
    $paragraph.FontFamily = $UIConstants.ConsoleFont
    $paragraph.FontSize = 15
    $paragraph.Background = [System.Windows.Media.SolidColorBrush]::new(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#1F2329")
    )
    $paragraph.Foreground = [System.Windows.Media.SolidColorBrush]::new(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E5E7EB")
    )
    $paragraph.Padding = "18"
    $paragraph.Margin = "0,18,0,18"
    $paragraph.LineHeight = 24
    $paragraph.Inlines.Add([System.Windows.Documents.Run]::new($Content))

    return $paragraph
}

function Resolve-ScriptLibraryPath {
    <#
    .SYNOPSIS
        Resolves a library path to an absolute file system path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Script path is empty."
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $ScriptPath -ChildPath $Path))
}

function Get-ScriptInputDefinitionsFromContent {
    <#
    .SYNOPSIS
        Reads script input metadata from markdown content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $match = [regex]::Match($Content, $RegexPatterns.ScriptInputBlock, 'IgnoreCase')
    if (-not $match.Success) {
        return @()
    }

    try {
        $definitions = $match.Groups[1].Value | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Invalid script input definition block: $($_.Exception.Message)"
    }

    $normalizedDefinitions = @()
    foreach ($definition in @($definitions)) {
        if ([string]::IsNullOrWhiteSpace($definition.Name)) {
            throw "Every script input must include a Name property."
        }

        $inputType = [string]$definition.Type
        if ([string]::IsNullOrWhiteSpace($inputType)) {
            $inputType = 'text'
        }

        $normalizedDefinitions += [PSCustomObject]@{
            Name        = [string]$definition.Name
            Label       = if ([string]::IsNullOrWhiteSpace($definition.Label)) { [string]$definition.Name } else { [string]$definition.Label }
            Type        = $inputType.ToLower()
            Required    = [bool]$definition.Required
            Default     = $definition.Default
            Help        = [string]$definition.Help
            Placeholder = [string]$definition.Placeholder
            Options     = @($definition.Options)
        }
    }

    return $normalizedDefinitions
}

function Remove-ScriptInputBlock {
    <#
    .SYNOPSIS
        Removes the custom script input metadata block from markdown content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    return ([regex]::Replace($Content, $RegexPatterns.ScriptInputBlock, '', 'IgnoreCase')).Trim()
}

function Get-ScriptInputDefinitions {
    <#
    .SYNOPSIS
        Loads input definitions for a script file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $resolvedPath = Resolve-ScriptLibraryPath -Path $FilePath
    if ([System.IO.Path]::GetExtension($resolvedPath).ToLower() -ne '.md') {
        return @()
    }

    $content = Get-Content -Path $resolvedPath -Raw -ErrorAction Stop
    return @(Get-ScriptInputDefinitionsFromContent -Content $content)
}

function Test-ScriptFileIsRunnable {
    <#
    .SYNOPSIS
        Checks whether a script file can be executed by the app.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    try {
        $resolvedPath = Resolve-ScriptLibraryPath -Path $FilePath
    }
    catch {
        return $false
    }

    if (-not (Test-Path -Path $resolvedPath -PathType Leaf)) {
        return $false
    }

    $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLower()
    if ($extension -eq '.ps1') {
        return $true
    }

    if ($extension -ne '.md') {
        return $false
    }

    try {
        $content = Get-Content -Path $resolvedPath -Raw -ErrorAction Stop
        return [regex]::IsMatch((Remove-ScriptInputBlock -Content $content), $RegexPatterns.PowerShellCodeBlock, 'IgnoreCase')
    }
    catch {
        return $false
    }
}

function Auto-DiscoverScripts {
    <#
    .SYNOPSIS
        Adds scripts from the local Scripts directory to the library if missing.
    .DESCRIPTION
        Scans the repository's Scripts directory for supported script files and appends
        any missing entries to scripts.xml. Existing entries are matched by resolved file path
        so relative and absolute paths do not get duplicated.
    #>
    [CmdletBinding()]
    param()

    $scriptsDirectory = Join-Path -Path $ScriptPath -ChildPath "Scripts"

    if (-not (Test-Path -Path $scriptsDirectory -PathType Container)) {
        return
    }

    try {
        if (-not (Test-Path -Path $ScriptsXmlPath -PathType Leaf)) {
            [System.IO.File]::WriteAllText($ScriptsXmlPath, $FileConstants.DefaultXmlContent)
        }

        [xml]$scriptsXml = Get-Content -Path $ScriptsXmlPath -ErrorAction Stop
        $updated = $false
        $existingPaths = @()

        foreach ($node in @($scriptsXml.scripts.script)) {
            if ([string]::IsNullOrWhiteSpace($node.path)) {
                continue
            }

            try {
                $existingPaths += Resolve-ScriptLibraryPath -Path $node.path
            }
            catch {
                $existingPaths += $node.path
            }
        }

        foreach ($file in Get-ChildItem -Path $scriptsDirectory -File) {
            if ([System.IO.Path]::GetExtension($file.FullName).ToLower() -notin $SupportedExtensions) {
                continue
            }

            $discoveredPath = Join-Path -Path 'Scripts' -ChildPath $file.Name
            if (-not (Test-ScriptFileIsRunnable -FilePath $discoveredPath)) {
                continue
            }

            $resolvedPath = Resolve-ScriptLibraryPath -Path $discoveredPath
            if ($resolvedPath -in $existingPaths) {
                continue
            }

            $scriptElement = $scriptsXml.CreateElement($FileConstants.ScriptElement)
            $nameElement = $scriptsXml.CreateElement($FileConstants.ScriptNameElement)
            $nameElement.InnerText = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $pathElement = $scriptsXml.CreateElement($FileConstants.ScriptPathElement)
            $pathElement.InnerText = $discoveredPath

            $scriptElement.AppendChild($nameElement) | Out-Null
            $scriptElement.AppendChild($pathElement) | Out-Null
            $scriptsXml.DocumentElement.AppendChild($scriptElement) | Out-Null

            $existingPaths += $resolvedPath
            $updated = $true
        }

        if ($updated) {
            $scriptsXml.Save($ScriptsXmlPath)
        }
    }
    catch {
        Add-OutputLine -Text "Error during script auto-discovery: $($_.Exception.Message)" -Color $ColorConstants.Error
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

    $resolvedPath = Resolve-ScriptLibraryPath -Path $FilePath

    # Validate file existence.
    if (-not (Test-Path -Path $resolvedPath -PathType Leaf)) {
        throw "Script file not found: $resolvedPath"
    }

    # Validate file extension.
    $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLower()
    if ($extension -notin $SupportedExtensions) {
        throw "Unsupported file extension: $extension. Supported: $($SupportedExtensions -join ', ')"
    }

    try {
        $fileContent = Get-Content -Path $resolvedPath -Raw -ErrorAction Stop
    }
    catch {
        throw "Failed to read script file: $($_.Exception.Message)"
    }

    # For PowerShell files, return content as-is.
    if ($extension -eq '.ps1') {
        return $fileContent
    }

    $fileContent = Remove-ScriptInputBlock -Content $fileContent

    # For Markdown files, extract PowerShell code block.
    $codeBlockRegex = $RegexPatterns.PowerShellCodeBlock
    $match = [regex]::Match($fileContent, $codeBlockRegex, 'IgnoreCase')

    if ($match.Success) {
        # Extract the code block content (Group 1 is the captured content).
        return $match.Groups[1].Value.Trim()
    }
    else {
        throw 'No PowerShell code block found. Expected: ```powershell...```'
    }
}

function Add-ScriptInputSummaryToDocument {
    <#
    .SYNOPSIS
        Renders script input definitions inside the preview pane.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$InputDefinitions,
        [Parameter(Mandatory = $true)]
        [System.Windows.Documents.FlowDocument]$Document
    )

    if ($InputDefinitions.Count -eq 0) {
        return
    }

    $heading = [System.Windows.Documents.Paragraph]::new()
    $heading.Margin = "0,10,0,4"
    $heading.FontSize = 16
    $heading.FontWeight = "Bold"
    $heading.Inlines.Add([System.Windows.Documents.Run]::new("Inputs"))
    $Document.Blocks.Add($heading)

    foreach ($definition in $InputDefinitions) {
        $parts = @()
        $parts += $definition.Label
        $parts += "[$($definition.Type)]"

        if ($definition.Required) {
            $parts += "required"
        }
        else {
            $parts += "optional"
        }

        if ($null -ne $definition.Default -and -not [string]::IsNullOrWhiteSpace([string]$definition.Default)) {
            $parts += "default: $($definition.Default)"
        }

        $paragraph = [System.Windows.Documents.Paragraph]::new()
        $paragraph.Margin = "0"
        $paragraph.Inlines.Add([System.Windows.Documents.Run]::new("- " + ($parts -join " | ")))
        $Document.Blocks.Add($paragraph)

        if (-not [string]::IsNullOrWhiteSpace($definition.Help)) {
            $helpParagraph = [System.Windows.Documents.Paragraph]::new()
            $helpParagraph.Margin = "10,0,0,4"
            $helpParagraph.Foreground = [System.Windows.Media.Brushes]::DimGray
            $helpParagraph.Inlines.Add([System.Windows.Documents.Run]::new($definition.Help))
            $Document.Blocks.Add($helpParagraph)
        }
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
    #>
    [CmdletBinding()]
    param()

    try {
        $computers = @(Get-NormalizedComputerList -Text $ui.ComputerInputTextBox.Text)

        # Validate computer names: must not contain invalid characters.
        # Valid: alphanumeric, hyphens, dots, underscores; 1-253 characters.
        $invalidComputerNames = @($computers | Where-Object {
            -not ($_ -match '^[a-zA-Z0-9._-]{1,253}$')
        })

        if ($invalidComputerNames.Count -gt 0) {
            Write-Verbose "Invalid computer names found: $($invalidComputerNames -join ', ')"
        }

        # Update UI with the list (invalid entries still shown for user awareness).
        $ui.ComputerListView.ItemsSource = $computers

        if ($computers.Count -eq 0) {
            $ui.ComputerSummaryTextBlock.Text = "No target computers loaded."
            $ui.ComputerSummaryTextBlock.Foreground = [System.Windows.Media.Brushes]::DimGray
        }
        elseif ($invalidComputerNames.Count -gt 0) {
            $ui.ComputerSummaryTextBlock.Text = "$($computers.Count) target(s) loaded, $($invalidComputerNames.Count) invalid name(s) still need attention."
            $ui.ComputerSummaryTextBlock.Foreground = [System.Windows.Media.Brushes]::OrangeRed
        }
        else {
            $ui.ComputerSummaryTextBlock.Text = "$($computers.Count) unique target computer(s) ready."
            $ui.ComputerSummaryTextBlock.Foreground = [System.Windows.Media.Brushes]::DimGray
        }

        Update-ActionState
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
    #>
    [CmdletBinding()]
    param()

    $selectedScript = $ui.ScriptSelectionComboBox.SelectedItem
    $doc = [System.Windows.Documents.FlowDocument]::new()
    $doc.PagePadding = "0"
    $doc.FontFamily = "Segoe UI"
    $doc.FontSize = 18
    $doc.Foreground = [System.Windows.Media.SolidColorBrush]::new(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2A2A2A")
    )

    # Handle no script selected.
    if ($null -eq $selectedScript) {
        $noScriptRun = [System.Windows.Documents.Run]::new("No script selected.")
        $noScriptPara = [System.Windows.Documents.Paragraph]::new($noScriptRun)
        $noScriptPara.Foreground = [System.Windows.Media.Brushes]::DimGray
        $doc.Blocks.Add($noScriptPara)
        $ui.ScriptDescriptionViewer.Document = $doc
        $ui.ScriptSummaryTextBlock.Text = "No script selected."
        $ui.ScriptSummaryTextBlock.Foreground = [System.Windows.Media.Brushes]::DimGray
        Set-PreviewBadge -Text "No script selected" -Background "#E8EEF5" -Foreground "#60758D"
        Update-ActionState
        return
    }

    try {
        # Validate script file still exists.
        $resolvedPath = Resolve-ScriptLibraryPath -Path $selectedScript.Path
        if (-not (Test-Path -Path $resolvedPath -PathType Leaf)) {
            throw "Script file no longer exists: $resolvedPath"
        }

        $fileContent = Get-Content -Path $resolvedPath -Raw -ErrorAction Stop

        # Handle .ps1 files: display as code block.
        $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLower()
        if ($extension -eq '.ps1') {
            $codeParagraph = New-CodePreviewParagraph -Content $fileContent
            $doc.Blocks.Add($codeParagraph)
            $ui.ScriptDescriptionViewer.Document = $doc
            $ui.ScriptSummaryTextBlock.Text = "PowerShell script | $resolvedPath"
            $ui.ScriptSummaryTextBlock.Foreground = [System.Windows.Media.Brushes]::DimGray
            Set-PreviewBadge -Text "PowerShell" -Background "#E7F5EC" -Foreground "#1F7A45"
            Update-ActionState
            return
        }

        # Handle .md files: parse for formatting.
        $inputDefinitions = @(Get-ScriptInputDefinitionsFromContent -Content $fileContent)
        $fileContent = Remove-ScriptInputBlock -Content $fileContent
        $codeBlockRegex = $RegexPatterns.PowerShellCodeBlock
        $codeBlockMatch = [regex]::Match($fileContent, $codeBlockRegex)

        if ($codeBlockMatch.Success) {
            # Extract sections before and after code block.
            $beforeCode = $fileContent.Substring(0, $codeBlockMatch.Index)
            $codeContent = $codeBlockMatch.Groups[1].Value.Trim()
            $afterCode = $fileContent.Substring($codeBlockMatch.Index + $codeBlockMatch.Length)

            # Process markdown before code block.
            Convert-MarkdownToFlowDocument -Content $beforeCode -Document $doc
            Add-ScriptInputSummaryToDocument -InputDefinitions $inputDefinitions -Document $doc

            # Add formatted code block.
            $codeParagraph = New-CodePreviewParagraph -Content $codeContent
            $doc.Blocks.Add($codeParagraph)

            # Process markdown after code block.
            Convert-MarkdownToFlowDocument -Content $afterCode -Document $doc
            $ui.ScriptSummaryTextBlock.Text = "Markdown script | $($inputDefinitions.Count) input field(s) | $resolvedPath"
            $ui.ScriptSummaryTextBlock.Foreground = [System.Windows.Media.Brushes]::DimGray
            Set-PreviewBadge -Text "Markdown - $($inputDefinitions.Count) input(s)" -Background "#DCEBFA" -Foreground "#0B5CAD"
        }
        else {
            # No code block found; treat entire file as markdown.
            Convert-MarkdownToFlowDocument -Content $fileContent -Document $doc
            Add-ScriptInputSummaryToDocument -InputDefinitions $inputDefinitions -Document $doc
            $ui.ScriptSummaryTextBlock.Text = "Markdown note | $($inputDefinitions.Count) input field(s) | $resolvedPath"
            $ui.ScriptSummaryTextBlock.Foreground = [System.Windows.Media.Brushes]::OrangeRed
            Set-PreviewBadge -Text "Markdown note" -Background "#FCE7D3" -Foreground "#B45309"
        }
    }
    catch {
        $errorRun = [System.Windows.Documents.Run]::new("Error reading script file: $($_.Exception.Message)")
        $errorRun.Foreground = [System.Windows.Media.Brushes]::Red
        $errorPara = [System.Windows.Documents.Paragraph]::new($errorRun)
        $doc.Blocks.Add($errorPara)
        $ui.ScriptSummaryTextBlock.Text = "Unable to load selected script."
        $ui.ScriptSummaryTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
        Set-PreviewBadge -Text "Preview error" -Background "#FEE2E2" -Foreground "#B91C1C"
    }

    $ui.ScriptDescriptionViewer.Document = $doc
    Update-ActionState
}

function Show-ScriptInputDialog {
    <#
    .SYNOPSIS
        Prompts the user for script input values defined in markdown metadata.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$InputDefinitions,
        [string]$ScriptName = "Script"
    )

    if ($InputDefinitions.Count -eq 0) {
        return [ordered]@{}
    }

    $window = [System.Windows.Window]::new()
    $window.Title = "Inputs: $ScriptName"
    $window.Width = 500
    $window.Height = 420
    $window.WindowStartupLocation = "CenterOwner"
    $window.ResizeMode = "CanResize"
    $window.Owner = $ui.Window

    $rootGrid = [System.Windows.Controls.Grid]::new()
    $rootGrid.Margin = "12"
    $rowTop = [System.Windows.Controls.RowDefinition]::new()
    $rowTop.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $rowBottom = [System.Windows.Controls.RowDefinition]::new()
    $rowBottom.Height = [System.Windows.GridLength]::Auto
    $rootGrid.RowDefinitions.Add($rowTop)
    $rootGrid.RowDefinitions.Add($rowBottom)

    $scrollViewer = [System.Windows.Controls.ScrollViewer]::new()
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    [System.Windows.Controls.Grid]::SetRow($scrollViewer, 0)

    $fieldPanel = [System.Windows.Controls.StackPanel]::new()
    $fieldPanel.Orientation = "Vertical"
    $scrollViewer.Content = $fieldPanel

    $buttonPanel = [System.Windows.Controls.StackPanel]::new()
    $buttonPanel.Orientation = "Horizontal"
    $buttonPanel.HorizontalAlignment = "Right"
    $buttonPanel.Margin = "0,12,0,0"
    [System.Windows.Controls.Grid]::SetRow($buttonPanel, 1)

    $okButton = [System.Windows.Controls.Button]::new()
    $okButton.Content = "OK"
    $okButton.Width = 90
    $okButton.Margin = "0,0,8,0"
    $okButton.IsDefault = $true

    $cancelButton = [System.Windows.Controls.Button]::new()
    $cancelButton.Content = "Cancel"
    $cancelButton.Width = 90
    $cancelButton.IsCancel = $true

    $buttonPanel.Children.Add($okButton) | Out-Null
    $buttonPanel.Children.Add($cancelButton) | Out-Null

    $rootGrid.Children.Add($scrollViewer) | Out-Null
    $rootGrid.Children.Add($buttonPanel) | Out-Null
    $window.Content = $rootGrid

    $controls = @{}

    foreach ($definition in $InputDefinitions) {
        $label = [System.Windows.Controls.TextBlock]::new()
        $label.FontWeight = "Bold"
        $label.Margin = "0,0,0,4"
        $label.Text = if ($definition.Required) { "$($definition.Label) *" } else { $definition.Label }
        $fieldPanel.Children.Add($label) | Out-Null

        $control = $null
        switch ($definition.Type) {
            'bool' {
                $control = [System.Windows.Controls.CheckBox]::new()
                $control.Margin = "0,0,0,4"
                $control.IsChecked = [bool]$definition.Default
            }
            'choice' {
                $control = [System.Windows.Controls.ComboBox]::new()
                $control.Margin = "0,0,0,4"
                foreach ($option in @($definition.Options)) {
                    [void]$control.Items.Add([string]$option)
                }

                if ($control.Items.Count -gt 0) {
                    if ($null -ne $definition.Default -and $control.Items.Contains([string]$definition.Default)) {
                        $control.SelectedItem = [string]$definition.Default
                    }
                    else {
                        $control.SelectedIndex = 0
                    }
                }
            }
            'multiline' {
                $control = [System.Windows.Controls.TextBox]::new()
                $control.Margin = "0,0,0,4"
                $control.AcceptsReturn = $true
                $control.TextWrapping = "Wrap"
                $control.Height = 90
                if ($null -ne $definition.Default) {
                    $control.Text = [string]$definition.Default
                }
            }
            default {
                $control = [System.Windows.Controls.TextBox]::new()
                $control.Margin = "0,0,0,4"
                if ($null -ne $definition.Default) {
                    $control.Text = [string]$definition.Default
                }
            }
        }

        if ($null -ne $control) {
            if (-not [string]::IsNullOrWhiteSpace($definition.Placeholder) -and $control -is [System.Windows.Controls.TextBox]) {
                $control.ToolTip = $definition.Placeholder
            }

            $fieldPanel.Children.Add($control) | Out-Null
            $controls[$definition.Name] = $control
        }

        if (-not [string]::IsNullOrWhiteSpace($definition.Help)) {
            $helpText = [System.Windows.Controls.TextBlock]::new()
            $helpText.Margin = "0,0,0,10"
            $helpText.Foreground = [System.Windows.Media.Brushes]::DimGray
            $helpText.TextWrapping = "Wrap"
            $helpText.Text = $definition.Help
            $fieldPanel.Children.Add($helpText) | Out-Null
        }
        else {
            $spacer = [System.Windows.Controls.TextBlock]::new()
            $spacer.Margin = "0,0,0,10"
            $fieldPanel.Children.Add($spacer) | Out-Null
        }
    }

    $okButton.Add_Click({
        foreach ($definition in $InputDefinitions) {
            $control = $controls[$definition.Name]
            $value = $null

            switch ($definition.Type) {
                'bool' { $value = [bool]$control.IsChecked }
                'choice' { $value = [string]$control.SelectedItem }
                default { $value = [string]$control.Text }
            }

            if ($definition.Required -and [string]::IsNullOrWhiteSpace([string]$value)) {
                [System.Windows.MessageBox]::Show(
                    "Please provide a value for '$($definition.Label)'.",
                    "Missing Input",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                ) | Out-Null
                return
            }

            if ($definition.Type -eq 'int' -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
                $parsedValue = 0
                if (-not [int]::TryParse([string]$value, [ref]$parsedValue)) {
                    [System.Windows.MessageBox]::Show(
                        "'$($definition.Label)' must be a whole number.",
                        "Invalid Input",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    ) | Out-Null
                    return
                }
            }
        }

        $window.DialogResult = $true
    })

    if ($window.ShowDialog() -ne $true) {
        return $null
    }

    $result = [ordered]@{}
    foreach ($definition in $InputDefinitions) {
        $control = $controls[$definition.Name]

        switch ($definition.Type) {
            'bool' {
                $result[$definition.Name] = [bool]$control.IsChecked
            }
            'int' {
                if ([string]::IsNullOrWhiteSpace($control.Text)) {
                    $result[$definition.Name] = $null
                }
                else {
                    $result[$definition.Name] = [int]$control.Text
                }
            }
            'choice' {
                $result[$definition.Name] = [string]$control.SelectedItem
            }
            default {
                $result[$definition.Name] = [string]$control.Text
            }
        }
    }

    return $result
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
        $paragraph.Margin = "0,0,0,12"
        $paragraph.Foreground = [System.Windows.Media.SolidColorBrush]::new(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
        )

        # Determine header level and adjust formatting.
        if ($line.StartsWith("###")) {
            $paragraph.FontSize = 18
            $paragraph.FontWeight = "SemiBold"
            $paragraph.Foreground = [System.Windows.Media.SolidColorBrush]::new(
                [System.Windows.Media.ColorConverter]::ConvertFromString("#51525A")
            )
            $line = $line.Substring(3).Trim()
        }
        elseif ($line.StartsWith("##")) {
            $paragraph.FontSize = 22
            $paragraph.FontWeight = "SemiBold"
            $paragraph.Foreground = [System.Windows.Media.SolidColorBrush]::new(
                [System.Windows.Media.ColorConverter]::ConvertFromString("#42444C")
            )
            $line = $line.Substring(2).Trim()
        }
        elseif ($line.StartsWith("#")) {
            $paragraph.FontSize = 28
            $paragraph.FontWeight = "SemiBold"
            $paragraph.Margin = "0,0,0,16"
            $paragraph.Foreground = [System.Windows.Media.SolidColorBrush]::new(
                [System.Windows.Media.ColorConverter]::ConvertFromString("#1F1F1F")
            )
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
        Creates a PSCredential from the optional UI fields when both values are present.
    .OUTPUTS
        [System.Management.Automation.PSCredential] or $null if credentials are not provided.
    #>
    [CmdletBinding()]
    param()

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

#region Script Path Initialization
if ($PSScriptRoot) {
    $ScriptPath = $PSScriptRoot
} else {
    $ScriptPath = Get-Location
}
$ScriptsXmlPath = Join-Path $ScriptPath "scripts.xml"
#endregion

#region UI Initialization
try {
    [xml]$xaml = $XAML_MainWindow
    [xml]$AddScriptDialogXAML = $XAML_AddScriptDialog

    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $ui = @{}
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object {
        $ui[$_.Name] = $window.FindName($_.Name)
    }

    $ui['Window'] = $window
}
catch {
    Write-Error "Failed to load the main window XAML: $($_.Exception.Message)"
    return
}
#endregion

#region Event Handlers
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

$ui.AddComputerButton.add_Click({
    Update-ComputerListView
})

$ui.ScriptSelectionComboBox.add_SelectionChanged({ 
    Update-ScriptDescriptionView
})

$ui.ScriptLibraryListView.add_SelectionChanged({
    Update-ActionState
})

$ui.GetInfoButton.add_Click({
    $computers = $ui.ComputerListView.ItemsSource

    # Validate that target computers are specified.
    if (-not $computers -or $computers.Count -eq 0) {
        Add-OutputLine -Text "No target computers specified. Please enter computer names." -Color $ColorConstants.Error
        return
    }

    Set-ApplicationBusy -IsBusy $true -Message "Collecting system details from $($computers.Count) target(s)..."

    try {
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
            Set-StatusMessage -Text "Querying $computer..." -Color $ColorConstants.Highlight
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
        Set-StatusMessage -Text "Get Info finished for $($computers.Count) target(s)." -Color $ColorConstants.Success
    }
    finally {
        Set-ApplicationBusy -IsBusy $false
    }
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

    try {
        $inputDefinitions = @(Get-ScriptInputDefinitions -FilePath $selectedScript.Path)
    }
    catch {
        Add-OutputLine -Text "Fatal error loading script inputs: $($_.Exception.Message)" -Color $ColorConstants.Error
        return
    }

    $scriptInputValues = Show-ScriptInputDialog -InputDefinitions $inputDefinitions -ScriptName $selectedScript.Name
    if ($null -eq $scriptInputValues) {
        Add-OutputLine -Text "Script execution canceled." -Color $ColorConstants.Warning
        Set-StatusMessage -Text "Script execution canceled." -Color $ColorConstants.Warning
        return
    }

    Set-ApplicationBusy -IsBusy $true -Message "Running '$($selectedScript.Name)' on $($computers.Count) target(s)..."

    try {
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
            Set-StatusMessage -Text "Running '$($selectedScript.Name)' on $computer..." -Color $ColorConstants.Highlight
            Add-OutputLine -Text "--- Executing on $computer ---" -Color $ColorConstants.Section
            try {
                $invokeParams["ComputerName"] = $computer
                if ($inputDefinitions.Count -gt 0) {
                    $invokeParams["ArgumentList"] = @(
                        foreach ($definition in $inputDefinitions) {
                            $scriptInputValues[$definition.Name]
                        }
                    )
                }
                elseif ($invokeParams.ContainsKey("ArgumentList")) {
                    $invokeParams.Remove("ArgumentList")
                }

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
        Set-StatusMessage -Text "'$($selectedScript.Name)' finished for $($computers.Count) target(s)." -Color $ColorConstants.Success
    }
    finally {
        Set-ApplicationBusy -IsBusy $false
    }
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
        if (-not (Test-ScriptFileIsRunnable -FilePath $newScriptPath)) {
            Add-OutputLine -Text "That file does not contain a runnable PowerShell script block for the app." -Color $ColorConstants.Error
            return
        }

        # Add script to XML library.
        try {
            [xml]$scriptsXml = Get-Content -Path $ScriptsXmlPath -ErrorAction Stop

            # Check for duplicate script names without relying on fragile XPath string interpolation.
            $existingScript = @($scriptsXml.scripts.script) | Where-Object {
                $_.name -eq $newScriptName
            } | Select-Object -First 1
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
            Set-StatusMessage -Text "Added script '$newScriptName' to the library." -Color $ColorConstants.Success
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

        $nodeToRemove = @($scriptsXml.scripts.script) | Where-Object {
            $_.name -eq $selectedItem.Name -and $_.path -eq $selectedItem.Path
        } | Select-Object -First 1

        if ($null -eq $nodeToRemove) {
            Add-OutputLine -Text "Script not found in library. It may have been removed already." -Color $ColorConstants.Warning
            Update-ScriptLibraryView
            return
        }

        # Remove the node and save.
        $nodeToRemove.ParentNode.RemoveChild($nodeToRemove) | Out-Null
        $scriptsXml.Save($ScriptsXmlPath)

        Add-OutputLine -Text "Removed script '$($selectedItem.Name)' from library." -Color $ColorConstants.Success
        Set-StatusMessage -Text "Removed script '$($selectedItem.Name)' from the library." -Color $ColorConstants.Success
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
        Update-ActionState
    }
    catch {
        Write-Verbose "Error clearing console output: $($_.Exception.Message)"
    }
})

$ui.CopyConsoleButton.add_Click({
    try {
        $range = [System.Windows.Documents.TextRange]::new(
            $ui.OutputConsole.Document.ContentStart,
            $ui.OutputConsole.Document.ContentEnd
        )

        if (-not [string]::IsNullOrWhiteSpace($range.Text)) {
            [System.Windows.Clipboard]::SetText($range.Text)
            Set-StatusMessage -Text "Copied console output to clipboard." -Color $ColorConstants.Success
        }
    }
    catch {
        Add-OutputLine -Text "Unable to copy console output: $($_.Exception.Message)" -Color $ColorConstants.Error
    }
})
#endregion

#region Application Start
try {
    Auto-DiscoverScripts

    # Initialize the script library from the XML file.
    Update-ScriptLibraryView

    # Pre-fill the computer name field with the local machine hostname.
    $localHostname = $env:COMPUTERNAME
    if ([string]::IsNullOrWhiteSpace($localHostname)) {
        $localHostname = [System.Net.Dns]::GetHostName()
    }
    $ui.ComputerInputTextBox.Text = $localHostname
    Update-ComputerListView

    $ui.OutputConsole.Document.PagePadding = "0"
    Add-OutputLine -Text "Admin Tool initialized successfully. Local hostname: $localHostname" -Color $ColorConstants.Success
    Set-StatusMessage -Text "Ready. Loaded admin tool for $localHostname." -Color $ColorConstants.Success
    Update-ActionState
}
catch {
    Add-OutputLine -Text "Critical error during initialization: $($_.Exception.Message)" -Color $ColorConstants.Error
}

# Display the main window and block until it is closed by the user.
if ($ui.Window) {
    $null = $ui.Window.ShowDialog()
}
#endregion
