[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "common.ps1")

try {
    $paths = Get-EngineeringPaths
    $hfss_python = Join-Path $paths.HfssVenv "Scripts\python.exe"
    $hfss_server = Join-Path $paths.HfssSource "hfss_server.py"
    if (-not (Test-Path -LiteralPath $hfss_python -PathType Leaf) -or -not (Test-Path -LiteralPath $hfss_server -PathType Leaf)) {
        throw "HFSS MCP is not installed. Run scripts\install.ps1 first."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $paths.HfssSource ".git") -PathType Container)) {
        throw "HFSS MCP source checkout is missing. Run scripts\install.ps1 first."
    }
    Initialize-FixedGitCheckout `
        -Repository $script:hfss_repo `
        -Commit $script:hfss_commit `
        -Destination $paths.HfssSource `
        -AllowDirty

    $hfss_patch = Join-Path $PSScriptRoot "hfss-2023r1.patch"
    $reverse_check = @(& git.exe -C $paths.HfssSource apply --reverse --check --whitespace=nowarn $hfss_patch 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "HFSS compatibility patch integrity check failed."
    }
    $hfss_changes = @(& git.exe -C $paths.HfssSource status --porcelain --untracked-files=all)
    $unexpected_changes = @($hfss_changes | Where-Object { $_ -notmatch '^ M (hfss_server\.py|requirements\.txt)$' })
    if ($unexpected_changes.Count -gt 0) {
        throw "HFSS source contains unexpected changes."
    }

    $aedt = Get-AedtInstallation
    if ($null -eq $aedt) {
        throw "Ansys Electronics Desktop 2023 R1 was not detected."
    }

    $env:ANSYSEM_ROOT231 = $aedt.Root
    if (-not (Test-Path -LiteralPath $paths.HfssState)) {
        New-Item -ItemType Directory -Path $paths.HfssState -Force | Out-Null
    }

    Set-Location -LiteralPath $paths.HfssState
    & $hfss_python -u $hfss_server
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
