-- Ba chương trình theo buổi/gói là sản phẩm bổ sung, không thay thế danh mục
-- dịch vụ chăm sóc theo giờ đã công bố ở migration 56.
BEGIN;

UPDATE catalog.service_types
SET is_active = true
WHERE code IN (
  'NONMED_COMPANION',
  'NONMED_ESSENTIAL',
  'NONMED_DAY',
  'NONMED_NIGHT'
);

-- Chỉ khôi phục bốn bảng giá niêm yết hiện hành. Các bảng giá seed cũ và bảng
-- giá do admin đóng trước đó không được tự động mở lại.
UPDATE catalog.pricing_rules
SET is_active = true,
    effective_to = NULL
WHERE id IN (
  'b0000000-0000-0000-0000-0000000000d5',
  'b0000000-0000-0000-0000-0000000000d6',
  'b0000000-0000-0000-0000-0000000000d7',
  'b0000000-0000-0000-0000-0000000000d8'
);

COMMIT;
