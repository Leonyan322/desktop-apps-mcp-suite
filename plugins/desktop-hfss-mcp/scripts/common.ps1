Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 固定上游、依赖镜像和补丁后文件指纹，避免运行未知代码。
$script:hfss_repo = "https://github.com/leonardwy/HFSS_McpServer.git"
$script:hfss_commit = "950c06dc8dae360ebe701bf00ff51542ac08c2b2"
$script:pypi_mirror = "https://pypi.tuna.tsinghua.edu.cn/simple"
$script:hfss_server_sha256 = "6CC3EEE934BBB5BE7B6CFD9BF4C136EBEC7C20FAF636AA7B251BD94743A760ED"
$script:hfss_requirements_sha256 = "FE1985302F89D703289F634B01FD95711EBECEE86EB1E4088D984FCC563295A8"

function Get-HfssPaths {
    <#
    .SYNOPSIS
    返回 HFSS MCP 的隔离运行目录。
    .PARAMETER None
    无参数。
    .OUTPUTS
    包含运行根目录、源码目录、虚拟环境和状态目录的对象。
    #>
    $local_app_data = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($local_app_data)) {
        throw "Unable to resolve LOCALAPPDATA."
    }

    $runtime_root = Join-Path $local_app_data "desktop-apps-mcp-suite\engineering\hfss"
    [pscustomobject]@{
        RuntimeRoot = $runtime_root
        Source = Join-Path $runtime_root "source"
        Venv = Join-Path $runtime_root ".venv"
        State = Join-Path $runtime_root "runtime"
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
    创建或验证 HFSS 固定提交的 Git 检出。
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
        & git.exe -C $Destination remote add origin $script:hfss_repo
        if ($LASTEXITCODE -ne 0) { throw "Failed to add HFSS upstream repository." }
        & git.exe -C $Destination fetch --depth 1 origin $script:hfss_commit
        if ($LASTEXITCODE -ne 0) { throw "Failed to fetch pinned HFSS commit." }
        & git.exe -C $Destination checkout --quiet --detach $script:hfss_commit
        if ($LASTEXITCODE -ne 0) { throw "Failed to check out pinned HFSS commit." }
    }

    $remote = (& git.exe -C $Destination remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $remote -ne $script:hfss_repo) {
        throw "HFSS upstream URL does not match."
    }
    $actual_commit = (& git.exe -C $Destination rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $actual_commit -ne $script:hfss_commit) {
        throw "HFSS commit mismatch. Expected $script:hfss_commit, got $actual_commit"
    }
}

function Get-NormalizedFileSha256 {
    <#
    .SYNOPSIS
    计算忽略换行符差异的 UTF-8 SHA-256。
    .PARAMETER Path
    需要校验的文本文件。
    .OUTPUTS
    大写十六进制 SHA-256 字符串。
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $text_value = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n")
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($sha256.ComputeHash($utf8.GetBytes($text_value))).Replace("-", "")
    } finally {
        $sha256.Dispose()
    }
}

function Assert-HfssPatchedCheckout {
    <#
    .SYNOPSIS
    验证上游、提交、补丁状态、允许的差异和补丁后文件指纹。
    .PARAMETER Destination
    HFSS 上游源码目录。
    .PARAMETER PatchPath
    与固定提交绑定的兼容补丁。
    .OUTPUTS
    无；任何不一致都会抛出异常。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$PatchPath
    )

    Initialize-FixedGitCheckout -Destination $Destination
    $reverse_check = @(& git.exe -C $Destination apply --reverse --check --whitespace=nowarn $PatchPath 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "HFSS compatibility patch integrity check failed.`n$($reverse_check -join [Environment]::NewLine)"
    }

    $changes = @(& git.exe -C $Destination status --porcelain --untracked-files=all | Sort-Object)
    $expected_changes = @(" M hfss_server.py", " M requirements.txt")
    if (($changes -join "`n") -ne ($expected_changes -join "`n")) {
        throw "HFSS source contains unexpected changes.`n$($changes -join [Environment]::NewLine)"
    }

    $server_path = Join-Path $Destination "hfss_server.py"
    $requirements_path = Join-Path $Destination "requirements.txt"
    if ((Get-NormalizedFileSha256 -Path $server_path) -ne $script:hfss_server_sha256) {
        throw "HFSS patched server fingerprint does not match."
    }
    if ((Get-NormalizedFileSha256 -Path $requirements_path) -ne $script:hfss_requirements_sha256) {
        throw "HFSS patched requirements fingerprint does not match."
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
            throw "Failed to create HFSS virtual environment: $Destination"
        }
    }

    return $venv_python
}
