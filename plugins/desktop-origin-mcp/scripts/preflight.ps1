[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot "common.ps1")

$checks = @()
$windows_ok = $env:OS -eq "Windows_NT" -and [Environment]::Is64BitOperatingSystem
$checks += [pscustomobject]@{ Name = "Windows 64-bit"; Ok = $windows_ok; Detail = [Environment]::OSVersion.VersionString }

$git_command = Get-Command "git.exe" -ErrorAction SilentlyContinue
$checks += [pscustomobject]@{ Name = "Git"; Ok = ($null -ne $git_command); Detail = if ($null -ne $git_command) { $git_command.Source } else { "git.exe was not found" } }

$python = Get-CompatiblePython
$checks += [pscustomobject]@{ Name = "Python"; Ok = ($null -ne $python); Detail = if ($null -ne $python) { "$($python.Path) $($python.PrefixArgs -join ' ')".Trim() } else { "64-bit Python 3.10-3.12 is required" } }

$origin = Get-OriginInstallation
$checks += [pscustomobject]@{ Name = "Origin COM"; Ok = ($null -ne $origin); Detail = if ($null -ne $origin) { $origin.Executable } else { "Origin.ApplicationSI is not registered" } }

$checks | Format-Table -AutoSize
if (@($checks | Where-Object { -not $_.Ok }).Count -gt 0) {
    exit 1
}

exit 0
