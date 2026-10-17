-- Snapshot quyen them task phat sinh theo goi. Chay sau 17 tren database dang ton tai.
BEGIN;

ALTER TABLE catalog.service_types
  ADD COLUMN IF NOT EXISTS allow_ad_hoc_tasks boolean NOT NULL DEFAULT false;

ALTER TABLE booking.bookings
  ADD COLUMN IF NOT EXISTS allow_ad_hoc_tasks boolean NOT NULL DEFAULT false;

-- Gia tri mac dinh false: cac goi chuan giu dung scope da ban.
-- Admin se bat true cho tung goi linh hoat qua man hinh cau hinh o phase sau.
COMMIT;
