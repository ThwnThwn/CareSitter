ALTER TABLE catalog.service_types
  ADD COLUMN IF NOT EXISTS image_url text;

ALTER TABLE catalog.service_types
  DROP CONSTRAINT IF EXISTS chk_service_types_image_url;

ALTER TABLE catalog.service_types
  ADD CONSTRAINT chk_service_types_image_url
  CHECK (
    image_url IS NULL OR
    (char_length(image_url) <= 2048 AND image_url ~ '^https?://')
  );
