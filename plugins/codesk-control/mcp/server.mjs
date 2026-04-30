#!/usr/bin/env node
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const pluginRoot = fs.realpathSync(path.resolve(__dirname, ".."));
const repoRoot = path.resolve(pluginRoot, "..", "..");

const serverInfo = {
  name: "codesk-control",
  version: "0.1.0"
};

const tools = [
  {
    name: "codesk_state",
    description: "Preferred first step for inspecting macOS UI state. Returns front app, bundle id, window title, focused element, selected text, and visible Accessibility text.",
    inputSchema: {
      type: "object",
      properties: {
        json: { type: "boolean", description: "Return JSON from the underlying CLI. Defaults to true." },
        limit: { type: "number", description: "Maximum visible text lines to collect.", default: 120 }
      }
    }
  },
  {
    name: "codesk_text",
    description: "Return visible Accessibility text from the frontmost macOS window. Use after navigation to confirm what the app shows without screenshots.",
    inputSchema: {
      type: "object",
      properties: {
        limit: { type: "number", description: "Maximum visible text lines to collect.", default: 120 }
      }
    }
  },
  {
    name: "codesk_app",
    description: "Activate or launch a macOS app by name or bundle id. Preferred before sending app-specific shortcuts.",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Application name or bundle id, for example Safari or com.apple.finder." }
      },
      required: ["name"]
    }
  },
  {
    name: "codesk_open",
    description: "Open a URL or filesystem path with macOS Launch Services.",
    inputSchema: {
      type: "object",
      properties: {
        target: { type: "string", description: "URL or file/folder path to open." }
      },
      required: ["target"]
    }
  },
  {
    name: "codesk_key",
    description: "Send one native keyboard shortcut to macOS, such as cmd+l, cmd+shift+p, enter, escape, or option+left.",
    inputSchema: {
      type: "object",
      properties: {
        chord: { type: "string", description: "Shortcut chord." }
      },
      required: ["chord"]
    }
  },
  {
    name: "codesk_keys",
    description: "Send a short sequence of native keyboard shortcuts to macOS.",
    inputSchema: {
      type: "object",
      properties: {
        chords: {
          type: "array",
          items: { type: "string" },
          description: "Shortcut chords to send in order."
        }
      },
      required: ["chords"]
    }
  },
  {
    name: "codesk_quick",
    description: "Send an app-aware quick shortcut alias. Preferred over raw key chords for common actions like address, new_tab, find, quick_open, command_palette, goto_folder, and terminal.",
    inputSchema: {
      type: "object",
      properties: {
        alias: { type: "string", description: "Quick alias name, for example address, safari.address, quick_open, or finder.goto_folder." }
      },
      required: ["alias"]
    }
  },
  {
    name: "codesk_quick_list",
    description: "List available Codesk quick shortcut aliases.",
    inputSchema: {
      type: "object",
      properties: {}
    }
  },
  {
    name: "codesk_paste",
    description: "Paste text into the focused macOS field using the clipboard and cmd+v. Preferred for long text.",
    inputSchema: {
      type: "object",
      properties: {
        text: { type: "string", description: "Text to paste." },
        leaveClipboard: { type: "boolean", description: "Leave the pasted text on the clipboard instead of restoring previous clipboard contents.", default: false }
      },
      required: ["text"]
    }
  },
  {
    name: "codesk_type",
    description: "Type text key by key into the focused macOS field. Use when paste is rejected or literal typing matters.",
    inputSchema: {
      type: "object",
      properties: {
        text: { type: "string", description: "Text to type." },
        delayMs: { type: "number", description: "Delay between characters in milliseconds.", default: 3 }
      },
      required: ["text"]
    }
  },
  {
    name: "codesk_wait",
    description: "Wait for macOS UI state to match text, title, app, or focused element. Use after actions to confirm completion.",
    inputSchema: {
      type: "object",
      properties: {
        condition: { type: "string", enum: ["text", "title", "app", "focus"], description: "Condition type to wait for." },
        value: { type: "string", description: "Expected value or substring." },
        timeout: { type: "number", description: "Timeout in seconds.", default: 5 },
        interval: { type: "number", description: "Polling interval in seconds.", default: 0.1 }
      },
      required: ["condition", "value"]
    }
  },
  {
    name: "codesk_find",
    description: "Find visible Accessibility elements matching text in the front window. Use before pressing ambiguous controls.",
    inputSchema: {
      type: "object",
      properties: {
        text: { type: "string", description: "Text to find." }
      },
      required: ["text"]
    }
  },
  {
    name: "codesk_press",
    description: "Press a visible Accessibility element by label, title, value, or description.",
    inputSchema: {
      type: "object",
      properties: {
        label: { type: "string", description: "Visible label to press." }
      },
      required: ["label"]
    }
  },
  {
    name: "codesk_menu",
    description: "Select an app menu path through Accessibility, for example File > Save or View > Reload Page.",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Menu path separated by >." }
      },
      required: ["path"]
    }
  },
  {
    name: "codesk_screenshot",
    description: "Capture a screenshot only when text and Accessibility state are insufficient.",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Optional PNG output path." }
      }
    }
  },
  {
    name: "codesk_permissions",
    description: "Check whether Codesk has macOS Accessibility permission. Can prompt the user to grant it.",
    inputSchema: {
      type: "object",
      properties: {
        prompt: { type: "boolean", description: "Show the macOS Accessibility permission prompt.", default: false }
      }
    }
  },
  {
    name: "codesk_raw",
    description: "Advanced escape hatch: run a raw codesk CLI command as an argument array, without a shell.",
    inputSchema: {
      type: "object",
      properties: {
        args: {
          type: "array",
          items: { type: "string" },
          description: "Arguments after the codesk executable, for example [\"state\", \"--json\"]."
        },
        timeoutMs: { type: "number", description: "Timeout in milliseconds.", default: 10000 }
      },
      required: ["args"]
    }
  }
];

