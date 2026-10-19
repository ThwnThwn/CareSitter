-- Booking Chat uses its own generic notification type. Keep the database
-- allowlist aligned with the public notification contract before enabling push.
ALTER TABLE support.notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE support.notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type IN ('BOOKING','CARE_TIMELINE','PAYMENT','PROMOTION','SYSTEM','SOS',
                   'BOOKING_OFFER','MATCHING_FAILED','SUPPORT_CHAT','BOOKING_CHAT'));
