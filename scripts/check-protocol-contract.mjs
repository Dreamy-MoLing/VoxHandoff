import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

async function read(relativePath) {
  return readFile(path.join(root, relativePath), "utf8");
}

function arrayValues(source, name) {
  const match = source.match(new RegExp(`export const ${name} = \\[([\\s\\S]*?)\\] as const`, "u"));
  assert(match, `could not find ${name}`);
  return [...match[1].matchAll(/"([^"]+)"/gu)].map((entry) => entry[1]);
}

function enumValues(source, name, prefix) {
  const match = source.match(new RegExp(`enum ${name} \\{([\\s\\S]*?)\\n\\}`, "u"));
  assert(match, `could not find enum ${name}`);
  return [...match[1].matchAll(/^\s*([A-Z][A-Z0-9_]*)\s*=\s*\d+;/gmu)]
    .map((entry) => entry[1])
    .filter((value) => value !== `${prefix}UNSPECIFIED`)
    .map((value) => value.slice(prefix.length).toLowerCase());
}

function messageFields(source, name) {
  const match = source.match(new RegExp(`message ${name} \\{([\\s\\S]*?)\\n\\}`, "u"));
  assert(match, `could not find message ${name}`);
  return [...match[1].matchAll(/^\s*(?:optional\s+)?[.A-Za-z0-9_]+\s+([a-z][a-z0-9_]*)\s*=\s*\d+;/gmu)].map(
    (entry) => entry[1],
  );
}

function camelCase(value) {
  return value.replace(/_([a-z])/gu, (_, letter) => letter.toUpperCase());
}

const [model, commonProto, controlProto, eventProto] = await Promise.all([
  read("packages/core/src/model.ts"),
  read("packages/protocol/proto/agent_talk/v1/common.proto"),
  read("packages/protocol/proto/agent_talk/v1/control.proto"),
  read("packages/protocol/proto/agent_talk/v1/event.proto"),
]);

const coreEvents = arrayValues(model, "agentEventTypes");
const protocolEvents = enumValues(eventProto, "AgentEventType", "AGENT_EVENT_TYPE_").map((value) =>
  value.replace("_", "."),
);
assert.deepEqual(protocolEvents, coreEvents, "protocol event taxonomy must exactly match core");

assert.deepEqual(
  enumValues(commonProto, "FailureStage", "FAILURE_STAGE_"),
  arrayValues(model, "failureStages"),
  "protocol failure stages must exactly match core",
);
assert.deepEqual(
  enumValues(commonProto, "FailureCategory", "FAILURE_CATEGORY_"),
  arrayValues(model, "failureCategories"),
  "protocol failure categories must exactly match core",
);

const protocolCapabilities = messageFields(commonProto, "AgentCapabilities").map(camelCase);
const expectedCapabilities = [
  "deltaMode",
  "eventStream",
  "sessionHistory",
  "createSession",
  "resumeSession",
  "interrupt",
  "steer",
  "clarification",
  "approval",
  "toolEvents",
  "attachments",
  "idempotency",
  "replay",
  "sequenceRecovery",
  "maxRequestBytes",
  "requestTimeoutMs",
];
assert.deepEqual(protocolCapabilities, expectedCapabilities, "protocol capability fields must match the fixed contract");

const clientCommandFields = messageFields(controlProto, "ClientCommand");
for (const identityField of ["command_id", "idempotency_key", "conversation_id", "request_id"]) {
  assert(clientCommandFields.includes(identityField), `ClientCommand must carry ${identityField}`);
}

process.stdout.write("protocol contract matches core taxonomy and capabilities\n");
