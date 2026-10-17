-- Luu muc do cham soc va anh dai dien cua nguoi duoc cham soc.
-- Safe to run repeatedly on an existing database.

BEGIN;

ALTER TABLE people.beneficiaries
  ADD COLUMN IF NOT EXISTS care_level varchar(20),
  ADD COLUMN IF NOT EXISTS avatar_url text;

ALTER TABLE people.beneficiaries
  DROP CONSTRAINT IF EXISTS beneficiaries_care_level_check;

ALTER TABLE people.beneficiaries
  ADD CONSTRAINT beneficiaries_care_level_check
  CHECK (care_level IN ('Nhẹ', 'Trung bình', 'Nặng'));

COMMIT;
