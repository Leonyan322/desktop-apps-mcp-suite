---
name: illustrator-live-control
description: Control locally installed Adobe Illustrator 2020 through a guarded Windows COM MCP server. Use when the user asks Codex to inspect, create, edit, automate, or save live Illustrator artwork, or to install, diagnose, health-check, or remove this Illustrator MCP runtime.
---

# Illustrator Live Control

Use the Illustrator MCP tools for the requested live-artwork operation. Treat the document as user data: inspect state first, change only what was requested, and do not save, overwrite, close, or export unless the user asked.

## Runtime workflow

1. If the MCP server is unavailable, run `scripts/preflight.ps1` from the plugin root.
2. If the runtime is absent, run `scripts/install.ps1`; it installs the pinned upstream commit under `%LOCALAPPDATA%\desktop-apps-mcp-suite\adobe\illustrator-mcp`.
3. Run `scripts/health-check.ps1` after installation or when startup fails.
4. Restart Codex after installation or MCP configuration changes.
5. Use `scripts/uninstall.ps1` only when the user explicitly requests removal.

Read [compatibility.md](references/compatibility.md) when diagnosing versions, startup, disabled tools, COM discovery, or approval prompts. Read [third-party.md](references/third-party.md) before redistributing, mirroring, or changing the pinned upstream source.

## Safety rules

- The `run` tool is the editing interface and executes arbitrary ExtendScript. Keep scripts short, deterministic, and limited to the current document.
- Allow the approval prompt to appear for `run`; never bypass it or split a risky operation to evade approval.
- Explain the exact side effect before asking the user to approve ExtendScript.
- Avoid filesystem access unless the user explicitly requested an import, export, open, or save operation.
- Keep `view` disabled because it captures the entire desktop, not only Illustrator.
- Keep `help` disabled until its prior end-to-end stability issue is resolved.
- Treat Codex MCP approval separately from Windows filesystem access. Full filesystem access does not pre-authorize a write inside Illustrator.
