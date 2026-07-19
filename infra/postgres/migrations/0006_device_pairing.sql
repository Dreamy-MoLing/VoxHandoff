CREATE TABLE agent_talk.pairing_rate_limits (
  rate_key_sha256 text PRIMARY KEY CHECK (rate_key_sha256 ~ '^[0-9a-f]{64}$'),
  window_started_at timestamptz NOT NULL,
  attempt_count integer NOT NULL CHECK (attempt_count > 0),
  updated_at timestamptz NOT NULL
);

CREATE TABLE agent_talk.pairings (
  pairing_id text PRIMARY KEY CHECK (pairing_id <> ''),
  user_code_sha256 text NOT NULL UNIQUE CHECK (user_code_sha256 ~ '^[0-9a-f]{64}$'),
  device_display_name text NOT NULL CHECK (device_display_name <> ''),
  device_public_key_spki bytea NOT NULL CHECK (octet_length(device_public_key_spki) BETWEEN 1 AND 512),
  device_public_key_sha256 text NOT NULL CHECK (device_public_key_sha256 ~ '^[0-9a-f]{64}$'),
  device_fingerprint text NOT NULL CHECK (device_fingerprint ~ '^sha256:[0-9a-f]{64}$'),
  gateway_fingerprint text NOT NULL CHECK (gateway_fingerprint ~ '^sha256:[0-9a-f]{64}$'),
  gateway_audience text NOT NULL CHECK (gateway_audience <> ''),
  requested_scopes text[] NOT NULL CHECK (
    cardinality(requested_scopes) BETWEEN 1 AND 5
    AND requested_scopes <@ ARRAY['observe', 'send', 'interrupt', 'approve', 'administer']::text[]
  ),
  approved_scopes text[] CHECK (
    approved_scopes IS NULL OR (
      cardinality(approved_scopes) BETWEEN 1 AND 5
      AND approved_scopes <@ requested_scopes
    )
  ),
  administrator_proof_sha256 text CHECK (
    administrator_proof_sha256 IS NULL OR administrator_proof_sha256 ~ '^[0-9a-f]{64}$'
  ),
  device_proof_payload bytea NOT NULL CHECK (octet_length(device_proof_payload) > 0),
  device_proof_sha256 text CHECK (device_proof_sha256 IS NULL OR device_proof_sha256 ~ '^[0-9a-f]{64}$'),
  device_id text,
  credential_id text,
  confirmation_payload bytea,
  state text NOT NULL CHECK (
    state IN ('pending_owner', 'approved', 'proof_verified', 'confirmed', 'expired', 'rejected')
  ),
  expires_at timestamptz NOT NULL,
  confirmation_expires_at timestamptz,
  approved_by_device_id text REFERENCES agent_talk.devices(device_id),
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  CHECK (expires_at > created_at),
  CHECK ((approved_scopes IS NULL) = (approved_by_device_id IS NULL)),
  CHECK ((administrator_proof_sha256 IS NULL) = (approved_by_device_id IS NULL)),
  CHECK (
    (state = 'pending_owner' AND approved_scopes IS NULL AND device_id IS NULL AND credential_id IS NULL)
    OR (state = 'approved' AND approved_scopes IS NOT NULL AND device_id IS NULL AND credential_id IS NULL)
    OR (state IN ('proof_verified', 'confirmed') AND approved_scopes IS NOT NULL
        AND device_proof_sha256 IS NOT NULL AND device_id IS NOT NULL AND credential_id IS NOT NULL
        AND confirmation_payload IS NOT NULL AND confirmation_expires_at IS NOT NULL)
    OR state IN ('expired', 'rejected')
  )
);

CREATE TABLE agent_talk.device_credentials (
  credential_id text PRIMARY KEY CHECK (credential_id <> ''),
  pairing_id text UNIQUE REFERENCES agent_talk.pairings(pairing_id) ON DELETE CASCADE,
  origin text NOT NULL CHECK (origin IN ('pairing', 'owner_bootstrap')),
  device_id text NOT NULL CHECK (device_id <> ''),
  state text NOT NULL CHECK (state IN ('pending_confirmation', 'active', 'revoked')),
  public_key_spki bytea NOT NULL CHECK (octet_length(public_key_spki) BETWEEN 1 AND 512),
  public_key_sha256 text NOT NULL CHECK (public_key_sha256 ~ '^[0-9a-f]{64}$'),
  gateway_audience text NOT NULL CHECK (gateway_audience <> ''),
  scopes text[] NOT NULL CHECK (
    cardinality(scopes) BETWEEN 1 AND 5
    AND scopes <@ ARRAY['observe', 'send', 'interrupt', 'approve', 'administer']::text[]
  ),
  generation bigint NOT NULL DEFAULT 1 CHECK (generation > 0),
  access_token_sha256 text CHECK (access_token_sha256 IS NULL OR access_token_sha256 ~ '^[0-9a-f]{64}$'),
  access_expires_at timestamptz,
  refresh_token_sha256 text CHECK (refresh_token_sha256 IS NULL OR refresh_token_sha256 ~ '^[0-9a-f]{64}$'),
  refresh_expires_at timestamptz NOT NULL,
  family_expires_at timestamptz NOT NULL,
  confirmation_payload bytea NOT NULL CHECK (octet_length(confirmation_payload) > 0),
  confirmation_expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL,
  activated_at timestamptz,
  revoked_at timestamptz,
  CHECK ((origin = 'pairing') = (pairing_id IS NOT NULL)),
  CHECK (refresh_expires_at <= family_expires_at),
  CHECK (confirmation_expires_at <= family_expires_at),
  CHECK ((access_token_sha256 IS NULL) = (access_expires_at IS NULL)),
  CHECK (
    (state = 'pending_confirmation' AND activated_at IS NULL AND revoked_at IS NULL
      AND access_token_sha256 IS NULL AND refresh_token_sha256 IS NULL)
    OR (state = 'active' AND activated_at IS NOT NULL AND revoked_at IS NULL
      AND access_token_sha256 IS NOT NULL AND refresh_token_sha256 IS NOT NULL)
    OR (state = 'revoked' AND revoked_at IS NOT NULL
      AND access_token_sha256 IS NULL AND access_expires_at IS NULL AND refresh_token_sha256 IS NULL)
  )
);

ALTER TABLE agent_talk.pairings
  ADD CONSTRAINT pairings_credential_fk
  FOREIGN KEY (credential_id) REFERENCES agent_talk.device_credentials(credential_id)
  DEFERRABLE INITIALLY DEFERRED;

CREATE UNIQUE INDEX device_credentials_access_token_idx
  ON agent_talk.device_credentials (access_token_sha256)
  WHERE access_token_sha256 IS NOT NULL;

CREATE UNIQUE INDEX device_credentials_refresh_token_idx
  ON agent_talk.device_credentials (refresh_token_sha256)
  WHERE refresh_token_sha256 IS NOT NULL;

CREATE TABLE agent_talk.device_signature_nonces (
  credential_id text NOT NULL REFERENCES agent_talk.device_credentials(credential_id) ON DELETE CASCADE,
  purpose text NOT NULL CHECK (purpose <> ''),
  nonce_sha256 text NOT NULL CHECK (nonce_sha256 ~ '^[0-9a-f]{64}$'),
  used_at timestamptz NOT NULL,
  PRIMARY KEY (credential_id, purpose, nonce_sha256)
);

CREATE INDEX device_signature_nonces_used_idx
  ON agent_talk.device_signature_nonces (used_at);
