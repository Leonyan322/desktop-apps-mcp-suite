[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

function Read-McpResponse {
    <#
    .SYNOPSIS
    在超时内读取指定 JSON-RPC id 的响应。
    .PARAMETER Reader
    子进程标准输出读取器。
    .PARAMETER ResponseId
    期望的 JSON-RPC id。
    .PARAMETER TimeoutMilliseconds
    超时时间。
    .OUTPUTS
    PSCustomObject 或空值
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.StreamReader]$Reader,

        [Parameter(Mandatory = $true)]
        [int]$ResponseId,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutMilliseconds
    )

    $deadline = [datetime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    while ([datetime]::UtcNow -lt $deadline) {
        $remaining = [int][Math]::Max(
            1,
            ($deadline - [datetime]::UtcNow).TotalMilliseconds
        )
        $read_task = $Reader.ReadLineAsync()
        if (-not $read_task.Wait($remaining)) {
            return $null
        }

        $line = $read_task.Result
        if ($null -eq $line) {
            return $null
        }

        try {
            $message = $line | ConvertFrom-Json
        }
        catch {
            $line_summary = if ($line.Length -gt 160) {
                $line.Substring(0, 160) + "..."
            }
            else {
                $line
            }
            throw "MCP stdout 出现非 JSON 数据：$line_summary"
        }

        $id_property = $message.PSObject.Properties["id"]
        if ($null -ne $id_property -and [int]$id_property.Value -eq $ResponseId) {
            return $message
        }
    }

    return $null
}

function Invoke-McpStdioProbe {
    <#
    .SYNOPSIS
    初始化 Photoshop MCP 并确认 tools/list 非空。
    .PARAMETER StartScript
    MCP 启动脚本的绝对路径。
    .OUTPUTS
    System.Int32，工具数量
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartScript
    )

    if (-not (Test-Path -LiteralPath $StartScript -PathType Leaf)) {
        throw "MCP 启动脚本不存在：$StartScript"
    }

    $powershell_command = Get-RequiredCommand -Name "powershell.exe"
    $start_info = New-Object System.Diagnostics.ProcessStartInfo
    $start_info.FileName = $powershell_command.Source
    $start_info.Arguments = (
        "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$StartScript`""
    )
    $start_info.WorkingDirectory = Split-Path -Parent $PSScriptRoot
    $start_info.UseShellExecute = $false
    $start_info.CreateNoWindow = $true
    $start_info.RedirectStandardInput = $true
    $start_info.RedirectStandardOutput = $true
    $start_info.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start_info
    $probe_error = $null
    $stderr_text = ""
    $stderr_task = $null
    $process_started = $false
    $tool_count = 0

    try {
        if (-not $process.Start()) {
            throw "无法启动 MCP 子进程。"
        }
        $process_started = $true
        $stderr_task = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.AutoFlush = $true

        $initialize_request = @{
            jsonrpc = "2.0"
            id = 1
            method = "initialize"
            params = @{
                protocolVersion = "2024-11-05"
                capabilities = @{}
                clientInfo = @{
                    name = "desktop-photoshop-mcp-health-check"
                    version = "0.2.0"
                }
            }
        } | ConvertTo-Json -Compress -Depth 8
        $process.StandardInput.WriteLine($initialize_request)

        $initialize_response = Read-McpResponse `
            -Reader $process.StandardOutput `
            -ResponseId 1 `
            -TimeoutMilliseconds 30000
        if ($null -eq $initialize_response) {
            throw "initialize 在 30 秒内未返回。"
        }
        if ($null -ne $initialize_response.PSObject.Properties["error"]) {
            throw "initialize 返回错误：$($initialize_response.error | ConvertTo-Json -Compress)"
        }

        $initialized_notification = @{
            jsonrpc = "2.0"
            method = "notifications/initialized"
            params = @{}
        } | ConvertTo-Json -Compress -Depth 4
        $process.StandardInput.WriteLine($initialized_notification)

        $list_request = @{
            jsonrpc = "2.0"
            id = 2
            method = "tools/list"
            params = @{}
        } | ConvertTo-Json -Compress -Depth 4
        $process.StandardInput.WriteLine($list_request)

        $list_response = Read-McpResponse `
            -Reader $process.StandardOutput `
            -ResponseId 2 `
            -TimeoutMilliseconds 15000
        if ($null -eq $list_response) {
            throw "tools/list 在 15 秒内未返回。"
        }
        if ($null -ne $list_response.PSObject.Properties["error"]) {
            throw "tools/list 返回错误：$($list_response.error | ConvertTo-Json -Compress)"
        }
        if ($null -eq $list_response.PSObject.Properties["result"] -or
            $null -eq $list_response.result.PSObject.Properties["tools"]) {
            throw "tools/list 响应缺少 result.tools。"
        }

        $tool_count = @($list_response.result.tools).Count
        if ($tool_count -lt 1) {
            throw "tools/list 返回空工具列表。"
        }
    }
    catch {
        $probe_error = $_
    }
    finally {
        if ($process_started -and -not $process.HasExited) {
            $process.StandardInput.Close()
            if (-not $process.WaitForExit(2000)) {
                $process.Kill()
                $process.WaitForExit()
            }
        }
        if ($null -ne $stderr_task -and $stderr_task.IsCompleted) {
            $stderr_text = $stderr_task.Result.Trim()
        }
        $process.Dispose()
    }

    if ($null -ne $probe_error) {
        $detail = $probe_error.Exception.Message
        if (-not [string]::IsNullOrWhiteSpace($stderr_text)) {
            $detail = "$detail；stderr: $stderr_text"
        }
        throw "Photoshop MCP stdio 探针失败：$detail"
    }

    return $tool_count
}

