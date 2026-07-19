import type { Pool, PoolClient } from "pg";

import { normalizeDeviceScopes, type DeviceScope } from "@agent-talk/protocol";

import type {
  DeviceAuthorizationRecord,
  DeviceCredentialRecord,
  CredentialRotationFacts,
  DeviceRevocationFacts,
  PairingActivationFacts,
  PairingApprovalFacts,
  PairingAuditFact,
  PairingLedger,
  PairingLedgerTransaction,
  PairingProofFacts,
  PairingRecord,
  UsedRefreshRecord,
} from "./pairing-ledger.js";

type UnknownRow = Record<string, unknown>;

function row(value: unknown): UnknownRow {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("invalid PostgreSQL pairing row");
  }
  return value as UnknownRow;
}

function stringAt(value: UnknownRow, key: string): string {
  const field = value[key];
  if (typeof field !== "string") throw new Error(`invalid PostgreSQL ${key}`);
  return field;
}

function nullableStringAt(value: UnknownRow, key: string): string | null {
  return value[key] === null ? null : stringAt(value, key);
}

function dateAt(value: UnknownRow, key: string): Date {
  const field = value[key];
  if (!(field instanceof Date) || Number.isNaN(field.getTime())) throw new Error(`invalid PostgreSQL ${key}`);
  return field;
}

function nullableDateAt(value: UnknownRow, key: string): Date | null {
  return value[key] === null ? null : dateAt(value, key);
}

function bytesAt(value: UnknownRow, key: string): Uint8Array {
  const field = value[key];
  if (!(field instanceof Uint8Array)) throw new Error(`invalid PostgreSQL ${key}`);
  return new Uint8Array(field);
}

function nullableBytesAt(value: UnknownRow, key: string): Uint8Array | null {
  return value[key] === null ? null : bytesAt(value, key);
}

function booleanAt(value: UnknownRow, key: string): boolean {
  const field = value[key];
  if (typeof field !== "boolean") throw new Error(`invalid PostgreSQL ${key}`);
  return field;
}

function bigintAt(value: UnknownRow, key: string): bigint {
  const field = value[key];
  if (typeof field === "bigint") return field;
  if (typeof field === "string" && /^\d+$/u.test(field)) return BigInt(field);
  if (typeof field === "number" && Number.isSafeInteger(field)) return BigInt(field);
  throw new Error(`invalid PostgreSQL ${key}`);
}

function scopesAt(value: UnknownRow, key: string): readonly DeviceScope[] {
  const field = value[key];
  if (!Array.isArray(field) || !field.every((scope) => typeof scope === "string")) {
    throw new Error(`invalid PostgreSQL ${key}`);
  }
  return normalizeDeviceScopes(field);
}

function nullableScopesAt(value: UnknownRow, key: string): readonly DeviceScope[] | null {
  return value[key] === null ? null : scopesAt(value, key);
}

const pairingColumns = `
  pairing_id, user_code_sha256, device_display_name, device_public_key_spki,
  device_public_key_sha256, device_fingerprint, gateway_fingerprint, gateway_audience,
  requested_scopes, approved_scopes, administrator_proof_sha256, device_proof_payload,
  device_proof_sha256, device_id, credential_id, confirmation_payload, state,
  expires_at, confirmation_expires_at, approved_by_device_id, created_at, updated_at
`;

