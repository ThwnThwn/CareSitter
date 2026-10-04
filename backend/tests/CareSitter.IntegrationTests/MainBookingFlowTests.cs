using CareSitter.Contracts.Services;
using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands.AcceptBooking;
using CareSitter.Modules.Booking.Application.Commands.CancelBooking;
using CareSitter.Modules.Booking.Application.Commands.CompleteBooking;
using CareSitter.Modules.Booking.Application.Commands.CheckInBooking;
using CareSitter.Modules.Booking.Application.Commands.RequestBookingCheckout;
using CareSitter.Modules.Booking.Application.Commands.RescheduleBooking;
using CareSitter.Modules.Booking.Application.Commands.StartBookingEnRoute;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Npgsql;
using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class MainBookingFlowTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;

    public async Task InitializeAsync() =>
        _database = await PostgresRaceTestDatabase.CreateAsync();

    public async Task DisposeAsync()
    {
        if (_database is not null) await _database.DisposeAsync();
    }

    [PostgresFact]
    public async Task CancelPaidBooking_ReleasesCommittedSlot_AllowingAnotherBooking()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "CONFIRMED");
        var hold = await AddHoldAsync(db, booking, committed: true);
        var handler = new CancelBookingCommandHandler(new BookingRepository(db),
            new Actor(booking.CustomerId, "CUSTOMER"), new SystemClock(), new Promotions(),
            new BookingSyncService(db), new PostCommit(), new Mapper());

        var result = await handler.Handle(new(booking.Id, "Đổi kế hoạch"), default);

        Assert.True(result.IsSuccess, result.Error.Message);
        await db.Entry(hold).ReloadAsync();
        Assert.Equal("RELEASED", hold.Status);
        Assert.NotNull(hold.ReleasedAt);
        var replacement = await SeedBookingAsync(db, "CONFIRMED");
        var replacementHold = CaregiverSlotHold.Create(replacement.Id,
            booking.CaregiverId!.Value, booking.ScheduledStart, booking.ScheduledEnd,
            DateTimeOffset.UtcNow.AddMinutes(30)).Value;
        db.CaregiverSlotHolds.Add(replacementHold);
        await db.SaveChangesAsync();
    }

    [PostgresFact]
    public async Task RescheduleUnpaidBooking_MovesExistingSlotToNewWindow()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "PENDING_PAYMENT");
        var hold = await AddHoldAsync(db, booking, committed: false);
        var start = booking.ScheduledStart.AddDays(1);
        var end = start.AddHours(3);

        var result = await RescheduleHandler(db, booking, 150_000)
            .Handle(new(booking.Id, start, end), default);

        Assert.True(result.IsSuccess, result.Error.Message);
        await db.Entry(hold).ReloadAsync();
        Assert.Equal(start, hold.ScheduledStart);
        Assert.Equal(end, hold.ScheduledEnd);
        Assert.Equal("HELD", hold.Status);
        Assert.Equal(150_000, booking.CustomerPayableAmount);
    }

    [PostgresFact]
    public async Task ReschedulePaidBooking_CannotChangeEscrowAlreadyCollected()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "CONFIRMED");
        var originalStart = booking.ScheduledStart;

        var result = await RescheduleHandler(db, booking, 200_000)
            .Handle(new(booking.Id, originalStart.AddDays(1), originalStart.AddDays(1).AddHours(4)), default);

        Assert.True(result.IsFailure);
        Assert.Equal("booking.reschedule.paid_price_change", result.Error.Code);
        await db.Entry(booking).ReloadAsync();
        Assert.Equal(originalStart, booking.ScheduledStart);
        Assert.Equal(100_000, booking.EscrowAmount);
    }

    [PostgresFact]
    public async Task ReschedulePaidBooking_WithSamePrice_MovesCommittedSlot()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "CONFIRMED");
        var hold = await AddHoldAsync(db, booking, committed: true);
        var start = booking.ScheduledStart.AddDays(1);

        var result = await RescheduleHandler(db, booking, 100_000)
            .Handle(new(booking.Id, start, start.AddHours(2)), default);

        Assert.True(result.IsSuccess, result.Error.Message);
        await db.Entry(hold).ReloadAsync();
        Assert.Equal(start, hold.ScheduledStart);
        Assert.Equal("COMMITTED", hold.Status);
        Assert.Equal(100_000, booking.EscrowAmount);
    }

    [PostgresFact]
    public async Task AcceptPreselectedBooking_RechecksKycApproval()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "CONFIRMED");
        var caregiverUserId = Guid.NewGuid();
        var handler = new AcceptBookingCommandHandler(new BookingRepository(db),
            new BookingAcceptanceTransaction(db), new Actor(caregiverUserId, "CAREGIVER"),
            new People(booking.CaregiverId!.Value, caregiverUserId, approved: false), null!,
            new BookingSyncService(db), new PostCommit(), new Mapper());

        var result = await handler.Handle(new(booking.Id), default);

        Assert.True(result.IsFailure);
        Assert.Equal("booking.caregiver.not_eligible", result.Error.Code);
        await db.Entry(booking).ReloadAsync();
        Assert.Equal(BookingStatus.Confirmed, booking.Status);
        Assert.False(await db.TimelineEvents.AnyAsync(x => x.BookingId == booking.Id));
    }

    [PostgresFact]
    public async Task AcceptPreselectedBooking_WithApprovedKyc_Succeeds()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "CONFIRMED");
        var caregiverUserId = Guid.NewGuid();
        var handler = new AcceptBookingCommandHandler(new BookingRepository(db),
            new BookingAcceptanceTransaction(db), new Actor(caregiverUserId, "CAREGIVER"),
            new People(booking.CaregiverId!.Value, caregiverUserId, approved: true), null!,
            new BookingSyncService(db), new PostCommit(), new Mapper());

        var result = await handler.Handle(new(booking.Id), default);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(BookingStatus.CaregiverAccepted, booking.Status);
        Assert.Equal("COMMITTED", (await db.CaregiverSlotHolds.SingleAsync()).Status);
    }

    [PostgresFact]
    public async Task CheckoutNeedingReview_RequiresAdmin_ThenCompletes()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "CHECKOUT_PENDING_REVIEW");
        booking.MarkNeedsReview();
        await db.SaveChangesAsync();

        CompleteBookingCommandHandler Handler(ICurrentUser actor) => new(
            new BookingRepository(db), actor, new Disputes(), new BookingSyncService(db),
            new PostCommit(), new Audit(), new Mapper());
        var customerResult = await Handler(new Actor(booking.CustomerId, "CUSTOMER"))
            .Handle(new(booking.Id), default);

        Assert.True(customerResult.IsFailure);
        Assert.Equal("booking.complete.admin_review_required", customerResult.Error.Code);
        await db.Entry(booking).ReloadAsync();
        Assert.Equal(BookingStatus.CheckoutPendingReview, booking.Status);

        var adminResult = await Handler(new Actor(Guid.NewGuid(), "ADMIN"))
            .Handle(new(booking.Id), default);
        Assert.True(adminResult.IsSuccess, adminResult.Error.Message);
        Assert.Equal(BookingStatus.Completed, booking.Status);
    }

    private RescheduleBookingCommandHandler RescheduleHandler(
        BookingDbContext db, BookingEntity booking, long amount) => new(
        new BookingRepository(db), new Actor(booking.CustomerId, "CUSTOMER"),
        new SystemClock(), new Pricing(amount), new BookingSyncService(db),
        new PostCommit(), new Mapper());

    [PostgresFact]
    public async Task PaidBooking_MainCareFlow_PersistsTimelineGpsAndCompletion()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "PENDING_PAYMENT");
        var start = DateTimeOffset.UtcNow.AddMinutes(5);
        Assert.True(booking.Reschedule(start, start.AddHours(2)).IsSuccess);
        await db.SaveChangesAsync();
        var caregiverUserId = await db.Database.SqlQuery<Guid>(
            $"SELECT user_id AS \"Value\" FROM people.caregiver_profiles WHERE id = {booking.CaregiverId!.Value}")
            .SingleAsync();
        var actor = new Actor(caregiverUserId, "CAREGIVER");
        var people = new People(booking.CaregiverId!.Value, caregiverUserId, approved: true);
        var repository = new BookingRepository(db);
        var sync = new BookingSyncService(db);
        var postCommit = new PostCommit();
        var mapper = new Mapper();
        var payment = new PaymentSucceeded(booking.Id, Guid.NewGuid(), booking.CustomerPayableAmount);
        var paymentHandler = PaymentHandler(db);
        await paymentHandler.Handle(payment, default);
        Assert.Equal(BookingStatus.Confirmed, booking.Status);
        Assert.NotEmpty(await db.CareTasks.Where(x => x.BookingId == booking.Id).ToListAsync());
        var accepted = await new AcceptBookingCommandHandler(repository,
            new BookingAcceptanceTransaction(db), actor, people, null!, sync, postCommit, mapper)
            .Handle(new(booking.Id), default);
        Assert.True(accepted.IsSuccess, accepted.Error.Message);
        // Durable outbox delivery may repeat after the caregiver has already accepted.
        var acceptedVersion = booking.SyncVersion;
        await paymentHandler.Handle(payment, default);
        Assert.Equal(BookingStatus.CaregiverAccepted, booking.Status);
        Assert.Equal(acceptedVersion, booking.SyncVersion);
        var enRoute = await new StartBookingEnRouteCommandHandler(
            repository, actor, people, sync, postCommit, mapper).Handle(new(booking.Id), default);
        Assert.True(enRoute.IsSuccess, enRoute.Error.Message);

        var policy = Options.Create(new CheckInOptions());
        var checkIn = new CheckInBookingCommandHandler(repository, actor, people, new Catalog(),
            policy, new CheckInBookingCommandValidator(policy), sync, postCommit, mapper);
        var outside = await checkIn.Handle(new(booking.Id, 11, 107, 5), default);
        Assert.Equal("booking.geofence", outside.Error.Code);
        var inside = await checkIn.Handle(new(booking.Id, 10.762622, 106.660172, 5), default);
        Assert.True(inside.IsSuccess, inside.Error.Message);
        var checkInEvent = await db.TimelineEvents.SingleAsync(x =>
            x.BookingId == booking.Id && x.EventType == "CHECKIN_VALID");
        Assert.Equal(10.762622, checkInEvent.Latitude);
        Assert.Equal(106.660172, checkInEvent.Longitude);

        foreach (var task in await db.CareTasks.Where(x => x.BookingId == booking.Id).ToListAsync())
            task.MarkCompleted(caregiverUserId);
        await db.SaveChangesAsync();
        var requested = await new RequestBookingCheckoutCommandHandler(
            repository, actor, people, sync, postCommit, mapper).Handle(new(booking.Id), default);
        Assert.True(requested.IsSuccess, requested.Error.Message);
        Assert.Equal(BookingStatus.CheckoutPendingReview, booking.Status);
        var completed = await new CompleteBookingCommandHandler(repository,
            new Actor(booking.CustomerId, "CUSTOMER"), new Disputes(), sync, postCommit, new Audit(), mapper)
            .Handle(new(booking.Id), default);
        Assert.True(completed.IsSuccess, completed.Error.Message);
        await db.Entry(booking).ReloadAsync();
        Assert.Equal(BookingStatus.Completed, booking.Status);
        Assert.NotNull(booking.ActualStart);
        Assert.NotNull(booking.ActualEnd);
        Assert.Null(booking.SettlementReleasedAt);
        Assert.Equal(6, await db.BookingSyncEvents.CountAsync(x => x.BookingId == booking.Id));

        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT ST_Y(coordinates::geometry), ST_X(coordinates::geometry)
            FROM booking.care_timeline_events WHERE id = @id
            """, connection);
        command.Parameters.AddWithValue("id", checkInEvent.Id);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        Assert.Equal(10.762622, reader.GetDouble(0));
        Assert.Equal(106.660172, reader.GetDouble(1));
    }

    [PostgresFact]
    public async Task PaymentWithStaleAmount_CannotConfirmRepricedBooking()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "PENDING_PAYMENT");
        var exception = await Assert.ThrowsAsync<InvalidOperationException>(() => PaymentHandler(db)
            .Handle(new PaymentSucceeded(booking.Id, Guid.NewGuid(), 50_000), default));
        Assert.Contains("amount", exception.Message, StringComparison.OrdinalIgnoreCase);
        await db.Entry(booking).ReloadAsync();
        Assert.Equal(BookingStatus.PendingPayment, booking.Status);
        Assert.False(await db.CareTasks.AnyAsync(x => x.BookingId == booking.Id));
        Assert.False(await db.BookingSyncEvents.AnyAsync(x => x.BookingId == booking.Id));
    }

    private static PaymentIntegrationEventHandler PaymentHandler(BookingDbContext db) => new(
        db, new ChecklistCatalog(), new BookingSyncService(db), new PostCommit(), new Matching(),
        null!, new Promotions(), new SystemClock(), NullLogger<PaymentIntegrationEventHandler>.Instance);

    [PostgresFact]
    public async Task GpsTrack_WritesScalarCoordinatesAndRequiredGeography()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "IN_PROGRESS");
        var track = GpsTrack.Create(booking.Id, booking.CaregiverId!.Value, 10.762622, 106.660172, 5);
        db.GpsTracks.Add(track);
        await db.SaveChangesAsync();
        await db.Entry(track).ReloadAsync();
        Assert.Equal(10.762622, track.Latitude);
        Assert.Equal(106.660172, track.Longitude);
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(
            "SELECT ST_X(location::geometry) FROM booking.gps_tracks WHERE id = @id", connection);
        command.Parameters.AddWithValue("id", track.Id);
        Assert.Equal(106.660172, await command.ExecuteScalarAsync());
    }

    [PostgresFact]
    public async Task RescheduleIntoAnotherHold_RollsBackBookingAndHoldTogether()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "PENDING_PAYMENT");
        var originalStart = booking.ScheduledStart;
        var hold = await AddHoldAsync(db, booking, committed: false);
        var other = await SeedBookingAsync(db, "CONFIRMED");
        var blockedStart = originalStart.AddDays(1);
        var blockedEnd = blockedStart.AddHours(2);
        db.CaregiverSlotHolds.Add(CaregiverSlotHold.Create(other.Id, other.CaregiverId!.Value,
            blockedStart, blockedEnd, DateTimeOffset.UtcNow.AddMinutes(30)).Value);
        await db.SaveChangesAsync();

        var result = await RescheduleHandler(db, booking, 100_000)
            .Handle(new(booking.Id, blockedStart, blockedEnd), default);

        Assert.True(result.IsFailure);
        Assert.Equal("booking.caregiver.new_schedule_conflict", result.Error.Code);
        db.ChangeTracker.Clear();
        Assert.Equal(originalStart, (await db.Bookings.SingleAsync(x => x.Id == booking.Id)).ScheduledStart);
        Assert.Equal(originalStart, (await db.CaregiverSlotHolds.SingleAsync(x => x.Id == hold.Id)).ScheduledStart);
        Assert.False(await db.BookingSyncEvents.AnyAsync(x => x.BookingId == booking.Id));
    }

    [PostgresFact]
    public async Task AutoCheckout_DoesNotCompleteBookingNeedingAdminReview()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "IN_PROGRESS");
        booking.RequestSystemTimeoutCheckout(DateTimeOffset.UtcNow.AddHours(-25));
        booking.MarkNeedsReview();
        await db.SaveChangesAsync();
        await RunAutoConfirmAsync();
        await db.Entry(booking).ReloadAsync();
        Assert.Equal(BookingStatus.CheckoutPendingReview, booking.Status);
        Assert.Null(booking.ActualEnd);
    }

    [PostgresFact]
    public async Task AutoCheckout_DoesNotCompleteBookingWithUnfinishedTasks()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "IN_PROGRESS");
        booking.RequestSystemTimeoutCheckout(DateTimeOffset.UtcNow.AddHours(-25));
        db.CareTasks.Add(CareTask.Create(booking.Id, "Công việc còn thiếu", isRequired: true));
        await db.SaveChangesAsync();
        await RunAutoConfirmAsync();
        await db.Entry(booking).ReloadAsync();
        Assert.Equal(BookingStatus.CheckoutPendingReview, booking.Status);
    }

    [PostgresFact]
    public async Task AutoCheckout_CleanBookingCompletesAndWritesDeltaSync()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "IN_PROGRESS");
        booking.RequestSystemTimeoutCheckout(DateTimeOffset.UtcNow.AddHours(-25));
        await db.SaveChangesAsync();
        await RunAutoConfirmAsync();
        await db.Entry(booking).ReloadAsync();
        Assert.Equal(BookingStatus.Completed, booking.Status);
        Assert.NotNull(booking.ActualEnd);
        Assert.Equal(1, await db.BookingSyncEvents.CountAsync(x => x.BookingId == booking.Id));
    }

    [PostgresFact]
    public async Task ExpiredShift_WithPendingTasks_IsFlaggedForReviewAndSynced()
    {
        await using var db = CreateDb();
        var booking = await SeedBookingAsync(db, "IN_PROGRESS");
        var now = DateTimeOffset.UtcNow;
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            UPDATE booking.bookings SET scheduled_start = {now.AddHours(-4)},
                scheduled_end = {now.AddHours(-1)} WHERE id = {booking.Id}
            """);
        db.CareTasks.Add(CareTask.Create(booking.Id, "Chưa hoàn tất", isRequired: true));
        await db.SaveChangesAsync();
        await RunAutoConfirmAsync(requestCheckout: true);
        await db.Entry(booking).ReloadAsync();
        Assert.Equal(BookingStatus.CheckoutPendingReview, booking.Status);
        Assert.True(booking.NeedsReview);
        Assert.Null(booking.ActualEnd);
        Assert.Equal(1, await db.BookingSyncEvents.CountAsync(x => x.BookingId == booking.Id));
    }

    private async Task RunAutoConfirmAsync(bool requestCheckout = false)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSignalR();
        services.AddScoped(_ => CreateDb());
        services.AddScoped<IBookingSyncService, BookingSyncService>();
        services.AddSingleton<IDisputeLookupService, Disputes>();
        services.AddSingleton<IUserNotificationService, Notifications>();
        await using var provider = services.BuildServiceProvider();
        var jobs = new BookingJobsService(provider, NullLogger<BookingJobsService>.Instance);
        if (requestCheckout) await jobs.AutoRequestCheckoutExpiredShiftsAsync();
        else await jobs.AutoConfirmPendingCheckoutsAsync();
    }

    private BookingDbContext CreateDb() => new(new DbContextOptionsBuilder<BookingDbContext>()
        .UseNpgsql(_database.ConnectionString).Options);

    private async Task<BookingEntity> SeedBookingAsync(BookingDbContext db, string status)
    {
        var id = Guid.NewGuid();
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO booking.bookings (
                id, customer_id, beneficiary_id, address_id, service_type_id, caregiver_id,
                scheduled_start, scheduled_end, payment_deadline, status,
                escrow_amount, platform_fee_amount, caregiver_earning_amount, customer_payable_amount)
            SELECT @id, beneficiary.customer_id, beneficiary.id, address.id, service.id, caregiver.id,
                   now() + interval '3 days' + (SELECT count(*) FROM booking.bookings) * interval '3 hours',
                   now() + interval '3 days 2 hours' + (SELECT count(*) FROM booking.bookings) * interval '3 hours',
                   now() + interval '30 minutes', @status, 100000, 15000, 85000, 100000
            FROM people.beneficiaries beneficiary
            JOIN catalog.addresses address ON address.owner_user_id = beneficiary.customer_id
            CROSS JOIN LATERAL (SELECT id FROM catalog.service_types ORDER BY id LIMIT 1) service
            CROSS JOIN LATERAL (SELECT id FROM people.caregiver_profiles ORDER BY id LIMIT 1) caregiver
            ORDER BY beneficiary.id, address.id LIMIT 1
            """, connection);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("status", status);
        Assert.Equal(1, await command.ExecuteNonQueryAsync());
        return await db.Bookings.SingleAsync(x => x.Id == id);
    }

    private static async Task<CaregiverSlotHold> AddHoldAsync(
        BookingDbContext db, BookingEntity booking, bool committed)
    {
        var hold = CaregiverSlotHold.Create(booking.Id, booking.CaregiverId!.Value,
            booking.ScheduledStart, booking.ScheduledEnd, DateTimeOffset.UtcNow.AddMinutes(30)).Value;
        if (committed) hold.Commit();
        db.CaregiverSlotHolds.Add(hold);
        await db.SaveChangesAsync();
        return hold;
    }

    private sealed class Actor(Guid id, params string[] roles) : ICurrentUser
    {
        public Guid? UserId => id;
        public IReadOnlyCollection<string> Roles => roles;
        public bool IsInRole(string role) => roles.Contains(role);
    }

    private sealed class Pricing(long amount) : IPricingService
    {
        public Task<Result<PriceQuote>> QuoteAsync(Guid serviceTypeId, DateTimeOffset start,
            DateTimeOffset end, CancellationToken ct = default) => Task.FromResult<Result<PriceQuote>>(
                new PriceQuote(amount, amount * 15 / 100, amount * 85 / 100, 48, "{}"));
    }

    private sealed class People(Guid profileId, Guid userId, bool approved) : IPeopleLookupService
    {
        public Task<bool> BeneficiaryBelongsToAsync(Guid beneficiaryId, Guid customerId,
            CancellationToken ct = default) => Task.FromResult(false);
        public Task<bool> CaregiverIsAvailableAsync(Guid caregiverId, DateTimeOffset start,
            DateTimeOffset end, CancellationToken ct = default) => Task.FromResult(approved);
        public Task<bool> IsCaregiverApprovedAsync(Guid caregiverId,
            CancellationToken ct = default) => Task.FromResult(approved && caregiverId == profileId);
        public Task<bool> IsCaregiverForBookingAsync(Guid caregiverId, Guid actorId,
            CancellationToken ct = default) => Task.FromResult(caregiverId == profileId && actorId == userId);
        public Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid actorId,
            CancellationToken ct = default) => Task.FromResult<Guid?>(actorId == userId ? profileId : null);
        public Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid caregiverId,
            CancellationToken ct = default) => Task.FromResult<Guid?>(userId);
        public Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid beneficiaryId,
            CancellationToken ct = default) => Task.FromResult<PeopleDisplaySummary?>(null);
        public Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid caregiverId,
            CancellationToken ct = default) => Task.FromResult<PeopleDisplaySummary?>(null);
    }

    private sealed class Promotions : IPromotionService
    {
        public Task<Result<PromotionPriceQuote>> PreviewAsync(PromotionPriceRequest request,
            CancellationToken ct = default) => throw new NotSupportedException();
        public Task<Result<PromotionPriceQuote>> ReserveAsync(PromotionReservationRequest request,
            CancellationToken ct = default) => throw new NotSupportedException();
        public Task<Result> RedeemAsync(Guid bookingId, Guid customerId,
            CancellationToken ct = default) => Task.FromResult(Result.Success());
        public Task<Result> ReleaseAsync(Guid bookingId, Guid customerId, string reason,
            CancellationToken ct = default) => Task.FromResult(Result.Success());
    }

    private sealed class Disputes : IDisputeLookupService
    {
        public Task<bool> HasOpenDisputeAsync(Guid bookingId, CancellationToken ct = default) =>
            Task.FromResult(false);
    }

    private sealed class Audit : IAuditLogger
    {
        public Task WriteAsync(string action, string entityType, Guid entityId,
            object? before, object? after, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class Notifications : IUserNotificationService
    {
        public Task NotifyAsync(UserNotificationMessage message, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class Catalog : ICatalogLookupService
    {
        public Task<bool> AddressBelongsToAsync(Guid id, Guid customerId, CancellationToken ct = default) => Task.FromResult(true);
        public Task<bool> AddressIsVerifiedForBookingAsync(Guid id, Guid customerId, CancellationToken ct = default) => Task.FromResult(true);
        public Task<bool> ServiceIsActiveAsync(Guid id, CancellationToken ct = default) => Task.FromResult(true);
        public Task<AddressDisplaySummary?> GetAddressDisplayAsync(Guid id, CancellationToken ct = default) => Task.FromResult<AddressDisplaySummary?>(null);
        public Task<ServiceDisplaySummary?> GetServiceDisplayAsync(Guid id, CancellationToken ct = default) => Task.FromResult<ServiceDisplaySummary?>(null);
        public Task<(double Lat, double Lng)?> GetAddressLocationAsync(Guid id, CancellationToken ct = default) =>
            Task.FromResult<(double Lat, double Lng)?>((10.762622, 106.660172));
    }

    private sealed class ChecklistCatalog : IServiceChecklistCatalog
    {
        public Task<bool> ExistsAsync(Guid id, CancellationToken ct = default) => Task.FromResult(true);
        public Task<bool?> GetAllowAdHocTasksAsync(Guid id, CancellationToken ct = default) => Task.FromResult<bool?>(false);
        public Task<ServiceChecklistPolicyChange?> SetPolicyAsync(Guid id, bool enabled, CancellationToken ct = default) =>
            throw new NotSupportedException();
    }

    private sealed class Matching : IMatchingService
    {
        public Task<IReadOnlyList<MatchingCandidate>> GetEligibleCaregiversAsync(Guid id, CancellationToken ct = default) =>
            Task.FromResult<IReadOnlyList<MatchingCandidate>>([]);
        public Task<IReadOnlyList<MatchingCandidate>> GetSuggestedCaregiversAsync(Guid id, CancellationToken ct = default) =>
            Task.FromResult<IReadOnlyList<MatchingCandidate>>([]);
        public Task<IReadOnlyList<Guid>> GetOpenBookingIdsForCaregiverAsync(Guid id, CancellationToken ct = default) =>
            Task.FromResult<IReadOnlyList<Guid>>([]);
        public Task<IReadOnlyList<MatchingCandidate>> OfferTopCandidatesAsync(Guid id, CancellationToken ct = default) =>
            Task.FromResult<IReadOnlyList<MatchingCandidate>>([]);
        public Task<int> ExpandExpiredOffersAsync(CancellationToken ct = default) => Task.FromResult(0);
    }

    private sealed class PostCommit : IBookingPostCommitService
    {
        public Task RunAsync(string action, Func<Task> operation) => operation();
        public Task BroadcastStatusAsync(Guid id, string before, string after, CancellationToken ct) => Task.CompletedTask;
        public Task BroadcastAcceptedStatusAsync(BookingEntity booking, string oldStatus, CancellationToken ct) => Task.CompletedTask;
        public Task PublishCustomerSyncEventAsync(BookingEntity booking, CancellationToken ct) => Task.CompletedTask;
        public Task NotifyBookingUserAsync(Guid userId, BookingEntity booking, string title, string body, CancellationToken ct) => Task.CompletedTask;
        public Task NotifyCaregiverAsync(BookingEntity booking, string title, string body, CancellationToken ct) => Task.CompletedTask;
        public Task NotifySosTargetsAsync(BookingEntity booking, Guid raisedByUserId, CancellationToken ct) => Task.CompletedTask;
        public Task PublishOfferChangedAsync(Guid caregiverId, Guid bookingId, string changeType, CancellationToken ct) => Task.CompletedTask;
    }

    private sealed class Mapper : IBookingResponseMapper
    {
        public Task<BookingResponse> ToResponseAsync(BookingEntity b, CancellationToken ct) => Task.FromResult(
            new BookingResponse(b.Id, b.BeneficiaryId, b.CaregiverId, b.AddressId, b.ServiceTypeId,
                b.ScheduledStart, b.ScheduledEnd, b.ActualStart, b.ActualEnd, b.CheckoutPendingReviewAt,
                b.CheckoutSource?.ToString(), b.Status.ToString(), b.EscrowAmount, b.PlatformFeeAmount,
                b.CaregiverEarningAmount, b.CancelledAt, b.CancelReason, b.CreatedAt, b.UpdatedAt));
        public Task<IReadOnlyList<BookingResponse>> ToResponsesAsync(IReadOnlyList<BookingEntity> bookings,
            CancellationToken ct, Guid? offerCaregiverId = null) => throw new NotSupportedException();
        public CaregiverSuggestionResponse ToCaregiverSuggestion(MatchingCandidate candidate,
            PeopleDisplaySummary? display) => throw new NotSupportedException();
    }
}
