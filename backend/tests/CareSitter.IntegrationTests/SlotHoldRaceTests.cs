using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class SlotHoldRaceTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;

    public async Task InitializeAsync() =>
        _database = await PostgresRaceTestDatabase.CreateAsync();

    public async Task DisposeAsync()
    {
        if (_database is not null) await _database.DisposeAsync();
    }

    [PostgresFact]
    public async Task SameCaregiver_CannotCommitOverlappingBookings()
    {
        var caregivers = await GetCaregiverIdsAsync();
        var firstBooking = await CreateBookingAsync();
        var secondBooking = await CreateBookingAsync();
        var start = DateTimeOffset.UtcNow.AddDays(2);
        var end = start.AddHours(2);

        var results = await RunConcurrentAsync(
            () => InsertCommittedHoldAsync(firstBooking, caregivers[0], start, end),
            () => InsertCommittedHoldAsync(secondBooking, caregivers[0], start.AddMinutes(30), end.AddMinutes(30)));

        Assert.Contains("OK", results);
        Assert.Contains(PostgresErrorCodes.ExclusionViolation, results);
        Assert.Equal(1, await CountCommittedHoldsAsync(firstBooking, secondBooking));
    }

    [PostgresFact]
    public async Task SameBooking_CannotBeCommittedToTwoCaregivers()
    {
        var caregivers = await GetCaregiverIdsAsync();
        Assert.True(caregivers.Count >= 2);
        var bookingId = await CreateBookingAsync();
        var start = DateTimeOffset.UtcNow.AddDays(3);
        var end = start.AddHours(2);

        var results = await RunConcurrentAsync(
            () => InsertCommittedHoldAsync(bookingId, caregivers[0], start, end),
            () => InsertCommittedHoldAsync(bookingId, caregivers[1], start, end));

        Assert.Contains("OK", results);
        Assert.Contains(PostgresErrorCodes.UniqueViolation, results);
        Assert.Equal(1, await CountCommittedHoldsAsync(bookingId));
    }

    private static async Task<string[]> RunConcurrentAsync(
        Func<Task<string>> first,
        Func<Task<string>> second)
    {
        var firstReady = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var secondReady = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var gate = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        async Task<string> RunAsync(Func<Task<string>> operation, TaskCompletionSource ready)
        {
            ready.SetResult();
            await gate.Task;
            return await operation();
        }

        var firstTask = RunAsync(first, firstReady);
        var secondTask = RunAsync(second, secondReady);
        await Task.WhenAll(firstReady.Task, secondReady.Task);
        gate.SetResult();
        return await Task.WhenAll(firstTask, secondTask);
    }

    private async Task<string> InsertCommittedHoldAsync(
        Guid bookingId,
        Guid caregiverId,
        DateTimeOffset start,
        DateTimeOffset end)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        try
        {
            await using var command = new NpgsqlCommand("""
                INSERT INTO booking.caregiver_slot_holds (
                    id, booking_id, caregiver_id, scheduled_start, scheduled_end,
                    expires_at, status)
                VALUES (gen_random_uuid(), @booking_id, @caregiver_id, @start, @end,
                        @end, 'COMMITTED')
                """, connection, transaction);
            command.Parameters.AddWithValue("booking_id", bookingId);
            command.Parameters.AddWithValue("caregiver_id", caregiverId);
            command.Parameters.AddWithValue("start", start);
            command.Parameters.AddWithValue("end", end);
            await command.ExecuteNonQueryAsync();
            await transaction.CommitAsync();
            return "OK";
        }
        catch (PostgresException exception)
        {
            await transaction.RollbackAsync();
            return exception.SqlState;
        }
    }

    private async Task<List<Guid>> GetCaregiverIdsAsync()
    {
        var result = new List<Guid>();
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(
            "SELECT id FROM people.caregiver_profiles ORDER BY id LIMIT 2", connection);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync()) result.Add(reader.GetGuid(0));
        return result;
    }

    private async Task<Guid> CreateBookingAsync()
    {
        var id = Guid.NewGuid();
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO booking.bookings (
                id, customer_id, beneficiary_id, address_id, service_type_id,
                scheduled_start, scheduled_end, payment_deadline, status)
            SELECT @id, beneficiary.customer_id, beneficiary.id,
                   address.id, service.id,
                   now() + interval '2 days'
                       + (SELECT count(*) FROM booking.bookings) * interval '3 hours',
                   now() + interval '2 days 2 hours'
                       + (SELECT count(*) FROM booking.bookings) * interval '3 hours',
                   now() + interval '30 minutes', 'CONFIRMED'
            FROM people.beneficiaries beneficiary
            JOIN catalog.addresses address ON address.owner_user_id = beneficiary.customer_id
            CROSS JOIN LATERAL (
                SELECT id FROM catalog.service_types ORDER BY id LIMIT 1
            ) service
            ORDER BY beneficiary.id, address.id
            LIMIT 1
            """, connection);
        command.Parameters.AddWithValue("id", id);
        Assert.Equal(1, await command.ExecuteNonQueryAsync());
        return id;
    }

    private async Task<long> CountCommittedHoldsAsync(params Guid[] bookingIds)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT count(*) FROM booking.caregiver_slot_holds
            WHERE booking_id = ANY(@booking_ids) AND status = 'COMMITTED'
            """, connection);
        command.Parameters.AddWithValue("booking_ids", bookingIds);
        return (long)(await command.ExecuteScalarAsync() ?? 0L);
    }
}
