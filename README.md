# Windows Desktop Apps MCP Suite

面向 Windows 桌面版 Codex 的可安装插件套件，把已经验证过的 Office、工程软件和 Adobe COM 自动化方案拆成三个独立插件。仓库只包含配置、启动包装器和安装脚本；第三方 MCP 源码在用户明确运行安装脚本时从上游固定版本下载，不会被复制进本仓库。

## 插件与兼容性

| 插件 | 软件 | 已验证版本 | MCP 固定版本 |
| --- | --- | --- | --- |
| `desktop-office-mcp` | PowerPoint、Excel、Word | Microsoft Office 桌面版 | `ppt-mcp 1.6.0`、`excel-mcp-server 0.12.0`、`officemcp 1.0.5` |
| `desktop-engineering-mcp` | Origin、Ansys HFSS | Origin 2021、AEDT/HFSS 2023 R1 | Origin commit `1e9741a`、HFSS commit `950c06d` |
| `desktop-adobe-mcp` | Photoshop、Illustrator | Adobe 2020 | Photoshop commit `152f893`、Illustrator commit `5040dde` |

只支持 Windows 10/11 的交互式桌面会话。服务器通过 COM 控制已安装的软件，因此不能在无桌面会话的云端或 Linux/macOS 上运行。其他软件版本可能可用，但尚未完成同等级验证。

## 前置条件

- 当前版本的 Codex 桌面应用。
- Windows PowerShell 5.1 或 PowerShell 7。
- Git。
- 64 位 Python 3.12；安装 Python 包时脚本固定使用清华 PyPI 镜像。
- Node.js 20 或更高版本（Excel、Photoshop 需要）。
- 要控制的桌面软件已经安装、正常启动过一次，并完成许可证或首次启动向导。

安装脚本不要求管理员权限，也不会修改个人 `~/.codex/config.toml`。软件自身若弹出 UAC、许可证、受保护视图或文件恢复窗口，需要用户在桌面上处理；这些窗口和 Codex 的 MCP 工具审批是两套独立机制。

## 安装

克隆仓库后，只安装需要的插件。以下以 Office 为例：

```powershell
git clone https://github.com/Leonyan322/desktop-apps-mcp-suite.git
Set-Location .\desktop-apps-mcp-suite

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\plugins\desktop-office-mcp\scripts\preflight.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\plugins\desktop-office-mcp\scripts\install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\plugins\desktop-office-mcp\scripts\health-check.ps1
```

工程软件或 Adobe 插件使用各自目录中的同名脚本：

```powershell
.\plugins\desktop-engineering-mcp\scripts\preflight.ps1
.\plugins\desktop-engineering-mcp\scripts\install.ps1
.\plugins\desktop-engineering-mcp\scripts\health-check.ps1

.\plugins\desktop-adobe-mcp\scripts\preflight.ps1
.\plugins\desktop-adobe-mcp\scripts\install.ps1
.\plugins\desktop-adobe-mcp\scripts\health-check.ps1
```

随后把仓库 Marketplace 加到 Codex，并安装所需插件：

```powershell
codex plugin marketplace add Leonyan322/desktop-apps-mcp-suite
codex plugin add desktop-office-mcp@desktop-apps-mcp-suite
codex plugin add desktop-engineering-mcp@desktop-apps-mcp-suite
codex plugin add desktop-adobe-mcp@desktop-apps-mcp-suite
```

重启 Codex 桌面应用并新建任务，使新安装的 Skill 和 MCP 工具进入新任务上下文。也可以只安装其中一个插件。

## 权限提示为什么仍会出现

“完全文件访问”只决定 Codex 能否访问本机文件，不等于允许 MCP 服务器执行所有桌面操作。本套件为高风险工具保留独立审批：

- OfficeMCP `RunPython`、Origin 写操作与 LabTalk、HFSS 建模写操作会逐次询问。
- Photoshop `photoshop_execute_script` 和 Illustrator `run` 可执行任意脚本，会逐次询问。
- PowerPoint、Excel、Photoshop、Illustrator 采用 `writes` 策略：只有上游明确标记为只读的工具才可直接执行。Adobe 上游当前缺少只读注解，因此查询操作也可能弹出审批，这是保守的安全行为。
- HFSS 的停止、重启和同步仿真工具默认禁用；Illustrator 的全屏截图 `view` 与不稳定的 `help` 默认禁用。

因此，“需要权限时弹消息”由插件的 MCP 工具策略完成。若没有弹窗，先确认调用的是否为只读工具，再在 Codex 插件设置中确认没有把该 MCP 的审批策略覆盖成自动允许。

## 运行目录与卸载

依赖安装到当前用户的：

```text
%LOCALAPPDATA%\desktop-apps-mcp-suite\
```

卸载某个运行环境时执行对应插件的 `scripts\uninstall.ps1`。该脚本只删除该插件自己的运行目录，不删除桌面软件、仓库、Codex 个人配置或用户文档。

## 第三方项目与许可证

本仓库的自有脚本和配置使用 [MIT License](LICENSE)。第三方 MCP 项目不包含在本仓库中，仍受各自上游条款约束。`hfss-2023r1.patch` 为固定上游提交的兼容性差异，其中保留的上游上下文不在本仓库 MIT 授权范围内：

| 项目 | 上游声明状态 |
| --- | --- |
| `ppt-mcp` | 包元数据声明 MIT，但上游仓库/发行包未附许可证正文 |
| `@negokaz/excel-mcp-server` | MIT，仓库和 npm 包均附许可证 |
| `OfficeMCP` | 上游未声明许可证 |
| `Origin-Pro-MCP` | MIT，仓库附许可证 |
| `HFSS_McpServer` | README 声明 MIT，但仓库未附许可证正文 |
| `photoshop-mcp` | npm 元数据声明 MIT，但仓库未附许可证正文 |
| `illustrator-mcp` | 上游未声明许可证 |

许可证未明确的项目不会被本仓库重新分发。安装脚本仅帮助用户从原始上游下载固定提交；使用者仍应自行确认其使用场景是否符合上游授权。若需要组织内分发或商业使用，建议先取得对应上游的明确许可。

## 安全与隐私

- Photoshop 启动时强制关闭其 MCP 分析遥测。
- 启动包装器的 stdout 只保留 MCP 协议数据，诊断信息写入 stderr。
- 安装与健康检查不会打开或修改测试文档；实际写入只在用户调用相应工具并通过审批后发生。
- 不提交个人 `config.toml`、绝对路径、测试文件、访问令牌或软件许可证信息。
