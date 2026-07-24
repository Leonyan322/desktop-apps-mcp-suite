---
name: photoshop-live-control
description: Control locally installed Adobe Photoshop 2020 through a guarded Windows COM MCP server. Use when the user asks Codex to inspect, create, edit, automate, or save a live Photoshop document, or to install, diagnose, health-check, or remove this Photoshop MCP runtime.
---

# Photoshop Live Control

Use the Photoshop MCP tools for the requested live-document operation. Treat the document as user data: inspect state first, change only what was requested, and do not save, overwrite, close, or export unless the user asked.

## Runtime workflow

1. If the MCP server is unavailable, run `scripts/preflight.ps1` from the plugin root.
2. If the runtime is absent, run `scripts/install.ps1`; it installs the pinned upstream commit under `%LOCALAPPDATA%\desktop-apps-mcp-suite\adobe\photoshop-mcp`.
3. Run `scripts/health-check.ps1` after installation or when startup fails.
4. Restart Codex after installation or MCP configuration changes.
5. Use `scripts/uninstall.ps1` only when the user explicitly requests removal.

Read [compatibility.md](references/compatibility.md) when diagnosing versions, startup, disabled tools, registry discovery, or approval prompts. Read [third-party.md](references/third-party.md) before redistributing, mirroring, or changing the pinned upstream source.

## Safety rules

- Prefer narrow built-in tools over arbitrary script execution.
- Allow the approval prompt to appear for `photoshop_execute_script`; never bypass it or split a risky operation to evade approval.
- Explain the exact side effect before asking the user to approve arbitrary ExtendScript.
- Keep generative, neural-filter, and sky-replacement tools disabled for Photoshop 2020.
- Treat Codex MCP approval separately from Windows filesystem access. Full filesystem access does not pre-authorize a write inside Photoshop.
- Inspect the active document and layer state before editing. Use `photoshop_execute_script` only when no dedicated tool covers the request.
