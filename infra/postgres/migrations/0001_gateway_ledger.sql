CREATE TABLE agent_talk.devices (
  device_id text PRIMARY KEY CHECK (device_id <> ''),
  display_name text NOT NULL,
  public_key_sha256 text NOT NULL CHECK (public_key_sha256 ~ '^[0-9a-f]{64}$'),
  status text NOT NULL CHECK (status IN ('active', 'revoked')),
  scopes text[] NOT NULL DEFAULT '{}',
  token_generation bigint NOT NULL DEFAULT 1 CHECK (token_generation > 0),
  paired_at timestamptz NOT NULL,
  revoked_at timestamptz,
  CHECK ((status = 'revoked') = (revoked_at IS NOT NULL))
);

CREATE TABLE agent_talk.nodes (
  node_id text PRIMARY KEY CHECK (node_id <> ''),
  display_name text NOT NULL,
  platform text NOT NULL,
  version text NOT NULL,
  status text NOT NULL CHECK (status IN ('online', 'offline', 'revoked')),
  last_seen_at timestamptz NOT NULL
);

CREATE TABLE agent_talk.agents (
  agent_id text PRIMARY KEY CHECK (agent_id <> ''),
  node_id text NOT NULL REFERENCES agent_talk.nodes(node_id),
  display_name text NOT NULL,
  adapter text NOT NULL,
  version text NOT NULL,
  status text NOT NULL CHECK (status IN ('online', 'offline', 'revoked')),
  capability_revision text NOT NULL CHECK (capability_revision <> ''),
  capabilities jsonb NOT NULL,
  max_request_bytes bigint CHECK (max_request_bytes > 0),
  UNIQUE (node_id, agent_id)
);

CREATE TABLE agent_talk.conversations (
  conversation_id text PRIMARY KEY CHECK (conversation_id <> ''),
  created_by_device_id text NOT NULL REFERENCES agent_talk.devices(device_id),
  last_sequence bigint NOT NULL DEFAULT 0 CHECK (last_sequence >= 0),
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE agent_talk.control_leases (
  conversation_id text PRIMARY KEY REFERENCES agent_talk.conversations(conversation_id) ON DELETE CASCADE,
  lease_id text NOT NULL UNIQUE CHECK (lease_id <> ''),
  device_id text NOT NULL REFERENCES agent_talk.devices(device_id),
  revision bigint NOT NULL CHECK (revision > 0),
  expires_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE agent_talk.requests (
  request_id text PRIMARY KEY CHECK (request_id <> ''),
  command_id text NOT NULL CHECK (command_id <> ''),
  idempotency_key text NOT NULL CHECK (idempotency_key <> ''),
  device_id text NOT NULL REFERENCES agent_talk.devices(device_id),
  accepted_connection_id text NOT NULL CHECK (accepted_connection_id <> ''),
  conversation_id text NOT NULL REFERENCES agent_talk.conversations(conversation_id),
  session_id text,
  node_id text NOT NULL,
  agent_id text NOT NULL,
  capability_revision text NOT NULL CHECK (capability_revision <> ''),
  confirmed_text text NOT NULL CHECK (confirmed_text <> ''),
  confirmed_text_sha256 text NOT NULL CHECK (confirmed_text_sha256 ~ '^[0-9a-f]{64}$'),
  state text NOT NULL CHECK (state IN ('accepted', 'working', 'completed', 'failed', 'cancelled', 'interrupted', 'uncertain')),
  accepted_sequence bigint NOT NULL CHECK (accepted_sequence > 0),
  accepted_at timestamptz NOT NULL,
  finalized_at timestamptz,
  failure_code text,
  UNIQUE (device_id, command_id),
  UNIQUE (device_id, idempotency_key),
  UNIQUE (conversation_id, accepted_sequence),
  FOREIGN KEY (node_id, agent_id) REFERENCES agent_talk.agents(node_id, agent_id)
);

CREATE INDEX requests_conversation_accepted_idx
  ON agent_talk.requests (conversation_id, accepted_sequence);

CREATE TABLE agent_talk.events (
  event_id text PRIMARY KEY CHECK (event_id <> ''),
  connection_id text NOT NULL CHECK (connection_id <> ''),
  device_id text NOT NULL REFERENCES agent_talk.devices(device_id),
  conversation_id text NOT NULL REFERENCES agent_talk.conversations(conversation_id),
  session_id text,
  request_id text REFERENCES agent_talk.requests(request_id),
  sequence bigint NOT NULL CHECK (sequence > 0),
  event_type text NOT NULL CHECK (event_type <> ''),
  safe_payload jsonb NOT NULL DEFAULT '{}',
  occurred_at timestamptz NOT NULL,
  UNIQUE (conversation_id, sequence)
);

CREATE INDEX events_request_sequence_idx
  ON agent_talk.events (request_id, sequence);

CREATE TABLE agent_talk.gateway_dispatch_outbox (
  outbox_id text PRIMARY KEY CHECK (outbox_id <> ''),
  request_id text NOT NULL REFERENCES agent_talk.requests(request_id),
  node_id text NOT NULL REFERENCES agent_talk.nodes(node_id),
  dispatch_kind text NOT NULL CHECK (dispatch_kind IN ('send', 'interrupt', 'approval', 'clarification')),
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'in_flight', 'delivered', 'dead')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  available_at timestamptz NOT NULL,
  locked_by text,
  locked_at timestamptz,
  delivered_at timestamptz,
  last_failure_code text,
  created_at timestamptz NOT NULL
);

CREATE INDEX gateway_dispatch_pending_idx
  ON agent_talk.gateway_dispatch_outbox (available_at, created_at)
  WHERE state = 'pending';

CREATE TABLE agent_talk.gateway_event_outbox (
  outbox_id text PRIMARY KEY CHECK (outbox_id <> ''),
  event_id text NOT NULL UNIQUE REFERENCES agent_talk.events(event_id),
  conversation_id text NOT NULL REFERENCES agent_talk.conversations(conversation_id),
  sequence bigint NOT NULL CHECK (sequence > 0),
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'in_flight', 'delivered', 'dead')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  available_at timestamptz NOT NULL,
  locked_by text,
  locked_at timestamptz,
  delivered_at timestamptz,
  last_failure_code text,
  created_at timestamptz NOT NULL,
  UNIQUE (conversation_id, sequence)
);

