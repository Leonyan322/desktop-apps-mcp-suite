# Compatibility

## Host requirements

- Windows 10 or Windows 11, 64-bit.
- Windows PowerShell 5.1 or PowerShell 7.
- Git available as `git.exe`.
- A 64-bit CPython 3.10, 3.11, or 3.12 installation. Python 3.12 is the validated version.
- A valid local license for each controlled desktop application.

The installer stores both isolated runtimes under `%LOCALAPPDATA%\desktop-apps-mcp-suite\engineering`. It does not copy the developer's virtual environments, test projects, or absolute application paths.

## Origin

- Upstream reports Origin Pro 2020 compatibility.
- Origin 2021 has been validated with this plugin route.
- Other releases may work through the same `Origin.ApplicationSI` COM server but are not verified.

Discovery resolves `HKCR\Origin.ApplicationSI\CLSID`, then the CLSID `LocalServer32` value. If Origin is installed but the COM entry is absent, run Origin once as administrator to register its Automation Server, then rerun the health check.

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

## Ansys HFSS

- Ansys Electronics Desktop 2023 R1 is required by the pinned compatibility patch.
- PyAEDT 0.25.1 and pandas 2.3.3 are pinned.
- The validated Python version is 3.12.1.

Discovery checks `ANSYSEM_ROOT231` at process, user, and machine scope, then reads:

```text
HKLM\SOFTWARE\Ansoft\ElectronicsDesktop\2023.1\Desktop\InstallationDirectory
```

The resolved directory must contain `ansysedt.exe`. Student-edition-only and other AEDT releases are not selected automatically.

HFSS state is stored in the runtime directory, separate from the plugin and user projects. Analysis, restart, and application-stop tools remain disabled.

## Approval policy

Both servers use `default_tools_approval_mode: prompt`, so all unlisted tools request Codex approval before execution.

Origin automatically approves only these read-only queries: `list_worksheets`, `get_worksheet_data`, `get_matrix_data`, `list_fitting_functions`, `get_labtalk_variable`, `list_skills`, and `get_skill`. `run_labtalk` and every write, delete, import, export, save, load, or project-replacement operation stay on prompt.

HFSS automatically approves only `hfss_get_process_status`, `hfss_query_modeling_knowledge`, and `hfss_get_modeling_knowledge_status`. `hfss_stop_app`, `hfss_restart_app`, and `hfss_run_analysis` are disabled in the client policy, while restart and analysis are also blocked by the patched server implementation.

## Diagnostics

Run from the plugin root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\preflight.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\health-check.ps1
```

Neither diagnostic connects to COM, launches a desktop application, nor changes a project.
