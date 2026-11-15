using CareSitter.Contracts.Nutrition;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.People;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class BookingMealsPostgresTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase database = null!;
    private NpgsqlDataSource source = null!;
    private ServiceProvider services = null!;
    public async Task InitializeAsync()
    {
        database = await PostgresRaceTestDatabase.CreateAsync();
        source = NpgsqlDataSource.Create(database.ConnectionString);
        var registrations = new ServiceCollection();
        new PeopleModule().RegisterServices(registrations, new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string,string?> { ["ConnectionStrings:CareSitter"] = database.ConnectionString }).Build());
        registrations.AddSingleton(source);
        services = registrations.BuildServiceProvider();
    }
    public async Task DisposeAsync() { if (services is not null) await services.DisposeAsync(); if (source is not null) await source.DisposeAsync(); if (database is not null) await database.DisposeAsync(); }
    private BookingDbContext Db() => new(new DbContextOptionsBuilder<BookingDbContext>()
        .UseNpgsql(database.ConnectionString, x => x.UseNetTopologySuite()).Options);

    [PostgresFact]
    public async Task Family_shares_assigned_caregiver_records_and_family_reads_real_timeline()
    {
        var seed = await SeedAsync(); var plan = Snapshot(seed);
        await using (var db = Db())
        {
            var owner = Handler(db, seed, seed.Owner, "CUSTOMER", plan);
            var ownerView = await owner.Handle(new ListBookingMealsQuery(seed.Booking), default);
            var window = Assert.IsType<BookingMealShareWindow>(ownerView.Value.ShareWindow);
            Assert.Equal(seed.Beneficiary, window.BeneficiaryId);
            Assert.InRange(plan.PlannedDate, window.FirstDate, window.LastDate);
            Assert.True((await owner.Handle(new ShareBookingMealPlanCommand(seed.Booking, plan.Id), default)).IsSuccess);
        }
        await using (var db = Db())
        {
            var stranger = Handler(db, seed, Guid.NewGuid(), "CUSTOMER", plan);
            Assert.True((await stranger.Handle(new ListBookingMealsQuery(seed.Booking), default)).IsFailure);
            Assert.True((await stranger.Handle(new ShareBookingMealPlanCommand(seed.Booking, plan.Id), default)).IsFailure);
        }
        await using (var db = Db())
        {
            var caregiver = Handler(db, seed, seed.CaregiverUser, "CAREGIVER", plan);
            var meals = await caregiver.Handle(new ListBookingMealsQuery(seed.Booking), default);
            Assert.Null(meals.Value.ShareWindow);
            var shared = Assert.Single(meals.Value.Plans);
            Assert.True(shared.CanRecord);
            Assert.Equal("Cháo thử nghiệm", Assert.Single(shared.Meals).Name);
            var record = await caregiver.Handle(Record(seed, plan, Guid.NewGuid()), default);
            Assert.True(record.IsSuccess, record.Error.Message);
            var refreshed = await caregiver.Handle(new ListBookingMealsQuery(seed.Booking), default);
            Assert.True(Assert.Single(refreshed.Value.Records).CanCorrect);
        }
        await using (var db = Db())
        {
            var owner = Handler(db, seed, seed.Owner, "CUSTOMER", plan);
            var meals = await owner.Handle(new ListBookingMealsQuery(seed.Booking), default);
            Assert.False(Assert.Single(meals.Value.Plans).CanRecord);
            var record = Assert.Single(meals.Value.Records);
            Assert.Equal("partly_eaten", record.Outcome);
            Assert.False(record.CanCorrect);
            var timeline = await new BookingTrackingStore(db).ListTimelineAsync(seed.Booking);
            Assert.Contains(timeline, x => x.Title == "Ăn một phần: Cháo thử nghiệm" && x.Note == "Ăn nửa phần.");
            Assert.True((await owner.Handle(new RevokeBookingMealPlanCommand(seed.Booking, plan.PlannedDate), default)).IsSuccess);
        }
        await using (var db = Db())
        {
            var caregiver = Handler(db, seed, seed.CaregiverUser, "CAREGIVER", plan);
            var hidden = await caregiver.Handle(new ListBookingMealsQuery(seed.Booking), default);
            Assert.Empty(hidden.Value.Plans); Assert.Empty(hidden.Value.Records);
            var denied = await caregiver.Handle(Record(seed, plan, Guid.NewGuid()), default);
            Assert.True(denied.IsFailure);
            var owner = Handler(db, seed, seed.Owner, "CUSTOMER", plan);
            Assert.Single((await owner.Handle(new ListBookingMealsQuery(seed.Booking), default)).Value.Records);
        }
    }

    [PostgresFact]
    public async Task Concurrent_retries_write_one_record_and_one_timeline_event_and_reject_payload_changes()
    {
        var seed = await SeedAsync(); var plan = Snapshot(seed); var key = Guid.NewGuid();
        await using (var db = Db())
            Assert.True((await Handler(db, seed, seed.Owner, "CUSTOMER", plan)
                .Handle(new ShareBookingMealPlanCommand(seed.Booking, plan.Id), default)).IsSuccess);
        async Task<Result<BookingMealRecordResponse>> Write(RecordBookingMealCommand request)
        {
            await using var db = Db();
            return await Handler(db, seed, seed.CaregiverUser, "CAREGIVER", plan).Handle(request, default);
        }
        var request = Record(seed, plan, key);
        var results = await Task.WhenAll(Write(request), Write(request));
        Assert.All(results, x => Assert.True(x.IsSuccess, x.Error.Message));
        Assert.Equal(results[0].Value.Id, results[1].Value.Id);
        Assert.Equal("booking.meals.idempotency_conflict", (await Write(request with { Outcome = "eaten" })).Error.Code);
        Assert.Equal("booking.meals.already_recorded", (await Write(request with { IdempotencyKey = Guid.NewGuid() })).Error.Code);
        await using var check = Db();
        Assert.Equal(1, await check.BookingMealRecords.CountAsync(x => x.BookingId == seed.Booking));
        Assert.Equal(1, await check.TimelineEvents.CountAsync(x => x.BookingId == seed.Booking));
    }

    [PostgresFact]
    public async Task Wrong_day_wrong_beneficiary_and_unassigned_caregiver_are_rejected()
    {
        var seed = await SeedAsync(new DateTimeOffset(2026, 1, 2, 16, 30, 0, TimeSpan.Zero));
        var plan = Snapshot(seed);
        await using (var db = Db())
        {
            // The fixture runs from 22:30 to 00:30 in Vietnam.
            var nextDay = plan with { PlannedDate = plan.PlannedDate.AddDays(1) };
            var shared = await Handler(db, seed, seed.Owner, "CUSTOMER", nextDay)
                .Handle(new ShareBookingMealPlanCommand(seed.Booking, plan.Id), default);
            Assert.True(shared.IsSuccess, shared.Error.Message);

            var outsideShift = plan with { PlannedDate = nextDay.PlannedDate.AddDays(1) };
            var rejected = await Handler(db, seed, seed.Owner, "CUSTOMER", outsideShift)
                .Handle(new ShareBookingMealPlanCommand(seed.Booking, plan.Id), default);
            Assert.Equal("booking.meals.request", rejected.Error.Code);
        }
        await using (var db = Db())
        {
            Assert.True((await Handler(db, seed, seed.Owner, "CUSTOMER", plan with { BeneficiaryId = Guid.NewGuid() })
                .Handle(new ShareBookingMealPlanCommand(seed.Booking, plan.Id), default)).IsFailure);
            Assert.True((await Handler(db, seed, Guid.NewGuid(), "CAREGIVER", plan)
                .Handle(new ListBookingMealsQuery(seed.Booking), default)).IsFailure);
            var payment = new GetBookingPaymentSummaryQueryHandler(new BookingReadStore(db),
                new Actor(Guid.NewGuid(), "CUSTOMER"), new SystemClock());
            Assert.True((await payment.Handle(new GetBookingPaymentSummaryQuery(seed.Booking), default)).IsFailure);
        }
    }

    private BookingMealHandlers Handler(BookingDbContext db, Seed seed, Guid user, string role, MealPlanSnapshot plan) =>
        new(new BookingMealStore(db), new BookingReadStore(db), new SnapshotReader(plan),
            new Actor(user, role), new People(seed), new SystemClock(), services.GetRequiredService<IBeneficiaryHealthSnapshotReader>());

    [PostgresFact]
    public async Task Changed_health_profile_hides_old_meals_and_blocks_new_records_until_reshared()
    {
        var seed = await SeedAsync(); var plan = Snapshot(seed);
        await using (var db = Db())
            Assert.True((await Handler(db, seed, seed.Owner, "CUSTOMER", plan)
                .Handle(new ShareBookingMealPlanCommand(seed.Booking, plan.Id), default)).IsSuccess);
        await using (var conn = await database.OpenConnectionAsync())
        {
            await using var cmd = new NpgsqlCommand("UPDATE people.beneficiaries SET general_note='synthetic changed profile' WHERE id=@id", conn);
            cmd.Parameters.AddWithValue("id", seed.Beneficiary); await cmd.ExecuteNonQueryAsync();
        }
        await using (var db = Db())
        {
            var caregiver = Handler(db, seed, seed.CaregiverUser, "CAREGIVER", plan);
            var result = await caregiver.Handle(new ListBookingMealsQuery(seed.Booking), default);
            var stale = Assert.Single(result.Value.Plans);
            Assert.True(stale.IsStale); Assert.Equal("stale", stale.Status); Assert.Empty(stale.Meals);
            Assert.False(stale.CanRecord);
            Assert.Equal("booking.meals.plan_stale", (await caregiver.Handle(Record(seed, plan, Guid.NewGuid()), default)).Error.Code);
        }
        await using (var db = Db())
        {
            var owner = Handler(db, seed, seed.Owner, "CUSTOMER", plan);
            Assert.True(Assert.Single((await owner.Handle(new ListBookingMealsQuery(seed.Booking), default)).Value.Plans).IsStale);
            Assert.Equal("booking.meals.plan_stale", (await owner.Handle(new ShareBookingMealPlanCommand(seed.Booking, plan.Id), default)).Error.Code);
        }
        await using (var db = Db())
        {
            var revision = (await services.GetRequiredService<IBeneficiaryHealthSnapshotReader>()
                .ReadAsync(seed.Owner, seed.Beneficiary))!.Revision;
            var renewed = plan with { Id = Guid.NewGuid(), HealthRevision = revision };
            Assert.True((await Handler(db, seed, seed.Owner, "CUSTOMER", renewed)
                .Handle(new ShareBookingMealPlanCommand(seed.Booking, renewed.Id), default)).IsSuccess);
            var visible = await Handler(db, seed, seed.CaregiverUser, "CAREGIVER", renewed)
                .Handle(new ListBookingMealsQuery(seed.Booking), default);
            Assert.False(Assert.Single(visible.Value.Plans).IsStale);
            Assert.NotEmpty(visible.Value.Plans[0].Meals);
        }
    }

    [PostgresFact]
    public async Task Concurrent_corrections_keep_original_and_one_audited_revision_and_reject_stale_writes()
    {
        var seed = await SeedAsync(); var plan = Snapshot(seed); Guid recordId;
        await using (var db = Db())
        {
            Assert.True((await Handler(db, seed, seed.Owner, "CUSTOMER", plan)
                .Handle(new ShareBookingMealPlanCommand(seed.Booking, plan.Id), default)).IsSuccess);
            recordId = (await Handler(db, seed, seed.CaregiverUser, "CAREGIVER", plan)
                .Handle(Record(seed, plan, Guid.NewGuid()), default)).Value.Id;
        }
        var request = new CorrectBookingMealCommand(seed.Booking, recordId, "eaten", "Đã ăn hết.", "Bấm nhầm kết quả.", 1, Guid.NewGuid());
        async Task<Result<BookingMealRecordResponse>> Correct(CorrectBookingMealCommand command)
        {
            await using var db = Db();
            return await new CorrectBookingMealCommandHandler(new BookingMealStore(db),
                new Actor(seed.CaregiverUser, "CAREGIVER"), new People(seed), new SystemClock()).Handle(command, default);
        }
        var results = await Task.WhenAll(Correct(request), Correct(request));
        Assert.All(results, x => Assert.True(x.IsSuccess, x.Error.Message));
        Assert.Equal(2, results[0].Value.Revision);
        Assert.Equal("partly_eaten", results[0].Value.OriginalOutcome);
        Assert.Equal(results[0].Value.Corrections![0].Id, results[1].Value.Corrections![0].Id);
        Assert.Equal("booking.meals.revision_conflict", (await Correct(request with { IdempotencyKey = Guid.NewGuid() })).Error.Code);
        Assert.Equal("booking.meals.idempotency_conflict", (await Correct(request with { Reason = "Nội dung khác" })).Error.Code);
        await using var check = Db();
        Assert.Equal("partly_eaten", (await check.BookingMealRecords.SingleAsync(x => x.Id == recordId)).Outcome);
        Assert.Equal(1, await check.BookingMealCorrections.CountAsync(x => x.RecordId == recordId));
        Assert.Equal(2, await check.TimelineEvents.CountAsync(x => x.BookingId == seed.Booking));
        var visible = await Handler(check, seed, seed.Owner, "CUSTOMER", plan).Handle(new ListBookingMealsQuery(seed.Booking), default);
        Assert.Equal("eaten", Assert.Single(visible.Value.Records).Outcome);
        var forbidden = await new CorrectBookingMealCommandHandler(new BookingMealStore(check),
            new Actor(Guid.NewGuid(), "CAREGIVER"), new People(seed), new SystemClock()).Handle(request, default);
        Assert.True(forbidden.IsFailure);
    }
    private static RecordBookingMealCommand Record(Seed seed, MealPlanSnapshot plan, Guid key) =>
        new(seed.Booking, plan.Id, plan.Meals[0].VersionId, "lunch", "partly_eaten", "Ăn nửa phần.", key);

    [PostgresFact]
    public async Task Family_taste_approval_does_not_block_remaining_meal_in_active_shift()
    {
        var seed = await SeedAsync();
        var dinner = new SharedMeal(Guid.NewGuid(), "Canh thử nghiệm", "dinner", 1, [new("Bí đỏ", 100, "g")], ["Nấu chín"], []);
        var initial = Snapshot(seed);
        var plan = initial with { Meals = [initial.Meals[0], dinner] };
        await using (var db = Db())
        {
            Assert.True((await Handler(db, seed, seed.Owner, "CUSTOMER", plan).Handle(new ShareBookingMealPlanCommand(seed.Booking, plan.Id), default)).IsSuccess);
            Assert.True((await Handler(db, seed, seed.CaregiverUser, "CAREGIVER", plan).Handle(Record(seed, plan, Guid.NewGuid()), default)).IsSuccess);
        }
        ServiceProvider FeedbackServices(Guid actor, string role)
        {
            var registrations = new ServiceCollection(); registrations.AddLogging(); registrations.AddSingleton(source);
            new PeopleModule().RegisterServices(registrations, new ConfigurationBuilder().AddInMemoryCollection(
                new Dictionary<string, string?> { ["ConnectionStrings:CareSitter"] = database.ConnectionString }).Build());
            registrations.AddSingleton<ICurrentUser>(new Actor(actor, role));
            registrations.AddSingleton<IClock, SystemClock>();
            registrations.AddSingleton<IMealPlanSnapshotReader>(new SnapshotReader(plan));
            return registrations.BuildServiceProvider();
        }
        await using (var provider = FeedbackServices(seed.Owner, "CUSTOMER"))
        {
            var mediator = provider.GetRequiredService<MediatR.IMediator>();
            var proposal = await mediator.Send(new CareSitter.Modules.People.Application.SubmitMealTasteFeedbackCommand(seed.Beneficiary, plan.Id, plan.Meals[0].VersionId, "want_again", Guid.NewGuid()));
            Assert.True(proposal.IsSuccess, proposal.Error.Message);
            var result = await mediator.Send(new CareSitter.Modules.People.Application.ReviewMealTasteFeedbackCommand(seed.Beneficiary, proposal.Value.Id, true, seed.HealthRevision));
            Assert.True(result.IsSuccess, result.Error.Message);
        }
        await using (var db = Db())
        {
            var handler = Handler(db, seed, seed.CaregiverUser, "CAREGIVER", plan);
            var current = (await handler.Handle(new ListBookingMealsQuery(seed.Booking), default)).Value;
            Assert.False(Assert.Single(current.Plans).IsStale);
            var next = await handler.Handle(Record(seed, plan, Guid.NewGuid()) with { RecipeVersionId = dinner.VersionId, MealType = "dinner" }, default);
            Assert.True(next.IsSuccess, next.Error.Message);
        }
    }
    private static MealPlanSnapshot Snapshot(Seed seed) => new(Guid.NewGuid(), seed.Beneficiary,
        BookingMealPolicy.VietnamDate(seed.ObservedAt), [new SharedMeal(Guid.NewGuid(), "Cháo thử nghiệm",
            "lunch", 1, [new("Gạo", 50, "g")], ["Nấu chín."], [])], seed.HealthRevision);
    private async Task<Seed> SeedAsync(DateTimeOffset? observedAt = null)
    {
        var now = observedAt ?? DateTimeOffset.UtcNow;
        await using var conn = await database.OpenConnectionAsync();
        await using var cmd = new NpgsqlCommand("""
            WITH template AS (
              SELECT b.customer_id, a.id AS address_id, s.id AS service_type_id
              FROM people.beneficiaries b JOIN catalog.addresses a ON a.owner_user_id=b.customer_id
              CROSS JOIN catalog.service_types s ORDER BY b.id, a.id, s.id LIMIT 1
            ), actor AS (
              INSERT INTO identity.users(email, full_name, roles, status)
              VALUES ('meals-' || gen_random_uuid()::text || '@example.test', 'Caregiver kiểm thử', ARRAY['CAREGIVER']::varchar[], 'ACTIVE')
              RETURNING id
            ), caregiver AS (
              INSERT INTO people.caregiver_profiles(user_id,full_name,kyc_status,availability_status)
              SELECT id,'Caregiver kiểm thử','APPROVED','ONLINE' FROM actor RETURNING id,user_id
            ), beneficiary AS (
              INSERT INTO people.beneficiaries(customer_id,full_name,default_address_id)
              SELECT customer_id,'Người nhận kiểm thử',address_id FROM template RETURNING id,customer_id,health_profile_revision
            ), inserted AS (
              INSERT INTO booking.bookings(customer_id, beneficiary_id, caregiver_id, address_id,
                service_type_id, scheduled_start, scheduled_end, actual_start, status)
              SELECT b.customer_id,b.id,c.id,t.address_id,t.service_type_id,
                 @observed_at - interval '1 hour',@observed_at + interval '1 hour',@observed_at - interval '30 minutes','IN_PROGRESS'
              FROM beneficiary b CROSS JOIN caregiver c CROSS JOIN template t
              RETURNING id,customer_id,beneficiary_id,caregiver_id)
            SELECT i.id,i.customer_id,i.beneficiary_id,i.caregiver_id,c.user_id,b.health_profile_revision
            FROM inserted i JOIN caregiver c ON c.id=i.caregiver_id JOIN beneficiary b ON b.id=i.beneficiary_id
            """, conn);
        cmd.Parameters.AddWithValue("observed_at", now);
        await using var reader = await cmd.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        return new(reader.GetGuid(0), reader.GetGuid(1), reader.GetGuid(2), reader.GetGuid(3), reader.GetGuid(4), reader.GetInt64(5), now);
    }
    private sealed record Seed(Guid Booking, Guid Owner, Guid Beneficiary, Guid Caregiver, Guid CaregiverUser,
        long HealthRevision, DateTimeOffset ObservedAt);
    private sealed class SnapshotReader(MealPlanSnapshot plan) : IMealPlanSnapshotReader
    {
        public Task<Result<MealPlanSnapshot>> ReadAsync(Guid beneficiary, Guid planId, CancellationToken ct) =>
            Task.FromResult(Result.Success(plan));
    }
    private sealed class Actor(Guid id, string role) : ICurrentUser
    {
        public Guid? UserId => id;
        public IReadOnlyCollection<string> Roles => [role];
        public bool IsInRole(string value) => role == value;
    }
    private sealed class People(Seed seed) : IPeopleLookupService
    {
        public Task<bool> IsCaregiverForBookingAsync(Guid id, Guid user, CancellationToken ct = default) =>
            Task.FromResult(id == seed.Caregiver && user == seed.CaregiverUser);
        public Task<bool> BeneficiaryBelongsToAsync(Guid id, Guid user, CancellationToken ct = default) => Task.FromResult(id == seed.Beneficiary && user == seed.Owner);
        public Task<bool> CaregiverIsAvailableAsync(Guid id, DateTimeOffset start, DateTimeOffset end, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> IsCaregiverApprovedAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid id, CancellationToken ct = default) => Task.FromResult<Guid?>(seed.Caregiver);
        public Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid id, CancellationToken ct = default) => Task.FromResult<Guid?>(seed.CaregiverUser);
        public Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
    }
}
