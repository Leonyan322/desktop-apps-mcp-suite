param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$runtime_root = Get-OfficeRuntimeRoot
$officemcp_python = Join-Path $runtime_root 'officemcp\.venv\Scripts\python.exe'
$launcher_path = Join-Path $PSScriptRoot 'officemcp_launcher.py'
if (-not (Test-Path -LiteralPath $officemcp_python -PathType Leaf)) {
    [Console]::Error.WriteLine('OfficeMCP is not installed. Run scripts\install.ps1 first.')
    exit 1
}

if ([string]::IsNullOrWhiteSpace($env:OFFICEMCP_ROOT_FOLDER)) {
    $env:OFFICEMCP_ROOT_FOLDER = Join-Path (Get-UserDocumentsPath) 'OfficeMCP'
}

& $officemcp_python $launcher_path
exit $LASTEXITCODE
