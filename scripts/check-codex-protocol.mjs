import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const requiredClientMethods = [
  "initialize",
  "thread/start",
  "thread/resume",
  "turn/start",
  "turn/interrupt",
];
const requiredServerNotifications = [
  "turn/started",
  "item/agentMessage/delta",
  "item/completed",
  "turn/completed",
];
const requiredServerRequests = [
  "item/commandExecution/requestApproval",
  "item/fileChange/requestApproval",
  "item/tool/requestUserInput",
];

const generatedDirectory = mkdtempSync(join(tmpdir(), "agent-talk-codex-protocol-"));

function runCodex(args, options = {}) {
  const result = spawnSync("codex", args, { encoding: "utf8", ...options });
  // Managed sandboxes may annotate successful child processes with EPERM.
  // Status and generated output remain authoritative in that environment.
  if (result.status !== 0) {
    throw new Error(result.stderr || `codex ${args.join(" ")} failed`);
  }
  return result.stdout ?? "";
}

try {
  const version = runCodex(["--version"]).trim();
  runCodex(["app-server", "generate-ts", "--out", generatedDirectory]);
  const files = {
    client: readFileSync(join(generatedDirectory, "ClientRequest.ts"), "utf8"),
    notifications: readFileSync(join(generatedDirectory, "ServerNotification.ts"), "utf8"),
    requests: readFileSync(join(generatedDirectory, "ServerRequest.ts"), "utf8"),
  };
  const missing = [
    ...requiredClientMethods.filter((method) => !files.client.includes(`"method": "${method}"`)),
    ...requiredServerNotifications.filter(
      (method) => !files.notifications.includes(`"method": "${method}"`),
    ),
    ...requiredServerRequests.filter((method) => !files.requests.includes(`"method": "${method}"`)),
  ];
  if (missing.length) {
    process.stderr.write(`Codex protocol is missing required methods: ${missing.join(", ")}\n`);
    process.exitCode = 1;
  } else {
    process.stdout.write(
      `${JSON.stringify({ version, compatible: true, checkedMethods: 12 })}\n`,
    );
  }
} finally {
  rmSync(generatedDirectory, { recursive: true, force: true });
}
