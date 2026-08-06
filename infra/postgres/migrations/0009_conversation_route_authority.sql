ALTER TABLE agent_talk.conversations
  ADD CONSTRAINT conversations_session_id_check
  CHECK (session_id IS NULL OR (session_id <> '' AND octet_length(session_id) <= 256));

CREATE UNIQUE INDEX conversations_agent_session_idx
  ON agent_talk.conversations (node_id, agent_id, capability_revision, session_id)
  WHERE session_id IS NOT NULL;
