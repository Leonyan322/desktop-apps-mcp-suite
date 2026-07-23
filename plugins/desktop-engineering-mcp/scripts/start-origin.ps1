[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "common.ps1")

try {
    $paths = Get-EngineeringPaths
    $origin_executable = Join-Path $paths.OriginVenv "Scripts\origin-pro-mcp.exe"
    if (-not (Test-Path -LiteralPath $origin_executable -PathType Leaf)) {
        throw "Origin MCP is not installed. Run scripts\install.ps1 first."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $paths.OriginSource ".git") -PathType Container)) {
        throw "Origin MCP source checkout is missing. Run scripts\install.ps1 first."
    }
    Initialize-FixedGitCheckout `
        -Repository $script:origin_repo `
        -Commit $script:origin_commit `
        -Destination $paths.OriginSource
    if ($null -eq (Get-OriginInstallation)) {
        throw "Origin.ApplicationSI COM registration was not detected."
    }

    $env:ORIGIN_PRO_MCP_USE_DAEMON = "0"
    $env:ORIGIN_PRO_MCP_ATTACH = "1"
    $env:ORIGIN_PRO_MCP_VISIBLE = "1"
    $env:ORIGIN_PRO_MCP_DIALOG_AUTODISMISS = "off"
    $env:ORIGIN_PRO_MCP_AUTOSAVE = "off"
    $env:ORIGIN_PRO_MCP_REAP_CLOSE = "off"
    $env:ORIGIN_PRO_MCP_SWEEP_ORPHANS = "off"
    $env:ORIGIN_PRO_MCP_DISPATCH_TIMEOUT = "90"
    $env:ORIGIN_PRO_MCP_DISPATCH_KILL_GRACE = "90"

    Set-Location -LiteralPath $paths.OriginSource
    & $origin_executable
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
