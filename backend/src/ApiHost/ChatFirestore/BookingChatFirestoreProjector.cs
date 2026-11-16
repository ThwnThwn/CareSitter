using Google.Cloud.Firestore;
using Npgsql;

namespace CareSitter.ApiHost.ChatFirestore;

internal static class BookingChatFirestoreProjector
{
    public static async Task ProjectAsync(NpgsqlConnection connection, ChatFirestoreProjectionEvent pending,
        ChatFirestoreDocuments documents, CancellationToken ct)
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
                await documents.DeleteConversationAsync(id, ct);
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
            await documents.DeleteConversationAsync(id, ct);
            return;
        }
        if (assignedProfile != epochProfile) caregiverId = null;
        var conversation = documents.Conversation(id);
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
        await documents.ProjectUserAsync(connection, ownerId, ct);
        if (caregiverId is { } currentCaregiver)
            await documents.ProjectUserAsync(connection, currentCaregiver, ct);

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
            await ChatFirestoreDocuments.ProjectMessageAsync(connection, epoch, "BOOKING", pending.MessageId!.Value, ct);
    }
}
