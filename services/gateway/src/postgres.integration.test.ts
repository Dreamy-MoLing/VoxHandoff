import assert from "node:assert/strict";
import { generateKeyPairSync, sign } from "node:crypto";
import { appendFile, cp, mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { Pool } from "pg";
import {
  DeviceSignatureAlgorithm,
  approvalDecisionPayload,
  administratorPairingPayload,
  credentialRefreshPayload,
  deviceRevocationPayload,
  ownerBootstrapPayload,
} from "@agent-talk/protocol";

import { acceptRequest, GatewayCommandError, type AcceptRequestInput } from "./acceptance.js";
import { acquireControlLease, renewControlLease } from "./control-lease.js";
import { EventOutboxPump } from "./event-publication.js";
import {
  acceptApprovalCommand,
  acceptClarificationCommand,
  acceptInterruptCommand,
} from "./interaction-commands.js";
import { MigrationError, runMigrations } from "./migrations.js";
import { PostgresGatewayLedger } from "./postgres-ledger.js";
import { NodeLedgerError } from "./node-ledger.js";
import { BoundedLiveEventHub } from "./live-events.js";
import { normalizeEd25519PublicKey, sha256 } from "./device-crypto.js";
import { DeviceStreamIdentityVerifier, PostgresDeviceCredentialAuthority } from "./device-identity.js";
import { PairingCoordinator } from "./pairing.js";
import { PostgresPairingLedger } from "./postgres-pairing-ledger.js";
import { bootstrapInitialOwner, PostgresOwnerBootstrapStore } from "./owner-bootstrap.js";

const databaseUrl = process.env.AGENT_TALK_POSTGRES_URL;
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const migrationDirectory = path.join(root, "infra/postgres/migrations");

test(
  "PostgreSQL migration and acceptance ledger converge across retry and Gateway recreation",
  { skip: databaseUrl === undefined ? "set AGENT_TALK_POSTGRES_URL for explicit PostgreSQL integration" : false },
  async () => {
    assert(databaseUrl);
    const pool = new Pool({ connectionString: databaseUrl, max: 4 });
    const suffix = `${process.pid}-${Date.now()}`;
    const deviceId = `device-${suffix}`;
    const connectionId = `connection-${suffix}`;
    const conversationId = `conversation-${suffix}`;
    const nodeId = `node-${suffix}`;
    const agentId = `agent-${suffix}`;
    let nextId = 0;

    try {
      assert.deepEqual(await runMigrations(pool, migrationDirectory), [
        "0001_gateway_ledger.sql",
        "0002_approval_rejected_state.sql",
        "0003_request_failure_details.sql",
        "0004_dispatch_ack_facts.sql",
        "0005_interaction_commands.sql",
        "0006_device_pairing.sql",
        "0007_credential_rotation.sql",
      ]);
      assert.deepEqual(await runMigrations(pool, migrationDirectory), []);

      const temporaryDirectory = await mkdtemp(path.join(os.tmpdir(), "agent-talk-migration-check-"));
      try {
        await cp(migrationDirectory, temporaryDirectory, { recursive: true });
        await appendFile(path.join(temporaryDirectory, "0001_gateway_ledger.sql"), "\n-- mutation must be rejected\n");
        await assert.rejects(
          runMigrations(pool, temporaryDirectory),
          (error: unknown) => error instanceof MigrationError && error.code === "migration_changed",
        );
      } finally {
        await rm(temporaryDirectory, { recursive: true, force: true });
      }

      const pairedAt = new Date("2030-01-01T00:00:00.000Z");
      const administratorKeys = generateKeyPairSync("ed25519");
      const administratorSpki = new Uint8Array(
        administratorKeys.publicKey.export({ format: "der", type: "spki" }),
      );
      const administratorPublicKey = normalizeEd25519PublicKey(administratorSpki);
      const administratorCredentialId = `administrator-credential-${suffix}`;
      const ownerNonce = new Uint8Array(32).fill(3);
      const ownerPayload = ownerBootstrapPayload({
        gatewayAudience: "https://gateway.example",
        deviceFingerprint: administratorPublicKey.fingerprint,
        scopes: ["administer", "approve", "interrupt", "observe", "send"],
        nonce: ownerNonce,
      });
      const owner = await bootstrapInitialOwner(new PostgresOwnerBootstrapStore(pool), {
        deviceDisplayName: "test device",
        devicePublicKey: administratorSpki,
        expectedGatewayAudience: "https://gateway.example",
        deviceSignature: {
          $typeName: "agent_talk.v1.DeviceSignature",
          credentialId: "",
          nonce: ownerNonce,
          signature: new Uint8Array(sign(null, ownerPayload, administratorKeys.privateKey)),
          algorithm: DeviceSignatureAlgorithm.ED25519,
        },
      }, {
        gatewayAudience: "https://gateway.example",
        now: () => pairedAt,
        newOpaqueId: (prefix) => {
          if (prefix === "device") return deviceId;
          if (prefix === "credential") return administratorCredentialId;
          return `owner-${prefix}-${suffix}`;
        },
        newOpaqueSecret: (bytes = 32) => `${bytes}-${"o".repeat(bytes)}`,
      });
      assert.equal(owner.deviceId, deviceId);
      await assert.rejects(
        bootstrapInitialOwner(new PostgresOwnerBootstrapStore(pool), {
          deviceDisplayName: "duplicate owner",
          devicePublicKey: administratorSpki,
          expectedGatewayAudience: "https://gateway.example",
          deviceSignature: {
            $typeName: "agent_talk.v1.DeviceSignature",
            credentialId: "",
            nonce: ownerNonce,
            signature: new Uint8Array(sign(null, ownerPayload, administratorKeys.privateKey)),
            algorithm: DeviceSignatureAlgorithm.ED25519,
          },
        }, { gatewayAudience: "https://gateway.example" }),
      );

      const pairingDeviceKeys = generateKeyPairSync("ed25519");
      const pairingDeviceSpki = new Uint8Array(
        pairingDeviceKeys.publicKey.export({ format: "der", type: "spki" }),
      );
      let pairingIdentity = 0;
      let pairingChallenge = 0;
      const pairingDependencies = {
        now: () => new Date("2030-01-01T00:00:05.000Z"),
        newOpaqueId: (prefix: string) => `${prefix}-${++pairingIdentity}-${suffix}`,
        newChallenge: (bytes = 32) => new Uint8Array(bytes).fill(++pairingChallenge),
        newOpaqueSecret: (bytes = 32) => `${bytes}-${++pairingIdentity}-${"s".repeat(bytes)}`,
        newUserCode: () => "WXYZ-2345",
      };
      const pairingCoordinator = new PairingCoordinator(new PostgresPairingLedger(pool), {
        gatewayAudience: "https://gateway.example",
        gatewayFingerprint: `sha256:${"f".repeat(64)}`,
        verificationUri: "https://gateway.example/pair",
        dependencies: pairingDependencies,
      });
      const begunPairing = await pairingCoordinator.begin({
        deviceDisplayName: "PostgreSQL paired device",
        devicePublicKey: pairingDeviceSpki,
        requestedScopes: ["observe", "send"],
        expectedGatewayAudience: "https://gateway.example",
        rateLimitKey: `test-rate-${suffix}`,
      });
      assert.equal(
        (await pairingCoordinator.inspect(begunPairing.userCode, deviceId)).pairingId,
        begunPairing.pairingId,
      );
      const administratorNonce = new Uint8Array(32).fill(7);
      const administratorPayload = administratorPairingPayload({
        pairingId: begunPairing.pairingId,
        userCode: begunPairing.userCode,
        deviceFingerprint: begunPairing.deviceFingerprint,
        gatewayFingerprint: begunPairing.gatewayFingerprint,
        gatewayAudience: begunPairing.gatewayAudience,
        approvedScopes: ["observe"],
        nonce: administratorNonce,
      });
      await pairingCoordinator.approve({
        pairingId: begunPairing.pairingId,
        userCode: begunPairing.userCode,
        approvedScopes: ["observe"],
        expectedDeviceFingerprint: begunPairing.deviceFingerprint,
        expectedGatewayFingerprint: begunPairing.gatewayFingerprint,
        expectedGatewayAudience: begunPairing.gatewayAudience,
        administratorDeviceId: deviceId,
        administratorSignature: {
          $typeName: "agent_talk.v1.DeviceSignature",
          credentialId: administratorCredentialId,
          nonce: administratorNonce,
          signature: new Uint8Array(sign(null, administratorPayload, administratorKeys.privateKey)),
          algorithm: DeviceSignatureAlgorithm.ED25519,
        },
      });
      const completedPairing = await pairingCoordinator.complete({
        pairingId: begunPairing.pairingId,
        legacyDeviceProof: "",
        deviceKeyProof: {
          $typeName: "agent_talk.v1.DeviceSignature",
          credentialId: "",
          nonce: new Uint8Array(),
          signature: new Uint8Array(sign(null, begunPairing.deviceProofPayload, pairingDeviceKeys.privateKey)),
          algorithm: DeviceSignatureAlgorithm.ED25519,
        },
      });
      const recreatedPairingCoordinator = new PairingCoordinator(new PostgresPairingLedger(pool), {
        gatewayAudience: "https://gateway.example",
        gatewayFingerprint: `sha256:${"f".repeat(64)}`,
        verificationUri: "https://gateway.example/pair",
        dependencies: pairingDependencies,
      });
      const confirmedPairing = await recreatedPairingCoordinator.confirm({
        pairingId: begunPairing.pairingId,
        credentialId: completedPairing.credentialId,
        deviceSignature: {
          $typeName: "agent_talk.v1.DeviceSignature",
          credentialId: completedPairing.credentialId,
          nonce: new Uint8Array(),
          signature: new Uint8Array(
            sign(null, completedPairing.confirmationPayload, pairingDeviceKeys.privateKey),
          ),
          algorithm: DeviceSignatureAlgorithm.ED25519,
        },
      });
      const pairingFacts = await pool.query<{
        pairing_state: string;
        credential_state: string;
        device_status: string;
        access_token_sha256: string;
        refresh_token_sha256: string;
      }>(
        `SELECT p.state AS pairing_state, c.state AS credential_state, d.status AS device_status,
                c.access_token_sha256, c.refresh_token_sha256
         FROM agent_talk.pairings p
         JOIN agent_talk.device_credentials c USING (pairing_id)
         JOIN agent_talk.devices d ON d.device_id = c.device_id
         WHERE p.pairing_id = $1`,
        [begunPairing.pairingId],
      );
      assert.deepEqual(pairingFacts.rows[0], {
        pairing_state: "confirmed",
        credential_state: "active",
        device_status: "active",
        access_token_sha256: sha256(confirmedPairing.accessToken),
        refresh_token_sha256: sha256(confirmedPairing.refreshToken),
      });
      const deviceIdentityVerifier = new DeviceStreamIdentityVerifier(
        new PostgresDeviceCredentialAuthority(pool),
        {
          gatewayAudience: "https://gateway.example",
          now: () => new Date("2030-01-01T00:00:06.000Z"),
        },
      );
      const firstAccessPrincipal = await deviceIdentityVerifier.authenticate(
        new Headers({ authorization: `Bearer ${confirmedPairing.accessToken}` }),
        "client",
      );
      assert.equal(firstAccessPrincipal.principalId, confirmedPairing.deviceId);
      const refreshNonce = new Uint8Array(32).fill(8);
      const refreshPayload = credentialRefreshPayload({
        credentialId: confirmedPairing.credentialId,
        deviceId: confirmedPairing.deviceId,
        gatewayAudience: confirmedPairing.gatewayAudience,
        refreshTokenSha256: sha256(confirmedPairing.refreshToken),
        generation: 1n,
        nonce: refreshNonce,
      });
      const refreshedPairing = await recreatedPairingCoordinator.refresh({
        credentialId: confirmedPairing.credentialId,
        refreshToken: confirmedPairing.refreshToken,
        deviceSignature: {
          $typeName: "agent_talk.v1.DeviceSignature",
          credentialId: confirmedPairing.credentialId,
          nonce: refreshNonce,
          signature: new Uint8Array(sign(null, refreshPayload, pairingDeviceKeys.privateKey)),
          algorithm: DeviceSignatureAlgorithm.ED25519,
        },
      });
      const rotationFacts = await pool.query<{
        generation: string;
        access_token_sha256: string;
        refresh_token_sha256: string;
        history_count: string;
      }>(
        `SELECT c.generation::text, c.access_token_sha256, c.refresh_token_sha256,
                (SELECT count(*)::text FROM agent_talk.device_refresh_history h
                 WHERE h.credential_id = c.credential_id) AS history_count
         FROM agent_talk.device_credentials c WHERE c.credential_id = $1`,
        [confirmedPairing.credentialId],
      );
      assert.deepEqual(rotationFacts.rows[0], {
        generation: "2",
        access_token_sha256: sha256(refreshedPairing.accessToken),
        refresh_token_sha256: sha256(refreshedPairing.refreshToken),
        history_count: "1",
      });
      await assert.rejects(deviceIdentityVerifier.revalidate(firstAccessPrincipal));
      const refreshedAccessPrincipal = await deviceIdentityVerifier.authenticate(
        new Headers({ authorization: `Bearer ${refreshedPairing.accessToken}` }),
        "client",
      );
      const revocationNonce = new Uint8Array(32).fill(9);
      const revocationPayload = deviceRevocationPayload({
        administratorDeviceId: deviceId,
        targetDeviceId: confirmedPairing.deviceId,
        reasonCode: "integration_revoked",
        gatewayAudience: confirmedPairing.gatewayAudience,
        nonce: revocationNonce,
      });
      assert.equal(await recreatedPairingCoordinator.revokeDevice({
        targetDeviceId: confirmedPairing.deviceId,
        reasonCode: "integration_revoked",
        administratorDeviceId: deviceId,
        administratorSignature: {
          $typeName: "agent_talk.v1.DeviceSignature",
          credentialId: administratorCredentialId,
          nonce: revocationNonce,
          signature: new Uint8Array(sign(null, revocationPayload, administratorKeys.privateKey)),
          algorithm: DeviceSignatureAlgorithm.ED25519,
        },
      }), true);
      const revokedFacts = await pool.query<{
        device_status: string;
        credential_state: string;
        access_token_sha256: string | null;
        refresh_token_sha256: string | null;
      }>(
        `SELECT d.status AS device_status, c.state AS credential_state,
                c.access_token_sha256, c.refresh_token_sha256
         FROM agent_talk.devices d JOIN agent_talk.device_credentials c USING (device_id)
         WHERE d.device_id = $1`,
        [confirmedPairing.deviceId],
      );
      assert.deepEqual(revokedFacts.rows[0], {
        device_status: "revoked",
        credential_state: "revoked",
        access_token_sha256: null,
        refresh_token_sha256: null,
      });
      await assert.rejects(deviceIdentityVerifier.revalidate(refreshedAccessPrincipal));
      await pool.query(
        `INSERT INTO agent_talk.nodes (node_id, display_name, platform, version, status, last_seen_at)
         VALUES ($1, 'test node', 'linux', 'test', 'online', $2)`,
        [nodeId, pairedAt],
      );
      await pool.query(
        `INSERT INTO agent_talk.agents (
           agent_id, node_id, display_name, adapter, version, status,
           capability_revision, capabilities, max_request_bytes
         ) VALUES ($1, $2, 'test agent', 'fake', 'test', 'online', 'cap-1',
                   '{"interrupt":true,"clarification":true}'::jsonb, 1024)`,
        [agentId, nodeId],
      );
      await pool.query(
        `INSERT INTO agent_talk.conversations (
           conversation_id, created_by_device_id, created_at, updated_at
         ) VALUES ($1, $2, $3, $3)`,
        [conversationId, deviceId, pairedAt],
      );
      const dependencies = {
        now: () => new Date("2030-01-01T00:00:10.000Z"),
        newOpaqueId: () => `generated-${++nextId}-${suffix}`,
      };
      const leaseDependencies = {
        ...dependencies,
        now: () => new Date("2030-01-01T00:00:01.000Z"),
        durationMs: 30_000,
      };
      const ledger = new PostgresGatewayLedger(pool);
      const acquired = await acquireControlLease(
        ledger,
        { deviceId, conversationId, explicitTakeover: false },
        leaseDependencies,
      );
      const renewed = await renewControlLease(
        ledger,
        {
          deviceId,
          conversationId,
          leaseId: acquired.lease.leaseId,
          expectedRevision: acquired.lease.revision,
        },
        { ...leaseDependencies, now: () => new Date("2030-01-01T00:00:09.000Z") },
      );

      const makeInput = (ordinal: number): AcceptRequestInput => ({
        requestId: `request-${ordinal}-${suffix}`,
        commandId: `command-${ordinal}-${suffix}`,
        idempotencyKey: `idempotency-${ordinal}-${suffix}`,
        deviceId,
        connectionId,
        conversationId,
        sessionId: `session-${suffix}`,
        leaseId: renewed.lease.leaseId,
        leaseRevision: renewed.lease.revision,
        nodeId,
        agentId,
        capabilityRevision: "cap-1",
        confirmedText: `confirmed prompt ${ordinal}`,
      });
      const duplicateResults = await Promise.all([
        acceptRequest(ledger, makeInput(1), dependencies),
        acceptRequest(ledger, makeInput(1), dependencies),
      ]);
      assert.deepEqual(
        duplicateResults.map((result) => result.kind).sort(),
        ["accepted", "existing"],
      );

      const recreatedGatewayLedger = new PostgresGatewayLedger(pool);
      assert.equal((await acceptRequest(recreatedGatewayLedger, makeInput(1), dependencies)).kind, "existing");
      const second = await acceptRequest(recreatedGatewayLedger, makeInput(2), dependencies);
      assert.equal(second.kind, "accepted");
      if (second.kind === "accepted") {
        assert.equal(second.facts.event.sequence, 2n);
      }

      const counts = await pool.query<{
        requests: string;
        events: string;
        dispatches: string;
        publications: string;
        last_sequence: string;
      }>(
        `SELECT
           (SELECT count(*) FROM agent_talk.requests WHERE conversation_id = $1)::text AS requests,
           (SELECT count(*) FROM agent_talk.events WHERE conversation_id = $1)::text AS events,
           (SELECT count(*) FROM agent_talk.gateway_dispatch_outbox d
              JOIN agent_talk.requests r USING (request_id) WHERE r.conversation_id = $1)::text AS dispatches,
           (SELECT count(*) FROM agent_talk.gateway_event_outbox WHERE conversation_id = $1)::text AS publications,
           (SELECT last_sequence FROM agent_talk.conversations WHERE conversation_id = $1)::text AS last_sequence`,
        [conversationId],
      );
      assert.deepEqual(counts.rows[0], {
        requests: "2",
        events: "2",
        dispatches: "2",
        publications: "2",
        last_sequence: "2",
      });

      const interruptInput = {
        commandId: `interrupt-command-${suffix}`,
        idempotencyKey: `interrupt-idempotency-${suffix}`,
        deviceId,
        connectionId,
        conversationId,
        requestId: makeInput(1).requestId,
        leaseId: renewed.lease.leaseId,
        leaseRevision: renewed.lease.revision,
      };
      const interrupt = await acceptInterruptCommand(recreatedGatewayLedger, interruptInput, dependencies);
      assert.equal(interrupt.kind, "accepted");
      assert.equal(interrupt.kind === "accepted" ? interrupt.facts.event.sequence : 0n, 3n);
      assert.equal((await acceptInterruptCommand(recreatedGatewayLedger, interruptInput, dependencies)).kind, "existing");

      const nodeRegistration = {
          nodeId,
          connectionId: "node-connection-1",
          displayName: "registered node",
          platform: "linux",
          version: "1",
          agents: [{
            agentId,
            displayName: "registered agent",
            adapter: "fake",
            version: "1",
            capabilityRevision: "cap-1",
            capabilities: { eventStream: true, interrupt: true, clarification: true, attachments: false },
            maxRequestBytes: 1024n,
          }],
        };
      await recreatedGatewayLedger.registerNode(
        nodeRegistration,
        new Date("2030-01-01T00:00:11.000Z"),
      );
      const firstClaims = await recreatedGatewayLedger.claimDispatches(
        nodeId,
        "node-connection-1",
        new Date("2030-01-01T00:00:12.000Z"),
        10,
      );
      assert.equal(firstClaims.length, 3);
      await recreatedGatewayLedger.registerNode(
        { ...nodeRegistration, connectionId: "node-connection-2" },
        new Date("2030-01-01T00:00:13.000Z"),
      );
      const reconnectClaims = await recreatedGatewayLedger.claimDispatches(
        nodeId,
        "node-connection-2",
        new Date("2030-01-01T00:00:13.000Z"),
        10,
      );
      assert.deepEqual(
        reconnectClaims.map((claim) => [claim.kind, claim.dispatchId, claim.requestId, claim.idempotencyKey]),
        firstClaims.map((claim) => [claim.kind, claim.dispatchId, claim.requestId, claim.idempotencyKey]),
      );
      const firstDispatch = reconnectClaims.find(
        (claim) => claim.kind === "send" && claim.requestId === makeInput(1).requestId,
      );
      assert(firstDispatch);
      await assert.rejects(
        recreatedGatewayLedger.acknowledgeDispatch({
          nodeId,
          connectionId: "node-connection-1",
          dispatchId: firstDispatch.dispatchId,
          requestId: firstDispatch.requestId,
          accepted: true,
          failure: null,
          occurredAt: new Date("2030-01-01T00:00:14.000Z"),
        }),
        (error: unknown) => error instanceof NodeLedgerError && error.code === "stale_node_connection",
      );
      await recreatedGatewayLedger.acknowledgeDispatch({
        nodeId,
        connectionId: "node-connection-2",
        dispatchId: firstDispatch.dispatchId,
        requestId: firstDispatch.requestId,
        accepted: true,
        failure: null,
        occurredAt: new Date("2030-01-01T00:00:14.000Z"),
      });
      const interruptDispatch = reconnectClaims.find((claim) => claim.kind === "interrupt");
      assert(interruptDispatch);
      await recreatedGatewayLedger.acknowledgeDispatch({
        nodeId,
        connectionId: "node-connection-2",
        dispatchId: interruptDispatch.dispatchId,
        requestId: interruptDispatch.requestId,
        accepted: true,
        failure: null,
        occurredAt: new Date("2030-01-01T00:00:14.000Z"),
      });
      await recreatedGatewayLedger.acknowledgeDispatch({
        nodeId,
        connectionId: "node-connection-2",
        dispatchId: firstDispatch.dispatchId,
        requestId: firstDispatch.requestId,
        accepted: true,
        failure: null,
        occurredAt: new Date("2030-01-01T00:00:14.000Z"),
      });
      const remainingClaims = await recreatedGatewayLedger.claimDispatches(
        nodeId,
        "node-connection-2",
        new Date("2030-01-01T00:00:15.000Z"),
        10,
      );
      assert.deepEqual(remainingClaims, []);

      const workingEvent = {
        eventId: `working-${suffix}`,
        nodeId,
        connectionId: "node-connection-2",
        requestId: makeInput(1).requestId,
        sourceSequence: 1n,
        conversationId,
        sessionId: `session-${suffix}`,
        eventType: "agent.working",
        safePayload: { safeMessage: "Agent is working." },
        requestState: "working" as const,
        failure: null,
        interaction: null,
        occurredAt: new Date("2030-01-01T00:00:16.000Z"),
      };
      await assert.rejects(
        recreatedGatewayLedger.ingestNodeEvent({ ...workingEvent, connectionId: "node-connection-1" }),
        (error: unknown) => error instanceof NodeLedgerError && error.code === "stale_node_connection",
      );
      assert.equal((await recreatedGatewayLedger.ingestNodeEvent(workingEvent)).sequence, 4n);
      await assert.rejects(
        recreatedGatewayLedger.ingestNodeEvent({ ...workingEvent, eventId: `stale-${suffix}` }),
        (error: unknown) => error instanceof NodeLedgerError && error.code === "stale_node_event",
      );
      const approvalId = `approval-${suffix}`;
      const approvalRequiredEvent = {
        ...workingEvent,
        eventId: `approval-required-${suffix}`,
        sourceSequence: 2n,
        eventType: "approval.required",
        safePayload: {
          approvalId,
          safeSummary: "Allow a harmless test action?",
          operationSummarySha256: "c".repeat(64),
          expiresAt: "2030-01-01T00:02:00.000Z",
        },
        requestState: null,
        interaction: {
          kind: "approval_required" as const,
          approvalId,
          nativeApprovalId: approvalId,
          safeSummary: "Allow a harmless test action?",
          operationSummarySha256: "c".repeat(64),
          expiresAt: new Date("2030-01-01T00:02:00.000Z"),
        },
        occurredAt: new Date("2030-01-01T00:00:16.500Z"),
      };
      assert.equal((await recreatedGatewayLedger.ingestNodeEvent(approvalRequiredEvent)).sequence, 5n);
      const pendingApproval = await pool.query<{ state: string }>(
        "SELECT state FROM agent_talk.approvals WHERE approval_id = $1",
        [approvalId],
      );
      assert.equal(pendingApproval.rows[0]?.state, "pending");
      const approvalInput = {
        commandId: `approval-command-${suffix}`,
        idempotencyKey: `approval-idempotency-${suffix}`,
        deviceId,
        conversationId,
        requestId: makeInput(1).requestId,
        approvalId,
        leaseId: renewed.lease.leaseId,
        leaseRevision: renewed.lease.revision,
        decision: "approved" as const,
        operationSummarySha256: "c".repeat(64),
        credentialId: administratorCredentialId,
        gatewayAudience: "https://gateway.example",
        deviceSignature: (() => {
          const nonce = new Uint8Array(32).fill(10);
          const payload = approvalDecisionPayload({
            credentialId: administratorCredentialId,
            deviceId,
            hostIdentity: nodeId,
            gatewayAudience: "https://gateway.example",
            requestId: makeInput(1).requestId,
            approvalId,
            decision: "approve",
            operationSummarySha256: "c".repeat(64),
            nonce,
          });
          return {
            $typeName: "agent_talk.v1.DeviceSignature" as const,
            credentialId: administratorCredentialId,
            nonce,
            signature: new Uint8Array(sign(null, payload, administratorKeys.privateKey)),
            algorithm: DeviceSignatureAlgorithm.ED25519,
          };
        })(),
      };
      assert.equal((await acceptApprovalCommand(recreatedGatewayLedger, approvalInput, dependencies)).kind, "accepted");
      assert.equal((await acceptApprovalCommand(recreatedGatewayLedger, approvalInput, dependencies)).kind, "existing");
      const approvalClaims = await recreatedGatewayLedger.claimDispatches(
        nodeId,
        "node-connection-2",
        new Date("2030-01-01T00:00:16.600Z"),
        10,
      );
      assert.equal(approvalClaims.length, 1);
      const approvalDispatch = approvalClaims[0];
      assert.equal(approvalDispatch?.kind, "approval");
      if (approvalDispatch?.kind === "approval") {
        assert.equal(approvalDispatch.approvalId, approvalId);
        assert.equal(approvalDispatch.decision, "approved");
        await recreatedGatewayLedger.acknowledgeDispatch({
          nodeId,
          connectionId: "node-connection-2",
          dispatchId: approvalDispatch.dispatchId,
          requestId: approvalDispatch.requestId,
          accepted: true,
          failure: null,
          occurredAt: new Date("2030-01-01T00:00:16.700Z"),
        });
      }
      const approvalResolvedEvent = {
        ...approvalRequiredEvent,
        eventId: `approval-resolved-${suffix}`,
        sourceSequence: 3n,
        eventType: "approval.resolved",
        interaction: {
          kind: "approval_state" as const,
          approvalId,
          operationSummarySha256: "c".repeat(64),
          state: "resolved" as const,
        },
        occurredAt: new Date("2030-01-01T00:00:16.800Z"),
      };
      assert.equal((await recreatedGatewayLedger.ingestNodeEvent(approvalResolvedEvent)).sequence, 6n);
      const clarificationId = `clarification-${suffix}`;
      const clarificationRequiredEvent = {
        ...workingEvent,
        eventId: `clarification-required-${suffix}`,
        sourceSequence: 4n,
        eventType: "clarification.required",
        safePayload: {
          clarificationId,
          safePrompt: "Which test directory should be used?",
          expiresAt: "2030-01-01T00:02:00.000Z",
        },
        requestState: null,
        interaction: {
          kind: "clarification_required" as const,
          clarificationId,
          nativeClarificationId: clarificationId,
          safePrompt: "Which test directory should be used?",
          expiresAt: new Date("2030-01-01T00:02:00.000Z"),
        },
        occurredAt: new Date("2030-01-01T00:00:16.850Z"),
      };
      assert.equal((await recreatedGatewayLedger.ingestNodeEvent(clarificationRequiredEvent)).sequence, 7n);
      const clarificationInput = {
        commandId: `clarification-command-${suffix}`,
        idempotencyKey: `clarification-idempotency-${suffix}`,
        deviceId,
        conversationId,
        requestId: makeInput(1).requestId,
        clarificationId,
        leaseId: renewed.lease.leaseId,
        leaseRevision: renewed.lease.revision,
        confirmedText: "Use the isolated test directory.",
      };
      assert.equal(
        (await acceptClarificationCommand(recreatedGatewayLedger, clarificationInput, dependencies)).kind,
        "accepted",
      );
      assert.equal(
        (await acceptClarificationCommand(recreatedGatewayLedger, clarificationInput, dependencies)).kind,
        "existing",
      );
      const clarificationClaims = await recreatedGatewayLedger.claimDispatches(
        nodeId,
        "node-connection-2",
        new Date("2030-01-01T00:00:16.900Z"),
        10,
      );
      assert.equal(clarificationClaims.length, 1);
      const clarificationDispatch = clarificationClaims[0];
      assert.equal(clarificationDispatch?.kind, "clarification");
      if (clarificationDispatch?.kind === "clarification") {
        assert.equal(clarificationDispatch.confirmedText, "Use the isolated test directory.");
        await recreatedGatewayLedger.acknowledgeDispatch({
          nodeId,
          connectionId: "node-connection-2",
          dispatchId: clarificationDispatch.dispatchId,
          requestId: clarificationDispatch.requestId,
          accepted: true,
          failure: null,
          occurredAt: new Date("2030-01-01T00:00:16.950Z"),
        });
      }
      const clarificationResolvedEvent = {
        ...clarificationRequiredEvent,
        eventId: `clarification-resolved-${suffix}`,
        sourceSequence: 5n,
        eventType: "clarification.resolved",
        interaction: {
          kind: "clarification_state" as const,
          clarificationId,
          state: "resolved" as const,
        },
        occurredAt: new Date("2030-01-01T00:00:16.975Z"),
      };
      assert.equal((await recreatedGatewayLedger.ingestNodeEvent(clarificationResolvedEvent)).sequence, 8n);
      const completedEvent = {
        ...workingEvent,
        eventId: `completed-${suffix}`,
        sourceSequence: 6n,
        eventType: "request.completed",
        safePayload: {},
        requestState: "completed" as const,
        occurredAt: new Date("2030-01-01T00:00:17.000Z"),
      };
      assert.equal((await recreatedGatewayLedger.ingestNodeEvent(completedEvent)).sequence, 9n);
      assert.equal((await recreatedGatewayLedger.ingestNodeEvent(completedEvent)).duplicate, true);
      await assert.rejects(
        recreatedGatewayLedger.ingestNodeEvent({ ...completedEvent, safePayload: { changed: true } }),
        (error: unknown) => error instanceof NodeLedgerError && error.code === "event_identity_conflict",
      );
      await assert.rejects(
        recreatedGatewayLedger.ingestNodeEvent({
          ...workingEvent,
          eventId: `late-${suffix}`,
          sourceSequence: 5n,
          occurredAt: new Date("2030-01-01T00:00:18.000Z"),
        }),
        (error: unknown) => error instanceof NodeLedgerError && error.code === "event_after_terminal",
      );
      const resolvedApproval = await pool.query<{ state: string }>(
        "SELECT state FROM agent_talk.approvals WHERE approval_id = $1",
        [approvalId],
      );
      assert.equal(resolvedApproval.rows[0]?.state, "approved");
      const resolvedClarification = await pool.query<{ state: string; confirmed_text: string }>(
        "SELECT state, confirmed_text FROM agent_talk.clarifications WHERE clarification_id = $1",
        [clarificationId],
      );
      assert.deepEqual(resolvedClarification.rows[0], {
        state: "resolved",
        confirmed_text: "Use the isolated test directory.",
      });

      const secondDispatch = reconnectClaims.find((claim) => claim.requestId === makeInput(2).requestId);
      assert(secondDispatch);
      const rejection = {
        nodeId,
        connectionId: "node-connection-2",
        dispatchId: secondDispatch.dispatchId,
        requestId: secondDispatch.requestId,
        accepted: false,
        failure: {
          stage: "agent",
          category: "unavailable",
          code: "adapter_unavailable",
          safeMessage: "The selected Agent adapter is unavailable.",
          retryable: false,
        },
        occurredAt: new Date("2030-01-01T00:00:19.000Z"),
      } as const;
      await recreatedGatewayLedger.acknowledgeDispatch(rejection);
      await recreatedGatewayLedger.acknowledgeDispatch(rejection);
      await assert.rejects(
        recreatedGatewayLedger.acknowledgeDispatch({ ...rejection, accepted: true, failure: null }),
        (error: unknown) => error instanceof NodeLedgerError && error.code === "dispatch_ack_conflict",
      );

      const storedStatus = await recreatedGatewayLedger.getRequestStatus(makeInput(1).requestId, conversationId);
      assert.equal(storedStatus?.state, "completed");
      const rejectedStatus = await recreatedGatewayLedger.getRequestStatus(makeInput(2).requestId, conversationId);
      assert.deepEqual(rejectedStatus?.failure, rejection.failure);
      assert.equal(rejectedStatus?.state, "failed");
      const replayed = await recreatedGatewayLedger.replayEvents(conversationId, 0n, 10);
      assert.deepEqual(
        replayed.map((event) => [event.sequence, event.eventType]),
        [
          [1n, "request.accepted"],
          [2n, "request.accepted"],
          [3n, "request.interrupting"],
          [4n, "agent.working"],
          [5n, "approval.required"],
          [6n, "approval.resolved"],
          [7n, "clarification.required"],
          [8n, "clarification.resolved"],
          [9n, "request.completed"],
          [10n, "request.failed"],
        ],
      );
      const liveHub = new BoundedLiveEventHub(20);
      const liveIterator = liveHub.subscribe(deviceId)[Symbol.asyncIterator]();
      const eventPump = new EventOutboxPump(recreatedGatewayLedger, liveHub, `event-worker-${suffix}`, 20);
      assert.equal(await eventPump.runOnce(new Date("2030-01-01T00:00:20.000Z")), 10);
      const liveSequences: bigint[] = [];
      for (let index = 0; index < 10; index += 1) {
        const liveBody = (await liveIterator.next()).value?.body;
        if (liveBody?.case === "event") liveSequences.push(liveBody.value.sequence ?? 0n);
      }
      assert.deepEqual(liveSequences, [1n, 2n, 3n, 4n, 5n, 6n, 7n, 8n, 9n, 10n]);
      assert.equal(await eventPump.runOnce(new Date("2030-01-01T00:00:21.000Z")), 0);
      await liveIterator.return?.();
      assert.equal(
        await recreatedGatewayLedger.acknowledgeEvent(
          deviceId,
          conversationId,
          replayed[1]!.sequence,
          replayed[1]!.eventId,
          new Date("2030-01-01T00:00:15.000Z"),
        ),
        true,
      );
      assert.equal(
        await recreatedGatewayLedger.acknowledgeEvent(
          deviceId,
          conversationId,
          999n,
          "missing-event",
          new Date("2030-01-01T00:00:16.000Z"),
        ),
        false,
      );

      await pool.query("UPDATE agent_talk.agents SET max_request_bytes = 1 WHERE agent_id = $1", [agentId]);
      await assert.rejects(
        acceptRequest(recreatedGatewayLedger, makeInput(3), dependencies),
        (error: unknown) => error instanceof GatewayCommandError && error.code === "request_too_large",
      );
      const afterFailure = await pool.query<{ last_sequence: string }>(
        "SELECT last_sequence::text FROM agent_talk.conversations WHERE conversation_id = $1",
        [conversationId],
      );
      assert.equal(afterFailure.rows[0]?.last_sequence, "10");

      const secondDeviceId = `device-2-${suffix}`;
      await pool.query(
        `INSERT INTO agent_talk.devices (
           device_id, display_name, public_key_sha256, status, scopes, paired_at
         ) VALUES ($1, 'second test device', $2, 'active', ARRAY['interrupt'], $3)`,
        [secondDeviceId, "b".repeat(64), pairedAt],
      );
      const takeover = await acquireControlLease(
        recreatedGatewayLedger,
        {
          deviceId: secondDeviceId,
          conversationId,
          explicitTakeover: true,
          expectedLeaseId: renewed.lease.leaseId,
          expectedRevision: renewed.lease.revision,
        },
        { ...leaseDependencies, now: () => new Date("2030-01-01T00:00:20.000Z") },
      );
      assert.equal(takeover.lease.revision, 3n);
      await assert.rejects(
        renewControlLease(
          recreatedGatewayLedger,
          {
            deviceId,
            conversationId,
            leaseId: renewed.lease.leaseId,
            expectedRevision: renewed.lease.revision,
          },
          { ...leaseDependencies, now: () => new Date("2030-01-01T00:00:21.000Z") },
        ),
        (error: unknown) => error instanceof GatewayCommandError && error.code === "control_lease_lost",
      );
      const auditCount = await pool.query<{ count: string }>(
        "SELECT count(*)::text AS count FROM agent_talk.security_audit_events WHERE target_id_sha256 = $1",
        [takeover.audit.targetIdSha256],
      );
      assert.equal(auditCount.rows[0]?.count, "3");
    } finally {
      await pool.end();
    }
  },
);
