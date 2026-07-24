param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$node_info = Find-NodeCommand -MinimumMajorVersion 20
$npm_path = Find-NpmCommand
if ($null -eq $node_info -or $null -eq $npm_path) {
    throw '未找到 Node.js 20+ 或 npm。'
}
if (-not (Test-ComRegistration -ProgId 'Excel.Application')) {
    throw '未检测到 Excel COM 注册：Excel.Application'
}

$runtime_root = Get-ExcelRuntimeRoot
New-Item -ItemType Directory -Force -Path $runtime_root | Out-Null
$npm_arguments = @(
    'install',
    '--prefix', $runtime_root,
    '--save-exact',
    '--ignore-scripts',
    '@negokaz/excel-mcp-server@0.12.0'
)
Invoke-CheckedCommand -FilePath $npm_path -Arguments $npm_arguments -FailureMessage '安装 Excel MCP 运行时失败'

& (Join-Path $PSScriptRoot 'health-check.ps1')
if ($LASTEXITCODE -ne 0) {
    throw '安装完成，但健康检查未通过。'
}

Write-Host "Excel MCP 运行时已安装到：$runtime_root"
