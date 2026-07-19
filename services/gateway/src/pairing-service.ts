import { Code, ConnectError, type HandlerContext, type ServiceImpl } from "@connectrpc/connect";

import { PairingService } from "@agent-talk/protocol";

import type { AuthenticatedDevicePrincipal } from "./device-identity.js";
import type { PairingCoordinator } from "./pairing.js";
import { PairingError } from "./pairing.js";

export interface PairingDeviceIdentityVerifier {
  authenticateDevice(headers: Headers, requiredScope?: "administer"): Promise<AuthenticatedDevicePrincipal>;
  revalidateDevice(principal: AuthenticatedDevicePrincipal, requiredScope?: "administer"): Promise<void>;
}

export interface PairingRpcServiceOptions {
  coordinator: Pick<
    PairingCoordinator,
    "begin" | "inspect" | "approve" | "complete" | "confirm" | "refresh" | "revokeDevice"
  >;
  identityVerifier: PairingDeviceIdentityVerifier;
  rateLimitKey(context: HandlerContext): string;
}

function mapPairingError(error: unknown): never {
  if (error instanceof ConnectError) throw error;
  if (!(error instanceof PairingError)) throw error;
  const code = (() => {
    switch (error.code) {
      case "invalid_request":
        return Code.InvalidArgument;
      case "rate_limited":
        return Code.ResourceExhausted;
      case "pairing_not_found":
      case "credential_not_found":
        return Code.NotFound;
      case "authentication_failed":
      case "proof_invalid":
        return Code.Unauthenticated;
      case "authorization_denied":
      case "scope_not_allowed":
      case "credential_revoked":
      case "refresh_replayed":
        return Code.PermissionDenied;
      case "pairing_expired":
      case "credential_expired":
        return Code.DeadlineExceeded;
      case "pairing_not_approved":
      case "pairing_conflict":
      case "fingerprint_mismatch":
      case "nonce_replayed":
        return Code.FailedPrecondition;
    }
  })();
  throw new ConnectError(error.message, code, {
    "agent-talk-error-code": error.code,
  });
}

async function execute<T>(operation: () => Promise<T>): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    mapPairingError(error);
  }
}

function unixMilliseconds(value: Date): bigint {
  return BigInt(value.getTime());
}

export function createPairingService(options: PairingRpcServiceOptions): ServiceImpl<typeof PairingService> {
  return {
    async beginPairing(request, context) {
      const result = await execute(() => options.coordinator.begin({
        deviceDisplayName: request.deviceDisplayName,
        devicePublicKey: request.devicePublicKey,
        requestedScopes: request.requestedScopes,
        expectedGatewayAudience: request.expectedGatewayAudience,
        rateLimitKey: options.rateLimitKey(context),
      }));
      return {
        pairingId: result.pairingId,
        userCode: result.userCode,
        verificationUri: result.verificationUri,
        expiresInSeconds: result.expiresInSeconds,
        deviceProofPayload: result.deviceProofPayload,
        deviceFingerprint: result.deviceFingerprint,
        gatewayFingerprint: result.gatewayFingerprint,
        gatewayAudience: result.gatewayAudience,
      };
    },

    async inspectPairing(request, context) {
      const principal = await options.identityVerifier.authenticateDevice(context.requestHeader, "administer");
      const result = await execute(() => options.coordinator.inspect(request.userCode, principal.deviceId));
      return {
        pairingId: result.pairingId,
        deviceDisplayName: result.deviceDisplayName,
        deviceFingerprint: result.deviceFingerprint,
        gatewayFingerprint: result.gatewayFingerprint,
        gatewayAudience: result.gatewayAudience,
        requestedScopes: [...result.requestedScopes],
        expiresInSeconds: result.expiresInSeconds,
      };
    },

    async approvePairing(request, context) {
      const principal = await options.identityVerifier.authenticateDevice(context.requestHeader, "administer");
      const result = await execute(() => options.coordinator.approve({
        pairingId: request.pairingId,
        userCode: request.userCode,
        approvedScopes: request.approvedScopes,
        expectedDeviceFingerprint: request.expectedDeviceFingerprint,
        expectedGatewayFingerprint: request.expectedGatewayFingerprint,
        expectedGatewayAudience: request.expectedGatewayAudience,
        administratorDeviceId: principal.deviceId,
        administratorSignature: request.administratorSignature,
      }));
      return { approved: result.approved, expiresInSeconds: result.expiresInSeconds };
    },

    async completePairing(request) {
      const result = await execute(() => options.coordinator.complete({
        pairingId: request.pairingId,
        legacyDeviceProof: request.deviceProof,
        deviceKeyProof: request.deviceKeyProof,
      }));
      return {
        deviceId: result.deviceId,
        accessToken: "",
        refreshToken: "",
        scopes: [...result.scopes],
        credentialId: result.credentialId,
        confirmationPayload: result.confirmationPayload,
        gatewayAudience: result.gatewayAudience,
        confirmationExpiresInSeconds: result.confirmationExpiresInSeconds,
      };
    },

    async confirmPairing(request) {
      const result = await execute(() => options.coordinator.confirm({
        pairingId: request.pairingId,
        credentialId: request.credentialId,
        deviceSignature: request.deviceSignature,
      }));
      return {
        paired: true,
        deviceId: result.deviceId,
        credentialId: result.credentialId,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        scopes: [...result.scopes],
        accessExpiresAtUnixMs: unixMilliseconds(result.accessExpiresAt),
        refreshExpiresAtUnixMs: unixMilliseconds(result.refreshExpiresAt),
        gatewayAudience: result.gatewayAudience,
      };
    },

    async refreshDeviceCredential(request) {
      const result = await execute(() => options.coordinator.refresh({
        credentialId: request.credentialId,
        refreshToken: request.refreshToken,
        deviceSignature: request.deviceSignature,
      }));
      return {
        deviceId: result.deviceId,
        credentialId: result.credentialId,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        scopes: [...result.scopes],
        accessExpiresAtUnixMs: unixMilliseconds(result.accessExpiresAt),
        refreshExpiresAtUnixMs: unixMilliseconds(result.refreshExpiresAt),
        gatewayAudience: result.gatewayAudience,
      };
    },

    async revokeDevice(request, context) {
      const principal = await options.identityVerifier.authenticateDevice(context.requestHeader, "administer");
      const revoked = await execute(() => options.coordinator.revokeDevice({
        targetDeviceId: request.deviceId,
        reasonCode: request.reasonCode,
        administratorDeviceId: principal.deviceId,
        administratorSignature: request.administratorSignature,
      }));
      return { revoked };
    },
  };
}
