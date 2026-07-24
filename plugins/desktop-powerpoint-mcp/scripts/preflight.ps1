param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$results = [System.Collections.Generic.List[object]]::new()

# 参数：检查项、状态和说明；返回值：无。
function Add-CheckResult {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [Parameter(Mandatory = $true)][string]$Details
    )
    $results.Add([pscustomobject]@{
        Check = $Name
        Status = if ($Passed) { 'OK' } else { 'FAIL' }
        Details = $Details
    })
}

$is_windows = ($env:OS -eq 'Windows_NT')
Add-CheckResult -Name 'Windows' -Passed $is_windows -Details $(if ($is_windows) { [Environment]::OSVersion.VersionString } else { '仅支持 Windows。' })

$python_info = Find-Python312
Add-CheckResult -Name 'Python 3.12' -Passed ($null -ne $python_info) -Details $(if ($null -ne $python_info) { $python_info.FilePath } else { '未找到 Python 3.12。' })

$registered = Test-ComRegistration -ProgId 'PowerPoint.Application'
Add-CheckResult -Name 'PowerPoint COM' -Passed $registered -Details $(if ($registered) { 'PowerPoint.Application' } else { '未注册 PowerPoint.Application。' })

try {
    Add-CheckResult -Name '运行时目录' -Passed $true -Details (Get-PowerPointRuntimeRoot)
}
catch {
    Add-CheckResult -Name '运行时目录' -Passed $false -Details $_.Exception.Message
}

$results | Format-Table -AutoSize
if ($results.Status -contains 'FAIL') {
    Write-Error '预检未通过。请安装缺少的软件并先手动完成 PowerPoint 首次启动或激活。'
    exit 1
}

Write-Host '预检通过。PowerPoint 首次启动、激活、受保护视图或文件恢复弹窗仍需用户在应用界面处理。'
