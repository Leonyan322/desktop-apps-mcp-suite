[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$runtime_root = Get-ExcelRuntimeRoot
$local_app_data = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$expected_parent = [System.IO.Path]::GetFullPath(
    (Join-Path $local_app_data 'desktop-apps-mcp-suite\office')
)
$resolved_parent = [System.IO.Path]::GetFullPath((Split-Path -Parent $runtime_root))
if ($resolved_parent -ne $expected_parent -or (Split-Path -Leaf $runtime_root) -ne 'excel') {
    throw "拒绝删除非预期路径：$runtime_root"
}

if (Test-Path -LiteralPath $runtime_root) {
    $runtime_item = Get-Item -LiteralPath $runtime_root -Force
    if (($runtime_item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "拒绝删除重解析点：$runtime_root"
    }
    if ($PSCmdlet.ShouldProcess($runtime_root, '删除 Excel MCP 运行时')) {
        Remove-Item -LiteralPath $runtime_root -Recurse -Force
        Write-Host "已删除 Excel MCP 运行时：$runtime_root"
    }
}
else {
    Write-Host "Excel MCP 运行时不存在：$runtime_root"
}

Write-Host '未删除任何 Excel 工作簿，也未关闭 Excel。'
