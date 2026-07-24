Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 参数：无；返回值：PowerPoint MCP 用户级运行时绝对路径。
function Get-PowerPointRuntimeRoot {
    $local_app_data = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($local_app_data)) {
        throw 'LOCALAPPDATA 未定义，无法确定用户级运行时目录。'
    }

    return [System.IO.Path]::GetFullPath(
        (Join-Path $local_app_data 'desktop-apps-mcp-suite\office\ppt')
    )
}

# 参数：可执行文件与前置参数；返回值：是否为 Python 3.12。
function Test-Python312Candidate {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$PrefixArguments = @()
    )

    try {
        & $FilePath @PrefixArguments -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 12) else 1)' 2>$null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

# 参数：无；返回值：Python 3.12 命令及前置参数，找不到时返回 null。
function Find-Python312 {
    $py_command = Get-Command 'py.exe' -ErrorAction SilentlyContinue
    if ($null -ne $py_command -and (Test-Python312Candidate -FilePath $py_command.Source -PrefixArguments @('-3.12'))) {
        return [pscustomobject]@{ FilePath = $py_command.Source; PrefixArguments = @('-3.12') }
    }

    $candidate_paths = @()
    $python_command = Get-Command 'python.exe' -ErrorAction SilentlyContinue
    if ($null -ne $python_command) {
        $candidate_paths += $python_command.Source
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $candidate_paths += Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        $candidate_paths += Join-Path $env:ProgramFiles 'Python312\python.exe'
    }

    foreach ($candidate_path in ($candidate_paths | Select-Object -Unique)) {
        if ((Test-Path -LiteralPath $candidate_path -PathType Leaf) -and
            (Test-Python312Candidate -FilePath $candidate_path)) {
            return [pscustomobject]@{ FilePath = $candidate_path; PrefixArguments = @() }
        }
    }

    return $null
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
