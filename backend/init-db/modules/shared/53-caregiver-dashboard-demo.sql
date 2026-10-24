-- Du lieu demo cho dashboard caregiver Nguyen Thi Bich Ngoc.
-- Ngay ca duoc tinh tu ngay khoi tao database de dashboard luon co du lieu gan day.
-- UUID co dinh va ON CONFLICT giup script an toan khi chay lai.
BEGIN;

INSERT INTO booking.bookings (
  id,
  customer_id,
  beneficiary_id,
  caregiver_id,
  address_id,
  service_type_id,
  scheduled_start,
  scheduled_end,
  actual_start,
  actual_end,
  duration_minutes,
  care_notes,
  status,
  escrow_amount,
  platform_fee_amount,
  caregiver_earning_amount,
  price_snapshot,
  settlement_released_at,
  customer_payable_amount,
  allow_ad_hoc_tasks
)
VALUES
  (
    'd0000000-0000-0000-0000-000000000101',
    'a0000000-0000-0000-0000-0000000000c1',
    'a0000000-0000-0000-0000-0000000000b1',
    'a0000000-0000-0000-0000-0000000000e4',
    'a0000000-0000-0000-0000-000000000071',
    'b0000000-0000-0000-0000-0000000000f1',
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE + time '23:00'),
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE + interval '1 day' + time '01:00'),
    NULL,
    NULL,
    120,
    'Xác nhận kế hoạch sinh hoạt, hỗ trợ bữa nhẹ và bàn giao cho gia đình cuối ca.',
    'CAREGIVER_ACCEPTED',
    180000,
    27000,
    153000,
    '{"source":"caregiver-dashboard-demo","serviceCode":"NONMED_ESSENTIAL"}'::jsonb,
    NULL,
    180000,
    false
  ),
  (
    'd0000000-0000-0000-0000-000000000102',
    'a0000000-0000-0000-0000-0000000000c1',
    'a0000000-0000-0000-0000-0000000000b1',
    'a0000000-0000-0000-0000-0000000000e4',
    'a0000000-0000-0000-0000-000000000071',
    'b0000000-0000-0000-0000-0000000000f1',
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '1 day' + time '08:00'),
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '1 day' + time '12:00'),
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '1 day' + time '08:00'),
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '1 day' + time '12:00'),
    240,
    'Hỗ trợ sinh hoạt buổi sáng và chuẩn bị bữa ăn theo hướng dẫn của gia đình.',
    'COMPLETED',
    360000,
    54000,
    306000,
    '{"source":"caregiver-dashboard-demo","serviceCode":"NONMED_ESSENTIAL"}'::jsonb,
    now(),
    360000,
    false
  ),
  (
    'd0000000-0000-0000-0000-000000000103',
    'a0000000-0000-0000-0000-0000000000c1',
    'a0000000-0000-0000-0000-0000000000b1',
    'a0000000-0000-0000-0000-0000000000e4',
    'a0000000-0000-0000-0000-000000000071',
    'b0000000-0000-0000-0000-0000000000f2',
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '3 days' + time '09:00'),
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '3 days' + time '13:00'),
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '3 days' + time '09:00'),
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '3 days' + time '13:00'),
    240,
    'Đồng hành tản bộ, trò chuyện và hỗ trợ sắp xếp khu vực sinh hoạt.',
    'COMPLETED',
    320000,
    48000,
    272000,
    '{"source":"caregiver-dashboard-demo","serviceCode":"NONMED_COMPANION"}'::jsonb,
    now(),
    320000,
    false
  ),
  (
    'd0000000-0000-0000-0000-000000000104',
    'a0000000-0000-0000-0000-0000000000c1',
    'a0000000-0000-0000-0000-0000000000b1',
    'a0000000-0000-0000-0000-0000000000e4',
    'a0000000-0000-0000-0000-000000000071',
    'b0000000-0000-0000-0000-0000000000f3',
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '5 days' + time '07:00'),
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '5 days' + time '15:00'),
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '5 days' + time '07:00'),
    timezone('Asia/Ho_Chi_Minh', CURRENT_DATE - interval '5 days' + time '15:00'),
    480,
    'Hỗ trợ sinh hoạt ban ngày, bữa ăn, vận động nhẹ và cập nhật cho gia đình.',
    'COMPLETED',
    560000,
    84000,
    476000,
    '{"source":"caregiver-dashboard-demo","serviceCode":"NONMED_DAY"}'::jsonb,
    now(),
    560000,
    false
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO booking.booking_assignments (
  id,
  booking_id,
  caregiver_id,
  assignment_type,
  status,
  rank,
  offered_at,
  responded_at
)
SELECT
  assignment_id,
  booking_id,
  'a0000000-0000-0000-0000-0000000000e4',
  'PRIMARY',
  'ACCEPTED',
  1,
  scheduled_start - interval '1 day',
  scheduled_start - interval '1 day' + interval '5 minutes'
