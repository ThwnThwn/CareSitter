using CareSitter.Contracts.Services;
using CareSitter.Modules.People;
using CareSitter.Modules.Catalog;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using CareSitter.Contracts.Services.Routing;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.SignalR;
using CareSitter.Infrastructure.Hubs;
using Npgsql;

namespace CareSitter.IntegrationTests;

public sealed class BookingMatchingPreviewPostgresTests
{
    [PostgresFact, Trait("Category", "PostgreSQL")]
    public async Task Preview_filters_schedule_skills_area_and_temporary_holds_without_creating_a_booking()
    {
        await using var database = await PostgresRaceTestDatabase.CreateAsync();
        Guid owner, beneficiary, address, serviceId, caregiver;
        await using (var conn = await database.OpenConnectionAsync())
        {
            await using var cmd = new NpgsqlCommand("""
                SELECT b.customer_id,b.id,a.id,s.id,c.id FROM people.beneficiaries b
                JOIN catalog.addresses a ON a.owner_user_id=b.customer_id
                CROSS JOIN catalog.service_types s CROSS JOIN people.caregiver_profiles c
                ORDER BY b.id,a.id,s.id,c.id LIMIT 1
                """, conn);
            await using var reader = await cmd.ExecuteReaderAsync();
            Assert.True(await reader.ReadAsync());
            owner = reader.GetGuid(0); beneficiary = reader.GetGuid(1); address = reader.GetGuid(2);
            serviceId = reader.GetGuid(3); caregiver = reader.GetGuid(4);
        }
        await using var db = new BookingDbContext(new DbContextOptionsBuilder<BookingDbContext>()
            .UseNpgsql(database.ConnectionString, x => x.UseNetTopologySuite()).Options);
        var point = new GeoPoint(10.8, 106.7);
        var good = new MatchingCaregiverProfile(caregiver, "APPROVED", "OFFLINE", "meal preparation",
            "HCM", "D1", point, 10000, 4.5m, 10, null, null);
        var profiles = new Profiles([good,
            good with { Id = Guid.NewGuid(), Skills = "companionship" },
            good with { Id = Guid.NewGuid(), ServiceCenter = new GeoPoint(11.8, 106.7) }]);
        var matching = new MatchingService(db, profiles, new Addresses(point), null!, new Routes(),
            null!, null!, Options.Create(new MatchingOptions()), NullLogger<MatchingService>.Instance, new SystemClock());
        var start = DateTimeOffset.UtcNow.AddDays(30);
        var preview = CareSitter.Modules.Booking.Domain.Booking.Create(owner, beneficiary, address, serviceId, start, start.AddHours(2),
            requiredSkills: "[\"meal preparation\"]").Value;
        var before = await db.Bookings.CountAsync();
        var candidate = Assert.Single(await matching.PreviewAsync(preview, default));
        Assert.Equal(caregiver, candidate.CaregiverId);
        Assert.Contains("required_skills_match", candidate.MatchReasons!);
        Assert.Null(candidate.YearsOfExperience);
        Assert.Equal(before, await db.Bookings.CountAsync());
        var immediate = CareSitter.Modules.Booking.Domain.Booking.Create(owner, beneficiary, address, serviceId,
            DateTimeOffset.UtcNow.AddHours(1), DateTimeOffset.UtcNow.AddHours(3)).Value;
        Assert.Empty(await matching.PreviewAsync(immediate, default));

        var heldBooking = CareSitter.Modules.Booking.Domain.Booking.Create(owner, beneficiary, address, serviceId, start, start.AddHours(2)).Value;
        heldBooking.TransitionTo(BookingStatus.PendingPayment);
        db.Bookings.Add(heldBooking);
        await db.SaveChangesAsync();
        var hold = CaregiverSlotHold.Create(heldBooking.Id, caregiver, start, start.AddHours(2), DateTimeOffset.UtcNow.AddMinutes(10)).Value;
        db.CaregiverSlotHolds.Add(hold);
        await db.SaveChangesAsync();
        Assert.Empty(await matching.PreviewAsync(preview, default));

        var offerStart = start.AddDays(1);
        var booking = CareSitter.Modules.Booking.Domain.Booking.Create(owner, beneficiary, address, serviceId,
            offerStart, offerStart.AddHours(2), requiredSkills: "[\"meal preparation\"]").Value;
        Assert.True(booking.ApplyPricing(100_000, 15_000, 85_000).IsSuccess);
        Assert.True(booking.TransitionTo(BookingStatus.PendingPayment).IsSuccess);
        Assert.True(booking.ConfirmPayment().IsSuccess);
        db.Bookings.Add(booking);
        await db.SaveChangesAsync();

        var registrations = new ServiceCollection();
        registrations.AddLogging();
        registrations.AddSignalR();
        new PeopleModule().RegisterServices(registrations, new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["ConnectionStrings:CareSitter"] = database.ConnectionString })
            .Build());
        registrations.AddSingleton<IUserProfileReader, Avatars>();
        await using var provider = registrations.BuildServiceProvider();
        await using var scope = provider.CreateAsyncScope();
        var offers = new RetryOfferNotification();
        var initial = new MatchingService(db, profiles, new Addresses(point),
            scope.ServiceProvider.GetRequiredService<IPeopleLookupService>(), new Routes(), offers,
            scope.ServiceProvider.GetRequiredService<IHubContext<CareTrackingHub>>(),
            Options.Create(new MatchingOptions()), NullLogger<MatchingService>.Instance, new SystemClock());

        await Assert.ThrowsAsync<InvalidOperationException>(() => initial.EnsureInitialOffersAsync(booking.Id, default));
        Assert.Empty(await initial.EnsureInitialOffersAsync(booking.Id, default));
        var assignment = await db.BookingAssignments.SingleAsync(x => x.BookingId == booking.Id);
        Assert.Equal(caregiver, assignment.CaregiverId);
        Assert.Equal("OFFERED", assignment.Status);
        Assert.Equal(new Guid?[] { assignment.Id, assignment.Id }, offers.EventIds);
        hold.Release();
        heldBooking.SelectCaregiver(caregiver);
        heldBooking.ConfirmPayment();
        await db.SaveChangesAsync();
        Assert.Empty(await matching.PreviewAsync(preview, default));
    }
    [PostgresFact, Trait("Category", "PostgreSQL")]
    public async Task Structured_needs_are_persisted_and_exposed_by_public_read_contracts_in_the_owner_scope()
    {
        await using var database = await PostgresRaceTestDatabase.CreateAsync();
        var registrations = new ServiceCollection();
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?> {
            ["ConnectionStrings:CareSitter"] = database.ConnectionString }).Build();
        new PeopleModule().RegisterServices(registrations,config);
        new CatalogModule().RegisterServices(registrations,config);
        registrations.AddSingleton<IUserProfileReader>(new Avatars());
        registrations.AddLogging();
        await using var services = registrations.BuildServiceProvider();
        await using var scope = services.CreateAsyncScope();
        Guid owner, beneficiary, service;
        await using(var conn = await database.OpenConnectionAsync())
        {
            await using var select = new NpgsqlCommand("SELECT b.customer_id,b.id,(SELECT id FROM catalog.service_types WHERE code='NONMED_ESSENTIAL' LIMIT 1) AS service_id FROM people.beneficiaries b ORDER BY b.id LIMIT 1",conn);
            await using(var reader = await select.ExecuteReaderAsync())
            { Assert.True(await reader.ReadAsync()); owner=reader.GetGuid(0);beneficiary=reader.GetGuid(1);service=reader.GetGuid(2); }
            await using var update = new NpgsqlCommand("UPDATE people.beneficiaries SET required_caregiver_skills=ARRAY['ho tro di chuyen'] WHERE id=@id",conn);
            update.Parameters.AddWithValue("id",beneficiary);await update.ExecuteNonQueryAsync();
        }
        var people = scope.ServiceProvider.GetRequiredService<IPeopleLookupService>();
        var catalog = scope.ServiceProvider.GetRequiredService<ICatalogLookupService>();
        Assert.Equal(new[] {"ho tro di chuyen"},await people.GetRequiredCaregiverSkillsAsync(beneficiary,owner));
        Assert.Empty(await people.GetRequiredCaregiverSkillsAsync(beneficiary,Guid.NewGuid()));
        Assert.Contains("chuan bi bua an",await catalog.GetRequiredCaregiverSkillsAsync(service));
        var resolved = await BookingCareRequirements.ResolveAsync(owner,beneficiary,service,[],people,catalog,default);
        Assert.True(resolved.IsSuccess);Assert.Contains("ho tro di chuyen",resolved.Value);
        Assert.Contains("chuan bi bua an",resolved.Value);
    }
    private sealed class Avatars : IUserProfileReader
    {
        public Task<string?> GetAvatarUrlAsync(Guid userId,CancellationToken ct=default) => Task.FromResult<string?>(null);
    }
    private sealed class RetryOfferNotification : IUserNotificationService
    {
        public List<Guid?> EventIds { get; } = [];

        public Task NotifyAsync(UserNotificationMessage message, CancellationToken ct = default)
        {
            EventIds.Add(message.EventId);
            if (EventIds.Count == 1) throw new InvalidOperationException("Temporary test failure");
            return Task.CompletedTask;
        }
    }
    private sealed class Profiles(IReadOnlyList<MatchingCaregiverProfile> values) : IMatchingCaregiverReader
    {
        public Task<IReadOnlyList<MatchingCaregiverProfile>> ListAvailableAsync(CancellationToken ct = default) =>
            Task.FromResult<IReadOnlyList<MatchingCaregiverProfile>>(values.Where(x => x.AvailabilityStatus == "ONLINE").ToArray());
        public Task<IReadOnlyList<MatchingCaregiverProfile>> ListForScheduledBookingAsync(CancellationToken ct = default) => Task.FromResult(values);
    }
    private sealed class Addresses(GeoPoint point) : IMatchingAddressReader
    {
        public Task<MatchingAddress?> GetAsync(Guid id, CancellationToken ct = default) =>
            Task.FromResult<MatchingAddress?>(new("D1", "HCM", point));
    }
    private sealed class Routes : IRouteMatrixService
    {
        public Task<IReadOnlyList<RouteMatrixItem>> CalculateAsync(IReadOnlyList<GeoPoint> origins,
            GeoPoint destination, CancellationToken ct = default) =>
            Task.FromResult<IReadOnlyList<RouteMatrixItem>>(origins.Select((_, i) => new RouteMatrixItem(i, 1000, 120)).ToArray());
    }
}
