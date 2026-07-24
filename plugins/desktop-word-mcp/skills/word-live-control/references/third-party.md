# 第三方组件

插件仓库不包含上游源码或 wheel；安装脚本让最终用户从包管理器获取固定版本。插件自身的 MIT 许可证不改变第三方许可条件。

- 包：`officemcp==1.0.5`
- 上游：https://github.com/OfficeMCP/OfficeMCP
- 审计基线提交：`188140dc784f53d66da566696072f47d29fa795a`
- PyPI wheel SHA-256：`9e263a91d996d6fd07eb9623ee762f7c10a1e4db43d20a38c15e0f897cba00ec`
- 许可风险：截至审计时，上游仓库、`pyproject.toml`、PyPI 元数据与发行包均未声明许可证，也未包含 LICENSE。不要复制、修改或再分发其源码或发行包。

插件内的 `officemcp_launcher.py` 是独立兼容层：它在 MCP 事件线程初始化 COM、替换高风险 `RunPython` 工具并以纯 stdio 启动服务，不修改上游安装文件。
