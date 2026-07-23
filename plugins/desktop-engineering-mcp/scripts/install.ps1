[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot "common.ps1")

if ($env:OS -ne "Windows_NT") {
    throw "This plugin can only be installed on Windows."
}
if ($null -eq (Get-Command "git.exe" -ErrorAction SilentlyContinue)) {
    throw "git.exe was not found. Install Git for Windows first."
}

$python = Get-CompatiblePython
if ($null -eq $python) {
    throw "64-bit Python 3.10, 3.11, or 3.12 was not found."
}
if ($null -eq (Get-OriginInstallation)) {
    throw "Origin.ApplicationSI was not detected. Install and run Origin once."
}
if ($null -eq (Get-AedtInstallation)) {
    throw "Ansys Electronics Desktop 2023 R1 was not detected."
}

$paths = Get-EngineeringPaths
New-Item -ItemType Directory -Path $paths.RuntimeRoot -Force | Out-Null
New-Item -ItemType Directory -Path $paths.OriginRoot -Force | Out-Null
New-Item -ItemType Directory -Path $paths.HfssRoot -Force | Out-Null
New-Item -ItemType Directory -Path $paths.HfssState -Force | Out-Null

Write-Host "Installing the pinned Origin MCP commit..."
Initialize-FixedGitCheckout -Repository $script:origin_repo -Commit $script:origin_commit -Destination $paths.OriginSource
$origin_python = New-IsolatedVenv -Python $python -Destination $paths.OriginVenv
& $origin_python -m pip install --disable-pip-version-check --upgrade pip -i $script:pypi_mirror
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade pip in the Origin environment." }
& $origin_python -m pip install --disable-pip-version-check -r (Join-Path $PSScriptRoot "requirements-origin.txt") -i $script:pypi_mirror
if ($LASTEXITCODE -ne 0) { throw "Failed to install Origin MCP dependencies." }
& $origin_python -m pip install --disable-pip-version-check --no-deps $paths.OriginSource -i $script:pypi_mirror
if ($LASTEXITCODE -ne 0) { throw "Failed to install the Origin MCP source." }

Write-Host "Installing the pinned HFSS MCP commit..."
Initialize-FixedGitCheckout -Repository $script:hfss_repo -Commit $script:hfss_commit -Destination $paths.HfssSource -AllowDirty
$hfss_patch = Join-Path $PSScriptRoot "hfss-2023r1.patch"
$patch_check = @(& git.exe -C $paths.HfssSource apply --check --whitespace=nowarn $hfss_patch 2>&1)
if ($LASTEXITCODE -eq 0) {
    & git.exe -C $paths.HfssSource apply --whitespace=nowarn $hfss_patch
    if ($LASTEXITCODE -ne 0) { throw "Failed to apply the HFSS compatibility patch." }
} else {
    $reverse_check = @(& git.exe -C $paths.HfssSource apply --reverse --check --whitespace=nowarn $hfss_patch 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "HFSS source matches neither the pre-patch nor post-patch state.`n$($patch_check -join [Environment]::NewLine)`n$($reverse_check -join [Environment]::NewLine)"
    }
}

$hfss_changes = @(& git.exe -C $paths.HfssSource status --porcelain --untracked-files=all)
$unexpected_changes = @($hfss_changes | Where-Object { $_ -notmatch '^ M (hfss_server\.py|requirements\.txt)$' })
if ($unexpected_changes.Count -gt 0) {
    throw "HFSS source contains unexpected changes:`n$($unexpected_changes -join [Environment]::NewLine)"
}

$hfss_python = New-IsolatedVenv -Python $python -Destination $paths.HfssVenv
& $hfss_python -m pip install --disable-pip-version-check --upgrade pip -i $script:pypi_mirror
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade pip in the HFSS environment." }
& $hfss_python -m pip install --disable-pip-version-check -r (Join-Path $PSScriptRoot "requirements-hfss.txt") -i $script:pypi_mirror
if ($LASTEXITCODE -ne 0) { throw "Failed to install HFSS MCP dependencies." }

Write-Host "Installation complete. Run scripts\health-check.ps1 to verify both MCP servers."
