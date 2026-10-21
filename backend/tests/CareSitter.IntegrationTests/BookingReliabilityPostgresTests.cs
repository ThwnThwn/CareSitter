using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Npgsql;
using BookingAggregate = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class BookingReliabilityPostgresTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;

    public async Task InitializeAsync() =>
        _database = await PostgresRaceTestDatabase.CreateAsync();

    public async Task DisposeAsync()
    {
        if (_database is not null) await _database.DisposeAsync();
    }

    [PostgresFact]
    public async Task Concurrent_create_with_same_key_commits_one_booking_and_replays_it()
    {
        var seed = await ReadSeedAsync();
        var key = Guid.NewGuid();
        var createdCount = 0;
        var start = DateTimeOffset.UtcNow.AddDays(5);

        async Task<Result<BookingAggregate>> ExecuteAsync()
        {
            await using var db = CreateDb();
            var store = new BookingCreationIdempotencyStore(db, new SystemClock());
            return await store.ExecuteAsync(seed.CustomerId, key, new string('a', 64),
                _ =>
                {
                    Interlocked.Increment(ref createdCount);
                    var booking = BookingAggregate.Create(
                        seed.CustomerId, seed.BeneficiaryId, seed.AddressId, seed.ServiceTypeId,
                        start, start.AddHours(2)).Value;
                    Assert.True(booking.ApplyPricing(100_000, 15_000, 85_000).IsSuccess);
                    Assert.True(booking.TransitionTo(BookingStatus.PendingPayment).IsSuccess);
                    db.Bookings.Add(booking);
                    return Task.FromResult<Result<BookingAggregate>>(booking);
                }, CancellationToken.None);
        }

        var results = await Task.WhenAll(ExecuteAsync(), ExecuteAsync());

        Assert.All(results, result => Assert.True(result.IsSuccess, result.Error.Message));
        Assert.Equal(results[0].Value.Id, results[1].Value.Id);
        Assert.Equal(1, createdCount);
        await using var verify = CreateDb();
        Assert.Equal(1, await verify.Bookings.CountAsync(x => x.Id == results[0].Value.Id));
        Assert.Equal(1, await verify.BookingDomainOutbox.CountAsync(
            x => x.BookingId == results[0].Value.Id));
    }

    [PostgresFact]
    public async Task Reusing_key_with_different_payload_is_conflict()
    {
        var seed = await ReadSeedAsync();
        var key = Guid.NewGuid();
        var start = DateTimeOffset.UtcNow.AddDays(6);
        await using var db = CreateDb();
        var store = new BookingCreationIdempotencyStore(db, new SystemClock());
        var first = await store.ExecuteAsync(seed.CustomerId, key, new string('b', 64),
            _ =>
            {
                var booking = BookingAggregate.Create(
                    seed.CustomerId, seed.BeneficiaryId, seed.AddressId, seed.ServiceTypeId,
                    start, start.AddHours(2)).Value;
                Assert.True(booking.TransitionTo(BookingStatus.PendingPayment).IsSuccess);
                db.Bookings.Add(booking);
                return Task.FromResult<Result<BookingAggregate>>(booking);
            }, CancellationToken.None);
        Assert.True(first.IsSuccess, first.Error.Message);

        await using var replayDb = CreateDb();
        var replayStore = new BookingCreationIdempotencyStore(replayDb, new SystemClock());
        var replay = await replayStore.ExecuteAsync(seed.CustomerId, key, new string('c', 64),
            _ => throw new InvalidOperationException("Conflicting replay must not create."),
            CancellationToken.None);

        Assert.True(replay.IsFailure);
        Assert.Equal("booking.idempotency.conflict", replay.Error.Code);
    }

    [PostgresFact]
    public async Task Domain_outbox_dispatches_committed_status_side_effects_and_marks_processed()
    {
        var seed = await ReadSeedAsync();
        var start = DateTimeOffset.UtcNow.AddDays(7);
        Guid bookingId;

        await using (var db = CreateDb())
        {
            var booking = BookingAggregate.Create(
                seed.CustomerId, seed.BeneficiaryId, seed.AddressId, seed.ServiceTypeId,
                start, start.AddHours(2)).Value;
            Assert.True(booking.ApplyPricing(100_000, 15_000, 85_000).IsSuccess);
            Assert.True(booking.TransitionTo(BookingStatus.PendingPayment).IsSuccess);
            Assert.True(booking.ConfirmPayment().IsSuccess);
            db.Bookings.Add(booking);
            new BookingSyncService(db).WriteSyncEvent(
                booking, BookingSyncEventTypes.PaymentConfirmed);
            await db.SaveChangesAsync();
            bookingId = booking.Id;

            Assert.Equal(2, await db.BookingDomainOutbox.CountAsync(
                x => x.BookingId == bookingId && x.Status == "PENDING"));
        }

        await using var dispatchDb = CreateDb();
        var hub = new RecordingHubContext();
        var notifications = new RecordingNotificationService();
        var dispatcher = new BookingDomainOutboxDispatcher(
            dispatchDb,
            hub,
            new BookingSyncService(dispatchDb),
            notifications,
            new PeopleLookupStub(),
            new SystemClock(),
            Options.Create(new BookingSideEffectOptions
            {
                BatchSize = 10,
                LeaseSeconds = 5,
                MaxAttempts = 3,
                RetryDelaySeconds = 1
            }),
            NullLogger<BookingDomainOutboxDispatcher>.Instance);

        Assert.Equal(2, await dispatcher.DispatchPendingAsync(CancellationToken.None));

        dispatchDb.ChangeTracker.Clear();
        var outbox = await dispatchDb.BookingDomainOutbox
            .Where(x => x.BookingId == bookingId)
            .OrderBy(x => x.OccurredAt)
            .ToListAsync();
        Assert.Equal(2, outbox.Count);
        Assert.All(outbox, message =>
        {
            Assert.Equal("PROCESSED", message.Status);
            Assert.NotNull(message.ProcessedAt);
            Assert.Null(message.ClaimToken);
            Assert.Null(message.LeaseUntil);
        });

        Assert.Equal(2, hub.Messages.Count(x => x.Method == "BookingListSync"));
        var statusMessage = Assert.Single(
            hub.Messages, x => x.Method == "BookingStatusChanged");
        var status = Assert.IsType<BookingStatusChangedEvent>(
            Assert.Single(statusMessage.Args));
        Assert.Equal(bookingId, status.BookingId);
        Assert.Equal("confirmed", status.NewStatus);

        var notification = Assert.Single(notifications.Messages);
        Assert.Equal(seed.CustomerId, notification.UserId);
        Assert.Equal("Thanh toán thành công", notification.Title);
        Assert.NotNull(notification.EventId);
        Assert.NotEqual(Guid.Empty, notification.EventId!.Value);
        Assert.Equal(bookingId.ToString(), notification.Data!["bookingId"]);
        Assert.Equal("confirmed", notification.Data["status"]);
    }

    private BookingDbContext CreateDb() => new(
        new DbContextOptionsBuilder<BookingDbContext>()
            .UseNpgsql(_database.ConnectionString)
            .Options);

    private async Task<Seed> ReadSeedAsync()
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT beneficiary.customer_id, beneficiary.id, address.id, service.id
            FROM people.beneficiaries beneficiary
            JOIN catalog.addresses address ON address.owner_user_id = beneficiary.customer_id
            CROSS JOIN LATERAL (
                SELECT id FROM catalog.service_types ORDER BY id LIMIT 1
            ) service
            ORDER BY beneficiary.id, address.id
            LIMIT 1
            """, connection);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        return new Seed(reader.GetGuid(0), reader.GetGuid(1), reader.GetGuid(2), reader.GetGuid(3));
    }

    private sealed record Seed(
        Guid CustomerId,
        Guid BeneficiaryId,
        Guid AddressId,
        Guid ServiceTypeId);

    private sealed class RecordingNotificationService : IUserNotificationService
    {
        public List<UserNotificationMessage> Messages { get; } = [];

        public Task NotifyAsync(UserNotificationMessage message,
            CancellationToken ct = default)
        {
            Messages.Add(message);
            return Task.CompletedTask;
        }
    }

    private sealed class RecordingHubContext : IHubContext<CareTrackingHub>
    {
        private readonly RecordingClientProxy _client = new();

        public IHubClients Clients => new RecordingHubClients(_client);
        public IGroupManager Groups { get; } = new NoOpGroupManager();
        public IReadOnlyList<(string Method, object?[] Args)> Messages => _client.Messages;
    }

    private sealed class RecordingHubClients(IClientProxy client) : IHubClients
    {
        public IClientProxy All => client;
        public IClientProxy AllExcept(IReadOnlyList<string> excludedConnectionIds) => client;
        public IClientProxy Client(string connectionId) => client;
        public IClientProxy Clients(IReadOnlyList<string> connectionIds) => client;
        public IClientProxy Group(string groupName) => client;
        public IClientProxy GroupExcept(string groupName,
            IReadOnlyList<string> excludedConnectionIds) => client;
        public IClientProxy Groups(IReadOnlyList<string> groupNames) => client;
        public IClientProxy User(string userId) => client;
        public IClientProxy Users(IReadOnlyList<string> userIds) => client;
    }

    private sealed class RecordingClientProxy : IClientProxy
    {
        public List<(string Method, object?[] Args)> Messages { get; } = [];

        public Task SendCoreAsync(string method, object?[] args,
            CancellationToken cancellationToken = default)
        {
            Messages.Add((method, args));
            return Task.CompletedTask;
        }
    }

    private sealed class NoOpGroupManager : IGroupManager
    {
        public Task AddToGroupAsync(string connectionId, string groupName,
            CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task RemoveFromGroupAsync(string connectionId, string groupName,
            CancellationToken cancellationToken = default) => Task.CompletedTask;
    }

    private sealed class PeopleLookupStub : IPeopleLookupService
    {
        public Task<bool> BeneficiaryBelongsToAsync(Guid beneficiaryId, Guid customerId,
            CancellationToken ct = default) => Task.FromResult(false);
        public Task<bool> CaregiverIsAvailableAsync(Guid caregiverId, DateTimeOffset start,
            DateTimeOffset end, CancellationToken ct = default) => Task.FromResult(false);
        public Task<bool> IsCaregiverApprovedAsync(Guid caregiverId,
            CancellationToken ct = default) => Task.FromResult(false);
        public Task<bool> IsCaregiverForBookingAsync(Guid caregiverId, Guid userId,
            CancellationToken ct = default) => Task.FromResult(false);
        public Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid userId,
            CancellationToken ct = default) => Task.FromResult<Guid?>(null);
        public Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid caregiverId,
            CancellationToken ct = default) => Task.FromResult<Guid?>(null);
        public Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid beneficiaryId,
            CancellationToken ct = default) => Task.FromResult<PeopleDisplaySummary?>(null);
        public Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid caregiverId,
            CancellationToken ct = default) => Task.FromResult<PeopleDisplaySummary?>(null);
    }
}
