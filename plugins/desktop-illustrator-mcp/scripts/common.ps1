Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 固定已验证的上游来源，避免安装结果随分支变化。
$script:illustrator_repo_url = "https://github.com/krVatsal/illustrator-mcp.git"
$script:illustrator_commit = "5040dde760688502f6006204ce9562c01c82c65c"
$script:pip_index_url = "https://pypi.tuna.tsinghua.edu.cn/simple"

function Get-AdobeRuntimeRoot {
    <#
    .SYNOPSIS
    返回共享的 Adobe MCP 用户级运行时目录。
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param()

    $local_app_data = [System.Environment]::GetFolderPath(
        [System.Environment+SpecialFolder]::LocalApplicationData
    )
    if ([string]::IsNullOrWhiteSpace($local_app_data)) {
        throw "无法确定 LOCALAPPDATA 目录。"
    }

    return Join-Path $local_app_data "desktop-apps-mcp-suite\adobe"
}

function Get-IllustratorRuntimePath {
    <#
    .SYNOPSIS
    返回 Illustrator MCP 源码目录。
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param()

    return Join-Path (Get-AdobeRuntimeRoot) "illustrator-mcp"
}

function Get-RequiredCommand {
    <#
    .SYNOPSIS
    查找必需的外部命令。
    .PARAMETER Name
    命令名称。
    .OUTPUTS
    System.Management.Automation.CommandInfo
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $command_info = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $command_info) {
        throw "未找到必需命令：$Name"
    }

    return $command_info
}

function Invoke-ExternalCommand {
    <#
    .SYNOPSIS
    执行外部命令并检查退出码。
    .PARAMETER FilePath
    可执行文件路径。
    .PARAMETER Arguments
    参数数组。
    .OUTPUTS
    None
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @()
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "命令执行失败（退出码 $LASTEXITCODE）：$FilePath"
    }
}

function Get-RegistryDefaultValue {
    <#
    .SYNOPSIS
    读取注册表键的默认值。
    .PARAMETER Path
    PowerShell 注册表路径。
    .OUTPUTS
    System.String 或空值
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -eq $item) {
        return $null
    }

    $value = $item.GetValue("")
    if ($null -eq $value) {
        return $null
    }

    return [string]$value
}

function ConvertTo-ExecutablePath {
    <#
    .SYNOPSIS
    从 LocalServer32 命令行中提取 exe 路径。
    .PARAMETER Value
    注册表命令行。
    .OUTPUTS
    System.String 或空值
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $match = [regex]::Match(
        $Value,
        '^\s*(?:"(?<quoted>[^"]+\.exe)"|(?<plain>.+?\.exe))(?:\s|$)',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $match.Success) {
        return $null
    }

    $path_value = $match.Groups["quoted"].Value
    if ([string]::IsNullOrWhiteSpace($path_value)) {
        $path_value = $match.Groups["plain"].Value
    }

    return $path_value.Trim()
}

function Get-IllustratorComInfo {
    <#
    .SYNOPSIS
    返回 Illustrator 当前 COM 注册信息，不启动应用。
    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding()]
    param()

    $prog_id = "Illustrator.Application"
    $prog_id_root = "Registry::HKEY_CLASSES_ROOT\$prog_id"
    $cur_ver = Get-RegistryDefaultValue -Path (Join-Path $prog_id_root "CurVer")
    $clsid = Get-RegistryDefaultValue -Path (Join-Path $prog_id_root "CLSID")
    $local_server_path = $null
    if (-not [string]::IsNullOrWhiteSpace($clsid)) {
        $local_server_key = "Registry::HKEY_CLASSES_ROOT\CLSID\$clsid\LocalServer32"
        $local_server_path = ConvertTo-ExecutablePath -Value (
            Get-RegistryDefaultValue -Path $local_server_key
        )
    }

    $app_path = Get-RegistryDefaultValue -Path (
        "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Illustrator.exe"
    )
    if ([string]::IsNullOrWhiteSpace($app_path)) {
        $app_path = Get-RegistryDefaultValue -Path (
            "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Illustrator.exe"
        )
    }

    $com_type = [type]::GetTypeFromProgID($prog_id, $false)
    return [pscustomobject]@{
        prog_id = $prog_id
        registered = ($null -ne $com_type)
        cur_ver = $cur_ver
        clsid = $clsid
        local_server_path = $local_server_path
        app_path = $app_path
    }
}

