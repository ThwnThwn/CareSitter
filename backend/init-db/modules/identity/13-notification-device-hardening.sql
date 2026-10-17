-- A physical FCM registration token must belong to only one CareSitter user.
-- Keep the most recently active row when upgrading an existing database.
WITH ranked_tokens AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY push_token
           ORDER BY last_seen_at DESC NULLS LAST, created_at DESC, id DESC
         ) AS token_rank
  FROM identity.user_devices
  WHERE push_token IS NOT NULL
)
UPDATE identity.user_devices AS device
SET push_token = NULL
FROM ranked_tokens AS ranked
WHERE device.id = ranked.id
  AND ranked.token_rank > 1;

CREATE UNIQUE INDEX IF NOT EXISTS ux_user_devices_push_token
  ON identity.user_devices(push_token)
  WHERE push_token IS NOT NULL;
