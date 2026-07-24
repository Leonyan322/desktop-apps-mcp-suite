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

$node_info = Find-NodeCommand -MinimumMajorVersion 20
Add-CheckResult -Name 'Node.js >= 20' -Passed ($null -ne $node_info) -Details $(if ($null -ne $node_info) { "v$($node_info.Version)" } else { '未找到 Node.js 20 或更高版本。' })

$npm_path = Find-NpmCommand
Add-CheckResult -Name 'npm' -Passed ($null -ne $npm_path) -Details $(if ($null -ne $npm_path) { $npm_path } else { '未找到 npm.cmd。' })

$registered = Test-ComRegistration -ProgId 'Excel.Application'
Add-CheckResult -Name 'Excel COM' -Passed $registered -Details $(if ($registered) { 'Excel.Application' } else { '未注册 Excel.Application。' })

try {
    Add-CheckResult -Name '运行时目录' -Passed $true -Details (Get-ExcelRuntimeRoot)
}
catch {
    Add-CheckResult -Name '运行时目录' -Passed $false -Details $_.Exception.Message
}

$results | Format-Table -AutoSize
if ($results.Status -contains 'FAIL') {
    Write-Error '预检未通过。请安装缺少的软件并先手动完成 Excel 首次启动或激活。'
    exit 1
}

Write-Host '预检通过。Excel 首次启动、激活、受保护视图或文件恢复弹窗仍需用户在应用界面处理。'
