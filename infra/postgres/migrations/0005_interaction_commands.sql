ALTER TABLE agent_talk.approvals
  ADD COLUMN required_scope text NOT NULL DEFAULT 'approve',
  ADD COLUMN resolution_decision text,
  ADD COLUMN resolution_command_id text;

ALTER TABLE agent_talk.approvals
  ADD CONSTRAINT approvals_resolution_facts_check
  CHECK (
    (
      state = 'pending'
      AND resolved_by_device_id IS NULL
      AND resolution_idempotency_key IS NULL
      AND resolution_decision IS NULL
      AND resolution_command_id IS NULL
      AND resolved_at IS NULL
    )
    OR
    (
      state IN ('approved', 'rejected')
      AND resolved_by_device_id IS NOT NULL
      AND resolution_idempotency_key IS NOT NULL
      AND resolution_decision = state
      AND resolution_command_id IS NOT NULL
      AND resolved_at IS NOT NULL
    )
    OR
    (
      state IN ('expired', 'cancelled')
      AND resolution_decision IS NULL
      AND resolution_command_id IS NULL
      AND resolved_at IS NOT NULL
    )
  );

CREATE TABLE agent_talk.clarifications (
  clarification_id text PRIMARY KEY CHECK (clarification_id <> ''),
  request_id text NOT NULL REFERENCES agent_talk.requests(request_id),
  node_id text NOT NULL,
  agent_id text NOT NULL,
  native_clarification_id text NOT NULL CHECK (native_clarification_id <> ''),
  safe_prompt text NOT NULL,
  state text NOT NULL CHECK (state IN ('pending', 'resolved', 'expired', 'cancelled')),
  resolved_by_device_id text REFERENCES agent_talk.devices(device_id),
  resolution_idempotency_key text,
  resolution_command_id text,
  confirmed_text text,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL,
  resolved_at timestamptz,
  UNIQUE (request_id, native_clarification_id),
  FOREIGN KEY (node_id, agent_id) REFERENCES agent_talk.agents(node_id, agent_id),
  CHECK (
    (
      state = 'pending'
      AND resolved_by_device_id IS NULL
      AND resolution_idempotency_key IS NULL
      AND resolution_command_id IS NULL
      AND confirmed_text IS NULL
      AND resolved_at IS NULL
    )
    OR
    (
      state = 'resolved'
      AND resolved_by_device_id IS NOT NULL
      AND resolution_idempotency_key IS NOT NULL
      AND resolution_command_id IS NOT NULL
      AND confirmed_text IS NOT NULL
      AND resolved_at IS NOT NULL
    )
    OR
    (
      state IN ('expired', 'cancelled')
      AND resolution_command_id IS NULL
      AND confirmed_text IS NULL
      AND resolved_at IS NOT NULL
    )
  )
);

CREATE UNIQUE INDEX clarifications_resolution_idempotency_idx
  ON agent_talk.clarifications (resolved_by_device_id, resolution_idempotency_key)
  WHERE resolution_idempotency_key IS NOT NULL;

CREATE TABLE agent_talk.control_commands (
  command_id text PRIMARY KEY CHECK (command_id <> ''),
  idempotency_key text NOT NULL CHECK (idempotency_key <> ''),
  device_id text NOT NULL REFERENCES agent_talk.devices(device_id),
  conversation_id text NOT NULL REFERENCES agent_talk.conversations(conversation_id),
  request_id text NOT NULL REFERENCES agent_talk.requests(request_id),
  command_kind text NOT NULL CHECK (command_kind IN ('interrupt', 'approval', 'clarification')),
  target_id text,
  payload_sha256 text NOT NULL CHECK (payload_sha256 ~ '^[0-9a-f]{64}$'),
  state text NOT NULL CHECK (state IN ('accepted', 'delivered', 'failed')),
  failure_stage text,
  failure_category text,
  failure_code text,
  failure_safe_message text,
  failure_retryable boolean,
  created_at timestamptz NOT NULL,
  delivered_at timestamptz,
  UNIQUE (device_id, idempotency_key),
  UNIQUE (device_id, command_id),
  CHECK (
    (state IN ('accepted', 'delivered') AND failure_code IS NULL)
    OR
    (
      state = 'failed'
      AND failure_stage IS NOT NULL
      AND failure_category IS NOT NULL
      AND failure_code IS NOT NULL
      AND failure_safe_message IS NOT NULL
      AND failure_retryable IS NOT NULL
    )
  )
);

CREATE UNIQUE INDEX control_commands_single_interrupt_idx
  ON agent_talk.control_commands (request_id)
  WHERE command_kind = 'interrupt';

ALTER TABLE agent_talk.gateway_dispatch_outbox
  ADD COLUMN control_command_id text REFERENCES agent_talk.control_commands(command_id);

ALTER TABLE agent_talk.gateway_dispatch_outbox
  ADD CONSTRAINT gateway_dispatch_command_binding_check
  CHECK (
    (dispatch_kind = 'send' AND control_command_id IS NULL)
    OR
    (dispatch_kind <> 'send' AND control_command_id IS NOT NULL)
  );
