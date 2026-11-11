-- Mo hinh gia theo buoi va goi nhieu buoi cho ba chuong trinh CareSitter.
-- Khong dua gia goi vao pricing_rules.base_hourly_price de tranh nhan sai theo so gio.
BEGIN;

CREATE TABLE IF NOT EXISTS catalog.service_plans (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_type_id       uuid NOT NULL REFERENCES catalog.service_types(id),
  code                  varchar(100) NOT NULL,
  name                  varchar(255) NOT NULL,
  description           text,
  billing_unit          varchar(30) NOT NULL CHECK (billing_unit IN ('SESSION', 'SESSION_PACKAGE')),
  duration_minutes      int NOT NULL CHECK (duration_minutes BETWEEN 15 AND 1440),
  included_sessions     int NOT NULL CHECK (included_sessions > 0),
  total_price           bigint NOT NULL CHECK (total_price >= 0),
  validity_days         int CHECK (validity_days BETWEEN 1 AND 3650),
  platform_fee_percent  numeric(5,2) NOT NULL DEFAULT 15.00 CHECK (platform_fee_percent BETWEEN 0 AND 100),
  dispute_window_hours  int NOT NULL DEFAULT 48 CHECK (dispute_window_hours BETWEEN 1 AND 720),
  sort_order            int NOT NULL DEFAULT 0,
  effective_from        timestamptz NOT NULL DEFAULT now(),
  effective_to          timestamptz,
  is_active              boolean NOT NULL DEFAULT true,
  CONSTRAINT service_plans_unit_sessions_check CHECK (
    (billing_unit = 'SESSION' AND included_sessions = 1)
    OR (billing_unit = 'SESSION_PACKAGE' AND included_sessions >= 2 AND validity_days IS NOT NULL)
  ),
  CONSTRAINT service_plans_effective_window_check CHECK (
    effective_to IS NULL OR effective_to > effective_from
  ),
  CONSTRAINT ux_service_plans_service_code UNIQUE (service_type_id, code)
);

CREATE INDEX IF NOT EXISTS ix_service_plans_active
  ON catalog.service_plans(service_type_id, is_active, effective_from, sort_order);

-- Ba chuong trinh thay the bon dich vu demo tach le trong danh muc cong khai.
UPDATE catalog.service_types
SET is_active = false
WHERE code IN ('NONMED_COMPANION', 'NONMED_ESSENTIAL', 'NONMED_DAY', 'NONMED_NIGHT', 'TEST_DV');

UPDATE catalog.pricing_rules rule
SET is_active = false,
    effective_to = COALESCE(rule.effective_to, now())
FROM catalog.service_types service
WHERE rule.service_type_id = service.id
  AND service.code IN ('NONMED_COMPANION', 'NONMED_ESSENTIAL', 'NONMED_DAY', 'NONMED_NIGHT', 'TEST_DV')
  AND rule.is_active = true;

INSERT INTO catalog.service_types (
  id, code, name, description, default_duration_minutes, is_active, allow_ad_hoc_tasks
)
VALUES
  (
    'c0000000-0000-0000-0000-0000000000a1',
    'AN_NHIEN',
    'CareSitter An Nhiên',
    'Đồng hành, hỗ trợ sinh hoạt hằng ngày và chăm sóc cá nhân tại nhà.',
    480, true, false
  ),
  (
    'c0000000-0000-0000-0000-0000000000a2',
    'AN_KHANG',
    'CareSitter An Khang',
    'Chăm sóc toàn diện kết hợp điều dưỡng tại nhà theo kế hoạch chuyên môn.',
    480, true, false
  ),
  (
    'c0000000-0000-0000-0000-0000000000a3',
    'THAN_TRI',
    'CareSitter Thân Trí',
    'Phục hồi chức năng, hỗ trợ nhận thức và y học cổ truyền theo chỉ định phù hợp.',
    60, true, false
  )
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  default_duration_minutes = EXCLUDED.default_duration_minutes,
  is_active = EXCLUDED.is_active,
  allow_ad_hoc_tasks = EXCLUDED.allow_ad_hoc_tasks;

