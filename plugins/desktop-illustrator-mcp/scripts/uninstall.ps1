[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$runtime_path = [System.IO.Path]::GetFullPath((Get-IllustratorRuntimePath)).TrimEnd('\')
$local_app_data = [System.IO.Path]::GetFullPath(
    [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
).TrimEnd('\')
$expected_path = [System.IO.Path]::GetFullPath(
    (Join-Path $local_app_data "desktop-apps-mcp-suite\adobe\illustrator-mcp")
).TrimEnd('\')

# 删除前验证完整绝对路径，防止环境变量异常扩大范围。
if (-not $runtime_path.Equals($expected_path, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "运行时目录校验失败，拒绝删除：$runtime_path"
}
if ((Split-Path -Leaf $runtime_path) -ne "illustrator-mcp") {
    throw "运行时目录名称异常，拒绝删除：$runtime_path"
}

if (-not (Test-Path -LiteralPath $runtime_path)) {
    Write-Output "Illustrator MCP 运行时不存在，无需卸载。"
    exit 0
}

$runtime_item = Get-Item -LiteralPath $runtime_path -Force
if (($runtime_item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "拒绝删除重解析点：$runtime_path"
}

if ($PSCmdlet.ShouldProcess($runtime_path, "删除 Illustrator MCP 用户级运行时")) {
    Remove-Item -LiteralPath $runtime_path -Recurse -Force
    Write-Output "已删除：$runtime_path"
    Write-Output "该运行时目录未移入回收站；Photoshop 运行时、插件文件和 Adobe 文档未删除。"
}
