using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CareSitter.IntegrationTests;

public sealed class BookingTransactionIntegrityTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;

    public async Task InitializeAsync() =>
        _database = await PostgresRaceTestDatabase.CreateAsync();

    public async Task DisposeAsync() => await _database.DisposeAsync();

    [PostgresFact]
    public async Task ConcurrentOverlappingBookings_ForSameBeneficiary_OnlyOneCanCommit()
    {
        var seed = await GetSeedAsync();
        var start = DateTimeOffset.UtcNow.AddDays(3);
        var end = start.AddHours(2);

        var results = await RunConcurrentAsync(
            () => InsertBookingAsync(seed, Guid.NewGuid(), "PENDING_PAYMENT", start, end),
            () => InsertBookingAsync(seed, Guid.NewGuid(), "PENDING_PAYMENT",
                start.AddMinutes(15), end.AddMinutes(15)));

        Assert.Contains("OK", results);
        Assert.Contains(PostgresErrorCodes.ExclusionViolation, results);
        Assert.Equal(1, await CountBookingsAsync(seed.BeneficiaryId));
    }

    [PostgresFact]
    public async Task ConcurrentRefundRetry_CreditsCustomerExactlyOnce()
    {
        var seed = await GetSeedAsync();
        var bookingId = await CreateFinancialBookingAsync(seed, "MATCHING_FAILED");
        await ResetWalletsAsync(seed);
        await InsertEscrowLockAsync(bookingId, 100_000);

        async Task ResolveAsync()
        {
            await using var db = CreatePaymentsDbContext();
            var service = CreateWalletService(db, seed);
            var result = await service.RefundToCustomerWalletAsync(
                bookingId, seed.CustomerId);
            Assert.True(result.IsSuccess, result.Error.Message);
        }

        await Task.WhenAll(ResolveAsync(), ResolveAsync());

        var state = await ReadFinancialStateAsync(bookingId, seed);
        Assert.Equal(100_000, state.CustomerAvailable);
        Assert.Equal(0, state.CaregiverAvailable);
        Assert.Equal(1, state.RefundCount);
        Assert.Equal(100_000, state.RefundAmount);
    }

    [PostgresFact]
    public async Task ConcurrentPartialDisputeResolution_DistributesEscrowExactlyOnce()
    {
        var seed = await GetSeedAsync();
        var bookingId = await CreateFinancialBookingAsync(seed, "DISPUTED");
        await ResetWalletsAsync(seed);
        await InsertEscrowLockAsync(bookingId, 100_000);

        async Task ResolveAsync()
        {
            await using var db = CreatePaymentsDbContext();
            var service = CreateWalletService(db, seed);
            var result = await service.ResolveDisputeAsync(
                bookingId,
                seed.CustomerId,
                seed.CaregiverProfileId,
                escrowAmount: 100_000,
                platformFeeAmount: 15_000,
                decision: "PARTIAL_REFUND",
                refundAmount: 40_000,
                caregiverPenaltyAmount: 5_000);
            Assert.True(result.IsSuccess, result.Error.Message);
        }

        await Task.WhenAll(ResolveAsync(), ResolveAsync());

        var state = await ReadFinancialStateAsync(bookingId, seed);
        Assert.Equal(40_000, state.CustomerAvailable);
        Assert.Equal(40_000, state.CaregiverAvailable);
        Assert.Equal(1, state.RefundCount);
        Assert.Equal(40_000, state.RefundAmount);
        Assert.Equal(40_000, state.CaregiverEarningAmount);
        Assert.Equal(15_000, state.PlatformFeeAmount);
        Assert.Equal(5_000, state.PenaltyAmount);
        Assert.Equal(4, state.PostedResolutionEntries);
        Assert.Equal(100_000,
            state.RefundAmount + state.CaregiverEarningAmount +
            state.PlatformFeeAmount + state.PenaltyAmount);
    }

    [PostgresFact]
    public async Task CustomerWins_WithAdministrativePenalty_RefundsOnlyLockedEscrow()
    {
        var seed = await GetSeedAsync();
        var bookingId = await CreateFinancialBookingAsync(seed, "DISPUTED");
        await ResetWalletsAsync(seed);
        await InsertEscrowLockAsync(bookingId, 100_000);

        await using var db = CreatePaymentsDbContext();
        var service = CreateWalletService(db, seed);
        var result = await service.ResolveDisputeAsync(
            bookingId,
            seed.CustomerId,
            seed.CaregiverProfileId,
            escrowAmount: 100_000,
            platformFeeAmount: 15_000,
            decision: "CUSTOMER_WINS",
            refundAmount: 100_000,
            caregiverPenaltyAmount: 10_000);

        Assert.True(result.IsSuccess, result.Error.Message);
        var state = await ReadFinancialStateAsync(bookingId, seed);
        Assert.Equal(100_000, state.CustomerAvailable);
        Assert.Equal(0, state.CaregiverAvailable);
        Assert.Equal(100_000, state.RefundAmount);
        Assert.Equal(0, state.PlatformFeeAmount);
        Assert.Equal(0, state.PenaltyAmount);
        Assert.Equal(1, state.PostedResolutionEntries);
    }

    [PostgresFact]
    public async Task ConcurrentMatureSettlement_ReleasesOnceAndStampsBooking()
    {
        var seed = await GetSeedAsync();
        var bookingId = await CreateFinancialBookingAsync(
            seed, "COMPLETED", actualEnd: DateTimeOffset.UtcNow.AddHours(-49));
        await ResetWalletsAsync(seed);
        await InsertEscrowLockAsync(bookingId, 100_000);
        var releasedAt = DateTimeOffset.UtcNow;

        async Task ReleaseAsync()
        {
            await using var db = CreatePaymentsDbContext();
            var service = CreateWalletService(db, seed);
            var result = await service.ReleaseMatureSettlementAsync(
                bookingId,
                seed.CaregiverProfileId,
                escrowAmount: 100_000,
                platformFeeAmount: 15_000,
                releasedAt);
            Assert.True(result.IsSuccess, result.Error.Message);
        }

        await Task.WhenAll(ReleaseAsync(), ReleaseAsync());

        var state = await ReadFinancialStateAsync(bookingId, seed);
        Assert.Equal(85_000, state.CaregiverAvailable);
        Assert.Equal(85_000, state.CaregiverEarningAmount);
        Assert.Equal(15_000, state.PlatformFeeAmount);
        Assert.Equal(2, state.PostedResolutionEntries);
        Assert.NotNull(state.SettlementReleasedAt);
    }

    [PostgresFact]
    public async Task OpenDispute_BlocksMatureSettlement()
    {
        var seed = await GetSeedAsync();
        var bookingId = await CreateFinancialBookingAsync(
            seed, "COMPLETED", actualEnd: DateTimeOffset.UtcNow.AddHours(-49));
        await ResetWalletsAsync(seed);
        await InsertEscrowLockAsync(bookingId, 100_000);
        await InsertOpenDisputeAsync(bookingId, seed.CustomerId);

        await using var db = CreatePaymentsDbContext();
        var service = CreateWalletService(db, seed);
        var result = await service.ReleaseMatureSettlementAsync(
            bookingId,
            seed.CaregiverProfileId,
            escrowAmount: 100_000,
            platformFeeAmount: 15_000,
            DateTimeOffset.UtcNow);

        Assert.True(result.IsFailure);
        Assert.Equal("payments.settlement.not_mature", result.Error.Code);
        var state = await ReadFinancialStateAsync(bookingId, seed);
        Assert.Equal(0, state.CaregiverAvailable);
        Assert.Equal(0, state.CaregiverEarningAmount);
        Assert.Null(state.SettlementReleasedAt);
    }

    private PaymentsDbContext CreatePaymentsDbContext() => new(
        new DbContextOptionsBuilder<PaymentsDbContext>()
            .UseNpgsql(_database.ConnectionString)
            .Options);

    private WalletService CreateWalletService(PaymentsDbContext db, SeedRecord seed) => new(
        db,
        new DisputeLookupStub(),
        new PeopleLookupStub(seed.CaregiverProfileId, seed.CaregiverUserId));

    private async Task<SeedRecord> GetSeedAsync()
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT beneficiary.customer_id, beneficiary.id, address.id, service.id,
                   caregiver.id, caregiver.user_id
            FROM people.beneficiaries beneficiary
            JOIN catalog.addresses address
              ON address.owner_user_id = beneficiary.customer_id
            CROSS JOIN LATERAL (
                SELECT id FROM catalog.service_types ORDER BY id LIMIT 1
            ) service
            CROSS JOIN LATERAL (
                SELECT id, user_id FROM people.caregiver_profiles ORDER BY id LIMIT 1
            ) caregiver
            ORDER BY beneficiary.id, address.id
            LIMIT 1
            """, connection);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        return new SeedRecord(
            reader.GetGuid(0), reader.GetGuid(1), reader.GetGuid(2),
            reader.GetGuid(3), reader.GetGuid(4), reader.GetGuid(5));
    }

    private async Task<string> InsertBookingAsync(
        SeedRecord seed, Guid bookingId, string status,
        DateTimeOffset start, DateTimeOffset end)
    {
        await using var connection = await _database.OpenConnectionAsync();
        try
        {
            await using var command = new NpgsqlCommand("""
                INSERT INTO booking.bookings (
                    id, customer_id, beneficiary_id, address_id, service_type_id,
                    scheduled_start, scheduled_end, payment_deadline, status)
                VALUES (@id, @customer_id, @beneficiary_id, @address_id, @service_type_id,
                        @start, @end, now() + interval '30 minutes', @status)
                """, connection);
            command.Parameters.AddWithValue("id", bookingId);
            command.Parameters.AddWithValue("customer_id", seed.CustomerId);
            command.Parameters.AddWithValue("beneficiary_id", seed.BeneficiaryId);
            command.Parameters.AddWithValue("address_id", seed.AddressId);
            command.Parameters.AddWithValue("service_type_id", seed.ServiceTypeId);
            command.Parameters.AddWithValue("start", start);
            command.Parameters.AddWithValue("end", end);
            command.Parameters.AddWithValue("status", status);
            await command.ExecuteNonQueryAsync();
            return "OK";
        }
        catch (PostgresException exception)
        {
            return exception.SqlState;
        }
    }

    private async Task<Guid> CreateFinancialBookingAsync(
        SeedRecord seed, string status, DateTimeOffset? actualEnd = null)
    {
        var bookingId = Guid.NewGuid();
        var end = DateTimeOffset.UtcNow.AddHours(-50);
        var start = end.AddHours(-2);
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO booking.bookings (
                id, customer_id, beneficiary_id, caregiver_id, address_id, service_type_id,
                scheduled_start, scheduled_end, payment_deadline, actual_start, actual_end,
                status, escrow_amount, platform_fee_amount, caregiver_earning_amount,
                dispute_window_hours)
            VALUES (@id, @customer_id, @beneficiary_id, @caregiver_id,
                    @address_id, @service_type_id, @start, @end, @start,
                    @start, @actual_end, @status, 100000, 15000, 85000, 48)
            """, connection);
        command.Parameters.AddWithValue("id", bookingId);
        command.Parameters.AddWithValue("customer_id", seed.CustomerId);
        command.Parameters.AddWithValue("beneficiary_id", seed.BeneficiaryId);
        command.Parameters.AddWithValue("caregiver_id", seed.CaregiverProfileId);
        command.Parameters.AddWithValue("address_id", seed.AddressId);
        command.Parameters.AddWithValue("service_type_id", seed.ServiceTypeId);
        command.Parameters.AddWithValue("start", start);
        command.Parameters.AddWithValue("end", end);
        command.Parameters.AddWithValue("actual_end", (object?)actualEnd ?? DBNull.Value);
        command.Parameters.AddWithValue("status", status);
        await command.ExecuteNonQueryAsync();
        return bookingId;
    }

    private async Task ResetWalletsAsync(SeedRecord seed)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            UPDATE payments.wallet_accounts
            SET available_balance = 0, pending_balance = 0
            WHERE user_id IN (@customer_id, @caregiver_user_id);
            """, connection);
        command.Parameters.AddWithValue("customer_id", seed.CustomerId);
        command.Parameters.AddWithValue("caregiver_user_id", seed.CaregiverUserId);
        await command.ExecuteNonQueryAsync();
    }

    private async Task InsertEscrowLockAsync(Guid bookingId, long amount)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO payments.ledger_entries (
                id, booking_id, transaction_type, debit_account, credit_account,
                amount, currency, status, created_at)
            VALUES (gen_random_uuid(), @booking_id, 'ESCROW_LOCK',
                    'customer:escrow', 'escrow:platform', @amount, 'VND', 'POSTED', now())
            """, connection);
        command.Parameters.AddWithValue("booking_id", bookingId);
        command.Parameters.AddWithValue("amount", amount);
        await command.ExecuteNonQueryAsync();
    }

    private async Task InsertOpenDisputeAsync(Guid bookingId, Guid customerId)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO support.disputes (
                id, booking_id, raised_by_user_id, reason, status, opened_at)
            VALUES (gen_random_uuid(), @booking_id, @customer_id,
                    'phase8-test', 'OPEN', now())
            """, connection);
        command.Parameters.AddWithValue("booking_id", bookingId);
        command.Parameters.AddWithValue("customer_id", customerId);
        await command.ExecuteNonQueryAsync();
    }

    private async Task<long> CountBookingsAsync(Guid beneficiaryId)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(
            "SELECT count(*) FROM booking.bookings WHERE beneficiary_id = @beneficiary_id",
            connection);
        command.Parameters.AddWithValue("beneficiary_id", beneficiaryId);
        return (long)(await command.ExecuteScalarAsync() ?? 0L);
    }

    private async Task<FinancialState> ReadFinancialStateAsync(
        Guid bookingId, SeedRecord seed)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT
              COALESCE((SELECT available_balance FROM payments.wallet_accounts
                        WHERE user_id = @customer_id AND account_type = 'CUSTOMER'), 0),
              COALESCE((SELECT available_balance FROM payments.wallet_accounts
                        WHERE user_id = @caregiver_user_id AND account_type = 'CAREGIVER'), 0),
              count(*) FILTER (WHERE transaction_type = 'REFUND'),
              COALESCE(sum(amount) FILTER (WHERE transaction_type = 'REFUND'), 0),
              COALESCE(sum(amount) FILTER (WHERE transaction_type = 'CAREGIVER_EARNING'), 0),
              COALESCE(sum(amount) FILTER (WHERE transaction_type = 'PLATFORM_FEE'), 0),
              COALESCE(sum(amount) FILTER (WHERE transaction_type = 'PENALTY'), 0),
              count(*) FILTER (WHERE transaction_type IN
                  ('REFUND','CAREGIVER_EARNING','PLATFORM_FEE','PENALTY') AND status = 'POSTED'),
              (SELECT settlement_released_at FROM booking.bookings WHERE id = @booking_id)
            FROM payments.ledger_entries
            WHERE booking_id = @booking_id
            """, connection);
        command.Parameters.AddWithValue("booking_id", bookingId);
        command.Parameters.AddWithValue("customer_id", seed.CustomerId);
        command.Parameters.AddWithValue("caregiver_user_id", seed.CaregiverUserId);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        return new FinancialState(
            reader.GetInt64(0), reader.GetInt64(1), reader.GetInt64(2),
            reader.GetInt64(3), reader.GetInt64(4), reader.GetInt64(5),
            reader.GetInt64(6), reader.GetInt64(7),
            reader.IsDBNull(8) ? null : reader.GetFieldValue<DateTimeOffset>(8));
    }

    private static async Task<string[]> RunConcurrentAsync(
        Func<Task<string>> first, Func<Task<string>> second)
    {
        var gate = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        async Task<string> RunAsync(Func<Task<string>> operation)
        {
            await gate.Task;
            return await operation();
        }

        var firstTask = RunAsync(first);
        var secondTask = RunAsync(second);
        gate.SetResult();
        return await Task.WhenAll(firstTask, secondTask);
    }

    private sealed record SeedRecord(
        Guid CustomerId,
        Guid BeneficiaryId,
        Guid AddressId,
        Guid ServiceTypeId,
        Guid CaregiverProfileId,
        Guid CaregiverUserId);

    private sealed record FinancialState(
        long CustomerAvailable,
        long CaregiverAvailable,
        long RefundCount,
        long RefundAmount,
        long CaregiverEarningAmount,
        long PlatformFeeAmount,
        long PenaltyAmount,
        long PostedResolutionEntries,
        DateTimeOffset? SettlementReleasedAt);

    private sealed class DisputeLookupStub : IDisputeLookupService
    {
        public Task<bool> HasOpenDisputeAsync(Guid bookingId, CancellationToken ct = default) =>
            Task.FromResult(false);
    }

    private sealed class PeopleLookupStub(Guid profileId, Guid userId) : IPeopleLookupService
    {
        public Task<Guid?> GetUserIdByCaregiverProfileIdAsync(
            Guid caregiverId, CancellationToken ct = default) =>
            Task.FromResult<Guid?>(caregiverId == profileId ? userId : null);
        public Task<bool> BeneficiaryBelongsToAsync(Guid beneficiaryId, Guid customerId,
            CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> CaregiverIsAvailableAsync(Guid caregiverId, DateTimeOffset start,
            DateTimeOffset end, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> IsCaregiverApprovedAsync(Guid caregiverId,
            CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> IsCaregiverForBookingAsync(Guid caregiverId, Guid currentUserId,
            CancellationToken ct = default) => throw new NotSupportedException();
        public Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid currentUserId,
            CancellationToken ct = default) => throw new NotSupportedException();
        public Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid beneficiaryId,
            CancellationToken ct = default) => throw new NotSupportedException();
        public Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid caregiverId,
            CancellationToken ct = default) => throw new NotSupportedException();
    }
}
