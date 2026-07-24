# Windows Desktop Apps MCP Suite

面向 Windows 桌面版 Codex 的独立应用 MCP 插件套件。每个插件只检测、安装和启动一个桌面软件的 MCP 运行时；用户不需要安装同组中的其他软件。仓库只包含配置、启动包装器和安装脚本，第三方 MCP 源码会在用户明确运行安装脚本时从固定上游版本下载。

## 插件与兼容性

| 插件 | 软件 | 已验证版本 | MCP 固定版本 |
| --- | --- | --- | --- |
| `desktop-powerpoint-mcp` | PowerPoint | Microsoft Office 桌面版 | `ppt-mcp 1.6.0` |
| `desktop-excel-mcp` | Excel | Microsoft Office 桌面版 | `excel-mcp-server 0.12.0` |
| `desktop-word-mcp` | Word | Microsoft Office 桌面版 | `officemcp 1.0.5` |
| `desktop-origin-mcp` | Origin | Origin 2021 | Origin commit `1e9741a` |
| `desktop-hfss-mcp` | Ansys HFSS | AEDT/HFSS 2023 R1 | HFSS commit `950c06d` |
| `desktop-photoshop-mcp` | Photoshop | Photoshop 2020 | Photoshop commit `152f893` |
| `desktop-illustrator-mcp` | Illustrator | Illustrator 2020 | Illustrator commit `5040dde` |

只支持 Windows 10/11 的交互式桌面会话。其他软件版本可能可用，但尚未完成同等级验证。

## 前置条件

所有插件都需要当前版本的 Codex 桌面应用和 Windows PowerShell 5.1 或 PowerShell 7。按插件安装额外依赖：

| 插件 | 额外依赖 |
| --- | --- |
| PowerPoint、Word | 64 位 Python 3.12 |
| Excel | Node.js 20 或更高版本、npm |
| Origin、HFSS | Git、64 位 Python 3.10–3.12 |
| Photoshop | Git、Node.js 18 或更高版本、npm、Windows Script Host |
| Illustrator | Git、64 位 Python 3.12 或更高版本 |

目标桌面软件必须已经安装、成功启动过一次，并完成许可证激活或首次启动向导。安装脚本不要求管理员权限，也不会修改个人 `~/.codex/config.toml`。软件自身的 UAC、激活、受保护视图或文件恢复窗口仍需用户在桌面处理。

## 安装单个插件

克隆仓库，选择一个插件并依次执行预检、安装和健康检查。以下以 Word 为例：

```powershell
git clone https://github.com/Leonyan322/desktop-apps-mcp-suite.git
Set-Location .\desktop-apps-mcp-suite

$plugin = "desktop-word-mcp"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\plugins\$plugin\scripts\preflight.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\plugins\$plugin\scripts\install.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\plugins\$plugin\scripts\health-check.ps1"
```

将仓库 Marketplace 加到 Codex，再安装所需插件：

```powershell
codex plugin marketplace add Leonyan322/desktop-apps-mcp-suite

codex plugin add desktop-powerpoint-mcp@desktop-apps-mcp-suite
codex plugin add desktop-excel-mcp@desktop-apps-mcp-suite
codex plugin add desktop-word-mcp@desktop-apps-mcp-suite
codex plugin add desktop-origin-mcp@desktop-apps-mcp-suite
codex plugin add desktop-hfss-mcp@desktop-apps-mcp-suite
codex plugin add desktop-photoshop-mcp@desktop-apps-mcp-suite
codex plugin add desktop-illustrator-mcp@desktop-apps-mcp-suite
```

只执行需要的软件对应命令。随后重启 Codex 并新建任务，使新 Skill 和 MCP 工具进入任务上下文。

## 从 v0.1.0 迁移

`v0.1.0` 的三个组合插件已经拆成七个独立插件。现有 MCP 运行时目录保持不变，不需要主动运行旧卸载脚本或重新下载全部依赖。

