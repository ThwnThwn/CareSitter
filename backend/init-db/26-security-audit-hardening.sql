-- Attribute booking status audit entries to the authenticated actor when the
-- change originates from an API request. Background jobs remain SYSTEM.

BEGIN;

CREATE OR REPLACE FUNCTION booking.log_booking_status()
RETURNS trigger AS $$
DECLARE
  actor_id_text text := current_setting('app.current_user_id', true);
  actor_roles text := current_setting('app.current_user_role', true);
  actor_id uuid := NULL;
BEGIN
  IF actor_id_text IS NOT NULL AND actor_id_text <> '' THEN
    actor_id := actor_id_text::uuid;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO identity.audit_logs (
      actor_user_id, actor_role, action, entity_type, entity_id,
      before_data, after_data, created_at)
    VALUES (
      actor_id,
      COALESCE(NULLIF(actor_roles, ''), 'SYSTEM'),
      'BOOKING_STATUS_CHANGED',
      'Booking',
      NEW.id,
      jsonb_build_object('status', OLD.status),
      jsonb_build_object(
        'status', NEW.status,
        'checkout_source', NEW.checkout_source,
        'checkout_pending_review_at', NEW.checkout_pending_review_at),
      now());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;
