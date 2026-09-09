ALTER TABLE catalog.addresses
  ADD COLUMN IF NOT EXISTS place_id varchar(255),
  ADD COLUMN IF NOT EXISTS provider varchar(50),
  ADD COLUMN IF NOT EXISTS verified_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_addresses_place_id
  ON catalog.addresses (place_id)
  WHERE place_id IS NOT NULL;

-- Seed/demo addresses keep working, but user-created addresses should be
-- re-added through Geoapify so they receive a real provider place_id.
UPDATE catalog.addresses
SET provider = 'SEED',
    place_id = CONCAT('seed:', id::text),
    verified_at = COALESCE(verified_at, now())
WHERE place_id IS NULL
  AND owner_user_id = 'a0000000-0000-0000-0000-0000000000c1';