function parsePairing(value: unknown): PairingRecord {
  const data = row(value);
  return {
    pairingId: stringAt(data, "pairing_id"),
    userCodeSha256: stringAt(data, "user_code_sha256"),
    deviceDisplayName: stringAt(data, "device_display_name"),
    devicePublicKeySpki: bytesAt(data, "device_public_key_spki"),
    devicePublicKeySha256: stringAt(data, "device_public_key_sha256"),
    deviceFingerprint: stringAt(data, "device_fingerprint"),
    gatewayFingerprint: stringAt(data, "gateway_fingerprint"),
    gatewayAudience: stringAt(data, "gateway_audience"),
    requestedScopes: scopesAt(data, "requested_scopes"),
    approvedScopes: nullableScopesAt(data, "approved_scopes"),
    administratorProofSha256: nullableStringAt(data, "administrator_proof_sha256"),
    deviceProofPayload: bytesAt(data, "device_proof_payload"),
    deviceProofSha256: nullableStringAt(data, "device_proof_sha256"),
    deviceId: nullableStringAt(data, "device_id"),
    credentialId: nullableStringAt(data, "credential_id"),
    confirmationPayload: nullableBytesAt(data, "confirmation_payload"),
    state: stringAt(data, "state") as PairingRecord["state"],
    expiresAt: dateAt(data, "expires_at"),
    confirmationExpiresAt: nullableDateAt(data, "confirmation_expires_at"),
    approvedByDeviceId: nullableStringAt(data, "approved_by_device_id"),
    createdAt: dateAt(data, "created_at"),
    updatedAt: dateAt(data, "updated_at"),
  };
}

const credentialColumns = `
  c.credential_id, c.device_id, c.state, COALESCE(d.status = 'active', false) AS device_active,
  c.public_key_spki, c.public_key_sha256, c.gateway_audience, c.scopes, c.generation,
  c.access_token_sha256, c.access_expires_at, c.refresh_token_sha256, c.refresh_expires_at,
  c.family_expires_at
`;

function parseCredential(value: unknown): DeviceCredentialRecord {
  const data = row(value);
  return {
    credentialId: stringAt(data, "credential_id"),
    deviceId: stringAt(data, "device_id"),
    state: stringAt(data, "state") as DeviceCredentialRecord["state"],
    deviceActive: booleanAt(data, "device_active"),
    publicKeySpki: bytesAt(data, "public_key_spki"),
    publicKeySha256: stringAt(data, "public_key_sha256"),
    gatewayAudience: stringAt(data, "gateway_audience"),
    scopes: scopesAt(data, "scopes"),
    generation: bigintAt(data, "generation"),
    accessTokenSha256: nullableStringAt(data, "access_token_sha256"),
    accessExpiresAt: nullableDateAt(data, "access_expires_at"),
    refreshTokenSha256: nullableStringAt(data, "refresh_token_sha256"),
    refreshExpiresAt: dateAt(data, "refresh_expires_at"),
    familyExpiresAt: dateAt(data, "family_expires_at"),
  };
}

class PostgresPairingTransaction implements PairingLedgerTransaction {
  constructor(private readonly client: PoolClient) {}