-- Gia booking don de luong dat lich hien tai van hoat dong. Day la gia mot ca
-- quy doi theo gio, khong phai gia cua goi nhieu buoi.
WITH booking_price_seed(service_code, id, name, base_hourly_price) AS (
  VALUES
    ('AN_NHIEN', 'e0000000-0000-0000-0000-0000000000a1'::uuid, 'Giá booking đơn An Nhiên', 100000::bigint),
    ('AN_KHANG', 'e0000000-0000-0000-0000-0000000000a2'::uuid, 'Giá booking đơn An Khang', 140000::bigint),
    ('THAN_TRI', 'e0000000-0000-0000-0000-0000000000a3'::uuid, 'Giá booking đơn Thân Trí từ', 320000::bigint)
)
INSERT INTO catalog.pricing_rules (
  id, name, service_type_id, base_hourly_price, night_multiplier,
  holiday_multiplier, platform_fee_percent, dispute_window_hours,
  effective_from, effective_to, is_active
)
SELECT booking_price_seed.id, booking_price_seed.name, service.id,
  booking_price_seed.base_hourly_price, 1.00, 1.50, 15.00, 48,
  '2026-10-01 00:00:00+07', NULL, true
FROM booking_price_seed
JOIN catalog.service_types service ON service.code = booking_price_seed.service_code
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  service_type_id = EXCLUDED.service_type_id,
  base_hourly_price = EXCLUDED.base_hourly_price,
  night_multiplier = EXCLUDED.night_multiplier,
  holiday_multiplier = EXCLUDED.holiday_multiplier,
  platform_fee_percent = EXCLUDED.platform_fee_percent,
  dispute_window_hours = EXCLUDED.dispute_window_hours,
  effective_from = EXCLUDED.effective_from,
  effective_to = EXCLUDED.effective_to,
  is_active = EXCLUDED.is_active;

