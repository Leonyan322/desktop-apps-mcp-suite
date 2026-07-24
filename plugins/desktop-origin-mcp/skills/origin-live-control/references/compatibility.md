# Compatibility

## Host requirements

- Windows 10 or Windows 11, 64-bit.
- Windows PowerShell 5.1 or PowerShell 7.
- Git available as `git.exe`.
- A 64-bit CPython 3.10, 3.11, or 3.12 installation. Python 3.12 is the validated version.
- A valid local Origin license.

The installer stores the isolated runtime under `%LOCALAPPDATA%\desktop-apps-mcp-suite\engineering\origin`. It does not copy developer virtual environments, test projects, or absolute application paths.

## Origin discovery and versions

- Upstream reports Origin Pro 2020 compatibility.
- Origin 2021 has been validated with this plugin route.
- Other releases may work through the same `Origin.ApplicationSI` COM server but are not verified.

Discovery resolves `HKCR\Origin.ApplicationSI\CLSID`, then parses the CLSID `LocalServer32` command. Both quoted executable paths and unquoted paths with trailing arguments are supported. If Origin is installed but the COM entry is absent, run Origin once as administrator to register its Automation Server, then rerun the health check.

The launcher uses these safety settings:

```text
ORIGIN_PRO_MCP_USE_DAEMON=0
ORIGIN_PRO_MCP_ATTACH=1
ORIGIN_PRO_MCP_VISIBLE=1
ORIGIN_PRO_MCP_DIALOG_AUTODISMISS=off
ORIGIN_PRO_MCP_AUTOSAVE=off
ORIGIN_PRO_MCP_REAP_CLOSE=off
ORIGIN_PRO_MCP_SWEEP_ORPHANS=off
```

## Approval policy

The server uses `default_tools_approval_mode: prompt`, so every unlisted tool requests Codex approval before execution.

Only these read-only queries are automatically approved: `list_worksheets`, `get_worksheet_data`, `get_matrix_data`, `list_fitting_functions`, `get_labtalk_variable`, `list_skills`, and `get_skill`. `run_labtalk` and every write, delete, import, export, save, load, or project-replacement operation stay on prompt.

## Diagnostics

Run from the plugin root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\preflight.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\health-check.ps1
```

The MCP probe performs only `initialize` and `tools/list`; it does not call a business tool.
