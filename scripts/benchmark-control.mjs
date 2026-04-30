#!/usr/bin/env node
import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { performance } from "node:perf_hooks";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const codeskBin = path.join(repoRoot, ".build", "release", "codesk");
const resultsDir = path.join(repoRoot, "benchmarks", "results");
const pluginRoot = path.join(repoRoot, "plugins", "codesk-control");

const options = parseArgs(process.argv.slice(2));

async function main() {
  const startedAt = new Date();
  const stamp = startedAt.toISOString().replace(/[:.]/g, "-");

  await fs.mkdir(resultsDir, { recursive: true });

  const metadata = {
    benchmark: "codesk-control-baseline",
    startedAt: startedAt.toISOString(),
    host: os.hostname(),
    platform: process.platform,
    arch: process.arch,
    node: process.version,
    iterations: options.iterations,
    warmup: options.warmup,
    redacted: true
  };

  const [swVers, swiftVersion, codeskVersion, liveSystems] = await Promise.all([
    runText("/usr/bin/sw_vers", []),
    runText("/usr/bin/swift", ["--version"]),
    runText(codeskBin, ["version"]),
    collectLiveSystems()
  ]);

  metadata.swVers = swVers.stdout.trim();
  metadata.swiftVersion = firstLine(swiftVersion.stdout);
  metadata.codeskVersion = codeskVersion.stdout.trim();

  const benchmarks = [];

  benchmarks.push(await benchmarkCommand({
    name: "codesk_state_json",
    category: "after: native text state",
    command: codeskBin,
    args: ["state", "--json", "--limit", String(options.textLimit)],
    behavior: summarizeCodeskState
  }));

  benchmarks.push(await benchmarkCommand({
    name: "codesk_text",
    category: "after: native text extraction",
    command: codeskBin,
    args: ["text", "--limit", String(options.textLimit)],
    behavior: summarizeTextOutput
  }));

  benchmarks.push(await benchmarkCommand({
    name: "codesk_quick_list",
    category: "after: shortcut registry",
    command: codeskBin,
    args: ["q", "list"],
    behavior: summarizeTextOutput
  }));

  benchmarks.push(await benchmarkMcpState());

  benchmarks.push(await benchmarkCommand({
    name: "osascript_front_app",
    category: "before: AppleScript process spawn",
    command: "/usr/bin/osascript",
    args: [
      "-e",
      'tell application "System Events" to get name of first application process whose frontmost is true'
    ],
    behavior: summarizeTextOutput
  }));

  benchmarks.push(await benchmarkCommand({
    name: "osascript_window_title",
    category: "before: AppleScript AX query",
    command: "/usr/bin/osascript",
    args: [
      "-e",
      'tell application "System Events"',
      "-e",
      'set frontProcess to first application process whose frontmost is true',
      "-e",
      'tell frontProcess',
      "-e",
      'if exists window 1 then return name of window 1',
      "-e",
      'return ""',
      "-e",
      'end tell',
      "-e",
      'end tell'
    ],
    behavior: summarizeTextOutput
  }));

  if (!options.skipScreenshot) {
    benchmarks.push(await benchmarkScreenshot());
  }

  const report = {
    metadata,
    liveSystems,
    benchmarks,
    comparisons: buildComparisons(benchmarks, "codesk_state_json")
  };

  const jsonPath = path.join(resultsDir, `${stamp}-baseline.json`);
  const mdPath = path.join(resultsDir, `${stamp}-baseline.md`);
  await fs.writeFile(jsonPath, JSON.stringify(report, null, 2) + "\n");
  await fs.writeFile(mdPath, renderMarkdown(report) + "\n");

  console.log(`Wrote ${jsonPath}`);
  console.log(`Wrote ${mdPath}`);
  console.log("");
  console.log(renderSummary(report));
}

