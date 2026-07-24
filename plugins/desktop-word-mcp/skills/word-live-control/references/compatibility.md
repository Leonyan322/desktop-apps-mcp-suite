# 兼容性与排错

## 固定运行时

- Windows、Microsoft Word、Python 3.12。
- `officemcp==1.0.5`、`fastmcp==2.3.3`、`mcp==1.28.1`、`pywin32==312`。
- 运行时：`%LOCALAPPDATA%\desktop-apps-mcp-suite\office\officemcp`。
- 默认工作目录：当前用户“文档”目录下的 `OfficeMCP`；可用 `OFFICEMCP_ROOT_FOLDER` 覆盖。
- 权限：每次工具调用都弹出审批，因为 `RunPython` 可执行任意本机代码；默认目录不是安全沙箱。

从插件根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\preflight.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\health-check.ps1
```

安装使用清华 PyPI 镜像。健康检查仅执行 MCP `initialize` 与 `tools/list`，不会调用 Word 业务工具。

Codex 文件访问权限不等于 Word UI 权限。登录、激活、受保护视图、文件恢复、Trust Center、宏、外部链接及另存为对话框需要用户处理。卸载只处理上述 `officemcp` 运行时子目录，支持 `-WhatIf`，不会删除文档或关闭 Word。
