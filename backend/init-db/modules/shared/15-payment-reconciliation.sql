-- Payment reconciliation hardening. Safe to run more than once.

BEGIN;

ALTER TABLE booking.bookings
  ADD COLUMN IF NOT EXISTS payment_deadline timestamptz;
UPDATE booking.bookings
SET payment_deadline = created_at + interval '15 minutes'
WHERE payment_deadline IS NULL;
ALTER TABLE booking.bookings
  ALTER COLUMN payment_deadline SET NOT NULL,
  ALTER COLUMN payment_deadline SET DEFAULT (now() + interval '30 minutes');

ALTER TABLE payments.payment_intents
  ADD COLUMN IF NOT EXISTS reconciliation_attempts int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reconciliation_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_reconciliation_at timestamptz,
  ADD COLUMN IF NOT EXISTS next_reconciliation_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_reconciliation_error text,
  ADD COLUMN IF NOT EXISTS finalized_source varchar(30),
  ADD COLUMN IF NOT EXISTS manual_review_reason text;

ALTER TABLE booking.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE booking.bookings ADD CONSTRAINT bookings_status_check CHECK (
  status IN ('DRAFT','PENDING_PAYMENT','PAYMENT_RECONCILIATION_PENDING','NEEDS_MANUAL_REVIEW',
             'CONFIRMED','CAREGIVER_ACCEPTED','MATCHING_FAILED','CAREGIVER_EN_ROUTE','IN_PROGRESS',
             'CHECKOUT_PENDING_REVIEW','COMPLETED','CANCELLED','CRISIS','DISPUTED','REFUNDED'));

ALTER TABLE payments.payment_intents DROP CONSTRAINT IF EXISTS payment_intents_status_check;
ALTER TABLE payments.payment_intents ADD CONSTRAINT payment_intents_status_check CHECK (
  status IN ('CREATED','PENDING','SUCCEEDED','FAILED','CANCELLED','EXPIRED','SUPERSEDED'));

CREATE INDEX IF NOT EXISTS idx_booking_payment_deadline
  ON booking.bookings (payment_deadline)
  WHERE status IN ('PENDING_PAYMENT','PAYMENT_RECONCILIATION_PENDING');
CREATE INDEX IF NOT EXISTS idx_payint_reconciliation_due
  ON payments.payment_intents (next_reconciliation_at)
  WHERE status = 'PENDING';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM payments.payment_intents
    WHERE status = 'PENDING'
    GROUP BY booking_id, provider
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Cannot create ux_payment_intent_one_pending_per_booking: duplicate PENDING attempts require reconciliation first';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_payment_intent_one_pending_per_booking
  ON payments.payment_intents (booking_id, provider)
  WHERE status = 'PENDING';

COMMIT;
