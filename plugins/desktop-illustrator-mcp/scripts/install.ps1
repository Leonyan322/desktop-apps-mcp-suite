[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

# 先确认系统依赖和 COM 注册，避免留下半安装状态。
& (Join-Path $PSScriptRoot "preflight.ps1")

$runtime_root = Get-AdobeRuntimeRoot
$illustrator_runtime = Get-IllustratorRuntimePath
New-Item -ItemType Directory -Path $runtime_root -Force | Out-Null

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
Write-Output "Illustrator MCP 安装完成。请重启 Codex 以重新加载服务器。"
