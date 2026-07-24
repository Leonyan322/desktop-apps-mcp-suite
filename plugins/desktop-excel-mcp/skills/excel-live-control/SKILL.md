---
name: excel-live-control
description: Control locally installed Microsoft Excel through the desktop-excel-mcp plugin on Windows. Use for live workbook inspection, creation, editing, formulas, formatting, saving, connection checks, and troubleshooting of .xlsx and .xlsm files when the user wants Codex to operate the desktop application.
---

# Excel Live Control

Use the `excel` MCP server to control Excel. Preserve the target workbook, visible application state, and explicit save destination.

## Prepare

1. Run `scripts/preflight.ps1` before first installation or after changing hosts.
2. Run `scripts/install.ps1` only when asked to install, repair, or update the runtime.
3. Run `scripts/health-check.ps1` when the server is unavailable.
4. Ask the user to handle activation, protected-view, file-recovery, Trust Center, or first-run dialogs in Excel.

Read [references/compatibility.md](references/compatibility.md) when setup fails. Read [references/third-party.md](references/third-party.md) before changing or redistributing dependencies.

## Operate safely

1. Use an absolute workbook path and confirm the intended workbook and worksheet before editing.
2. Inspect before changing cells; keep writes narrow and avoid overwriting formulas unintentionally.
3. Respect every approval prompt. The plugin requests approval for write tools.
4. Do not close Excel or a workbook unless the user asks. Close only temporary instances created for the task.
5. Save only after confirming the destination, then verify the output exists.

Report blocking application dialogs instead of trying to dismiss them automatically.
