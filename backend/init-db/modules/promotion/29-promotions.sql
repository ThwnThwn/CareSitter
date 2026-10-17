-- ========================================================
-- 29-promotions.sql | Promotion module + booking price snapshot
-- ========================================================

CREATE SCHEMA IF NOT EXISTS promotion;

CREATE TABLE IF NOT EXISTS promotion.promotions (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                     varchar(50) NOT NULL UNIQUE,
  title                    varchar(160) NOT NULL,
  summary                  varchar(300) NOT NULL,
  description              text,
  badge_text               varchar(50) NOT NULL,
  terms                    jsonb NOT NULL DEFAULT '[]'::jsonb,
  discount_type            varchar(20) NOT NULL
                           CHECK (discount_type IN ('PERCENTAGE','FIXED_AMOUNT')),
  discount_value           bigint NOT NULL CHECK (discount_value > 0),
  max_discount_amount      bigint CHECK (max_discount_amount IS NULL OR max_discount_amount > 0),
  min_order_amount         bigint NOT NULL DEFAULT 0 CHECK (min_order_amount >= 0),
  starts_at                timestamptz NOT NULL,
  ends_at                  timestamptz NOT NULL,
  is_active                boolean NOT NULL DEFAULT TRUE,
  first_paid_booking_only  boolean NOT NULL DEFAULT FALSE,
  total_usage_limit        int CHECK (total_usage_limit IS NULL OR total_usage_limit > 0),
  per_customer_usage_limit int NOT NULL DEFAULT 1 CHECK (per_customer_usage_limit > 0),
  priority                 int NOT NULL DEFAULT 0,
  is_featured              boolean NOT NULL DEFAULT FALSE,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT promotions_window_check CHECK (ends_at > starts_at),
  CONSTRAINT promotions_terms_array_check CHECK (jsonb_typeof(terms) = 'array'),
  CONSTRAINT promotions_percentage_check CHECK (
    discount_type <> 'PERCENTAGE' OR discount_value BETWEEN 1 AND 100)
);

CREATE TABLE IF NOT EXISTS promotion.promotion_service_scopes (
  promotion_id   uuid NOT NULL REFERENCES promotion.promotions(id) ON DELETE CASCADE,
  service_type_id uuid NOT NULL REFERENCES catalog.service_types(id) ON DELETE CASCADE,
  PRIMARY KEY (promotion_id, service_type_id)
);

CREATE TABLE IF NOT EXISTS promotion.promotion_redemptions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  promotion_id    uuid NOT NULL REFERENCES promotion.promotions(id),
  customer_id     uuid NOT NULL REFERENCES identity.users(id),
  -- Logical reference only: the reservation is created before Booking commits.
  -- Expiry + compensation make this a safe cross-module saga boundary.
  booking_id      uuid NOT NULL,
  discount_amount bigint NOT NULL CHECK (discount_amount > 0),
  status          varchar(20) NOT NULL CHECK (status IN ('RESERVED','REDEEMED','RELEASED')),
  reserved_at     timestamptz NOT NULL,
  expires_at      timestamptz NOT NULL,
  redeemed_at     timestamptz,
  released_at     timestamptz,
  release_reason  varchar(100),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT promotion_redemption_window_check CHECK (expires_at > reserved_at),
  CONSTRAINT promotion_redemption_state_check CHECK (
    (status = 'RESERVED' AND redeemed_at IS NULL AND released_at IS NULL) OR
    (status = 'REDEEMED' AND redeemed_at IS NOT NULL AND released_at IS NULL) OR
    (status = 'RELEASED' AND released_at IS NOT NULL AND redeemed_at IS NULL))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_promotion_redemptions_booking
  ON promotion.promotion_redemptions (booking_id);
CREATE INDEX IF NOT EXISTS ix_promotion_redemptions_quota
  ON promotion.promotion_redemptions (promotion_id, status, expires_at);
CREATE INDEX IF NOT EXISTS ix_promotion_redemptions_customer
  ON promotion.promotion_redemptions (promotion_id, customer_id, status);

DROP TRIGGER IF EXISTS trg_promotions_updated ON promotion.promotions;
CREATE TRIGGER trg_promotions_updated BEFORE UPDATE ON promotion.promotions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
DROP TRIGGER IF EXISTS trg_promotion_redemptions_updated ON promotion.promotion_redemptions;
CREATE TRIGGER trg_promotion_redemptions_updated BEFORE UPDATE ON promotion.promotion_redemptions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE booking.bookings
  ADD COLUMN IF NOT EXISTS customer_payable_amount bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS promotion_discount_amount bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS promotion_subsidy_amount bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS promotion_id uuid,
  ADD COLUMN IF NOT EXISTS promotion_code varchar(50);

