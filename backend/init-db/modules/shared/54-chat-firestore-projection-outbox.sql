-- Durable, identifier-only events for the optional Firestore chat read model.
-- Message bodies stay in their owning module's PostgreSQL table until projected.
CREATE TABLE public.chat_firestore_outbox (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    chat_type varchar(10) NOT NULL CHECK (chat_type IN ('BOOKING', 'SUPPORT', 'USER')),
    action varchar(20) NOT NULL CHECK (action IN ('MESSAGE', 'REFRESH', 'PURGE', 'USER_ACCESS')),
    conversation_id uuid,
    epoch_id uuid,
    message_id uuid,
    user_id uuid,
    source_id uuid,
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    available_at timestamptz NOT NULL DEFAULT now(),
    delivered_at timestamptz,
    dead_letter_at timestamptz,
    last_error varchar(200),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chat_firestore_outbox_shape CHECK (
        (action = 'USER_ACCESS' AND chat_type = 'USER' AND user_id IS NOT NULL
            AND conversation_id IS NULL AND message_id IS NULL)
        OR (action = 'MESSAGE' AND chat_type IN ('BOOKING', 'SUPPORT')
            AND conversation_id IS NOT NULL AND message_id IS NOT NULL AND source_id = message_id)
        OR (action IN ('REFRESH', 'PURGE') AND chat_type IN ('BOOKING', 'SUPPORT')
            AND conversation_id IS NOT NULL AND message_id IS NULL)
    )
);
CREATE UNIQUE INDEX uq_chat_firestore_message_event
    ON public.chat_firestore_outbox(chat_type, source_id)
    WHERE action = 'MESSAGE';
CREATE INDEX ix_chat_firestore_outbox_pending
    ON public.chat_firestore_outbox(id)
    WHERE delivered_at IS NULL AND dead_letter_at IS NULL;
CREATE INDEX ix_chat_firestore_outbox_urgent
    ON public.chat_firestore_outbox(id)
    WHERE delivered_at IS NULL AND action IN ('PURGE', 'USER_ACCESS');
CREATE INDEX ix_chat_firestore_outbox_access_barrier
    ON public.chat_firestore_outbox(id)
    WHERE delivered_at IS NULL AND action IN ('REFRESH', 'PURGE', 'USER_ACCESS');

CREATE TABLE public.chat_firestore_reconcile_cursors (
    chat_type varchar(10) PRIMARY KEY CHECK (chat_type IN ('BOOKING', 'SUPPORT')),
    after_created_at timestamptz,
    after_message_id uuid,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((after_created_at IS NULL) = (after_message_id IS NULL))
);
INSERT INTO public.chat_firestore_reconcile_cursors(chat_type) VALUES ('BOOKING'), ('SUPPORT');

CREATE FUNCTION public.enqueue_booking_chat_firestore_message() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.chat_firestore_outbox
        (chat_type, action, conversation_id, epoch_id, message_id, source_id)
    VALUES ('BOOKING', 'MESSAGE', NEW.conversation_id, NEW.epoch_id, NEW.id, NEW.id)
    ON CONFLICT DO NOTHING;
    RETURN NEW;
END $$;
CREATE TRIGGER booking_chat_firestore_message
    AFTER INSERT ON booking.booking_chat_messages FOR EACH ROW
    EXECUTE FUNCTION public.enqueue_booking_chat_firestore_message();

CREATE FUNCTION public.enqueue_support_chat_firestore_message() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.chat_firestore_outbox
        (chat_type, action, conversation_id, epoch_id, message_id, source_id)
    VALUES ('SUPPORT', 'MESSAGE', NEW.conversation_id, NEW.conversation_id, NEW.id, NEW.id)
    ON CONFLICT DO NOTHING;
    RETURN NEW;
END $$;
CREATE TRIGGER support_chat_firestore_message
    AFTER INSERT ON support.chat_messages FOR EACH ROW
    EXECUTE FUNCTION public.enqueue_support_chat_firestore_message();

CREATE FUNCTION public.enqueue_booking_chat_firestore_refresh() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' OR NEW.ended_at IS DISTINCT FROM OLD.ended_at THEN
        INSERT INTO public.chat_firestore_outbox(chat_type, action, conversation_id, epoch_id)
        VALUES ('BOOKING', 'REFRESH', NEW.conversation_id, NEW.id);
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER booking_chat_firestore_epoch
    AFTER INSERT OR UPDATE OF ended_at ON booking.booking_chat_epochs FOR EACH ROW
    EXECUTE FUNCTION public.enqueue_booking_chat_firestore_refresh();

CREATE FUNCTION public.enqueue_booking_chat_firestore_state() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.purged_at IS NOT NULL AND OLD.purged_at IS NULL THEN
        INSERT INTO public.chat_firestore_outbox(chat_type, action, conversation_id)
        VALUES ('BOOKING', 'PURGE', NEW.id);
    ELSIF NEW.purged_at IS NULL THEN
        INSERT INTO public.chat_firestore_outbox(chat_type, action, conversation_id)
        VALUES ('BOOKING', 'REFRESH', NEW.id);
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER booking_chat_firestore_state
    AFTER UPDATE OF change_version, scope_version, write_blocked_at,
        dispute_locked_at, retained_until, hold_until,
        legal_hold_at, legal_hold_released_at, purged_at
    ON booking.booking_chat_conversations FOR EACH ROW
    EXECUTE FUNCTION public.enqueue_booking_chat_firestore_state();

