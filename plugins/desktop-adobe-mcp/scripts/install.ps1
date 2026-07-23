[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

# 先确认系统依赖和 COM 注册，避免留下半安装状态。
& (Join-Path $PSScriptRoot "preflight.ps1")

$runtime_root = Get-AdobeRuntimeRoot
$photoshop_runtime = Get-PhotoshopRuntimePath
$illustrator_runtime = Get-IllustratorRuntimePath
New-Item -ItemType Directory -Path $runtime_root -Force | Out-Null

Write-Output "安装 Photoshop MCP 到：$photoshop_runtime"
Install-PinnedRepository `
    -RepositoryUrl $script:photoshop_repo_url `
    -Commit $script:photoshop_commit `
    -TargetPath $photoshop_runtime

$npm_command = Get-RequiredCommand -Name "npm.cmd"
Push-Location -LiteralPath $photoshop_runtime
try {
    # 上游固定提交未包含 lockfile；使用插件内已审计锁文件保证依赖一致。
    $bundled_lock_path = Join-Path $PSScriptRoot "photoshop-package-lock.json"
    $expected_lock_hash = "CB86D1E4C6005E5D4DF1DBE705AB8A0DE2CDC5F070B025F5AD342FCEB2A8FD51"
    if (-not (Test-Path -LiteralPath $bundled_lock_path -PathType Leaf)) {
        throw "缺少 Photoshop npm 锁文件：$bundled_lock_path"
    }
    $actual_lock_hash = (Get-FileHash -LiteralPath $bundled_lock_path -Algorithm SHA256).Hash
    if ($actual_lock_hash -ne $expected_lock_hash) {
        throw "Photoshop npm 锁文件哈希不匹配。"
    }
    $package_lock_path = Join-Path $photoshop_runtime "package-lock.json"
    Copy-Item -LiteralPath $bundled_lock_path -Destination $package_lock_path -Force

    # 只构建 stdio MCP 服务，跳过不需要的 Web UI 与原生安装脚本。
    Invoke-ExternalCommand -FilePath $npm_command.Source -Arguments @(
        "ci", "--ignore-scripts", "--no-audit", "--no-fund"
    )
    Invoke-ExternalCommand -FilePath $npm_command.Source -Arguments @("run", "build:server")
}
finally {
    Pop-Location
}

Write-Output "安装 Illustrator MCP 到：$illustrator_runtime"
Install-PinnedRepository `
    -RepositoryUrl $script:illustrator_repo_url `
    -Commit $script:illustrator_commit `
    -TargetPath $illustrator_runtime

$python_info = Find-Python312
if ($null -eq $python_info) {
    throw "未找到 Python 3.12 或更高版本。"
}

$venv_path = Join-Path $illustrator_runtime ".venv"
$venv_python = Join-Path $venv_path "Scripts\python.exe"
if (-not (Test-Path -LiteralPath $venv_python -PathType Leaf)) {
    $venv_args = @($python_info.prefix_args) + @("-m", "venv", $venv_path)
    Invoke-ExternalCommand -FilePath $python_info.path -Arguments $venv_args
}

$requirements_path = Join-Path $illustrator_runtime "requirements.txt"
Invoke-ExternalCommand -FilePath $venv_python -Arguments @(
    "-m",
    "pip",
    "install",
    "--disable-pip-version-check",
    "-r",
    $requirements_path,
    "-i",
    $script:pip_index_url
)

# 将固定提交安装为本地包，确保从插件目录启动时也能解析 illustrator 模块。
Invoke-ExternalCommand -FilePath $venv_python -Arguments @(
    "-m",
    "pip",
    "install",
    "--disable-pip-version-check",
    "--no-deps",
    $illustrator_runtime,
    "-i",
    $script:pip_index_url
)

& (Join-Path $PSScriptRoot "health-check.ps1")
Write-Output "安装完成。请重启 Codex 以重新加载 MCP 服务器。"
