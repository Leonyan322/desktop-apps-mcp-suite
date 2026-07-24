# Illustrator MCP compatibility and safety

## Supported profile

This plugin targets 64-bit Windows with Illustrator 2020 installed and registered for COM automation.

| Component | Pinned source | Runtime requirement |
| --- | --- | --- |
| Illustrator MCP | `krVatsal/illustrator-mcp` commit `5040dde760688502f6006204ce9562c01c82c65c` | Python 3.12 or newer; `mcp==1.1.1`; `Pillow==11.0.0`; `pywin32==310` |

The managed runtime is `%LOCALAPPDATA%\desktop-apps-mcp-suite\adobe\illustrator-mcp`. The scripts resolve this location at runtime and do not depend on a user name or drive letter. Installation adds the fixed checkout as a local package inside its virtual environment so `python -m illustrator` works outside the repository root.

## Windows COM discovery

Discovery verifies the current `Illustrator.Application` ProgID and reads its CurVer, CLSID, dynamic `LocalServer32`, and App Paths registration without launching Illustrator. Illustrator 2020 normally registers CurVer `Illustrator.Application.24`. If several versions are installed, the upstream server controls whichever version owns the unversioned ProgID.

## Restrictions and approval

Keep `view` disabled because its Windows implementation calls `PIL.ImageGrab.grab()` and captures the whole desktop. Keep `help` disabled as a conservative stability isolation after an earlier end-to-end timeout.

The upstream server omits MCP read-only/destructive annotations. The plugin defaults write operations to approval and explicitly prompts for `run`, which executes arbitrary ExtendScript. This is independent from Windows administrator rights and filesystem access.

Run `scripts/preflight.ps1` and `scripts/health-check.ps1` from the plugin root for diagnostics. The checks do not execute ExtendScript or capture the screen.
