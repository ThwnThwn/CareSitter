-- Catalog phi y te cho luong dat lich demo.
-- Giu lai cac goi Genki cu o trang thai ngung hoat dong de bao toan lich su booking.
BEGIN;

UPDATE catalog.service_types
SET is_active = false
WHERE code IN (
  'GENKI_DUONG',
  'GENKI_AN',
  'GENKI_TAM',
  'GENKI_PHUCHOI',
  'GENKI_DONGHANH',
  'GENKI_DEM'
);

UPDATE catalog.pricing_rules
SET is_active = false,
    effective_to = COALESCE(effective_to, now())
WHERE service_type_id IN (
  SELECT id
  FROM catalog.service_types
  WHERE code IN (
    'GENKI_DUONG',
    'GENKI_AN',
    'GENKI_TAM',
    'GENKI_PHUCHOI',
    'GENKI_DONGHANH',
    'GENKI_DEM'
  )
)
  AND is_active = true;

INSERT INTO catalog.service_types (
  id,
  code,
  name,
  description,
  default_duration_minutes,
  is_active,
  allow_ad_hoc_tasks
)
VALUES
  (
    'b0000000-0000-0000-0000-0000000000f1',
    'NONMED_ESSENTIAL',
    'Hỗ trợ thiết yếu',
    'Hỗ trợ vệ sinh cá nhân, thay đồ, chuẩn bị bữa ăn hoặc đồ uống theo hướng dẫn của gia đình và nhắc lịch để người được chăm sóc tự thực hiện. Không thực hiện thủ thuật y tế.',
    120,
    true,
    false
  ),
  (
    'b0000000-0000-0000-0000-0000000000f2',
    'NONMED_COMPANION',
    'Đồng hành linh hoạt',
    'Trò chuyện, đọc sách, tản bộ, đi chợ hoặc đồng hành đến cuộc hẹn; hỗ trợ di chuyển và việc nhà nhẹ. Không tư vấn hoặc chăm sóc y tế.',
    240,
    true,
    false
  ),
  (
    'b0000000-0000-0000-0000-0000000000f3',
    'NONMED_DAY',
    'Chăm sóc ban ngày',
    'Hỗ trợ sinh hoạt trong ngày, bữa ăn, vận động nhẹ theo khả năng, giữ không gian an toàn và cập nhật cho gia đình. Không theo dõi hoặc xử trí y tế.',
    480,
    true,
    false
  ),
  (
    'b0000000-0000-0000-0000-0000000000f4',
    'NONMED_NIGHT',
    'Hỗ trợ ban đêm',
    'Túc trực ban đêm, hỗ trợ đi vệ sinh và di chuyển an toàn, nhắc lịch do gia đình cung cấp. Khi có dấu hiệu bất thường, caregiver liên hệ người thân hoặc cấp cứu và không tự xử trí y tế.',
    480,
    true,
    false
  )
ON CONFLICT (id) DO UPDATE SET
  code = EXCLUDED.code,
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  default_duration_minutes = EXCLUDED.default_duration_minutes,
  is_active = EXCLUDED.is_active,
  allow_ad_hoc_tasks = EXCLUDED.allow_ad_hoc_tasks;

