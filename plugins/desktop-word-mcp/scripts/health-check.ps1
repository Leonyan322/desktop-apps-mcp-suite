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

# 参数：Python 路径及期望包版本；返回值：版本检查结果。
function Test-PythonPackages {
    param(
        [Parameter(Mandatory = $true)][string]$PythonPath,
        [Parameter(Mandatory = $true)][hashtable]$ExpectedVersions
    )
    if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
        return [pscustomobject]@{ Passed = $false; Details = "不存在：$PythonPath" }
    }
    try {
        $actual_versions = @{}
        foreach ($package_name in @($ExpectedVersions.Keys | Sort-Object)) {
            $actual_version = (& $PythonPath -c 'import importlib.metadata as m,sys; print(m.version(sys.argv[1]))' $package_name 2>$null).Trim()
            if ($LASTEXITCODE -ne 0) {
                return [pscustomobject]@{ Passed = $false; Details = "读取包版本失败：$package_name" }
            }
            $actual_versions[$package_name] = $actual_version
        }
        $mismatches = @($ExpectedVersions.Keys | Where-Object { $actual_versions[$_] -ne $ExpectedVersions[$_] } | ForEach-Object { "$_=$($actual_versions[$_])，期望 $($ExpectedVersions[$_])" })
        if ($mismatches.Count -gt 0) {
            return [pscustomobject]@{ Passed = $false; Details = ($mismatches -join '；') }
        }
        $details = (@($ExpectedVersions.Keys | Sort-Object) | ForEach-Object { "$_=$($actual_versions[$_])" }) -join ';'
        return [pscustomobject]@{ Passed = $true; Details = $details }
    }
    catch {
        return [pscustomobject]@{ Passed = $false; Details = $_.Exception.Message }
    }
}

$runtime_python = Join-Path (Get-WordRuntimeRoot) '.venv\Scripts\python.exe'
$package_result = Test-PythonPackages -PythonPath $runtime_python -ExpectedVersions @{
    'officemcp' = '1.0.5'
    'fastmcp' = '2.3.3'
    'mcp' = '1.28.1'
    'pywin32' = '312'
}
Add-HealthResult -Name 'Word MCP' -Passed $package_result.Passed -Details $package_result.Details

$registered = Test-ComRegistration -ProgId 'Word.Application'
Add-HealthResult -Name 'Word COM' -Passed $registered -Details $(if ($registered) { 'Word.Application' } else { '未注册。' })

$probe_python = Find-Python312
if ($null -eq $probe_python) {
    Add-HealthResult -Name 'MCP word' -Passed $false -Details '未找到 Python 3.12。'
}
else {
    $plugin_root = Split-Path -Parent $PSScriptRoot
    $probe_arguments = @($probe_python.PrefixArguments) + @(
        (Join-Path $PSScriptRoot 'mcp_stdio_probe.py'),
        '--name', 'word', '--timeout', '45', '--cwd', $plugin_root, '--',
        'powershell.exe', '-NoLogo', '-NoProfile', '-NonInteractive',
        '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'start-word.ps1')
    )
    $previous_error_action = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $probe_output = (& $probe_python.FilePath @probe_arguments 2>&1) -join ' '
        $probe_exit_code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous_error_action
    }
    Add-HealthResult -Name 'MCP word' -Passed ($probe_exit_code -eq 0) -Details $probe_output
}

$results | Format-Table -AutoSize
if ($results.Status -contains 'FAIL') {
    Write-Error 'Word MCP 健康检查未通过。可重新运行 install.ps1 修复运行时。'
    exit 1
}

Write-Host '健康检查通过。只执行了 MCP initialize 与 tools/list，未调用文档业务工具。'
