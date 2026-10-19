-- Booking chat belongs to the Booking module and follows each booking's
-- assignment/lifecycle. Message bodies never enter the realtime/outbox tables.
SET search_path = booking, public;

CREATE TABLE booking_chat_conversations (
    id uuid PRIMARY KEY,
    booking_id uuid NOT NULL UNIQUE REFERENCES booking.bookings(id) ON DELETE CASCADE,
    last_sequence bigint NOT NULL DEFAULT 0 CHECK (last_sequence >= 0),
    change_version bigint NOT NULL DEFAULT 1 CHECK (change_version > 0),
    scope_version bigint NOT NULL DEFAULT 1 CHECK (scope_version > 0),
    last_message_at timestamptz,
    grace_started_at timestamptz,
    write_closes_at timestamptz,
    dispute_locked_at timestamptz,
    write_blocked_at timestamptz,
    write_block_reason varchar(500),
    blocked_by_user_id uuid REFERENCES identity.users(id) ON DELETE SET NULL,
    retained_until timestamptz,
    hold_until timestamptz,
    purged_at timestamptz,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT booking_chat_grace_window_check CHECK (
        (grace_started_at IS NULL AND write_closes_at IS NULL) OR
        (grace_started_at IS NOT NULL AND write_closes_at > grace_started_at)
    ),
    CONSTRAINT booking_chat_block_check CHECK (
        (write_blocked_at IS NULL AND write_block_reason IS NULL AND blocked_by_user_id IS NULL) OR
        (write_blocked_at IS NOT NULL AND write_block_reason IS NOT NULL)
    )
);
CREATE INDEX ix_booking_chat_conversations_retention
    ON booking_chat_conversations(retained_until)
    WHERE purged_at IS NULL AND retained_until IS NOT NULL;

CREATE TABLE booking_chat_epochs (
    id uuid PRIMARY KEY,
    conversation_id uuid NOT NULL REFERENCES booking_chat_conversations(id) ON DELETE CASCADE,
    epoch_number integer NOT NULL CHECK (epoch_number > 0),
    caregiver_profile_id uuid NOT NULL REFERENCES people.caregiver_profiles(id),
    caregiver_user_id uuid NOT NULL REFERENCES identity.users(id),
    started_at timestamptz NOT NULL,
    ended_at timestamptz,
    CONSTRAINT booking_chat_epoch_window_check CHECK (
        ended_at IS NULL OR ended_at >= started_at
    ),
    CONSTRAINT uq_booking_chat_epoch_number UNIQUE (conversation_id, epoch_number)
);
CREATE UNIQUE INDEX uq_booking_chat_current_epoch
    ON booking_chat_epochs(conversation_id)
    WHERE ended_at IS NULL;
CREATE INDEX ix_booking_chat_epoch_caregiver
    ON booking_chat_epochs(caregiver_user_id, conversation_id, epoch_number DESC);

CREATE TABLE booking_chat_messages (
    id uuid PRIMARY KEY,
    conversation_id uuid NOT NULL REFERENCES booking_chat_conversations(id) ON DELETE CASCADE,
    epoch_id uuid NOT NULL REFERENCES booking_chat_epochs(id),
    sequence bigint NOT NULL CHECK (sequence > 0),
    sender_user_id uuid REFERENCES identity.users(id),
    sender_role varchar(20) CHECK (sender_role IN ('CUSTOMER','CAREGIVER')),
    kind varchar(20) NOT NULL CHECK (kind IN ('text','quick_message','system')),
    template_key varchar(100),
    template_version integer CHECK (template_version > 0),
    template_params jsonb,
    body_snapshot varchar(2000) NOT NULL
        CHECK (char_length(body_snapshot) BETWEEN 1 AND 2000)
        CHECK (octet_length(body_snapshot) <= 8192),
    idempotency_key uuid,
    payload_hash char(64),
    source_event_id uuid,
    created_at timestamptz NOT NULL,
    CONSTRAINT uq_booking_chat_message_sequence UNIQUE (conversation_id, sequence),
    CONSTRAINT booking_chat_message_shape_check CHECK (
        (
            kind = 'system' AND
            sender_user_id IS NULL AND sender_role IS NULL AND
            idempotency_key IS NULL AND payload_hash IS NULL AND
            source_event_id IS NOT NULL
        ) OR (
            kind IN ('text','quick_message') AND
            sender_user_id IS NOT NULL AND sender_role IS NOT NULL AND
            idempotency_key IS NOT NULL AND payload_hash IS NOT NULL AND
            source_event_id IS NULL
        )
    ),
    CONSTRAINT booking_chat_template_shape_check CHECK (
        (kind = 'quick_message' AND template_key IS NOT NULL AND
            template_version IS NOT NULL AND template_params IS NOT NULL) OR
        (kind <> 'quick_message' AND template_key IS NULL AND
            template_version IS NULL AND template_params IS NULL)
    )
);
CREATE INDEX ix_booking_chat_messages_recent
    ON booking_chat_messages(conversation_id, sequence DESC);
