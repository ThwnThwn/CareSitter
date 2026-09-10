-- ========================================================
-- Hotfix: Add checkout_pending_review_at & checkout_source
-- to existing booking.bookings table in PostgreSQL
-- ========================================================

ALTER TABLE booking.bookings
  ADD COLUMN IF NOT EXISTS checkout_pending_review_at timestamptz,
  ADD COLUMN IF NOT EXISTS checkout_source varchar(30)
    CHECK (checkout_source IN ('CaregiverRequested','SystemTimeout','AdminOverride'));

-- Ensure status check constraint includes MATCHING_FAILED and CHECKOUT_PENDING_REVIEW
ALTER TABLE booking.bookings
  DROP CONSTRAINT IF EXISTS bookings_status_check;

ALTER TABLE booking.bookings
  ADD CONSTRAINT bookings_status_check
  CHECK (status IN ('DRAFT','PENDING_PAYMENT','CONFIRMED','CAREGIVER_ACCEPTED',
                    'MATCHING_FAILED',
                    'CAREGIVER_EN_ROUTE','IN_PROGRESS','CHECKOUT_PENDING_REVIEW',
                    'COMPLETED','CANCELLED','CRISIS','DISPUTED','REFUNDED'));

-- Update trigger function to record checkout fields in audit log
CREATE OR REPLACE FUNCTION booking.log_booking_status()
RETURNS trigger AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO identity.audit_logs (actor_user_id, actor_role, action, entity_type, entity_id, after_data, created_at)
    VALUES (NULL, 'SYSTEM', 'booking.status_change', 'booking', NEW.id,
            jsonb_build_object('from', OLD.status, 'to', NEW.status,
                               'checkout_source', NEW.checkout_source,
                               'checkout_pending_review_at', NEW.checkout_pending_review_at), now());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure notification type check constraint includes BOOKING_OFFER and MATCHING_FAILED
ALTER TABLE support.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE support.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN ('BOOKING','CARE_TIMELINE','PAYMENT','PROMOTION','SYSTEM','SOS','BOOKING_OFFER','MATCHING_FAILED'));

