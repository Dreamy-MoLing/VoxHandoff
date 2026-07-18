import assert from "node:assert/strict";
import { appendFile, cp, mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { Pool } from "pg";

import { acceptRequest, GatewayCommandError, type AcceptRequestInput } from "./acceptance.js";
import { MigrationError, runMigrations } from "./migrations.js";
import { PostgresGatewayLedger } from "./postgres-ledger.js";

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
    const leaseId = `lease-${suffix}`;
    const nodeId = `node-${suffix}`;
    const agentId = `agent-${suffix}`;
    let nextId = 0;

    try {
      assert.deepEqual(await runMigrations(pool, migrationDirectory), ["0001_gateway_ledger.sql"]);
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
         ) VALUES ($1, 'test device', $2, 'active', ARRAY['agent:send'], $3)`,
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
      await pool.query(
        `INSERT INTO agent_talk.control_leases (
           conversation_id, lease_id, device_id, revision, expires_at, updated_at
         ) VALUES ($1, $2, $3, 1, $4, $5)`,
        [conversationId, leaseId, deviceId, new Date("2030-01-01T00:00:30.000Z"), pairedAt],
      );

      const makeInput = (ordinal: number): AcceptRequestInput => ({
        requestId: `request-${ordinal}-${suffix}`,
        commandId: `command-${ordinal}-${suffix}`,
        idempotencyKey: `idempotency-${ordinal}-${suffix}`,
        deviceId,
        connectionId,
        conversationId,
        sessionId: `session-${suffix}`,
        leaseId,
        leaseRevision: 1n,
        nodeId,
        agentId,
        capabilityRevision: "cap-1",
        confirmedText: `confirmed prompt ${ordinal}`,
      });
      const dependencies = {
        now: () => new Date("2030-01-01T00:00:01.000Z"),
        newOpaqueId: () => `generated-${++nextId}-${suffix}`,
      };

      const ledger = new PostgresGatewayLedger(pool);
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

      await pool.query("UPDATE agent_talk.agents SET max_request_bytes = 1 WHERE agent_id = $1", [agentId]);
      await assert.rejects(
        acceptRequest(recreatedGatewayLedger, makeInput(3), dependencies),
        (error: unknown) => error instanceof GatewayCommandError && error.code === "request_too_large",
      );
      const afterFailure = await pool.query<{ last_sequence: string }>(
        "SELECT last_sequence::text FROM agent_talk.conversations WHERE conversation_id = $1",
        [conversationId],
      );
      assert.equal(afterFailure.rows[0]?.last_sequence, "2");
    } finally {
      await pool.end();
    }
  },
);
