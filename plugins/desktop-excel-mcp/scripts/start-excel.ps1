param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$node_info = Find-NodeCommand -MinimumMajorVersion 20
if ($null -eq $node_info) {
    [Console]::Error.WriteLine('Node.js 20 or later was not found.')
    exit 1
}
$excel_launcher = Join-Path (Get-ExcelRuntimeRoot) 'node_modules\@negokaz\excel-mcp-server\dist\launcher.js'
if (-not (Test-Path -LiteralPath $excel_launcher -PathType Leaf)) {
    [Console]::Error.WriteLine('Excel MCP is not installed. Run scripts\install.ps1 first.')
    exit 1
}
if ([string]::IsNullOrWhiteSpace($env:EXCEL_MCP_PAGING_CELLS_LIMIT)) {
    $env:EXCEL_MCP_PAGING_CELLS_LIMIT = '4000'
}

& $node_info.FilePath $excel_launcher
exit $LASTEXITCODE
