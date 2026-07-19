CREATE TABLE agent_talk.device_refresh_history (
  credential_id text NOT NULL REFERENCES agent_talk.device_credentials(credential_id) ON DELETE CASCADE,
  refresh_token_sha256 text NOT NULL CHECK (refresh_token_sha256 ~ '^[0-9a-f]{64}$'),
  generation bigint NOT NULL CHECK (generation > 0),
  used_at timestamptz NOT NULL,
  PRIMARY KEY (credential_id, refresh_token_sha256),
  UNIQUE (refresh_token_sha256)
);

CREATE INDEX device_refresh_history_used_idx
  ON agent_talk.device_refresh_history (used_at);
