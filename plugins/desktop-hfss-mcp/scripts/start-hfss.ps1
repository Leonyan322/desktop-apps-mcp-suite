[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "common.ps1")

try {
    $paths = Get-HfssPaths
    $hfss_python = Join-Path $paths.Venv "Scripts\python.exe"
    $hfss_server = Join-Path $paths.Source "hfss_server.py"
    if (-not (Test-Path -LiteralPath $hfss_python -PathType Leaf) -or -not (Test-Path -LiteralPath $hfss_server -PathType Leaf)) {
        throw "HFSS MCP is not installed. Run scripts\install.ps1 first."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $paths.Source ".git") -PathType Container)) {
        throw "HFSS MCP source checkout is missing. Run scripts\install.ps1 first."
    }

    $hfss_patch = Join-Path $PSScriptRoot "hfss-2023r1.patch"
    Assert-HfssPatchedCheckout -Destination $paths.Source -PatchPath $hfss_patch

    $aedt = Get-AedtInstallation
    if ($null -eq $aedt) {
        throw "Ansys Electronics Desktop 2023 R1 was not detected."
    }

    $env:ANSYSEM_ROOT231 = $aedt.Root
    if (-not (Test-Path -LiteralPath $paths.State)) {
        New-Item -ItemType Directory -Path $paths.State -Force | Out-Null
    }

    Set-Location -LiteralPath $paths.State
    & $hfss_python -u $hfss_server
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
