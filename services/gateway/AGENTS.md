# Agent Talk Gateway guide

This file inherits the repository-root `AGENTS.md`. Root product and security
invariants remain binding; this file only narrows the rules for
`services/gateway/**`.

## Authority and stream boundaries

- PostgreSQL is the production authority for device and credential state,
  pairing, idempotent request acceptance, control leases, event sequences and
  cursors, Node registration/dispatch, and interaction state. In-memory stores
  and fakes are test seams, not an alternate production authority.
- Authenticate and negotiate the stream before business frames, and revalidate
  the principal while it remains open. Reject stale connection, Node, request,
  session, device, and sequence identities before committing or publishing.
- A per-command domain rejection is not a transport failure. Return the
  command's durable request/failure status when the stream and principal remain
  valid; reserve stream termination/Connect errors for authentication,
  handshake, malformed-frame, resource, or transport invariants.
- Treat Node liveness as connection-specific. Registration and heartbeats must
  not revive a superseded connection, and dispatch acknowledgements/events from
  stale connections fail closed. Preserve multiple paired devices as distinct
  principals; observation does not grant control, and mutating actions remain
  bound to scope plus the current conversation lease.
- Commit authoritative state before publishing an outbox/live event or
  acknowledging acceptance. Never infer acceptance from an attempted write or
  silently retry an outcome that may already have committed.

## PostgreSQL migrations

- Migrations live in `infra/postgres/migrations/` and are forward-only. Append
  the next zero-padded `NNNN_description.sql`; never edit, rename, reorder, or
  remove an applied migration. The checksum guard intentionally rejects drift.
- Make migrations transactional and safe across Gateway restarts/concurrent
  starts. Do not add an automatic down migration, schema reset, or data-dropping
  fallback. Exercise upgrades against an isolated real PostgreSQL database.

## Commands and completion gate

From the repository root:

```bash
npm run check -w @agent-talk/gateway
npm run test -w @agent-talk/gateway
AGENT_TALK_POSTGRES_URL=postgresql://... npm run test:postgres -w @agent-talk/gateway
npm run test:transport -w @agent-talk/gateway
```

The normal suite may use deterministic ledgers and protocol fakes. Changes to
SQL, transaction ordering, outbox/cursor convergence, credentials, Node
liveness, or multi-device control also require the opt-in real PostgreSQL gate.
Changes to stream authentication, framing, or service wiring require the real
loopback HTTP/2 gRPC gate. Use only an isolated disposable test database; never
point integration tests at user or production data.

Protocol changes start in the source proto and use the repository-root
generation and breaking-change checks; do not hand-edit generated bindings.
Keep untrusted payloads as `unknown` until validated, keep cancellation distinct
from failure, and never log tokens, signatures, confirmed text, Agent full-text
replies, or secret-bearing database values. Do not expose this Gateway, a Node,
or an Agent endpoint unauthenticated on a public network, and never implement
automatic approval or authorization decisions.
