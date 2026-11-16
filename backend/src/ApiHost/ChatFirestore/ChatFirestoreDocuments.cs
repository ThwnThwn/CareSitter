using Google.Cloud.Firestore;
using Npgsql;

namespace CareSitter.ApiHost.ChatFirestore;

internal sealed class ChatFirestoreDocuments(ChatFirestoreClient firestore)
{
    public DocumentReference Conversation(Guid id) =>
        firestore.Database.Collection("chatConversations").Document(id.ToString());

    public async Task ProjectUserAsync(NpgsqlConnection connection, Guid userId,
        CancellationToken ct)
    {
        await using var command = new NpgsqlCommand("""
            SELECT status, admin_is_active, roles FROM identity.users WHERE id = @id
            """, connection);
        command.Parameters.AddWithValue("id", userId);
        bool active = false, activeAdmin = false, activeCaregiver = false;
        await using (var reader = await command.ExecuteReaderAsync(ct))
        {
            if (await reader.ReadAsync(ct))
            {
                active = reader.GetString(0) == "ACTIVE";
                var roles = reader.GetFieldValue<string[]>(2);
                activeCaregiver = active && roles.Contains("CAREGIVER");
                activeAdmin = active && !reader.IsDBNull(1) && reader.GetBoolean(1) &&
                    roles.Contains("ADMIN");
            }
        }
        await firestore.Database.Collection("chatUserAccess").Document(userId.ToString())
            .SetAsync(new { active, activeAdmin, activeCaregiver }, cancellationToken: ct);
    }

    public static async Task ProjectMessageAsync(NpgsqlConnection connection,
        DocumentReference epoch, string chatType, Guid messageId, CancellationToken ct)
    {
        var data = await ChatFirestoreMessage.ReadAsync(connection, chatType, messageId, ct);
        if (data is null)
        {
            await epoch.Collection("messages").Document(messageId.ToString())
                .DeleteAsync(cancellationToken: ct);
            return;
        }
        await epoch.Collection("messages").Document(messageId.ToString())
            .SetAsync(data, cancellationToken: ct);
    }

    public async Task DeleteConversationAsync(Guid id, CancellationToken ct)
    {
        var conversation = Conversation(id);
        // Deny new reads before deleting descendants. Deletion is safe to retry.
        await conversation.SetAsync(new { readEnabled = false }, SetOptions.MergeAll, ct);
        var epochs = await conversation.Collection("epochs").GetSnapshotAsync(ct);
        foreach (var epoch in epochs.Documents)
        {
            await DeleteCollectionAsync(epoch.Reference.Collection("messages"), ct);
            await DeleteCollectionAsync(epoch.Reference.Collection("members"), ct);
            await epoch.Reference.DeleteAsync(cancellationToken: ct);
        }
        await conversation.DeleteAsync(cancellationToken: ct);
    }

    private static async Task DeleteCollectionAsync(CollectionReference collection,
        CancellationToken ct)
    {
        while (true)
        {
            var batch = await collection.Limit(200).GetSnapshotAsync(ct);
            if (batch.Count == 0) return;
            foreach (var document in batch.Documents)
                await document.Reference.DeleteAsync(cancellationToken: ct);
        }
    }
}
