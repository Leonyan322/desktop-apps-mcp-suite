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

$paths = Get-OriginPaths
$results = @()

$origin = Get-OriginInstallation
$results += Add-HealthResult -Name "Origin COM" -Ok ($null -ne $origin) -Detail $(if ($null -ne $origin) { $origin.Executable } else { "Origin.ApplicationSI is not registered" })

$source_ok = $false
$source_detail = "Origin source checkout is missing"
if ($null -ne (Get-Command "git.exe" -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-Path $paths.Source ".git"))) {
    try {
        Initialize-FixedGitCheckout -Destination $paths.Source
        $source_ok = $true
        $source_detail = $script:origin_commit
    } catch {
        $source_detail = $_.Exception.Message
    }
}
$results += Add-HealthResult -Name "Origin pinned source integrity" -Ok $source_ok -Detail $source_detail

$origin_python = Join-Path $paths.Venv "Scripts\python.exe"
$origin_runtime_ok = Test-Path -LiteralPath $origin_python -PathType Leaf
if ($origin_runtime_ok) {
    $origin_version = @(& $origin_python -c "import importlib.metadata as m; print(m.version('origin-pro-mcp'))" 2>$null)
    $origin_runtime_ok = $LASTEXITCODE -eq 0 -and $origin_version.Count -eq 1 -and $origin_version[0] -eq "0.3.1"
}
$results += Add-HealthResult -Name "Origin Python runtime" -Ok $origin_runtime_ok -Detail $(if ($origin_runtime_ok) { $origin_python } else { "Missing or package version is not 0.3.1" })

$mcp_health_script = Join-Path $PSScriptRoot "mcp-health.py"
$origin_mcp_ok = $false
$origin_mcp_detail = "Origin Python runtime or source integrity is unavailable"
if ($origin_runtime_ok -and $source_ok -and $null -ne $origin) {
    $origin_probe = Invoke-McpHealthProbe -PythonPath $origin_python -StartScript (Join-Path $PSScriptRoot "start-origin.ps1")
    $origin_mcp_ok = $origin_probe.ExitCode -eq 0
    $origin_mcp_detail = $origin_probe.Detail
}
$results += Add-HealthResult -Name "Origin MCP initialize/list_tools" -Ok $origin_mcp_ok -Detail $origin_mcp_detail

$results | Format-Table -AutoSize
if (@($results | Where-Object { -not $_.Ok }).Count -gt 0) {
    exit 1
}

exit 0
