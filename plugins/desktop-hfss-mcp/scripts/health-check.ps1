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
    运行只读 MCP 初始化与工具发现探针。
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

$paths = Get-HfssPaths
$results = @()

$aedt = Get-AedtInstallation
$results += Add-HealthResult -Name "AEDT 2023 R1" -Ok ($null -ne $aedt) -Detail $(if ($null -ne $aedt) { $aedt.Executable } else { "AEDT 2023.1 was not found" })

$source_ok = $false
$source_detail = "HFSS source checkout is missing"
if ($null -ne (Get-Command "git.exe" -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-Path $paths.Source ".git"))) {
    try {
        Assert-HfssPatchedCheckout -Destination $paths.Source -PatchPath (Join-Path $PSScriptRoot "hfss-2023r1.patch")
        $source_ok = $true
        $source_detail = $script:hfss_commit
    } catch {
        $source_detail = $_.Exception.Message
    }
}
$results += Add-HealthResult -Name "HFSS patched source integrity" -Ok $source_ok -Detail $source_detail

$hfss_python = Join-Path $paths.Venv "Scripts\python.exe"
$hfss_runtime_ok = Test-Path -LiteralPath $hfss_python -PathType Leaf
if ($hfss_runtime_ok) {
    $hfss_versions = @(& $hfss_python -c "import importlib.metadata as m; print(m.version('pyaedt')); print(m.version('pandas'))" 2>$null)
    $hfss_runtime_ok = $LASTEXITCODE -eq 0 -and $hfss_versions.Count -eq 2 -and $hfss_versions[0] -eq "0.25.1" -and $hfss_versions[1] -eq "2.3.3"
}
$results += Add-HealthResult -Name "HFSS Python runtime" -Ok $hfss_runtime_ok -Detail $(if ($hfss_runtime_ok) { $hfss_python } else { "Missing or dependency versions do not match" })

$mcp_health_script = Join-Path $PSScriptRoot "mcp-health.py"
$hfss_mcp_ok = $false
$hfss_mcp_detail = "HFSS Python runtime or source integrity is unavailable"
if ($hfss_runtime_ok -and $source_ok -and $null -ne $aedt) {
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
