-- BCHAT-13 expands the existing chat report rows into a durable worker queue and
-- records immutable administrative activity. Existing messages/conversations stay intact.
SET search_path = booking, public;

ALTER TABLE booking_chat_conversations
    ADD COLUMN legal_hold_at timestamptz,
    ADD COLUMN legal_hold_reason varchar(500),
    ADD COLUMN legal_hold_released_at timestamptz;

ALTER TABLE booking_chat_reports
    DROP CONSTRAINT booking_chat_reports_status_check,
    ADD COLUMN lease_until timestamptz,
    ADD COLUMN claim_token uuid,
    ADD CONSTRAINT booking_chat_reports_status_check
        CHECK (status IN ('PENDING','PROCESSING','LINKED','FAILED','DEAD_LETTER'));

CREATE INDEX ix_booking_chat_reports_lease
    ON booking_chat_reports(lease_until)
    WHERE status = 'PROCESSING';

CREATE INDEX ix_booking_chat_conversations_legal_hold
    ON booking_chat_conversations(legal_hold_at)
    WHERE legal_hold_at IS NOT NULL AND legal_hold_released_at IS NULL;
