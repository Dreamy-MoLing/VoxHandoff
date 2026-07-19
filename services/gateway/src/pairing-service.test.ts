import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

import { Code, ConnectError, createClient, createRouterTransport, type ServiceImpl } from "@connectrpc/connect";
import { createGrpcTransport } from "@connectrpc/connect-node";
import { GatewayControlService, PairingService } from "@agent-talk/protocol";

import type { AuthenticatedDevicePrincipal } from "./device-identity.js";
import { PairingError } from "./pairing.js";
import {
  createPairingService,
  type PairingDeviceIdentityVerifier,
  type PairingRpcServiceOptions,
} from "./pairing-service.js";
import { startGatewayServer } from "./server.js";

const execFileAsync = promisify(execFile);

class FakePairingIdentityVerifier implements PairingDeviceIdentityVerifier {
  authenticateCount = 0;

  async authenticateDevice(headers: Headers): Promise<AuthenticatedDevicePrincipal> {
    this.authenticateCount += 1;
    if (headers.get("authorization") !== "Bearer administrator-token") {
      throw new ConnectError("Authentication required.", Code.Unauthenticated);
    }
    return {
      deviceId: "administrator-device",
      credentialId: "administrator-credential",
      generation: 1n,
      scopes: ["administer"],
    };
  }

  async revalidateDevice(): Promise<void> {}
}

function setup() {
  const verifier = new FakePairingIdentityVerifier();
  const calls = { rateLimitKey: "", administratorDeviceId: "", revokedDeviceId: "" };
  const coordinator: PairingRpcServiceOptions["coordinator"] = {
    async begin(input) {
      calls.rateLimitKey = input.rateLimitKey;
      return {
        pairingId: "pairing-1",
        userCode: "ABCD-EFGH",
        verificationUri: "https://gateway.example/pair",
        expiresInSeconds: 600,
        deviceProofPayload: new Uint8Array([1, 2, 3]),
        deviceFingerprint: `sha256:${"a".repeat(64)}`,
        gatewayFingerprint: `sha256:${"b".repeat(64)}`,
        gatewayAudience: "https://gateway.example",
      };
    },
    async inspect(_userCode, administratorDeviceId) {
      calls.administratorDeviceId = administratorDeviceId;
      return {
        pairingId: "pairing-1",
        deviceDisplayName: "test device",
        deviceFingerprint: `sha256:${"a".repeat(64)}`,
        gatewayFingerprint: `sha256:${"b".repeat(64)}`,
        gatewayAudience: "https://gateway.example",
        requestedScopes: ["observe"],
        expiresInSeconds: 500,
      };
    },
    async approve(input) {
      calls.administratorDeviceId = input.administratorDeviceId;
      return { approved: true, expiresInSeconds: 400 };
    },
    async complete() {
      return {
        deviceId: "device-1",
        credentialId: "credential-1",
        scopes: ["observe"],
        confirmationPayload: new Uint8Array([4, 5, 6]),
        gatewayAudience: "https://gateway.example",
        confirmationExpiresInSeconds: 120,
      };
    },
    async confirm() {
      return {
        deviceId: "device-1",
        credentialId: "credential-1",
        accessToken: "a".repeat(43),
        refreshToken: "b".repeat(64),
        scopes: ["observe"],
        accessExpiresAt: new Date("2030-01-01T00:15:00.000Z"),
        refreshExpiresAt: new Date("2030-01-31T00:00:00.000Z"),
        gatewayAudience: "https://gateway.example",
      };
    },
    async refresh() {
      return {
        deviceId: "device-1",
        credentialId: "credential-1",
        accessToken: "c".repeat(43),
        refreshToken: "d".repeat(64),
        scopes: ["observe"],
        accessExpiresAt: new Date("2030-01-01T00:20:00.000Z"),
        refreshExpiresAt: new Date("2030-01-31T00:00:00.000Z"),
        gatewayAudience: "https://gateway.example",
      };
    },
    async revokeDevice(input) {
      calls.administratorDeviceId = input.administratorDeviceId;
      calls.revokedDeviceId = input.targetDeviceId;
      return true;
    },
  };
  const service = createPairingService({
    coordinator,
    identityVerifier: verifier,
    rateLimitKey: () => "trusted-peer-hash-input",
  });
  const transport = createRouterTransport((router) => router.service(PairingService, service));
  return { verifier, calls, coordinator, client: createClient(PairingService, transport) };
}

