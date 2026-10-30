-- User-level blocking for one-to-one booking chat. Blocking prevents new chat
-- messages in both directions but does not revoke history, booking access, SOS,
-- or CareSitter support access.
SET search_path = booking, public;

CREATE TABLE booking_chat_user_blocks (
    conversation_id uuid NOT NULL
        REFERENCES booking_chat_conversations(id) ON DELETE CASCADE,
    blocker_user_id uuid NOT NULL
        REFERENCES identity.users(id) ON DELETE CASCADE,
    blocked_user_id uuid NOT NULL
        REFERENCES identity.users(id) ON DELETE CASCADE,
    blocked_at timestamptz NOT NULL,
    unblocked_at timestamptz,
    PRIMARY KEY (conversation_id, blocker_user_id, blocked_user_id),
    CONSTRAINT booking_chat_user_block_distinct_users
        CHECK (blocker_user_id <> blocked_user_id),
    CONSTRAINT booking_chat_user_block_window
        CHECK (unblocked_at IS NULL OR unblocked_at >= blocked_at)
);

CREATE INDEX ix_booking_chat_user_blocks_active_target
    ON booking_chat_user_blocks(conversation_id, blocked_user_id)
    WHERE unblocked_at IS NULL;
