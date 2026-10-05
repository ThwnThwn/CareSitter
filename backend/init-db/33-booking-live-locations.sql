BEGIN;

-- A server-wide sequence keeps REST/events ordered even after expiry/recreation.
CREATE SEQUENCE IF NOT EXISTS booking.live_location_version_seq AS bigint;
CREATE TABLE IF NOT EXISTS booking.live_locations (
    booking_id uuid PRIMARY KEY REFERENCES booking.bookings(id) ON DELETE CASCADE,
    caregiver_id uuid NOT NULL,
    tracking_session_id uuid NOT NULL,
    source_instance_id uuid NOT NULL,
    location_version bigint NOT NULL DEFAULT nextval('booking.live_location_version_seq'),
    latitude double precision,
    longitude double precision,
    accuracy_meters double precision,
    speed_mps double precision,
    heading_degrees double precision,
    captured_at timestamptz,
    received_at timestamptz,
    session_lease_until timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    CONSTRAINT ck_live_version CHECK (location_version > 0),
    CONSTRAINT ck_live_coordinates CHECK ((latitude IS NULL) = (longitude IS NULL)),
    CONSTRAINT ck_live_lat CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT ck_live_lng CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT ck_live_accuracy CHECK (accuracy_meters >= 0 AND accuracy_meters < 'Infinity'::float8),
    CONSTRAINT ck_live_speed CHECK (speed_mps >= 0 AND speed_mps < 'Infinity'::float8),
    CONSTRAINT ck_live_heading CHECK (heading_degrees >= 0 AND heading_degrees < 360),
    CONSTRAINT ck_live_fix_times CHECK (
        (latitude IS NULL AND captured_at IS NULL AND received_at IS NULL)
        OR (latitude IS NOT NULL AND captured_at IS NOT NULL AND received_at IS NOT NULL))
) WITH (fillfactor = 70, autovacuum_vacuum_scale_factor = 0.05,
        autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1);

CREATE OR REPLACE FUNCTION booking.delete_live_location_on_booking_change()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM booking.live_locations WHERE booking_id = NEW.id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS delete_live_location_on_booking_change ON booking.bookings;
CREATE TRIGGER delete_live_location_on_booking_change
AFTER UPDATE OF status, caregiver_id ON booking.bookings
FOR EACH ROW WHEN (
    (NEW.status IS DISTINCT FROM OLD.status AND upper(NEW.status) IN ('COMPLETED', 'CANCELLED', 'REFUNDED'))
    OR NEW.caregiver_id IS DISTINCT FROM OLD.caregiver_id)
EXECUTE FUNCTION booking.delete_live_location_on_booking_change();

COMMIT;
