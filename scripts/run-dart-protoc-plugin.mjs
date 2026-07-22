import { spawn } from "node:child_process";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const flutterRoot = process.env.AGENT_TALK_FLUTTER_ROOT;
const dart = flutterRoot === undefined
  ? "dart"
  : path.join(flutterRoot, "bin", process.platform === "win32" ? "dart.bat" : "dart");
const protocolPackage = path.join(root, "packages/protocol/dart");

const child = spawn(
  dart,
  ["run", "protoc_plugin:protoc_plugin"],
  { cwd: protocolPackage, env: process.env, stdio: "inherit" },
);

child.once("error", (error) => {
  process.stderr.write(`Dart protoc plugin could not start: ${error.message}\n`);
  process.exitCode = 1;
});
child.once("exit", (code, signal) => {
  if (signal !== null) {
    process.stderr.write(`Dart protoc plugin terminated by ${signal}.\n`);
    process.exitCode = 1;
    return;
  }
  process.exitCode = code ?? 1;
});
