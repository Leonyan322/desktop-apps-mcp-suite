param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$python_info = Find-Python312
if ($null -eq $python_info) {
    throw '未找到 Python 3.12。请先安装 Python 3.12。'
}

$node_info = Find-NodeCommand -MinimumMajorVersion 20
$npm_path = Find-NpmCommand
if ($null -eq $node_info -or $null -eq $npm_path) {
    throw '未找到 Node.js 20+ 或 npm。'
}

$required_prog_ids = @('PowerPoint.Application', 'Excel.Application', 'Word.Application')
foreach ($prog_id in $required_prog_ids) {
    if (-not (Test-ComRegistration -ProgId $prog_id)) {
        throw "未检测到 Office COM 注册：$prog_id"
    }
}

$runtime_root = Get-OfficeRuntimeRoot
$ppt_root = Join-Path $runtime_root 'ppt'
$excel_root = Join-Path $runtime_root 'excel'
$officemcp_root = Join-Path $runtime_root 'officemcp'
New-Item -ItemType Directory -Force -Path $ppt_root, $excel_root, $officemcp_root | Out-Null

# 参数：目标虚拟环境目录；返回值：虚拟环境中的 python.exe。
function Ensure-VirtualEnvironment {
    param([Parameter(Mandatory = $true)][string]$VenvPath)

    $venv_python = Join-Path $VenvPath 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $venv_python -PathType Leaf)) {
        $venv_arguments = @($python_info.PrefixArguments) + @('-m', 'venv', $VenvPath)
        Invoke-CheckedCommand -FilePath $python_info.FilePath -Arguments $venv_arguments -FailureMessage "创建虚拟环境失败：$VenvPath"
    }
    return $venv_python
}

$pip_index = 'https://pypi.tuna.tsinghua.edu.cn/simple'

$ppt_python = Ensure-VirtualEnvironment -VenvPath (Join-Path $ppt_root '.venv')
$ppt_packages = @(
    '-m', 'pip', 'install', '--disable-pip-version-check',
    '-i', $pip_index,
    'ppt-mcp==1.6.0',
    'mcp==1.28.1',
    'pydantic==2.13.4',
    'pywin32==312'
)
Invoke-CheckedCommand -FilePath $ppt_python -Arguments $ppt_packages -FailureMessage '安装 PowerPoint MCP 运行时失败'

$officemcp_python = Ensure-VirtualEnvironment -VenvPath (Join-Path $officemcp_root '.venv')
$officemcp_packages = @(
    '-m', 'pip', 'install', '--disable-pip-version-check',
    '-i', $pip_index,
    'officemcp==1.0.5',
    'fastmcp==2.3.3',
    'mcp==1.28.1',
    'pywin32==312'
)
Invoke-CheckedCommand -FilePath $officemcp_python -Arguments $officemcp_packages -FailureMessage '安装 OfficeMCP 运行时失败'

$npm_arguments = @(
    'install',
    '--prefix', $excel_root,
    '--save-exact',
    '--ignore-scripts',
    '@negokaz/excel-mcp-server@0.12.0'
)
Invoke-CheckedCommand -FilePath $npm_path -Arguments $npm_arguments -FailureMessage '安装 Excel MCP 运行时失败'

& (Join-Path $PSScriptRoot 'health-check.ps1')
if ($LASTEXITCODE -ne 0) {
    throw '安装完成，但健康检查未通过。'
}

Write-Host "Office MCP 运行时已安装到：$runtime_root"
