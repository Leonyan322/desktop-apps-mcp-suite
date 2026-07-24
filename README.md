# Windows Desktop Apps MCP Suite

7 个独立桌面软件 MCP 插件，**同时支持 Codex 和 Claude Code**。每个插件只负责一个软件；底层的 MCP 运行时是同一套，安装一次即可双端通用。

| 插件 | 软件 | 已验证版本 | MCP 固定版本 |
| --- | --- | --- | --- |
| `desktop-powerpoint-mcp` | PowerPoint | Microsoft Office 桌面版 | `ppt-mcp 1.6.0` |
| `desktop-excel-mcp` | Excel | Microsoft Office 桌面版 | `excel-mcp-server 0.12.0` |
| `desktop-word-mcp` | Word | Microsoft Office 桌面版 | `officemcp 1.0.5` |
| `desktop-origin-mcp` | Origin | Origin 2021 | Origin commit `1e9741a` |
| `desktop-hfss-mcp` | Ansys HFSS | AEDT/HFSS 2023 R1 | HFSS commit `950c06d` |
| `desktop-photoshop-mcp` | Photoshop | Photoshop 2020 | Photoshop commit `152f893` |
| `desktop-illustrator-mcp` | Illustrator | Illustrator 2020 | Illustrator commit `5040dde` |

只支持 Windows 10/11 的交互式桌面会话。

---

## 选你的平台

### 我是 Codex 用户

```powershell
git clone https://github.com/Leonyan322/desktop-apps-mcp-suite.git
Set-Location .\desktop-apps-mcp-suite

# ① 安装运行时（以 Word 为例，其他同理）
$plugin = “desktop-word-mcp”
powershell.exe -NoProfile -ExecutionPolicy Bypass -File “.\plugins\$plugin\scripts\preflight.ps1”
powershell.exe -NoProfile -ExecutionPolicy Bypass -File “.\plugins\$plugin\scripts\install.ps1”
powershell.exe -NoProfile -ExecutionPolicy Bypass -File “.\plugins\$plugin\scripts\health-check.ps1”

# ② 添加 Marketplace 并安装插件
codex plugin marketplace add Leonyan322/desktop-apps-mcp-suite
codex plugin add desktop-word-mcp@desktop-apps-mcp-suite

# ③ 重启 Codex，新建任务即可使用
```

只安装你需要的软件对应的插件。完整列表：

```powershell
codex plugin add desktop-powerpoint-mcp@desktop-apps-mcp-suite
codex plugin add desktop-excel-mcp@desktop-apps-mcp-suite
codex plugin add desktop-word-mcp@desktop-apps-mcp-suite
codex plugin add desktop-origin-mcp@desktop-apps-mcp-suite
codex plugin add desktop-hfss-mcp@desktop-apps-mcp-suite
codex plugin add desktop-photoshop-mcp@desktop-apps-mcp-suite
codex plugin add desktop-illustrator-mcp@desktop-apps-mcp-suite
```

### 我是 Claude Code 用户

```powershell
git clone https://github.com/Leonyan322/desktop-apps-mcp-suite.git
Set-Location .\desktop-apps-mcp-suite

# ① 安装运行时（以 Word 为例，其他同理）
$plugin = “desktop-word-mcp”
powershell.exe -NoProfile -ExecutionPolicy Bypass -File “.\plugins\$plugin\scripts\preflight.ps1”
powershell.exe -NoProfile -ExecutionPolicy Bypass -File “.\plugins\$plugin\scripts\install.ps1”
powershell.exe -NoProfile -ExecutionPolicy Bypass -File “.\plugins\$plugin\scripts\health-check.ps1”

# ② 什么都不用做——仓库根目录的 .mcp.json 已配好全部 7 个服务器
# ③ 在当前目录启动 Claude Code，MCP 自动连接
```

仓库根目录的 `.mcp.json` 预配了全部 7 个服务器。不需要的软件把对应 `”enabled”` 改为 `false` 即可，未装运行时的服务器启动失败不影响其他服务器。

### 从 v0.1.0（旧 3 合 1 插件）迁移

旧版用户不需要重装运行时，只需更新仓库：

```powershell
# Codex
codex plugin marketplace upgrade desktop-apps-mcp-suite
# 在 Codex 插件页面停用旧的 desktop-office-mcp / desktop-engineering-mcp / desktop-adobe-mcp
# 再按需安装新的独立插件

# Claude Code
git pull
# .mcp.json 已随仓库更新，重启 Claude Code 即可
```

