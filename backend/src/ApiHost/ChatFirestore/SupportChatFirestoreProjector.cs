using Npgsql;

namespace CareSitter.ApiHost.ChatFirestore;

internal static class SupportChatFirestoreProjector
{
    public static async Task ProjectAsync(NpgsqlConnection connection, ChatFirestoreProjectionEvent pending,
        ChatFirestoreDocuments documents, CancellationToken ct)
    {
        var id = pending.ConversationId!.Value;
        await using var command = new NpgsqlCommand("""
            SELECT c.owner_user_id, t.assigned_admin_id, t.status, c.closed_at,
                   u.status, u.admin_is_active,
                   COALESCE('ADMIN' = ANY(u.roles), false), c.last_sequence
            FROM support.chat_conversations c
            JOIN support.support_tickets t ON t.id = c.ticket_id
            LEFT JOIN identity.users u ON u.id = t.assigned_admin_id
            WHERE c.id = @id
            """, connection);
        command.Parameters.AddWithValue("id", id);
        Guid ownerId;
        Guid? adminId;
        string status;
        bool closed;
        long lastSequence;
        await using (var reader = await command.ExecuteReaderAsync(ct))
        {
            if (!await reader.ReadAsync(ct))
            {
                await documents.DeleteConversationAsync(id, ct);
                return;
            }
            ownerId = reader.GetGuid(0);
            adminId = reader.IsDBNull(1) || reader.IsDBNull(4) ||
                reader.GetString(4) != "ACTIVE" || reader.IsDBNull(5) ||
                !reader.GetBoolean(5) || !reader.GetBoolean(6)
                ? null : reader.GetGuid(1);
            status = reader.GetString(2);
            closed = !reader.IsDBNull(3);
            lastSequence = reader.GetInt64(7);
        }
        var conversation = documents.Conversation(id);
        await conversation.SetAsync(new Dictionary<string, object?>
        {
            ["type"] = "SUPPORT", ["ownerUserId"] = ownerId.ToString(),
            ["activeEpochId"] = id.ToString(), ["assignedAdminId"] = adminId?.ToString(),
            ["status"] = status, ["closed"] = closed, ["readEnabled"] = true,
            ["lastSequence"] = lastSequence
        }, cancellationToken: ct);
        await documents.ProjectUserAsync(connection, ownerId, ct);
        if (adminId is { } activeAdmin) await documents.ProjectUserAsync(connection, activeAdmin, ct);
        var epoch = conversation.Collection("epochs").Document(id.ToString());
        await epoch.SetAsync(new { number = 1 }, cancellationToken: ct);
        await epoch.Collection("members").Document(ownerId.ToString())
            .SetAsync(new { role = "OWNER" }, cancellationToken: ct);
        if (adminId is { } currentAdmin)
            await epoch.Collection("members").Document(currentAdmin.ToString())
                .SetAsync(new { role = "ADMIN" }, cancellationToken: ct);
        if (pending.Action == "MESSAGE")
            await ChatFirestoreDocuments.ProjectMessageAsync(connection, epoch, "SUPPORT", pending.MessageId!.Value, ct);
    }
}
