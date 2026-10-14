using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class ConsultationRequestPostgresTests
{
    [PostgresFact]
    public async Task Concurrent_retries_store_one_request_and_return_the_same_receipt()
    {
        await using var database = await PostgresRaceTestDatabase.CreateAsync();
        var request = NewRequest(Guid.NewGuid());
        var results = await Task.WhenAll(Enumerable.Range(0, 8).Select(async _ =>
        {
            await using var db = Context(database.ConnectionString);
            return await new ConsultationRequestStore(db).SaveAsync(request, default);
        }));
        Assert.All(results, result => Assert.True(result.IsSuccess));
        Assert.Single(results.Select(result => result.Value).Distinct());
        await using var read = Context(database.ConnectionString);
        Assert.Equal(1, await read.Set<ConsultationRequest>().CountAsync());
        var list = await new ConsultationRequestStore(read).ListAsync(1, 20, default);
        Assert.Equal("0912345678", Assert.Single(list.Items).Phone);
    }

    [PostgresFact]
    public async Task Reusing_key_with_changed_payload_is_rejected_without_overwriting()
    {
        await using var database = await PostgresRaceTestDatabase.CreateAsync();
        var id = Guid.NewGuid();
        await using (var first = Context(database.ConnectionString))
            Assert.True((await new ConsultationRequestStore(first).SaveAsync(NewRequest(id), default)).IsSuccess);
        await using var retry = Context(database.ConnectionString);
        var result = await new ConsultationRequestStore(retry).SaveAsync(NewRequest(id, "Gia đình B"), default);
        Assert.True(result.IsFailure);
        Assert.Equal("consultation.key_conflict", result.Error.Code);
        Assert.Equal("Gia đình A", (await retry.Set<ConsultationRequest>().SingleAsync()).ContactName);
    }

    private static SupportDbContext Context(string connection) => new(
        new DbContextOptionsBuilder<SupportDbContext>().UseNpgsql(connection,
            options => options.UseNetTopologySuite()).Options);

    [PostgresFact]
    public async Task Replay_after_Vietnam_midnight_returns_saved_receipt_but_new_past_request_fails()
    {
        await using var database = await PostgresRaceTestDatabase.CreateAsync();
        var id = Guid.NewGuid();
        var beforeMidnight = new DateTime(2026, 10, 12, 16, 59, 0, DateTimeKind.Utc);
        ConsultationRequest Attempt(Guid key, DateTime now) => ConsultationRequest.Create(key,
            "Gia đình A", "0912345678", "elderly_care", new DateOnly(2026, 10, 12),
            4, null, null, true, now).Value;
        await using var db = Context(database.ConnectionString);
        var store = new ConsultationRequestStore(db);
        var first = await store.SaveAsync(Attempt(id, beforeMidnight), default);
        var replay = await store.SaveAsync(Attempt(id, beforeMidnight.AddHours(1)), default);
        Assert.True(first.IsSuccess);
        Assert.True(replay.IsSuccess);
        Assert.Equal(first.Value, replay.Value);
        var newPastRequest = await store.SaveAsync(Attempt(Guid.NewGuid(), beforeMidnight.AddHours(1)), default);
        Assert.Equal("consultation.date", newPastRequest.Error.Code);
        Assert.Equal(1, await db.Set<ConsultationRequest>().CountAsync());
    }

    private static ConsultationRequest NewRequest(Guid id, string name = "Gia đình A") =>
        ConsultationRequest.Create(id, name, "0912345678", "elderly_care",
            DateOnly.FromDateTime(DateTime.UtcNow.AddDays(2)), 4, null, "Gọi buổi sáng", true,
            DateTime.UtcNow).Value;
}
