# Compatibility

## Host requirements

- Windows 10 or Windows 11, 64-bit.
- Windows PowerShell 5.1 or PowerShell 7.
- Git available as `git.exe`.
- A 64-bit CPython 3.10, 3.11, or 3.12 installation. Python 3.12.1 is the validated version.
- Ansys Electronics Desktop 2023 R1 and a valid local license.

The installer stores the isolated runtime under `%LOCALAPPDATA%\desktop-apps-mcp-suite\engineering\hfss`. It does not copy developer virtual environments, test projects, or absolute application paths.

## AEDT discovery and versions

- Ansys Electronics Desktop 2023 R1 is required by the pinned compatibility patch.
- PyAEDT 0.25.1 and pandas 2.3.3 are pinned.
- Student-edition-only and other AEDT releases are not selected automatically.

Discovery checks `ANSYSEM_ROOT231` at process, user, and machine scope, then reads:

```text
HKLM\SOFTWARE\Ansoft\ElectronicsDesktop\2023.1\Desktop\InstallationDirectory
```

The resolved directory must contain `ansysedt.exe`. HFSS runtime state is stored separately from the plugin and user projects.

## Source integrity and safety patch

The launcher verifies the exact upstream remote and commit, confirms that the compatibility patch can be cleanly reversed, allows changes only to `hfss_server.py` and `requirements.txt`, and compares both patched files against newline-normalized SHA-256 fingerprints. Analysis, restart, and application-stop tools remain disabled.

## Approval policy

The server uses `default_tools_approval_mode: prompt`, so every unlisted tool requests Codex approval before execution.

Only `hfss_get_process_status`, `hfss_query_modeling_knowledge`, and `hfss_get_modeling_knowledge_status` are automatically approved. `hfss_stop_app`, `hfss_restart_app`, and `hfss_run_analysis` are disabled in the client policy, while restart and analysis are also blocked by the patched server implementation.

## Diagnostics

Run from the plugin root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\preflight.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\health-check.ps1
```

The MCP probe performs only `initialize` and `tools/list`; it does not call a business tool.
