ALTER TABLE agent_talk.nodes
  ADD COLUMN current_connection_id text;

ALTER TABLE agent_talk.events
  ADD COLUMN source_sequence bigint CHECK (source_sequence > 0);

CREATE UNIQUE INDEX events_request_source_sequence_idx
  ON agent_talk.events (request_id, source_sequence)
  WHERE source_sequence IS NOT NULL;

ALTER TABLE agent_talk.gateway_dispatch_outbox
  ADD COLUMN ack_accepted boolean,
  ADD COLUMN failure_stage text,
  ADD COLUMN failure_category text,
  ADD COLUMN failure_safe_message text,
  ADD COLUMN failure_retryable boolean;

ALTER TABLE agent_talk.gateway_dispatch_outbox
  ADD CONSTRAINT gateway_dispatch_ack_facts_check
  CHECK (
    (
      state IN ('pending', 'in_flight')
      AND ack_accepted IS NULL
      AND failure_stage IS NULL
      AND failure_category IS NULL
      AND failure_safe_message IS NULL
      AND failure_retryable IS NULL
    )
    OR
    (
      state = 'delivered'
      AND ack_accepted = true
      AND last_failure_code IS NULL
      AND failure_stage IS NULL
      AND failure_category IS NULL
      AND failure_safe_message IS NULL
      AND failure_retryable IS NULL
    )
    OR
    (
      state = 'dead'
      AND ack_accepted = false
      AND last_failure_code IS NOT NULL
      AND failure_stage IS NOT NULL
      AND failure_category IS NOT NULL
      AND failure_safe_message IS NOT NULL
      AND failure_retryable IS NOT NULL
    )
  );
