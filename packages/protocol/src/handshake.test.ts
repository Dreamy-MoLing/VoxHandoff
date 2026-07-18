import assert from "node:assert/strict";
import test from "node:test";

import { create } from "@bufbuild/protobuf";

import { AgentCapabilitiesSchema, ComponentRole } from "./gen/agent_talk/v1/common_pb.js";
import { HandshakeOfferSchema } from "./gen/agent_talk/v1/control_pb.js";
import { negotiateHandshake, type HandshakePolicy } from "./handshake.js";

function offer(overrides: { major?: number; minimumMinor?: number; maximumMinor?: number; attachments?: boolean } = {}) {
  return create(HandshakeOfferSchema, {
    currentProtocol: { major: overrides.major ?? 1, minor: overrides.maximumMinor ?? 0 },
    acceptedProtocols: {
      major: overrides.major ?? 1,
      minimumMinor: overrides.minimumMinor ?? 0,
      maximumMinor: overrides.maximumMinor ?? 0,
    },
    schemaBuild: "test-build",
    schemaSha256: "a".repeat(64),
    componentVersion: "0.1.0-test",
    componentRole: ComponentRole.CLIENT,
    capabilityRevision: "cap-test",
    capabilities: create(AgentCapabilitiesSchema, { attachments: overrides.attachments ?? false }),
  });
}

test("selects the highest mutually supported protocol minor", () => {
  const local: HandshakePolicy = {
    current: { major: 1, minor: 2 },
    minimumMinor: 1,
    maximumMinor: 2,
    attachmentsEnabled: false,
  };

  assert.deepEqual(negotiateHandshake(offer({ minimumMinor: 0, maximumMinor: 1 }), local), {
    ok: true,
    selected: { major: 1, minor: 1 },
  });
});

test("rejects incompatible major and minor ranges with stable codes", () => {
  assert.equal(negotiateHandshake(offer({ major: 2 })).ok, false);

  const local: HandshakePolicy = {
    current: { major: 1, minor: 2 },
    minimumMinor: 2,
    maximumMinor: 2,
    attachmentsEnabled: false,
  };
  const result = negotiateHandshake(offer({ minimumMinor: 0, maximumMinor: 1 }), local);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "protocol_minor_mismatch");
  }
});

test("rejects invalid ranges before negotiation", () => {
  const result = negotiateHandshake(offer({ minimumMinor: 2, maximumMinor: 1 }));
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "protocol_range_invalid");
  }
});

test("keeps attachments disabled through M5", () => {
  const result = negotiateHandshake(offer({ attachments: true }));
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "attachments_not_supported");
  }
});
