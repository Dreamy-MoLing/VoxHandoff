import assert from "node:assert/strict";
import { appendFile, cp, mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { Pool } from "pg";

import { acceptRequest, GatewayCommandError, type AcceptRequestInput } from "./acceptance.js";
import { acquireControlLease, renewControlLease } from "./control-lease.js";
import { MigrationError, runMigrations } from "./migrations.js";
import { PostgresGatewayLedger } from "./postgres-ledger.js";
import { NodeLedgerError } from "./node-ledger.js";

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
      await pool.query(
        `INSERT INTO agent_talk.devices (
           device_id, display_name, public_key_sha256, status, scopes, paired_at
         ) VALUES ($1, 'test device', $2, 'active', ARRAY['send'], $3)`,
        [deviceId, "a".repeat(64), pairedAt],
      );
      await pool.query(
        `INSERT INTO agent_talk.nodes (node_id, display_name, platform, version, status, last_seen_at)
         VALUES ($1, 'test node', 'linux', 'test', 'online', $2)`,
        [nodeId, pairedAt],
      );
      await pool.query(
        `INSERT INTO agent_talk.agents (
           agent_id, node_id, display_name, adapter, version, status,
           capability_revision, capabilities, max_request_bytes
         ) VALUES ($1, $2, 'test agent', 'fake', 'test', 'online', 'cap-1', '{}'::jsonb, 1024)`,
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
            capabilities: { eventStream: true, attachments: false },
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
      assert.equal(firstClaims.length, 2);
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
        reconnectClaims.map((claim) => [claim.dispatchId, claim.requestId, claim.idempotencyKey]),
        firstClaims.map((claim) => [claim.dispatchId, claim.requestId, claim.idempotencyKey]),
      );
      const firstDispatch = reconnectClaims.find((claim) => claim.requestId === makeInput(1).requestId);
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
        occurredAt: new Date("2030-01-01T00:00:16.000Z"),
      };
      await assert.rejects(
        recreatedGatewayLedger.ingestNodeEvent({ ...workingEvent, connectionId: "node-connection-1" }),
        (error: unknown) => error instanceof NodeLedgerError && error.code === "stale_node_connection",
      );
      assert.equal((await recreatedGatewayLedger.ingestNodeEvent(workingEvent)).sequence, 3n);
      await assert.rejects(
        recreatedGatewayLedger.ingestNodeEvent({ ...workingEvent, eventId: `stale-${suffix}` }),
        (error: unknown) => error instanceof NodeLedgerError && error.code === "stale_node_event",
      );
      const completedEvent = {
        ...workingEvent,
        eventId: `completed-${suffix}`,
        sourceSequence: 2n,
        eventType: "request.completed",
        safePayload: {},
        requestState: "completed" as const,
        occurredAt: new Date("2030-01-01T00:00:17.000Z"),
      };
      assert.equal((await recreatedGatewayLedger.ingestNodeEvent(completedEvent)).sequence, 4n);
      assert.equal((await recreatedGatewayLedger.ingestNodeEvent(completedEvent)).duplicate, true);
      await assert.rejects(
        recreatedGatewayLedger.ingestNodeEvent({ ...completedEvent, safePayload: { changed: true } }),
        (error: unknown) => error instanceof NodeLedgerError && error.code === "event_identity_conflict",
      );
      await assert.rejects(
        recreatedGatewayLedger.ingestNodeEvent({
          ...workingEvent,
          eventId: `late-${suffix}`,
          sourceSequence: 3n,
          occurredAt: new Date("2030-01-01T00:00:18.000Z"),
        }),
        (error: unknown) => error instanceof NodeLedgerError && error.code === "event_after_terminal",
      );

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
          [3n, "agent.working"],
          [4n, "request.completed"],
          [5n, "request.failed"],
        ],
      );
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
      assert.equal(afterFailure.rows[0]?.last_sequence, "5");

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
