---
name: powerpoint-live-control
description: Control locally installed Microsoft PowerPoint through the desktop-powerpoint-mcp plugin on Windows. Use for live presentation inspection, creation, editing, formatting, saving, export, connection checks, and troubleshooting of .pptx files when the user wants Codex to operate the desktop application.
---

# PowerPoint Live Control

Use the `ppt` MCP server to control PowerPoint. Preserve the target presentation, visible application state, and explicit save destination.

## Prepare

1. Run `scripts/preflight.ps1` before first installation or after changing hosts.
2. Run `scripts/install.ps1` only when asked to install, repair, or update the runtime.
3. Run `scripts/health-check.ps1` when the server is unavailable.
4. Ask the user to handle activation, protected-view, file-recovery, Trust Center, or first-run dialogs in PowerPoint.

Read [references/compatibility.md](references/compatibility.md) when setup fails. Read [references/third-party.md](references/third-party.md) before changing or redistributing dependencies.

## Operate safely

1. Connect, list presentations, and activate the exact target before editing.
2. Inspect before changing content; keep write operations narrow.
3. Respect every approval prompt. The plugin requests approval for write tools and keeps `PPT_AUTO_DISMISS_DIALOG=false`.
4. Do not close PowerPoint or a presentation unless the user asks. Close only temporary instances created for the task.
5. Save only after confirming the requested destination, then verify the output exists.

Report blocking application dialogs instead of trying to dismiss them automatically.