$failures = New-Object System.Collections.Generic.List[string]
$photoshop_runtime = Get-PhotoshopRuntimePath

try {
    Assert-GitCommit `
        -RepositoryPath $photoshop_runtime `
        -ExpectedCommit $script:photoshop_commit `
        -ExpectedRemote $script:photoshop_repo_url
    Write-Output "[通过] Photoshop MCP 提交：$script:photoshop_commit"
}
catch {
    $failures.Add($_.Exception.Message)
}

$photoshop_entry = Join-Path $photoshop_runtime "dist\index.js"
if (-not (Test-Path -LiteralPath $photoshop_entry -PathType Leaf)) {
    $failures.Add("缺少 Photoshop MCP 构建入口：$photoshop_entry")
}
else {
    try {
        $node_command = Get-RequiredCommand -Name "node.exe"
        & $node_command.Source --check $photoshop_entry
        if ($LASTEXITCODE -ne 0) {
            throw "Node.js 语法检查失败。"
        }
        Write-Output "[通过] Photoshop MCP Node.js 入口"
    }
    catch {
        $failures.Add($_.Exception.Message)
    }
}

$photoshop_path = Resolve-PhotoshopPath
if ([string]::IsNullOrWhiteSpace($photoshop_path)) {
    $failures.Add("未发现 Photoshop.exe。")
}
else {
    Write-Output "[通过] Photoshop 应用：$photoshop_path"
}

if ($failures.Count -eq 0) {
    try {
        $tool_count = Invoke-McpStdioProbe `
            -StartScript (Join-Path $PSScriptRoot "start-photoshop.ps1")
        Write-Output "[通过] Photoshop MCP initialize/tools/list：$tool_count 个工具"
    }
    catch {
        $failures.Add($_.Exception.Message)
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure_message in $failures) {
        Write-Output "[失败] $failure_message"
    }
    throw "Photoshop MCP 健康检查失败，共 $($failures.Count) 项。"
}

Write-Output "Photoshop MCP 健康检查通过；未执行写操作、任意脚本或屏幕截图。"
