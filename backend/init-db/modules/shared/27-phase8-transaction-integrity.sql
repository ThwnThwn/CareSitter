-- Phase 8: golden-flow transaction integrity and dispute-window settlement.
-- Safe to run repeatedly.

BEGIN;

ALTER TABLE booking.bookings
  ADD COLUMN IF NOT EXISTS dispute_window_hours int NOT NULL DEFAULT 48,
  ADD COLUMN IF NOT EXISTS settlement_released_at timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bookings_dispute_window_hours_check'
      AND connamespace = 'booking'::regnamespace
  ) THEN
    ALTER TABLE booking.bookings
      ADD CONSTRAINT bookings_dispute_window_hours_check
      CHECK (dispute_window_hours BETWEEN 1 AND 720);
  END IF;
END $$;

-- A beneficiary cannot have two active care bookings whose time windows overlap.
-- The advisory lock serializes writes for one beneficiary and lets an existing
-- database upgrade without deleting legacy rows that already overlap.
CREATE OR REPLACE FUNCTION booking.prevent_active_beneficiary_booking_overlap()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status NOT IN ('COMPLETED','CANCELLED','MATCHING_FAILED','REFUNDED') THEN
    PERFORM pg_advisory_xact_lock(hashtextextended(NEW.beneficiary_id::text, 0));

    IF EXISTS (
      SELECT 1
      FROM booking.bookings existing
      WHERE existing.id <> NEW.id
        AND existing.beneficiary_id = NEW.beneficiary_id
        AND existing.status NOT IN ('COMPLETED','CANCELLED','MATCHING_FAILED','REFUNDED')
        AND tstzrange(existing.scheduled_start, existing.scheduled_end, '[)')
            && tstzrange(NEW.scheduled_start, NEW.scheduled_end, '[)')
    ) THEN
      RAISE EXCEPTION 'active beneficiary booking overlap'
        USING ERRCODE = '23P01',
              CONSTRAINT = 'ex_active_beneficiary_booking_overlap';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_active_beneficiary_booking_overlap
  ON booking.bookings;
CREATE TRIGGER trg_prevent_active_beneficiary_booking_overlap
BEFORE INSERT OR UPDATE OF beneficiary_id, scheduled_start, scheduled_end, status
ON booking.bookings
FOR EACH ROW
EXECUTE FUNCTION booking.prevent_active_beneficiary_booking_overlap();

-- Add the native exclusion constraint when current data permits it. The trigger
-- above remains the equivalent race-safe guard for upgraded legacy databases.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ex_active_beneficiary_booking_overlap'
      AND connamespace = 'booking'::regnamespace
  ) AND NOT EXISTS (
    SELECT 1
    FROM booking.bookings first_booking
    JOIN booking.bookings second_booking
      ON first_booking.id < second_booking.id
     AND first_booking.beneficiary_id = second_booking.beneficiary_id
     AND first_booking.status NOT IN ('COMPLETED','CANCELLED','MATCHING_FAILED','REFUNDED')
     AND second_booking.status NOT IN ('COMPLETED','CANCELLED','MATCHING_FAILED','REFUNDED')
     AND tstzrange(first_booking.scheduled_start, first_booking.scheduled_end, '[)')
         && tstzrange(second_booking.scheduled_start, second_booking.scheduled_end, '[)')
  ) THEN
    ALTER TABLE booking.bookings
      ADD CONSTRAINT ex_active_beneficiary_booking_overlap
      EXCLUDE USING gist (
        beneficiary_id WITH =,
        tstzrange(scheduled_start, scheduled_end, '[)') WITH &&
      ) WHERE (status NOT IN ('COMPLETED','CANCELLED','MATCHING_FAILED','REFUNDED'));
  ELSIF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ex_active_beneficiary_booking_overlap'
      AND connamespace = 'booking'::regnamespace
  ) THEN
    RAISE NOTICE 'Skipped exclusion constraint because legacy active bookings overlap; trigger guard is active.';
  END IF;
END $$;

ALTER TABLE support.disputes
  DROP CONSTRAINT IF EXISTS disputes_refund_amount_check,
  DROP CONSTRAINT IF EXISTS disputes_caregiver_penalty_amount_check;

ALTER TABLE support.disputes
  ADD CONSTRAINT disputes_refund_amount_check
    CHECK (refund_amount IS NULL OR refund_amount >= 0),
  ADD CONSTRAINT disputes_caregiver_penalty_amount_check
    CHECK (caregiver_penalty_amount IS NULL OR caregiver_penalty_amount >= 0);

CREATE UNIQUE INDEX IF NOT EXISTS ux_ledger_booking_penalty
  ON payments.ledger_entries (booking_id, transaction_type)
  WHERE booking_id IS NOT NULL AND transaction_type = 'PENALTY';

CREATE INDEX IF NOT EXISTS ix_bookings_mature_settlement
  ON booking.bookings (actual_end, dispute_window_hours)
  WHERE status = 'COMPLETED' AND settlement_released_at IS NULL;

COMMIT;
