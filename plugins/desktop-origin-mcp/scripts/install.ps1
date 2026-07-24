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

$paths = Get-OriginPaths
New-Item -ItemType Directory -Path $paths.RuntimeRoot -Force | Out-Null

Write-Host "Installing the pinned Origin MCP commit..."
Initialize-FixedGitCheckout -Destination $paths.Source
$origin_python = New-IsolatedVenv -Python $python -Destination $paths.Venv
& $origin_python -m pip install --disable-pip-version-check --upgrade pip -i $script:pypi_mirror
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade pip in the Origin environment." }
& $origin_python -m pip install --disable-pip-version-check -r (Join-Path $PSScriptRoot "requirements.txt") -i $script:pypi_mirror
if ($LASTEXITCODE -ne 0) { throw "Failed to install Origin MCP dependencies." }
& $origin_python -m pip install --disable-pip-version-check --no-deps $paths.Source -i $script:pypi_mirror
if ($LASTEXITCODE -ne 0) { throw "Failed to install the Origin MCP source." }

Write-Host "Origin MCP installation complete. Run scripts\health-check.ps1 to verify it."
