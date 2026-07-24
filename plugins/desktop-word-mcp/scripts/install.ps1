param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$python_info = Find-Python312
if ($null -eq $python_info) {
    throw '未找到 Python 3.12。请先安装 Python 3.12。'
}
if (-not (Test-ComRegistration -ProgId 'Word.Application')) {
    throw '未检测到 Word COM 注册：Word.Application'
}

$runtime_root = Get-WordRuntimeRoot
New-Item -ItemType Directory -Force -Path $runtime_root | Out-Null
$venv_path = Join-Path $runtime_root '.venv'
$venv_python = Join-Path $venv_path 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venv_python -PathType Leaf)) {
    $venv_arguments = @($python_info.PrefixArguments) + @('-m', 'venv', $venv_path)
    Invoke-CheckedCommand -FilePath $python_info.FilePath -Arguments $venv_arguments -FailureMessage "创建虚拟环境失败：$venv_path"
}

$pip_arguments = @(
    '-m', 'pip', 'install', '--disable-pip-version-check',
    '-i', 'https://pypi.tuna.tsinghua.edu.cn/simple',
    'officemcp==1.0.5',
    'fastmcp==2.3.3',
    'mcp==1.28.1',
    'pywin32==312'
)
Invoke-CheckedCommand -FilePath $venv_python -Arguments $pip_arguments -FailureMessage '安装 Word MCP 运行时失败'

& (Join-Path $PSScriptRoot 'health-check.ps1')
if ($LASTEXITCODE -ne 0) {
    throw '安装完成，但健康检查未通过。'
}

Write-Host "Word MCP 运行时已安装到：$runtime_root"