  async consumePairingRateLimit(
    keySha256: string,
    windowStartedAt: Date,
    maximumAttempts: number,
    now: Date,
  ): Promise<boolean> {
    await this.client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [`pairing-rate:${keySha256}`]);
    const existing = await this.client.query<UnknownRow>(
      `SELECT window_started_at, attempt_count
       FROM agent_talk.pairing_rate_limits WHERE rate_key_sha256 = $1 FOR UPDATE`,
      [keySha256],
    );
    const current = existing.rows[0];
    if (current === undefined) {
      await this.client.query(
        `INSERT INTO agent_talk.pairing_rate_limits (
           rate_key_sha256, window_started_at, attempt_count, updated_at
         ) VALUES ($1, $2, 1, $2)`,
        [keySha256, now],
      );
      return true;
    }
    const data = row(current);
    const previousStart = dateAt(data, "window_started_at");
    const previousCount = Number(bigintAt(data, "attempt_count"));
    const reset = previousStart.getTime() <= windowStartedAt.getTime();
    const nextCount = reset ? 1 : previousCount + 1;
    await this.client.query(
      `UPDATE agent_talk.pairing_rate_limits
       SET window_started_at = $2, attempt_count = $3, updated_at = $4
       WHERE rate_key_sha256 = $1`,
      [keySha256, reset ? now : previousStart, nextCount, now],
    );
    return nextCount <= maximumAttempts;
  }

  async insertPairing(record: PairingRecord): Promise<void> {
    await this.client.query(
      `INSERT INTO agent_talk.pairings (
         pairing_id, user_code_sha256, device_display_name, device_public_key_spki,
         device_public_key_sha256, device_fingerprint, gateway_fingerprint, gateway_audience,
         requested_scopes, approved_scopes, administrator_proof_sha256, device_proof_payload,
         device_proof_sha256, device_id, credential_id, confirmation_payload, state,
         expires_at, confirmation_expires_at, approved_by_device_id, created_at, updated_at
       ) VALUES (
         $1, $2, $3, $4, $5, $6, $7, $8, $9, NULL, NULL, $10,
         NULL, NULL, NULL, NULL, 'pending_owner', $11, NULL, NULL, $12, $12
       )`,
      [
        record.pairingId,
        record.userCodeSha256,
        record.deviceDisplayName,
        Buffer.from(record.devicePublicKeySpki),
        record.devicePublicKeySha256,
        record.deviceFingerprint,
        record.gatewayFingerprint,
        record.gatewayAudience,
        [...record.requestedScopes],
        Buffer.from(record.deviceProofPayload),
        record.expiresAt,
        record.createdAt,
      ],
    );
  }

  async lockPairingById(pairingId: string): Promise<PairingRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT ${pairingColumns} FROM agent_talk.pairings WHERE pairing_id = $1 FOR UPDATE`,
      [pairingId],
    );
    return result.rows[0] === undefined ? undefined : parsePairing(result.rows[0]);
  }

  async lockPairingByUserCodeSha256(userCodeSha256: string): Promise<PairingRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT ${pairingColumns} FROM agent_talk.pairings WHERE user_code_sha256 = $1 FOR UPDATE`,
      [userCodeSha256],
    );
    return result.rows[0] === undefined ? undefined : parsePairing(result.rows[0]);
  }

  async lockDeviceAuthorization(deviceId: string): Promise<DeviceAuthorizationRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      "SELECT device_id, status = 'active' AS active, scopes FROM agent_talk.devices WHERE device_id = $1 FOR UPDATE",
      [deviceId],
    );
    const current = result.rows[0];
    if (current === undefined) return undefined;
    const data = row(current);
    return {
      deviceId: stringAt(data, "device_id"),
      active: booleanAt(data, "active"),
      scopes: scopesAt(data, "scopes"),
    };
  }

  async lockCredential(credentialId: string): Promise<DeviceCredentialRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT ${credentialColumns}
       FROM agent_talk.device_credentials c
       LEFT JOIN agent_talk.devices d ON d.device_id = c.device_id
       WHERE c.credential_id = $1 FOR UPDATE OF c`,
      [credentialId],
    );
    return result.rows[0] === undefined ? undefined : parseCredential(result.rows[0]);
  }

  async findUsedRefresh(
    credentialId: string,
    refreshTokenSha256: string,
  ): Promise<UsedRefreshRecord | undefined> {
    const result = await this.client.query<UnknownRow>(
      `SELECT credential_id, refresh_token_sha256, generation
       FROM agent_talk.device_refresh_history
       WHERE credential_id = $1 AND refresh_token_sha256 = $2`,
      [credentialId, refreshTokenSha256],
    );
    const current = result.rows[0];
    if (current === undefined) return undefined;
    const data = row(current);
    return {
      credentialId: stringAt(data, "credential_id"),
      refreshTokenSha256: stringAt(data, "refresh_token_sha256"),
      generation: bigintAt(data, "generation"),
    };
  }

  async recordNonce(credentialId: string, purpose: string, nonceSha256: string, usedAt: Date): Promise<boolean> {
    const result = await this.client.query(
      `INSERT INTO agent_talk.device_signature_nonces (credential_id, purpose, nonce_sha256, used_at)
       VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING`,
      [credentialId, purpose, nonceSha256, usedAt],
    );
    return result.rowCount === 1;
  }

  async approvePairing(facts: PairingApprovalFacts): Promise<void> {
    const result = await this.client.query(
      `UPDATE agent_talk.pairings
       SET state = 'approved', approved_scopes = $2, administrator_proof_sha256 = $3,
           approved_by_device_id = $4, updated_at = $5
       WHERE pairing_id = $1 AND state = 'pending_owner'`,
      [
        facts.pairingId,
        [...facts.approvedScopes],
        facts.administratorProofSha256,
        facts.administratorDeviceId,
        facts.approvedAt,
      ],
    );
    if (result.rowCount !== 1) throw new Error("pairing approval state changed concurrently");
  }

  async verifyPairingProof(facts: PairingProofFacts): Promise<void> {
    const credential = facts.credential;
    await this.client.query(
      `INSERT INTO agent_talk.device_credentials (
         credential_id, pairing_id, origin, device_id, state, public_key_spki, public_key_sha256,
         gateway_audience, scopes, generation, access_token_sha256, access_expires_at,
         refresh_token_sha256, refresh_expires_at, family_expires_at, confirmation_payload,
         confirmation_expires_at, created_at, activated_at, revoked_at
       ) VALUES (
         $1, $2, 'pairing', $3, 'pending_confirmation', $4, $5, $6, $7, 1, NULL, NULL,
         NULL, $8, $8, $9, $10, $11, NULL, NULL
       )`,
      [
        credential.credentialId,
        credential.pairingId,
        credential.deviceId,
        Buffer.from(credential.publicKeySpki),
        credential.publicKeySha256,
        credential.gatewayAudience,
        [...credential.scopes],
        credential.familyExpiresAt,
        Buffer.from(credential.confirmationPayload),
        credential.confirmationExpiresAt,
        credential.createdAt,
      ],
    );
    const result = await this.client.query(
      `UPDATE agent_talk.pairings
       SET state = 'proof_verified', device_proof_sha256 = $2, device_id = $3,
           credential_id = $4, confirmation_payload = $5, confirmation_expires_at = $6, updated_at = $7
       WHERE pairing_id = $1 AND state = 'approved'`,
      [
        facts.pairingId,
        facts.proofSha256,
        facts.deviceId,
        credential.credentialId,
        Buffer.from(credential.confirmationPayload),
        credential.confirmationExpiresAt,
        facts.verifiedAt,
      ],
    );
    if (result.rowCount !== 1) throw new Error("pairing proof state changed concurrently");
  }

  async activatePairing(facts: PairingActivationFacts): Promise<void> {
    await this.client.query(
      `INSERT INTO agent_talk.devices (
         device_id, display_name, public_key_sha256, status, scopes, token_generation, paired_at, revoked_at
       ) VALUES ($1, $2, $3, 'active', $4, 1, $5, NULL)`,
      [facts.deviceId, facts.displayName, facts.publicKeySha256, [...facts.scopes], facts.activatedAt],
    );
    const credential = await this.client.query(
      `UPDATE agent_talk.device_credentials
       SET state = 'active', access_token_sha256 = $3, access_expires_at = $4,
           refresh_token_sha256 = $5, refresh_expires_at = $6, activated_at = $7
       WHERE credential_id = $1 AND device_id = $2 AND state = 'pending_confirmation'
         AND confirmation_expires_at > $7 AND family_expires_at >= $6`,
      [
        facts.credentialId,
        facts.deviceId,
        facts.accessTokenSha256,
        facts.accessExpiresAt,
        facts.refreshTokenSha256,
        facts.refreshExpiresAt,
        facts.activatedAt,
      ],
    );
    if (credential.rowCount !== 1) throw new Error("pending credential state changed concurrently");
    const pairing = await this.client.query(
      `UPDATE agent_talk.pairings SET state = 'confirmed', updated_at = $4
       WHERE pairing_id = $1 AND credential_id = $2 AND device_id = $3 AND state = 'proof_verified'`,
      [facts.pairingId, facts.credentialId, facts.deviceId, facts.activatedAt],
    );
    if (pairing.rowCount !== 1) throw new Error("pairing confirmation state changed concurrently");
  }

  async rotateCredential(facts: CredentialRotationFacts): Promise<void> {
    await this.client.query(
      `INSERT INTO agent_talk.device_refresh_history (
         credential_id, refresh_token_sha256, generation, used_at
       ) VALUES ($1, $2, $3, $4)`,
      [
        facts.credentialId,
        facts.previousRefreshTokenSha256,
        facts.expectedGeneration.toString(),
        facts.rotatedAt,
      ],
    );
    const result = await this.client.query(
      `UPDATE agent_talk.device_credentials
       SET generation = generation + 1, access_token_sha256 = $5, access_expires_at = $6,
           refresh_token_sha256 = $7, refresh_expires_at = $8
       WHERE credential_id = $1 AND device_id = $2 AND state = 'active'
         AND generation = $3 AND refresh_token_sha256 = $4 AND family_expires_at >= $8`,
      [
        facts.credentialId,
        facts.deviceId,
        facts.expectedGeneration.toString(),
        facts.previousRefreshTokenSha256,
        facts.accessTokenSha256,
        facts.accessExpiresAt,
        facts.refreshTokenSha256,
        facts.refreshExpiresAt,
      ],
    );
    if (result.rowCount !== 1) throw new Error("credential rotation state changed concurrently");
  }

  async revokeDeviceCredentials(facts: DeviceRevocationFacts): Promise<void> {
    const device = await this.client.query(
      `UPDATE agent_talk.devices
       SET status = 'revoked', token_generation = token_generation + 1, revoked_at = $2
       WHERE device_id = $1 AND status = 'active'`,
      [facts.deviceId, facts.revokedAt],
    );
    if (device.rowCount !== 1) throw new Error("active device state changed concurrently");
    await this.client.query(
      `UPDATE agent_talk.device_credentials
       SET state = 'revoked', access_token_sha256 = NULL, access_expires_at = NULL,
           refresh_token_sha256 = NULL, revoked_at = $2
       WHERE device_id = $1 AND state <> 'revoked'`,
      [facts.deviceId, facts.revokedAt],
    );
  }

  async expirePairing(pairingId: string, expiredAt: Date): Promise<void> {
    await this.client.query(
      `UPDATE agent_talk.device_credentials
       SET state = 'revoked', access_token_sha256 = NULL, access_expires_at = NULL,
           refresh_token_sha256 = NULL, revoked_at = $2
       WHERE pairing_id = $1 AND state = 'pending_confirmation'`,
      [pairingId, expiredAt],
    );
    await this.client.query(
      `UPDATE agent_talk.pairings SET state = 'expired', updated_at = $2
       WHERE pairing_id = $1 AND state NOT IN ('confirmed', 'rejected', 'expired')`,
      [pairingId, expiredAt],
    );
  }

  async insertSecurityAudit(fact: PairingAuditFact): Promise<void> {
    await this.client.query(
      `INSERT INTO agent_talk.security_audit_events (
         audit_id, device_id, action, outcome, target_type, target_id_sha256, safe_code, occurred_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        fact.auditId,
        fact.deviceId,
        fact.action,
        fact.outcome,
        fact.targetType,
        fact.targetIdSha256,
        fact.safeCode,
        fact.occurredAt,
      ],
    );
  }
}

export class PostgresPairingLedger implements PairingLedger {
  constructor(private readonly pool: Pool) {}

  async runPairingTransaction<T>(work: (transaction: PairingLedgerTransaction) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const result = await work(new PostgresPairingTransaction(client));
      await client.query("COMMIT");
      return result;
    } catch (error) {
      try {
        await client.query("ROLLBACK");
      } catch {
        // Preserve the original failure; the pool discards unusable connections.
      }
      throw error;
    } finally {
      client.release();
    }
  }
}
