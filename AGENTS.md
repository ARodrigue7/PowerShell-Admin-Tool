# AGENTS.md

## Purpose

This repository contains a self-contained PowerShell WPF application for remote administration. The main goal of any agent working here is to keep the app reliable, easy to run, and compatible with the current single-file architecture.

## Key Files

- `AdminTool.ps1`
  Primary application entry point and the main file to modify for most tasks.
- `GeminiAdmin.ps1`
  Older or alternate variant kept for comparison. Do not update it unless the task explicitly requires it.
- `scripts.xml`
  Persistent script library used by the UI.
- `Scripts/`
  Runnable `.ps1` and markdown-backed `.md` script assets.
- `README.md`
  End-user setup and usage documentation.

## Repo Conventions

- Prefer editing `AdminTool.ps1` instead of introducing new runtime modules unless the task clearly benefits from a refactor.
- Keep changes compatible with Windows PowerShell 5.1 where practical.
- Preserve support for both `.ps1` scripts and markdown `.md` scripts.
- Preserve support for relative paths stored in `scripts.xml`.
- Treat `GeminiAdmin.ps1` as reference material unless asked to keep parity.

## Markdown Script Rules

- Runnable markdown scripts must include a fenced `powershell` block.
- The first fenced `powershell` block is the code the app executes.
- Optional user prompts are defined with a fenced `script-inputs` block containing JSON.
- Be careful when changing regex or markdown parsing logic because it affects both preview and execution.

## UI and Behavior Notes

- The app loads inline XAML and maps named controls into the `$ui` hashtable.
- The UI includes:
  - target computer entry and import
  - optional alternate credentials
  - script selection and preview
  - library management
  - output console and footer status area
- Remote execution currently uses synchronous `Invoke-Command` calls. Avoid making the UX feel more blocked unless the task is specifically about execution flow.

## Validation

There is no formal automated test suite in the repo today. After PowerShell edits, run at least a syntax parse check:

```powershell
pwsh -NoProfile -Command '$tokens = $null; $errors = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("AdminTool.ps1", [ref]$tokens, [ref]$errors); if ($errors) { $errors | ForEach-Object { $_.Message }; exit 1 }'
```

If the task changes app behavior, also do a quick manual review of the affected UI flow when possible.

## Safe Change Strategy

- Prefer focused, low-risk patches.
- Do not silently change file formats or library assumptions.
- Keep user-facing status and error messages clear.
- If changing startup, script discovery, script execution, or preview behavior, review the whole flow because these areas are tightly connected.

## Good Next Improvements

- Move remote execution off the UI thread using runspaces or jobs.
- Add run summaries with per-target success and failure counts.
- Persist more UI state between launches.
- Add script library filtering if the script count grows.
