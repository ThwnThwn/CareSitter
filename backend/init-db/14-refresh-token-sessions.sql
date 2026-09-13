-- Durable refresh-token sessions for existing databases.
-- Safe to run repeatedly; PostgreSQL remains authoritative and Redis is cache only.
SET search_path = identity, public;

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash     varchar(64) NOT NULL,
  device_id      varchar(255),
  device_info    varchar(500),
  issued_at      timestamptz NOT NULL DEFAULT now(),
  expires_at     timestamptz NOT NULL,
  revoked_at     timestamptz,
  replaced_by_id uuid REFERENCES refresh_tokens(id) ON DELETE SET NULL,
  ip_address     varchar(45),
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_refresh_tokens_hash
  ON refresh_tokens(token_hash);

CREATE INDEX IF NOT EXISTS ix_refresh_tokens_active_user
  ON refresh_tokens(user_id)
  WHERE revoked_at IS NULL;