WITH plan_seed(service_code, id, code, name, description, billing_unit, duration_minutes,
  included_sessions, total_price, validity_days, sort_order) AS (
  VALUES
    ('AN_NHIEN', 'd0000000-0000-0000-0000-000000000101'::uuid, 'AN_NHIEN_01', 'An Nhiên · 1 buổi', 'Một buổi chăm sóc 8 giờ.', 'SESSION', 480, 1, 800000, NULL, 1),
    ('AN_NHIEN', 'd0000000-0000-0000-0000-000000000108'::uuid, 'AN_NHIEN_08', 'An Nhiên · 8 buổi', 'Gói 8 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 8, 6000000, 30, 8),
    ('AN_NHIEN', 'd0000000-0000-0000-0000-000000000112'::uuid, 'AN_NHIEN_12', 'An Nhiên · 12 buổi', 'Gói 12 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 12, 8800000, 30, 12),
    ('AN_NHIEN', 'd0000000-0000-0000-0000-000000000116'::uuid, 'AN_NHIEN_16', 'An Nhiên · 16 buổi', 'Gói 16 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 16, 11500000, 30, 16),
    ('AN_NHIEN', 'd0000000-0000-0000-0000-000000000120'::uuid, 'AN_NHIEN_20', 'An Nhiên · 20 buổi', 'Gói 20 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 20, 14000000, 30, 20),
    ('AN_NHIEN', 'd0000000-0000-0000-0000-000000000124'::uuid, 'AN_NHIEN_24', 'An Nhiên · 24 buổi', 'Gói 24 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 24, 15500000, 30, 24),
    ('AN_NHIEN', 'd0000000-0000-0000-0000-000000000130'::uuid, 'AN_NHIEN_30', 'An Nhiên · 30 buổi', 'Gói 30 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 30, 16000000, 30, 30),

    ('AN_KHANG', 'd0000000-0000-0000-0000-000000000201'::uuid, 'AN_KHANG_01', 'An Khang · 1 buổi', 'Một buổi chăm sóc và điều dưỡng 8 giờ.', 'SESSION', 480, 1, 1120000, NULL, 1),
    ('AN_KHANG', 'd0000000-0000-0000-0000-000000000208'::uuid, 'AN_KHANG_08', 'An Khang · 8 buổi', 'Gói 8 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 8, 8400000, 30, 8),
    ('AN_KHANG', 'd0000000-0000-0000-0000-000000000212'::uuid, 'AN_KHANG_12', 'An Khang · 12 buổi', 'Gói 12 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 12, 12320000, 30, 12),
    ('AN_KHANG', 'd0000000-0000-0000-0000-000000000216'::uuid, 'AN_KHANG_16', 'An Khang · 16 buổi', 'Gói 16 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 16, 16100000, 30, 16),
    ('AN_KHANG', 'd0000000-0000-0000-0000-000000000220'::uuid, 'AN_KHANG_20', 'An Khang · 20 buổi', 'Gói 20 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 20, 19600000, 30, 20),
    ('AN_KHANG', 'd0000000-0000-0000-0000-000000000224'::uuid, 'AN_KHANG_24', 'An Khang · 24 buổi', 'Gói 24 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 24, 22680000, 30, 24),
    ('AN_KHANG', 'd0000000-0000-0000-0000-000000000230'::uuid, 'AN_KHANG_30', 'An Khang · 30 buổi', 'Gói 30 buổi, sử dụng trong 30 ngày.', 'SESSION_PACKAGE', 480, 30, 25480000, 30, 30),

    ('THAN_TRI', 'd0000000-0000-0000-0000-000000000301'::uuid, 'THAN_TRI_PHYSIO', 'Vật lý trị liệu tại nhà', 'Một buổi phục hồi chức năng 60 phút.', 'SESSION', 60, 1, 400000, NULL, 1),
    ('THAN_TRI', 'd0000000-0000-0000-0000-000000000302'::uuid, 'THAN_TRI_COGNITIVE', 'Hỗ trợ nhận thức chuyên sâu', 'Một buổi hoạt động nhận thức CST/Montessori 60 phút.', 'SESSION', 60, 1, 320000, NULL, 2),
    ('THAN_TRI', 'd0000000-0000-0000-0000-000000000303'::uuid, 'THAN_TRI_TCM', 'Châm cứu, bấm huyệt', 'Một buổi y học cổ truyền 60 phút sau sàng lọc chống chỉ định.', 'SESSION', 60, 1, 480000, NULL, 3)
)
INSERT INTO catalog.service_plans (
  id, service_type_id, code, name, description, billing_unit, duration_minutes,
  included_sessions, total_price, validity_days, platform_fee_percent,
  dispute_window_hours, sort_order, effective_from, effective_to, is_active
)
SELECT plan_seed.id, service.id, plan_seed.code, plan_seed.name, plan_seed.description,
  plan_seed.billing_unit, plan_seed.duration_minutes, plan_seed.included_sessions,
  plan_seed.total_price, plan_seed.validity_days, 15.00, 48, plan_seed.sort_order,
  '2026-10-01 00:00:00+07', NULL, true
FROM plan_seed
JOIN catalog.service_types service ON service.code = plan_seed.service_code
ON CONFLICT (service_type_id, code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  billing_unit = EXCLUDED.billing_unit,
  duration_minutes = EXCLUDED.duration_minutes,
  included_sessions = EXCLUDED.included_sessions,
  total_price = EXCLUDED.total_price,
  validity_days = EXCLUDED.validity_days,
  platform_fee_percent = EXCLUDED.platform_fee_percent,
  dispute_window_hours = EXCLUDED.dispute_window_hours,
  sort_order = EXCLUDED.sort_order,
  effective_from = EXCLUDED.effective_from,
  effective_to = EXCLUDED.effective_to,
  is_active = EXCLUDED.is_active;

-- Checklist là template cho từng ca; booking sẽ snapshot template hiện hành.
UPDATE booking.package_task_templates template
SET is_active = false
FROM catalog.service_types service
WHERE template.service_type_id = service.id
  AND service.code IN ('AN_NHIEN', 'AN_KHANG', 'THAN_TRI');

WITH task_seed(service_code, name, description, is_required, sort_order) AS (
  VALUES
    ('AN_NHIEN', 'Tiếp nhận và xác nhận kế hoạch trong buổi', 'Đọc lưu ý, xác nhận nhu cầu và các công việc đã thống nhất với gia đình.', true, 1),
    ('AN_NHIEN', 'Kiểm tra an toàn tại nhà', 'Kiểm tra lối đi, ánh sáng, vật cản và các nguy cơ té ngã dễ nhận biết.', true, 2),
    ('AN_NHIEN', 'Hỗ trợ vệ sinh và chăm sóc cá nhân', 'Hỗ trợ vệ sinh, thay đồ và chăm sóc cá nhân trong phạm vi đã thống nhất.', true, 3),
    ('AN_NHIEN', 'Hỗ trợ bữa ăn và nước uống', 'Chuẩn bị hoặc hỗ trợ dùng bữa theo hướng dẫn, ghi nhận lượng ăn uống quan sát được.', true, 4),
    ('AN_NHIEN', 'Hỗ trợ vận động và di chuyển', 'Hỗ trợ đi lại, thay đổi tư thế và vận động nhẹ phù hợp.', true, 5),
    ('AN_NHIEN', 'Đồng hành và hoạt động nhận thức nhẹ', 'Trò chuyện, đọc sách, chơi cờ hoặc hoạt động đã thống nhất.', true, 6),
    ('AN_NHIEN', 'Nhắc lịch dùng thuốc', 'Chỉ nhắc theo lịch gia đình cung cấp; không tự chia liều, đổi thuốc hoặc chỉ định.', false, 7),
    ('AN_NHIEN', 'Ghi nhật ký và bàn giao cuối buổi', 'Ghi nhận công việc, diễn biến đáng chú ý và bàn giao cho gia đình.', true, 8),

    ('AN_KHANG', 'Tiếp nhận hồ sơ và kế hoạch chăm sóc', 'Đối chiếu chỉ định, tiền sử, dị ứng và phạm vi chuyên môn của buổi chăm sóc.', true, 1),
    ('AN_KHANG', 'Đánh giá ban đầu và an toàn', 'Đánh giá tình trạng chung, nguy cơ té ngã và dấu hiệu cần báo bác sĩ hoặc gia đình.', true, 2),
    ('AN_KHANG', 'Theo dõi dấu hiệu sinh tồn', 'Đo và ghi nhận các chỉ số theo kế hoạch chuyên môn.', true, 3),
    ('AN_KHANG', 'Chăm sóc cá nhân và dinh dưỡng', 'Hỗ trợ vệ sinh, vận động, ăn uống và phòng ngừa biến chứng thường gặp.', true, 4),
    ('AN_KHANG', 'Thực hiện chăm sóc điều dưỡng được giao', 'Thực hiện kỹ thuật điều dưỡng trong phạm vi chứng chỉ và chỉ định hợp lệ.', true, 5),
    ('AN_KHANG', 'Hỗ trợ thuốc theo chỉ định', 'Thực hiện hoặc hỗ trợ đúng y lệnh; không tự thay đổi thuốc hoặc liều dùng.', true, 6),
    ('AN_KHANG', 'Kiểm soát nhiễm khuẩn và thu dọn', 'Vệ sinh tay, dụng cụ và xử lý vật tư theo quy định phù hợp.', true, 7),
    ('AN_KHANG', 'Ghi hồ sơ và bàn giao cuối buổi', 'Ghi nhận can thiệp, đáp ứng, bất thường và nội dung cần theo dõi tiếp.', true, 8),

    ('THAN_TRI', 'Đối chiếu chương trình chuyên môn', 'Xác nhận phương án Thân Trí, mục tiêu buổi và hướng dẫn chuyên môn hiện hành.', true, 1),
    ('THAN_TRI', 'Sàng lọc an toàn và chống chỉ định', 'Đánh giá nhanh điều kiện thực hiện; hoãn và báo người phụ trách khi không an toàn.', true, 2),
    ('THAN_TRI', 'Thực hiện nội dung chuyên môn đã chọn', 'Thực hiện vật lý trị liệu, hỗ trợ nhận thức hoặc y học cổ truyền theo phương án.', true, 3),
    ('THAN_TRI', 'Theo dõi đáp ứng trong buổi', 'Theo dõi đau, mệt, chóng mặt, nhận thức và các dấu hiệu bất thường.', true, 4),
    ('THAN_TRI', 'Hướng dẫn hoạt động tại nhà', 'Hướng dẫn bài tập hoặc hoạt động duy trì phù hợp cho người cao tuổi và gia đình.', false, 5),
    ('THAN_TRI', 'Ghi kết quả và bàn giao', 'Ghi nhận mức tham gia, đáp ứng và khuyến nghị theo dõi cho buổi tiếp theo.', true, 6)
)
INSERT INTO booking.package_task_templates (
  service_type_id, name, description, is_required, requires_photo, sort_order, is_active
)
SELECT service.id, task_seed.name, task_seed.description, task_seed.is_required,
  false, task_seed.sort_order, true
FROM task_seed
JOIN catalog.service_types service ON service.code = task_seed.service_code
ON CONFLICT (service_type_id, name) DO UPDATE SET
  description = EXCLUDED.description,
  is_required = EXCLUDED.is_required,
  requires_photo = EXCLUDED.requires_photo,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;

COMMIT;
