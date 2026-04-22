# Codex Reference Guide

## Project Snapshot

This repository contains a self-contained Windows PowerShell WPF application for remote administration. The app presents a script library, allows a user to target one or more remote machines, optionally supply alternate credentials, preview script content, and execute the selected script through PowerShell remoting.

The current primary implementation is `AdminTool.ps1`. `GeminiAdmin.ps1` is useful as an older comparison point, but changes should generally target `AdminTool.ps1` unless there is a clear reason to keep both in sync.

## Repo Layout

- `AdminTool.ps1`
  Main application script. Defines XAML, helper functions, UI initialization, and event handlers.
- `GeminiAdmin.ps1`
  Legacy or experimental variant of the app.
- `scripts.xml`
  Persistent library of script records exposed in the UI.
- `Scripts/`
  Source files for runnable scripts. Supports `.ps1` and markdown `.md`.
- `README.md`
  End-user overview and setup instructions.

## Runtime Model

### UI composition

The app stores its WPF markup in PowerShell here-strings and loads it with `XamlReader`. After loading, named controls are collected into a `$ui` hashtable. That hashtable is the central access point for all control updates and event handlers.

### Script library loading

The app reads `scripts.xml`, builds lightweight objects with `Name` and `Path`, and binds those to:

- `ScriptLibraryListView`
- `ScriptSelectionComboBox`

If `scripts.xml` is missing, the app creates it. During startup it also scans the `Scripts/` directory and auto-adds missing runnable scripts.

### Supported script formats

The tool supports:

- Plain `.ps1` files: full file content is executed.
- Markdown `.md` files: the first fenced `powershell` block is extracted and executed.

Markdown files can also include a fenced `script-inputs` block containing JSON metadata that drives the dynamic input dialog before execution.

Example structure:

````md
# Example Script

```script-inputs
[
  {
    "Name": "UserName",
    "Label": "User name",
    "Type": "text",
    "Required": true
  }
]
```

```powershell
param($UserName)
Get-LocalUser -Name $UserName
```
````

## Important Functions

- `Add-OutputLine`
  Appends colored output to the bottom console safely via the UI dispatcher.
- `Update-ScriptLibraryView`
  Loads `scripts.xml` into UI-bound objects.
- `Resolve-ScriptLibraryPath`
  Normalizes absolute and relative script paths.
- `Get-ScriptInputDefinitionsFromContent`
  Parses `script-inputs` metadata from markdown.
- `Test-ScriptFileIsRunnable`
  Ensures the selected file is executable by the app.
- `Auto-DiscoverScripts`
  Scans `Scripts/` for runnable `.ps1` and `.md` files and registers them.
- `Get-ScriptCodeFromFile`
  Extracts actual runnable PowerShell code from `.ps1` or `.md`.
- `Update-ComputerListView`
  Parses target input and updates the visible computer list and summary.
- `Update-ScriptDescriptionView`
  Renders the script preview and script summary details.
- `Show-ScriptInputDialog`
  Builds a dynamic prompt window for markdown-defined inputs.
- `New-PSCredentialFromUI`
  Creates a `PSCredential` from the optional username and password fields.

## Current UX Notes

The current app has a few useful guardrails:

- action buttons enable and disable based on current selections
- target input is normalized and de-duplicated
- the footer shows current busy state and short status messages
- the preview shows whether a selected file is a PowerShell script or markdown-backed script

These improvements make the app easier to use, but remote execution is still synchronous. If responsiveness becomes a priority, moving remoting work off the UI thread is the next big win.

## Known Constraints

- The app is designed around Windows PowerShell and WPF.
- Remote operations rely on `Invoke-Command` and WinRM availability.
- Markdown rendering is intentionally minimal.
- The first fenced `powershell` block is the one that gets executed.
- A markdown file without a runnable fenced block should be treated as documentation, not an executable script.

## Safe Change Strategy

When editing this project:

- Prefer focused changes in `AdminTool.ps1` rather than broad structural refactors.
- Keep compatibility with Windows PowerShell 5.1 in mind.
- Re-parse the script after edits to catch syntax regressions.
- Be careful with path handling and markdown extraction, since those impact both preview and execution.
- Avoid changing `scripts.xml` assumptions unless the UI binding and auto-discovery logic are updated together.

## Suggested Future Work

- Run remote calls on background runspaces to keep the UI responsive.
- Add a run summary with total targets, successes, and failures.
- Persist more user state between launches.
- Add inline validation hints for credential entry and script inputs.
- Add search and filtering for the script library if the number of scripts grows.
