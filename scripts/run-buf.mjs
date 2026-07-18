import { mkdir } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const cacheRoot = process.env.AGENT_TALK_BUF_CACHE ?? path.join(os.tmpdir(), "agent-talk-buf-cache");
await mkdir(cacheRoot, { recursive: true });

const executable = path.join(root, "node_modules", ".bin", process.platform === "win32" ? "buf.cmd" : "buf");
const child = spawn(executable, process.argv.slice(2), {
  cwd: root,
  env: { ...process.env, XDG_CACHE_HOME: cacheRoot },
  stdio: "inherit",
});

child.on("error", (error) => {
  process.stderr.write(`failed to start Buf: ${error.message}\n`);
  process.exitCode = 1;
});

child.on("exit", (code, signal) => {
  if (signal !== null) {
    process.stderr.write(`Buf terminated by ${signal}\n`);
    process.exitCode = 1;
  } else {
    process.exitCode = code ?? 1;
  }
});