let buffer = "";
let inputEnded = false;
const pendingMessages = new Set();

process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => {
  buffer += chunk;
  while (true) {
    const newline = buffer.indexOf("\n");
    if (newline === -1) break;
    const line = buffer.slice(0, newline).replace(/\r$/, "");
    buffer = buffer.slice(newline + 1);
    if (line.trim() === "") continue;
    enqueueLine(line);
  }
});

process.stdin.on("end", () => {
  inputEnded = true;
  maybeExit();
});

function enqueueLine(line) {
  const pending = handleLine(line)
    .catch(error => {
      sendError(null, -32603, error.message ?? String(error));
    })
    .finally(() => {
      pendingMessages.delete(pending);
      maybeExit();
    });
  pendingMessages.add(pending);
}

function maybeExit() {
  if (inputEnded && pendingMessages.size === 0) {
    process.exit(0);
  }
}

async function handleLine(line) {
  let message;
  try {
    message = JSON.parse(line);
  } catch (error) {
    sendError(null, -32700, `Parse error: ${error.message}`);
    return;
  }

  if (!message.id && message.method?.startsWith("notifications/")) {
    return;
  }

  try {
    const result = await dispatch(message);
    if (message.id !== undefined) {
      send({ jsonrpc: "2.0", id: message.id, result });
    }
  } catch (error) {
    if (message.id !== undefined) {
      sendError(message.id, error.code ?? -32603, error.message ?? String(error));
    }
  }
}

async function dispatch(message) {
  switch (message.method) {
    case "initialize":
      return {
        protocolVersion: message.params?.protocolVersion ?? "2024-11-05",
        capabilities: {
          tools: {}
        },
        serverInfo
      };
    case "ping":
      return {};
    case "tools/list":
      return { tools };
    case "tools/call":
      return callTool(message.params ?? {});
    case "resources/list":
      return { resources: [] };
    case "prompts/list":
      return { prompts: [] };
    case "logging/setLevel":
      return {};
    default:
      throw rpcError(-32601, `Method not found: ${message.method}`);
  }
}

async function callTool(params) {
  const name = params.name;
  const args = params.arguments ?? {};

  if (!tools.some(tool => tool.name === name)) {
    throw rpcError(-32602, `Unknown tool: ${name}`);
  }

  try {
    const output = await runCodesk(argsForTool(name, args), timeoutForTool(name, args));
    return textResult(output || "ok");
  } catch (error) {
    return textResult(error.message, true);
  }
}

