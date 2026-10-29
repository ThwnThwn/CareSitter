\set ON_ERROR_STOP on
-- Counts only; no chat content or participant identifiers leave PostgreSQL.
SELECT chat_type, day, count(*) AS messages
FROM (
    SELECT 'BOOKING' AS chat_type, (created_at AT TIME ZONE 'UTC')::date AS day
    FROM booking.booking_chat_messages
    WHERE created_at >= now() - interval '30 days'
    UNION ALL
    SELECT 'SUPPORT', (created_at AT TIME ZONE 'UTC')::date
    FROM support.chat_messages
    WHERE created_at >= now() - interval '30 days'
) daily
GROUP BY chat_type, day ORDER BY day DESC, chat_type;

SELECT chat_type,
       count(*) FILTER (WHERE delivered_at IS NULL) AS pending,
       count(*) FILTER (WHERE delivered_at IS NULL AND attempts > 0) AS retrying,
       count(*) FILTER (WHERE delivered_at IS NULL AND dead_letter_at IS NOT NULL)
           AS dead_letters,
       round(extract(epoch FROM (now() - min(created_at)
           FILTER (WHERE delivered_at IS NULL)))::numeric, 1)
           AS oldest_pending_seconds,
       round((percentile_cont(0.95) WITHIN GROUP
           (ORDER BY extract(epoch FROM (delivered_at - created_at)))
           FILTER (WHERE delivered_at IS NOT NULL))::numeric, 1)
           AS delivery_lag_p95_seconds
FROM public.chat_firestore_outbox GROUP BY chat_type ORDER BY chat_type;
