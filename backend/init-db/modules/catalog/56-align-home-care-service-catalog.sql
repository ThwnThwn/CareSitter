-- Dong bo bon dich vu demo voi bang gia cham soc tai nha co hieu luc tu 01/10/2026.
-- Giu nguyen service id/code de booking cu va asset theo code tiep tuc hoat dong.
BEGIN;

WITH service_updates(code, name, description) AS (
  VALUES
    (
      'NONMED_COMPANION',
      'Trò chuyện, đồng hành và kích thích nhận thức nhẹ',
      'Trò chuyện, đọc sách, chơi cờ và nhắc sinh hoạt theo lịch gia đình cung cấp. Không thay thế đánh giá hoặc can thiệp y tế.'
    ),
    (
      'NONMED_ESSENTIAL',
      'Vệ sinh cá nhân, tắm rửa và thay đồ',
      'Hỗ trợ vệ sinh cá nhân, tắm rửa và thay đồ đúng kỹ thuật, tôn trọng sự riêng tư và phạm vi gia đình đã thống nhất.'
    ),
    (
      'NONMED_DAY',
      'Hỗ trợ bữa ăn dinh dưỡng',
      'Chuẩn bị và hỗ trợ bữa ăn theo nguyên liệu, khẩu phần và hướng dẫn chuyên môn do gia đình cung cấp.'
    ),
    (
      'NONMED_NIGHT',
      'Phòng ngừa té ngã và chăm sóc da',
      'Kiểm tra nguy cơ té ngã, hỗ trợ xoay trở và quan sát da bên ngoài; báo gia đình khi có bất thường, không tự chẩn đoán hoặc xử trí y tế.'
    )
)
UPDATE catalog.service_types service
SET name = service_updates.name,
    description = service_updates.description,
    default_duration_minutes = 60,
    is_active = true,
    allow_ad_hoc_tasks = false
FROM service_updates
WHERE service.code = service_updates.code;

-- Dong cac bang gia seed cu, nhung khong can thiep bang gia do admin tao sau nay.
UPDATE catalog.pricing_rules
SET is_active = false,
    effective_to = COALESCE(effective_to, now())
WHERE id IN (
  'b0000000-0000-0000-0000-0000000000d1',
  'b0000000-0000-0000-0000-0000000000d2',
  'b0000000-0000-0000-0000-0000000000d3',
  'b0000000-0000-0000-0000-0000000000d4'
);

INSERT INTO catalog.pricing_rules (
  id,
  name,
  service_type_id,
  base_hourly_price,
  night_multiplier,
  holiday_multiplier,
  platform_fee_percent,
  dispute_window_hours,
  effective_from,
  effective_to,
  is_active
)
VALUES
  (
    'b0000000-0000-0000-0000-0000000000d5',
    'Giá Trò chuyện, đồng hành và kích thích nhận thức nhẹ',
    'b0000000-0000-0000-0000-0000000000f2',
    80000, 1.00, 1.50, 15.00, 48, '2026-10-01 00:00:00+07', NULL, true
  ),
  (
    'b0000000-0000-0000-0000-0000000000d6',
    'Giá Vệ sinh cá nhân, tắm rửa và thay đồ',
    'b0000000-0000-0000-0000-0000000000f1',
    120000, 1.00, 1.50, 15.00, 48, '2026-10-01 00:00:00+07', NULL, true
  ),
  (
    'b0000000-0000-0000-0000-0000000000d7',
    'Giá Hỗ trợ bữa ăn dinh dưỡng',
    'b0000000-0000-0000-0000-0000000000f3',
    85000, 1.00, 1.50, 15.00, 48, '2026-10-01 00:00:00+07', NULL, true
  ),
  (
    'b0000000-0000-0000-0000-0000000000d8',
    'Giá Phòng ngừa té ngã và chăm sóc da',
    'b0000000-0000-0000-0000-0000000000f4',
    120000, 1.00, 1.50, 15.00, 48, '2026-10-01 00:00:00+07', NULL, true
  )
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

-- Chi template hien hanh doi theo ten dich vu; care_tasks cua booking cu la snapshot va duoc giu nguyen.
UPDATE booking.package_task_templates template
SET is_active = false
WHERE template.service_type_id IN (
  'b0000000-0000-0000-0000-0000000000f1',
  'b0000000-0000-0000-0000-0000000000f2',
  'b0000000-0000-0000-0000-0000000000f3',
  'b0000000-0000-0000-0000-0000000000f4'
);

