[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot "common.ps1")

$paths = Get-EngineeringPaths
$local_app_data = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$expected_root = [IO.Path]::GetFullPath((Join-Path $local_app_data "desktop-apps-mcp-suite\engineering"))
$actual_root = [IO.Path]::GetFullPath($paths.RuntimeRoot)
if (-not [string]::Equals($expected_root, $actual_root, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to delete an unexpected directory: $actual_root"
}

if (Test-Path -LiteralPath $actual_root) {
    $runtime_item = Get-Item -LiteralPath $actual_root -Force
    if (($runtime_item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing to delete a reparse point: $actual_root"
    }
    if ($PSCmdlet.ShouldProcess($actual_root, "Remove the engineering MCP runtime")) {
        Remove-Item -LiteralPath $actual_root -Recurse -Force
        Write-Host "Removed the engineering MCP runtime: $actual_root"
        Write-Host "This removal is not recoverable by this script. Origin and HFSS user projects were not deleted."
    }
} else {
    Write-Host "The engineering MCP runtime does not exist: $actual_root"
}
