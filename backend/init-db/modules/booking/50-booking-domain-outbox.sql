-- Durable delivery for Booking aggregate domain events.
CREATE TABLE IF NOT EXISTS booking.booking_domain_outbox (
    event_id uuid PRIMARY KEY,
    booking_id uuid NOT NULL REFERENCES booking.bookings(id) ON DELETE CASCADE,
    booking_version bigint NOT NULL,
    event_type varchar(100) NOT NULL,
    payload jsonb NOT NULL,
    occurred_at timestamptz NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING','PROCESSING','FAILED','PROCESSED','DEAD_LETTER')),
    attempts int NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    available_at timestamptz NOT NULL,
    lease_until timestamptz,
    claim_token uuid,
    last_error varchar(500),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    processed_at timestamptz
);

CREATE INDEX IF NOT EXISTS ix_booking_domain_outbox_dispatch
    ON booking.booking_domain_outbox (status, available_at, occurred_at);

CREATE INDEX IF NOT EXISTS ix_booking_domain_outbox_booking
    ON booking.booking_domain_outbox (booking_id, occurred_at);
