-- Checklist theo goi: template la cau hinh hien hanh, care_tasks la snapshot cua tung booking.
BEGIN;

CREATE TABLE IF NOT EXISTS booking.package_task_templates (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_type_id uuid NOT NULL REFERENCES catalog.service_types(id) ON DELETE CASCADE,
  name           varchar(255) NOT NULL,
  description    text,
  is_required    boolean NOT NULL DEFAULT true,
  requires_photo boolean NOT NULL DEFAULT false,
  sort_order     int NOT NULL DEFAULT 0,
  is_active      boolean NOT NULL DEFAULT true
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_package_task_templates_service_name
  ON booking.package_task_templates(service_type_id, name);

ALTER TABLE booking.bookings
  ADD COLUMN IF NOT EXISTS needs_review boolean NOT NULL DEFAULT false;
ALTER TABLE booking.bookings
  ADD COLUMN IF NOT EXISTS allow_ad_hoc_tasks boolean NOT NULL DEFAULT false;
ALTER TABLE catalog.service_types
  ADD COLUMN IF NOT EXISTS allow_ad_hoc_tasks boolean NOT NULL DEFAULT false;

ALTER TABLE booking.care_tasks
  ADD COLUMN IF NOT EXISTS completed_by uuid REFERENCES identity.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS skip_reason varchar(500),
  ADD COLUMN IF NOT EXISTS source varchar(30) NOT NULL DEFAULT 'PACKAGE',
  ADD COLUMN IF NOT EXISTS template_id uuid REFERENCES booking.package_task_templates(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES identity.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE booking.care_tasks DROP CONSTRAINT IF EXISTS care_tasks_status_check;
UPDATE booking.care_tasks SET status = 'COMPLETED' WHERE status = 'DONE';
UPDATE booking.care_tasks
SET skip_reason = 'Khong co ly do (du lieu cu)'
WHERE status = 'SKIPPED' AND (skip_reason IS NULL OR btrim(skip_reason) = '');
ALTER TABLE booking.care_tasks ADD CONSTRAINT care_tasks_status_check
  CHECK (status IN ('PENDING', 'COMPLETED', 'SKIPPED'));
ALTER TABLE booking.care_tasks DROP CONSTRAINT IF EXISTS care_tasks_skip_reason_check;
ALTER TABLE booking.care_tasks ADD CONSTRAINT care_tasks_skip_reason_check
  CHECK (status <> 'SKIPPED' OR length(btrim(skip_reason)) >= 3);
ALTER TABLE booking.care_tasks DROP CONSTRAINT IF EXISTS care_tasks_source_check;
ALTER TABLE booking.care_tasks ADD CONSTRAINT care_tasks_source_check
  CHECK (source IN ('PACKAGE', 'CAREGIVER_AD_HOC', 'ADMIN', 'SYSTEM'));

ALTER TABLE booking.care_timeline_events DROP CONSTRAINT IF EXISTS care_timeline_events_event_type_check;
ALTER TABLE booking.care_timeline_events ADD CONSTRAINT care_timeline_events_event_type_check CHECK (event_type IN (
  'CHECKIN','CHECKIN_VALID','CHECKIN_OUTSIDE_GEOFENCE','TASK_DONE','TASK_SKIPPED',
  'PHOTO_UPLOADED','NOTE','CHECKOUT','CHECKOUT_OTP_SENT','CHECKOUT_VALID',
  'CHECKOUT_MANUAL_REQUESTED','CHECKOUT_MANUAL_APPROVED','CHECKOUT_MANUAL_REJECTED',
  'GPS_LOST','SOS','SYNC_DELAYED','LATE_CHECKIN','AUTO_CHECKOUT'
));

CREATE INDEX IF NOT EXISTS ix_care_tasks_booking_status
  ON booking.care_tasks(booking_id, status);

WITH templates(service_code, name, description, is_required, requires_photo, sort_order) AS (
  VALUES
    ('GENKI_DUONG', 'Vệ sinh cá nhân', 'Hỗ trợ vệ sinh, thay đồ và sắp xếp vật dụng cá nhân.', true, true, 1),
    ('GENKI_DUONG', 'Chuẩn bị bữa ăn', 'Chuẩn bị đúng ghi chú dinh dưỡng của gia đình.', true, true, 2),
    ('GENKI_DUONG', 'Nhắc lịch uống thuốc', 'Nhắc người được chăm sóc theo lịch gia đình đã cung cấp.', true, false, 3),
    ('GENKI_DUONG', 'Vận động nhẹ nhàng', 'Đồng hành vận động trong phạm vi an toàn.', true, true, 4),
    ('GENKI_AN', 'Vệ sinh cá nhân', 'Hỗ trợ vệ sinh, thay đồ và sắp xếp vật dụng cá nhân.', true, true, 1),
    ('GENKI_AN', 'Chuẩn bị bữa ăn', 'Chuẩn bị đúng ghi chú dinh dưỡng của gia đình.', true, true, 2),
    ('GENKI_AN', 'Nhắc lịch uống thuốc', 'Nhắc người được chăm sóc theo lịch gia đình đã cung cấp.', true, false, 3),
    ('GENKI_AN', 'Vận động nhẹ nhàng', 'Đồng hành vận động trong phạm vi an toàn.', true, true, 4),
    ('GENKI_AN', 'Hoạt động thư giãn', 'Đọc sách, trò chuyện hoặc hoạt động trí não phù hợp.', true, true, 5),
    ('GENKI_TAM', 'Hỗ trợ phục hồi theo kế hoạch', 'Thực hiện đúng hướng dẫn phục hồi đã được cung cấp.', true, true, 1),
    ('GENKI_TAM', 'Lăn trở và kiểm tra tư thế', 'Hỗ trợ đổi tư thế an toàn và ghi nhận tình trạng.', true, true, 2),
    ('GENKI_PHUCHOI', 'Bài tập vận động Kaigo', 'Hỗ trợ bài tập phục hồi chức năng nhẹ nhàng.', true, true, 1),
    ('GENKI_PHUCHOI', 'Ghi nhận phản ứng vận động', 'Ghi chú mức độ linh hoạt và phản ứng sau buổi tập.', true, false, 2),
    ('GENKI_DONGHANH', 'Chuẩn bị trước khi di chuyển', 'Kiểm tra giấy tờ, thuốc và vật dụng cần thiết.', true, false, 1),
    ('GENKI_DONGHANH', 'Đồng hành và hỗ trợ di chuyển', 'Hỗ trợ đi lại an toàn.', true, true, 2),
    ('GENKI_DEM', 'Hỗ trợ chuẩn bị trước giờ ngủ', 'Chuẩn bị điều kiện nghỉ ngơi an toàn.', true, true, 1),
    ('GENKI_DEM', 'Túc trực và theo dõi giấc ngủ', 'Theo dõi giấc ngủ và các dấu hiệu bất thường.', true, false, 2)
)
INSERT INTO booking.package_task_templates(service_type_id, name, description, is_required, requires_photo, sort_order)
SELECT service.id, templates.name, templates.description, templates.is_required, templates.requires_photo, templates.sort_order
FROM templates JOIN catalog.service_types service ON service.code = templates.service_code
ON CONFLICT (service_type_id, name) DO NOTHING;

COMMIT;
