#!/usr/bin/env bun

import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { spawn, spawnSync } from "node:child_process";

type Issue = {
  id: string;
  title: string;
  description?: string;
  type: string;
  status: string;
  priority?: number;
  parent?: string;
  labels?: string[];
  blocked_by?: string[];
  blocks?: string[];
};

type Args = {
  positional: string[];
  options: Record<string, string | boolean>;
};

type RunResult = {
  stdout: string;
  stderr: string;
};

const factoryRoot = resolve(import.meta.dir, "..");
const repoRoot = resolve(factoryRoot, "..");

async function main() {
  loadDotEnv(join(factoryRoot, ".env"));
  loadDotEnv(join(repoRoot, ".env"));

  const [command = "help", ...rest] = process.argv.slice(2);
  const args = parseArgs(rest);

  switch (command) {
    case "doctor":
      doctor();
      break;
    case "prompt":
      prompt(args);
      break;
    case "step":
      await step(args);
      break;
    case "loop":
      await loop(args);
      break;
    case "help":
    case "--help":
    case "-h":
      help();
      break;
    default:
      fail(`Unknown command: ${command}`);
  }
}

function help() {
  console.log(`Pi Connector Factory

Usage:
  bun run doctor
  bun run prompt [--issue <id>] [--allow-epic]
  bun run step [--issue <id>] [--allow-epic]
  bun run loop [--limit <n>] [--allow-epic]

Beadwork owns the backlog. This wrapper selects one ready Beadwork task and
asks Pi + Z.ai to produce exactly one clean Git commit.
`);
}

function doctor() {
  const checks = [
    ["bun", commandExists("bun")],
    ["pi", commandExists("pi")],
    ["bw", commandExists("bw")],
    ["git", commandExists("git")],
    ["ZAI_API_KEY", Boolean(process.env.ZAI_API_KEY)],
    ["repo root", existsSync(join(repoRoot, "mix.exs"))],
    ["Beadwork", canRun("bw", ["ready", "--json"])]
  ] as const;

  for (const [name, ok] of checks) {
    console.log(`${ok ? "ok " : "NO "} ${name}`);
  }

  const ready = queueIssues();
  const nextTask = ready.find((issue) => issue.type !== "epic");

  console.log("");
  console.log(`Repo:        ${repoRoot}`);
  console.log(`Pi provider: ${piProvider()}`);
  console.log(`Pi model:    ${piModel()}`);
  console.log(`Thinking:    ${piThinking()}`);
  console.log(`Ready tasks: ${ready.filter((issue) => issue.type !== "epic").length}`);

  if (nextTask) {
    console.log(`Next task:   ${nextTask.id} ${nextTask.title}`);
  } else {
    console.log("Next task:   none; split a ready epic into child tasks first");
  }
}

function prompt(args: Args) {
  const issue = selectIssue(args);
  const promptText = renderPrompt(issue);
  const runDir = ensureRunDir(issue, "prompt");

  writeFileSync(join(runDir, "prompt.md"), promptText);
  console.log(promptText);
  console.log("");
  console.log(`wrote ${relativeToRepo(join(runDir, "prompt.md"))}`);
}

async function step(args: Args) {
  ensureCleanGit("before starting Pi");

  const issue = selectIssue(args);
  const beforeHead = git(["rev-parse", "HEAD"]).stdout.trim();
  const runDir = ensureRunDir(issue, "step");

  startIssue(issue);

  const startedIssue = showIssue(issue.id);
  const promptText = renderPrompt(startedIssue);
  writeFileSync(join(runDir, "prompt.md"), promptText);

  console.log(`issue: ${startedIssue.id} ${startedIssue.title}`);
  console.log(`run:   ${relativeToRepo(runDir)}`);

  const piOutput = await runPi(promptText, runDir);
  writeFileSync(join(runDir, "pi.stdout.log"), piOutput.stdout);
  writeFileSync(join(runDir, "pi.stderr.log"), piOutput.stderr);

  const afterHead = git(["rev-parse", "HEAD"]).stdout.trim();
  const commitCount = Number(git(["rev-list", "--count", `${beforeHead}..${afterHead}`]).stdout);

  if (afterHead === beforeHead || commitCount !== 1) {
    fail(`Pi must create exactly one Git commit; found ${commitCount}`);
  }

  ensureCleanGit("after Pi commit");

  const shortSha = git(["rev-parse", "--short", "HEAD"]).stdout.trim();
  const finalIssue = showIssue(issue.id);

  if (finalIssue.status !== "closed") {
    run("bw", ["close", issue.id, "--reason", `Implemented in ${shortSha} by pi-connector-factory`], {
      cwd: repoRoot
    });
  }

  console.log(`done: ${issue.id} -> ${shortSha}`);
}

