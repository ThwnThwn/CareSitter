-- Mức giá booking lấy từ bảng pricing theo service type.
-- Xóa field giá mong muốn không được dùng trong thanh toán/matching.
ALTER TABLE IF EXISTS people.caregiver_profiles
    DROP COLUMN IF EXISTS hourly_rate_expected;