FROM (
  VALUES
    ('d0000000-0000-0000-0000-000000000301'::uuid, 'd0000000-0000-0000-0000-000000000101'::uuid),
    ('d0000000-0000-0000-0000-000000000302'::uuid, 'd0000000-0000-0000-0000-000000000102'::uuid),
    ('d0000000-0000-0000-0000-000000000303'::uuid, 'd0000000-0000-0000-0000-000000000103'::uuid),
    ('d0000000-0000-0000-0000-000000000304'::uuid, 'd0000000-0000-0000-0000-000000000104'::uuid)
) AS demo(assignment_id, booking_id)
JOIN booking.bookings booking ON booking.id = demo.booking_id
ON CONFLICT (id) DO NOTHING;

INSERT INTO booking.care_tasks (
  id,
  booking_id,
  name,
  description,
  is_required,
  requires_photo,
  sort_order,
  status,
  completed_at
)
SELECT
  md5(booking.id::text || ':' || template.id::text)::uuid,
  booking.id,
  template.name,
  template.description,
  template.is_required,
  template.requires_photo,
  template.sort_order,
  CASE WHEN booking.status = 'COMPLETED' THEN 'COMPLETED' ELSE 'PENDING' END,
  CASE WHEN booking.status = 'COMPLETED' THEN booking.actual_end ELSE NULL END
FROM booking.bookings booking
JOIN booking.package_task_templates template
  ON template.service_type_id = booking.service_type_id
 AND template.is_active = true
WHERE booking.id IN (
  'd0000000-0000-0000-0000-000000000101',
  'd0000000-0000-0000-0000-000000000102',
  'd0000000-0000-0000-0000-000000000103',
  'd0000000-0000-0000-0000-000000000104'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO support.reviews (
  id,
  booking_id,
  caregiver_id,
  customer_id,
  rating,
  comment,
  experience_tags,
  created_at
)
VALUES
  (
    'd0000000-0000-0000-0000-000000000201',
    'd0000000-0000-0000-0000-000000000102',
    'a0000000-0000-0000-0000-0000000000e4',
    'a0000000-0000-0000-0000-0000000000c1',
    5,
    'Đúng giờ, chu đáo và cập nhật đầy đủ cho gia đình.',
    '["Đúng giờ","Tận tâm","Giao tiếp tốt"]'::jsonb,
    now() - interval '1 day'
  ),
  (
    'd0000000-0000-0000-0000-000000000202',
    'd0000000-0000-0000-0000-000000000103',
    'a0000000-0000-0000-0000-0000000000e4',
    'a0000000-0000-0000-0000-0000000000c1',
    5,
    'Thân thiện, hỗ trợ di chuyển cẩn thận và bàn giao rõ ràng.',
    '["Tận tâm","Thân thiện","Giao tiếp tốt"]'::jsonb,
    now() - interval '3 days'
  ),
  (
    'd0000000-0000-0000-0000-000000000203',
    'd0000000-0000-0000-0000-000000000104',
    'a0000000-0000-0000-0000-0000000000e4',
    'a0000000-0000-0000-0000-0000000000c1',
    4,
    'Chăm sóc kỹ và thực hiện đầy đủ các việc đã thống nhất.',
    '["Tận tâm","Đúng giờ"]'::jsonb,
    now() - interval '5 days'
  )
ON CONFLICT (id) DO NOTHING;

WITH inserted_earnings AS (
  INSERT INTO payments.ledger_entries (
    id,
    booking_id,
    transaction_type,
    debit_account,
    credit_account,
    amount,
    currency,
    status,
    metadata,
    created_at
  )
  VALUES
    (
      'd0000000-0000-0000-0000-000000000401',
      'd0000000-0000-0000-0000-000000000102',
      'CAREGIVER_EARNING',
      'escrow:platform',
      'wallet:caregiver:a0000000-0000-0000-0000-0000000000e3',
      306000,
      'VND',
      'PENDING',
      '{"source":"caregiver-dashboard-demo"}'::jsonb,
      now() - interval '1 day'
    ),
    (
      'd0000000-0000-0000-0000-000000000402',
      'd0000000-0000-0000-0000-000000000103',
      'CAREGIVER_EARNING',
      'escrow:platform',
      'wallet:caregiver:a0000000-0000-0000-0000-0000000000e3',
      272000,
      'VND',
      'PENDING',
      '{"source":"caregiver-dashboard-demo"}'::jsonb,
      now() - interval '3 days'
    ),
    (
      'd0000000-0000-0000-0000-000000000403',
      'd0000000-0000-0000-0000-000000000104',
      'CAREGIVER_EARNING',
      'escrow:platform',
      'wallet:caregiver:a0000000-0000-0000-0000-0000000000e3',
      476000,
      'VND',
      'PENDING',
      '{"source":"caregiver-dashboard-demo"}'::jsonb,
      now() - interval '5 days'
    )
  ON CONFLICT DO NOTHING
  RETURNING amount
)
UPDATE payments.wallet_accounts
SET available_balance = available_balance + (
      SELECT COALESCE(sum(amount), 0) FROM inserted_earnings
    ),
    updated_at = now()
WHERE id = 'a0000000-0000-0000-0000-000000000003'
  AND EXISTS (SELECT 1 FROM inserted_earnings);

COMMIT;
