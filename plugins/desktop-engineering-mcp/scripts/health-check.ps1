[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot "common.ps1")

function Add-HealthResult {
    <#
    .SYNOPSIS
    创建一项健康检查结果。
    .PARAMETER Name
    检查名称。
    .PARAMETER Ok
    是否通过。
    .PARAMETER Detail
    结果详情。
    .OUTPUTS
    健康检查结果对象。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Ok,
        [Parameter(Mandatory = $true)][string]$Detail
    )

    [pscustomobject]@{ Name = $Name; Ok = $Ok; Detail = $Detail }
}

function Invoke-McpHealthProbe {
    <#
    .SYNOPSIS
    运行 MCP 探针并保留 stderr 诊断，但不让 PowerShell 5.1 把原生警告提升为终止错误。
    .PARAMETER PythonPath
    虚拟环境中的 python.exe。
    .PARAMETER StartScript
    MCP PowerShell 启动脚本。
    .OUTPUTS
    包含退出码与合并诊断文本的对象。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$PythonPath,
        [Parameter(Mandatory = $true)][string]$StartScript
    )

    $saved_error_action = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = @(& $PythonPath $mcp_health_script $StartScript 2>&1)
        $exit_code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $saved_error_action
    }

    [pscustomobject]@{
        ExitCode = $exit_code
        Detail = ($output -join " ").Trim()
    }
}

$paths = Get-EngineeringPaths
$results = @()

$origin = Get-OriginInstallation
$results += Add-HealthResult -Name "Origin COM" -Ok ($null -ne $origin) -Detail $(if ($null -ne $origin) { $origin.Executable } else { "Origin.ApplicationSI is not registered" })
$aedt = Get-AedtInstallation
$results += Add-HealthResult -Name "AEDT 2023 R1" -Ok ($null -ne $aedt) -Detail $(if ($null -ne $aedt) { $aedt.Executable } else { "AEDT 2023.1 was not found" })

$origin_head = "missing"
if (Test-Path -LiteralPath (Join-Path $paths.OriginSource ".git")) {
    $origin_head = (& git.exe -C $paths.OriginSource rev-parse HEAD 2>$null).Trim()
}
$results += Add-HealthResult -Name "Origin pinned commit" -Ok ($origin_head -eq $script:origin_commit) -Detail $origin_head

$origin_python = Join-Path $paths.OriginVenv "Scripts\python.exe"
$origin_runtime_ok = Test-Path -LiteralPath $origin_python -PathType Leaf
if ($origin_runtime_ok) {
    $origin_version = @(& $origin_python -c "import importlib.metadata as m; print(m.version('origin-pro-mcp'))" 2>$null)
    $origin_runtime_ok = $LASTEXITCODE -eq 0 -and $origin_version.Count -eq 1 -and $origin_version[0] -eq "0.3.1"
}
$results += Add-HealthResult -Name "Origin Python runtime" -Ok $origin_runtime_ok -Detail $(if ($origin_runtime_ok) { $origin_python } else { "Missing or package version is not 0.3.1" })

$mcp_health_script = Join-Path $PSScriptRoot "mcp-health.py"
$origin_mcp_ok = $false
$origin_mcp_detail = "Origin Python runtime is unavailable"
if ($origin_runtime_ok) {
    $origin_probe = Invoke-McpHealthProbe -PythonPath $origin_python -StartScript (Join-Path $PSScriptRoot "start-origin.ps1")
    $origin_mcp_ok = $origin_probe.ExitCode -eq 0
    $origin_mcp_detail = $origin_probe.Detail
}
$results += Add-HealthResult -Name "Origin MCP initialize/list_tools" -Ok $origin_mcp_ok -Detail $origin_mcp_detail

$hfss_head = "missing"
if (Test-Path -LiteralPath (Join-Path $paths.HfssSource ".git")) {
    $hfss_head = (& git.exe -C $paths.HfssSource rev-parse HEAD 2>$null).Trim()
}
$results += Add-HealthResult -Name "HFSS pinned commit" -Ok ($hfss_head -eq $script:hfss_commit) -Detail $hfss_head

$hfss_server = Join-Path $paths.HfssSource "hfss_server.py"
$hfss_patch_ok = $false
if (Test-Path -LiteralPath $hfss_server -PathType Leaf) {
    $server_text = Get-Content -LiteralPath $hfss_server -Raw -Encoding UTF8
    $hfss_patch_ok = $server_text.Contains('AEDT_VERSION = "2023.1"') -and
        $server_text.Contains("Disabled for safety. Run analysis manually in AEDT") -and
        $server_text.Contains("AEDT remains open")
}
$results += Add-HealthResult -Name "HFSS safety patch" -Ok $hfss_patch_ok -Detail $(if ($hfss_patch_ok) { $hfss_server } else { "Patch markers are missing" })

$hfss_python = Join-Path $paths.HfssVenv "Scripts\python.exe"
$hfss_runtime_ok = Test-Path -LiteralPath $hfss_python -PathType Leaf
if ($hfss_runtime_ok) {
    $hfss_versions = @(& $hfss_python -c "import importlib.metadata as m; print(m.version('pyaedt')); print(m.version('pandas'))" 2>$null)
    $hfss_runtime_ok = $LASTEXITCODE -eq 0 -and $hfss_versions.Count -eq 2 -and $hfss_versions[0] -eq "0.25.1" -and $hfss_versions[1] -eq "2.3.3"
}
$results += Add-HealthResult -Name "HFSS Python runtime" -Ok $hfss_runtime_ok -Detail $(if ($hfss_runtime_ok) { $hfss_python } else { "Missing or dependency versions do not match" })

$hfss_mcp_ok = $false
$hfss_mcp_detail = "HFSS Python runtime is unavailable"
if ($hfss_runtime_ok) {
    $hfss_probe = Invoke-McpHealthProbe -PythonPath $hfss_python -StartScript (Join-Path $PSScriptRoot "start-hfss.ps1")
    $hfss_mcp_ok = $hfss_probe.ExitCode -eq 0
    $hfss_mcp_detail = $hfss_probe.Detail
}
$results += Add-HealthResult -Name "HFSS MCP initialize/list_tools" -Ok $hfss_mcp_ok -Detail $hfss_mcp_detail

$results | Format-Table -AutoSize
if (@($results | Where-Object { -not $_.Ok }).Count -gt 0) {
    exit 1
}

exit 0