CREATE INDEX ix_booking_chat_messages_epoch
    ON booking_chat_messages(epoch_id, sequence);
CREATE UNIQUE INDEX uq_booking_chat_user_message_key
    ON booking_chat_messages(conversation_id, sender_user_id, idempotency_key)
    WHERE sender_user_id IS NOT NULL AND idempotency_key IS NOT NULL;
CREATE UNIQUE INDEX uq_booking_chat_system_event
    ON booking_chat_messages(conversation_id, source_event_id)
    WHERE source_event_id IS NOT NULL;

CREATE TABLE booking_chat_read_cursors (
    conversation_id uuid NOT NULL REFERENCES booking_chat_conversations(id) ON DELETE CASCADE,
    epoch_id uuid NOT NULL REFERENCES booking_chat_epochs(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    last_read_sequence bigint NOT NULL DEFAULT 0 CHECK (last_read_sequence >= 0),
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (conversation_id, epoch_id, user_id)
);

CREATE TABLE booking_chat_activity_events (
    id uuid PRIMARY KEY,
    conversation_id uuid NOT NULL REFERENCES booking_chat_conversations(id) ON DELETE CASCADE,
    actor_user_id uuid REFERENCES identity.users(id) ON DELETE SET NULL,
    action varchar(40) NOT NULL,
    reason varchar(500),
    created_at timestamptz NOT NULL
);
CREATE INDEX ix_booking_chat_activity
    ON booking_chat_activity_events(conversation_id, created_at, id);

CREATE TABLE booking_chat_outbox (
    event_id uuid PRIMARY KEY,
    conversation_id uuid NOT NULL REFERENCES booking_chat_conversations(id) ON DELETE CASCADE,
    epoch_id uuid REFERENCES booking_chat_epochs(id) ON DELETE CASCADE,
    recipient_user_id uuid NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    kind varchar(40) NOT NULL,
    change_version bigint NOT NULL CHECK (change_version > 0),
    message_id uuid REFERENCES booking_chat_messages(id) ON DELETE CASCADE,
    status varchar(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING','PROCESSING','SENT','FAILED','DROPPED','DEAD_LETTER')),
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    available_at timestamptz NOT NULL,
    lease_until timestamptz,
    last_error varchar(500),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT uq_booking_chat_outbox_delivery
        UNIQUE (conversation_id, recipient_user_id, event_id)
);
CREATE INDEX ix_booking_chat_outbox_pending
    ON booking_chat_outbox(status, available_at, created_at)
    WHERE status IN ('PENDING','FAILED');
CREATE INDEX ix_booking_chat_outbox_lease
    ON booking_chat_outbox(lease_until)
    WHERE status = 'PROCESSING';

CREATE TABLE booking_chat_reports (
    id uuid PRIMARY KEY,
    message_id uuid NOT NULL REFERENCES booking_chat_messages(id) ON DELETE CASCADE,
    reporter_user_id uuid NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    reason varchar(500) NOT NULL CHECK (char_length(btrim(reason)) > 0),
    support_ticket_id uuid REFERENCES support.support_tickets(id) ON DELETE SET NULL,
    status varchar(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING','LINKED','FAILED')),
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    available_at timestamptz NOT NULL,
    last_error varchar(500),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT uq_booking_chat_report UNIQUE (message_id, reporter_user_id)
);
CREATE INDEX ix_booking_chat_reports_pending
    ON booking_chat_reports(status, available_at, created_at)
    WHERE status IN ('PENDING','FAILED');
