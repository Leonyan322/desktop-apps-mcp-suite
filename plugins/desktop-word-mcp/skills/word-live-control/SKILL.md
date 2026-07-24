---
name: word-live-control
description: Control locally installed Microsoft Word through the desktop-word-mcp plugin on Windows. Use for live document inspection, creation, editing, formatting, saving, export, connection checks, and troubleshooting of .docx files when the user wants Codex to operate the desktop application.
---

# Word Live Control

Use the `word` MCP server to control Word. Preserve the target document, visible application state, and explicit save destination.

## Prepare

1. Run `scripts/preflight.ps1` before first installation or after changing hosts.
2. Run `scripts/install.ps1` only when asked to install, repair, or update the runtime.
3. Run `scripts/health-check.ps1` when the server is unavailable.
4. Ask the user to handle activation, protected-view, file-recovery, Trust Center, or first-run dialogs in Word.

Read [references/compatibility.md](references/compatibility.md) when setup fails. Read [references/third-party.md](references/third-party.md) before changing or redistributing dependencies.

## Operate safely

1. Check `IsAppAvailable`, then use `RunPython` with focused COM automation and an explicit output value.
2. Inspect the exact document before changing it; keep writes narrow.
3. Respect every approval prompt. Every server call prompts because `RunPython` can execute arbitrary local code; `OFFICEMCP_ROOT_FOLDER` is not a security sandbox.
4. Do not close Word or a document unless the user asks. Close only temporary instances created for the task.
5. Save only after confirming the destination, then verify the output exists.

Report blocking application dialogs instead of trying to dismiss them automatically.
