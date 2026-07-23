Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 这些脚本级常量只描述固定上游与本地隔离目录。
$script:origin_repo = "https://github.com/youngminsw/Origin-Pro-MCP.git"
$script:origin_commit = "1e9741af96c45bcac9e619c3ba32264bac6950e7"
$script:hfss_repo = "https://github.com/leonardwy/HFSS_McpServer.git"
$script:hfss_commit = "950c06dc8dae360ebe701bf00ff51542ac08c2b2"
$script:pypi_mirror = "https://pypi.tuna.tsinghua.edu.cn/simple"

function Get-EngineeringPaths {
    <#
    .SYNOPSIS
    返回插件运行目录。
    .PARAMETER None
    无参数。
    .OUTPUTS
    包含运行根目录、源码、虚拟环境和状态目录的对象。
    #>
    $local_app_data = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($local_app_data)) {
        throw "Unable to resolve LOCALAPPDATA."
    }

    $runtime_root = Join-Path $local_app_data "desktop-apps-mcp-suite\engineering"
    [pscustomobject]@{
        RuntimeRoot = $runtime_root
        OriginRoot = Join-Path $runtime_root "origin"
        OriginSource = Join-Path $runtime_root "origin\source"
        OriginVenv = Join-Path $runtime_root "origin\.venv"
        HfssRoot = Join-Path $runtime_root "hfss"
        HfssSource = Join-Path $runtime_root "hfss\source"
        HfssVenv = Join-Path $runtime_root "hfss\.venv"
        HfssState = Join-Path $runtime_root "hfss\runtime"
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

function Get-AedtInstallation {
    <#
    .SYNOPSIS
    发现 Ansys Electronics Desktop 2023 R1。
    .PARAMETER None
    无参数。
    .OUTPUTS
    包含版本、安装目录与可执行文件的对象；未找到时返回空值。
    #>
    $roots = @()
    foreach ($scope in @("Process", "User", "Machine")) {
        $value = [Environment]::GetEnvironmentVariable("ANSYSEM_ROOT231", $scope)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $roots += $value
        }
    }

    $registry_path = "HKLM:\SOFTWARE\Ansoft\ElectronicsDesktop\2023.1\Desktop"
    if (Test-Path -LiteralPath $registry_path) {
        $registry_values = Get-ItemProperty -LiteralPath $registry_path -ErrorAction SilentlyContinue
        $installation_property = $registry_values.PSObject.Properties["InstallationDirectory"]
        $registry_root = if ($null -ne $installation_property) { $installation_property.Value } else { $null }
        if (-not [string]::IsNullOrWhiteSpace($registry_root)) {
            $roots += $registry_root
        }
    }

    foreach ($root in ($roots | Select-Object -Unique)) {
        $resolved_root = $root.Trim().Trim('"')
        $executable = Join-Path $resolved_root "ansysedt.exe"
        if (Test-Path -LiteralPath $executable -PathType Leaf) {
            return [pscustomobject]@{
                Version = "2023.1"
                EnvironmentVariable = "ANSYSEM_ROOT231"
                Root = $resolved_root
                Executable = $executable
            }
        }
    }

    return $null
}

function Initialize-FixedGitCheckout {
    <#
    .SYNOPSIS
    创建或验证固定提交的 Git 检出。
    .PARAMETER Repository
    上游仓库 URL。
    .PARAMETER Commit
    必须检出的完整提交 SHA。
    .PARAMETER Destination
    本地源码目录。
    .PARAMETER AllowDirty
    是否允许后续兼容补丁造成工作树修改。
    .OUTPUTS
    无。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$Destination,
        [switch]$AllowDirty
    )

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
        & git.exe -C $Destination remote add origin $Repository
        if ($LASTEXITCODE -ne 0) { throw "Failed to add upstream repository: $Repository" }
        & git.exe -C $Destination fetch --depth 1 origin $Commit
        if ($LASTEXITCODE -ne 0) { throw "Failed to fetch pinned commit: $Commit" }
        & git.exe -C $Destination checkout --quiet --detach $Commit
        if ($LASTEXITCODE -ne 0) { throw "Failed to check out pinned commit: $Commit" }
    }

    $remote = (& git.exe -C $Destination remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $remote -ne $Repository) {
        throw "Upstream URL does not match: $Destination"
    }

    $actual_commit = (& git.exe -C $Destination rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $actual_commit -ne $Commit) {
        throw "Commit mismatch. Expected $Commit, got $actual_commit"
    }

    if (-not $AllowDirty) {
        $status = @(& git.exe -C $Destination status --porcelain)
        if ($status.Count -gt 0) {
            throw "Pinned source contains uncommitted changes: $Destination"
        }
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
            throw "Failed to create virtual environment: $Destination"
        }
    }

    return $venv_python
}
