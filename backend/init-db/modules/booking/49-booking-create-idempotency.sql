-- Persistent idempotency ledger for POST /api/v1/bookings.
-- Rows follow the booking lifetime and are deleted with their booking.
CREATE TABLE IF NOT EXISTS booking.booking_creation_requests (
    customer_id uuid NOT NULL,
    idempotency_key uuid NOT NULL,
    payload_hash varchar(64) NOT NULL,
    booking_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_booking_creation_requests
        PRIMARY KEY (customer_id, idempotency_key),
    CONSTRAINT uq_booking_creation_request_booking UNIQUE (booking_id),
    CONSTRAINT ck_booking_creation_request_payload_hash
        CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT fk_booking_creation_request_booking
        FOREIGN KEY (booking_id) REFERENCES booking.bookings(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_booking_creation_requests_created_at
    ON booking.booking_creation_requests (created_at);
