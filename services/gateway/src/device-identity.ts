import { Code, ConnectError } from "@connectrpc/connect";
import type { Pool } from "pg";

import { normalizeDeviceScopes, type DeviceScope } from "@agent-talk/protocol";

import type { AuthenticatedPrincipal, StreamIdentityVerifier } from "./control-service.js";
import { canonicalGatewayAudience, sha256 } from "./device-crypto.js";

export interface AccessCredentialIdentity {
  credentialId: string;
  deviceId: string;
  credentialState: "pending_confirmation" | "active" | "revoked";
  deviceActive: boolean;
  generation: bigint;
  gatewayAudience: string;
  credentialScopes: readonly DeviceScope[];
  deviceScopes: readonly DeviceScope[];
  accessTokenSha256: string | null;
  accessExpiresAt: Date | null;
}

export interface DeviceCredentialAuthority {
  findByAccessTokenSha256(accessTokenSha256: string): Promise<AccessCredentialIdentity | undefined>;
  findByCredentialId(credentialId: string): Promise<AccessCredentialIdentity | undefined>;
}

export interface AuthenticatedDevicePrincipal {
  deviceId: string;
  credentialId: string;
  generation: bigint;
  scopes: readonly DeviceScope[];
}

export interface DeviceIdentityVerifierOptions {
  gatewayAudience: string;
  allowInsecureLoopbackForTests?: boolean;
  now?: () => Date;
}

function unauthenticated(message = "The device access credential is invalid."): never {
  throw new ConnectError(message, Code.Unauthenticated);
}

function permission(message: string): never {
  throw new ConnectError(message, Code.PermissionDenied);
}

function bearerToken(headers: Headers): string {
  const authorization = headers.get("authorization");
  const match = authorization?.match(/^Bearer ([A-Za-z0-9_-]{32,512})$/u);
  if (match?.[1] === undefined) unauthenticated();
  return match[1];
}

function validateIdentity(
  identity: AccessCredentialIdentity | undefined,
  expectedAudience: string,
  now: Date,
): AccessCredentialIdentity {
  if (
    identity === undefined ||
    identity.credentialState !== "active" ||
    !identity.deviceActive ||
    identity.gatewayAudience !== expectedAudience ||
    identity.generation <= 0n ||
    identity.accessTokenSha256 === null ||
    identity.accessExpiresAt === null ||
    identity.accessExpiresAt.getTime() <= now.getTime()
  ) {
    unauthenticated();
  }
  const deviceScopes = new Set(identity.deviceScopes);
  if (!identity.credentialScopes.every((scope) => deviceScopes.has(scope))) {
    unauthenticated("The device credential scope binding is invalid.");
  }
  return identity;
}

export class DeviceStreamIdentityVerifier implements StreamIdentityVerifier {
  private readonly gatewayAudience: string;
  private readonly now: () => Date;

  constructor(
    private readonly authority: DeviceCredentialAuthority,
    options: DeviceIdentityVerifierOptions,
  ) {
    this.gatewayAudience = canonicalGatewayAudience(
      options.gatewayAudience,
      options.allowInsecureLoopbackForTests ?? false,
    );
    this.now = options.now ?? (() => new Date());
  }

  async authenticateDevice(headers: Headers, requiredScope?: DeviceScope): Promise<AuthenticatedDevicePrincipal> {
    const tokenSha256 = sha256(bearerToken(headers));
    const identity = validateIdentity(
      await this.authority.findByAccessTokenSha256(tokenSha256),
      this.gatewayAudience,
      this.now(),
    );
    if (identity.accessTokenSha256 !== tokenSha256) unauthenticated();
    if (requiredScope !== undefined && !identity.credentialScopes.includes(requiredScope)) {
      permission(`The device credential does not include the required ${requiredScope} scope.`);
    }
    return {
      deviceId: identity.deviceId,
      credentialId: identity.credentialId,
      generation: identity.generation,
      scopes: identity.credentialScopes,
    };
  }

