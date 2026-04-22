# Codex Working Notes

Project: PowerShell Remote Admin Tool

Purpose
- WPF-based PowerShell admin console for running local script-library items against one or more remote computers with optional alternate credentials.

Primary files
- `AdminTool.ps1`: main app and current working version.
- `GeminiAdmin.ps1`: alternate or older variant for comparison and experimentation.
- `scripts.xml`: persisted script library entries shown in the UI.
- `Scripts/`: runnable `.ps1` or markdown-backed `.md` scripts.

How the app works
- Loads WPF XAML from inline here-strings.
- Maps named UI controls into the `$ui` hashtable.
- Auto-discovers runnable scripts from `Scripts/` and merges missing ones into `scripts.xml`.
- Supports direct `.ps1` execution.
- Supports markdown `.md` execution by extracting the first fenced `powershell` block.
- Supports optional `script-inputs` JSON metadata blocks for prompting the user before execution.
- Uses `Invoke-Command` for remote execution.

Current UI behavior
- Main tab:
  - target computer entry and file import
  - optional alternate credentials
  - script selection, preview, and execution
- Library tab:
  - add and remove script records stored in `scripts.xml`
- Footer/status area:
  - busy state
  - short status text
- Output console:
  - colored status and error lines

Important implementation details
- Paths in `scripts.xml` can be relative; `Resolve-ScriptLibraryPath` normalizes them.
- Markdown preview is intentionally lightweight, not full Markdown.
- Runnable markdown requires a fenced `powershell` code block.
- Script input definitions are parsed from a fenced `script-inputs` block.
- Remote actions are still synchronous on the UI thread; status feedback exists, but true background execution is still a future optimization.

Recent improvements
- Added target and script summary text in the UI.
- Added footer status and busy messaging.
- Added action enable and disable logic to reduce invalid clicks.
- Improved target parsing to accept commas, semicolons, and new lines with de-duplication.

Good next improvements
- Move remote execution to background runspaces or jobs so the UI stays responsive.
- Add per-target success and failure counts at the end of runs.
- Persist last-used UI state such as selected script and recent targets.
- Add search or filter support in the script library if the script set grows.

Editing guidance
- Preserve the single-file app style in `AdminTool.ps1` unless a refactor is clearly worth it.
- Prefer low-risk PowerShell 5.1-compatible changes.
- Validate markdown-backed execution whenever changing regex or preview logic.
- Be careful not to break `scripts.xml` relative path support.
