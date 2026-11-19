namespace CareSitter.Modules.Support.Infrastructure;

internal static class NotificationInboxSql
{
    private const string Keyed = """
        WITH keyed AS (
            SELECT id, type, created_at, read_at, chat_message_id, data ->> 'messageId' AS message_id,
                type || ':' || COALESCE(
                    CASE type
                        WHEN 'BOOKING_CHAT' THEN COALESCE(NULLIF(data ->> 'bookingId', ''),
                            NULLIF(data ->> 'conversationId', ''))
                        WHEN 'SUPPORT_CHAT' THEN NULLIF(data ->> 'conversationId', '')
                    END, id::text) AS group_key
            FROM support.notifications
            WHERE user_id = {0}
        )
        """;

    // The delivery head anchors read-group. The message sequence independently selects the preview.
    internal const string List = Keyed + """
        , heads AS (
            SELECT DISTINCT ON (group_key) id, group_key, created_at,
                count(*) FILTER (WHERE read_at IS NULL) OVER (PARTITION BY group_key) AS unread
            FROM keyed
            ORDER BY group_key, created_at DESC, id DESC
        ), totals AS (
            SELECT count(*)::integer AS groups, COALESCE(sum(unread), 0)::integer AS unread,
                COALESCE(bit_xor(hashtextextended(id::text || ':' || unread::text, 0)), 0)::text AS version
            FROM heads
        ), page AS (
            SELECT * FROM heads ORDER BY created_at DESC, id DESC LIMIT {1} OFFSET {2}
        ), booking_refs AS (
            SELECT k.group_key, array_agg(DISTINCT k.message_id) AS ids
            FROM keyed k JOIN page p USING (group_key)
            WHERE k.type = 'BOOKING_CHAT' AND k.message_id IS NOT NULL
            GROUP BY k.group_key
        ), support_messages AS (
            SELECT DISTINCT ON (k.group_key) k.group_key, m.body, m.created_at
            FROM keyed k JOIN page p USING (group_key)
            JOIN support.chat_messages m ON m.id = k.chat_message_id
            JOIN support.chat_conversations c ON c.id = m.conversation_id
            WHERE k.type = 'SUPPORT_CHAT' AND c.owner_user_id = {0}
              AND m.sender_user_id <> {0} AND m.sender_role = 'ADMIN'
              AND k.group_key = 'SUPPORT_CHAT:' || c.id::text
            ORDER BY k.group_key, m.sequence DESC
        )
        SELECT p.id AS "Id", p.group_key AS "GroupKey", n.type AS "Type", n.title AS "Title",
            n.body AS "Body", n.data::text AS "Data", p.created_at AS "CreatedAt",
            p.unread::integer AS "UnreadCount", b.ids AS "BookingMessageIds",
            m.body AS "SupportBody", m.created_at AS "SupportSentAt",
            t.groups AS "TotalGroups", t.unread AS "TotalUnread", t.version AS "Version"
        FROM totals t LEFT JOIN page p ON true
        LEFT JOIN support.notifications n ON n.id = p.id
        LEFT JOIN booking_refs b ON b.group_key = p.group_key
        LEFT JOIN support_messages m ON m.group_key = p.group_key
        ORDER BY p.created_at DESC, p.id DESC
        """;

    internal const string MarkRead = Keyed + """
        UPDATE support.notifications AS n SET read_at = {2}
        FROM keyed target JOIN keyed anchor ON target.group_key = anchor.group_key
        WHERE anchor.id = {1} AND n.id = target.id AND n.read_at IS NULL
          AND (target.created_at, target.id) <= (anchor.created_at, anchor.id)
        """;
}