function parseArgs(args) {
  const parsed = {
    iterations: 12,
    warmup: 3,
    textLimit: 40,
    skipScreenshot: false
  };

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    const readValue = () => {
      const value = args[i + 1];
      if (value === undefined) throw new Error(`Missing value for ${arg}`);
      i += 1;
      return value;
    };

    if (arg === "--iterations") parsed.iterations = Number(readValue());
    else if (arg.startsWith("--iterations=")) parsed.iterations = Number(arg.slice("--iterations=".length));
    else if (arg === "--warmup") parsed.warmup = Number(readValue());
    else if (arg.startsWith("--warmup=")) parsed.warmup = Number(arg.slice("--warmup=".length));
    else if (arg === "--text-limit") parsed.textLimit = Number(readValue());
    else if (arg.startsWith("--text-limit=")) parsed.textLimit = Number(arg.slice("--text-limit=".length));
    else if (arg === "--skip-screenshot") parsed.skipScreenshot = true;
    else if (arg === "--help" || arg === "-h") {
      console.log(`Usage: scripts/benchmark-control.mjs [--iterations n] [--warmup n] [--text-limit n] [--skip-screenshot]`);
      process.exit(0);
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  for (const key of ["iterations", "warmup", "textLimit"]) {
    if (!Number.isFinite(parsed[key]) || parsed[key] < 0) {
      throw new Error(`Invalid numeric option: ${key}`);
    }
  }
  parsed.iterations = Math.max(1, Math.floor(parsed.iterations));
  parsed.warmup = Math.floor(parsed.warmup);
  parsed.textLimit = Math.floor(parsed.textLimit);
  return parsed;
}

async function benchmarkCommand(config) {
  const samples = [];
  let behavior = {};

  for (let i = 0; i < options.warmup + options.iterations; i += 1) {
    const sample = await timeAsync(() => runText(config.command, config.args, { timeoutMs: config.timeoutMs ?? 15000 }));
    if (i >= options.warmup) {
      samples.push(sample);
      if (Object.keys(behavior).length === 0) {
        behavior = config.behavior?.(sample.result) ?? {};
      }
    }
  }

  return {
    name: config.name,
    category: config.category,
    command: redactCommand(config.command, config.args),
    stats: summarizeSamples(samples),
    behavior
  };
}

async function benchmarkScreenshot() {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "codesk-bench-"));
  try {
    const samples = [];
    let behavior = {};
    for (let i = 0; i < options.warmup + options.iterations; i += 1) {
      const file = path.join(tempDir, `shot-${i}.png`);
      const sample = await timeAsync(async () => {
        const result = await runText("/usr/sbin/screencapture", ["-x", file], { timeoutMs: 20000 });
        const stat = await fs.stat(file).catch(() => null);
        await fs.rm(file, { force: true });
        return {
          ...result,
          screenshotBytes: stat?.size ?? 0
        };
      });
      if (i >= options.warmup) {
        samples.push(sample);
        if (Object.keys(behavior).length === 0) {
          behavior = {
            outputKind: "png-file-then-deleted",
            screenshotBytes: sample.result.screenshotBytes,
            textAvailable: false
          };
        }
      }
    }
    return {
      name: "screencapture_png",
      category: "before: vision capture substrate",
      command: "/usr/sbin/screencapture -x <temp.png>",
      stats: summarizeSamples(samples),
      behavior
    };
  } finally {
    await fs.rm(tempDir, { recursive: true, force: true });
  }
}

async function benchmarkMcpState() {
  const client = new McpClient(pluginRoot);
  await client.start();
  try {
    await client.request("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "codesk-benchmark", version: "0.1.0" }
    });
    client.notify("notifications/initialized", {});

    const samples = [];
    let behavior = {};
    for (let i = 0; i < options.warmup + options.iterations; i += 1) {
      const sample = await timeAsync(() => client.request("tools/call", {
        name: "codesk_state",
        arguments: { json: true, limit: options.textLimit }
      }));
      if (i >= options.warmup) {
        samples.push(sample);
        if (Object.keys(behavior).length === 0) {
          behavior = summarizeMcpTextResult(sample.result);
        }
      }
    }

    return {
      name: "codesk_mcp_state",
      category: "after: persistent MCP tool call",
      command: "MCP tools/call codesk_state",
      stats: summarizeSamples(samples),
      behavior
    };
  } finally {
    await client.stop();
  }
}

class McpClient {
  constructor(cwd) {
    this.cwd = cwd;
    this.nextId = 1;
    this.pending = new Map();
    this.buffer = "";
  }

  async start() {
    this.child = spawn("./mcp/codesk-mcp.sh", ["mcp"], {
      cwd: this.cwd,
      env: process.env,
      stdio: ["pipe", "pipe", "pipe"]
    });
    this.child.stdout.setEncoding("utf8");
    this.child.stderr.setEncoding("utf8");
    this.child.stdout.on("data", chunk => this.onStdout(chunk));
    this.child.stderr.on("data", chunk => {
      this.stderr = (this.stderr ?? "") + chunk;
    });
    this.child.on("exit", code => {
      for (const { reject } of this.pending.values()) {
        reject(new Error(`MCP server exited with ${code}`));
      }
      this.pending.clear();
    });
  }

