BEGIN;

ALTER TABLE people.caregiver_profiles
  ADD COLUMN IF NOT EXISTS cccd_front_url text,
  ADD COLUMN IF NOT EXISTS cccd_back_url text,
  ADD COLUMN IF NOT EXISTS certificate_urls jsonb DEFAULT '[]'::jsonb;

ALTER TABLE support.support_tickets
  ADD COLUMN IF NOT EXISTS title varchar(255),
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS attachment_urls jsonb NOT NULL DEFAULT '[]'::jsonb;

UPDATE support.support_tickets
SET title = COALESCE(title, 'Yeu cau ho tro'),
    description = COALESCE(description, 'Noi dung duoc tao truoc khi he thong ho tro mo ta chi tiet.');

ALTER TABLE support.support_tickets
  ALTER COLUMN title SET NOT NULL,
  ALTER COLUMN description SET NOT NULL;

COMMIT;
