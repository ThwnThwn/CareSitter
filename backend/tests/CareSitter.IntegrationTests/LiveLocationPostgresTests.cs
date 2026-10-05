using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands.PostBookingGps;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class LiveLocationPostgresTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;
    private readonly TestClock _clock = new();
    private readonly TestUser _user = new();
    private Guid _booking;
    private Guid _caregiver;

    public async Task InitializeAsync()
    {
        _database = await PostgresRaceTestDatabase.CreateAsync();
        await using var connection = await _database.OpenConnectionAsync();
        await using var seed = new NpgsqlCommand("""
            INSERT INTO booking.bookings (id, customer_id, beneficiary_id, address_id, service_type_id,
                caregiver_id, scheduled_start, scheduled_end, payment_deadline, status)
            SELECT gen_random_uuid(), b.customer_id, b.id, a.id, s.id, c.id,
                now() + interval '100 days', now() + interval '100 days 2 hours',
                now() + interval '30 minutes', 'CAREGIVER_EN_ROUTE'
            FROM people.beneficiaries b JOIN catalog.addresses a ON a.owner_user_id = b.customer_id
            CROSS JOIN LATERAL (SELECT id FROM catalog.service_types ORDER BY id LIMIT 1) s
            CROSS JOIN LATERAL (SELECT id FROM people.caregiver_profiles ORDER BY id LIMIT 1) c
            ORDER BY b.id, a.id LIMIT 1 RETURNING id, caregiver_id
            """, connection);
        await using var reader = await seed.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        _booking = reader.GetGuid(0);
        _caregiver = reader.GetGuid(1);
    }

    public async Task DisposeAsync() { if (_database is not null) await _database.DisposeAsync(); }

    [PostgresFact]
    public async Task LatestOnly_DuplicatesAndOlderSamplesDoNotRenewLeaseOrProduceEvents()
    {
        var session = await Open();
        var sample = Sample(session.Value.SessionId);
        var accepted = await Write(sample);
        Assert.True(accepted.IsSuccess, accepted.Error.Message);
        Assert.NotNull(accepted.Value);
        _clock.UtcNow = _clock.UtcNow.AddSeconds(11);
        Assert.Null((await Write(sample)).Value);
        Assert.Null((await Write(sample with { CapturedAt = sample.CapturedAt.AddSeconds(-1) })).Value);
        var latest = await Read();
        Assert.Equal(accepted.Value.Version, latest!.Version);
        Assert.Equal(accepted.Value.ReceivedAt, latest.ReceivedAt);
        Assert.Equal(1, await Count());
        var next = await Write(Sample(session.Value.SessionId) with { Latitude = 11 });
        Assert.True(next.Value!.Version > latest.Version);
        Assert.Equal(11, (await Read())!.Latitude);
        Assert.Equal(1, await Count());
        Assert.Equal(0, await Scalar("SELECT count(*) FROM booking.gps_tracks WHERE booking_id = @id"));
    }

    [PostgresFact]
    public async Task SessionLease_PreventsSecondSource_ExpiresAndRejectsPreviousSession()
    {
        var source = Guid.NewGuid();
        var first = await Open(source);
        Assert.Equal(first.Value.SessionId, (await Open(source)).Value.SessionId);
        Assert.Equal("booking.gps.source_active", (await Open()).Error.Code);
        Assert.True((await Write(Sample(first.Value.SessionId))).IsSuccess);
        _clock.UtcNow = _clock.UtcNow.AddSeconds(121);
        var second = await Open();
        Assert.True(second.IsSuccess);
        Assert.NotEqual(first.Value.SessionId, second.Value.SessionId);
        Assert.True(second.Value.Version > first.Value.Version);
        Assert.Null(await Read());
        Assert.Equal("booking.gps.invalid_session", (await Write(Sample(first.Value.SessionId))).Error.Code);
        Assert.True((await Write(Sample(second.Value.SessionId))).IsSuccess);
    }

    [PostgresFact]
    public async Task InputTimeRateAssignmentAndExpiryAreEnforced()
    {
        var session = (await Open()).Value;
        Assert.Equal("booking.gps.invalid_time", (await Write(Sample(session.SessionId) with { CapturedAt = _clock.UtcNow.AddSeconds(-61) })).Error.Code);
        Assert.Equal("booking.gps.invalid_time", (await Write(Sample(session.SessionId) with { CapturedAt = _clock.UtcNow.AddSeconds(31) })).Error.Code);
        await Write(Sample(session.SessionId));
        Assert.Equal("booking.gps.rate_limited", (await Write(Sample(session.SessionId) with { CapturedAt = _clock.UtcNow.AddSeconds(1) })).Error.Code);
        await Execute("UPDATE booking.live_locations SET expires_at = received_at - interval '1 second' WHERE booking_id = @id");
        Assert.Null(await Read());
        await using var db = Context();
        Assert.Equal(1, await Store(db).DeleteExpiredBatchAsync(default));
        Assert.Equal(0, await Store(db).DeleteExpiredBatchAsync(default));
        var recreated = await Open();
        Assert.True(recreated.Value.Version > session.Version);
        await Execute("UPDATE booking.bookings SET caregiver_id = NULL WHERE id = @id");
        Assert.Equal(0, await Count());
        Assert.True((await Open()).IsFailure);
    }

    [PostgresFact]
    public async Task AllThreeTerminalStates_DeleteAndRejectLatePackets_IncludingWithRuntimeRole()
    {
        foreach (var status in new[] { "COMPLETED", "CANCELLED", "REFUNDED" })
        {
            await Execute("UPDATE booking.bookings SET status = 'CAREGIVER_EN_ROUTE' WHERE id = @id");
            var session = (await Open()).Value;
            await Write(Sample(session.SessionId));
            await using (var connection = await _database.OpenConnectionAsync())
            {
                await using var tx = await connection.BeginTransactionAsync();
                // A non-owner, non-superuser runtime role exercises the trigger's
                // real permissions. Rollback also removes this temporary role.
                var role = "gps_test_" + Guid.NewGuid().ToString("N");
                await using var permissions = new NpgsqlCommand($"""
                    CREATE ROLE {role} NOLOGIN NOSUPERUSER NOBYPASSRLS;
                    GRANT USAGE ON SCHEMA booking, identity TO {role};
                    GRANT INSERT ON identity.audit_logs TO {role};
                    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA booking TO {role};
                    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA booking TO {role};
                    SET LOCAL ROLE {role};
                    """, connection, tx);
                await permissions.ExecuteNonQueryAsync();
                await using var update = new NpgsqlCommand("UPDATE booking.bookings SET status = @status WHERE id = @id", connection, tx);
                update.Parameters.AddWithValue("status", status);
                update.Parameters.AddWithValue("id", _booking);
                await update.ExecuteNonQueryAsync();
                await using var check = new NpgsqlCommand("SELECT count(*) FROM booking.live_locations WHERE booking_id = @id", connection, tx);
                check.Parameters.AddWithValue("id", _booking);
                Assert.Equal(0L, await check.ExecuteScalarAsync());
                await tx.RollbackAsync();
            }
            await Execute($"UPDATE booking.bookings SET status = '{status}' WHERE id = @id");
            Assert.Equal(0, await Count());
            Assert.Equal("booking.gps.not_en_route", (await Write(Sample(session.SessionId))).Error.Code);
            Assert.Equal("booking.gps.not_en_route", (await Open()).Error.Code);
            Assert.Equal(0, await Count());
        }
    }

    [PostgresFact]
    public async Task GpsLocksBookingFirst_ConcurrentCompletionDeletesCommittedFix()
    {
        var session = (await Open()).Value;
        await using var blocker = await _database.OpenConnectionAsync();
        await using var tx = await blocker.BeginTransactionAsync();
        await using var hold = new NpgsqlCommand("SELECT booking_id FROM booking.live_locations WHERE booking_id = @id FOR UPDATE", blocker, tx);
        hold.Parameters.AddWithValue("id", _booking);
        await hold.ExecuteScalarAsync();
        var write = Write(Sample(session.SessionId));
        await WaitForBlocked(1);
        var complete = Execute("UPDATE booking.bookings SET status = 'COMPLETED' WHERE id = @id");
        await WaitForBlocked(2);
        await tx.CommitAsync();
        Assert.True((await write).IsSuccess);
        await complete;
        Assert.Equal(0, await Count());
        Assert.True((await Write(Sample(session.SessionId))).IsFailure);
    }

    [PostgresFact]
    public async Task CompletionLocksBookingFirst_GpsCannotRecreateDeletedFix()
    {
        var session = (await Open()).Value;
        await using var blocker = await _database.OpenConnectionAsync();
        await using var tx = await blocker.BeginTransactionAsync();
        await using var complete = new NpgsqlCommand("UPDATE booking.bookings SET status = 'COMPLETED' WHERE id = @id", blocker, tx);
        complete.Parameters.AddWithValue("id", _booking);
        await complete.ExecuteNonQueryAsync();
        var write = Write(Sample(session.SessionId));
        await WaitForBlocked(1);
        await tx.CommitAsync();
        Assert.Equal("booking.gps.not_en_route", (await write).Error.Code);
        Assert.Equal(0, await Count());
    }

    [PostgresFact]
    public async Task UnrelatedAndAnonymousUsersCannotReadWriteOrOpenSessions()
    {
        var session = (await Open()).Value;
        await Write(Sample(session.SessionId));
        await using var db = Context();
        var bookings = new BookingTrackingStore(db);
        var people = new UnrelatedPeople();
        foreach (var actor in new[] { new TestUser(Guid.NewGuid()), new TestUser() })
        {
            var reader = new GetLatestBookingGpsQueryHandler(bookings, Store(db), new TestOptions(), actor, people);
            Assert.True((await reader.Handle(new GetLatestBookingGpsQuery(_booking), default)).IsFailure);
            var opener = new OpenGpsSessionHandler(bookings, Store(db), actor, people, new TestOptions());
            Assert.True((await opener.Handle(new OpenGpsSessionCommand(_booking, Guid.NewGuid()), default)).IsFailure);
            var writer = new PostBookingGpsCommandHandler(bookings, Store(db), null!, null!, actor, people,
                new TestOptions(), new PostBookingGpsCommandValidator());
            Assert.True((await writer.Handle(Sample(session.SessionId), default)).IsFailure);
        }
        var booking = await bookings.GetBookingAsync(_booking);
        var customer = new GetLatestBookingGpsQueryHandler(bookings, Store(db), new TestOptions(), new TestUser(booking!.CustomerId), people);
        Assert.True((await customer.Handle(new GetLatestBookingGpsQuery(_booking), default)).IsSuccess);
    }

    [PostgresFact]
    public async Task CheckInHidesLocationAndStopsWrites_PhysicalDeleteCascades()
    {
        var session = (await Open()).Value;
        await Write(Sample(session.SessionId));
        await Execute("UPDATE booking.bookings SET status = 'IN_PROGRESS' WHERE id = @id");
        Assert.Null(await Read());
        Assert.Equal("booking.gps.not_en_route", (await Write(Sample(session.SessionId))).Error.Code);
        await Execute("DELETE FROM booking.bookings WHERE id = @id");
        Assert.Equal(0, await Count());
    }

    private BookingDbContext Context() => new(new DbContextOptionsBuilder<BookingDbContext>()
        .UseNpgsql(_database.ConnectionString, x => x.UseNetTopologySuite()).Options);
    private LiveLocationStore Store(BookingDbContext db) => new(db, _user, _clock, new TestOptions());
    private async Task<Result<LiveTrackingSessionResponse>> Open(Guid? source = null)
    {
        await using var db = Context();
        return await Store(db).OpenSessionAsync(_booking, _caregiver, source ?? Guid.NewGuid(), default);
    }
    private async Task<Result<GpsTrackResponse?>> Write(PostBookingGpsCommand sample)
    {
        await using var db = Context();
        return await Store(db).WriteAsync(sample, _caregiver, default);
    }
    private async Task<GpsTrackResponse?> Read()
    {
        await using var db = Context();
        return await Store(db).GetLatestAsync(_booking, default);
    }
    private PostBookingGpsCommand Sample(Guid session) => new(_booking, session, 10.8, 106.7, _clock.UtcNow, 5);
    private Task<long> Count() => Scalar("SELECT count(*) FROM booking.live_locations WHERE booking_id = @id");
    private async Task<long> Scalar(string sql)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("id", _booking);
        return (long)(await command.ExecuteScalarAsync())!;
    }
    private async Task Execute(string sql)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("id", _booking);
        await command.ExecuteNonQueryAsync();
    }
    private async Task WaitForBlocked(int count)
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(1));
        while (await Scalar("SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock'") < count)
            await Task.Delay(10, timeout.Token);
    }
    private sealed class TestClock : IClock { public DateTimeOffset UtcNow { get; set; } = DateTimeOffset.FromUnixTimeMilliseconds(DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()); }
    private sealed class TestUser(Guid? id = null) : ICurrentUser
    {
        public Guid? UserId => id;
        public IReadOnlyCollection<string> Roles => [];
        public bool IsInRole(string role) => false;
    }
    private sealed class UnrelatedPeople : IPeopleLookupService
    {
        public Task<bool> IsCaregiverForBookingAsync(Guid caregiverId, Guid userId, CancellationToken ct = default) => Task.FromResult(false);
        public Task<bool> BeneficiaryBelongsToAsync(Guid beneficiaryId, Guid customerId, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> CaregiverIsAvailableAsync(Guid caregiverId, DateTimeOffset start, DateTimeOffset end, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> IsCaregiverApprovedAsync(Guid caregiverId, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid userId, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid caregiverId, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid beneficiaryId, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid caregiverId, CancellationToken ct = default) => throw new NotSupportedException();
    }
    private sealed class TestOptions : IOptionsMonitor<LiveTrackingOptions>
    {
        public LiveTrackingOptions CurrentValue { get; } = new() { Enabled = true };
        public LiveTrackingOptions Get(string? name) => CurrentValue;
        public IDisposable? OnChange(Action<LiveTrackingOptions, string?> listener) => null;
    }
}