INSERT INTO catalog.pricing_rules (
  id,
  name,
  service_type_id,
  base_hourly_price,
  night_multiplier,
  holiday_multiplier,
  platform_fee_percent,
  dispute_window_hours,
  is_active
)
VALUES
  (
    'b0000000-0000-0000-0000-0000000000d1',
    'Giá Hỗ trợ thiết yếu',
    'b0000000-0000-0000-0000-0000000000f1',
    90000,
    1.20,
    1.50,
    15.00,
    48,
    true
  ),
  (
    'b0000000-0000-0000-0000-0000000000d2',
    'Giá Đồng hành linh hoạt',
    'b0000000-0000-0000-0000-0000000000f2',
    80000,
    1.20,
    1.50,
    15.00,
    48,
    true
  ),
  (
    'b0000000-0000-0000-0000-0000000000d3',
    'Giá Chăm sóc ban ngày',
    'b0000000-0000-0000-0000-0000000000f3',
    70000,
    1.20,
    1.50,
    15.00,
    48,
    true
  ),
  (
    'b0000000-0000-0000-0000-0000000000d4',
    'Giá Hỗ trợ ban đêm',
    'b0000000-0000-0000-0000-0000000000f4',
    85000,
    1.00,
    1.50,
    15.00,
    48,
    true
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  service_type_id = EXCLUDED.service_type_id,
  base_hourly_price = EXCLUDED.base_hourly_price,
  night_multiplier = EXCLUDED.night_multiplier,
  holiday_multiplier = EXCLUDED.holiday_multiplier,
  platform_fee_percent = EXCLUDED.platform_fee_percent,
  dispute_window_hours = EXCLUDED.dispute_window_hours,
  effective_to = NULL,
  is_active = EXCLUDED.is_active;

WITH templates(service_code, name, description, is_required, sort_order) AS (
  VALUES
    ('NONMED_ESSENTIAL', 'Xác nhận ghi chú chăm sóc', 'Đọc lại phạm vi hỗ trợ và các lưu ý do gia đình cung cấp trước khi bắt đầu.', true, 1),
    ('NONMED_ESSENTIAL', 'Hỗ trợ vệ sinh và thay đồ', 'Hỗ trợ các hoạt động sinh hoạt cá nhân trong phạm vi đã thống nhất.', true, 2),
    ('NONMED_ESSENTIAL', 'Chuẩn bị bữa ăn hoặc đồ uống', 'Chuẩn bị theo nguyên liệu và hướng dẫn do gia đình cung cấp.', true, 3),
    ('NONMED_ESSENTIAL', 'Nhắc lịch sinh hoạt', 'Nhắc lịch do gia đình cung cấp; người được chăm sóc tự thực hiện việc dùng thuốc.', true, 4),
    ('NONMED_ESSENTIAL', 'Bàn giao cuối ca', 'Ghi nhận các việc đã hoàn thành và cập nhật cho gia đình.', true, 5),

    ('NONMED_COMPANION', 'Xác nhận kế hoạch đồng hành', 'Thống nhất điểm đến, cách di chuyển và thông tin liên hệ với gia đình.', true, 1),
    ('NONMED_COMPANION', 'Trò chuyện hoặc hoạt động tinh thần', 'Đọc sách, trò chuyện hoặc tham gia hoạt động giải trí phù hợp.', true, 2),
    ('NONMED_COMPANION', 'Đồng hành di chuyển', 'Hỗ trợ tản bộ, đi chợ hoặc đến cuộc hẹn theo kế hoạch gia đình.', true, 3),
    ('NONMED_COMPANION', 'Hỗ trợ việc nhà nhẹ', 'Sắp xếp khu vực sinh hoạt gọn gàng và loại bỏ nguy cơ vấp ngã dễ thấy.', true, 4),
    ('NONMED_COMPANION', 'Bàn giao cuối ca', 'Ghi nhận hành trình và cập nhật cho gia đình.', true, 5),

    ('NONMED_DAY', 'Xác nhận kế hoạch trong ngày', 'Đọc lại lịch sinh hoạt, bữa ăn và thông tin liên hệ do gia đình cung cấp.', true, 1),
    ('NONMED_DAY', 'Hỗ trợ sinh hoạt cá nhân', 'Hỗ trợ vệ sinh, thay đồ và di chuyển trong nhà.', true, 2),
    ('NONMED_DAY', 'Chuẩn bị bữa ăn và đồ uống', 'Chuẩn bị theo nguyên liệu và hướng dẫn do gia đình cung cấp.', true, 3),
    ('NONMED_DAY', 'Đồng hành vận động nhẹ', 'Tản bộ hoặc vận động sinh hoạt trong khả năng của người được chăm sóc.', true, 4),
    ('NONMED_DAY', 'Giữ không gian sinh hoạt an toàn', 'Thu dọn nhẹ và loại bỏ nguy cơ vấp ngã dễ thấy.', true, 5),
    ('NONMED_DAY', 'Bàn giao cuối ca', 'Ghi nhận các việc đã hoàn thành và cập nhật cho gia đình.', true, 6),

    ('NONMED_NIGHT', 'Chuẩn bị không gian nghỉ ngơi', 'Kiểm tra lối đi, ánh sáng và vật dụng cần thiết trước giờ ngủ.', true, 1),
    ('NONMED_NIGHT', 'Hỗ trợ đi vệ sinh ban đêm', 'Hỗ trợ di chuyển an toàn khi người được chăm sóc có nhu cầu.', true, 2),
    ('NONMED_NIGHT', 'Túc trực theo kế hoạch gia đình', 'Có mặt và thực hiện các lần nhắc hoặc hỗ trợ sinh hoạt đã thống nhất.', true, 3),
    ('NONMED_NIGHT', 'Liên hệ khi có bất thường', 'Báo ngay cho người thân hoặc cấp cứu; không tự chẩn đoán hay xử trí y tế.', true, 4),
    ('NONMED_NIGHT', 'Bàn giao ca sáng', 'Ghi nhận sự kiện trong đêm và cập nhật cho gia đình.', true, 5)
)
INSERT INTO booking.package_task_templates (
  service_type_id,
  name,
  description,
  is_required,
  requires_photo,
  sort_order,
  is_active
)
SELECT
  service.id,
  templates.name,
  templates.description,
  templates.is_required,
  false,
  templates.sort_order,
  true
FROM templates
JOIN catalog.service_types service ON service.code = templates.service_code
ON CONFLICT (service_type_id, name) DO UPDATE SET
  description = EXCLUDED.description,
  is_required = EXCLUDED.is_required,
  requires_photo = EXCLUDED.requires_photo,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;

COMMIT;