async function loop(args: Args) {
  const limit = Number(args.options.limit || "5");
  if (!Number.isFinite(limit) || limit < 1) fail("--limit must be a positive number");

  for (let index = 0; index < limit; index += 1) {
    const issue = selectIssue({ ...args, options: { ...args.options, issue: false } }, true);

    if (!issue) {
      console.log("No ready Beadwork task left.");
      return;
    }

    console.log(`\n[${index + 1}/${limit}] ${issue.id} ${issue.title}`);
    await step({ positional: [], options: { ...args.options, issue: issue.id } });
  }
}

function selectIssue(args: Args, nullable?: false): Issue;
function selectIssue(args: Args, nullable: true): Issue | undefined;
function selectIssue(args: Args, nullable = false) {
  const issueId = stringOption(args.options.issue);
  const allowEpic = args.options["allow-epic"] === true;
  const issue = issueId ? showIssue(issueId) : queueIssues().find((item) => allowEpic || item.type !== "epic");

  if (!issue) {
    if (nullable) return undefined;
    fail("No ready non-epic Beadwork task found. Split a ready epic into child tasks first.");
  }

  if (issue.type === "epic" && !allowEpic) {
    fail(`${issue.id} is an epic. Use a child task, or pass --allow-epic deliberately.`);
  }

  if (!["open", "in_progress"].includes(issue.status)) {
    fail(`${issue.id} has status ${issue.status}; expected open or in_progress`);
  }

  return issue;
}

function startIssue(issue: Issue) {
  if (issue.status === "in_progress") return;

  run("bw", ["start", issue.id], { cwd: repoRoot });
}

function readyIssues() {
  return parseJson<Issue[]>(run("bw", ["ready", "--json"], { cwd: repoRoot, capture: true }).stdout);
}

function queueIssues() {
  const rawReady = readyIssues();
  const queue = new Map<string, Issue>();
  const blockerStatus = new Map<string, string>();

  for (const issue of rawReady) {
    if (issue.type !== "epic") {
      queue.set(issue.id, issue);
      continue;
    }

    for (const child of childIssues(issue.id)) {
      if (isReadyLeaf(child, blockerStatus)) {
        queue.set(child.id, child);
      }
    }

    queue.set(issue.id, issue);
  }

  return [...queue.values()];
}

function childIssues(parentId: string) {
  return parseJson<Issue[]>(
    run("bw", ["list", "--parent", parentId, "--json"], { cwd: repoRoot, capture: true }).stdout
  );
}

function isReadyLeaf(issue: Issue, blockerStatus: Map<string, string>) {
  if (issue.type === "epic") return false;
  if (!["open", "in_progress"].includes(issue.status)) return false;

  return (issue.blocked_by || []).every((blockerId) => {
    let status = blockerStatus.get(blockerId);

    if (!status) {
      status = showIssue(blockerId).status;
      blockerStatus.set(blockerId, status);
    }

    return status === "closed";
  });
}

function showIssue(id: string) {
  return parseJson<Issue>(run("bw", ["show", id, "--json"], { cwd: repoRoot, capture: true }).stdout);
}

function renderPrompt(issue: Issue) {
  return renderTemplate(readFileSync(join(factoryRoot, "templates/step.md"), "utf8"), {
    issue_id: issue.id,
    issue_json: JSON.stringify(issue, null, 2)
  });
}

