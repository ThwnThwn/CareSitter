-- Chỉ thay đổi thích/không thích không khóa bữa còn lại của ca.
-- Không backfill từ hồ sơ hiện tại: bản chia sẻ cũ tiếp tục đối chiếu revision đến khi chia sẻ lại.
ALTER TABLE booking.booking_meal_plans ADD COLUMN IF NOT EXISTS health_fingerprint varchar(64);
