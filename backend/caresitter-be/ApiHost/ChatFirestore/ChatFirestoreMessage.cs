using Npgsql;

namespace CareSitter.ApiHost.ChatFirestore;

/// <summary>The allowlist of message fields copied to the private read model.</summary>
internal static class ChatFirestoreMessage
{
    internal static async Task<Dictionary<string, object?>?> ReadAsync(
        NpgsqlConnection connection, string chatType, Guid messageId, CancellationToken ct)
    {
        var sql = chatType == "BOOKING" ? """
            SELECT sequence, sender_user_id, sender_role, kind, template_key,
                   body_snapshot, created_at
            FROM booking.booking_chat_messages WHERE id = @id
            """ : """
            SELECT sequence, sender_user_id, sender_role, 'text', NULL::text,
                   body, created_at
            FROM support.chat_messages WHERE id = @id
            """;
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("id", messageId);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) return null;
        return new Dictionary<string, object?>
        {
            ["id"] = messageId.ToString(), ["sequence"] = reader.GetInt64(0),
            ["senderUserId"] = reader.IsDBNull(1) ? null : reader.GetGuid(1).ToString(),
            ["senderRole"] = reader.IsDBNull(2) ? null : reader.GetString(2),
            ["kind"] = reader.GetString(3),
            ["templateKey"] = reader.IsDBNull(4) ? null : reader.GetString(4),
            ["body"] = reader.GetString(5),
            ["createdAt"] = reader.GetDateTime(6).ToString("O")
        };
    }
}
