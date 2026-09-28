-- Keep the Identity EF model and clean-install schema aligned.
-- Existing installations may already store avatar URLs in media assets, so the
-- new user-level URL remains nullable and requires no destructive backfill.

BEGIN;

ALTER TABLE identity.users
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS notification_prefs jsonb;

COMMIT;
