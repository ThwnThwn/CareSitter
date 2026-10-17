-- EF writes scalar coordinates; retain PostGIS geography for existing readers/indexes.
-- Additive upgrade, safe to re-run. No booking or timeline records are removed.
BEGIN;
ALTER TABLE booking.care_timeline_events
    ADD COLUMN IF NOT EXISTS latitude double precision,
    ADD COLUMN IF NOT EXISTS longitude double precision;
ALTER TABLE booking.gps_tracks
    ADD COLUMN IF NOT EXISTS latitude double precision,
    ADD COLUMN IF NOT EXISTS longitude double precision;

UPDATE booking.care_timeline_events
SET latitude = ST_Y(coordinates::geometry), longitude = ST_X(coordinates::geometry)
WHERE coordinates IS NOT NULL AND latitude IS NULL AND longitude IS NULL;
UPDATE booking.gps_tracks
SET latitude = ST_Y(location::geometry), longitude = ST_X(location::geometry)
WHERE location IS NOT NULL AND latitude IS NULL AND longitude IS NULL;

CREATE OR REPLACE FUNCTION booking.sync_timeline_coordinates()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.coordinates IS DISTINCT FROM OLD.coordinates
       AND NEW.latitude IS NOT DISTINCT FROM OLD.latitude
       AND NEW.longitude IS NOT DISTINCT FROM OLD.longitude THEN
        NEW.latitude := ST_Y(NEW.coordinates::geometry);
        NEW.longitude := ST_X(NEW.coordinates::geometry);
    ELSIF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        IF NEW.latitude NOT BETWEEN -90 AND 90 OR NEW.longitude NOT BETWEEN -180 AND 180 THEN
            RAISE EXCEPTION 'Invalid timeline coordinates' USING ERRCODE = '23514';
        END IF;
        NEW.coordinates := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    ELSIF NEW.latitude IS NULL AND NEW.longitude IS NULL THEN
        IF TG_OP = 'UPDATE' AND (OLD.latitude IS NOT NULL OR OLD.longitude IS NOT NULL) THEN
            NEW.coordinates := NULL;
        ELSE
            NEW.latitude := ST_Y(NEW.coordinates::geometry);
            NEW.longitude := ST_X(NEW.coordinates::geometry);
        END IF;
    ELSE
        RAISE EXCEPTION 'Latitude and longitude must be supplied together' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION booking.sync_gps_coordinates()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.location IS DISTINCT FROM OLD.location
       AND NEW.latitude IS NOT DISTINCT FROM OLD.latitude
       AND NEW.longitude IS NOT DISTINCT FROM OLD.longitude THEN
        NEW.latitude := ST_Y(NEW.location::geometry);
        NEW.longitude := ST_X(NEW.location::geometry);
    ELSIF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        IF NEW.latitude NOT BETWEEN -90 AND 90 OR NEW.longitude NOT BETWEEN -180 AND 180 THEN
            RAISE EXCEPTION 'Invalid GPS coordinates' USING ERRCODE = '23514';
        END IF;
        NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    ELSIF NEW.latitude IS NULL AND NEW.longitude IS NULL THEN
        NEW.latitude := ST_Y(NEW.location::geometry);
        NEW.longitude := ST_X(NEW.location::geometry);
    ELSE
        RAISE EXCEPTION 'Latitude and longitude must be supplied together' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_timeline_coordinates ON booking.care_timeline_events;
CREATE TRIGGER sync_timeline_coordinates
BEFORE INSERT OR UPDATE OF latitude, longitude, coordinates ON booking.care_timeline_events
FOR EACH ROW EXECUTE FUNCTION booking.sync_timeline_coordinates();

DROP TRIGGER IF EXISTS sync_gps_coordinates ON booking.gps_tracks;
CREATE TRIGGER sync_gps_coordinates
BEFORE INSERT OR UPDATE OF latitude, longitude, location ON booking.gps_tracks
FOR EACH ROW EXECUTE FUNCTION booking.sync_gps_coordinates();

COMMIT;
