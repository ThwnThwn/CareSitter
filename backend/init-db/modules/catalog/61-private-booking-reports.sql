-- Durable upload intent exists before any provider I/O. No provider URLs are public.
CREATE TABLE catalog.report_uploads (
    id uuid PRIMARY KEY,
    owner_user_id uuid NOT NULL REFERENCES identity.users(id),
    booking_id uuid NOT NULL REFERENCES booking.bookings(id),
    idempotency_key uuid NOT NULL,
    checksum varchar(64) NOT NULL CHECK (checksum ~ '^[a-f0-9]{64}$'),
    size_bytes bigint NOT NULL CHECK (size_bytes BETWEEN 16 AND 10485760),
    cloud_name varchar(255) NOT NULL,
    object_key text NOT NULL UNIQUE,
    status varchar(20) NOT NULL CHECK (status IN ('PENDING','COMPLETED')),
    lease_token uuid NOT NULL,
    lease_until timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    UNIQUE(owner_user_id, idempotency_key)
);
CREATE INDEX idx_report_uploads_owner_booking ON catalog.report_uploads(owner_user_id, booking_id, created_at DESC, id DESC);
