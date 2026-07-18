import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const target = process.argv[2] ?? "typescript";
const targetConfiguration =
  target === "dart"
    ? {
        generatedRoot: "packages/protocol/dart/lib/src/gen",
        template: "buf.gen.dart.yaml",
        label: "Dart",
      }
    : target === "typescript"
      ? {
          generatedRoot: "packages/protocol/src/gen",
          template: "buf.gen.yaml",
          label: "TypeScript",
        }
      : undefined;
assert(targetConfiguration, `unknown generated protocol target: ${target}`);
const generatedRoot = path.join(root, targetConfiguration.generatedRoot);

async function snapshot(directory, prefix = "") {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = new Map();
  for (const entry of entries) {
    const relativePath = path.posix.join(prefix, entry.name);
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      for (const [name, content] of await snapshot(absolutePath, relativePath)) {
        files.set(name, content);
      }
    } else if (entry.isFile()) {
      files.set(relativePath, await readFile(absolutePath, "utf8"));
    }
  }
  return files;
}

const before = await snapshot(generatedRoot);
assert(before.size > 0, `protocol ${targetConfiguration.label} bindings have not been generated`);

await execFileAsync(
  process.execPath,
  ["scripts/run-buf.mjs", "generate", "--template", targetConfiguration.template],
  { cwd: root },
);

const after = await snapshot(generatedRoot);
assert.deepEqual(
  after,
  before,
  `generated ${targetConfiguration.label} bindings were stale; commit the regenerated files`,
);
process.stdout.write(`generated ${targetConfiguration.label} protocol bindings are current\n`);