CREATE FUNCTION public.enqueue_booking_chat_firestore_assignment() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE chat_id uuid;
BEGIN
    SELECT id INTO chat_id FROM booking.booking_chat_conversations WHERE booking_id = NEW.id;
    IF chat_id IS NOT NULL THEN
        INSERT INTO public.chat_firestore_outbox(chat_type, action, conversation_id)
        VALUES ('BOOKING', 'REFRESH', chat_id);
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER booking_chat_firestore_assignment
    AFTER UPDATE OF caregiver_id ON booking.bookings FOR EACH ROW
    WHEN (OLD.caregiver_id IS DISTINCT FROM NEW.caregiver_id)
    EXECUTE FUNCTION public.enqueue_booking_chat_firestore_assignment();

CREATE FUNCTION public.enqueue_support_chat_firestore_state() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE chat_id uuid;
BEGIN
    SELECT id INTO chat_id FROM support.chat_conversations WHERE ticket_id = NEW.id;
    IF chat_id IS NOT NULL THEN
        INSERT INTO public.chat_firestore_outbox(chat_type, action, conversation_id)
        VALUES ('SUPPORT', 'REFRESH', chat_id);
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER support_chat_firestore_state
    AFTER UPDATE OF status, assigned_admin_id ON support.support_tickets FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status OR
          OLD.assigned_admin_id IS DISTINCT FROM NEW.assigned_admin_id)
    EXECUTE FUNCTION public.enqueue_support_chat_firestore_state();

CREATE FUNCTION public.enqueue_chat_firestore_user_access() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.chat_firestore_outbox(chat_type, action, user_id)
    VALUES ('USER', 'USER_ACCESS', NEW.id);
    RETURN NEW;
END $$;
CREATE TRIGGER chat_firestore_user_access
    AFTER UPDATE OF status, admin_is_active, roles ON identity.users FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status OR
          OLD.admin_is_active IS DISTINCT FROM NEW.admin_is_active OR
          OLD.roles IS DISTINCT FROM NEW.roles)
    EXECUTE FUNCTION public.enqueue_chat_firestore_user_access();

CREATE FUNCTION public.enqueue_chat_firestore_conversation_delete() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.chat_firestore_outbox(chat_type, action, conversation_id)
    VALUES (CASE WHEN TG_TABLE_SCHEMA = 'booking' THEN 'BOOKING' ELSE 'SUPPORT' END,
        'PURGE', OLD.id);
    RETURN OLD;
END $$;
CREATE TRIGGER booking_chat_firestore_delete
    AFTER DELETE ON booking.booking_chat_conversations FOR EACH ROW
    EXECUTE FUNCTION public.enqueue_chat_firestore_conversation_delete();
CREATE TRIGGER support_chat_firestore_delete
    AFTER DELETE ON support.chat_conversations FOR EACH ROW
    EXECUTE FUNCTION public.enqueue_chat_firestore_conversation_delete();

-- Run repeatedly in bounded batches before enabling client reads. Existing rows
-- are not copied into the outbox by CREATE TRIGGER.
CREATE FUNCTION public.enqueue_chat_firestore_backfill(batch_size integer)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE inserted_count integer := 0;
DECLARE added integer;
BEGIN
    IF batch_size < 1 OR batch_size > 500 THEN
        RAISE EXCEPTION 'batch_size must be between 1 and 500';
    END IF;
    INSERT INTO public.chat_firestore_outbox
        (chat_type, action, conversation_id, epoch_id, message_id, source_id)
    SELECT 'BOOKING', 'MESSAGE', m.conversation_id, m.epoch_id, m.id, m.id
    FROM booking.booking_chat_messages m
    WHERE NOT EXISTS (SELECT 1 FROM public.chat_firestore_outbox o
        WHERE o.chat_type = 'BOOKING' AND o.action = 'MESSAGE' AND o.source_id = m.id)
    ORDER BY m.created_at, m.id LIMIT batch_size
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS added = ROW_COUNT;
    inserted_count := inserted_count + added;

    INSERT INTO public.chat_firestore_outbox
        (chat_type, action, conversation_id, epoch_id, message_id, source_id)
    SELECT 'SUPPORT', 'MESSAGE', m.conversation_id, m.conversation_id, m.id, m.id
    FROM support.chat_messages m
    WHERE NOT EXISTS (SELECT 1 FROM public.chat_firestore_outbox o
        WHERE o.chat_type = 'SUPPORT' AND o.action = 'MESSAGE' AND o.source_id = m.id)
    ORDER BY m.created_at, m.id LIMIT batch_size
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS added = ROW_COUNT;
    RETURN inserted_count + added;
END $$;
