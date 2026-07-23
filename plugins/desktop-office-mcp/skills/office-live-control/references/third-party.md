# 第三方组件

插件仓库不包含以下上游源码、wheel 或 npm 包；`install.ps1` 从包管理器安装固定版本。插件自身的 MIT 许可证不改变任何第三方组件的许可条件。

## PowerPoint MCP

- 包：`ppt-mcp==1.6.0`
- 上游：https://github.com/ykuwai/ppt-mcp
- 标签：`v1.6.0`（提交 `40475197bf470cb710cfe3de1d9cc2ed053ed9de`）
- PyPI wheel SHA-256：`398bf00ba6dec32b5d9473fc7d634f68fdad21bf07f2153ada1ab4a905603123`
- 许可证：PyPI 元数据声明 `MIT`，但 1.6.0 的 GitHub 仓库和 wheel 未附带许可证文本。分发时描述为“upstream declares MIT”，不要将上游源码并入插件仓库。

## Excel MCP Server

- 包：`@negokaz/excel-mcp-server@0.12.0`
- 上游：https://github.com/negokaz/excel-mcp-server
- 标签：`v0.12.0`（提交 `1ff4340573c3e421920282da1602afd89f3bb282`）
- npm integrity：`sha512-d42FfomnLrqT/Z6lCBWTCUxuMpWIp3dgvII6kLYZBRaZlOe4h/rMxFfe5Odkryoeo1H8HxJhdLnDhkINsNuDxw==`
- 许可证：MIT；上游仓库与 npm 包均包含许可证文本。

## OfficeMCP

- 包：`officemcp==1.0.5`
- 上游：https://github.com/OfficeMCP/OfficeMCP
- 审计基线提交：`188140dc784f53d66da566696072f47d29fa795a`
- PyPI wheel SHA-256：`9e263a91d996d6fd07eb9623ee762f7c10a1e4db43d20a38c15e0f897cba00ec`
- 许可证：截至审计时，上游仓库、`pyproject.toml`、PyPI 元数据与发行包均未声明许可证，也未包含 LICENSE。不要复制、修改或再分发其源码或发行包；安装脚本仅让最终用户直接从 PyPI 获取。

插件的 `officemcp_launcher.py` 是独立兼容层：它在固定的 FastMCP 2.3.3 中重注册 `RunPython`，于 MCP 事件线程初始化 COM，并以纯 stdio 启动服务。它不修改上游安装文件。
