using Npgsql;

namespace CareSitter.ApiHost.ChatFirestore;

public sealed class ChatFirestoreAccessGate(IConfiguration configuration)
{
    public async Task<bool> CanIssueSessionAsync(CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(
            configuration.GetConnectionString("CareSitter"));
        await connection.OpenAsync(ct);
        // A pending/dead-lettered ACL update must prevent session renewal. This
        // bounds stale direct reads by the five-minute custom claim lifetime.
        await using var command = new NpgsqlCommand("""
            SELECT NOT EXISTS (
                SELECT 1 FROM public.chat_firestore_outbox
                WHERE delivered_at IS NULL AND action IN ('REFRESH', 'PURGE', 'USER_ACCESS')
            )
            """, connection);
        return await command.ExecuteScalarAsync(ct) is true;
    }
}
