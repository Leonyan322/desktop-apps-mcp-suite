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

# 参数：Python 路径及期望的包版本；返回值：版本是否全部匹配。
function Test-PythonPackages {
    param(
        [Parameter(Mandatory = $true)][string]$PythonPath,
        [Parameter(Mandatory = $true)][hashtable]$ExpectedVersions
    )

    if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
        return [pscustomobject]@{ Passed = $false; Details = "不存在：$PythonPath" }
    }

    $package_names = @($ExpectedVersions.Keys | Sort-Object)
    $python_code = 'import importlib.metadata as m,sys; print(m.version(sys.argv[1]))'
    try {
        $actual_versions = @{}
        foreach ($package_name in $package_names) {
            $actual_version = (& $PythonPath -c $python_code $package_name 2>$null).Trim()
            if ($LASTEXITCODE -ne 0) {
                return [pscustomobject]@{ Passed = $false; Details = "读取包版本失败：$package_name" }
            }
            $actual_versions[$package_name] = $actual_version
        }

        $mismatches = [System.Collections.Generic.List[string]]::new()
        foreach ($package_name in $package_names) {
            if ($actual_versions[$package_name] -ne $ExpectedVersions[$package_name]) {
                $mismatches.Add("$package_name=$($actual_versions[$package_name])，期望 $($ExpectedVersions[$package_name])")
            }
        }
        if ($mismatches.Count -gt 0) {
            return [pscustomobject]@{ Passed = $false; Details = ($mismatches -join '；') }
        }
        $version_text = ($package_names | ForEach-Object { "$_=$($actual_versions[$_])" }) -join ';'
        return [pscustomobject]@{ Passed = $true; Details = $version_text }
    }
    catch {
        return [pscustomobject]@{ Passed = $false; Details = $_.Exception.Message }
    }
}

$runtime_root = Get-OfficeRuntimeRoot
$ppt_python = Join-Path $runtime_root 'ppt\.venv\Scripts\python.exe'
$ppt_result = Test-PythonPackages -PythonPath $ppt_python -ExpectedVersions @{
    'ppt-mcp' = '1.6.0'
    'mcp' = '1.28.1'
    'pydantic' = '2.13.4'
    'pywin32' = '312'
}
Add-HealthResult -Name 'PowerPoint MCP' -Passed $ppt_result.Passed -Details $ppt_result.Details

$officemcp_python = Join-Path $runtime_root 'officemcp\.venv\Scripts\python.exe'
$officemcp_result = Test-PythonPackages -PythonPath $officemcp_python -ExpectedVersions @{
    'officemcp' = '1.0.5'
    'fastmcp' = '2.3.3'
    'mcp' = '1.28.1'
    'pywin32' = '312'
}
Add-HealthResult -Name 'OfficeMCP' -Passed $officemcp_result.Passed -Details $officemcp_result.Details

$excel_package_path = Join-Path $runtime_root 'excel\node_modules\@negokaz\excel-mcp-server\package.json'
if (Test-Path -LiteralPath $excel_package_path -PathType Leaf) {
    try {
        $excel_package = Get-Content -Raw -LiteralPath $excel_package_path | ConvertFrom-Json
        $excel_ok = ($excel_package.version -eq '0.12.0')
        Add-HealthResult -Name 'Excel MCP' -Passed $excel_ok -Details "@negokaz/excel-mcp-server=$($excel_package.version)"
    }
    catch {
        Add-HealthResult -Name 'Excel MCP' -Passed $false -Details $_.Exception.Message
    }
}
else {
    Add-HealthResult -Name 'Excel MCP' -Passed $false -Details "不存在：$excel_package_path"
}

$com_checks = @(
    @{ Name = 'PowerPoint COM'; ProgId = 'PowerPoint.Application' },
    @{ Name = 'Excel COM'; ProgId = 'Excel.Application' },
    @{ Name = 'Word COM'; ProgId = 'Word.Application' }
)
foreach ($com_check in $com_checks) {
    $registered = Test-ComRegistration -ProgId $com_check.ProgId
    Add-HealthResult -Name $com_check.Name -Passed $registered -Details $(if ($registered) { $com_check.ProgId } else { '未注册。' })
}

$probe_python = Find-Python312
$probe_script = Join-Path $PSScriptRoot 'mcp_stdio_probe.py'
if ($null -eq $probe_python) {
    Add-HealthResult -Name 'MCP 协议探针' -Passed $false -Details '未找到 Python 3.12。'
}
else {
    $plugin_root = Split-Path -Parent $PSScriptRoot
    $server_probes = @(
        @{ Name = 'ppt'; Script = 'start-ppt.ps1' },
        @{ Name = 'excel'; Script = 'start-excel.ps1' },
        @{ Name = 'officemcp'; Script = 'start-officemcp.ps1' }
    )
    foreach ($server_probe in $server_probes) {
        $start_script = Join-Path $PSScriptRoot $server_probe.Script
        $probe_arguments = @($probe_python.PrefixArguments) + @(
            $probe_script,
            '--name', $server_probe.Name,
            '--timeout', '45',
            '--cwd', $plugin_root,
            '--',
            'powershell.exe',
            '-NoLogo',
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            $start_script
        )
        $previous_error_action = $ErrorActionPreference
        try {
            # 非零退出由健康结果处理，不让 PowerShell 把探针 stderr 提前升级为终止错误。
            $ErrorActionPreference = 'Continue'
            $probe_output = (& $probe_python.FilePath @probe_arguments 2>&1) -join ' '
            $probe_exit_code = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previous_error_action
        }
        $probe_passed = ($probe_exit_code -eq 0)
        Add-HealthResult -Name "MCP $($server_probe.Name)" -Passed $probe_passed -Details $probe_output
    }
}

$results | Format-Table -AutoSize
if ($results.Status -contains 'FAIL') {
    Write-Error 'Office MCP 健康检查未通过。可重新运行 install.ps1 修复运行时。'
    exit 1
}

Write-Host '健康检查通过。注册表检查不会触发 Office 首次启动或激活弹窗。'