function argsForTool(name, args) {
  switch (name) {
    case "codesk_state": {
      const command = ["state"];
      if (args.json ?? true) command.push("--json");
      if (args.limit !== undefined) command.push("--limit", String(args.limit));
      return command;
    }
    case "codesk_text":
      return ["text", "--limit", String(args.limit ?? 120)];
    case "codesk_app":
      return ["app", requiredString(args, "name")];
    case "codesk_open":
      return ["open", requiredString(args, "target")];
    case "codesk_key":
      return ["key", requiredString(args, "chord")];
    case "codesk_keys":
      return ["keys", ...requiredStringArray(args, "chords")];
    case "codesk_quick":
      return ["q", requiredString(args, "alias")];
    case "codesk_quick_list":
      return ["q", "list"];
    case "codesk_paste": {
      const command = ["paste"];
      if (args.leaveClipboard) command.push("--leave-clipboard");
      command.push(requiredString(args, "text"));
      return command;
    }
    case "codesk_type": {
      const command = ["type"];
      if (args.delayMs !== undefined) command.push("--delay-ms", String(args.delayMs));
      command.push(requiredString(args, "text"));
      return command;
    }
    case "codesk_wait": {
      const command = ["wait", requiredString(args, "condition"), requiredString(args, "value")];
      if (args.timeout !== undefined) command.push("--timeout", String(args.timeout));
      if (args.interval !== undefined) command.push("--interval", String(args.interval));
      return command;
    }
    case "codesk_find":
      return ["find", requiredString(args, "text")];
    case "codesk_press":
      return ["press", requiredString(args, "label")];
    case "codesk_menu":
      return ["menu", requiredString(args, "path")];
    case "codesk_screenshot":
      return args.path ? ["screenshot", String(args.path)] : ["screenshot"];
    case "codesk_permissions": {
      const command = ["permissions"];
      if (args.prompt) command.push("--prompt");
      return command;
    }
    case "codesk_raw":
      return requiredStringArray(args, "args");
    default:
      throw rpcError(-32602, `Unhandled tool: ${name}`);
  }
}

function timeoutForTool(name, args) {
  if (name === "codesk_wait" && args.timeout !== undefined) {
    return Math.max(1000, Number(args.timeout) * 1000 + 1000);
  }
  if (name === "codesk_raw" && args.timeoutMs !== undefined) {
    return Number(args.timeoutMs);
  }
  if (name === "codesk_screenshot") return 15000;
  return 10000;
}

function requiredString(args, key) {
  const value = args[key];
  if (typeof value !== "string" || value.length === 0) {
    throw rpcError(-32602, `Missing required string argument: ${key}`);
  }
  return value;
}

function requiredStringArray(args, key) {
  const value = args[key];
  if (!Array.isArray(value) || !value.every(item => typeof item === "string")) {
    throw rpcError(-32602, `Missing required string array argument: ${key}`);
  }
  return value;
}

function textResult(text, isError = false) {
  return {
    content: [
      {
        type: "text",
        text
      }
    ],
    isError
  };
}

async function runCodesk(args, timeoutMs) {
  const bin = resolveCodeskBinary();
  return new Promise((resolve, reject) => {
    const child = spawn(bin, args, {
      cwd: repoRoot,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill("SIGTERM");
      reject(new Error(`codesk timed out after ${timeoutMs}ms: ${args.join(" ")}`));
    }, timeoutMs);

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", chunk => { stdout += chunk; });
    child.stderr.on("data", chunk => { stderr += chunk; });
    child.on("error", error => {
      clearTimeout(timer);
      reject(error);
    });
    child.on("close", code => {
      clearTimeout(timer);
      const output = [stdout.trim(), stderr.trim()].filter(Boolean).join("\n");
      if (code === 0) {
        resolve(output);
      } else {
        reject(new Error(output || `codesk exited with status ${code}`));
      }
    });
  });
}

function resolveCodeskBinary() {
  const candidates = [];
  if (process.env.CODESK_BIN) {
    candidates.push(path.resolve(process.cwd(), process.env.CODESK_BIN));
    candidates.push(path.resolve(pluginRoot, process.env.CODESK_BIN));
  }
  candidates.push(path.join(repoRoot, ".build", "release", "codesk"));
  candidates.push(path.join(repoRoot, ".build", "debug", "codesk"));
  candidates.push("/Volumes/EXT/Applications/Codesk control/.build/release/codesk");

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  return "codesk";
}

function send(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

function sendError(id, code, message) {
  send({
    jsonrpc: "2.0",
    id,
    error: { code, message }
  });
}

function rpcError(code, message) {
  const error = new Error(message);
  error.code = code;
  return error;
}
