-- Kafka delivery state is separate from the existing Payments MediatR outbox.
-- Keep this migration additive; production runs numbered SQL through deploy/migrate.sh.
BEGIN;
DO $migration$
DECLARE module_schema text;
BEGIN
    FOREACH module_schema IN ARRAY ARRAY['support', 'payments'] LOOP
        EXECUTE format('CREATE TABLE IF NOT EXISTS %I.kafka_outbox_messages (
            id uuid PRIMARY KEY, event_type text NOT NULL, schema_version int NOT NULL CHECK (schema_version > 0),
            topic text NOT NULL, message_key text NOT NULL, envelope jsonb NOT NULL, correlation_id text,
            occurred_at timestamptz NOT NULL, published_at timestamptz, attempt_count int NOT NULL DEFAULT 0,
            next_attempt_at timestamptz NOT NULL DEFAULT now(), last_error text, lease_owner text, lease_until timestamptz,
            CHECK ((lease_owner IS NULL) = (lease_until IS NULL)))', module_schema);
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_kafka_outbox_pending ON %I.kafka_outbox_messages
            (next_attempt_at, occurred_at) WHERE published_at IS NULL', module_schema);
        EXECUTE format('CREATE TABLE IF NOT EXISTS %I.kafka_inbox_messages (
            consumer_name text NOT NULL, handler_name text NOT NULL, event_id uuid NOT NULL, event_type text NOT NULL,
            processed_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (consumer_name, handler_name, event_id))', module_schema);
    END LOOP;
END $migration$;
CREATE TABLE IF NOT EXISTS support.notification_deliveries (
    event_id uuid NOT NULL, channel text NOT NULL CHECK (channel IN ('push', 'email')),
    notification_id uuid NOT NULL REFERENCES support.notifications(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Sending', 'Sent', 'Failed')),
    claim_token uuid, lease_until timestamptz, sent_at timestamptz, last_error text,
    PRIMARY KEY (event_id, channel), CHECK ((claim_token IS NULL) = (lease_until IS NULL))
);
COMMIT;