```powershell
codex plugin marketplace upgrade desktop-apps-mcp-suite
```

然后在 Codex 插件页面停用或卸载旧的 `desktop-office-mcp`、`desktop-engineering-mcp`、`desktop-adobe-mcp`，并安装需要的独立插件。旧版本仍可通过 Git 标签 [`v0.1.0`](https://github.com/Leonyan322/desktop-apps-mcp-suite/tree/v0.1.0) 获取。

## 验证范围

健康检查会真实执行 MCP `initialize` 和 `tools/list`，但不会调用写入、删除、任意脚本、保存、截图或仿真工具。当前实机基线：

| 软件 | 工具数量 |
| --- | ---: |
| PowerPoint | 156 |
| Excel | 7 |
| Word | 14 |
| Origin | 45 |
| HFSS | 非空工具列表 |
| Photoshop | 87 |
| Illustrator | 7 |

这些结果证明固定版本在已验证环境中能够完成协议握手和工具发现，不等于所有业务工具、软件版本和异常状态均无缺陷。

## 权限提示

“完全文件访问”只决定 Codex 能否访问本机文件，不等于允许 MCP 执行所有桌面操作。各插件对高风险操作保留独立审批：

- Word `RunPython`、Origin 写操作与 LabTalk、HFSS 建模写操作会询问。
- Photoshop `photoshop_execute_script` 和 Illustrator `run` 能执行任意脚本，会逐次询问。
- PowerPoint、Excel、Photoshop、Illustrator 使用保守的 `writes` 策略。Adobe 上游缺少只读注解，因此查询也可能弹出审批。
- HFSS 的停止、重启和同步仿真工具默认禁用；Illustrator 的全屏截图 `view` 与不稳定的 `help` 默认禁用。

Codex MCP 审批与 Windows、Office、Origin、Ansys、Adobe 自身弹窗是两套独立机制。

## 运行目录与卸载

运行时安装在当前用户的：

```text
%LOCALAPPDATA%\desktop-apps-mcp-suite\
```

七个插件继续复用 `office\ppt`、`office\excel`、`office\officemcp`、`engineering\origin`、`engineering\hfss`、`adobe\photoshop-mcp` 和 `adobe\illustrator-mcp`。每个 `scripts\uninstall.ps1` 只允许删除自己的组件目录，不删除桌面软件、其他 MCP 运行时、仓库、Codex 配置或用户文档。可先使用 `-WhatIf` 预览。

## 第三方项目与许可证

本仓库的自有脚本和配置使用 [MIT License](LICENSE)。第三方 MCP 项目不包含在本仓库中，仍受各自上游条款约束。`hfss-2023r1.patch` 中保留的上游上下文不在本仓库 MIT 授权范围内。

| 项目 | 上游声明状态 |
| --- | --- |
| `ppt-mcp` | 包元数据声明 MIT，但上游仓库/发行包未附许可证正文 |
| `@negokaz/excel-mcp-server` | MIT，仓库和 npm 包均附许可证 |
| `OfficeMCP` | 上游未声明许可证 |
| `Origin-Pro-MCP` | MIT，仓库附许可证 |
| `HFSS_McpServer` | README 声明 MIT，但仓库未附许可证正文 |
| `photoshop-mcp` | npm 元数据声明 MIT，但仓库未附许可证正文 |
| `illustrator-mcp` | 上游未声明许可证 |

许可证未明确的项目不会被本仓库重新分发。安装脚本只帮助用户从原始上游下载固定提交；组织内分发或商业使用前应自行确认上游授权。

## 安全与隐私

- Photoshop 启动时强制关闭其 MCP 分析遥测。
- stdio 启动包装器的 stdout 只保留 MCP 协议数据，诊断信息写入 stderr。
- 安装和健康检查不会打开或修改测试文档。
- 仓库不提交个人 `config.toml`、绝对路径、测试文件、访问令牌或软件许可证信息。
