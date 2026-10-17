-- Backfill MỘT LẦN cho các booking đang mở được tạo trước checklist snapshot.
-- Chỉ chạy sau 17-checklist-snapshots.sql. Không thay đổi booking đã hoàn tất/hủy.
BEGIN;

WITH eligible_bookings AS (
  SELECT b.id, b.service_type_id
  FROM booking.bookings b
  WHERE b.status IN (
    'CONFIRMED', 'CAREGIVER_ACCEPTED', 'CAREGIVER_EN_ROUTE', 'IN_PROGRESS', 'CRISIS', 'CHECKOUT_PENDING_REVIEW'
  )
    AND NOT EXISTS (
      SELECT 1 FROM booking.care_tasks task WHERE task.booking_id = b.id
    )
)
UPDATE booking.bookings booking
SET allow_ad_hoc_tasks = service.allow_ad_hoc_tasks
FROM eligible_bookings eligible
JOIN catalog.service_types service ON service.id = eligible.service_type_id
WHERE booking.id = eligible.id;

INSERT INTO booking.care_tasks (
  id, booking_id, name, description, is_required, requires_photo, sort_order,
  status, source, template_id, created_at
)
SELECT
  gen_random_uuid(), booking.id, template.name, template.description,
  template.is_required, template.requires_photo, template.sort_order,
  'PENDING', 'PACKAGE', template.id, now()
FROM booking.bookings booking
JOIN booking.package_task_templates template
  ON template.service_type_id = booking.service_type_id AND template.is_active
WHERE booking.status IN (
  'CONFIRMED', 'CAREGIVER_ACCEPTED', 'CAREGIVER_EN_ROUTE', 'IN_PROGRESS', 'CRISIS', 'CHECKOUT_PENDING_REVIEW'
)
  AND NOT EXISTS (
    SELECT 1 FROM booking.care_tasks task WHERE task.booking_id = booking.id
  );

COMMIT;
