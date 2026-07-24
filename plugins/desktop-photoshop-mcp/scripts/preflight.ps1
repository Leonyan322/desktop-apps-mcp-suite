[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$failures = New-Object System.Collections.Generic.List[string]

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

try {
    $node_command = Get-RequiredCommand -Name "node.exe"
    $node_version = (& $node_command.Source --version).Trim()
    $node_major = [int]($node_version.TrimStart('v').Split('.')[0])
    if ($node_major -lt 18) {
        $failures.Add("Node.js 版本过低：$node_version，需要 18 或更高版本。")
    }
    else {
        Write-Output "[通过] Node.js: $node_version"
    }
}
catch {
    $failures.Add($_.Exception.Message)
}

try {
    $npm_command = Get-RequiredCommand -Name "npm.cmd"
    Write-Output "[通过] npm: $($npm_command.Source)"
}
catch {
    $failures.Add($_.Exception.Message)
}

try {
    $cscript_command = Get-RequiredCommand -Name "cscript.exe"
    Write-Output "[通过] Windows Script Host: $($cscript_command.Source)"
}
catch {
    $failures.Add("未找到 cscript.exe；Photoshop COM 桥接需要 Windows Script Host。")
}

$photoshop_path = Resolve-PhotoshopPath
if ([string]::IsNullOrWhiteSpace($photoshop_path)) {
    $failures.Add("未通过环境变量或注册表发现 Photoshop.exe。")
}
else {
    Write-Output "[通过] Photoshop: $photoshop_path"
}

$photoshop_type = [type]::GetTypeFromProgID("Photoshop.Application", $false)
if ($null -eq $photoshop_type) {
    $failures.Add("未注册 Photoshop.Application COM ProgID。")
}
else {
    Write-Output "[通过] Photoshop COM: $($photoshop_type.GUID)"
}

if ($failures.Count -gt 0) {
    foreach ($failure_message in $failures) {
        Write-Output "[失败] $failure_message"
    }
    throw "Photoshop MCP 预检失败，共 $($failures.Count) 项。"
}

Write-Output "Photoshop MCP 预检通过。"