  onStdout(chunk) {
    this.buffer += chunk;
    while (true) {
      const newline = this.buffer.indexOf("\n");
      if (newline === -1) break;
      const line = this.buffer.slice(0, newline);
      this.buffer = this.buffer.slice(newline + 1);
      if (!line.trim()) continue;
      const message = JSON.parse(line);
      const pending = this.pending.get(message.id);
      if (!pending) continue;
      this.pending.delete(message.id);
      if (message.error) pending.reject(new Error(message.error.message));
      else pending.resolve(message.result);
    }
  }

  request(method, params) {
    const id = this.nextId;
    this.nextId += 1;
    const message = { jsonrpc: "2.0", id, method, params };
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`MCP request timed out: ${method}`));
      }, 15000);
      this.pending.set(id, {
        resolve: value => {
          clearTimeout(timer);
          resolve(value);
        },
        reject: error => {
          clearTimeout(timer);
          reject(error);
        }
      });
      this.child.stdin.write(JSON.stringify(message) + "\n");
    });
  }

  notify(method, params) {
    this.child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method, params }) + "\n");
  }

  async stop() {
    if (!this.child) return;
    this.child.stdin.end();
    await new Promise(resolve => {
      const timer = setTimeout(() => {
        this.child.kill("SIGTERM");
        resolve();
      }, 1000);
      this.child.on("exit", () => {
        clearTimeout(timer);
        resolve();
      });
    });
  }
}

async function collectLiveSystems() {
  const result = await runText("/bin/ps", ["-axo", "pid,ppid,etime,pcpu,pmem,comm,args"]);
  const lines = result.stdout.split("\n").slice(1).filter(Boolean);
  const groups = [
    { name: "codex_app", pattern: /\/Applications\/Codex\.app/i },
    { name: "computer_use_mcp", pattern: /SkyComputerUseClient.*\bmcp\b/i },
    { name: "webtool_mcp", pattern: /codex-web-mcp\.mjs/i },
    { name: "codesk_mcp", pattern: /codesk-control\/mcp\/server\.mjs/i },
    { name: "telecodex_bridge", pattern: /Telecodex.*bridge|telecodex_bridge/i },
    { name: "chrome_remote_debugging", pattern: /Google Chrome.*remote-debugging-port/i },
    { name: "osascript", pattern: /\bosascript\b/i },
    { name: "screencapture", pattern: /\bscreencapture\b/i }
  ];

  return groups.map(group => {
    const matches = lines.filter(line => group.pattern.test(line));
    return {
      name: group.name,
      count: matches.length,
      examples: matches.slice(0, 5).map(redactProcessLine)
    };
  });
}

async function runText(command, args, { timeoutMs = 10000 } = {}) {
  return new Promise(resolve => {
    const child = spawn(command, args, { cwd: repoRoot, stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
    }, timeoutMs);
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", chunk => { stdout += chunk; });
    child.stderr.on("data", chunk => { stderr += chunk; });
    child.on("error", error => {
      clearTimeout(timer);
      resolve({ exitCode: -1, stdout, stderr: String(error), timedOut });
    });
    child.on("close", code => {
      clearTimeout(timer);
      resolve({ exitCode: code ?? -1, stdout, stderr, timedOut });
    });
  });
}

async function timeAsync(fn) {
  const start = performance.now();
  const result = await fn();
  const durationMs = performance.now() - start;
  return {
    durationMs,
    success: result?.exitCode === undefined ? true : result.exitCode === 0 && !result.timedOut,
    result
  };
}

function summarizeSamples(samples) {
  const durations = samples.map(sample => sample.durationMs).sort((a, b) => a - b);
  const successes = samples.filter(sample => sample.success).length;
  return {
    runs: samples.length,
    successRate: round(successes / samples.length),
    minMs: round(durations[0]),
    medianMs: round(percentile(durations, 0.5)),
    meanMs: round(durations.reduce((sum, value) => sum + value, 0) / durations.length),
    p95Ms: round(percentile(durations, 0.95)),
    maxMs: round(durations[durations.length - 1])
  };
}

function summarizeCodeskState(result) {
  const text = result.stdout.trim();
  let parsed = {};
  try {
    parsed = JSON.parse(text);
  } catch {
    return summarizeTextOutput(result);
  }
  return {
    outputKind: "json-ui-state",
    frontApp: parsed.frontApp ?? null,
    bundleIdentifier: parsed.bundleIdentifier ?? null,
    processIdentifierPresent: parsed.processIdentifier !== undefined,
    windowTitlePresent: Boolean(parsed.windowTitle),
    focusedRole: parsed.focusedRole ?? null,
    focusedTitlePresent: Boolean(parsed.focusedTitle),
    focusedValuePresent: Boolean(parsed.focusedValue),
    selectedTextPresent: Boolean(parsed.selectedText),
    accessibilityTrusted: Boolean(parsed.accessibilityTrusted),
    visibleTextCount: Array.isArray(parsed.visibleText) ? parsed.visibleText.length : 0,
    outputBytes: Buffer.byteLength(text)
  };
}

