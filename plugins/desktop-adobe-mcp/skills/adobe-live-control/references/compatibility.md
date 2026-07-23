# Adobe MCP compatibility and safety

## Supported profile

This plugin targets 64-bit Windows with Photoshop 2020 and Illustrator 2020 installed and registered for COM automation.

| Component | Pinned source | Runtime requirement |
| --- | --- | --- |
| Photoshop MCP | `alisaitteke/photoshop-mcp` commit `152f8937be98b352c40ab5b525829a50d022f283` | Node.js 18 or newer; Windows Script Host `cscript.exe`; Photoshop COM registration |
| Illustrator MCP | `krVatsal/illustrator-mcp` commit `5040dde760688502f6006204ce9562c01c82c65c` | Python 3.12 or newer; `mcp==1.1.1`; `Pillow==11.0.0`; `pywin32==310` |

The managed runtime is `%LOCALAPPDATA%\desktop-apps-mcp-suite\adobe`. The launch scripts resolve this location at runtime and do not depend on a user name or drive letter.

The Photoshop commit does not include an npm lockfile. The plugin supplies a separately audited lockfile, verifies its SHA-256, copies it into the runtime checkout, and installs with `npm ci` so dependency resolution does not vary by installation date.

## Windows discovery

Photoshop discovery checks the registered App Paths entry, Adobe Photoshop registry branches, the current `Photoshop.Application` ProgID and its dynamic CLSID/`LocalServer32`, then Program Files candidates. The launcher passes the resolved executable through `PHOTOSHOP_PATH`.

Illustrator discovery verifies the current `Illustrator.Application` ProgID and reads its CurVer, CLSID, dynamic `LocalServer32`, and App Paths registration without launching Illustrator. Illustrator 2020 normally registers CurVer `Illustrator.Application.24`. If several Illustrator versions are installed, the upstream server controls whichever version owns the unversioned ProgID.

## Photoshop 2020 restrictions

The pinned upstream detector may parse the path-derived string `2020` as a very large numeric major version and report newer capabilities incorrectly. The server also registers version-gated tools unconditionally. Keep these client-side blocks:

- `photoshop_generative_fill`
- `photoshop_generative_remove`
- `photoshop_generative_expand`
- `photoshop_generative_upscale`
- `photoshop_generate_image`
- `photoshop_neural_filter`
- `photoshop_sky_replacement`
- `photoshop_recipe_sky_blend`

The launcher sets `ANALYTICS_DISABLED=1` and the legacy `POSTHOG_DISABLED=1` before starting Photoshop MCP. It does not start the optional web UI or UXP bridge.

## Illustrator restrictions

Keep `view` disabled because its Windows implementation calls `PIL.ImageGrab.grab()` and captures the whole desktop. Keep `help` disabled as a conservative stability isolation after an earlier end-to-end timeout; the underlying string formatter alone does not require extra permissions.

## Approval prompts

Both upstream servers omit MCP read-only/destructive annotations. The plugin therefore defaults write operations to approval and explicitly sets per-call prompts for arbitrary code tools:

- Photoshop: `photoshop_execute_script`
- Illustrator: `run`

These prompts are Codex tool approvals. They are independent from Windows administrator rights and filesystem access. A user can grant full filesystem access and still receive a prompt before a tool mutates a live Adobe document.

## Diagnostics

Run these scripts from the plugin root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\preflight.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\health-check.ps1
```

The checks do not execute arbitrary ExtendScript and do not capture the screen.
