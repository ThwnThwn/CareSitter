\set ON_ERROR_STOP on
BEGIN;
DO $test$
DECLARE
    owner_id uuid;
    admin_id uuid;
    caregiver_user_id uuid;
    caregiver_profile_id uuid;
    booking_id uuid := gen_random_uuid();
    booking_chat_id uuid := gen_random_uuid();
    booking_epoch_id uuid := gen_random_uuid();
    booking_message_id uuid := gen_random_uuid();
    ticket_id uuid := gen_random_uuid();
    support_chat_id uuid := gen_random_uuid();
    support_message_id uuid := gen_random_uuid();
BEGIN
    SELECT id INTO owner_id FROM identity.users ORDER BY id LIMIT 1;
    SELECT id INTO admin_id FROM identity.users WHERE id <> owner_id ORDER BY id LIMIT 1;
    SELECT id, user_id INTO caregiver_profile_id, caregiver_user_id
    FROM people.caregiver_profiles ORDER BY id LIMIT 1;
    IF owner_id IS NULL OR admin_id IS NULL OR caregiver_user_id IS NULL THEN
        RAISE EXCEPTION 'Test database needs seed users and caregiver';
    END IF;

    INSERT INTO support.support_tickets(id, user_id, type, title, description)
    VALUES (ticket_id, owner_id, 'GENERAL', 'Projection test', 'Projection test');
    INSERT INTO support.chat_conversations
        (id, ticket_id, owner_user_id, create_key, create_payload_hash,
         last_message_at, created_at, updated_at)
    VALUES (support_chat_id, ticket_id, owner_id, gen_random_uuid(),
        repeat('a', 64), now(), now(), now());
    INSERT INTO support.chat_messages
        (id, conversation_id, sequence, sender_user_id, sender_role,
         idempotency_key, body, payload_hash, created_at)
    VALUES (support_message_id, support_chat_id, 1, owner_id, 'CUSTOMER',
        gen_random_uuid(), 'Test', repeat('b', 64), now());
    UPDATE support.support_tickets SET status = 'IN_PROGRESS',
        assigned_admin_id = admin_id WHERE id = ticket_id;

    INSERT INTO booking.bookings
        (id, customer_id, beneficiary_id, caregiver_id, address_id,
         service_type_id, scheduled_start, scheduled_end, created_at, updated_at)
    SELECT booking_id, owner_id,
        (SELECT id FROM people.beneficiaries LIMIT 1), caregiver_profile_id,
        (SELECT id FROM catalog.addresses LIMIT 1),
        (SELECT id FROM catalog.service_types LIMIT 1),
        now() + interval '1 day', now() + interval '2 days', now(), now();
    INSERT INTO booking.booking_chat_conversations
        (id, booking_id, last_sequence, change_version, scope_version,
         last_message_at, created_at, updated_at)
    VALUES (booking_chat_id, booking_id, 1, 1, 1, now(), now(), now());
    INSERT INTO booking.booking_chat_epochs
        (id, conversation_id, epoch_number, caregiver_profile_id,
         caregiver_user_id, started_at)
    VALUES (booking_epoch_id, booking_chat_id, 1, caregiver_profile_id,
        caregiver_user_id, now());
    INSERT INTO booking.booking_chat_messages
        (id, conversation_id, epoch_id, sequence, kind, body_snapshot,
         source_event_id, created_at)
    VALUES (booking_message_id, booking_chat_id, booking_epoch_id, 1,
        'system', 'Test', gen_random_uuid(), now());
    UPDATE booking.booking_chat_conversations SET purged_at = now()
    WHERE id = booking_chat_id;
    UPDATE identity.users SET status = 'SUSPENDED' WHERE id = owner_id;

    IF (SELECT count(*) FROM public.chat_firestore_outbox
        WHERE action = 'MESSAGE' AND message_id IN (booking_message_id, support_message_id)) <> 2 THEN
        RAISE EXCEPTION 'Both message triggers must enqueue exactly one event';
    END IF;
    IF (SELECT count(*) FROM public.chat_firestore_outbox
        WHERE action = 'PURGE' AND conversation_id = booking_chat_id) <> 1 THEN
        RAISE EXCEPTION 'Retention purge must enqueue deletion';
    END IF;
    IF (SELECT count(*) FROM public.chat_firestore_outbox
        WHERE action = 'REFRESH' AND conversation_id = support_chat_id) <> 1 THEN
        RAISE EXCEPTION 'Support assignment must enqueue membership refresh';
    END IF;
    IF (SELECT count(*) FROM public.chat_firestore_outbox
        WHERE action = 'USER_ACCESS' AND user_id = owner_id) <> 1 THEN
        RAISE EXCEPTION 'Account lock must enqueue access refresh';
    END IF;
    IF public.enqueue_chat_firestore_backfill(10) <> 0 THEN
        RAISE EXCEPTION 'Backfill must not duplicate tracked messages';
    END IF;
    DELETE FROM support.chat_messages WHERE id = support_message_id;
    DELETE FROM support.chat_conversations WHERE id = support_chat_id;
    IF (SELECT count(*) FROM public.chat_firestore_outbox
        WHERE action = 'PURGE' AND conversation_id = support_chat_id) <> 1 THEN
        RAISE EXCEPTION 'Support conversation deletion must enqueue projection purge';
    END IF;
END $test$;
ROLLBACK;