function summarizeMcpTextResult(result) {
  const text = result?.content?.find(item => item.type === "text")?.text ?? "";
  return summarizeCodeskState({ stdout: text, stderr: "", exitCode: result?.isError ? 1 : 0 });
}

function summarizeTextOutput(result) {
  const text = result.stdout.trim();
  return {
    outputKind: "text",
    lineCount: text ? text.split("\n").length : 0,
    outputBytes: Buffer.byteLength(text),
    stderrBytes: Buffer.byteLength(result.stderr ?? ""),
    exitCode: result.exitCode,
    timedOut: Boolean(result.timedOut),
    textAvailable: Boolean(text)
  };
}

function buildComparisons(benchmarks, baselineName) {
  const baseline = benchmarks.find(item => item.name === baselineName);
  if (!baseline) return [];
  const baselineMedian = baseline.stats.medianMs;
  return benchmarks.map(item => ({
    name: item.name,
    medianMs: item.stats.medianMs,
    versusBaseline: item.name === baselineName ? 1 : round(item.stats.medianMs / baselineMedian)
  }));
}

function renderMarkdown(report) {
  const lines = [];
  lines.push("# Codesk Control Baseline Benchmark");
  lines.push("");
  lines.push(`- Started: ${report.metadata.startedAt}`);
  lines.push(`- Host: ${report.metadata.host}`);
  lines.push(`- Iterations: ${report.metadata.iterations} measured, ${report.metadata.warmup} warmup`);
  lines.push(`- Codesk: ${report.metadata.codeskVersion}`);
  lines.push("");
  lines.push("## Live Systems");
  lines.push("");
  lines.push("| System | Count | Example |");
  lines.push("| --- | ---: | --- |");
  for (const group of report.liveSystems) {
    lines.push(`| ${group.name} | ${group.count} | ${escapeMarkdown(group.examples[0] ?? "")} |`);
  }
  lines.push("");
  lines.push("## Timing");
  lines.push("");
  lines.push("| Benchmark | Category | Success | Median ms | Mean ms | P95 ms | vs codesk_state |");
  lines.push("| --- | --- | ---: | ---: | ---: | ---: | ---: |");
  for (const item of report.benchmarks) {
    const comparison = report.comparisons.find(row => row.name === item.name);
    lines.push(`| ${item.name} | ${item.category} | ${Math.round(item.stats.successRate * 100)}% | ${item.stats.medianMs} | ${item.stats.meanMs} | ${item.stats.p95Ms} | ${comparison?.versusBaseline ?? ""}x |`);
  }
  lines.push("");
  lines.push("## Behavior");
  lines.push("");
  for (const item of report.benchmarks) {
    lines.push(`### ${item.name}`);
    lines.push("");
    lines.push("```json");
    lines.push(JSON.stringify(item.behavior, null, 2));
    lines.push("```");
    lines.push("");
  }
  return lines.join("\n");
}

function renderSummary(report) {
  const rows = report.benchmarks.map(item => {
    const comparison = report.comparisons.find(row => row.name === item.name);
    return `${item.name.padEnd(24)} median=${String(item.stats.medianMs).padStart(7)}ms p95=${String(item.stats.p95Ms).padStart(7)}ms vs=${comparison?.versusBaseline ?? ""}x`;
  });
  return rows.join("\n");
}

function redactCommand(command, args) {
  if (command === codeskBin) {
    return `.build/release/codesk ${args.join(" ")}`;
  }
  return [command, ...args].join(" ");
}

function redactProcessLine(line) {
  return line
    .replaceAll(os.homedir(), "~")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 220);
}

function firstLine(value) {
  return value.trim().split("\n")[0] ?? "";
}

function percentile(values, p) {
  if (values.length === 0) return 0;
  const index = (values.length - 1) * p;
  const lower = Math.floor(index);
  const upper = Math.ceil(index);
  if (lower === upper) return values[lower];
  const weight = index - lower;
  return values[lower] * (1 - weight) + values[upper] * weight;
}

function round(value) {
  return Math.round(value * 100) / 100;
}

function escapeMarkdown(value) {
  return value.replaceAll("|", "\\|");
}

await main();
