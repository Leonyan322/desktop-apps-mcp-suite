[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot "common.ps1")

function Assert-NoReparsePoint {
    <#
    .SYNOPSIS
    拒绝通过 junction 或符号链接执行删除。
    .PARAMETER Paths
    需要检查的固定目录链。
    .OUTPUTS
    无；发现 reparse point 时抛出异常。
    #>
    param([Parameter(Mandatory = $true)][string[]]$Paths)

    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -LiteralPath $path -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Refusing to delete through a reparse point: $path"
            }
        }
    }
}

$paths = Get-OriginPaths
$local_app_data = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$suite_root = [IO.Path]::GetFullPath((Join-Path $local_app_data "desktop-apps-mcp-suite"))
$engineering_root = [IO.Path]::GetFullPath((Join-Path $suite_root "engineering"))
$expected_root = [IO.Path]::GetFullPath((Join-Path $engineering_root "origin"))
$actual_root = [IO.Path]::GetFullPath($paths.RuntimeRoot)
if (-not [string]::Equals($expected_root, $actual_root, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to delete an unexpected directory: $actual_root"
}

Assert-NoReparsePoint -Paths @($suite_root, $engineering_root, $actual_root)
if (Test-Path -LiteralPath $actual_root) {
    if ($PSCmdlet.ShouldProcess($actual_root, "Remove only the Origin MCP runtime")) {
        Remove-Item -LiteralPath $actual_root -Recurse -Force
        Write-Host "Removed the Origin MCP runtime: $actual_root"
        Write-Host "This removal is not recoverable by this script. Origin user projects were not deleted."
    }
} else {
    Write-Host "The Origin MCP runtime does not exist: $actual_root"
}
