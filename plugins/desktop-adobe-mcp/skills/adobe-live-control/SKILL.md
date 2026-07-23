---
name: adobe-live-control
description: Control locally installed Adobe Photoshop 2020 and Illustrator 2020 through guarded Windows COM MCP servers. Use when the user asks Codex to inspect, create, edit, automate, or save a live Photoshop document or Illustrator artwork, or to install, diagnose, health-check, or remove this Adobe MCP runtime.
---

# Adobe Live Control

Use the dedicated Photoshop or Illustrator MCP tools for the requested live-document operation. Treat the application document as user data: inspect state first, change only what was requested, and do not save, overwrite, close, or export unless the user asked.

## Runtime workflow

1. If the MCP server is unavailable, run `scripts/preflight.ps1` from the plugin root.
2. If the runtime is absent, run `scripts/install.ps1`; it installs pinned upstream commits under `%LOCALAPPDATA%\desktop-apps-mcp-suite\adobe`.
3. Run `scripts/health-check.ps1` after installation or when startup fails.
4. Restart Codex after installation or MCP configuration changes.
5. Use `scripts/uninstall.ps1` only when the user explicitly requests removal.

Read [compatibility.md](references/compatibility.md) when diagnosing versions, startup, disabled tools, registry discovery, or approval prompts. Read [third-party.md](references/third-party.md) before redistributing, mirroring, or changing the pinned upstream sources.

## Safety rules

- Prefer narrow built-in tools over arbitrary script execution.
- Allow the approval prompt to appear for `photoshop_execute_script` and Illustrator `run`; never bypass it or split a risky operation to evade approval.
- Explain the exact side effect before asking the user to approve arbitrary ExtendScript.
- Keep Photoshop generative, neural-filter, and sky-replacement tools disabled for Photoshop 2020.
- Keep Illustrator `view` disabled because it captures the entire desktop, not only Illustrator.
- Keep Illustrator `help` disabled until its prior end-to-end stability issue is resolved.
- Treat Codex MCP approval separately from Windows filesystem access. Full filesystem access does not pre-authorize a write inside an Adobe application.

## Application guidance

For Photoshop, inspect the active document and layer state before editing. Use `photoshop_execute_script` only when no dedicated tool covers the request.

For Illustrator, the `run` tool is the editing interface and executes arbitrary ExtendScript. Keep scripts short, deterministic, and limited to the current document. Avoid filesystem access unless the user explicitly requested an import, export, open, or save operation.
