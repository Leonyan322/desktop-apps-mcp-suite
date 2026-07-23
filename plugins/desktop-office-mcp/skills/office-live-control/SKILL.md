---
name: office-live-control
description: Control locally installed Microsoft PowerPoint, Excel, and Word through the desktop-office-mcp plugin on Windows. Use for live Office inspection, creation, editing, formatting, saving, export, connection checks, and troubleshooting of .pptx, .xlsx/.xlsm, and .docx files when the user wants Codex to operate the desktop applications rather than only transform standalone files.
---

# Office Live Control

Use the plugin's three local MCP servers to control the installed Office applications. Preserve the user's target file, visible application state, and explicit save destination.

## Prepare the runtime

1. Run `scripts/preflight.ps1` before first installation or when the host changes.
2. Run `scripts/install.ps1` only when the user asks to install, repair, or update the local runtime.
3. Run `scripts/health-check.ps1` when a server is unavailable or reports a connection error.
4. Ask the user to handle Office activation, protected-view, file-recovery, Trust Center, or first-run dialogs in the application window.

Read [references/compatibility.md](references/compatibility.md) when setup or connection checks fail. Read [references/third-party.md](references/third-party.md) before changing dependency versions or redistribution behavior.

## Select the server

- Use `ppt` tools for live PowerPoint work. Connect, list presentations, and activate the intended presentation before editing it.
- Use `excel` tools for workbook reads and writes. Pass an absolute file path and, for live COM operations, keep the target workbook open in Excel.
- Use `officemcp` for Word. Check `IsAppAvailable` first, then call `RunPython` with focused COM automation code and an explicit output value.

## Work safely

1. Inspect the active application and exact target before changing content.
2. Keep write operations narrow and save only after verifying the requested destination.
3. Never bypass an approval prompt. PowerPoint and Excel write tools require approval; every OfficeMCP call prompts because `RunPython` can execute arbitrary local code.
4. Treat `OFFICEMCP_ROOT_FOLDER` as a default working directory, not a security sandbox.
5. Do not close an Office instance or document unless the user asks. Close only temporary instances created for the current task.
6. Report blocking application dialogs instead of attempting to dismiss them automatically.

## Finish

Verify the saved file exists, confirm the relevant Office application remains in the expected state, and report the exact output path. If a tool fails after a dialog appears, let the user clear the dialog and retry the smallest failed operation.
