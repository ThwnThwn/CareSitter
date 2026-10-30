using System.Diagnostics.Metrics;
using Google.Cloud.Firestore;
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
    ChatFirestoreClient firestore,
    ILogger<ChatFirestoreProjectionWorker> logger) : BackgroundService
{
    private static readonly Meter Meter = new("CareSitter.ChatFirestore");
    private static readonly Counter<long> Projected = Meter.CreateCounter<long>("chat_firestore_projected");
    private static readonly Counter<long> Failures = Meter.CreateCounter<long>("chat_firestore_failures");
    private static readonly Histogram<double> Lag = Meter.CreateHistogram<double>(
        "chat_firestore_projection_lag_seconds");

    private sealed record Event(long Id, string ChatType, string Action, Guid? ConversationId,
        Guid? EpochId, Guid? MessageId, Guid? UserId, int Attempts,
        DateTime AvailableAt, DateTime CreatedAt);

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
                    await ProjectAsync(connection, pending, ct);
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

    private static async Task<Event?> OldestAsync(NpgsqlConnection connection,
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
        return new Event(reader.GetInt64(0), reader.GetString(1), reader.GetString(2),
            reader.IsDBNull(3) ? null : reader.GetGuid(3),
            reader.IsDBNull(4) ? null : reader.GetGuid(4),
            reader.IsDBNull(5) ? null : reader.GetGuid(5),
            reader.IsDBNull(6) ? null : reader.GetGuid(6), reader.GetInt32(7),
            reader.GetDateTime(8), reader.GetDateTime(9));
    }

    private async Task ProjectAsync(NpgsqlConnection connection, Event pending, CancellationToken ct)
    {
        if (pending.Action == "USER_ACCESS")
        {
            await ProjectUserAsync(connection, pending.UserId!.Value, ct);
            return;
        }
        var id = pending.ConversationId!.Value;
        if (pending.Action == "PURGE")
        {
            await DeleteConversationAsync(id, ct);
            return;
        }
        if (pending.ChatType == "BOOKING")
            await ProjectBookingAsync(connection, pending, ct);
        else
            await ProjectSupportAsync(connection, pending, ct);
    }

    private async Task ProjectBookingAsync(NpgsqlConnection connection, Event pending,
        CancellationToken ct)
    {
        var id = pending.ConversationId!.Value;
        await using var stateCommand = new NpgsqlCommand("""
            SELECT c.booking_id, b.customer_id, b.caregiver_id, c.purged_at,
                   c.retained_until, c.write_blocked_at, c.dispute_locked_at,
                   e.id, e.caregiver_profile_id, e.caregiver_user_id,
                   c.last_sequence, c.change_version
            FROM booking.booking_chat_conversations c
            JOIN booking.bookings b ON b.id = c.booking_id
            LEFT JOIN LATERAL (
                SELECT id, caregiver_profile_id, caregiver_user_id
                FROM booking.booking_chat_epochs
                WHERE conversation_id = c.id AND ended_at IS NULL LIMIT 1
            ) e ON true
            WHERE c.id = @id
            """, connection);
        stateCommand.Parameters.AddWithValue("id", id);
        Guid bookingId, ownerId;
        Guid? assignedProfile, activeEpoch, epochProfile, caregiverId;
        DateTime? retainedUntil;
        bool purged, locked;
        long lastSequence, changeVersion;
        await using (var reader = await stateCommand.ExecuteReaderAsync(ct))
        {
            if (!await reader.ReadAsync(ct))
            {
                await DeleteConversationAsync(id, ct);
                return;
            }
            bookingId = reader.GetGuid(0);
            ownerId = reader.GetGuid(1);
            assignedProfile = reader.IsDBNull(2) ? null : reader.GetGuid(2);
            purged = !reader.IsDBNull(3);
            retainedUntil = reader.IsDBNull(4) ? null : reader.GetDateTime(4);
            locked = !reader.IsDBNull(5) || !reader.IsDBNull(6);
            activeEpoch = reader.IsDBNull(7) ? null : reader.GetGuid(7);
            epochProfile = reader.IsDBNull(8) ? null : reader.GetGuid(8);
            caregiverId = reader.IsDBNull(9) ? null : reader.GetGuid(9);
            lastSequence = reader.GetInt64(10);
            changeVersion = reader.GetInt64(11);
        }
        if (purged)
        {
            await DeleteConversationAsync(id, ct);
            return;
        }
        if (assignedProfile != epochProfile) caregiverId = null;
        var conversation = firestore.Database.Collection("chatConversations").Document(id.ToString());
        await conversation.SetAsync(new Dictionary<string, object?>
        {
            ["type"] = "BOOKING", ["bookingId"] = bookingId.ToString(),
            ["ownerUserId"] = ownerId.ToString(),
            ["activeEpochId"] = caregiverId is null ? null : activeEpoch?.ToString(),
            ["caregiverUserId"] = caregiverId?.ToString(),
            ["readEnabled"] = true, ["writeLocked"] = locked,
            ["lastSequence"] = lastSequence, ["changeVersion"] = changeVersion,
            ["retainedUntil"] = retainedUntil.HasValue
                ? Timestamp.FromDateTime(retainedUntil.Value.ToUniversalTime()) : null
        }, cancellationToken: ct);
        await ProjectUserAsync(connection, ownerId, ct);
        if (caregiverId is { } currentCaregiver)
            await ProjectUserAsync(connection, currentCaregiver, ct);

        var targetEpoch = pending.EpochId ?? activeEpoch;
        if (targetEpoch is not { } epochId) return;
        await using var epochCommand = new NpgsqlCommand("""
            SELECT epoch_number, caregiver_user_id, started_at
            FROM booking.booking_chat_epochs
            WHERE id = @epoch AND conversation_id = @conversation
            """, connection);
        epochCommand.Parameters.AddWithValue("epoch", epochId);
        epochCommand.Parameters.AddWithValue("conversation", id);
        int epochNumber;
        Guid epochCaregiver;
        DateTime startedAt;
        await using (var reader = await epochCommand.ExecuteReaderAsync(ct))
        {
            if (!await reader.ReadAsync(ct)) return;
            epochNumber = reader.GetInt32(0);
            epochCaregiver = reader.GetGuid(1);
            startedAt = reader.GetDateTime(2);
        }
        var epoch = conversation.Collection("epochs").Document(epochId.ToString());
        await epoch.SetAsync(new Dictionary<string, object>
        {
            ["number"] = epochNumber, ["caregiverUserId"] = epochCaregiver.ToString(),
            ["startedAt"] = startedAt.ToString("O")
        }, cancellationToken: ct);
        await epoch.Collection("members").Document(ownerId.ToString())
            .SetAsync(new { role = "CUSTOMER" }, cancellationToken: ct);
        await epoch.Collection("members").Document(epochCaregiver.ToString())
            .SetAsync(new { role = "CAREGIVER" }, cancellationToken: ct);
        if (pending.Action == "MESSAGE")
            await ProjectBookingMessageAsync(connection, epoch, pending.MessageId!.Value, ct);
    }

    private static async Task ProjectBookingMessageAsync(NpgsqlConnection connection,
        DocumentReference epoch, Guid messageId, CancellationToken ct)
    {
        var data = await ChatFirestoreMessage.ReadAsync(connection, "BOOKING", messageId, ct);
        if (data is null)
        {
            await epoch.Collection("messages").Document(messageId.ToString())
                .DeleteAsync(cancellationToken: ct);
            return;
        }
        await epoch.Collection("messages").Document(messageId.ToString())
            .SetAsync(data, cancellationToken: ct);
    }

    private async Task ProjectSupportAsync(NpgsqlConnection connection, Event pending,
        CancellationToken ct)
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
                await DeleteConversationAsync(id, ct);
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
        var conversation = firestore.Database.Collection("chatConversations").Document(id.ToString());
        await conversation.SetAsync(new Dictionary<string, object?>
        {
            ["type"] = "SUPPORT", ["ownerUserId"] = ownerId.ToString(),
            ["activeEpochId"] = id.ToString(), ["assignedAdminId"] = adminId?.ToString(),
            ["status"] = status, ["closed"] = closed, ["readEnabled"] = true,
            ["lastSequence"] = lastSequence
        }, cancellationToken: ct);
        await ProjectUserAsync(connection, ownerId, ct);
        if (adminId is { } activeAdmin) await ProjectUserAsync(connection, activeAdmin, ct);
        var epoch = conversation.Collection("epochs").Document(id.ToString());
        await epoch.SetAsync(new { number = 1 }, cancellationToken: ct);
        await epoch.Collection("members").Document(ownerId.ToString())
            .SetAsync(new { role = "OWNER" }, cancellationToken: ct);
        if (adminId is { } currentAdmin)
            await epoch.Collection("members").Document(currentAdmin.ToString())
                .SetAsync(new { role = "ADMIN" }, cancellationToken: ct);
        if (pending.Action != "MESSAGE") return;
        var messageId = pending.MessageId!.Value;
        var data = await ChatFirestoreMessage.ReadAsync(connection, "SUPPORT", messageId, ct);
        if (data is null)
        {
            await epoch.Collection("messages").Document(messageId.ToString())
                .DeleteAsync(cancellationToken: ct);
            return;
        }
        await epoch.Collection("messages").Document(messageId.ToString())
            .SetAsync(data, cancellationToken: ct);
    }

    private async Task ProjectUserAsync(NpgsqlConnection connection, Guid userId,
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

    private async Task DeleteConversationAsync(Guid id, CancellationToken ct)
    {
        var conversation = firestore.Database.Collection("chatConversations").Document(id.ToString());
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
