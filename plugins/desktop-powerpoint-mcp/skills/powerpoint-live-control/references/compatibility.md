# 兼容性与排错

## 固定运行时

- Windows、Microsoft PowerPoint、Python 3.12。
- `ppt-mcp==1.6.0`、`mcp==1.28.1`、`pydantic==2.13.4`、`pywin32==312`。
- 运行时：`%LOCALAPPDATA%\desktop-apps-mcp-suite\office\ppt`。
- 权限：只读工具默认直接运行，写工具弹出审批；不要绕过审批。

从插件根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\preflight.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\health-check.ps1
```

安装使用清华 PyPI 镜像。健康检查仅执行 MCP `initialize` 与 `tools/list`，不会调用演示文稿业务工具。

## 应用弹窗

Codex 文件访问权限不等于 PowerPoint UI 权限。登录、激活、受保护视图、文件恢复、Trust Center、宏、外部链接及另存为对话框需要用户在应用中处理。插件默认不自动按 Esc。

COM 未注册时先启动 PowerPoint 完成首次配置；仍失败时修复 Office。卸载只处理上述 `ppt` 运行时子目录，支持 `-WhatIf`，不会删除演示文稿或关闭 PowerPoint。
