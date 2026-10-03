using CareSitter.Contracts.Services;
using CareSitter.Modules.Promotion.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class PromotionRaceTests : IAsyncLifetime
{
    private static readonly Guid CustomerId =
        Guid.Parse("a0000000-0000-0000-0000-0000000000c1");
    private static readonly Guid ServiceTypeId =
        Guid.Parse("a0000000-0000-0000-0000-0000000000f1");

    private PostgresRaceTestDatabase _database = null!;

    public Task InitializeAsync() => InitializeDatabaseAsync();
    public async Task DisposeAsync()
    {
        if (_database is not null) await _database.DisposeAsync();
    }

    [PostgresFact]
    public async Task ConcurrentReservations_CannotExceedPromotionQuota()
    {
        var now = DateTimeOffset.UtcNow;
        await InsertSingleUsePromotionAsync(now);

        var results = await Task.WhenAll(
            ReserveAsync(Guid.NewGuid(), now),
            ReserveAsync(Guid.NewGuid(), now));

        Assert.Single(results, x => x.IsSuccess);
        Assert.Single(results, x => x.IsFailure &&
            x.Error.Code is "promotion.usage_limit_reached" or
                "promotion.customer_usage_limit_reached");

        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT count(*)
            FROM promotion.promotion_redemptions
            WHERE status = 'RESERVED'
            """, connection);
        Assert.Equal(1L, (long)(await command.ExecuteScalarAsync())!);
    }

    private async Task<CareSitter.SharedKernel.Results.Result<PromotionPriceQuote>> ReserveAsync(
        Guid bookingId, DateTimeOffset now)
    {
        await using var db = new PromotionDbContext(
            new DbContextOptionsBuilder<PromotionDbContext>()
                .UseNpgsql(_database.ConnectionString).Options);
        var service = new PromotionApplicationService(
            db, new BookingLookupStub(), new ClockStub(now));
        return await service.ReserveAsync(new PromotionReservationRequest(
            "RACE1", CustomerId, bookingId, ServiceTypeId,
            now.AddDays(1), now.AddDays(1).AddHours(2), now.AddMinutes(30),
            500_000));
    }

    private async Task InsertSingleUsePromotionAsync(DateTimeOffset now)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO promotion.promotions (
              id, code, title, summary, badge_text, terms,
              discount_type, discount_value, min_order_amount,
              starts_at, ends_at, is_active, first_paid_booking_only,
              total_usage_limit, per_customer_usage_limit, priority, is_featured)
            VALUES (
              gen_random_uuid(), 'RACE1', 'Race test', 'Race test', '10%', '[]'::jsonb,
              'PERCENTAGE', 10, 0, @starts_at, @ends_at, TRUE, FALSE, 1, 1, 0, FALSE)
            """, connection);
        command.Parameters.AddWithValue("starts_at", now.AddDays(-1));
        command.Parameters.AddWithValue("ends_at", now.AddDays(1));
        await command.ExecuteNonQueryAsync();
    }

    private async Task InitializeDatabaseAsync() =>
        _database = await PostgresRaceTestDatabase.CreateAsync();

    private sealed class BookingLookupStub : IPromotionBookingLookup
    {
        public Task<bool> HasPaidBookingAsync(Guid customerId,
            CancellationToken ct = default) => Task.FromResult(false);
    }

    private sealed record ClockStub(DateTimeOffset UtcNow) : IClock;
}
