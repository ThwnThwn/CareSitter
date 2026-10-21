-- A database upgraded after booking chat can apply 40-support-chat later.
-- Restore the combined notification type allowlist without mutating applied migrations.
ALTER TABLE support.notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE support.notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type IN ('BOOKING','CARE_TIMELINE','PAYMENT','PROMOTION','SYSTEM','SOS',
                   'BOOKING_OFFER','MATCHING_FAILED','SUPPORT_CHAT','BOOKING_CHAT'));
