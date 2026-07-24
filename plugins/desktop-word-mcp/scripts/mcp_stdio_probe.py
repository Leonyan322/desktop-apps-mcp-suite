# coding=utf-8
"""只通过 initialize 与 tools/list 检查 stdio MCP 服务。"""

from __future__ import annotations

import argparse
import json
import os
import queue
import subprocess
import sys
import threading
import time
from collections.abc import Sequence


def parse_arguments() -> argparse.Namespace:
    """参数：命令行；返回值：探针设置与服务启动命令。"""
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--timeout", type=float, default=45.0)
    parser.add_argument("--cwd", required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    arguments = parser.parse_args()
    if arguments.command and arguments.command[0] == "--":
        arguments.command = arguments.command[1:]
    if not arguments.command:
        parser.error("missing MCP server command")
    return arguments


def read_stream_lines(stream: object, output_queue: queue.Queue[str | None]) -> None:
    """参数：文本流与输出队列；返回值：无。"""
    try:
        for line in stream:  # type: ignore[union-attr]
            output_queue.put(line.rstrip("\r\n"))
    finally:
        output_queue.put(None)


def collect_stderr(stream: object, lines: list[str]) -> None:
    """参数：stderr 文本流与目标列表；返回值：无。"""
    for line in stream:  # type: ignore[union-attr]
        lines.append(line.rstrip("\r\n"))
        if len(lines) > 20:
            del lines[0]


def send_message(process: subprocess.Popen[str], message: dict) -> None:
    """参数：服务进程与 JSON-RPC 消息；返回值：无。"""
    if process.stdin is None:
        raise RuntimeError("server stdin is unavailable")
    process.stdin.write(json.dumps(message, ensure_ascii=False, separators=(",", ":")) + "\n")
    process.stdin.flush()


def receive_response(
    process: subprocess.Popen[str],
    output_queue: queue.Queue[str | None],
    request_id: int,
    deadline: float,
) -> dict:
    """参数：进程、输出队列、请求 ID 与截止时间；返回值：对应响应。"""
    while time.monotonic() < deadline:
        remaining = max(0.05, deadline - time.monotonic())
        try:
            line = output_queue.get(timeout=min(0.25, remaining))
        except queue.Empty:
            if process.poll() is not None:
                raise RuntimeError(f"server exited with code {process.returncode}")
            continue
        if line is None:
            raise RuntimeError(f"server closed stdout with code {process.poll()}")
        if not line.strip():
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError as error:
            raise RuntimeError(f"non-JSON stdout: {line[:200]}") from error
        if message.get("id") != request_id:
            continue
        if "error" in message:
            raise RuntimeError(f"JSON-RPC error: {message['error']}")
        return message
    raise TimeoutError(f"request {request_id} timed out")


def stop_process_tree(process: subprocess.Popen[str]) -> None:
    """参数：探针创建的服务进程；返回值：无。"""
    if process.stdin is not None:
        try:
            process.stdin.close()
        except OSError:
            pass
    try:
        process.wait(timeout=2)
        return
    except subprocess.TimeoutExpired:
        pass
    if os.name == "nt":
        subprocess.run(
            ["taskkill.exe", "/PID", str(process.pid), "/T", "/F"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    else:
        process.kill()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()


def probe_server(name: str, command: Sequence[str], cwd: str, timeout: float) -> int:
    """参数：服务名称、启动命令、目录与超时；返回值：进程退出码。"""
    creation_flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    process = subprocess.Popen(
        list(command),
        cwd=cwd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
        creationflags=creation_flags,
    )
    output_queue: queue.Queue[str | None] = queue.Queue()
    stderr_lines: list[str] = []
    threading.Thread(target=read_stream_lines, args=(process.stdout, output_queue), daemon=True).start()
    threading.Thread(target=collect_stderr, args=(process.stderr, stderr_lines), daemon=True).start()

    deadline = time.monotonic() + timeout
    try:
        send_message(
            process,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "desktop-word-health-check", "version": "0.2.0"},
                },
            },
        )
        initialize_response = receive_response(process, output_queue, 1, deadline)
        server_info = initialize_response.get("result", {}).get("serverInfo", {})
        send_message(process, {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})
        send_message(process, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
        tools_response = receive_response(process, output_queue, 2, deadline)
        tools = tools_response.get("result", {}).get("tools", [])
        if not isinstance(tools, list) or not tools:
            raise RuntimeError("tools/list returned no tools")
        print(f"initialize={server_info.get('name') or name};tools={len(tools)}")
        return 0
    except Exception as error:
        stderr_tail = " | ".join(line for line in stderr_lines if line.strip())
        details = f"{name}: {error}"
        if stderr_tail:
            details += f"; stderr={stderr_tail[:600]}"
        print(details, file=sys.stderr)
        return 1
    finally:
        stop_process_tree(process)


def main() -> int:
    """参数：无；返回值：探针退出码。"""
    arguments = parse_arguments()
    return probe_server(arguments.name, arguments.command, arguments.cwd, arguments.timeout)


if __name__ == "__main__":
    raise SystemExit(main())