旧版本仍可通过 Git 标签 [`v0.1.0`](https://github.com/Leonyan322/desktop-apps-mcp-suite/tree/v0.1.0) 获取。

---

## 前置条件

Windows PowerShell 5.1 或 PowerShell 7。按插件安装额外依赖：

| 插件 | 额外依赖 |
| --- | --- |
| PowerPoint、Word | 64 位 Python 3.12 |
| Excel | Node.js 20 或更高版本、npm |
| Origin、HFSS | Git、64 位 Python 3.10–3.12 |
| Photoshop | Git、Node.js 18 或更高版本、npm、Windows Script Host |
| Illustrator | Git、64 位 Python 3.12 或更高版本 |

目标桌面软件必须已经安装、成功启动过一次，并完成许可证激活或首次启动向导。安装脚本不要求管理员权限。软件自身的 UAC、激活、受保护视图或文件恢复窗口仍需用户在桌面处理。

---

## 安装运行时（两种平台都要跑这一步）

运行时的安装方式完全相同——它独立于 Codex / Claude Code：

```powershell
$plugin = “desktop-word-mcp”   # 换成你要的插件名
powershell.exe -NoProfile -ExecutionPolicy Bypass -File “.\plugins\$plugin\scripts\preflight.ps1”
powershell.exe -NoProfile -ExecutionPolicy Bypass -File “.\plugins\$plugin\scripts\install.ps1”
powershell.exe -NoProfile -ExecutionPolicy Bypass -File “.\plugins\$plugin\scripts\health-check.ps1”
```

运行时安装在 `%LOCALAPPDATA%\desktop-apps-mcp-suite\`。Codex 和 Claude Code 共享同一份运行时，不需要重复安装。

---

## 验证范围

健康检查会真实执行 MCP `initialize` 和 `tools/list`，但不会调用写入、删除、保存、截图或仿真工具。当前实机基线：

| 软件 | 工具数量 |
| --- | ---: |
| PowerPoint | 156 |
| Excel | 7 |
| Word | 14 |
| Origin | 45 |
| HFSS | 非空工具列表 |
| Photoshop | 87 |
| Illustrator | 7 |

---

## 权限与安全

各插件对高风险操作保留独立审批。Codex 和 Claude Code 各有自己的审批机制，与 Windows、Office、Origin、Ansys、Adobe 自身弹窗是两套独立机制。

- Word `RunPython`、Origin 写操作与 LabTalk、HFSS 建模写操作会询问
- Photoshop `photoshop_execute_script` 和 Illustrator `run` 能执行任意脚本，会逐次询问
- PowerPoint、Excel、Photoshop、Illustrator 使用保守的 `writes` 策略
- HFSS 的停止、重启和同步仿真工具默认禁用；Illustrator 的全屏截图 `view` 与不稳定的 `help` 默认禁用
- Photoshop 启动时强制关闭其 MCP 分析遥测
- stdio 启动包装器的 stdout 只保留 MCP 协议数据，诊断信息写入 stderr
- 安装和健康检查不会打开或修改测试文档
- 仓库不提交个人配置、绝对路径、测试文件、访问令牌或软件许可证信息

---

## 运行目录与卸载

七个插件的运行时目录：

```text
%LOCALAPPDATA%\desktop-apps-mcp-suite\
├── office\ppt\
├── office\excel\
├── office\officemcp\
├── engineering\origin\
├── engineering\hfss\
├── adobe\photoshop-mcp\
└── adobe\illustrator-mcp\
```

每个 `scripts\uninstall.ps1` 只删除自己的组件目录，不删除桌面软件、其他 MCP 运行时、仓库、AI 工具配置或用户文档。可先使用 `-WhatIf` 预览。

---

## 第三方项目与许可证

本仓库的自有脚本和配置使用 [MIT License](LICENSE)。第三方 MCP 项目不包含在本仓库中，仍受各自上游条款约束。

| 项目 | 上游声明状态 |
| --- | --- |
| `ppt-mcp` | 包元数据声明 MIT，但上游仓库未附许可证正文 |
| `@negokaz/excel-mcp-server` | MIT，仓库和 npm 包均附许可证 |
| `OfficeMCP` | 上游未声明许可证 |
| `Origin-Pro-MCP` | MIT，仓库附许可证 |
| `HFSS_McpServer` | README 声明 MIT，但仓库未附许可证正文 |
| `photoshop-mcp` | npm 元数据声明 MIT，但仓库未附许可证正文 |
| `illustrator-mcp` | 上游未声明许可证 |

许可证未明确的项目不会被本仓库重新分发。安装脚本只帮助用户从原始上游下载固定提交；组织内分发或商业使用前应自行确认上游授权。
