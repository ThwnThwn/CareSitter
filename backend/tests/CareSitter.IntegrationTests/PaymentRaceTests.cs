using System.Text.Json;
using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.Payouts;
using CareSitter.Modules.Payments.Application.Payouts.ApprovePayout;
using CareSitter.Modules.Payments.Application.Payouts.CreatePayout;
using CareSitter.Modules.Payments.Application.Payouts.RejectPayout;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class PaymentRaceTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;

    public Task InitializeAsync() => InitializeDatabaseAsync();
    public async Task DisposeAsync()
    {
        if (_database is not null) await _database.DisposeAsync();
    }

    [PostgresFact]
    public async Task ConcurrentPayouts_CannotReserveMoreThanAvailableBalance()
    {
        var caregiver = await GetCaregiverAsync();
        await ResetWalletAsync(caregiver.WalletId, available: 150_000);

        var results = await Task.WhenAll(
            CreatePayoutAsync(caregiver.UserId, Guid.NewGuid().ToString("N")),
            CreatePayoutAsync(caregiver.UserId, Guid.NewGuid().ToString("N")));

        Assert.Single(results, x => x.IsSuccess && x.Value.Created);
        Assert.Single(results, x =>
            x.IsFailure && x.Error.Code == PayoutErrors.InsufficientBalanceCode);

        var state = await ReadPayoutStateAsync(caregiver.UserId);
        Assert.Equal(50_000, state.Available);
        Assert.Equal(100_000, state.Pending);
        Assert.Equal(1, state.PayoutCount);
    }

    [PostgresFact]
    public async Task ConcurrentPayoutRetry_WithSameKey_ReservesExactlyOnce()
    {
        var caregiver = await GetCaregiverAsync();
        await ResetWalletAsync(caregiver.WalletId, available: 300_000);
        var key = Guid.NewGuid().ToString("N");

        var results = await Task.WhenAll(
            CreatePayoutAsync(caregiver.UserId, key),
            CreatePayoutAsync(caregiver.UserId, key));

        Assert.All(results, result => Assert.True(result.IsSuccess, result.Error.Message));
        Assert.Single(results, x => x.Value.Created);
        Assert.Single(results, x => !x.Value.Created);
        var state = await ReadPayoutStateAsync(caregiver.UserId);
        Assert.Equal(200_000, state.Available);
        Assert.Equal(100_000, state.Pending);
        Assert.Equal(1, state.PayoutCount);
    }

    [PostgresFact]
    public async Task ConcurrentApproveAndReject_OnlyOneTransitionChangesMoney()
    {
        var caregiver = await GetCaregiverAsync();
        await ResetWalletAsync(caregiver.WalletId, available: 200_000);
        var created = await CreatePayoutAsync(
            caregiver.UserId, Guid.NewGuid().ToString("N"));
        Assert.True(created.IsSuccess, created.Error.Message);
        Assert.True(created.Value.Created);
        var payout = created.Value.Payout;
        var adminId = await GetAdminUserIdAsync();

        var results = await Task.WhenAll(
            ReviewPayoutAsync(adminId, payout.Id, approve: true),
            ReviewPayoutAsync(adminId, payout.Id, approve: false));

        Assert.Single(results, x => x.IsSuccess);
        Assert.Single(results, x =>
            x.IsFailure && x.Error.Type == CareSitter.SharedKernel.Results.ErrorType.Conflict);

        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT payout.status, wallet.available_balance, wallet.pending_balance,
                   (SELECT count(*) FROM payments.ledger_entries ledger
                    WHERE ledger.payout_request_id = payout.id)
            FROM payments.payout_requests payout
            JOIN payments.wallet_accounts wallet ON wallet.id = payout.wallet_account_id
            WHERE payout.id = @id
            """, connection);
        command.Parameters.AddWithValue("id", payout.Id);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        var status = reader.GetString(0);
        var available = reader.GetInt64(1);
        var pending = reader.GetInt64(2);
        var ledgerCount = reader.GetInt64(3);

        if (status == "APPROVED")
        {
            Assert.Equal(100_000, available);
            Assert.Equal(0, pending);
            Assert.Equal(1, ledgerCount);
        }
        else
        {
            Assert.Equal("REJECTED", status);
            Assert.Equal(200_000, available);
            Assert.Equal(0, pending);
            Assert.Equal(0, ledgerCount);
        }
    }

    [PostgresFact]
    public async Task ConcurrentSettlement_CreditsCaregiverExactlyOnce()
    {
        var caregiver = await GetCaregiverAsync();
        await ResetWalletAsync(caregiver.WalletId, available: 0);
        var booking = await CreateBookingAsync("COMPLETED", caregiver.ProfileId);

        async Task<CareSitter.SharedKernel.Results.Result> SettleAsync()
        {
            await using var db = CreatePaymentsDbContext();
            var service = new WalletService(
                new WalletLedgerStore(db),
                new DisputeLookupStub(),
                new PeopleLookupStub(caregiver.ProfileId, caregiver.UserId));
            return await service.SettleAsync(
                booking.BookingId, caregiver.ProfileId, 100_000, 15_000);
        }

        var results = await Task.WhenAll(SettleAsync(), SettleAsync());
        Assert.All(results, result => Assert.True(result.IsSuccess));

        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT wallet.available_balance,
                   count(*) FILTER (WHERE ledger.transaction_type = 'CAREGIVER_EARNING'),
                   count(*) FILTER (WHERE ledger.transaction_type = 'PLATFORM_FEE')
            FROM payments.wallet_accounts wallet
            LEFT JOIN payments.ledger_entries ledger ON ledger.booking_id = @booking_id
            WHERE wallet.id = @wallet_id
            GROUP BY wallet.available_balance
            """, connection);
        command.Parameters.AddWithValue("booking_id", booking.BookingId);
        command.Parameters.AddWithValue("wallet_id", caregiver.WalletId);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        Assert.Equal(85_000, reader.GetInt64(0));
        Assert.Equal(1, reader.GetInt64(1));
        Assert.Equal(1, reader.GetInt64(2));
    }

    [PostgresFact]
    public async Task ConcurrentPaymentFinalization_FinalizesBookingAndEscrowOnce()
    {
        var booking = await CreateBookingAsync("PENDING_PAYMENT", caregiverProfileId: null);
        Guid intentId;
        await using (var paymentsDb = CreatePaymentsDbContext())
        {
            var intent = PaymentIntent.Create(
                booking.BookingId,
                booking.CustomerId,
                "VNPAY",
                100_000,
                Guid.NewGuid().ToString("N")).Value;
            Assert.True(intent.MarkPending().IsSuccess);
            intentId = intent.Id;
            paymentsDb.PaymentIntents.Add(intent);
            await paymentsDb.SaveChangesAsync();
        }

        async Task<PaymentFinalizationResult> FinalizeAsync()
        {
            await using var paymentsDb = CreatePaymentsDbContext();
            await using var bookingDb = CreateBookingDbContext();
            var outbox = new BookingConfirmingOutboxDispatcher(paymentsDb, bookingDb);
            var service = new PaymentFinalizationService(
                paymentsDb,
                outbox,
                new AuditLoggerStub(),
                NullLogger<PaymentFinalizationService>.Instance);
            return await service.FinalizeSuccessfulPaymentAsync(
                intentId,
                "txn-race-1",
                "{}",
                PaymentFinalizationSource.Ipn);
        }

        var results = await Task.WhenAll(FinalizeAsync(), FinalizeAsync());
        Assert.All(results, result => Assert.True(result.Succeeded));

        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT booking.status,
                   (SELECT count(*) FROM payments.payment_intents intent
                    WHERE intent.booking_id = booking.id AND intent.status = 'SUCCEEDED'),
                   (SELECT count(*) FROM payments.ledger_entries ledger
                    WHERE ledger.booking_id = booking.id AND ledger.transaction_type = 'ESCROW_LOCK')
            FROM booking.bookings booking
            WHERE booking.id = @booking_id
            """, connection);
        command.Parameters.AddWithValue("booking_id", booking.BookingId);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        Assert.Equal("CONFIRMED", reader.GetString(0));
        Assert.Equal(1, reader.GetInt64(1));
        Assert.Equal(1, reader.GetInt64(2));
    }

    [PostgresFact]
    public async Task OriginalVnpayCreateDate_survives_database_reload_and_generates_identical_link()
    {
        var booking = await CreateBookingAsync("PENDING_PAYMENT", null);
        var createdAt = new DateTimeOffset(2026, 9, 30, 3, 0, 0, TimeSpan.Zero);
        var intent = PaymentIntent.Create(booking.BookingId, booking.CustomerId, "VNPAY",
            100000, Guid.NewGuid().ToString("N"), createdAt: createdAt).Value;
        Assert.True(intent.SetProviderOrderRef("CSdate01").IsSuccess);
        Assert.True(intent.MarkPending().IsSuccess);
        var options = new VNPayOptions
        {
            TmnCode = "TEST0001", HashSecret = "local-test-key",
            ReturnUrl = "https://example.test/return"
        };
        var service = new VNPayService(new HttpClient());
        var original = service.BuildPaymentUrl(intent, options);
        await using (var db = CreatePaymentsDbContext())
        {
            db.PaymentIntents.Add(intent);
            await db.SaveChangesAsync();
        }
        await using var reloadedDb = CreatePaymentsDbContext();
        var reloaded = await reloadedDb.PaymentIntents.AsNoTracking().SingleAsync(x => x.Id == intent.Id);
        Assert.Equal("20260930100000", reloaded.ProviderCreateDate);
        Assert.Equal(original, service.BuildPaymentUrl(reloaded, options));
    }

    [PostgresFact]
    public async Task Legacy_payment_original_date_is_not_backfilled_from_created_at()
    {
        var booking = await CreateBookingAsync("PENDING_PAYMENT", null);
        var intent = PaymentIntent.Create(booking.BookingId, booking.CustomerId, "VNPAY",
            100000, Guid.NewGuid().ToString("N")).Value;
        Assert.True(intent.SetProviderOrderRef("CSlegacy01").IsSuccess);
        Assert.True(intent.MarkPending().IsSuccess);
        await using (var db = CreatePaymentsDbContext())
        {
            db.PaymentIntents.Add(intent);
            await db.SaveChangesAsync();
        }
        await using (var connection = await _database.OpenConnectionAsync())
        {
            await using var command = new NpgsqlCommand(
                "UPDATE payments.payment_intents SET provider_create_date = NULL WHERE id = @id", connection);
            command.Parameters.AddWithValue("id", intent.Id);
            await command.ExecuteNonQueryAsync();
        }
        await using var reloadedDb = CreatePaymentsDbContext();
        var legacy = await reloadedDb.PaymentIntents.AsNoTracking().SingleAsync(x => x.Id == intent.Id);
        Assert.Null(legacy.ProviderCreateDate);
        var result = await new VNPayService(new HttpClient()).QueryTransactionAsync(legacy, new VNPayOptions
        {
            TmnCode = "TEST0001", HashSecret = "local-test-key"
        });
        Assert.Equal(VNPayQueryState.Unknown, result.State);
        Assert.Equal("MISSING_ORIGINAL_CREATE_DATE", result.ResponseCode);
    }

    private async Task InitializeDatabaseAsync() =>
        _database = await PostgresRaceTestDatabase.CreateAsync();

    private PaymentsDbContext CreatePaymentsDbContext() => new(
        new DbContextOptionsBuilder<PaymentsDbContext>()
            .UseNpgsql(_database.ConnectionString)
            .Options);

    private BookingDbContext CreateBookingDbContext() => new(
        new DbContextOptionsBuilder<BookingDbContext>()
            .UseNpgsql(_database.ConnectionString)
            .Options);

    private async Task<CareSitter.SharedKernel.Results.Result<CreatePayoutResult>> CreatePayoutAsync(
        Guid caregiverUserId,
        string idempotencyKey)
    {
        await using var db = CreatePaymentsDbContext();
        var encryption = new EncryptionStub();
        var handler = new CreatePayoutCommandHandler(
            new PayoutStore(db),
            new CurrentUserStub(caregiverUserId, "CAREGIVER"),
            encryption,
            new AuditLoggerStub(),
            new PayoutMapper(encryption));
        return await handler.Handle(new CreatePayoutCommand(
            100_000,
            "VCB",
            "NGUYEN VAN A",
            "0123456789",
            idempotencyKey,
            null), CancellationToken.None);
    }

    private async Task<CareSitter.SharedKernel.Results.Result<PayoutResponse>> ReviewPayoutAsync(
        Guid adminId,
        Guid payoutId,
        bool approve)
    {
        await using var db = CreatePaymentsDbContext();
        var user = new CurrentUserStub(adminId, "ADMIN");
        var encryption = new EncryptionStub();
        var mapper = new PayoutMapper(encryption);
        if (approve)
        {
            var handler = new ApprovePayoutCommandHandler(
                new PayoutStore(db),
                user,
                new AuditLoggerStub(),
                mapper);
            return await handler.Handle(
                new ApprovePayoutCommand(payoutId), CancellationToken.None);
        }

        var rejectHandler = new RejectPayoutCommandHandler(
            new PayoutStore(db),
            user,
            new AuditLoggerStub(),
            mapper);
        return await rejectHandler.Handle(
            new RejectPayoutCommand(payoutId, "Thông tin chưa hợp lệ"),
            CancellationToken.None);
    }

    private async Task<CaregiverRecord> GetCaregiverAsync()
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT profile.id, profile.user_id, wallet.id
            FROM people.caregiver_profiles profile
            JOIN payments.wallet_accounts wallet
              ON wallet.user_id = profile.user_id AND wallet.account_type = 'CAREGIVER'
            ORDER BY profile.id
            LIMIT 1
            """, connection);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        return new CaregiverRecord(reader.GetGuid(0), reader.GetGuid(1), reader.GetGuid(2));
    }

    private async Task<Guid> GetAdminUserIdAsync()
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(
            "SELECT id FROM identity.users WHERE 'ADMIN' = ANY(roles) ORDER BY id LIMIT 1", connection);
        return (Guid)(await command.ExecuteScalarAsync()
            ?? throw new InvalidOperationException("Seed admin was not found."));
    }

    private async Task ResetWalletAsync(Guid walletId, long available)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            DELETE FROM payments.ledger_entries
            WHERE payout_request_id IN (
                SELECT id FROM payments.payout_requests WHERE wallet_account_id = @wallet_id);
            DELETE FROM payments.payout_requests WHERE wallet_account_id = @wallet_id;
            UPDATE payments.wallet_accounts
            SET available_balance = @available, pending_balance = 0
            WHERE id = @wallet_id;
            """, connection);
        command.Parameters.AddWithValue("wallet_id", walletId);
        command.Parameters.AddWithValue("available", available);
        await command.ExecuteNonQueryAsync();
    }

    private async Task<PayoutState> ReadPayoutStateAsync(Guid userId)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT wallet.available_balance, wallet.pending_balance,
                   (SELECT count(*) FROM payments.payout_requests payout
                    WHERE payout.caregiver_id = @user_id)
            FROM payments.wallet_accounts wallet
            WHERE wallet.user_id = @user_id AND wallet.account_type = 'CAREGIVER'
            """, connection);
        command.Parameters.AddWithValue("user_id", userId);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        return new PayoutState(reader.GetInt64(0), reader.GetInt64(1), reader.GetInt64(2));
    }

    private async Task<BookingRecord> CreateBookingAsync(string status, Guid? caregiverProfileId)
    {
        var bookingId = Guid.NewGuid();
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO booking.bookings (
                id, customer_id, beneficiary_id, caregiver_id, address_id, service_type_id,
                scheduled_start, scheduled_end, payment_deadline, status,
                escrow_amount, platform_fee_amount, caregiver_earning_amount)
            SELECT @id, beneficiary.customer_id, beneficiary.id, @caregiver_id,
                   address.id, service.id,
                   now() + interval '2 days', now() + interval '2 days 2 hours',
                   now() + interval '30 minutes', @status,
                   100000, 15000, 85000
            FROM people.beneficiaries beneficiary
            JOIN catalog.addresses address ON address.owner_user_id = beneficiary.customer_id
            CROSS JOIN LATERAL (
                SELECT id FROM catalog.service_types ORDER BY id LIMIT 1
            ) service
            ORDER BY beneficiary.id, address.id
            LIMIT 1
            RETURNING customer_id
            """, connection);
        command.Parameters.AddWithValue("id", bookingId);
        command.Parameters.AddWithValue("caregiver_id", (object?)caregiverProfileId ?? DBNull.Value);
        command.Parameters.AddWithValue("status", status);
        var customerId = (Guid)(await command.ExecuteScalarAsync()
            ?? throw new InvalidOperationException("Seed booking was not found."));
        return new BookingRecord(bookingId, customerId);
    }

    private sealed record CaregiverRecord(Guid ProfileId, Guid UserId, Guid WalletId);
    private sealed record PayoutState(long Available, long Pending, long PayoutCount);
    private sealed record BookingRecord(Guid BookingId, Guid CustomerId);

    private sealed class CurrentUserStub(Guid userId, params string[] roles) : ICurrentUser
    {
        public Guid? UserId => userId;
        public IReadOnlyCollection<string> Roles => roles;
        public bool IsInRole(string role) => roles.Contains(role, StringComparer.OrdinalIgnoreCase);
    }

    private sealed class EncryptionStub : IEncryptionService
    {
        public string Encrypt(string plaintext) => $"encrypted:{plaintext}";
        public string Decrypt(string ciphertext) => ciphertext.Replace("encrypted:", string.Empty);
        public string Hmac(string value) => value;
    }

    private sealed class AuditLoggerStub : IAuditLogger
    {
        public Task WriteAsync(string action, string entityType, Guid entityId,
            object? before, object? after, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class BookingConfirmingOutboxDispatcher(
        PaymentsDbContext paymentsDb,
        BookingDbContext bookingDb) : IPaymentOutboxDispatcher
    {
        public async Task DispatchAsync(Guid messageId, CancellationToken ct = default)
        {
            var message = await paymentsDb.OutboxMessages.SingleAsync(x => x.Id == messageId, ct);
            var integrationEvent = JsonSerializer.Deserialize<PaymentSucceeded>(message.Payload)
                ?? throw new InvalidOperationException("Invalid payment event payload.");
            var booking = await bookingDb.Bookings.SingleAsync(
                x => x.Id == integrationEvent.BookingId, ct);
            if (booking.Status != CareSitter.Modules.Booking.Domain.BookingStatus.Confirmed)
            {
                var result = booking.ConfirmPayment();
                Assert.True(result.IsSuccess, result.Error.Message);
                await bookingDb.SaveChangesAsync(ct);
            }

            message.MarkProcessed(DateTimeOffset.UtcNow);
            await paymentsDb.SaveChangesAsync(ct);
        }

        public async Task<int> DispatchPendingAsync(
            int batchSize = 20, CancellationToken ct = default)
        {
            var ids = await paymentsDb.OutboxMessages.AsNoTracking()
                .Where(x => x.ProcessedOnUtc == null)
                .Take(batchSize)
                .Select(x => x.Id)
                .ToListAsync(ct);
            foreach (var id in ids) await DispatchAsync(id, ct);
            return ids.Count;
        }
    }

    private sealed class DisputeLookupStub : IDisputeLookupService
    {
        public Task<bool> HasOpenDisputeAsync(Guid bookingId, CancellationToken ct = default) =>
            Task.FromResult(false);
    }

    private sealed class PeopleLookupStub(Guid profileId, Guid userId) : IPeopleLookupService
    {
        public Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid caregiverId, CancellationToken ct = default) =>
            Task.FromResult<Guid?>(caregiverId == profileId ? userId : null);
        public Task<bool> BeneficiaryBelongsToAsync(Guid beneficiaryId, Guid customerId, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> CaregiverIsAvailableAsync(Guid caregiverId, DateTimeOffset start, DateTimeOffset end, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> IsCaregiverApprovedAsync(Guid caregiverId, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> IsCaregiverForBookingAsync(Guid caregiverId, Guid userId, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid userId, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid beneficiaryId, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid caregiverId, CancellationToken ct = default) => throw new NotSupportedException();
    }
}