function Find-Python312 {
    <#
    .SYNOPSIS
    查找 Python 3.12 或更高版本。
    .OUTPUTS
    PSCustomObject，包含 path 与 prefix_args
    #>
    [CmdletBinding()]
    param()

    $py_launcher = Get-Command -Name "py.exe" -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -ne $py_launcher) {
        & $py_launcher.Source -3.12 -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 12) else 1)" 2>$null
        if ($LASTEXITCODE -eq 0) {
            return [pscustomobject]@{
                path = $py_launcher.Source
                prefix_args = @("-3.12")
            }
        }
    }

    foreach ($python_name in @("python.exe", "python3.exe")) {
        $python_command = Get-Command -Name $python_name -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -eq $python_command) {
            continue
        }

        & $python_command.Source -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 12) else 1)" 2>$null
        if ($LASTEXITCODE -eq 0) {
            return [pscustomobject]@{
                path = $python_command.Source
                prefix_args = @()
            }
        }
    }

    return $null
}

function Assert-GitCommit {
    <#
    .SYNOPSIS
    校验运行时仓库的来源、固定提交与已跟踪文件状态。
    .PARAMETER RepositoryPath
    仓库路径。
    .PARAMETER ExpectedCommit
    预期 SHA。
    .PARAMETER ExpectedRemote
    预期上游地址。
    .OUTPUTS
    None
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryPath,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$ExpectedCommit,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedRemote
    )

    if (-not (Test-Path -LiteralPath (Join-Path $RepositoryPath ".git") -PathType Container)) {
        throw "运行时仓库不存在或无效：$RepositoryPath"
    }

    $git_command = Get-RequiredCommand -Name "git.exe"
    $actual_commit = (& $git_command.Source -C $RepositoryPath rev-parse HEAD 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $actual_commit -ne $ExpectedCommit) {
        throw "提交校验失败：$RepositoryPath，实际 $actual_commit，预期 $ExpectedCommit"
    }

    $actual_remote = (& $git_command.Source -C $RepositoryPath remote get-url origin 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $actual_remote -ne $ExpectedRemote) {
        throw "上游地址校验失败：$RepositoryPath"
    }

    $tracked_changes = @(& $git_command.Source -C $RepositoryPath status --porcelain --untracked-files=no 2>$null)
    if ($LASTEXITCODE -ne 0 -or $tracked_changes.Count -gt 0) {
        throw "运行时包含被修改的已跟踪文件：$RepositoryPath"
    }
}

function Install-PinnedRepository {
    <#
    .SYNOPSIS
    下载并校验固定提交的上游仓库。
    .PARAMETER RepositoryUrl
    上游 Git URL。
    .PARAMETER Commit
    固定提交 SHA。
    .PARAMETER TargetPath
    安装目标目录。
    .OUTPUTS
    None
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryUrl,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$Commit,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    if (Test-Path -LiteralPath $TargetPath) {
        Assert-GitCommit -RepositoryPath $TargetPath -ExpectedCommit $Commit -ExpectedRemote $RepositoryUrl
        return
    }

    $git_command = Get-RequiredCommand -Name "git.exe"
    New-Item -ItemType Directory -Path $TargetPath | Out-Null
    Invoke-ExternalCommand -FilePath $git_command.Source -Arguments @("-C", $TargetPath, "init")
    Invoke-ExternalCommand -FilePath $git_command.Source -Arguments @(
        "-C", $TargetPath, "remote", "add", "origin", $RepositoryUrl
    )
    Invoke-ExternalCommand -FilePath $git_command.Source -Arguments @(
        "-C", $TargetPath, "fetch", "--depth", "1", "--no-tags", "origin", $Commit
    )
    Invoke-ExternalCommand -FilePath $git_command.Source -Arguments @(
        "-C", $TargetPath, "checkout", "--detach", "FETCH_HEAD"
    )
    Assert-GitCommit -RepositoryPath $TargetPath -ExpectedCommit $Commit -ExpectedRemote $RepositoryUrl
}
