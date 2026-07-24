Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 固定上游版本与清华 PyPI 镜像，确保安装结果可复现。
$script:origin_repo = "https://github.com/youngminsw/Origin-Pro-MCP.git"
$script:origin_commit = "1e9741af96c45bcac9e619c3ba32264bac6950e7"
$script:pypi_mirror = "https://pypi.tuna.tsinghua.edu.cn/simple"

function Get-OriginPaths {
    <#
    .SYNOPSIS
    返回 Origin MCP 的隔离运行目录。
    .PARAMETER None
    无参数。
    .OUTPUTS
    包含运行根目录、源码目录和虚拟环境目录的对象。
    #>
    $local_app_data = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($local_app_data)) {
        throw "Unable to resolve LOCALAPPDATA."
    }

    $runtime_root = Join-Path $local_app_data "desktop-apps-mcp-suite\engineering\origin"
    [pscustomobject]@{
        RuntimeRoot = $runtime_root
        Source = Join-Path $runtime_root "source"
        Venv = Join-Path $runtime_root ".venv"
    }
}

function Get-CompatiblePython {
    <#
    .SYNOPSIS
    查找支持的 64 位 Python。
    .PARAMETER None
    无参数。
    .OUTPUTS
    包含可执行文件与启动参数的对象；未找到时返回空值。
    #>
    $candidates = @()
    $py_launcher = Get-Command "py.exe" -ErrorAction SilentlyContinue
    if ($null -ne $py_launcher) {
        foreach ($selector in @("-3.12", "-3.11", "-3.10")) {
            $candidates += [pscustomobject]@{ Path = $py_launcher.Source; PrefixArgs = @($selector) }
        }
    }

    foreach ($command_name in @("python.exe", "python")) {
        $python_command = Get-Command $command_name -ErrorAction SilentlyContinue
        if ($null -ne $python_command) {
            $candidates += [pscustomobject]@{ Path = $python_command.Source; PrefixArgs = @() }
        }
    }

    foreach ($candidate in $candidates) {
        $probe = @(& $candidate.Path @($candidate.PrefixArgs) -c "import struct,sys; print('ok' if sys.version_info[:2] in ((3,10),(3,11),(3,12)) and struct.calcsize('P') == 8 else 'no')" 2>$null)
        if ($LASTEXITCODE -eq 0 -and $probe.Count -eq 1 -and $probe[0] -eq "ok") {
            return $candidate
        }
    }

    return $null
}

function Get-OriginInstallation {
    <#
    .SYNOPSIS
    从 COM 注册表解析 Origin 可执行文件。
    .PARAMETER None
    无参数。
    .OUTPUTS
    包含 ProgID、CLSID 和可执行文件路径的对象；未找到时返回空值。
    #>
    $prog_id_path = "Registry::HKEY_CLASSES_ROOT\Origin.ApplicationSI\CLSID"
    if (-not (Test-Path -LiteralPath $prog_id_path)) {
        return $null
    }

    $clsid = [string](Get-Item -LiteralPath $prog_id_path).GetValue("")
    if ([string]::IsNullOrWhiteSpace($clsid)) {
        return $null
    }

    $server_path = "Registry::HKEY_CLASSES_ROOT\CLSID\$clsid\LocalServer32"
    if (-not (Test-Path -LiteralPath $server_path)) {
        return $null
    }

    $server_command = [string](Get-Item -LiteralPath $server_path).GetValue("")
    $server_match = [regex]::Match(
        $server_command,
        '^\s*(?:"(?<quoted>[^"]+\.exe)"|(?<plain>.+?\.exe))(?:\s|$)',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $server_match.Success) {
        return $null
    }

    $executable = $server_match.Groups['quoted'].Value
    if ([string]::IsNullOrWhiteSpace($executable)) {
        $executable = $server_match.Groups['plain'].Value
    }
    $executable = $executable.Trim()
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        return $null
    }

    [pscustomobject]@{
        ProgId = "Origin.ApplicationSI"
        Clsid = $clsid
        Executable = $executable
    }
}

function Initialize-FixedGitCheckout {
    <#
    .SYNOPSIS
    创建或验证固定提交且无修改的 Git 检出。
    .PARAMETER Destination
    本地源码目录。
    .OUTPUTS
    无。
    #>
    param([Parameter(Mandatory = $true)][string]$Destination)

    if (-not (Test-Path -LiteralPath (Join-Path $Destination ".git"))) {
        if (Test-Path -LiteralPath $Destination) {
            $entries = @(Get-ChildItem -LiteralPath $Destination -Force)
            if ($entries.Count -gt 0) {
                throw "Destination exists and is not a Git repository: $Destination"
            }
        } else {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        }

        & git.exe -C $Destination init --quiet
        if ($LASTEXITCODE -ne 0) { throw "Failed to initialize Git repository: $Destination" }
        & git.exe -C $Destination remote add origin $script:origin_repo
        if ($LASTEXITCODE -ne 0) { throw "Failed to add Origin upstream repository." }
        & git.exe -C $Destination fetch --depth 1 origin $script:origin_commit
        if ($LASTEXITCODE -ne 0) { throw "Failed to fetch pinned Origin commit." }
        & git.exe -C $Destination checkout --quiet --detach $script:origin_commit
        if ($LASTEXITCODE -ne 0) { throw "Failed to check out pinned Origin commit." }
    }

    $remote = (& git.exe -C $Destination remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $remote -ne $script:origin_repo) {
        throw "Origin upstream URL does not match."
    }
    $actual_commit = (& git.exe -C $Destination rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $actual_commit -ne $script:origin_commit) {
        throw "Origin commit mismatch. Expected $script:origin_commit, got $actual_commit"
    }
    $status = @(& git.exe -C $Destination status --porcelain --untracked-files=all)
    if ($LASTEXITCODE -ne 0 -or $status.Count -gt 0) {
        throw "Pinned Origin source contains unexpected changes."
    }
}

function New-IsolatedVenv {
    <#
    .SYNOPSIS
    使用已发现的 Python 创建隔离虚拟环境。
    .PARAMETER Python
    Get-CompatiblePython 返回的解释器对象。
    .PARAMETER Destination
    虚拟环境目录。
    .OUTPUTS
    虚拟环境中的 python.exe 路径。
    #>
    param(
        [Parameter(Mandatory = $true)]$Python,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $venv_python = Join-Path $Destination "Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $venv_python -PathType Leaf)) {
        & $Python.Path @($Python.PrefixArgs) -m venv $Destination
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create Origin virtual environment: $Destination"
        }
    }

    return $venv_python
}