async function runPi(promptText: string, runDir: string): Promise<RunResult> {
  if (!process.env.ZAI_API_KEY) {
    fail("ZAI_API_KEY is missing. Put it in pi-connector-factory/.env or the repo root .env.");
  }

  const sessionDir = join(runDir, "sessions");
  mkdirSync(sessionDir, { recursive: true });

  console.log(`logs:  ${relativeToRepo(sessionDir)}/*.jsonl`);

  const args = [
    "--provider",
    piProvider(),
    "--model",
    piModel(),
    "--thinking",
    piThinking(),
    "--mode",
    "text",
    "--session-dir",
    sessionDir,
    "--no-extensions",
    "--no-skills",
    "--no-prompt-templates",
    "--tools",
    "read,bash,edit,write,grep,find,ls",
    "-p",
    promptText
  ];

  const stdoutChunks: Buffer[] = [];
  const stderrChunks: Buffer[] = [];
  const streamer = startSessionStreamer(sessionDir);
  const timeoutMs = Number(process.env.PI_TIMEOUT_MS || "1800000");

  return await new Promise<RunResult>((resolvePromise, reject) => {
    let timedOut = false;
    const child = spawn("pi", args, {
      cwd: repoRoot,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"]
    });

    const timeout =
      timeoutMs > 0
        ? setTimeout(() => {
            timedOut = true;
            child.kill("SIGTERM");
          }, timeoutMs)
        : undefined;

    child.stdout.on("data", (chunk: Buffer) => {
      stdoutChunks.push(chunk);
      process.stdout.write(chunk);
    });

    child.stderr.on("data", (chunk: Buffer) => {
      stderrChunks.push(chunk);
      process.stderr.write(chunk);
    });

    child.on("error", (error) => {
      if (timeout) clearTimeout(timeout);
      streamer.stop();
      reject(error);
    });

    child.on("close", (status, signal) => {
      if (timeout) clearTimeout(timeout);
      streamer.stop();

      const stdout = Buffer.concat(stdoutChunks).toString("utf8");
      const stderr = Buffer.concat(stderrChunks).toString("utf8");

      if (timedOut) {
        writeFileSync(join(runDir, "pi.stdout.log"), stdout);
        writeFileSync(join(runDir, "pi.stderr.log"), stderr);
        reject(new Error(`pi timed out after ${timeoutMs}ms`));
        return;
      }

      if (status !== 0) {
        writeFileSync(join(runDir, "pi.stdout.log"), stdout);
        writeFileSync(join(runDir, "pi.stderr.log"), stderr);
        reject(new Error(`pi exited with status ${status ?? `signal ${signal}`}`));
        return;
      }

      resolvePromise({ stdout, stderr });
    });
  }).catch((error: Error) => fail(error.message));
}

type SessionStreamState = {
  buffer: string;
  offset: number;
};

function startSessionStreamer(sessionDir: string) {
  const states = new Map<string, SessionStreamState>();
  const pollMs = Number(process.env.PI_LOG_POLL_MS || "1000");
  const timer = setInterval(flush, pollMs);

  function flush() {
    for (const path of sessionFiles(sessionDir)) {
      streamSessionFile(path, states);
    }
  }

  function stop() {
    clearInterval(timer);
    flush();
  }

  flush();

  return { stop };
}

function sessionFiles(sessionDir: string) {
  if (!existsSync(sessionDir)) return [];

  return readdirSync(sessionDir)
    .filter((file) => file.endsWith(".jsonl"))
    .sort()
    .map((file) => join(sessionDir, file));
}

function streamSessionFile(path: string, states: Map<string, SessionStreamState>) {
  const state = states.get(path) || { buffer: "", offset: 0 };
  const size = statSync(path).size;

  if (size <= state.offset) {
    states.set(path, state);
    return;
  }

  const chunk = readFileSync(path).subarray(state.offset, size).toString("utf8");
  state.offset = size;

  const lines = `${state.buffer}${chunk}`.split(/\r?\n/);
  state.buffer = lines.pop() || "";
  states.set(path, state);

  for (const line of lines) {
    if (!line.trim()) continue;
    streamSessionLine(line);
  }
}

function streamSessionLine(line: string) {
  try {
    const event = JSON.parse(line);
    streamSessionEvent(event);
  } catch {
    console.log(`[pi:log] ${line}`);
  }
}

function streamSessionEvent(event: any) {
  if (event?.type !== "message") return;

  const message = event.message;
  const content = Array.isArray(message?.content) ? message.content : [];

  if (message?.role === "assistant") {
    for (const item of content) {
      if (item?.type === "text") {
        streamText("pi", item.text);
      }

      if (item?.type === "toolCall") {
        console.log(`[pi:${item.name}] ${summarizeToolCall(item.name, item.arguments || {})}`);
      }
    }
  }

  if (message?.role === "toolResult") {
    const text = content.map((item: any) => item?.text).filter(Boolean).join("\n");
    if (text && text !== "(no output)") {
      streamText(`pi:${message.toolName || "result"}`, text, toolResultLimit());
    }
  }
}

