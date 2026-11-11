-- Bổ sung tám dịch vụ theo giờ còn thiếu trong bảng giá chăm sóc tại nhà.
-- Bốn dịch vụ NONMED hiện hữu được giữ nguyên bởi migration 58.
BEGIN;

INSERT INTO catalog.service_types (
  id, code, name, description, default_duration_minutes, is_active, allow_ad_hoc_tasks
)
VALUES
  (
    'b0000000-0000-0000-0000-0000000000f5',
    'APPOINTMENT_COMPANION',
    'Đồng hành đi khám / đi ra ngoài',
    'Hỗ trợ di chuyển an toàn, đồng hành và chờ khám hoặc tham gia hoạt động bên ngoài theo kế hoạch đã thống nhất.',
    60, true, false
  ),
  (
    'b0000000-0000-0000-0000-0000000000f6',
    'MOBILITY_SUPPORT',
    'Vận động nhẹ / hỗ trợ di chuyển',
    'Hỗ trợ đi lại trong nhà, thay đổi tư thế và vận động nhẹ phù hợp với khả năng của người được chăm sóc.',
    60, true, false
  ),
  (
    'b0000000-0000-0000-0000-0000000000f7',
    'NURSING_VITALS',
    'Theo dõi sinh hiệu, tiêm và thay băng',
    'Theo dõi sinh hiệu, tiêm và thay băng theo chỉ định hợp lệ, do nhân sự có chuyên môn phù hợp thực hiện.',
    60, true, false
  ),
  (
    'b0000000-0000-0000-0000-0000000000f8',
    'CHRONIC_CARE',
    'Quản lý và theo dõi bệnh mạn tính',
    'Theo dõi đường huyết, huyết áp, thuốc và các chỉ số theo kế hoạch chăm sóc đã được cung cấp.',
    60, true, false
  ),
  (
    'b0000000-0000-0000-0000-0000000000f9',
    'PALLIATIVE_CARE',
    'Chăm sóc giảm nhẹ và cuối đời',
    'Chăm sóc giảm nhẹ tại nhà theo kế hoạch chuyên môn, phối hợp với gia đình và bác sĩ phụ trách.',
    60, true, false
  ),
  (
    'b0000000-0000-0000-0000-0000000000fa',
    'HOME_PHYSIOTHERAPY',
    'Vật lý trị liệu tại nhà',
    'Phục hồi chức năng tại nhà sau đột quỵ, phẫu thuật hoặc gãy xương theo đánh giá và kế hoạch chuyên môn.',
    60, true, false
  ),
  (
    'b0000000-0000-0000-0000-0000000000fb',
    'COGNITIVE_STIMULATION',
    'Kích thích nhận thức CST / Montessori',
    'Hoạt động hỗ trợ duy trì chức năng nhận thức theo chương trình phù hợp, không cam kết phục hồi trí nhớ.',
    60, true, false
  ),
  (
    'b0000000-0000-0000-0000-0000000000fc',
    'ACUPUNCTURE_ACUPRESSURE',
    'Châm cứu, bấm huyệt',
    'Dịch vụ y học cổ truyền tại nhà do người có chuyên môn phù hợp thực hiện sau sàng lọc chống chỉ định.',
    60, true, false
  )
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  default_duration_minutes = EXCLUDED.default_duration_minutes,
  is_active = EXCLUDED.is_active,
  allow_ad_hoc_tasks = EXCLUDED.allow_ad_hoc_tasks;

WITH hourly_price_seed(service_code, id, name, base_hourly_price) AS (
  VALUES
    ('APPOINTMENT_COMPANION', 'b0000000-0000-0000-0000-0000000000d9'::uuid, 'Giá Đồng hành đi khám / đi ra ngoài', 90000::bigint),
    ('MOBILITY_SUPPORT', 'b0000000-0000-0000-0000-0000000000da'::uuid, 'Giá Vận động nhẹ / hỗ trợ di chuyển', 130000::bigint),
    ('NURSING_VITALS', 'b0000000-0000-0000-0000-0000000000db'::uuid, 'Giá Theo dõi sinh hiệu, tiêm và thay băng', 200000::bigint),
    ('CHRONIC_CARE', 'b0000000-0000-0000-0000-0000000000dc'::uuid, 'Giá Quản lý và theo dõi bệnh mạn tính', 220000::bigint),
    ('PALLIATIVE_CARE', 'b0000000-0000-0000-0000-0000000000dd'::uuid, 'Giá Chăm sóc giảm nhẹ và cuối đời', 280000::bigint),
    ('HOME_PHYSIOTHERAPY', 'b0000000-0000-0000-0000-0000000000de'::uuid, 'Giá Vật lý trị liệu tại nhà', 250000::bigint),
    ('COGNITIVE_STIMULATION', 'b0000000-0000-0000-0000-0000000000df'::uuid, 'Giá Kích thích nhận thức CST / Montessori', 200000::bigint),
    ('ACUPUNCTURE_ACUPRESSURE', 'b0000000-0000-0000-0000-0000000000e0'::uuid, 'Giá Châm cứu, bấm huyệt', 300000::bigint)
)
INSERT INTO catalog.pricing_rules (
  id, name, service_type_id, base_hourly_price, night_multiplier,
  holiday_multiplier, platform_fee_percent, dispute_window_hours,
  effective_from, effective_to, is_active
)
SELECT hourly_price_seed.id, hourly_price_seed.name, service.id,
  hourly_price_seed.base_hourly_price, 1.00, 1.50, 15.00, 48,
  '2026-10-01 00:00:00+07', NULL, true
FROM hourly_price_seed
JOIN catalog.service_types service ON service.code = hourly_price_seed.service_code
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

COMMIT;
