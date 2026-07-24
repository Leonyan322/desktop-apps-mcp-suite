// 只通过 initialize 与 tools/list 检查 stdio MCP 服务。

import { spawn, spawnSync } from "node:child_process";
import { once } from "node:events";
import { createInterface } from "node:readline";

// 参数：命令行；返回值：解析后的探针设置。
function parse_arguments(argv) {
  const separator_index = argv.indexOf("--");
  if (separator_index < 0 || separator_index === argv.length - 1) {
    throw new Error("missing MCP server command");
  }
  const options = argv.slice(0, separator_index);
  const command = argv.slice(separator_index + 1);
  const read_option = (name, fallback = undefined) => {
    const option_index = options.indexOf(name);
    return option_index >= 0 ? options[option_index + 1] : fallback;
  };
  const name = read_option("--name");
  const cwd = read_option("--cwd");
  const timeout_ms = Number(read_option("--timeout", "45")) * 1000;
  if (!name || !cwd || !Number.isFinite(timeout_ms)) {
    throw new Error("invalid probe arguments");
  }
  return { name, cwd, timeout_ms, command };
}

// 参数：毫秒；返回值：延迟 Promise。
function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

// 参数：子进程；返回值：无。
async function stop_process_tree(child) {
  if (child.stdin && !child.stdin.destroyed) {
    child.stdin.end();
  }
  if (child.exitCode === null) {
    await Promise.race([once(child, "exit"), delay(2000)]);
  }
  if (child.exitCode === null) {
    if (process.platform === "win32") {
      spawnSync("taskkill.exe", ["/PID", String(child.pid), "/T", "/F"], {
        stdio: "ignore",
        windowsHide: true,
      });
    } else {
      child.kill("SIGKILL");
    }
  }
}

// 参数：探针设置；返回值：进程退出码。
async function probe_server(settings) {
  const [file_path, ...arguments_list] = settings.command;
  const child = spawn(file_path, arguments_list, {
    cwd: settings.cwd,
    windowsHide: true,
    stdio: ["pipe", "pipe", "pipe"],
  });
  child.stdin.setDefaultEncoding("utf8");
  child.stdout.setEncoding("utf8");
  child.stderr.setEncoding("utf8");

  const pending = new Map();
  const stderr_lines = [];
  let fatal_error = null;

  // 参数：错误；返回值：无。
  const fail_pending = (error) => {
    fatal_error = error;
    for (const { reject, timer } of pending.values()) {
      clearTimeout(timer);
      reject(error);
    }
    pending.clear();
  };

  child.on("error", fail_pending);
  child.on("exit", (code) => {
    if (pending.size > 0) {
      fail_pending(new Error(`server exited with code ${code}`));
    }
  });
  child.stderr.on("data", (chunk) => {
    stderr_lines.push(...String(chunk).split(/\r?\n/).filter(Boolean));
    if (stderr_lines.length > 20) {
      stderr_lines.splice(0, stderr_lines.length - 20);
    }
  });

  const reader = createInterface({ input: child.stdout });
  reader.on("line", (line) => {
    if (!line.trim()) {
      return;
    }
    let message;
    try {
      message = JSON.parse(line);
    } catch {
      fail_pending(new Error(`non-JSON stdout: ${line.slice(0, 200)}`));
      return;
    }
    const waiter = pending.get(message.id);
    if (!waiter) {
      return;
    }
    pending.delete(message.id);
    clearTimeout(waiter.timer);
    if (message.error) {
      waiter.reject(new Error(`JSON-RPC error: ${JSON.stringify(message.error)}`));
    } else {
      waiter.resolve(message);
    }
  });

  // 参数：JSON-RPC 消息；返回值：无。
  const send_message = (message) => {
    if (fatal_error) {
      throw fatal_error;
    }
    child.stdin.write(`${JSON.stringify(message)}\n`);
  };

  // 参数：请求消息；返回值：响应 Promise。
  const request = (message) => new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(message.id);
      reject(new Error(`request ${message.id} timed out`));
    }, settings.timeout_ms);
    pending.set(message.id, { resolve, reject, timer });
    try {
      send_message(message);
    } catch (error) {
      clearTimeout(timer);
      pending.delete(message.id);
      reject(error);
    }
  });

  try {
    const initialize_response = await request({
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "desktop-excel-health-check", version: "0.2.0" },
      },
    });
    send_message({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
    const tools_response = await request({
      jsonrpc: "2.0",
      id: 2,
      method: "tools/list",
      params: {},
    });
    const tools = tools_response?.result?.tools;
    if (!Array.isArray(tools) || tools.length === 0) {
      throw new Error("tools/list returned no tools");
    }
    const server_name = initialize_response?.result?.serverInfo?.name || settings.name;
    process.stdout.write(`initialize=${server_name};tools=${tools.length}\n`);
    return 0;
  } catch (error) {
    const stderr_tail = stderr_lines.join(" | ").slice(0, 600);
    const suffix = stderr_tail ? `; stderr=${stderr_tail}` : "";
    process.stderr.write(`${settings.name}: ${error.message}${suffix}\n`);
    return 1;
  } finally {
    reader.close();
    await stop_process_tree(child);
  }
}

// 参数：无；返回值：进程退出码。
async function main() {
  const settings = parse_arguments(process.argv.slice(2));
  return probe_server(settings);
}

process.exitCode = await main();