UPDATE booking.bookings
SET customer_payable_amount = escrow_amount
WHERE customer_payable_amount = 0 AND escrow_amount > 0;

-- Backward-compatible guard for existing SQL writers that only provide
-- escrow_amount. Application writes still send customer_payable_amount explicitly.
CREATE OR REPLACE FUNCTION booking.default_customer_payable_amount()
RETURNS trigger AS $$
BEGIN
  IF NEW.promotion_id IS NULL
     AND NEW.promotion_discount_amount = 0
     AND NEW.customer_payable_amount = 0
     AND NEW.escrow_amount > 0 THEN
    NEW.customer_payable_amount = NEW.escrow_amount;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_bookings_default_customer_payable ON booking.bookings;
CREATE TRIGGER trg_bookings_default_customer_payable
  BEFORE INSERT ON booking.bookings
  FOR EACH ROW EXECUTE FUNCTION booking.default_customer_payable_amount();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_bookings_promotion'
  ) THEN
    ALTER TABLE booking.bookings ADD CONSTRAINT fk_bookings_promotion
      FOREIGN KEY (promotion_id) REFERENCES promotion.promotions(id) ON DELETE SET NULL;
  END IF;
END $$;

ALTER TABLE booking.bookings
  DROP CONSTRAINT IF EXISTS bookings_promotion_price_check;
ALTER TABLE booking.bookings
  ADD CONSTRAINT bookings_promotion_price_check CHECK (
    customer_payable_amount >= 0 AND
    promotion_discount_amount >= 0 AND
    promotion_subsidy_amount >= 0 AND
    customer_payable_amount + promotion_discount_amount = escrow_amount AND
    promotion_subsidy_amount = promotion_discount_amount AND
    ((promotion_id IS NULL AND promotion_code IS NULL AND promotion_discount_amount = 0) OR
     (promotion_id IS NOT NULL AND promotion_code IS NOT NULL AND promotion_discount_amount > 0))
  );

ALTER TABLE payments.ledger_entries
  DROP CONSTRAINT IF EXISTS ledger_entries_transaction_type_check;
ALTER TABLE payments.ledger_entries
  ADD CONSTRAINT ledger_entries_transaction_type_check CHECK (
    transaction_type IN ('ESCROW_LOCK','PLATFORM_FEE','CAREGIVER_EARNING',
      'REFUND','PAYOUT','PENALTY','BONUS','PROMOTION_SUBSIDY'));
CREATE UNIQUE INDEX IF NOT EXISTS ux_ledger_promotion_subsidy_booking
  ON payments.ledger_entries (booking_id)
  WHERE booking_id IS NOT NULL AND transaction_type = 'PROMOTION_SUBSIDY';

INSERT INTO promotion.promotions (
  id, code, title, summary, description, badge_text, terms,
  discount_type, discount_value, max_discount_amount, min_order_amount,
  starts_at, ends_at, is_active, first_paid_booking_only,
  total_usage_limit, per_customer_usage_limit, priority, is_featured)
VALUES
  ('b0000000-0000-0000-0000-000000000001', 'CHAOMUNG20',
   'Ưu đãi khách hàng mới', 'Giảm 20% cho đơn chăm sóc đầu tiên',
   'CareSitter tài trợ ưu đãi để người chăm sóc vẫn nhận đủ thu nhập theo báo giá.',
   'Giảm 20%',
   '["Áp dụng cho đơn thanh toán đầu tiên", "Giảm tối đa 100.000đ", "Không quy đổi thành tiền mặt"]'::jsonb,
   'PERCENTAGE', 20, 100000, 100000,
   '2026-01-01T00:00:00+07:00', '2027-12-31T23:59:59+07:00', TRUE, TRUE,
   10000, 1, 100, TRUE),
  ('b0000000-0000-0000-0000-000000000002', 'CARESITTER50',
   'Chăm sóc an tâm', 'Giảm 50.000đ cho đơn từ 300.000đ',
   'Ưu đãi dành cho khách hàng đặt các gói chăm sóc đủ điều kiện.',
   'Giảm 50k',
   '["Đơn tối thiểu 300.000đ", "Mỗi khách hàng sử dụng một lần", "Không áp dụng đồng thời ưu đãi khác"]'::jsonb,
   'FIXED_AMOUNT', 50000, NULL, 300000,
   '2026-01-01T00:00:00+07:00', '2027-12-31T23:59:59+07:00', TRUE, FALSE,
   20000, 1, 50, FALSE)
ON CONFLICT (id) DO NOTHING;
