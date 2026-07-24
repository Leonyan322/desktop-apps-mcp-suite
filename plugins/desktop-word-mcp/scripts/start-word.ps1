param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$runtime_python = Join-Path (Get-WordRuntimeRoot) '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $runtime_python -PathType Leaf)) {
    [Console]::Error.WriteLine('Word MCP is not installed. Run scripts\install.ps1 first.')
    exit 1
}
if ([string]::IsNullOrWhiteSpace($env:OFFICEMCP_ROOT_FOLDER)) {
    $env:OFFICEMCP_ROOT_FOLDER = Join-Path (Get-UserDocumentsPath) 'OfficeMCP'
}

& $runtime_python (Join-Path $PSScriptRoot 'officemcp_launcher.py')
exit $LASTEXITCODE
