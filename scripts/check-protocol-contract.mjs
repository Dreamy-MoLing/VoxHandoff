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
  return [...match[1].matchAll(/^\s*(?:(?:optional|repeated)\s+)?[.A-Za-z0-9_]+\s+([a-z][a-z0-9_]*)\s*=\s*\d+;/gmu)].map(
    (entry) => entry[1],
  );
}

function camelCase(value) {
  return value.replace(/_([a-z])/gu, (_, letter) => letter.toUpperCase());
}

const [model, commonProto, controlProto, eventProto, gatewayProto] = await Promise.all([
  read("packages/core/src/model.ts"),
  read("packages/protocol/proto/agent_talk/v1/common.proto"),
  read("packages/protocol/proto/agent_talk/v1/control.proto"),
  read("packages/protocol/proto/agent_talk/v1/event.proto"),
  read("packages/protocol/proto/agent_talk/v1/gateway.proto"),
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

const resolveApprovalFields = messageFields(controlProto, "ResolveApproval");
assert(
  resolveApprovalFields.includes("device_signature"),
  "approval responses must carry a device signature",
);

for (const [message, fields] of Object.entries({
  BeginPairingRequest: ["device_public_key", "requested_scopes", "expected_gateway_audience"],
  BeginPairingResponse: ["device_proof_payload", "device_fingerprint", "gateway_fingerprint", "gateway_audience"],
  ApprovePairingRequest: ["approved_scopes", "expected_device_fingerprint", "administrator_signature"],
  CompletePairingRequest: ["device_key_proof"],
  CompletePairingResponse: ["credential_id", "confirmation_payload"],
  ConfirmPairingRequest: ["credential_id", "device_signature"],
  ConfirmPairingResponse: ["access_token", "refresh_token", "access_expires_at_unix_ms"],
  RefreshDeviceCredentialRequest: ["refresh_token", "device_signature"],
  RevokeDeviceRequest: ["reason_code", "administrator_signature"],
})) {
  const actual = messageFields(gatewayProto, message);
  for (const field of fields) {
    assert(actual.includes(field), `${message} must carry ${field}`);
  }
}

for (const method of [
  "InspectPairing",
  "ApprovePairing",
  "ConfirmPairing",
  "RefreshDeviceCredential",
  "RevokeDevice",
]) {
  assert(gatewayProto.includes(`rpc ${method}(`), `PairingService must expose ${method}`);
}

process.stdout.write("protocol contract matches core taxonomy and capabilities\n");
