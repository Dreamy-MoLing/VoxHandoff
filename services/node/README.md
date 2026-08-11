# VoxHandoff Hermes Node Connector

This service is the production protocol boundary between an authenticated
VoxHandoff Gateway Node stream and one Hermes API endpoint. It does not expose
Hermes directly to Flutter or to a public network.

Build and start it from the repository root:

```bash
npm run build -w @agent-talk/node
VOXHANDOFF_GATEWAY_URL=https://gateway.example \
VOXHANDOFF_GATEWAY_NODE_TOKEN=<node credential> \
VOXHANDOFF_HERMES_URL=https://hermes.example \
VOXHANDOFF_HERMES_TOKEN=<Hermes API token> \
VOXHANDOFF_HERMES_APPROVAL_TIMEOUT_SECONDS=60 \
VOXHANDOFF_NODE_ID=<opaque paired Node id> \
VOXHANDOFF_HERMES_AGENT_ID=<opaque Agent id> \
VOXHANDOFF_NODE_STATE_FILE=/absolute/private/path/hermes-sessions.json \
npm run start -w @agent-talk/node
```

Secrets are accepted only through explicit environment variables. URLs
containing userinfo are rejected. HTTPS is mandatory unless both endpoints are
literal loopback and `VOXHANDOFF_ALLOW_INSECURE_LOOPBACK=1` is explicitly set
for isolated development. A private CA should be installed in the process trust
store (for example through the platform trust store or `NODE_EXTRA_CA_CERTS`);
certificate verification is never disabled.

`VOXHANDOFF_HERMES_APPROVAL_TIMEOUT_SECONDS` must exactly match the isolated
Hermes profile's `approvals.timeout`. Hermes must use
`approvals.mode: manual`; smart and off modes are unsupported because they can
make a tool decision without the explicitly authorized VoxHandoff device.

The persisted state file contains only opaque conversation-to-Hermes-session
identities and is written with mode `0600` under a `0700` directory. It never
contains Gateway or Hermes tokens, confirmed text, replies, approval summaries,
or audio.

The Connector refuses to register Hermes unless the capability endpoint
explicitly advertises an event stream and idempotent run submission. Missing
capabilities stay disabled. If Hermes run acceptance is uncertain, the
Connector emits a visible connection fact and does not call `startRun` again.
When Hermes explicitly advertises replay, sequence recovery, and stable event
IDs, an interrupted SSE stream is resumed from its last native cursor with
bounded retries; only the stream is reopened, never the run submission.
Approval and stop actions use the exact Gateway idempotency key and never run
without an explicit dispatch.

## Gateway stream lifecycle

The production transport retains a finite `defaultTimeoutMs` for any future
short RPC, but the long-lived `ConnectNode` call explicitly uses `timeoutMs: 0`.
HTTP/2 pings and application heartbeats are liveness signals; they do not reset
an RPC deadline.

An unexpected retryable Gateway transport close is supervised with bounded
backoff. The Connector keeps an accepted Hermes run and its stable event
identity, waits for the replacement stream to finish its handshake and Node
registration, and then continues forwarding frames. It never calls `startRun`
again merely because the Gateway stream disconnected. A completed dispatch
keeps its exact acceptance or rejection acknowledgement in memory so a
redelivered Gateway outbox entry can be acknowledged after that reconnect.

Protocol 1.1 adds `NodeEventReceipt`: Gateway sends it only after its Node
ledger durably accepts the exact event. The Connector retains at most 256
in-memory event frames, replays them in order after registration, and removes
one only after its matching receipt; a terminal Hermes run remains present
until that receipt. Output epochs prevent an event created during the
disconnect/handshake window from being enqueued twice. This protects a
transport reconnect inside the same Node process only. The retry journal is
not persisted and does not promise process-crash recovery. Protocol 1.0 is a
rolling-upgrade fallback with its historical enqueue-only semantics: it has no
receipt and therefore no lossless reconnect guarantee.

`SIGINT` and `SIGTERM` are explicit shutdown: they cancel active runs and do
not start another connection attempt.

Run the explicit socket gate after the normal Node tests:

```bash
AGENT_TALK_LOOPBACK_INTEGRATION=1 npm run test:transport
```
