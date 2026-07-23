[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$runtime_root = [System.IO.Path]::GetFullPath((Get-AdobeRuntimeRoot)).TrimEnd('\')
$local_app_data = [System.IO.Path]::GetFullPath(
    [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
).TrimEnd('\')
$expected_root = [System.IO.Path]::GetFullPath(
    (Join-Path $local_app_data "desktop-apps-mcp-suite\adobe")
).TrimEnd('\')

# 删除前验证完整绝对路径，防止环境变量异常扩大范围。
if (-not $runtime_root.Equals($expected_root, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "运行时目录校验失败，拒绝删除：$runtime_root"
}
if ((Split-Path -Leaf $runtime_root) -ne "adobe") {
    throw "运行时目录名称异常，拒绝删除：$runtime_root"
}

if (-not (Test-Path -LiteralPath $runtime_root)) {
    Write-Output "Adobe MCP 运行时不存在，无需卸载。"
    exit 0
}

$runtime_item = Get-Item -LiteralPath $runtime_root -Force
if (($runtime_item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "拒绝删除重解析点：$runtime_root"
}

if ($PSCmdlet.ShouldProcess($runtime_root, "删除 Adobe MCP 用户级运行时")) {
    Remove-Item -LiteralPath $runtime_root -Recurse -Force
    Write-Output "已删除：$runtime_root"
    Write-Output "该运行时目录未移入回收站；插件文件和 Adobe 文档未删除。"
}
