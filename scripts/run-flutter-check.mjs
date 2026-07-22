import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const flutterRoot = process.env.AGENT_TALK_FLUTTER_ROOT;
const executable = (name) => flutterRoot === undefined
  ? name
  : path.join(flutterRoot, "bin", process.platform === "win32" ? `${name}.bat` : name);

async function capture(command, args, cwd) {
  return await new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, env: process.env });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.once("error", reject);
    child.once("exit", (code, signal) => {
      if (code === 0) {
        resolve(stdout);
        return;
      }
      reject(new Error(
        signal === null
          ? `${path.basename(command)} ${args.join(" ")} exited with code ${code}: ${stderr.trim()}`
          : `${path.basename(command)} ${args.join(" ")} terminated by ${signal}`,
      ));
    });
  });
}

async function run(command, args, cwd) {
  await new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, stdio: "inherit", env: process.env });
    child.once("error", reject);
    child.once("exit", (code, signal) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(
        signal === null
          ? `${path.basename(command)} ${args.join(" ")} exited with code ${code}`
          : `${path.basename(command)} ${args.join(" ")} terminated by ${signal}`,
      ));
    });
  });
}

const pinned = JSON.parse(
  await readFile(path.join(root, "toolchains/flutter.json"), "utf8"),
);
const installed = JSON.parse(
  await capture(executable("flutter"), ["--version", "--machine"], root),
);
const mismatches = [
  ["channel", installed.channel, pinned.channel],
  ["Flutter", installed.frameworkVersion, pinned.flutterVersion],
  ["Dart", installed.dartSdkVersion, pinned.dartVersion],
].filter(([, actual, expected]) => actual !== expected);
if (mismatches.length > 0) {
  throw new Error(
    `Flutter toolchain mismatch: ${mismatches
      .map(([name, actual, expected]) => `${name} expected ${expected}, got ${actual}`)
      .join("; ")}`,
  );
}

const clientRoot = path.join(root, "apps/client");
const generatedFiles = [
  path.join(clientRoot, "lib/infrastructure/storage/drift_client_event_ledger.g.dart"),
];
const generatedBefore = await Promise.all(
  generatedFiles.map((file) => readFile(file)),
);

await run(executable("dart"), ["analyze"], path.join(root, "packages/protocol/dart"));
await run(
  executable("dart"),
  ["run", "build_runner", "build"],
  clientRoot,
);
const generatedAfter = await Promise.all(
  generatedFiles.map((file) => readFile(file)),
);
const staleGenerated = generatedFiles.filter(
  (_, index) => !generatedBefore[index].equals(generatedAfter[index]),
);
if (staleGenerated.length > 0) {
  throw new Error(
    `Flutter generated files were stale and have been refreshed: ${staleGenerated
      .map((file) => path.relative(root, file))
      .join(", ")}`,
  );
}
await run(
  executable("dart"),
  ["format", "--output=none", "--set-exit-if-changed", "lib", "test"],
  clientRoot,
);
await run(executable("flutter"), ["analyze"], clientRoot);
await run(executable("flutter"), ["test"], clientRoot);
