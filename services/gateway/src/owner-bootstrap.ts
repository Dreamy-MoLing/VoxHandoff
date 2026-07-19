import {
  DeviceSignatureAlgorithm,
  ownerBootstrapPayload,
  ownerRecoveryPayload,
  type DeviceScope,
  type DeviceSignature,
} from "@agent-talk/protocol";
import type { Pool, PoolClient } from "pg";

import {
  canonicalGatewayAudience,
  newOpaqueId,
  newOpaqueSecret,
  normalizeEd25519PublicKey,
  sha256,
  validateNonce,
  verifyEd25519Signature,
} from "./device-crypto.js";

const ownerScopes: readonly DeviceScope[] = Object.freeze([
  "administer",
  "approve",
  "interrupt",
  "observe",
  "send",
]);

export interface OwnerBootstrapFacts {
  deviceId: string;
  credentialId: string;
  displayName: string;
  publicKeySpki: Uint8Array;
  publicKeySha256: string;
  gatewayAudience: string;
  scopes: readonly DeviceScope[];
  proofPayload: Uint8Array;
  accessTokenSha256: string;
  accessExpiresAt: Date;
  refreshTokenSha256: string;
  refreshExpiresAt: Date;
  createdAt: Date;
  auditId: string;
}

export interface OwnerBootstrapStore {
  createInitialOwner(facts: OwnerBootstrapFacts): Promise<boolean>;
}

export interface OwnerRecoveryFacts extends OwnerBootstrapFacts {
  revocationAuditId: string;
}

export interface OwnerRecoveryStore {
  replaceOwner(facts: OwnerRecoveryFacts): Promise<boolean>;
}

export class OwnerBootstrapError extends Error {
  constructor(
    readonly code: "invalid_request" | "proof_invalid" | "owner_exists" | "owner_missing",
    message: string,
  ) {
    super(message);
    this.name = "OwnerBootstrapError";
  }
}

export interface BootstrapOwnerInput {
  deviceDisplayName: string;
  devicePublicKey: Uint8Array;
  expectedGatewayAudience: string;
  deviceSignature: DeviceSignature | undefined;
}

export interface BootstrapOwnerOptions {
  gatewayAudience: string;
  allowInsecureLoopbackForTests?: boolean;
  now?: () => Date;
  newOpaqueId?: (prefix: string) => string;
  newOpaqueSecret?: (bytes?: number) => string;
}

interface PreparedOwner {
  facts: OwnerBootstrapFacts;
  credentials: {
    deviceId: string;
    credentialId: string;
    accessToken: string;
    refreshToken: string;
    scopes: readonly DeviceScope[];
    accessExpiresAt: Date;
    refreshExpiresAt: Date;
    gatewayAudience: string;
  };
}

