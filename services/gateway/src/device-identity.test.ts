import assert from "node:assert/strict";
import test from "node:test";

import { Code, ConnectError } from "@connectrpc/connect";

import { sha256 } from "./device-crypto.js";
import {
  DeviceStreamIdentityVerifier,
  type AccessCredentialIdentity,
  type DeviceCredentialAuthority,
} from "./device-identity.js";

class FakeAuthority implements DeviceCredentialAuthority {
  identity: AccessCredentialIdentity | undefined;

  async findByAccessTokenSha256(accessTokenSha256: string): Promise<AccessCredentialIdentity | undefined> {
    return this.identity?.accessTokenSha256 === accessTokenSha256 ? structuredClone(this.identity) : undefined;
  }

  async findByCredentialId(credentialId: string): Promise<AccessCredentialIdentity | undefined> {
    return this.identity?.credentialId === credentialId ? structuredClone(this.identity) : undefined;
  }
}

const token = "a".repeat(43);

function activeIdentity(): AccessCredentialIdentity {
  return {
    credentialId: "credential-1",
    deviceId: "device-1",
    credentialState: "active",
    deviceActive: true,
    generation: 1n,
    gatewayAudience: "https://gateway.example",
    credentialScopes: ["observe", "send"],
    deviceScopes: ["observe", "send"],
    accessTokenSha256: sha256(token),
    accessExpiresAt: new Date("2030-01-01T00:15:00.000Z"),
  };
}

function verifier(authority: FakeAuthority): DeviceStreamIdentityVerifier {
  return new DeviceStreamIdentityVerifier(authority, {
    gatewayAudience: "https://gateway.example",
    now: () => new Date("2030-01-01T00:00:00.000Z"),
  });
}

test("authenticates only the current active bearer and returns its credential binding", async () => {
  const authority = new FakeAuthority();
  authority.identity = activeIdentity();
  const identityVerifier = verifier(authority);
  const principal = await identityVerifier.authenticate(
    new Headers({ authorization: `Bearer ${token}` }),
    "client",
  );
  assert.deepEqual(principal, {
    principalId: "device-1",
    role: "client",
    scopes: ["observe", "send"],
    credentialId: "credential-1",
    credentialGeneration: 1n,
  });
  await identityVerifier.revalidate(principal);
  await assert.rejects(
    identityVerifier.authenticate(new Headers({ authorization: `Bearer ${token}` }), "node"),
    (error: unknown) => error instanceof ConnectError && error.code === Code.PermissionDenied,
  );
});

test("rejects missing, malformed, expired, revoked, and audience-mismatched credentials", async () => {
  const authority = new FakeAuthority();
  authority.identity = activeIdentity();
  const identityVerifier = verifier(authority);
  for (const headers of [new Headers(), new Headers({ authorization: "Basic nope" })]) {
    await assert.rejects(
      identityVerifier.authenticate(headers, "client"),
      (error: unknown) => error instanceof ConnectError && error.code === Code.Unauthenticated,
    );
  }
  for (const change of [
    { accessExpiresAt: new Date("2029-12-31T23:59:59.000Z") },
    { credentialState: "revoked" as const },
    { deviceActive: false },
    { gatewayAudience: "https://other.example" },
    { credentialScopes: ["send"] as const, deviceScopes: ["observe"] as const },
  ]) {
    authority.identity = { ...activeIdentity(), ...change };
    await assert.rejects(
      identityVerifier.authenticate(new Headers({ authorization: `Bearer ${token}` }), "client"),
      (error: unknown) => error instanceof ConnectError && error.code === Code.Unauthenticated,
    );
  }
});

test("closes an established principal when refresh changes generation or scope", async () => {
  const authority = new FakeAuthority();
  authority.identity = activeIdentity();
  const identityVerifier = verifier(authority);
  const principal = await identityVerifier.authenticate(
    new Headers({ authorization: `Bearer ${token}` }),
    "client",
  );
  authority.identity = {
    ...activeIdentity(),
    generation: 2n,
    accessTokenSha256: sha256("b".repeat(43)),
  };
  await assert.rejects(
    identityVerifier.revalidate(principal),
    (error: unknown) => error instanceof ConnectError && error.code === Code.Unauthenticated,
  );
});

test("enforces administer scope for pairing management", async () => {
  const authority = new FakeAuthority();
  authority.identity = activeIdentity();
  const identityVerifier = verifier(authority);
  await assert.rejects(
    identityVerifier.authenticateDevice(new Headers({ authorization: `Bearer ${token}` }), "administer"),
    (error: unknown) => error instanceof ConnectError && error.code === Code.PermissionDenied,
  );
  authority.identity = {
    ...activeIdentity(),
    credentialScopes: ["administer"],
    deviceScopes: ["administer"],
  };
  assert.equal(
    (await identityVerifier.authenticateDevice(
      new Headers({ authorization: `Bearer ${token}` }),
      "administer",
    )).credentialId,
    "credential-1",
  );
});
