-- ========================================================
-- 08-booking-sync.sql  |  Realtime delta-sync infrastructure
-- Chạy một lần sau 04-booking.sql đã tồn tại.
-- Idempotent: dùng ADD COLUMN IF NOT EXISTS và CREATE TABLE IF NOT EXISTS.
-- ========================================================

SET search_path = booking, public;

-- 1. Thêm sync_version vào bookings
--    Tăng mỗi khi booking đổi trạng thái / được mutation.
--    Bắt đầu tại 1 (0 = chưa bao giờ sync).
ALTER TABLE booking.bookings
  ADD COLUMN IF NOT EXISTS sync_version bigint NOT NULL DEFAULT 1;

-- 2. Bảng event log cho delta sync per-customer
--    cursor: IDENTITY tăng đơn điệu toàn bảng → dùng làm mốc "đã đọc đến đâu".
--    booking_version: snapshot sync_version tại thời điểm event để client skip event cũ.
CREATE TABLE IF NOT EXISTS booking.booking_sync_events (
  cursor          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id     uuid        NOT NULL,
  booking_id      uuid        NOT NULL REFERENCES booking.bookings(id) ON DELETE CASCADE,
  booking_version bigint      NOT NULL,
  event_type      varchar(50) NOT NULL,
  occurred_at     timestamptz NOT NULL DEFAULT now()
);

-- 3. Index cốt lõi: lookup delta kể từ cursor X của customer Y
CREATE INDEX IF NOT EXISTS ix_bse_customer_cursor
  ON booking.booking_sync_events (customer_id, cursor);

-- 4. Partial index: tìm cursor mới nhất của customer (dùng trong /bookings initial load)
CREATE INDEX IF NOT EXISTS ix_bse_customer_occurred
  ON booking.booking_sync_events (customer_id, occurred_at DESC);

-- ── Verify ──────────────────────────────────────────────────────────────────
DO $$
BEGIN
  ASSERT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'booking' AND table_name = 'bookings' AND column_name = 'sync_version'
  ), 'Column booking.bookings.sync_version missing';

  ASSERT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'booking' AND table_name = 'booking_sync_events'
  ), 'Table booking.booking_sync_events missing';

  RAISE NOTICE 'booking-sync migration OK';
END;
$$;
