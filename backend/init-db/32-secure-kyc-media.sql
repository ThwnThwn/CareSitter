-- Additive, replay-safe. Legacy URLs are deliberately NOT trusted/backfilled.
BEGIN;
ALTER TABLE catalog.media_assets
  ADD COLUMN IF NOT EXISTS delivery_type varchar(30),
  ADD COLUMN IF NOT EXISTS file_format varchar(10);
ALTER TABLE people.caregiver_profiles
  ADD COLUMN IF NOT EXISTS cccd_front_media_id uuid REFERENCES catalog.media_assets(id),
  ADD COLUMN IF NOT EXISTS cccd_back_media_id uuid REFERENCES catalog.media_assets(id),
  ADD COLUMN IF NOT EXISTS certificate_media_ids jsonb NOT NULL DEFAULT '[]'::jsonb;
COMMIT;
