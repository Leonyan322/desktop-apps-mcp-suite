param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$results = [System.Collections.Generic.List[object]]::new()

# 参数：检查项、状态和说明；返回值：无。
function Add-HealthResult {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [Parameter(Mandatory = $true)][string]$Details
    )
    $results.Add([pscustomobject]@{
        Check = $Name
        Status = if ($Passed) { 'OK' } else { 'FAIL' }
        Details = $Details
    })
}

$runtime_root = Get-ExcelRuntimeRoot
$package_path = Join-Path $runtime_root 'node_modules\@negokaz\excel-mcp-server\package.json'
if (Test-Path -LiteralPath $package_path -PathType Leaf) {
    try {
        $package = Get-Content -Raw -LiteralPath $package_path | ConvertFrom-Json
        Add-HealthResult -Name 'Excel MCP' -Passed ($package.version -eq '0.12.0') -Details "@negokaz/excel-mcp-server=$($package.version)"
    }
    catch {
        Add-HealthResult -Name 'Excel MCP' -Passed $false -Details $_.Exception.Message
    }
}
else {
    Add-HealthResult -Name 'Excel MCP' -Passed $false -Details "不存在：$package_path"
}

$registered = Test-ComRegistration -ProgId 'Excel.Application'
Add-HealthResult -Name 'Excel COM' -Passed $registered -Details $(if ($registered) { 'Excel.Application' } else { '未注册。' })

$node_info = Find-NodeCommand -MinimumMajorVersion 20
if ($null -eq $node_info) {
    Add-HealthResult -Name 'MCP excel' -Passed $false -Details '未找到 Node.js 20 或更高版本。'
}
else {
    $plugin_root = Split-Path -Parent $PSScriptRoot
    $probe_arguments = @(
        (Join-Path $PSScriptRoot 'mcp_stdio_probe.mjs'),
        '--name', 'excel', '--timeout', '45', '--cwd', $plugin_root, '--',
        'powershell.exe', '-NoLogo', '-NoProfile', '-NonInteractive',
        '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'start-excel.ps1')
    )
    $previous_error_action = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $probe_output = (& $node_info.FilePath @probe_arguments 2>&1) -join ' '
        $probe_exit_code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous_error_action
    }
    Add-HealthResult -Name 'MCP excel' -Passed ($probe_exit_code -eq 0) -Details $probe_output
}

$results | Format-Table -AutoSize
if ($results.Status -contains 'FAIL') {
    Write-Error 'Excel MCP 健康检查未通过。可重新运行 install.ps1 修复运行时。'
    exit 1
}

Write-Host '健康检查通过。只执行了 MCP initialize 与 tools/list，未调用工作簿业务工具。'
