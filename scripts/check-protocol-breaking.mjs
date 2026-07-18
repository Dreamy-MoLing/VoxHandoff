import { execFile } from "node:child_process";
import { promisify } from "node:util";
import path from "node:path";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const explicitArguments = process.argv.slice(2);

if (explicitArguments.length > 0) {
  await execFileAsync(process.execPath, ["scripts/run-buf.mjs", "breaking", ...explicitArguments], {
    cwd: root,
    stdio: "inherit",
  });
  process.exit(0);
}

try {
  await execFileAsync("git", ["cat-file", "-e", "HEAD:packages/protocol/proto"], { cwd: root });
} catch {
  process.stdout.write("protocol breaking check skipped: HEAD has no protocol baseline yet\n");
  process.exit(0);
}

await execFileAsync(
  process.execPath,
  [
    "scripts/run-buf.mjs",
    "breaking",
    "packages/protocol/proto",
    "--against",
    ".git#subdir=packages/protocol/proto",
  ],
  { cwd: root, stdio: "inherit" },
);
