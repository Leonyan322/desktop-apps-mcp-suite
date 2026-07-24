[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

try {
    $runtime_path = Get-IllustratorRuntimePath
    Assert-GitCommit `
        -RepositoryPath $runtime_path `
        -ExpectedCommit $script:illustrator_commit `
        -ExpectedRemote $script:illustrator_repo_url

    $illustrator_info = Get-IllustratorComInfo
    if (-not $illustrator_info.registered) {
        throw "未注册 Illustrator.Application COM ProgID。"
    }

    $venv_python = Join-Path $runtime_path ".venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $venv_python -PathType Leaf)) {
        throw "缺少 Illustrator Python 虚拟环境，请先运行 scripts/install.ps1。"
    }

    Set-Location -LiteralPath $runtime_path
    & $venv_python -m illustrator
    exit $LASTEXITCODE
}
catch {
    [Console]::Error.WriteLine("Illustrator MCP 启动失败：$($_.Exception.Message)")
    exit 1
}
