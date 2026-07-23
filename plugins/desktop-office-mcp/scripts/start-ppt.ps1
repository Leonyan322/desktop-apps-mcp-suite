param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$runtime_root = Get-OfficeRuntimeRoot
$ppt_command = Join-Path $runtime_root 'ppt\.venv\Scripts\ppt-mcp.exe'
if (-not (Test-Path -LiteralPath $ppt_command -PathType Leaf)) {
    [Console]::Error.WriteLine('PowerPoint MCP is not installed. Run scripts\install.ps1 first.')
    exit 1
}

if ([string]::IsNullOrWhiteSpace($env:PPT_AUTO_DISMISS_DIALOG)) {
    $env:PPT_AUTO_DISMISS_DIALOG = 'false'
}

& $ppt_command
exit $LASTEXITCODE
