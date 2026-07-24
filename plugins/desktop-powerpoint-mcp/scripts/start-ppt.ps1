param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$ppt_command = Join-Path (Get-PowerPointRuntimeRoot) '.venv\Scripts\ppt-mcp.exe'
if (-not (Test-Path -LiteralPath $ppt_command -PathType Leaf)) {
    [Console]::Error.WriteLine('PowerPoint MCP is not installed. Run scripts\install.ps1 first.')
    exit 1
}
if ([string]::IsNullOrWhiteSpace($env:PPT_AUTO_DISMISS_DIALOG)) {
    $env:PPT_AUTO_DISMISS_DIALOG = 'false'
}

& $ppt_command
exit $LASTEXITCODE