  async revalidateDevice(principal: AuthenticatedDevicePrincipal, requiredScope?: DeviceScope): Promise<void> {
    const identity = validateIdentity(
      await this.authority.findByCredentialId(principal.credentialId),
      this.gatewayAudience,
      this.now(),
    );
    if (
      identity.deviceId !== principal.deviceId ||
      identity.generation !== principal.generation ||
      identity.credentialScopes.join("\0") !== principal.scopes.join("\0")
    ) {
      unauthenticated("The device access credential changed; reconnect with the current token.");
    }
    if (requiredScope !== undefined && !identity.credentialScopes.includes(requiredScope)) {
      permission(`The device credential no longer includes the required ${requiredScope} scope.`);
    }
  }

  async authenticate(
    headers: Headers,
    expectedRole: AuthenticatedPrincipal["role"],
  ): Promise<AuthenticatedPrincipal> {
    if (expectedRole !== "client") {
      permission("A device credential cannot authenticate a Node stream.");
    }
    const device = await this.authenticateDevice(headers);
    return {
      principalId: device.deviceId,
      role: "client",
      scopes: device.scopes,
      credentialId: device.credentialId,
      credentialGeneration: device.generation,
    };
  }

  async revalidate(principal: AuthenticatedPrincipal): Promise<void> {
    if (
      principal.role !== "client" ||
      principal.credentialId === undefined ||
      principal.credentialGeneration === undefined
    ) {
      unauthenticated();
    }
    await this.revalidateDevice({
      deviceId: principal.principalId,
      credentialId: principal.credentialId,
      generation: principal.credentialGeneration,
      scopes: principal.scopes as readonly DeviceScope[],
    });
  }
}

type UnknownRow = Record<string, unknown>;

function row(value: unknown): UnknownRow {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("invalid PostgreSQL device credential row");
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

function dateAt(value: UnknownRow, key: string): Date | null {
  const field = value[key];
  if (field === null) return null;
  if (!(field instanceof Date) || Number.isNaN(field.getTime())) throw new Error(`invalid PostgreSQL ${key}`);
  return field;
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

const identityColumns = `
  c.credential_id, c.device_id, c.state AS credential_state,
  d.status = 'active' AS device_active, c.generation, c.gateway_audience,
  c.scopes AS credential_scopes, d.scopes AS device_scopes,
  c.access_token_sha256, c.access_expires_at
`;

function parseIdentity(value: unknown): AccessCredentialIdentity {
  const data = row(value);
  return {
    credentialId: stringAt(data, "credential_id"),
    deviceId: stringAt(data, "device_id"),
    credentialState: stringAt(data, "credential_state") as AccessCredentialIdentity["credentialState"],
    deviceActive: booleanAt(data, "device_active"),
    generation: bigintAt(data, "generation"),
    gatewayAudience: stringAt(data, "gateway_audience"),
    credentialScopes: scopesAt(data, "credential_scopes"),
    deviceScopes: scopesAt(data, "device_scopes"),
    accessTokenSha256: nullableStringAt(data, "access_token_sha256"),
    accessExpiresAt: dateAt(data, "access_expires_at"),
  };
}

export class PostgresDeviceCredentialAuthority implements DeviceCredentialAuthority {
  constructor(private readonly pool: Pool) {}

  async findByAccessTokenSha256(accessTokenSha256: string): Promise<AccessCredentialIdentity | undefined> {
    const result = await this.pool.query<UnknownRow>(
      `SELECT ${identityColumns}
       FROM agent_talk.device_credentials c
       JOIN agent_talk.devices d ON d.device_id = c.device_id
       WHERE c.access_token_sha256 = $1`,
      [accessTokenSha256],
    );
    return result.rows[0] === undefined ? undefined : parseIdentity(result.rows[0]);
  }

  async findByCredentialId(credentialId: string): Promise<AccessCredentialIdentity | undefined> {
    const result = await this.pool.query<UnknownRow>(
      `SELECT ${identityColumns}
       FROM agent_talk.device_credentials c
       JOIN agent_talk.devices d ON d.device_id = c.device_id
       WHERE c.credential_id = $1`,
      [credentialId],
    );
    return result.rows[0] === undefined ? undefined : parseIdentity(result.rows[0]);
  }
}
