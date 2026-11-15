using Hangfire;
using Microsoft.Extensions.Options;
using Npgsql;
using NpgsqlTypes;

namespace CareSitter.ApiHost.ChatFirestore;

public sealed class ChatFirestoreReconcileJob(
    IConfiguration configuration,
    IOptions<ChatFirestoreOptions> options,
    ChatFirestoreReconciler reconciler,
    ILogger<ChatFirestoreReconcileJob> logger)
{
    [AutomaticRetry(Attempts = 3)]
    public async Task RunAsync(CancellationToken ct)
    {
        if (!options.Value.ProjectionEnabled || !options.Value.ReconcileEnabled) return;
        var size = Math.Clamp(options.Value.ReconcileBatchSize, 1, 100);
        await using var connection = new NpgsqlConnection(
            configuration.GetConnectionString("CareSitter"));
        await connection.OpenAsync(ct);
        await using var gate = new NpgsqlCommand("SELECT pg_try_advisory_lock(2026, 5401)", connection);
        if (await gate.ExecuteScalarAsync(ct) is not true) return;
        try
        {
            foreach (var chatType in new[] { "BOOKING", "SUPPORT" })
            {
                DateTime? afterAt;
                Guid? afterId;
                await using (var cursor = new NpgsqlCommand("""
                    SELECT after_created_at, after_message_id
                    FROM public.chat_firestore_reconcile_cursors WHERE chat_type = @type
                    """, connection))
                {
                    cursor.Parameters.AddWithValue("type", chatType);
                    await using var reader = await cursor.ExecuteReaderAsync(ct);
                    if (!await reader.ReadAsync(ct))
                        throw new InvalidOperationException("Missing chat reconciliation checkpoint.");
                    afterAt = reader.IsDBNull(0) ? null : reader.GetDateTime(0);
                    afterId = reader.IsDBNull(1) ? null : reader.GetGuid(1);
                }
                var result = await reconciler.ScanAsync(chatType, afterAt, afterId, size, ct);
                // Advance only after all repairs are durably enqueued. A failed run
                // repeats this page safely; finishing a pass starts again next run.
                await using var checkpoint = new NpgsqlCommand("""
                    UPDATE public.chat_firestore_reconcile_cursors
                    SET after_created_at = @at, after_message_id = @id, updated_at = now()
                    WHERE chat_type = @type
                    """, connection);
                checkpoint.Parameters.AddWithValue("type", chatType);
                checkpoint.Parameters.Add("at", NpgsqlDbType.TimestampTz).Value =
                    result.Scanned == size && result.NextCreatedAt is { } nextAt ? nextAt : DBNull.Value;
                checkpoint.Parameters.Add("id", NpgsqlDbType.Uuid).Value =
                    result.Scanned == size && result.NextMessageId is { } nextId ? nextId : DBNull.Value;
                await checkpoint.ExecuteNonQueryAsync(ct);
                logger.LogInformation(
                    "Chat Firestore reconciliation {ChatType}: scanned {Scanned}, missing {Missing}, mismatched {Mismatched}.",
                    chatType, result.Scanned, result.Missing, result.Mismatched);
            }
        }
        finally
        {
            await using var unlock = new NpgsqlCommand(
                "SELECT pg_advisory_unlock(2026, 5401)", connection);
            await unlock.ExecuteScalarAsync(CancellationToken.None);
        }
    }
}
