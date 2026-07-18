import type { HandshakeOffer } from "./gen/agent_talk/v1/control_pb.js";

export interface NegotiatedProtocolVersion {
  major: number;
  minor: number;
}

export interface HandshakePolicy {
  current: NegotiatedProtocolVersion;
  minimumMinor: number;
  maximumMinor: number;
  attachmentsEnabled: boolean;
}

export type HandshakeNegotiation =
  | { ok: true; selected: NegotiatedProtocolVersion }
  | {
      ok: false;
      error: {
        code: string;
        safeMessage: string;
        retryable: false;
      };
    };

export const currentHandshakePolicy: HandshakePolicy = Object.freeze({
  current: Object.freeze({ major: 1, minor: 0 }),
  minimumMinor: 0,
  maximumMinor: 0,
  attachmentsEnabled: false,
});

function rejected(code: string, safeMessage: string): HandshakeNegotiation {
  return { ok: false, error: { code, safeMessage, retryable: false } };
}

export function negotiateHandshake(
  remote: HandshakeOffer,
  local: HandshakePolicy = currentHandshakePolicy,
): HandshakeNegotiation {
  const current = remote.currentProtocol;
  const range = remote.acceptedProtocols;

  if (current === undefined || range === undefined) {
    return rejected("protocol_version_missing", "The peer did not provide a complete protocol range.");
  }

  if (
    current.major === 0 ||
    range.major === 0 ||
    current.major !== range.major ||
    range.minimumMinor > range.maximumMinor ||
    current.minor < range.minimumMinor ||
    current.minor > range.maximumMinor
  ) {
    return rejected("protocol_range_invalid", "The peer provided an invalid protocol range.");
  }

  if (current.major !== local.current.major) {
    return rejected(
      "protocol_major_mismatch",
      `Protocol major ${current.major} is incompatible with local major ${local.current.major}.`,
    );
  }

  if (
    remote.schemaBuild.length === 0 ||
    remote.schemaSha256.length === 0 ||
    remote.componentVersion.length === 0 ||
    remote.componentRole === 0 ||
    remote.capabilityRevision.length === 0 ||
    remote.capabilities === undefined
  ) {
    return rejected("handshake_metadata_missing", "The peer did not provide complete handshake metadata.");
  }

  if (!local.attachmentsEnabled && remote.capabilities.attachments) {
    return rejected("attachments_not_supported", "Attachments are not supported by this release.");
  }

  const minimumMinor = Math.max(local.minimumMinor, range.minimumMinor);
  const maximumMinor = Math.min(local.maximumMinor, range.maximumMinor);
  if (minimumMinor > maximumMinor) {
    return rejected("protocol_minor_mismatch", "No mutually supported protocol minor version is available.");
  }

  return { ok: true, selected: { major: current.major, minor: maximumMinor } };
}
