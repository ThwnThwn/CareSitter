using Google.Cloud.Firestore;
using Microsoft.Extensions.Options;
using Npgsql;
using NpgsqlTypes;

namespace CareSitter.ApiHost.ChatFirestore;

public sealed record ChatFirestoreReconcileResult(
    int Scanned, int Missing, int Mismatched, int RefreshedConversations,
    DateTime? NextCreatedAt, Guid? NextMessageId);

public sealed class ChatFirestoreReconciler(
    IConfiguration configuration,
    ChatFirestoreClient firestore,
    IOptions<ChatFirestoreOptions> options)
{
    public async Task<int> EnqueueBackfillAsync(int batchSize, CancellationToken ct)
    {
        if (!options.Value.ProjectionEnabled)
            throw new InvalidOperationException("Chat Firestore projection is disabled.");
        await using var connection = new NpgsqlConnection(
            configuration.GetConnectionString("CareSitter"));
        await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand(
            "SELECT public.enqueue_chat_firestore_backfill(@batch_size)", connection);
        command.Parameters.AddWithValue("batch_size", Math.Clamp(batchSize, 1, 500));
        return (int)(await command.ExecuteScalarAsync(ct))!;
    }

    public async Task<ChatFirestoreReconcileResult> ScanAsync(string chatType,
        DateTime? afterCreatedAt, Guid? afterMessageId, int limit, CancellationToken ct)
    {
        if (!options.Value.ProjectionEnabled)
            throw new InvalidOperationException("Chat Firestore projection is disabled.");
        if (chatType is not ("BOOKING" or "SUPPORT") ||
            afterCreatedAt.HasValue != afterMessageId.HasValue)
            throw new ArgumentException("Invalid reconcile cursor or chat type.");
        var size = Math.Clamp(limit, 1, 100);
        await using var connection = new NpgsqlConnection(
            configuration.GetConnectionString("CareSitter"));
        await connection.OpenAsync(ct);
        var table = chatType == "BOOKING"
            ? "booking.booking_chat_messages" : "support.chat_messages";
        await using var command = new NpgsqlCommand($"""
            SELECT id, conversation_id, { (chatType == "BOOKING" ? "epoch_id" : "conversation_id") },
                   created_at
            FROM {table}
            WHERE (@after_at IS NULL OR (created_at, id) > (@after_at, @after_id))
            ORDER BY created_at, id LIMIT @limit
            """, connection);
        command.Parameters.Add("after_at", NpgsqlDbType.TimestampTz).Value =
            afterCreatedAt.HasValue ? afterCreatedAt.Value.ToUniversalTime() : DBNull.Value;
        command.Parameters.Add("after_id", NpgsqlDbType.Uuid).Value =
            afterMessageId.HasValue ? afterMessageId.Value : DBNull.Value;
        command.Parameters.AddWithValue("limit", size);
        var rows = new List<(Guid MessageId, Guid ConversationId, Guid EpochId, DateTime CreatedAt)>();
        await using (var reader = await command.ExecuteReaderAsync(ct))
            while (await reader.ReadAsync(ct))
                rows.Add((reader.GetGuid(0), reader.GetGuid(1), reader.GetGuid(2),
                    reader.GetDateTime(3)));

        var missing = 0;
        var mismatched = 0;
        var conversations = new HashSet<Guid>();
        foreach (var row in rows)
        {
            var expected = await ChatFirestoreMessage.ReadAsync(connection,
                chatType, row.MessageId, ct);
            if (expected is null) continue;
            var snapshot = await firestore.Database.Collection("chatConversations")
                .Document(row.ConversationId.ToString()).Collection("epochs")
                .Document(row.EpochId.ToString()).Collection("messages")
                .Document(row.MessageId.ToString()).GetSnapshotAsync(ct);
            var matches = snapshot.Exists && expected.All(field =>
                snapshot.TryGetValue<object>(field.Key, out var actual) &&
                Equals(field.Value, actual));
            if (!matches)
            {
                await using var enqueue = new NpgsqlCommand("""
                    INSERT INTO public.chat_firestore_outbox
                        (chat_type, action, conversation_id, epoch_id, message_id, source_id)
                    VALUES (@type, 'MESSAGE', @conversation, @epoch, @message, @message)
                    ON CONFLICT (chat_type, source_id) WHERE action = 'MESSAGE'
                    DO UPDATE SET delivered_at = NULL, dead_letter_at = NULL,
                        attempts = 0, available_at = now(), last_error = NULL
                    """, connection);
                enqueue.Parameters.AddWithValue("type", chatType);
                enqueue.Parameters.AddWithValue("conversation", row.ConversationId);
                enqueue.Parameters.AddWithValue("epoch", row.EpochId);
                enqueue.Parameters.AddWithValue("message", row.MessageId);
                await enqueue.ExecuteNonQueryAsync(ct);
                if (snapshot.Exists) mismatched++;
                else missing++;
            }
            conversations.Add(row.ConversationId);
        }
        // Refresh membership and current lifecycle even when the message exists.
        foreach (var conversationId in conversations)
        {
            await using var refresh = new NpgsqlCommand("""
                INSERT INTO public.chat_firestore_outbox(chat_type, action, conversation_id)
                VALUES (@type, 'REFRESH', @conversation)
                """, connection);
            refresh.Parameters.AddWithValue("type", chatType);
            refresh.Parameters.AddWithValue("conversation", conversationId);
            await refresh.ExecuteNonQueryAsync(ct);
        }
        var last = rows.LastOrDefault();
        return new ChatFirestoreReconcileResult(rows.Count, missing, mismatched, conversations.Count,
            rows.Count == 0 ? null : last.CreatedAt,
            rows.Count == 0 ? null : last.MessageId);
    }
}
