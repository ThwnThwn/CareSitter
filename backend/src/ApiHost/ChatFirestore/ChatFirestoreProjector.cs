using Npgsql;

namespace CareSitter.ApiHost.ChatFirestore;

internal sealed class ChatFirestoreProjector(ChatFirestoreDocuments documents)
{
    public async Task ProjectAsync(NpgsqlConnection connection, ChatFirestoreProjectionEvent pending, CancellationToken ct)
    {
        if (pending.Action == "USER_ACCESS")
        {
            await documents.ProjectUserAsync(connection, pending.UserId!.Value, ct);
            return;
        }
        var id = pending.ConversationId!.Value;
        if (pending.Action == "PURGE")
        {
            await documents.DeleteConversationAsync(id, ct);
            return;
        }
        if (pending.ChatType == "BOOKING")
            await BookingChatFirestoreProjector.ProjectAsync(connection, pending, documents, ct);
        else
            await SupportChatFirestoreProjector.ProjectAsync(connection, pending, documents, ct);
    }
}
