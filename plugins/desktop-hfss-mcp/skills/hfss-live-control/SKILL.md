---
name: hfss-live-control
description: Safely control local Ansys Electronics Desktop HFSS 2023 R1 through the desktop-hfss-mcp plugin on Windows. Use when the user asks to inspect or modify HFSS/AEDT projects, designs, geometry, variables, materials, ports, boundaries, setups, sweeps, or results.
---

# HFSS Live Control

Use the installed `hfss` MCP server. Keep every write operation behind the configured Codex approval prompt.

## Workflow

1. Confirm the HFSS project, design, and objects in scope.
2. Run `scripts/health-check.ps1` from the plugin root when the connection is unhealthy. Run `scripts/preflight.ps1` before first installation and `scripts/install.ps1` only when the user asks to install or repair the runtime.
3. Query process, session, and object state before modifying a design.
4. Describe the concrete write operation and let the configured MCP approval prompt request permission.
5. Perform only the requested operation, then verify the HFSS state or saved artifact.

## Safety rules

- Target AEDT 2023 R1 with PyAEDT 0.25.1.
- Keep `hfss_stop_app`, `hfss_restart_app`, and `hfss_run_analysis` disabled. Start analyses manually in AEDT after reviewing the setup.
- Treat project creation, geometry, variables, ports, boundaries, setup changes, save, close, import, and export as approval-required writes.
- Never terminate an AEDT process. The patched stop path only detaches the MCP session.

## References

- Read [references/compatibility.md](references/compatibility.md) when installation, AEDT discovery, or version compatibility is relevant.
- Read [references/third-party.md](references/third-party.md) before redistributing, updating, or replacing the pinned upstream or compatibility patch.
