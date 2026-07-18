import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

import type { Pool } from "pg";

export type MigrationErrorCode = "migration_changed" | "database_schema_newer";

export class MigrationError extends Error {
  constructor(
    readonly code: MigrationErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "MigrationError";
  }
}

interface MigrationFile {
  name: string;
  sha256: string;
  sql: string;
}

interface AppliedMigrationRow {
  name: string;
  sha256: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseAppliedMigration(value: unknown): AppliedMigrationRow {
  if (!isRecord(value) || typeof value.name !== "string" || typeof value.sha256 !== "string") {
    throw new Error("invalid schema_migrations row");
  }
  return { name: value.name, sha256: value.sha256 };
}

async function loadMigrations(directory: string): Promise<MigrationFile[]> {
  const names = (await readdir(directory))
    .filter((name) => /^\d{4}_[a-z0-9_]+\.sql$/u.test(name))
    .sort((left, right) => left.localeCompare(right));
  const migrations: MigrationFile[] = [];
  for (const name of names) {
    const sql = await readFile(path.join(directory, name), "utf8");
    migrations.push({ name, sql, sha256: createHash("sha256").update(sql, "utf8").digest("hex") });
  }
  return migrations;
}

export async function runMigrations(pool: Pool, directory: string): Promise<readonly string[]> {
  const migrations = await loadMigrations(directory);
  const client = await pool.connect();
  const appliedNow: string[] = [];
  try {
    await client.query("BEGIN");
    await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", ["agent-talk:migrations"]);
    await client.query("CREATE SCHEMA IF NOT EXISTS agent_talk");
    await client.query(`
      CREATE TABLE IF NOT EXISTS agent_talk.schema_migrations (
        name text PRIMARY KEY,
        sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
        applied_at timestamptz NOT NULL
      )
    `);

    const result = await client.query("SELECT name, sha256 FROM agent_talk.schema_migrations ORDER BY name");
    const applied = new Map(result.rows.map((row: unknown) => {
      const parsed = parseAppliedMigration(row);
      return [parsed.name, parsed.sha256] as const;
    }));
    const availableNames = new Set(migrations.map((migration) => migration.name));
    for (const name of applied.keys()) {
      if (!availableNames.has(name)) {
        throw new MigrationError(
          "database_schema_newer",
          `Database migration ${name} is not known to this Gateway build.`,
        );
      }
    }

    for (const migration of migrations) {
      const existingHash = applied.get(migration.name);
      if (existingHash !== undefined) {
        if (existingHash !== migration.sha256) {
          throw new MigrationError("migration_changed", `Applied migration ${migration.name} was modified.`);
        }
        continue;
      }

      await client.query(migration.sql);
      await client.query(
        "INSERT INTO agent_talk.schema_migrations (name, sha256, applied_at) VALUES ($1, $2, clock_timestamp())",
        [migration.name, migration.sha256],
      );
      appliedNow.push(migration.name);
    }

    await client.query("COMMIT");
    return appliedNow;
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch {
      // Preserve the migration error; the pool will discard a broken connection.
    }
    throw error;
  } finally {
    client.release();
  }
}
