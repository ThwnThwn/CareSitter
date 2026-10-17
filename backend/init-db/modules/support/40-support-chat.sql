-- Support conversations are one-to-one with tickets. Existing tickets remain valid.
ALTER TABLE support.support_tickets
    ADD COLUMN version bigint NOT NULL DEFAULT 1;

CREATE TABLE support.chat_conversations (
    id uuid PRIMARY KEY,
    ticket_id uuid NOT NULL UNIQUE REFERENCES support.support_tickets(id),
    owner_user_id uuid NOT NULL REFERENCES identity.users(id),
    create_key uuid NOT NULL,
    create_payload_hash char(64) NOT NULL,
    last_sequence bigint NOT NULL DEFAULT 0 CHECK (last_sequence >= 0),
    staff_last_read_sequence bigint NOT NULL DEFAULT 0 CHECK (staff_last_read_sequence >= 0),
    version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
    last_message_at timestamptz NOT NULL,
    closed_at timestamptz,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT chat_read_within_sequence CHECK (staff_last_read_sequence <= last_sequence),
    CONSTRAINT uq_chat_owner_create_key UNIQUE (owner_user_id, create_key)
);
CREATE UNIQUE INDEX uq_chat_open_owner ON support.chat_conversations(owner_user_id)
    WHERE closed_at IS NULL;
CREATE INDEX ix_chat_owner_recent ON support.chat_conversations(owner_user_id, created_at DESC, id DESC);

CREATE TABLE support.chat_messages (
    id uuid PRIMARY KEY,
    conversation_id uuid NOT NULL REFERENCES support.chat_conversations(id),
    sequence bigint NOT NULL CHECK (sequence > 0),
    sender_user_id uuid NOT NULL REFERENCES identity.users(id),
    sender_role varchar(20) NOT NULL CHECK (sender_role IN ('CUSTOMER','CAREGIVER','ADMIN')),
    idempotency_key uuid NOT NULL,
    body varchar(2000) NOT NULL CHECK (length(body) BETWEEN 1 AND 2000),
    payload_hash char(64) NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT uq_chat_message_sequence UNIQUE (conversation_id, sequence),
    CONSTRAINT uq_chat_message_key UNIQUE (conversation_id, sender_user_id, idempotency_key)
);
CREATE INDEX ix_chat_messages_recent ON support.chat_messages(conversation_id, sequence DESC);

CREATE TABLE support.chat_read_cursors (
    conversation_id uuid NOT NULL REFERENCES support.chat_conversations(id),
    user_id uuid NOT NULL REFERENCES identity.users(id),
    last_read_sequence bigint NOT NULL DEFAULT 0 CHECK (last_read_sequence >= 0),
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE support.chat_activity_events (
    id uuid PRIMARY KEY,
    conversation_id uuid NOT NULL REFERENCES support.chat_conversations(id),
    actor_user_id uuid NOT NULL REFERENCES identity.users(id),
    action varchar(30) NOT NULL,
    from_status varchar(20),
    to_status varchar(20),
    from_admin_id uuid,
    to_admin_id uuid,
    reason varchar(2000),
    created_at timestamptz NOT NULL
);
CREATE INDEX ix_chat_activities ON support.chat_activity_events(conversation_id, created_at, id);

-- Chat notifications have a stable event identity even when push is disabled.
ALTER TABLE support.notifications
    ADD COLUMN chat_message_id uuid UNIQUE REFERENCES support.chat_messages(id);
ALTER TABLE support.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE support.notifications ADD CONSTRAINT notifications_type_check
    CHECK (type IN ('BOOKING','CARE_TIMELINE','PAYMENT','PROMOTION','SYSTEM','SOS',
                   'BOOKING_OFFER','MATCHING_FAILED','SUPPORT_CHAT'));
