"""只初始化 MCP 并验证工具列表，不调用业务工具。"""

import asyncio
import json
import os
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def inspect_server(start_script: Path, timeout_seconds: float = 45.0) -> dict:
    """
    参数：start_script 为 MCP PowerShell 启动脚本，timeout_seconds 为总超时。
    返回：服务器名称与工具数量。
    """
    plugin_root = start_script.parent.parent
    parameters = StdioServerParameters(
        command="powershell.exe",
        args=[
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(start_script),
        ],
        cwd=str(plugin_root),
        env=os.environ.copy(),
    )

    async def initialize_and_list() -> dict:
        """
        参数：无，使用外层服务器参数。
        返回：initialize 结果中的服务器名称与非空工具数量。
        """
        async with stdio_client(parameters) as (read_stream, write_stream):
            async with ClientSession(read_stream, write_stream) as session:
                initialized = await session.initialize()
                listed = await session.list_tools()
                tool_count = len(listed.tools)
                if tool_count < 1:
                    raise RuntimeError("MCP list_tools 返回空列表")
                server_info = initialized.serverInfo
                return {
                    "server": getattr(server_info, "name", "unknown"),
                    "tool_count": tool_count,
                }

    return await asyncio.wait_for(initialize_and_list(), timeout=timeout_seconds)


def main() -> int:
    """
    参数：命令行第一个参数为启动脚本。
    返回：成功为 0，失败为 1。
    """
    if len(sys.argv) != 2:
        print("用法：mcp-health.py <start-script>", file=sys.stderr)
        return 1

    start_script = Path(sys.argv[1]).resolve()
    if not start_script.is_file():
        print(f"启动脚本不存在：{start_script}", file=sys.stderr)
        return 1

    try:
        result = asyncio.run(inspect_server(start_script))
    except Exception as exc:  # 健康检查只返回简洁错误，不泄漏堆栈。
        print(str(exc), file=sys.stderr)
        return 1

    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
