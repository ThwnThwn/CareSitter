-- Thêm payOS và chặn mở đồng thời hai cổng cho cùng một booking.
BEGIN;

ALTER TABLE payments.payment_intents DROP CONSTRAINT IF EXISTS payment_intents_provider_check;
ALTER TABLE payments.payment_intents ADD CONSTRAINT payment_intents_provider_check
  CHECK (provider IN ('VNPAY', 'PAYOS', 'MOMO', 'CARD'));
ALTER TABLE payments.payment_webhooks DROP CONSTRAINT IF EXISTS payment_webhooks_provider_check;
ALTER TABLE payments.payment_webhooks ADD CONSTRAINT payment_webhooks_provider_check
  CHECK (provider IN ('VNPAY', 'PAYOS', 'MOMO', 'CARD'));

ALTER TABLE payments.payment_intents
  ADD COLUMN IF NOT EXISTS provider_link_id varchar(100),
  ADD COLUMN IF NOT EXISTS checkout_url text,
  ADD COLUMN IF NOT EXISTS provider_account_number varchar(100),
  ADD COLUMN IF NOT EXISTS provider_expires_at timestamptz;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM payments.payment_intents
             WHERE status IN ('CREATED','PENDING') GROUP BY booking_id HAVING count(*) > 1) THEN
    RAISE EXCEPTION 'Cần đối soát các giao dịch CREATED/PENDING trùng booking trước khi chạy migration payOS';
  END IF;
END $$;
DROP INDEX IF EXISTS payments.ux_payment_intent_one_pending_per_booking;
CREATE UNIQUE INDEX ux_payment_intent_one_pending_per_booking
  ON payments.payment_intents (booking_id) WHERE status IN ('CREATED','PENDING');
CREATE UNIQUE INDEX IF NOT EXISTS ux_payment_intent_provider_link
  ON payments.payment_intents (provider, provider_link_id) WHERE provider_link_id IS NOT NULL;

COMMIT;