CREATE INDEX gateway_event_pending_idx
  ON agent_talk.gateway_event_outbox (available_at, created_at)
  WHERE state = 'pending';

CREATE TABLE agent_talk.device_cursors (
  device_id text NOT NULL REFERENCES agent_talk.devices(device_id),
  conversation_id text NOT NULL REFERENCES agent_talk.conversations(conversation_id) ON DELETE CASCADE,
  sequence bigint NOT NULL CHECK (sequence >= 0),
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (device_id, conversation_id)
);

CREATE TABLE agent_talk.approvals (
  approval_id text PRIMARY KEY CHECK (approval_id <> ''),
  request_id text NOT NULL REFERENCES agent_talk.requests(request_id),
  node_id text NOT NULL,
  agent_id text NOT NULL,
  native_approval_id text NOT NULL CHECK (native_approval_id <> ''),
  operation_summary_sha256 text NOT NULL CHECK (operation_summary_sha256 ~ '^[0-9a-f]{64}$'),
  safe_summary text NOT NULL,
  state text NOT NULL CHECK (state IN ('pending', 'approved', 'denied', 'expired', 'cancelled')),
  resolved_by_device_id text REFERENCES agent_talk.devices(device_id),
  resolution_idempotency_key text,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL,
  resolved_at timestamptz,
  UNIQUE (request_id, native_approval_id),
  FOREIGN KEY (node_id, agent_id) REFERENCES agent_talk.agents(node_id, agent_id)
);

CREATE UNIQUE INDEX approvals_resolution_idempotency_idx
  ON agent_talk.approvals (resolved_by_device_id, resolution_idempotency_key)
  WHERE resolution_idempotency_key IS NOT NULL;

CREATE TABLE agent_talk.security_audit_events (
  audit_id text PRIMARY KEY CHECK (audit_id <> ''),
  device_id text REFERENCES agent_talk.devices(device_id),
  action text NOT NULL CHECK (action <> ''),
  outcome text NOT NULL CHECK (outcome IN ('allowed', 'denied', 'expired', 'revoked')),
  target_type text NOT NULL CHECK (target_type <> ''),
  target_id_sha256 text NOT NULL CHECK (target_id_sha256 ~ '^[0-9a-f]{64}$'),
  safe_code text NOT NULL CHECK (safe_code <> ''),
  occurred_at timestamptz NOT NULL
);
