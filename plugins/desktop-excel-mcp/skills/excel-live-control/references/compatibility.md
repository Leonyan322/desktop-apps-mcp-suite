# 兼容性与排错

## 固定运行时

- Windows、Microsoft Excel、Node.js 20+ 与 npm。
- `@negokaz/excel-mcp-server@0.12.0`。
- 运行时：`%LOCALAPPDATA%\desktop-apps-mcp-suite\office\excel`。
- 权限：只读工具默认直接运行，写工具弹出审批；不要绕过审批。

从插件根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\preflight.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\health-check.ps1
```

健康检查使用 Node.js 探针，仅执行 MCP `initialize` 与 `tools/list`，不会调用工作簿业务工具。Excel 找不到 workbook 时使用绝对路径，并在需要实时 COM 操作时保持目标工作簿已打开。

Codex 文件访问权限不等于 Excel UI 权限。登录、激活、受保护视图、文件恢复、Trust Center、宏、外部链接及另存为对话框需要用户处理。卸载只处理上述 `excel` 运行时子目录，支持 `-WhatIf`，不会删除工作簿或关闭 Excel。
