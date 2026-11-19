ALTER TABLE booking.bookings ADD COLUMN IF NOT EXISTS status_before_dispute text;

-- Recover the precise prior state for disputes opened before this column existed.
UPDATE booking.bookings b
SET status_before_dispute = e.prior
FROM (
    SELECT DISTINCT ON (booking_id) booking_id, payload->>'From' AS prior
    FROM booking.booking_domain_outbox
    WHERE event_type = 'BookingStatusChanged' AND payload->>'To' = 'Disputed'
    ORDER BY booking_id, booking_version DESC, occurred_at DESC
) e
WHERE b.id = e.booking_id AND lower(b.status::text) = 'disputed' AND b.status_before_dispute IS NULL;
