---
name: engineering-live-control
description: Safely control local Origin/OriginPro and Ansys Electronics Desktop HFSS through the desktop-engineering-mcp plugin on Windows. Use when the user asks to inspect, create, edit, analyze, plot, import, export, or save Origin worksheets, graphs, and projects, or inspect and modify HFSS/AEDT projects, geometry, variables, ports, boundaries, setups, and results.
---

# Engineering Live Control

Use the installed `origin` and `hfss` MCP servers. Keep all write operations behind the configured Codex approval prompt.

## Workflow

1. Confirm which application and project the user intends to control.
2. If a connection is missing or unhealthy, run `scripts/health-check.ps1` from the plugin root. Run `scripts/preflight.ps1` before first installation and `scripts/install.ps1` only when the user asks to install or repair the runtime.
3. Inspect the current application state with read-only tools before changing it.
4. Describe the concrete write operation and let the configured MCP approval prompt request permission.
5. Perform only the requested operation, then verify the application state or saved artifact.

## Origin rules

- Work in the already-open Origin instance; the launcher forces in-process COM attach.
- Treat `run_labtalk` as high risk. Review the complete script and preserve both the MCP prompt and its `confirm=True` gate.
- Confirm the target workbook, worksheet, graph, and output path before writes, deletion, import, export, save, load, or project replacement.
- Do not enable automatic modal-dialog dismissal, autosave, orphan cleanup, or forced process termination.

## HFSS rules

- Target AEDT 2023 R1 with PyAEDT 0.25.1.
- Query process, session, and object state before modifying a design.
- Keep `hfss_stop_app`, `hfss_restart_app`, and `hfss_run_analysis` disabled. Start analyses manually in AEDT after reviewing the setup.
- Treat project creation, geometry, variables, ports, boundaries, setup changes, save, close, import, and export as approval-required writes.
- Never terminate an AEDT process. The patched stop path only detaches the MCP session.

## References

- Read [references/compatibility.md](references/compatibility.md) when installation, application discovery, or version compatibility is relevant.
- Read [references/third-party.md](references/third-party.md) before redistributing, updating, or replacing either pinned upstream.