function summarizeToolCall(name: string, args: Record<string, unknown>) {
  if (name === "bash") return String(args.command || "");
  if (typeof args.path === "string") return args.path;

  return JSON.stringify(args);
}

function streamText(label: string, text: unknown, limit = assistantTextLimit()) {
  if (typeof text !== "string" || text.trim().length === 0) return;

  const trimmed = truncate(text.trim(), limit);
  for (const line of trimmed.split(/\r?\n/)) {
    console.log(`[${label}] ${line}`);
  }
}

function truncate(value: string, limit: number) {
  if (value.length <= limit) return value;
  return `${value.slice(0, limit)}\n... truncated ${value.length - limit} chars`;
}

function assistantTextLimit() {
  return Number(process.env.PI_LOG_ASSISTANT_CHARS || "2000");
}

function toolResultLimit() {
  return Number(process.env.PI_LOG_RESULT_CHARS || "2000");
}

function ensureCleanGit(reason: string) {
  const status = git(["status", "--short"]).stdout.trim();
  if (status) {
    fail(`Git worktree must be clean ${reason}:\n${status}`);
  }
}

function git(args: string[]) {
  return run("git", args, { cwd: repoRoot, capture: true });
}

function run(
  command: string,
  args: string[],
  opts: { cwd?: string; capture?: boolean } = {}
): RunResult {
  const result = spawnSync(command, args, {
    cwd: opts.cwd || repoRoot,
    env: process.env,
    stdio: opts.capture ? "pipe" : "inherit",
    encoding: "utf8",
    maxBuffer: 128 * 1024 * 1024
  });

  if (result.error) fail(result.error.message);
  if (result.status !== 0) fail(`${command} ${args.join(" ")} exited with status ${result.status}`);

  return {
    stdout: result.stdout || "",
    stderr: result.stderr || ""
  };
}

function parseArgs(args: string[]): Args {
  const positional: string[] = [];
  const options: Record<string, string | boolean> = {};

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];

    if (!arg.startsWith("--")) {
      positional.push(arg);
      continue;
    }

    const key = arg.slice(2);
    const next = args[index + 1];

    if (!next || next.startsWith("--")) {
      options[key] = true;
      continue;
    }

    options[key] = next;
    index += 1;
  }

  return { positional, options };
}

function stringOption(value: string | boolean | undefined) {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function ensureRunDir(issue: Issue, command: string) {
  const timestamp = new Date().toISOString().replaceAll(/[:.]/g, "-");
  const dir = join(factoryRoot, "runs", `${timestamp}-${issue.id}-${command}`);
  mkdirSync(dir, { recursive: true });
  return dir;
}

function loadDotEnv(path: string) {
  if (!existsSync(path)) return;

  for (const line of readFileSync(path, "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match) continue;

    const [, key, rawValue] = match;
    if (process.env[key]) continue;

    process.env[key] = rawValue.replace(/^['"]|['"]$/g, "");
  }
}

function commandExists(command: string) {
  return canRun("sh", ["-lc", `command -v ${escapeShell(command)}`]);
}

function canRun(command: string, args: string[]) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    env: process.env,
    stdio: "ignore"
  });

  return result.status === 0;
}

function piProvider() {
  return process.env.PI_PROVIDER || "zai";
}

function piModel() {
  return process.env.PI_MODEL || "glm-5.1";
}

function piThinking() {
  return process.env.PI_THINKING || "medium";
}

function parseJson<T>(value: string) {
  try {
    return JSON.parse(value) as T;
  } catch {
    fail(`Failed to parse JSON:\n${value}`);
  }
}

function renderTemplate(template: string, values: Record<string, string>) {
  return template.replaceAll(/\{\{([a-zA-Z0-9_]+)\}\}/g, (_match, key: string) => {
    return values[key] ?? "";
  });
}

function relativeToRepo(path: string) {
  return path.startsWith(repoRoot) ? path.slice(repoRoot.length + 1) : path;
}

function escapeShell(value: string) {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

function fail(message: string): never {
  console.error(`error: ${message}`);
  process.exit(1);
}

await main();
