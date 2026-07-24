Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 参数：无；返回值：Excel MCP 用户级运行时绝对路径。
function Get-ExcelRuntimeRoot {
    $local_app_data = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($local_app_data)) {
        throw 'LOCALAPPDATA 未定义，无法确定用户级运行时目录。'
    }
    return [System.IO.Path]::GetFullPath(
        (Join-Path $local_app_data 'desktop-apps-mcp-suite\office\excel')
    )
}

# 参数：最低主版本；返回值：Node.js 命令信息，版本不满足时返回 null。
function Find-NodeCommand {
    param([int]$MinimumMajorVersion = 20)
    $node_command = Get-Command 'node.exe' -ErrorAction SilentlyContinue
    if ($null -eq $node_command) {
        return $null
    }
    try {
        $version_text = (& $node_command.Source --version 2>$null).TrimStart('v')
        $version = [version]$version_text
        if ($version.Major -lt $MinimumMajorVersion) {
            return $null
        }
        return [pscustomobject]@{ FilePath = $node_command.Source; Version = $version.ToString() }
    }
    catch {
        return $null
    }
}

# 参数：无；返回值：npm.cmd 的绝对路径，找不到时返回 null。
function Find-NpmCommand {
    $npm_command = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
    if ($null -eq $npm_command) {
        return $null
    }
    return $npm_command.Source
}

# 参数：COM ProgID；返回值：该 ProgID 是否已注册。
function Test-ComRegistration {
    param([Parameter(Mandatory = $true)][string]$ProgId)
    return Test-Path -LiteralPath ("Registry::HKEY_CLASSES_ROOT\{0}" -f $ProgId)
}

# 参数：程序、参数和失败提示；返回值：无，失败时抛出异常。
function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory = $true)][string]$FailureMessage
    )
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw ("{0}（退出码 {1}）" -f $FailureMessage, $LASTEXITCODE)
    }
}
