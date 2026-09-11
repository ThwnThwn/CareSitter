-- Upgrade an existing CareSitter database for VNPay Sandbox/IPN idempotency.
-- Safe to run more than once.

ALTER TABLE payments.payment_intents
  ADD COLUMN IF NOT EXISTS provider_order_ref varchar(100);

CREATE TABLE IF NOT EXISTS booking.caregiver_slot_holds (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id      uuid NOT NULL REFERENCES booking.bookings(id) ON DELETE CASCADE,
  caregiver_id    uuid NOT NULL REFERENCES people.caregiver_profiles(id),
  scheduled_start timestamptz NOT NULL,
  scheduled_end   timestamptz NOT NULL,
  expires_at      timestamptz NOT NULL,
  status          varchar(20) NOT NULL DEFAULT 'HELD'
                  CHECK (status IN ('HELD','COMMITTED','RELEASED')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  released_at     timestamptz,
  CONSTRAINT caregiver_slot_hold_schedule_check CHECK (scheduled_end > scheduled_start)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_slot_hold_booking
  ON booking.caregiver_slot_holds (booking_id)
  WHERE status IN ('HELD','COMMITTED');

CREATE INDEX IF NOT EXISTS idx_slot_hold_caregiver_status_expiry
  ON booking.caregiver_slot_holds (caregiver_id, status, expires_at);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ex_active_caregiver_slot_hold_overlap'
      AND connamespace = 'booking'::regnamespace
  ) THEN
    ALTER TABLE booking.caregiver_slot_holds
      ADD CONSTRAINT ex_active_caregiver_slot_hold_overlap
      EXCLUDE USING gist (
        caregiver_id WITH =,
        tstzrange(scheduled_start, scheduled_end, '[)') WITH &&
      ) WHERE (status IN ('HELD','COMMITTED'));
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_payint_provider_order_ref
  ON payments.payment_intents (provider, provider_order_ref)
  WHERE provider_order_ref IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_ledger_booking_transaction_type
  ON payments.ledger_entries (booking_id, transaction_type)
  WHERE booking_id IS NOT NULL
    AND transaction_type IN ('ESCROW_LOCK', 'PLATFORM_FEE', 'CAREGIVER_EARNING');

CREATE INDEX IF NOT EXISTS idx_payint_booking_status
  ON payments.payment_intents (booking_id, status);
