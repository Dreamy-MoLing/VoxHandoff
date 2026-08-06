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
