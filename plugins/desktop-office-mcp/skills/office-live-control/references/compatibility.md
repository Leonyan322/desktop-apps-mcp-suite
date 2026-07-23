# 兼容性与排错

## 固定运行时

| 服务 | 固定版本 | 本机依赖 | 审批策略 |
|---|---:|---|---|
| `ppt` | `ppt-mcp==1.6.0` | Windows、PowerPoint、Python 3.12 | 写操作审批 |
| `excel` | `@negokaz/excel-mcp-server@0.12.0` | Windows、Excel、Node.js 20+ | 写操作审批 |
| `officemcp` | `officemcp==1.0.5` | Windows、Word、Python 3.12 | 每次调用审批 |

OfficeMCP 同时固定 `fastmcp==2.3.3`、`mcp==1.28.1` 与 `pywin32==312`。PowerPoint 运行时固定 `mcp==1.28.1`、`pydantic==2.13.4` 与 `pywin32==312`。运行时位于 `%LOCALAPPDATA%\desktop-apps-mcp-suite\office`，不写入插件仓库。

## 安装与检查

从插件根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\preflight.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\health-check.ps1
```

安装 Python 包时固定使用清华 PyPI 镜像。脚本通过 `HKCR\PowerPoint.Application`、`HKCR\Excel.Application` 与 `HKCR\Word.Application` 动态检查 COM 注册，不依赖固定 Office 安装目录。健康检查还会为三个服务器分别创建临时子进程，只执行 MCP `initialize` 与 `tools/list`，确认协议可用且工具列表非空；它不会调用 Office 业务工具。

## 工作目录

设置 `OFFICEMCP_ROOT_FOLDER` 可覆盖 Word 默认工作目录；未设置时使用当前用户“文档”目录下的 `OfficeMCP`。该目录只控制默认路径，不能限制 `RunPython` 对本机的访问，因此必须保留逐次审批。

## 首次 Office 弹窗

Codex 的文件访问权限与 Office 自身的 UI 状态不同。下列弹窗必须由用户在应用中完成：

- Office 登录、许可证激活和隐私确认；
- 受保护视图、文件恢复与只读提示；
- Trust Center、宏或外部链接警告；
- Save As、字体替换或格式兼容性对话框。

PowerPoint 默认 `PPT_AUTO_DISMISS_DIALOG=false`，插件不会自动按 Esc。对话框阻塞 COM 时，先由用户关闭弹窗，再重试失败的单个操作。

## 常见故障

- “未安装”：运行 `install.ps1`，随后运行 `health-check.ps1`。
- COM 未注册：启动对应 Office 应用完成首次配置；仍失败时修复 Office 安装。
- Excel 找不到 workbook：使用绝对路径，并在 Excel 中打开目标文件。
- Word 出现 COM 未初始化错误：确认实际启动的是插件的 `start-officemcp.ps1`，且健康检查显示固定版本匹配。
- 文件被占用：不要结束用户的 Office 进程；让用户处理弹窗或关闭冲突的文档。

卸载仅删除 `%LOCALAPPDATA%\desktop-apps-mcp-suite\office`，不会删除用户文档，也不会关闭 Office 应用。
