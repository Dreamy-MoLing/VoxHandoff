ALTER TABLE agent_talk.conversations
  ADD COLUMN title text,
  ADD COLUMN node_id text,
  ADD COLUMN agent_id text,
  ADD COLUMN capability_revision text,
  ADD COLUMN session_id text,
  ADD COLUMN created_command_id text,
  ADD COLUMN created_idempotency_key text;

ALTER TABLE agent_talk.conversations
  ADD CONSTRAINT conversations_route_shape_check
  CHECK (
    (node_id IS NULL AND agent_id IS NULL AND capability_revision IS NULL)
    OR
    (node_id IS NOT NULL AND agent_id IS NOT NULL AND capability_revision IS NOT NULL)
  ),
  ADD CONSTRAINT conversations_title_check
  CHECK (title IS NULL OR (title <> '' AND octet_length(title) <= 256)),
  ADD CONSTRAINT conversations_agent_route_fkey
  FOREIGN KEY (node_id, agent_id) REFERENCES agent_talk.agents(node_id, agent_id);

CREATE UNIQUE INDEX conversations_created_command_idx
  ON agent_talk.conversations (created_by_device_id, created_command_id)
  WHERE created_command_id IS NOT NULL;

CREATE UNIQUE INDEX conversations_created_idempotency_idx
  ON agent_talk.conversations (created_by_device_id, created_idempotency_key)
  WHERE created_idempotency_key IS NOT NULL;
