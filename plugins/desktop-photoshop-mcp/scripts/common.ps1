Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 固定已验证的上游来源，避免安装结果随分支变化。
$script:photoshop_repo_url = "https://github.com/alisaitteke/photoshop-mcp.git"
$script:photoshop_commit = "152f8937be98b352c40ab5b525829a50d022f283"
$script:photoshop_lock_hash = "CB86D1E4C6005E5D4DF1DBE705AB8A0DE2CDC5F070B025F5AD342FCEB2A8FD51"

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

function Get-PhotoshopRuntimePath {
    <#
    .SYNOPSIS
    返回 Photoshop MCP 源码目录。
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    param()

    return Join-Path (Get-AdobeRuntimeRoot) "photoshop-mcp"
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

function Test-PhotoshopCandidate {
    <#
    .SYNOPSIS
    将候选目录或文件规范化为有效的 Photoshop.exe。
    .PARAMETER Path
    候选路径。
    .OUTPUTS
    System.String 或空值
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $candidate = [System.Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
    if ([System.IO.Path]::GetExtension($candidate) -ne ".exe") {
        $candidate = Join-Path $candidate "Photoshop.exe"
    }

    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return [System.IO.Path]::GetFullPath($candidate)
    }

    return $null
}

function Resolve-PhotoshopPath {
    <#
    .SYNOPSIS
    通过环境变量与注册表动态发现 Photoshop.exe。
    .OUTPUTS
    System.String 或空值
    #>
    [CmdletBinding()]
    param()

    $environment_candidate = Test-PhotoshopCandidate -Path $env:PHOTOSHOP_PATH
    if ($null -ne $environment_candidate) {
        return $environment_candidate
    }

    $app_path_keys = @(
        "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe",
        "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe"
    )
    foreach ($app_path_key in $app_path_keys) {
        $candidate = Test-PhotoshopCandidate -Path (Get-RegistryDefaultValue -Path $app_path_key)
        if ($null -ne $candidate) {
            return $candidate
        }
    }

    $adobe_roots = @(
        "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Adobe\Photoshop",
        "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Adobe\Photoshop"
    )
    foreach ($adobe_root in $adobe_roots) {
        if (-not (Test-Path -LiteralPath $adobe_root)) {
            continue
        }

        $version_keys = Get-ChildItem -LiteralPath $adobe_root -ErrorAction SilentlyContinue |
            Sort-Object -Property PSChildName -Descending
        foreach ($version_key in $version_keys) {
            $properties = Get-ItemProperty -LiteralPath $version_key.PSPath -ErrorAction SilentlyContinue
            if ($null -eq $properties) {
                continue
            }

            $application_path = $properties.PSObject.Properties["ApplicationPath"]
            if ($null -eq $application_path) {
                continue
            }

            $candidate = Test-PhotoshopCandidate -Path ([string]$application_path.Value)
            if ($null -ne $candidate) {
                return $candidate
            }
        }
    }

    $prog_id_root = "Registry::HKEY_CLASSES_ROOT\Photoshop.Application"
    $clsid = Get-RegistryDefaultValue -Path (Join-Path $prog_id_root "CLSID")
    if (-not [string]::IsNullOrWhiteSpace($clsid)) {
        $local_server_key = "Registry::HKEY_CLASSES_ROOT\CLSID\$clsid\LocalServer32"
        $server_command = Get-RegistryDefaultValue -Path $local_server_key
        $server_path = ConvertTo-ExecutablePath -Value $server_command
        $candidate = Test-PhotoshopCandidate -Path $server_path
        if ($null -ne $candidate) {
            return $candidate
        }
    }

    $program_files_roots = @(
        [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ProgramFiles),
        [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ProgramFilesX86)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($program_files_root in $program_files_roots) {
        $candidate = Test-PhotoshopCandidate -Path (
            Join-Path $program_files_root "Adobe\Adobe Photoshop 2020\Photoshop.exe"
        )
        if ($null -ne $candidate) {
            return $candidate
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
