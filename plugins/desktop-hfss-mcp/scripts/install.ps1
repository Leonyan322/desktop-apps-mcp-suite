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
if ($null -eq (Get-AedtInstallation)) {
    throw "Ansys Electronics Desktop 2023 R1 was not detected."
}

$paths = Get-HfssPaths
New-Item -ItemType Directory -Path $paths.RuntimeRoot -Force | Out-Null
New-Item -ItemType Directory -Path $paths.State -Force | Out-Null

Write-Host "Installing the pinned HFSS MCP commit..."
Initialize-FixedGitCheckout -Destination $paths.Source
$hfss_patch = Join-Path $PSScriptRoot "hfss-2023r1.patch"
$patch_check = @(& git.exe -C $paths.Source apply --check --whitespace=nowarn $hfss_patch 2>&1)
if ($LASTEXITCODE -eq 0) {
    & git.exe -C $paths.Source apply --whitespace=nowarn $hfss_patch
    if ($LASTEXITCODE -ne 0) { throw "Failed to apply the HFSS compatibility patch." }
} else {
    $reverse_check = @(& git.exe -C $paths.Source apply --reverse --check --whitespace=nowarn $hfss_patch 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "HFSS source matches neither the pre-patch nor post-patch state.`n$($patch_check -join [Environment]::NewLine)`n$($reverse_check -join [Environment]::NewLine)"
    }
}
Assert-HfssPatchedCheckout -Destination $paths.Source -PatchPath $hfss_patch

$hfss_python = New-IsolatedVenv -Python $python -Destination $paths.Venv
& $hfss_python -m pip install --disable-pip-version-check --upgrade pip -i $script:pypi_mirror
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade pip in the HFSS environment." }
& $hfss_python -m pip install --disable-pip-version-check -r (Join-Path $PSScriptRoot "requirements.txt") -i $script:pypi_mirror
if ($LASTEXITCODE -ne 0) { throw "Failed to install HFSS MCP dependencies." }

Write-Host "HFSS MCP installation complete. Run scripts\health-check.ps1 to verify it."
