[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

# 先确认系统依赖和 COM 注册，避免留下半安装状态。
& (Join-Path $PSScriptRoot "preflight.ps1")

$runtime_root = Get-AdobeRuntimeRoot
$photoshop_runtime = Get-PhotoshopRuntimePath
New-Item -ItemType Directory -Path $runtime_root -Force | Out-Null

Write-Output "安装 Photoshop MCP 到：$photoshop_runtime"
Install-PinnedRepository `
    -RepositoryUrl $script:photoshop_repo_url `
    -Commit $script:photoshop_commit `
    -TargetPath $photoshop_runtime

$npm_command = Get-RequiredCommand -Name "npm.cmd"
Push-Location -LiteralPath $photoshop_runtime
try {
    # 上游固定提交未包含 lockfile；校验插件内锁文件后用 npm ci 安装。
    $bundled_lock_path = Join-Path $PSScriptRoot "photoshop-package-lock.json"
    if (-not (Test-Path -LiteralPath $bundled_lock_path -PathType Leaf)) {
        throw "缺少 Photoshop npm 锁文件：$bundled_lock_path"
    }
    $actual_lock_hash = (Get-FileHash -LiteralPath $bundled_lock_path -Algorithm SHA256).Hash
    if ($actual_lock_hash -ne $script:photoshop_lock_hash) {
        throw "Photoshop npm 锁文件哈希不匹配。"
    }
    Copy-Item `
        -LiteralPath $bundled_lock_path `
        -Destination (Join-Path $photoshop_runtime "package-lock.json") `
        -Force

    # 只构建 stdio MCP 服务，跳过不需要的 Web UI 与原生安装脚本。
    Invoke-ExternalCommand -FilePath $npm_command.Source -Arguments @(
        "ci", "--ignore-scripts", "--no-audit", "--no-fund"
    )
    Invoke-ExternalCommand -FilePath $npm_command.Source -Arguments @("run", "build:server")
}
finally {
    Pop-Location
}

& (Join-Path $PSScriptRoot "health-check.ps1")
Write-Output "Photoshop MCP 安装完成。请重启 Codex 以重新加载服务器。"
