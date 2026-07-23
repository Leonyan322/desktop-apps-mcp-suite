# coding=utf-8
"""以纯 stdio 模式启动 OfficeMCP，并替换其高风险 Python 工具。"""

from __future__ import annotations

import os
from pathlib import Path

import pythoncom
from officemcp.OfficeMCP import Officer, mcp

_com_initialized = False


async def run_python(
    code: str = "\nprint(f'hello world from {data}')\noutput=data\n",
    data: str = "OfficeMCP",
) -> dict:
    """参数：Python 代码和输入数据；返回值：执行状态与输出。"""
    global _com_initialized

    try:
        if not _com_initialized:
            # 在 MCP 事件线程初始化 COM，避免 Office 对象跨线程失效。
            pythoncom.CoInitialize()
            _com_initialized = True

        namespace = {
            "data": data,
            "Officer": Officer,
            "output": "Execution completed",
            "__builtins__": __builtins__,
        }
        exec(code, namespace)
        return {"success": True, "output": namespace.get("output")}
    except Exception as error:
        return {"success": False, "error": str(error)}


def replace_run_python_tool() -> None:
    """参数：无；返回值：无。"""
    # FastMCP 2.3.3 固定为替换同名工具，避免修改上游源码。
    mcp._tool_manager.duplicate_behavior = "replace"
    mcp.add_tool(
        run_python,
        name="RunPython",
        description=(
            "Run Python code to control installed Office applications with the "
            "provided data. This tool can execute arbitrary code."
        ),
    )


def main() -> None:
    """参数：无；返回值：无。"""
    default_root = Path.home() / "Documents" / "OfficeMCP"
    root_folder = Path(os.environ.get("OFFICEMCP_ROOT_FOLDER") or default_root).expanduser()
    root_folder.mkdir(parents=True, exist_ok=True)
    Officer._default_folder = str(root_folder.resolve())
    replace_run_python_tool()
    mcp.run("stdio")


if __name__ == "__main__":
    main()