WITH templates(service_code, name, description, sort_order) AS (
  VALUES
    ('NONMED_COMPANION', 'Xác nhận hoạt động đồng hành', 'Thống nhất nội dung trò chuyện, hoạt động và lịch sinh hoạt với gia đình.', 1),
    ('NONMED_COMPANION', 'Trò chuyện và lắng nghe', 'Trò chuyện, lắng nghe và khuyến khích người được chăm sóc chia sẻ.', 2),
    ('NONMED_COMPANION', 'Hoạt động nhận thức nhẹ', 'Đọc sách, chơi cờ hoặc thực hiện hoạt động giải trí phù hợp đã thống nhất.', 3),
    ('NONMED_COMPANION', 'Nhắc lịch sinh hoạt', 'Nhắc các hoạt động trong lịch gia đình cung cấp; không tự điều chỉnh thuốc hoặc chỉ định y tế.', 4),
    ('NONMED_COMPANION', 'Bàn giao cuối ca', 'Ghi nhận hoạt động, phản hồi và cập nhật cho gia đình.', 5),

    ('NONMED_ESSENTIAL', 'Xác nhận lưu ý chăm sóc cá nhân', 'Đọc lại thói quen, mức hỗ trợ và các lưu ý riêng tư do gia đình cung cấp.', 1),
    ('NONMED_ESSENTIAL', 'Chuẩn bị đồ dùng và không gian an toàn', 'Chuẩn bị vật dụng cần thiết, kiểm tra nhiệt độ nước và giảm nguy cơ trơn trượt.', 2),
    ('NONMED_ESSENTIAL', 'Hỗ trợ vệ sinh và tắm rửa', 'Hỗ trợ đúng phạm vi đã thống nhất, bảo đảm an toàn và tôn trọng riêng tư.', 3),
    ('NONMED_ESSENTIAL', 'Hỗ trợ thay đồ', 'Hỗ trợ lựa chọn và thay trang phục phù hợp, giữ ấm và thoải mái.', 4),
    ('NONMED_ESSENTIAL', 'Bàn giao cuối ca', 'Ghi nhận việc đã hoàn thành và báo gia đình khi có bất thường.', 5),

    ('NONMED_DAY', 'Xác nhận hướng dẫn bữa ăn', 'Đọc lại khẩu phần, dị ứng, cách chế biến và hướng dẫn do gia đình cung cấp.', 1),
    ('NONMED_DAY', 'Chuẩn bị nguyên liệu và dụng cụ', 'Kiểm tra nguyên liệu, vệ sinh tay và chuẩn bị khu vực chế biến an toàn.', 2),
    ('NONMED_DAY', 'Chuẩn bị bữa ăn', 'Chế biến hoặc hâm nóng đúng hướng dẫn và khẩu phần đã thống nhất.', 3),
    ('NONMED_DAY', 'Hỗ trợ dùng bữa', 'Sắp xếp bữa ăn và hỗ trợ trong phạm vi an toàn, không ép ăn.', 4),
    ('NONMED_DAY', 'Thu dọn và bàn giao', 'Thu dọn khu vực, ghi nhận lượng ăn theo quan sát và cập nhật cho gia đình.', 5),

    ('NONMED_NIGHT', 'Kiểm tra nguy cơ té ngã', 'Quan sát lối đi, ánh sáng, thảm và vật cản dễ gây trượt hoặc vấp ngã.', 1),
    ('NONMED_NIGHT', 'Sắp xếp không gian an toàn', 'Đặt vật dụng cần thiết trong tầm với và giữ lối di chuyển thông thoáng.', 2),
    ('NONMED_NIGHT', 'Hỗ trợ thay đổi tư thế', 'Hỗ trợ xoay trở hoặc thay đổi tư thế theo kế hoạch gia đình đã thống nhất.', 3),
    ('NONMED_NIGHT', 'Quan sát tình trạng da bên ngoài', 'Quan sát vùng da dễ tì đè và báo gia đình khi có dấu hiệu bất thường; không tự điều trị.', 4),
    ('NONMED_NIGHT', 'Bàn giao cuối ca', 'Ghi nhận nguy cơ đã xử lý, hỗ trợ đã thực hiện và cập nhật cho gia đình.', 5)
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
  true,
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
