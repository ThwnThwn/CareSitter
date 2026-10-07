using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Promotion;
using CareSitter.Modules.Promotion.Application;
using CareSitter.Modules.Promotion.Controllers;
using CareSitter.Modules.Promotion.Domain;
using CareSitter.Modules.Promotion.Infrastructure;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class AdminPromotionTests : IAsyncLifetime
{
    private static readonly Guid CustomerId = Guid.Parse("a0000000-0000-0000-0000-0000000000c1");
    private static readonly Guid ServiceId = Guid.Parse("a0000000-0000-0000-0000-0000000000f1");
    private PostgresRaceTestDatabase _database = null!;
    private readonly Clock _clock = new(DateTimeOffset.UtcNow);
    public async Task InitializeAsync() => _database = await PostgresRaceTestDatabase.CreateAsync();
    public async Task DisposeAsync() { if (_database is not null) await _database.DisposeAsync(); }
    private PromotionDbContext Context() => new(new DbContextOptionsBuilder<PromotionDbContext>().UseNpgsql(_database.ConnectionString).Options);
    private PromotionAdminStore Store(PromotionDbContext db) => new(db, new CatalogStub(), _clock);
    private PromotionConfiguration Configuration(string code = "ADMIN10") => new(
        code, "Chiến dịch test", "Giảm 10%", "Mô tả", "10%", ["Áp dụng theo điều kiện"],
        PromotionDiscountType.Percentage, 10, 100_000, 200_000, _clock.UtcNow.AddDays(-1),
        _clock.UtcNow.AddDays(7), true, false, 10, 2, 1, true, [ServiceId]);
    private async Task<AdminPromotionResponse> CreateAsync(PromotionConfiguration configuration)
    {
        await using var db = Context();
        return (await Store(db).CreateAsync(configuration, default)).Value.After!;
    }

    [PostgresFact]
    public async Task Crud_updates_scopes_filters_and_public_listing_and_deletes_unused_campaign()
    {
        var configuration = Configuration(" admin10 ");
        var created = await CreateAsync(configuration);
        Assert.Equal("ADMIN10", created.Code);
        Assert.True(created.CanDelete);
        await using (var db = Context())
        {
            var duplicate = await Store(db).CreateAsync(configuration, default);
            Assert.Equal("promotion.code_exists", duplicate.Error.Code);
        }
        await using (var db = Context())
        {
            var store = Store(db);
            var list = await store.ListAsync("chiến", "ACTIVE", 1, 20, default);
            Assert.Contains(list.Items, x => x.Id == created.Id);
            var updated = await store.UpdateAsync(created.Id,
                configuration with { EligibleServiceIds = [], Title = "Updated", IsActive = false },
                created.UpdatedAt, default);
            Assert.True(updated.IsSuccess);
            created = updated.Value.After!;
            Assert.Empty(created.EligibleServiceIds);
            Assert.Equal("INACTIVE", created.Status);
            Assert.DoesNotContain((await new PromotionReadStore(db).ListActiveAsync(_clock.UtcNow, default)), x => x.Id == created.Id);
        }
        await using (var db = Context())
        {
            var changed = await Store(db).SetActiveAsync(created.Id, true, created.UpdatedAt, default);
            Assert.True(changed.IsSuccess);
            created = changed.Value.After!;
            Assert.Contains((await new PromotionReadStore(db).ListActiveAsync(_clock.UtcNow, default)), x => x.Id == created.Id);
        }
        await using (var db = Context())
        {
            Assert.True((await Store(db).DeleteAsync(created.Id, created.UpdatedAt, default)).IsSuccess);
            Assert.Null(await Store(db).GetAsync(created.Id, default));
        }
    }

    [PostgresFact]
    public async Task History_locks_financial_rules_and_delete_but_allows_safe_updates_and_redemption_after_disable()
    {
        var configuration = Configuration();
        var promotion = await CreateAsync(configuration);
        var first = Guid.NewGuid(); var second = Guid.NewGuid();
        // Admin edits use timestamps returned by PostgreSQL, which stores microseconds.
        configuration = configuration with { StartsAt = promotion.StartsAt, EndsAt = promotion.EndsAt };
        Assert.True((await ReserveAsync(first)).IsSuccess);
        Assert.True((await ReserveAsync(second)).IsSuccess);
        await using (var db = Context())
        {
            var state = (await Store(db).GetAsync(promotion.Id, default))!;
            Assert.Equal(2, state.ReservedCount);
            Assert.False(state.CanDelete);
            Assert.Equal("promotion.has_history", (await Store(db).DeleteAsync(state.Id, state.UpdatedAt, default)).Error.Code);
            Assert.Equal("promotion.rules_locked", (await Store(db).UpdateAsync(state.Id,
                configuration with { DiscountValue = 20 }, state.UpdatedAt, default)).Error.Code);
            Assert.Equal("promotion.quota_below_usage", (await Store(db).UpdateAsync(state.Id,
                configuration with { TotalUsageLimit = 1 }, state.UpdatedAt, default)).Error.Code);
            Assert.Equal("promotion.customer_quota_below_usage", (await Store(db).UpdateAsync(state.Id,
                configuration with { PerCustomerUsageLimit = 1 }, state.UpdatedAt, default)).Error.Code);
            var updated = await Store(db).UpdateAsync(state.Id, configuration with { Title = "Updated", TotalUsageLimit = 20 },
                state.UpdatedAt, default);
            Assert.True(updated.IsSuccess);
            promotion = updated.Value.After!;
        }
        await using (var db = Context())
            Assert.True((await Store(db).SetActiveAsync(promotion.Id, false, promotion.UpdatedAt, default)).IsSuccess);
        Assert.Equal("promotion.not_active", (await ReserveAsync(Guid.NewGuid())).Error.Code);
        await using (var db = Context())
        {
            var service = new PromotionApplicationService(db, new BookingLookup(), _clock);
            Assert.True((await service.RedeemAsync(first, CustomerId)).IsSuccess);
            Assert.True((await service.ReleaseAsync(second, CustomerId, "CANCELLED")).IsSuccess);
            var state = (await Store(db).GetAsync(promotion.Id, default))!;
            Assert.Equal(1, state.RedeemedCount);
            Assert.Equal(1, state.ReleasedCount);
            Assert.Equal(0, state.ReservedCount);
            Assert.False(state.CanDelete);
        }
    }

    [PostgresFact]
    public async Task Concurrent_edits_and_creates_cannot_overwrite_or_duplicate_codes()
    {
        var configuration = Configuration();
        var promotion = await CreateAsync(configuration);
        async Task<CareSitter.SharedKernel.Results.Result<AdminPromotionChange>> Edit(string title)
        {
            await using var db = Context();
            return await Store(db).UpdateAsync(promotion.Id, configuration with { Title = title }, promotion.UpdatedAt, default);
        }
        var edits = await Task.WhenAll(Edit("Admin A"), Edit("Admin B"));
        Assert.Single(edits, x => x.IsSuccess);
        Assert.Single(edits, x => x.IsFailure && x.Error.Code == "promotion.stale");
        async Task<CareSitter.SharedKernel.Results.Result<AdminPromotionChange>> Insert()
        {
            await using var db = Context();
            return await Store(db).CreateAsync(configuration with { Code = "SAME_CODE" }, default);
        }
        var inserts = await Task.WhenAll(Insert(), Insert());
        Assert.Single(inserts, x => x.IsSuccess);
        Assert.Single(inserts, x => x.IsFailure && x.Error.Code == "promotion.code_exists");
    }

    [PostgresFact]
    public async Task Delete_and_reserve_share_the_lock_and_preserve_any_successful_reservation()
    {
        var promotion = await CreateAsync(Configuration());
        var bookingId = Guid.NewGuid();
        async Task<CareSitter.SharedKernel.Results.Result<AdminPromotionChange>> Delete()
        {
            await using var db = Context();
            return await Store(db).DeleteAsync(promotion.Id, promotion.UpdatedAt, default);
        }
        var deletion = Delete(); var reservation = ReserveAsync(bookingId);
        await Task.WhenAll(deletion, reservation);
        Assert.True(deletion.Result.IsSuccess != reservation.Result.IsSuccess);
        await using var context = Context();
        Assert.Equal(reservation.Result.IsSuccess, await context.PromotionRedemptions.AnyAsync(x => x.BookingId == bookingId));
        Assert.Equal(reservation.Result.IsSuccess, await context.Promotions.AnyAsync(x => x.Id == promotion.Id));
    }

    [PostgresFact]
    public async Task Invalid_services_and_stale_toggle_delete_are_rejected()
    {
        await using (var db = Context())
        {
            var invalid = await Store(db).CreateAsync(Configuration() with { EligibleServiceIds = [Guid.NewGuid()] }, default);
            Assert.Equal("promotion.invalid_services", invalid.Error.Code);
        }
        var state = await CreateAsync(Configuration());
        await using (var db = Context())
            Assert.True((await Store(db).SetActiveAsync(state.Id, false, state.UpdatedAt, default)).IsSuccess);
        await using (var db = Context())
        {
            Assert.Equal("promotion.stale", (await Store(db).SetActiveAsync(state.Id, true, state.UpdatedAt, default)).Error.Code);
            Assert.Equal("promotion.stale", (await Store(db).DeleteAsync(state.Id, state.UpdatedAt, default)).Error.Code);
        }
    }

    [PostgresFact]
    public async Task Http_routes_enforce_admin_role_validate_requests_and_emit_audited_crud_responses()
    {
        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseTestServer();
        builder.Logging.ClearProviders();
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?> { ["ConnectionStrings:CareSitter"] = _database.ConnectionString });
        builder.Services.AddAuthentication("test").AddScheme<AuthenticationSchemeOptions, RoleAuth>("test", _ => { });
        builder.Services.AddAuthorization();
        builder.Services.AddSingleton<IClock>(_clock);
        builder.Services.AddSingleton<ICatalogLookupService, CatalogStub>();
        var audit = new Audit();
        builder.Services.AddSingleton<IAuditLogger>(audit);
        new PromotionModule().RegisterServices(builder.Services, builder.Configuration);
        await using var app = builder.Build();
        app.UseAuthentication(); app.UseAuthorization(); app.MapControllers();
        await app.StartAsync();
        var client = app.GetTestClient();
        var id = Guid.NewGuid();
        foreach (var role in new[] { "", "CUSTOMER", "CAREGIVER" })
        {
            client.DefaultRequestHeaders.Remove("X-Test-Role");
            if (role != "") client.DefaultRequestHeaders.Add("X-Test-Role", role);
            foreach (var (method, path) in new[] {
                (HttpMethod.Get, ""), (HttpMethod.Get, $"/{id}"), (HttpMethod.Post, ""),
                (HttpMethod.Put, $"/{id}"), (HttpMethod.Patch, $"/{id}/active"), (HttpMethod.Delete, $"/{id}") })
            {
                using var request = new HttpRequestMessage(method, "/api/v1/admin/promotions" + path) { Content = JsonContent.Create(new { }) };
                Assert.Equal(role == "" ? HttpStatusCode.Unauthorized : HttpStatusCode.Forbidden, (await client.SendAsync(request)).StatusCode);
            }
        }
        Assert.Empty(audit.Actions);
        client.DefaultRequestHeaders.Remove("X-Test-Role"); client.DefaultRequestHeaders.Add("X-Test-Role", "ADMIN");
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/api/v1/admin/promotions?page=0")).StatusCode);
        var configuration = Configuration();
        UpsertAdminPromotionRequest Body(DateTimeOffset? version = null) => new(
            configuration.Code, configuration.Title, configuration.Summary, configuration.Description, configuration.BadgeText,
            configuration.Terms, "percentage", configuration.DiscountValue, configuration.MaxDiscountAmount, configuration.MinOrderAmount,
            configuration.StartsAt, configuration.EndsAt, false, false, 10, 2, 1, true, configuration.EligibleServiceIds, version);
        var created = await client.PostAsJsonAsync("/api/v1/admin/promotions", Body());
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var state = (await created.Content.ReadFromJsonAsync<AdminPromotionResponse>())!;
        Assert.Equal($"/api/v1/admin/promotions/{state.Id}", created.Headers.Location!.ToString());
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PutAsJsonAsync(created.Headers.Location, Body())).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/admin/promotions", Body() with { DiscountType = "bogus" })).StatusCode);
        var updated = await client.PutAsJsonAsync(created.Headers.Location, Body(state.UpdatedAt) with { Title = "Updated" });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        state = (await updated.Content.ReadFromJsonAsync<AdminPromotionResponse>())!;
        var activated = await client.PatchAsJsonAsync($"/api/v1/admin/promotions/{state.Id}/active", new SetAdminPromotionActiveRequest(true, state.UpdatedAt));
        Assert.Equal(HttpStatusCode.OK, activated.StatusCode);
        state = (await activated.Content.ReadFromJsonAsync<AdminPromotionResponse>())!;
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync($"/api/v1/admin/promotions/{state.Id}")).StatusCode);
        using var delete = new HttpRequestMessage(HttpMethod.Delete, $"/api/v1/admin/promotions/{state.Id}") { Content = JsonContent.Create(new DeleteAdminPromotionRequest(state.UpdatedAt)) };
        Assert.Equal(HttpStatusCode.NoContent, (await client.SendAsync(delete)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/admin/promotions/{state.Id}")).StatusCode);
        Assert.Equal(new[] { "ADMIN_PROMOTION_CREATED", "ADMIN_PROMOTION_UPDATED", "ADMIN_PROMOTION_ACTIVE_CHANGED", "ADMIN_PROMOTION_DELETED" }, audit.Actions);
    }

    private async Task<CareSitter.SharedKernel.Results.Result<PromotionPriceQuote>> ReserveAsync(Guid bookingId)
    {
        await using var db = Context();
        return await new PromotionApplicationService(db, new BookingLookup(), _clock).ReserveAsync(
            new PromotionReservationRequest("ADMIN10", CustomerId, bookingId, ServiceId,
                _clock.UtcNow.AddDays(1), _clock.UtcNow.AddDays(1).AddHours(2), _clock.UtcNow.AddMinutes(30), 500_000));
    }
    private sealed record Clock(DateTimeOffset UtcNow) : IClock;
    private sealed class BookingLookup : IPromotionBookingLookup
    { public Task<bool> HasPaidBookingAsync(Guid customerId, CancellationToken ct = default) => Task.FromResult(false); }
    private sealed class Audit : IAuditLogger
    {
        public List<string> Actions { get; } = [];
        public Task WriteAsync(string action, string entityType, Guid entityId, object? before, object? after, CancellationToken ct = default)
        { Actions.Add(action); return Task.CompletedTask; }
    }
    private sealed class CatalogStub : ICatalogLookupService
    {
        public Task<ServiceDisplaySummary?> GetServiceDisplayAsync(Guid id, CancellationToken ct = default) =>
            Task.FromResult(id == ServiceId ? new ServiceDisplaySummary(id, "Service") : null);
        public Task<bool> AddressBelongsToAsync(Guid id, Guid customer, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> AddressIsVerifiedForBookingAsync(Guid id, Guid customer, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> ServiceIsActiveAsync(Guid id, CancellationToken ct = default) => Task.FromResult(id == ServiceId);
        public Task<AddressDisplaySummary?> GetAddressDisplayAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<(double Lat, double Lng)?> GetAddressLocationAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
    }
    private sealed class RoleAuth(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var role = Request.Headers["X-Test-Role"].ToString();
            if (role is not ("ADMIN" or "CUSTOMER" or "CAREGIVER")) return Task.FromResult(AuthenticateResult.NoResult());
            var identity = new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, CustomerId.ToString()), new Claim(ClaimTypes.Role, role)], "test");
            return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), "test")));
        }
    }
}
