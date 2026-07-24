---
name: origin-live-control
description: Safely control local Origin or OriginPro through the desktop-origin-mcp plugin on Windows. Use when the user asks to inspect, create, edit, analyze, plot, import, export, or save Origin worksheets, matrices, graphs, fitting workflows, LabTalk variables, or projects.
---

# Origin Live Control

Use the installed `origin` MCP server. Keep every write operation behind the configured Codex approval prompt.

## Workflow

1. Confirm the workbook, worksheet, graph, matrix, project, and output path in scope.
2. Run `scripts/health-check.ps1` from the plugin root when the connection is unhealthy. Run `scripts/preflight.ps1` before first installation and `scripts/install.ps1` only when the user asks to install or repair the runtime.
3. Inspect the current Origin state with read-only tools before changing it.
4. Describe the concrete write operation and let the configured MCP approval prompt request permission.
5. Perform only the requested operation, then verify the application state or saved artifact.

## Safety rules

- Work in the already-open Origin instance; the launcher forces in-process COM attach.
- Treat `run_labtalk` as high risk. Review the complete script and preserve both the MCP prompt and its `confirm=True` gate.
- Confirm targets before writes, deletion, import, export, save, load, or project replacement.
- Do not enable automatic modal-dialog dismissal, autosave, orphan cleanup, or forced process termination.

## References

- Read [references/compatibility.md](references/compatibility.md) when installation, COM discovery, or version compatibility is relevant.
- Read [references/third-party.md](references/third-party.md) before redistributing, updating, or replacing the pinned upstream.