function prepareOwner(
  input: BootstrapOwnerInput,
  options: BootstrapOwnerOptions,
  purpose: "bootstrap" | "recovery",
): PreparedOwner {
  let audience: string;
  let expectedAudience: string;
  try {
    audience = canonicalGatewayAudience(
      options.gatewayAudience,
      options.allowInsecureLoopbackForTests ?? false,
    );
    expectedAudience = canonicalGatewayAudience(
      input.expectedGatewayAudience,
      audience.startsWith("http://"),
    );
  } catch {
    throw new OwnerBootstrapError("invalid_request", "The Gateway audience is invalid.");
  }
  if (expectedAudience !== audience) {
    throw new OwnerBootstrapError("invalid_request", "The expected Gateway audience does not match.");
  }
  const displayName = input.deviceDisplayName.trim();
  if (
    displayName.length === 0 ||
    new TextEncoder().encode(displayName).byteLength > 128 ||
    /[\u0000-\u001f\u007f]/u.test(displayName)
  ) {
    throw new OwnerBootstrapError("invalid_request", "The owner device display name is invalid.");
  }
  let publicKey: ReturnType<typeof normalizeEd25519PublicKey>;
  try {
    publicKey = normalizeEd25519PublicKey(input.devicePublicKey);
  } catch {
    throw new OwnerBootstrapError("proof_invalid", "The owner device public key is invalid.");
  }
  const signature = input.deviceSignature;
  if (
    signature === undefined ||
    signature.credentialId !== "" ||
    signature.algorithm !== DeviceSignatureAlgorithm.ED25519 ||
    signature.signature.byteLength !== 64
  ) {
    throw new OwnerBootstrapError("proof_invalid", "The owner bootstrap signature is invalid.");
  }
  try {
    validateNonce(signature.nonce);
  } catch {
    throw new OwnerBootstrapError("proof_invalid", "The owner bootstrap nonce is invalid.");
  }
  const payloadInput = {
    gatewayAudience: audience,
    deviceFingerprint: publicKey.fingerprint,
    scopes: ownerScopes,
    nonce: signature.nonce,
  };
  const proofPayload = purpose === "bootstrap"
    ? ownerBootstrapPayload(payloadInput)
    : ownerRecoveryPayload(payloadInput);
  if (!verifyEd25519Signature(publicKey, proofPayload, signature.signature)) {
    throw new OwnerBootstrapError("proof_invalid", "The owner bootstrap proof-of-possession is invalid.");
  }
  const now = (options.now ?? (() => new Date()))();
  const makeId = options.newOpaqueId ?? newOpaqueId;
  const makeSecret = options.newOpaqueSecret ?? newOpaqueSecret;
  const deviceId = makeId("device");
  const credentialId = makeId("credential");
  const accessToken = makeSecret(32);
  const refreshToken = makeSecret(48);
  const accessExpiresAt = new Date(now.getTime() + 15 * 60_000);
  const refreshExpiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60_000);
  return {
    facts: {
      deviceId,
      credentialId,
      displayName,
      publicKeySpki: publicKey.spkiDer,
      publicKeySha256: publicKey.sha256,
      gatewayAudience: audience,
      scopes: ownerScopes,
      proofPayload,
      accessTokenSha256: sha256(accessToken),
      accessExpiresAt,
      refreshTokenSha256: sha256(refreshToken),
      refreshExpiresAt,
      createdAt: now,
      auditId: makeId("audit"),
    },
    credentials: {
      deviceId,
      credentialId,
      accessToken,
      refreshToken,
      scopes: ownerScopes,
      accessExpiresAt,
      refreshExpiresAt,
      gatewayAudience: audience,
    },
  };
}

export async function bootstrapInitialOwner(
  store: OwnerBootstrapStore,
  input: BootstrapOwnerInput,
  options: BootstrapOwnerOptions,
): Promise<{
  deviceId: string;
  credentialId: string;
  accessToken: string;
  refreshToken: string;
  scopes: readonly DeviceScope[];
  accessExpiresAt: Date;
  refreshExpiresAt: Date;
  gatewayAudience: string;
}> {
  const prepared = prepareOwner(input, options, "bootstrap");
  const created = await store.createInitialOwner(prepared.facts);
  if (!created) throw new OwnerBootstrapError("owner_exists", "An active owner already exists.");
  return prepared.credentials;
}

export async function recoverOwner(
  store: OwnerRecoveryStore,
  input: BootstrapOwnerInput,
  options: BootstrapOwnerOptions,
): Promise<PreparedOwner["credentials"]> {
  const prepared = prepareOwner(input, options, "recovery");
  const makeId = options.newOpaqueId ?? newOpaqueId;
  const replaced = await store.replaceOwner({
    ...prepared.facts,
    revocationAuditId: makeId("audit"),
  });
  if (!replaced) throw new OwnerBootstrapError("owner_missing", "No active owner exists to recover.");
  return prepared.credentials;
}

async function insertOwner(client: PoolClient, facts: OwnerBootstrapFacts): Promise<void> {
  await client.query(
    `INSERT INTO agent_talk.devices (
       device_id, display_name, public_key_sha256, status, scopes, token_generation, paired_at
     ) VALUES ($1, $2, $3, 'active', $4, 1, $5)`,
    [facts.deviceId, facts.displayName, facts.publicKeySha256, [...facts.scopes], facts.createdAt],
  );
  await client.query(
    `INSERT INTO agent_talk.device_credentials (
       credential_id, pairing_id, origin, device_id, state, public_key_spki, public_key_sha256,
       gateway_audience, scopes, generation, access_token_sha256, access_expires_at,
       refresh_token_sha256, refresh_expires_at, family_expires_at, confirmation_payload,
       confirmation_expires_at, created_at, activated_at
     ) VALUES ($1, NULL, 'owner_bootstrap', $2, 'active', $3, $4, $5, $6, 1,
               $7, $8, $9, $10, $10, $11, $12, $12, $12)`,
    [
      facts.credentialId, facts.deviceId, Buffer.from(facts.publicKeySpki), facts.publicKeySha256,
      facts.gatewayAudience, [...facts.scopes], facts.accessTokenSha256, facts.accessExpiresAt,
      facts.refreshTokenSha256, facts.refreshExpiresAt, Buffer.from(facts.proofPayload), facts.createdAt,
    ],
  );
}

