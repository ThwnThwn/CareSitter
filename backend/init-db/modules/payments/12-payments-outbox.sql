-- Durable Payments integration-event outbox for existing databases.
CREATE TABLE IF NOT EXISTS payments.outbox_messages (
  id                  uuid PRIMARY KEY,
  type                varchar(500) NOT NULL,
  payload             jsonb NOT NULL,
  occurred_on_utc     timestamptz NOT NULL,
  processed_on_utc    timestamptz,
  error               text,
  attempt_count       int NOT NULL DEFAULT 0,
  next_attempt_on_utc timestamptz
);

CREATE INDEX IF NOT EXISTS ix_payments_outbox_pending
  ON payments.outbox_messages (processed_on_utc, next_attempt_on_utc)
  WHERE processed_on_utc IS NULL;
