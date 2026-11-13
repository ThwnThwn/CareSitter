using System.Text.Json;
using Npgsql;

namespace CareSitter.Nutrition.Infrastructure;

/// <summary>Processes a deletion and its inbox marker in one Nutrition transaction.</summary>
internal sealed class BeneficiaryDeletionProcessor(NpgsqlDataSource dataSource)
{
    internal sealed record BeneficiaryDeleted(Guid OwnerUserId, Guid BeneficiaryId, DateTimeOffset OccurredAt);
    private sealed record WireEnvelope(Guid EventId, string EventType, int SchemaVersion,
        DateTimeOffset OccurredAt, string Producer, string? CorrelationId, string Key, JsonElement Payload);
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web) { MaxDepth = 32 };
    internal const string EventType = "caresitter.people.beneficiary-deleted";

    public static BeneficiaryDeleted? Parse(string wire, string brokerKey, out Guid eventId)
    {
        if (System.Text.Encoding.UTF8.GetByteCount(wire) > 65536)
            throw new InvalidDataException("Event exceeds size limit.");
        var envelope = JsonSerializer.Deserialize<WireEnvelope>(wire, JsonOptions)
            ?? throw new InvalidDataException("Event envelope is empty.");
        eventId = envelope.EventId;
        if (envelope.EventType != EventType) return null;
        if (envelope.SchemaVersion != 1 || envelope.EventId == Guid.Empty ||
            envelope.OccurredAt == default || envelope.OccurredAt.Offset != TimeSpan.Zero ||
            string.IsNullOrWhiteSpace(envelope.Producer) || envelope.Key != brokerKey)
            throw new InvalidDataException("Invalid beneficiary deletion envelope.");
        var value = envelope.Payload.Deserialize<BeneficiaryDeleted>(JsonOptions)
            ?? throw new InvalidDataException("Deletion payload is empty.");
        if (value.OwnerUserId == Guid.Empty || value.BeneficiaryId == Guid.Empty ||
            value.OccurredAt != envelope.OccurredAt || envelope.Key != value.BeneficiaryId.ToString("D"))
            throw new InvalidDataException("Invalid beneficiary deletion payload.");
        return value;
    }

    public async Task PurgeAsync(Guid eventId, BeneficiaryDeleted value, CancellationToken ct)
    {
        await using var connection = await dataSource.OpenConnectionAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);
        // Match NutritionStore's owner lock. A concurrent write either commits before
        // this purge and is removed, or sees the committed tombstone on its insert.
        await using (var scope = new NpgsqlCommand("SELECT set_config('app.current_user_id',@owner::text,true); SELECT pg_advisory_xact_lock(hashtextextended('nutrition:' || @owner::text,0))", connection, transaction))
        {
            scope.Parameters.AddWithValue("owner", value.OwnerUserId);
            await scope.ExecuteNonQueryAsync(ct);
        }
        await using (var inbox = new NpgsqlCommand("INSERT INTO nutrition.beneficiary_deletion_inbox(event_id,customer_id,beneficiary_id) VALUES (@event,@owner,@beneficiary) ON CONFLICT DO NOTHING", connection, transaction))
        {
            Bind(inbox, eventId, value);
            if (await inbox.ExecuteNonQueryAsync(ct) == 0)
            {
                await using var prior = new NpgsqlCommand("SELECT customer_id,beneficiary_id FROM nutrition.beneficiary_deletion_inbox WHERE event_id=@event", connection, transaction);
                prior.Parameters.AddWithValue("event", eventId);
                bool matches;
                await using (var reader = await prior.ExecuteReaderAsync(ct))
                    matches = await reader.ReadAsync(ct) && reader.GetGuid(0) == value.OwnerUserId &&
                        reader.GetGuid(1) == value.BeneficiaryId;
                if (!matches)
                    throw new InvalidDataException("Event ID was reused for a different beneficiary.");
                await transaction.CommitAsync(ct);
                return;
            }
        }
        await using (var tombstone = new NpgsqlCommand("INSERT INTO nutrition.beneficiary_deletions(customer_id,beneficiary_id,event_id) VALUES (@owner,@beneficiary,@event) ON CONFLICT (customer_id,beneficiary_id) DO NOTHING", connection, transaction))
        {
            Bind(tombstone, eventId, value);
            await tombstone.ExecuteNonQueryAsync(ct);
        }
        foreach (var table in new[] { "assessment_jobs", "assessments", "recommendations", "meal_plans", "preferences" })
        {
            await using var delete = new NpgsqlCommand($"DELETE FROM nutrition.{table} WHERE customer_id=@owner AND beneficiary_id=@beneficiary", connection, transaction);
            delete.Parameters.AddWithValue("owner", value.OwnerUserId);
            delete.Parameters.AddWithValue("beneficiary", value.BeneficiaryId);
            await delete.ExecuteNonQueryAsync(ct);
        }
        await transaction.CommitAsync(ct);
    }

    private static void Bind(NpgsqlCommand command, Guid eventId, BeneficiaryDeleted value)
    {
        command.Parameters.AddWithValue("event", eventId);
        command.Parameters.AddWithValue("owner", value.OwnerUserId);
        command.Parameters.AddWithValue("beneficiary", value.BeneficiaryId);
    }
}