export class PostgresOwnerBootstrapStore implements OwnerBootstrapStore, OwnerRecoveryStore {
  constructor(private readonly pool: Pool) {}

  async createInitialOwner(facts: OwnerBootstrapFacts): Promise<boolean> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", ["agent-talk:owner-bootstrap"]);
      const existing = await client.query(
        `SELECT 1 FROM agent_talk.device_credentials c
         JOIN agent_talk.devices d ON d.device_id = c.device_id
         WHERE c.state = 'active' AND d.status = 'active' AND c.scopes @> ARRAY['administer']::text[]
         LIMIT 1`,
      );
      if (existing.rowCount !== 0) {
        await client.query("COMMIT");
        return false;
      }
      await insertOwner(client, facts);
      await client.query(
        `INSERT INTO agent_talk.security_audit_events (
           audit_id, device_id, action, outcome, target_type, target_id_sha256, safe_code, occurred_at
         ) VALUES ($1, $2, 'owner.bootstrap', 'allowed', 'device', $3, 'initial_owner_created', $4)`,
        [facts.auditId, facts.deviceId, sha256(facts.deviceId), facts.createdAt],
      );
      await client.query("COMMIT");
      return true;
    } catch (error) {
      try { await client.query("ROLLBACK"); } catch { /* preserve original failure */ }
      throw error;
    } finally {
      client.release();
    }
  }

  async replaceOwner(facts: OwnerRecoveryFacts): Promise<boolean> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", ["agent-talk:owner-bootstrap"]);
      const existing = await client.query<{ device_id: string }>(
        `SELECT d.device_id
         FROM agent_talk.device_credentials c
         JOIN agent_talk.devices d ON d.device_id = c.device_id
         WHERE c.origin = 'owner_bootstrap' AND c.state = 'active'
           AND d.status = 'active' AND c.scopes @> ARRAY['administer']::text[]
         ORDER BY c.created_at DESC
         LIMIT 2
         FOR UPDATE OF c, d`,
      );
      if (existing.rowCount === 0) {
        await client.query("COMMIT");
        return false;
      }
      if (existing.rowCount !== 1) {
        throw new Error("multiple active owner credentials violate the single-owner invariant");
      }
      const previousDeviceId = existing.rows[0]?.device_id;
      if (previousDeviceId === undefined) throw new Error("active owner row is invalid");
      const revokedDevice = await client.query(
        `UPDATE agent_talk.devices
         SET status = 'revoked', token_generation = token_generation + 1, revoked_at = $2
         WHERE device_id = $1 AND status = 'active'`,
        [previousDeviceId, facts.createdAt],
      );
      if (revokedDevice.rowCount !== 1) throw new Error("active owner changed during recovery");
      await client.query(
        `UPDATE agent_talk.device_credentials
         SET state = 'revoked', access_token_sha256 = NULL, access_expires_at = NULL,
             refresh_token_sha256 = NULL, revoked_at = $2
         WHERE device_id = $1 AND state <> 'revoked'`,
        [previousDeviceId, facts.createdAt],
      );
      await client.query(
        `INSERT INTO agent_talk.security_audit_events (
           audit_id, device_id, action, outcome, target_type, target_id_sha256, safe_code, occurred_at
         ) VALUES ($1, $2, 'owner.recover', 'revoked', 'device', $3, 'prior_owner_revoked', $4)`,
        [facts.revocationAuditId, previousDeviceId, sha256(previousDeviceId), facts.createdAt],
      );
      await insertOwner(client, facts);
      await client.query(
        `INSERT INTO agent_talk.security_audit_events (
           audit_id, device_id, action, outcome, target_type, target_id_sha256, safe_code, occurred_at
         ) VALUES ($1, $2, 'owner.recover', 'allowed', 'device', $3, 'replacement_owner_created', $4)`,
        [facts.auditId, facts.deviceId, sha256(previousDeviceId), facts.createdAt],
      );
      await client.query("COMMIT");
      return true;
    } catch (error) {
      try { await client.query("ROLLBACK"); } catch { /* preserve original failure */ }
      throw error;
    } finally {
      client.release();
    }
  }
}
