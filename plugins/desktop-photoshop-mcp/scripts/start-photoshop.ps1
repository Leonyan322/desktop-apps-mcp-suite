[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

try {
    $runtime_path = Get-PhotoshopRuntimePath
    Assert-GitCommit `
        -RepositoryPath $runtime_path `
        -ExpectedCommit $script:photoshop_commit `
        -ExpectedRemote $script:photoshop_repo_url

    $entry_path = Join-Path $runtime_path "dist\index.js"
    if (-not (Test-Path -LiteralPath $entry_path -PathType Leaf)) {
        throw "缺少 Photoshop MCP 构建入口，请先运行 scripts/install.ps1。"
    }

    $photoshop_path = Resolve-PhotoshopPath
    if ([string]::IsNullOrWhiteSpace($photoshop_path)) {
        throw "未通过环境变量或注册表发现 Photoshop.exe。"
    }

    $node_command = Get-RequiredCommand -Name "node.exe"
    $env:PHOTOSHOP_PATH = $photoshop_path
    $env:ANALYTICS_DISABLED = "1"
    $env:POSTHOG_DISABLED = "1"
    $env:LOG_LEVEL = "2"

    Set-Location -LiteralPath $runtime_path
    & $node_command.Source $entry_path
    exit $LASTEXITCODE
}
catch {
    [Console]::Error.WriteLine("Photoshop MCP 启动失败：$($_.Exception.Message)")
    exit 1
}
