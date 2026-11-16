using System.Diagnostics.Metrics;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.ApiHost.ChatFirestore;

/// <summary>
/// Replays identifier-only PostgreSQL events by ID using current source state. A session advisory
/// lock keeps multiple API replicas from projecting one conversation out of order.
/// </summary>
internal sealed class ChatFirestoreProjectionWorker(
    IConfiguration configuration,
    IOptions<ChatFirestoreOptions> options,
    ChatFirestoreProjector projector,
    ILogger<ChatFirestoreProjectionWorker> logger) : BackgroundService
{
    private static readonly Meter Meter = new("CareSitter.ChatFirestore");
    private static readonly Counter<long> Projected = Meter.CreateCounter<long>("chat_firestore_projected");
    private static readonly Counter<long> Failures = Meter.CreateCounter<long>("chat_firestore_failures");
    private static readonly Histogram<double> Lag = Meter.CreateHistogram<double>(
        "chat_firestore_projection_lag_seconds");

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.ProjectionEnabled) return;
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(
            Math.Clamp(options.Value.PollSeconds, 1, 60)));
        while (!stoppingToken.IsCancellationRequested)
        {
            try { await ProcessBatchAsync(stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception exception)
            {
                logger.LogError(exception, "Chat Firestore projection polling failed.");
            }
            if (!await timer.WaitForNextTickAsync(stoppingToken)) break;
        }
    }

    internal async Task<int> ProcessBatchAsync(CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(
            configuration.GetConnectionString("CareSitter"));
        await connection.OpenAsync(ct);
        await using (var lockCommand = new NpgsqlCommand(
            "SELECT pg_try_advisory_lock(2026, 54)", connection))
        {
            if (await lockCommand.ExecuteScalarAsync(ct) is not true)
                return 0;
        }

        try
        {
            var completed = 0;
            for (var i = 0; i < Math.Clamp(options.Value.BatchSize, 1, 500); i++)
            {
                var pending = await OldestAsync(connection, urgentOnly: true, ct)
                    ?? await OldestAsync(connection, urgentOnly: false, ct);
                if (pending is null || pending.AvailableAt > DateTime.UtcNow) break;
                try
                {
                    await projector.ProjectAsync(connection, pending, ct);
                    await using var complete = new NpgsqlCommand(
                        "UPDATE public.chat_firestore_outbox SET delivered_at = now(), last_error = NULL " +
                        "WHERE id = @id AND delivered_at IS NULL", connection);
                    complete.Parameters.AddWithValue("id", pending.Id);
                    await complete.ExecuteNonQueryAsync(ct);
                    Projected.Add(1, new KeyValuePair<string, object?>("chat_type", pending.ChatType));
                    Lag.Record(Math.Max(0, (DateTime.UtcNow - pending.CreatedAt).TotalSeconds),
                        new KeyValuePair<string, object?>("chat_type", pending.ChatType));
                    completed++;
                }
                catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
                catch (Exception exception)
                {
                    var deadLetter = pending.Attempts + 1 >=
                        Math.Clamp(options.Value.MaxAttempts, 1, 100);
                    var delaySeconds = deadLetter ? 3600 :
                        Math.Min(300, 1 << Math.Min(pending.Attempts + 1, 8));
                    await using var retry = new NpgsqlCommand(
                        "UPDATE public.chat_firestore_outbox SET attempts = attempts + 1, " +
                        "available_at = now() + @delay * interval '1 second', last_error = @error, " +
                        "dead_letter_at = CASE WHEN @dead THEN COALESCE(dead_letter_at, now()) " +
                        "ELSE dead_letter_at END " +
                        "WHERE id = @id AND delivered_at IS NULL", connection);
                    retry.Parameters.AddWithValue("delay", delaySeconds);
                    retry.Parameters.AddWithValue("error", exception.GetType().Name);
                    retry.Parameters.AddWithValue("dead", deadLetter);
                    retry.Parameters.AddWithValue("id", pending.Id);
                    await retry.ExecuteNonQueryAsync(ct);
                    Failures.Add(1, new KeyValuePair<string, object?>("chat_type", pending.ChatType));
                    logger.LogWarning(
                        "Chat Firestore projection failed for outbox event {EventId} ({ErrorType}); dead letter: {DeadLetter}; retry in {DelaySeconds}s.",
                        pending.Id, exception.GetType().Name, deadLetter, delaySeconds);
                    // Pause this batch on failure; exhausted normal events require replay.
                    break;
                }
            }
            return completed;
        }
        finally
        {
            await using var unlock = new NpgsqlCommand(
                "SELECT pg_advisory_unlock(2026, 54)", connection);
            await unlock.ExecuteScalarAsync(CancellationToken.None);
        }
    }

    private static async Task<ChatFirestoreProjectionEvent?> OldestAsync(NpgsqlConnection connection,
        bool urgentOnly, CancellationToken ct)
    {
        var sql = urgentOnly ? """
            SELECT id, chat_type, action, conversation_id, epoch_id, message_id,
                   user_id, attempts, available_at, created_at
            FROM public.chat_firestore_outbox
            WHERE delivered_at IS NULL AND action IN ('PURGE', 'USER_ACCESS')
              AND available_at <= now()
            ORDER BY id LIMIT 1
            """ : """
            SELECT id, chat_type, action, conversation_id, epoch_id, message_id,
                   user_id, attempts, available_at, created_at
            FROM public.chat_firestore_outbox
            WHERE delivered_at IS NULL AND dead_letter_at IS NULL
            ORDER BY id LIMIT 1
            """;
        await using var command = new NpgsqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) return null;
        return new ChatFirestoreProjectionEvent(reader.GetInt64(0), reader.GetString(1), reader.GetString(2),
            reader.IsDBNull(3) ? null : reader.GetGuid(3),
            reader.IsDBNull(4) ? null : reader.GetGuid(4),
            reader.IsDBNull(5) ? null : reader.GetGuid(5),
            reader.IsDBNull(6) ? null : reader.GetGuid(6), reader.GetInt32(7),
            reader.GetDateTime(8), reader.GetDateTime(9));
    }
}

internal sealed record ChatFirestoreProjectionEvent(long Id, string ChatType, string Action, Guid? ConversationId,
    Guid? EpochId, Guid? MessageId, Guid? UserId, int Attempts,
    DateTime AvailableAt, DateTime CreatedAt);
