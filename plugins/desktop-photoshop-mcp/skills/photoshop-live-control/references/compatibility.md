# Photoshop MCP compatibility and safety

## Supported profile

This plugin targets 64-bit Windows with Photoshop 2020 installed and registered for COM automation.

| Component | Pinned source | Runtime requirement |
| --- | --- | --- |
| Photoshop MCP | `alisaitteke/photoshop-mcp` commit `152f8937be98b352c40ab5b525829a50d022f283` | Node.js 18 or newer; Windows Script Host `cscript.exe`; Photoshop COM registration |

The managed runtime is `%LOCALAPPDATA%\desktop-apps-mcp-suite\adobe\photoshop-mcp`. The scripts resolve this location at runtime and do not depend on a user name or drive letter.

The pinned upstream commit does not include an npm lockfile. The plugin supplies a separately audited lockfile, verifies SHA-256 `CB86D1E4C6005E5D4DF1DBE705AB8A0DE2CDC5F070B025F5AD342FCEB2A8FD51`, copies it into the runtime checkout, and installs with `npm ci`.

## Windows discovery

Discovery checks `PHOTOSHOP_PATH`, registered App Paths, Adobe Photoshop registry branches, the current `Photoshop.Application` ProgID and its dynamic CLSID/`LocalServer32`, then Program Files candidates. The launcher passes the resolved executable through `PHOTOSHOP_PATH`.

## Photoshop 2020 restrictions

The pinned upstream detector may parse the path-derived string `2020` as a very large numeric major version and report newer capabilities incorrectly. Keep these client-side blocks:

- `photoshop_generative_fill`
- `photoshop_generative_remove`
- `photoshop_generative_expand`
- `photoshop_generative_upscale`
- `photoshop_generate_image`
- `photoshop_neural_filter`
- `photoshop_sky_replacement`
- `photoshop_recipe_sky_blend`

The launcher sets `ANALYTICS_DISABLED=1` and `POSTHOG_DISABLED=1`. It does not start the optional web UI or UXP bridge.

## Approval prompts

The upstream server omits MCP read-only/destructive annotations. The plugin defaults write operations to approval and explicitly prompts for `photoshop_execute_script`. This is independent from Windows administrator rights and filesystem access.

Run `scripts/preflight.ps1` and `scripts/health-check.ps1` from the plugin root for diagnostics. The checks do not execute ExtendScript or capture the screen.
