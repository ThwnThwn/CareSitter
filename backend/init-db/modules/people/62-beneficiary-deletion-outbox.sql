-- A People-owned outbox row is committed with the beneficiary soft deletion.
BEGIN;
CREATE TABLE people.kafka_outbox_messages (
 id uuid PRIMARY KEY, event_type text NOT NULL, schema_version int NOT NULL CHECK (schema_version > 0),
 topic text NOT NULL, message_key text NOT NULL, envelope jsonb NOT NULL, correlation_id text,
 occurred_at timestamptz NOT NULL, published_at timestamptz, attempt_count int NOT NULL DEFAULT 0,
 next_attempt_at timestamptz NOT NULL DEFAULT now(), last_error text, lease_owner text, lease_until timestamptz,
 CHECK ((lease_owner IS NULL) = (lease_until IS NULL))
);
CREATE INDEX ix_kafka_outbox_pending ON people.kafka_outbox_messages
 (next_attempt_at, occurred_at) WHERE published_at IS NULL;
COMMIT;