test("exposes the staged pairing lifecycle and never returns draft Complete tokens", async () => {
  const { client, calls } = setup();
  const begun = await client.beginPairing({
    deviceDisplayName: "test device",
    devicePublicKey: new Uint8Array([1]),
    requestedScopes: ["observe"],
    expectedGatewayAudience: "https://gateway.example",
  });
  assert.equal(begun.pairingId, "pairing-1");
  assert.equal(calls.rateLimitKey, "trusted-peer-hash-input");

  const completed = await client.completePairing({ pairingId: "pairing-1" });
  assert.equal(completed.accessToken, "");
  assert.equal(completed.refreshToken, "");
  assert.equal(completed.credentialId, "credential-1");

  const confirmed = await client.confirmPairing({ pairingId: "pairing-1", credentialId: "credential-1" });
  assert.equal(confirmed.paired, true);
  assert.equal(confirmed.accessExpiresAtUnixMs, 1_893_456_900_000n);
});

test("requires an authenticated administer device for inspect, approve, and revoke", async () => {
  const { client, calls, verifier } = setup();
  await assert.rejects(
    client.inspectPairing({ userCode: "ABCD-EFGH" }),
    (error: unknown) => error instanceof ConnectError && error.code === Code.Unauthenticated,
  );
  const headers = new Headers({ authorization: "Bearer administrator-token" });
  const inspected = await client.inspectPairing({ userCode: "ABCD-EFGH" }, { headers });
  assert.equal(inspected.pairingId, "pairing-1");
  await client.approvePairing({ pairingId: "pairing-1", userCode: "ABCD-EFGH" }, { headers });
  assert.equal(await client.revokeDevice({ deviceId: "device-1", reasonCode: "owner_revoked" }, { headers }).then(
    (response) => response.revoked,
  ), true);
  assert.equal(calls.administratorDeviceId, "administrator-device");
  assert.equal(calls.revokedDeviceId, "device-1");
  assert.equal(verifier.authenticateCount, 4);
});

test("maps stable pairing failures to safe Connect status codes", async () => {
  const { client, coordinator } = setup();
  coordinator.begin = async () => {
    throw new PairingError("rate_limited", "Too many pairing attempts. Try again later.", true);
  };
  await assert.rejects(
    client.beginPairing({}),
    (error: unknown) =>
      error instanceof ConnectError &&
      error.code === Code.ResourceExhausted &&
      error.metadata.get("agent-talk-error-code") === "rate_limited" &&
      error.message.includes("Too many pairing attempts"),
  );
});

test("serves real loopback HTTP/2 gRPC HTTPS pairing only to a client that trusts the certificate", {
  skip:
    process.env.AGENT_TALK_LOOPBACK_INTEGRATION === "1"
      ? false
      : "set AGENT_TALK_LOOPBACK_INTEGRATION=1 for explicit socket integration",
}, async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "agent-talk-pairing-tls-"));
  const keyPath = path.join(directory, "key.pem");
  const certificatePath = path.join(directory, "certificate.pem");
  let running: Awaited<ReturnType<typeof startGatewayServer>> | undefined;
  try {
    await execFileAsync("openssl", [
      "req",
      "-x509",
      "-newkey",
      "rsa:2048",
      "-nodes",
      "-keyout",
      keyPath,
      "-out",
      certificatePath,
      "-days",
      "1",
      "-subj",
      "/CN=127.0.0.1",
      "-addext",
      "subjectAltName=IP:127.0.0.1",
    ]);
    const [key, cert] = await Promise.all([readFile(keyPath), readFile(certificatePath)]);
    const { coordinator } = setup();
    const pairingService = createPairingService({
      coordinator,
      identityVerifier: new FakePairingIdentityVerifier(),
      rateLimitKey: () => "loopback-test-peer",
    });
    const controlService: ServiceImpl<typeof GatewayControlService> = {
      async *connectClient() {},
      async *connectNode() {},
    };
    running = await startGatewayServer({
      controlService,
      pairingService,
      host: "127.0.0.1",
      port: 0,
      tls: { key, cert },
    });
    const baseUrl = `https://127.0.0.1:${running.address.port}`;
    const untrustedClient = createClient(PairingService, createGrpcTransport({
      baseUrl,
      defaultTimeoutMs: 5_000,
      idleConnectionTimeoutMs: 10,
    }));
    await assert.rejects(untrustedClient.beginPairing({ expectedGatewayAudience: baseUrl }));

    const trustedClient = createClient(PairingService, createGrpcTransport({
      baseUrl,
      defaultTimeoutMs: 5_000,
      idleConnectionTimeoutMs: 10,
      nodeOptions: { ca: cert },
    }));
    const response = await trustedClient.beginPairing({
      deviceDisplayName: "TLS test device",
      devicePublicKey: new Uint8Array([1]),
      requestedScopes: ["observe"],
      expectedGatewayAudience: baseUrl,
    });
    assert.equal(response.pairingId, "pairing-1");
    assert.equal(Object.hasOwn(response, "accessToken"), false);
  } finally {
    await running?.close();
    await rm(directory, { recursive: true, force: true });
  }
});
