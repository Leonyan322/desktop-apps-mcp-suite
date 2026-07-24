[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

if (-not [System.Environment]::Is64BitOperatingSystem) {
    $failures.Add("需要 64 位 Windows。")
}
if ($env:OS -ne "Windows_NT") {
    $failures.Add("此插件仅支持 Windows。")
}

try {
    $git_command = Get-RequiredCommand -Name "git.exe"
    Write-Output "[通过] Git: $($git_command.Source)"
}
catch {
    $failures.Add($_.Exception.Message)
}

$python_info = Find-Python312
if ($null -eq $python_info) {
    $failures.Add("未找到 Python 3.12 或更高版本。")
}
else {
    $version_args = @($python_info.prefix_args) + @("--version")
    $python_version = (& $python_info.path @version_args 2>&1).Trim()
    Write-Output "[通过] Python: $python_version"
}

$illustrator_info = Get-IllustratorComInfo
if (-not $illustrator_info.registered) {
    $failures.Add("未注册 Illustrator.Application COM ProgID。")
}
else {
    Write-Output "[通过] Illustrator COM: $($illustrator_info.clsid)"
    Write-Output "[信息] Illustrator CurVer: $($illustrator_info.cur_ver)"
    Write-Output "[信息] Illustrator LocalServer32: $($illustrator_info.local_server_path)"
    if ($illustrator_info.cur_ver -ne "Illustrator.Application.24") {
        $warnings.Add(
            "当前 Illustrator CurVer 不是 Illustrator.Application.24；多版本环境会控制当前注册版本。"
        )
    }
}

foreach ($warning_message in $warnings) {
    Write-Warning $warning_message
}

if ($failures.Count -gt 0) {
    foreach ($failure_message in $failures) {
        Write-Output "[失败] $failure_message"
    }
    throw "Illustrator MCP 预检失败，共 $($failures.Count) 项。"
}

Write-Output "Illustrator MCP 预检通过。"
