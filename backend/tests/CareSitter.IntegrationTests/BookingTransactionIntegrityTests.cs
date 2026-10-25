using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.Refunds;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class BookingTransactionIntegrityTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;

    public async Task InitializeAsync() =>
        _database = await PostgresRaceTestDatabase.CreateAsync();

    public async Task DisposeAsync()
    {
        if (_database is not null) await _database.DisposeAsync();
    }

    [PostgresFact]
    public async Task ConcurrentOverlappingBookings_ForSameBeneficiary_OnlyOneCanCommit()
    {
        var seed = await GetSeedAsync();
        var start = DateTimeOffset.UtcNow.AddDays(3);
        var end = start.AddHours(2);
        var firstBookingId = Guid.NewGuid();
        var secondBookingId = Guid.NewGuid();

        var results = await RunConcurrentAsync(
            () => InsertBookingAsync(seed, firstBookingId, "PENDING_PAYMENT", start, end),
            () => InsertBookingAsync(seed, secondBookingId, "PENDING_PAYMENT",
                start.AddMinutes(15), end.AddMinutes(15)));

        Assert.Contains("OK", results);
        Assert.Contains(PostgresErrorCodes.ExclusionViolation, results);
        Assert.Equal(1, await CountBookingsAsync(firstBookingId, secondBookingId));
    }

    [PostgresFact]
    public async Task ConcurrentOriginalRefundRequest_CreatesOneManualPayOSRequestWithoutCreditingWallet()
    {
        var seed = await GetSeedAsync();
        var bookingId = await CreateFinancialBookingAsync(seed, "MATCHING_FAILED");
        await ResetWalletsAsync(seed);
        await InsertEscrowLockAsync(bookingId, 100_000);
        await InsertSucceededPayOSIntentAsync(bookingId, seed.CustomerId, 100_000);

        async Task ResolveAsync()
        {
            await using var db = CreatePaymentsDbContext();
            var service = CreateWalletService(db, seed);
            var result = await service.RequestOriginalPaymentRefundAsync(
                bookingId, seed.CustomerId, "NO_CAREGIVER_AVAILABLE");
            Assert.True(result.IsSuccess, result.Error.Message);
            Assert.Equal(OriginalPaymentRefundState.ManualActionRequired, result.Value.State);
        }

        await Task.WhenAll(ResolveAsync(), ResolveAsync());

        var state = await ReadFinancialStateAsync(bookingId, seed);
        Assert.Equal(0, state.CustomerAvailable);
        Assert.Equal(0, state.CaregiverAvailable);
        Assert.Equal(0, state.RefundCount);
        Assert.Equal(0, state.RefundAmount);
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT count(*), min(status), min(provider), min(amount)
            FROM payments.refund_requests
            WHERE booking_id = @booking_id
            """, connection);
        command.Parameters.AddWithValue("booking_id", bookingId);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        Assert.Equal(1, reader.GetInt64(0));
        Assert.Equal("MANUAL_REQUIRED", reader.GetString(1));
        Assert.Equal("PAYOS", reader.GetString(2));
        Assert.Equal(100_000, reader.GetInt64(3));
    }

    [PostgresFact]
    public async Task ProviderConfirmedVNPayRefund_PostsOneExternalRefundLedgerWithoutCreditingWallet()
    {
        var seed = await GetSeedAsync();
        var bookingId = await CreateFinancialBookingAsync(seed, "MATCHING_FAILED");
        await ResetWalletsAsync(seed);
        await InsertEscrowLockAsync(bookingId, 100_000);
        var paymentIntentId = await InsertSucceededVNPayIntentAsync(
            bookingId, seed.CustomerId, 100_000);

        await using (var createDb = CreatePaymentsDbContext())
        {
            var coordinator = new OriginalPaymentRefundCoordinator(new RefundStore(createDb));
            var created = await coordinator.EnsureRefundAsync(
                bookingId, seed.CustomerId, null, "NO_CAREGIVER_AVAILABLE");
            Assert.True(created.IsSuccess, created.Error.Message);
            Assert.Equal(OriginalPaymentRefundState.Pending, created.Value.State);
        }

        Guid requestId;
        Guid leaseId;
        await using (var processDb = CreatePaymentsDbContext())
        {
            var store = new RefundStore(processDb);
            var now = DateTimeOffset.UtcNow;
            var work = await store.ClaimNextAsync(
                now, now.AddSeconds(30), now.AddSeconds(10));
            Assert.NotNull(work);
            Assert.True(work.Submit);
            requestId = work.Request.Id;
            leaseId = work.LeaseId;

            var confirmed = await store.ApplyProviderResultAsync(
                requestId,
                leaseId,
                new RefundProviderResult(
                    RefundProviderOutcome.Confirmed,
                    "response-001",
                    "refund-001",
                    "00"),
                now.AddSeconds(1),
                now.AddSeconds(10));
            Assert.True(confirmed.IsSuccess, confirmed.Error.Message);

            // A duplicated provider result must not create a second ledger movement.
            var replay = await store.ApplyProviderResultAsync(
                requestId,
                leaseId,
                new RefundProviderResult(
                    RefundProviderOutcome.Confirmed,
                    "response-001",
                    "refund-001",
                    "00"),
                now.AddSeconds(2),
                now.AddSeconds(10));
            Assert.True(replay.IsSuccess, replay.Error.Message);
        }

        await using (var verifyDb = CreatePaymentsDbContext())
        {
            var coordinator = new OriginalPaymentRefundCoordinator(new RefundStore(verifyDb));
            var existing = await coordinator.EnsureRefundAsync(
                bookingId, seed.CustomerId, null, "NO_CAREGIVER_AVAILABLE");
            Assert.True(existing.IsSuccess, existing.Error.Message);
            Assert.Equal(OriginalPaymentRefundState.Confirmed, existing.Value.State);
        }

        var state = await ReadFinancialStateAsync(bookingId, seed);
        Assert.Equal(0, state.CustomerAvailable);
        Assert.Equal(1, state.RefundCount);
        Assert.Equal(100_000, state.RefundAmount);

        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT payment_intent_id, debit_account, credit_account, status
            FROM payments.ledger_entries
            WHERE booking_id = @booking_id AND transaction_type = 'REFUND'
            """, connection);
        command.Parameters.AddWithValue("booking_id", bookingId);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        Assert.Equal(paymentIntentId, reader.GetGuid(0));
        Assert.Equal("escrow:platform", reader.GetString(1));
        Assert.Equal("provider-refund:vnpay", reader.GetString(2));
        Assert.Equal("POSTED", reader.GetString(3));
        Assert.False(await reader.ReadAsync());
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
                seed.CaregiverProfileId,
                escrowAmount: 100_000,
                customerPayableAmount: 100_000,
                promotionSubsidyAmount: 0,
                platformFeeAmount: 15_000,
                decision: "PARTIAL_REFUND",
                refundAmount: 40_000,
                caregiverPenaltyAmount: 5_000);
            Assert.True(result.IsSuccess, result.Error.Message);
        }

        await Task.WhenAll(ResolveAsync(), ResolveAsync());

        var state = await ReadFinancialStateAsync(bookingId, seed);
        Assert.Equal(0, state.CustomerAvailable);
        Assert.Equal(46_000, state.CaregiverAvailable);
        Assert.Equal(0, state.RefundCount);
        Assert.Equal(0, state.RefundAmount);
        Assert.Equal(46_000, state.CaregiverEarningAmount);
        Assert.Equal(9_000, state.PlatformFeeAmount);
        Assert.Equal(5_000, state.PenaltyAmount);
        Assert.Equal(4, state.PostedResolutionEntries);
        Assert.Equal(60_000,
            state.CaregiverEarningAmount + state.PlatformFeeAmount +
            state.PenaltyAmount);
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
            seed.CaregiverProfileId,
            escrowAmount: 100_000,
            customerPayableAmount: 100_000,
            promotionSubsidyAmount: 0,
            platformFeeAmount: 15_000,
            decision: "CUSTOMER_WINS",
            refundAmount: 100_000,
            caregiverPenaltyAmount: 10_000);

        Assert.True(result.IsSuccess, result.Error.Message);
        var state = await ReadFinancialStateAsync(bookingId, seed);
        Assert.Equal(0, state.CustomerAvailable);
        Assert.Equal(0, state.CaregiverAvailable);
        Assert.Equal(0, state.RefundAmount);
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

            await using var bookingDb = new CareSitter.Modules.Booking.Infrastructure.BookingDbContext(
                new DbContextOptionsBuilder<CareSitter.Modules.Booking.Infrastructure.BookingDbContext>()
                    .UseNpgsql(_database.ConnectionString)
                    .Options);
            var booking = await bookingDb.Bookings.SingleAsync(x => x.Id == bookingId);
            var marked = booking.MarkSettlementReleased(releasedAt);
            Assert.True(marked.IsSuccess, marked.Error.Message);
            await bookingDb.SaveChangesAsync();
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
        new WalletLedgerStore(db,
            new PostgresDisputeLookupStub(_database.ConnectionString)),
        new PostgresDisputeLookupStub(_database.ConnectionString),
        new PeopleLookupStub(seed.CaregiverProfileId, seed.CaregiverUserId),
        new OriginalPaymentRefundCoordinator(new RefundStore(db)));

    private async Task InsertSucceededPayOSIntentAsync(
        Guid bookingId,
        Guid customerId,
        long amount)
    {
        await using var db = CreatePaymentsDbContext();
        var intent = PaymentIntent.Create(
            bookingId, customerId, "PAYOS", amount, $"test-{Guid.NewGuid():N}").Value;
        Assert.True(intent.SetProviderOrderRef(
            Random.Shared.NextInt64(1, 9_007_199_254_740_991).ToString()).IsSuccess);
        Assert.True(intent.MarkPending().IsSuccess);
        Assert.True(intent.MarkSucceeded("payos-link-id", finalizedSource: "TEST").IsSuccess);
        db.PaymentIntents.Add(intent);
        await db.SaveChangesAsync();
    }

    private async Task<Guid> InsertSucceededVNPayIntentAsync(
        Guid bookingId,
        Guid customerId,
        long amount)
    {
        await using var db = CreatePaymentsDbContext();
        var intent = PaymentIntent.Create(
            bookingId, customerId, "VNPAY", amount, $"test-{Guid.NewGuid():N}").Value;
        Assert.True(intent.SetProviderOrderRef($"CS{Random.Shared.NextInt64(100_000, 999_999)}").IsSuccess);
        Assert.True(intent.MarkPending().IsSuccess);
        Assert.True(intent.MarkSucceeded(
            Random.Shared.NextInt64(100_000_000, 999_999_999).ToString(),
            finalizedSource: "TEST").IsSuccess);
        db.PaymentIntents.Add(intent);
        await db.SaveChangesAsync();
        return intent.Id;
    }

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

    private async Task<long> CountBookingsAsync(Guid firstBookingId, Guid secondBookingId)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(
            "SELECT count(*) FROM booking.bookings WHERE id IN (@first_booking_id, @second_booking_id)",
            connection);
        command.Parameters.AddWithValue("first_booking_id", firstBookingId);
        command.Parameters.AddWithValue("second_booking_id", secondBookingId);
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
                  ('REFUND','CAREGIVER_EARNING','PLATFORM_FEE','PENALTY','DISPUTE_RESOLUTION')
                  AND status = 'POSTED'),
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

    private sealed class PostgresDisputeLookupStub(string connectionString) : IDisputeLookupService
    {
        public async Task<bool> HasOpenDisputeAsync(
            Guid bookingId, CancellationToken ct = default)
        {
            await using var connection = new NpgsqlConnection(connectionString);
            await connection.OpenAsync(ct);
            await using var command = new NpgsqlCommand("""
                SELECT EXISTS (
                    SELECT 1 FROM support.disputes
                    WHERE booking_id = @booking_id
                      AND status NOT IN ('RESOLVED', 'CANCELLED'))
                """, connection);
            command.Parameters.AddWithValue("booking_id", bookingId);
            return (bool)(await command.ExecuteScalarAsync(ct) ?? false);
        }
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
