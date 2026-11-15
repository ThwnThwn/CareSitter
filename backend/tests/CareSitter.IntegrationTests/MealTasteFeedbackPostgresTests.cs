using System.Text.Json;
using CareSitter.Contracts.Nutrition;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.People;
using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.HealthProfile;
using CareSitter.Modules.People.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class MealTasteFeedbackPostgresTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase database = null!;
    private NpgsqlDataSource source = null!;
    private Guid owner, beneficiary;
    private MealPlanSnapshot plan = null!;
    public async Task InitializeAsync()
    {
        database = await PostgresRaceTestDatabase.CreateAsync();
        var builder = new NpgsqlDataSourceBuilder(database.ConnectionString);
        builder.UseNetTopologySuite();
        source = builder.Build();
        await using var connection = await database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO people.beneficiaries(customer_id,full_name,health_history,allergies)
            SELECT customer_id,'Taste fixture','{"legacy":{"note":"keep"},"nutrition":{"schemaVersion":1,"dislikedFoods":"Cá hấp"}}','["Tôm"]'
            FROM people.beneficiaries LIMIT 1 RETURNING customer_id,id
            """, connection);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync()); owner = reader.GetGuid(0); beneficiary = reader.GetGuid(1);
        plan = new(Guid.NewGuid(), beneficiary, DateOnly.FromDateTime(DateTime.UtcNow.AddHours(7)),
            [new(Guid.NewGuid(), "Cá hấp", "lunch", 1, [new("Cá", 100, "g")], ["Hấp chín"], [])]);
    }
    public async Task DisposeAsync() { if (source is not null) await source.DisposeAsync(); if (database is not null) await database.DisposeAsync(); }
    private ServiceProvider Services(Guid? actor = null, string role = "CUSTOMER", MealPlanSnapshot? snapshot = null)
    {
        var services = new ServiceCollection(); services.AddLogging(); services.AddSingleton(source);
        new PeopleModule().RegisterServices(services, new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?> { ["ConnectionStrings:CareSitter"] = database.ConnectionString }).Build());
        services.UseFixtureProvider<PeopleDbContext>();
        services.AddSingleton<ICurrentUser>(new Actor(actor ?? owner, role));
        services.AddSingleton<IClock, SystemClock>();
        services.AddSingleton<IMealPlanSnapshotReader>(new Plans(snapshot ?? plan));
        return services.BuildServiceProvider();
    }
    private async Task<Result<T>> SendAsync<T>(IRequest<Result<T>> command, Guid? actor = null, string role = "CUSTOMER", MealPlanSnapshot? snapshot = null)
    {
        await using var services = Services(actor, role, snapshot);
        return await services.GetRequiredService<IMediator>().Send(command);
    }
    private async Task<BeneficiaryHealthSnapshot> HealthAsync()
    {
        await using var services = Services();
        return (await services.GetRequiredService<IBeneficiaryHealthSnapshotReader>().ReadAsync(owner, beneficiary))!;
    }
    private SubmitMealTasteFeedbackCommand Submit(string feedback = "liked") => new(beneficiary, plan.Id, plan.Meals[0].VersionId, feedback, Guid.NewGuid());

    [PostgresFact]
    public async Task Draft_does_not_change_preferences_and_concurrent_approval_is_atomic_and_replayable()
    {
        var before = await HealthAsync(); var request = Submit();
        var drafts = await Task.WhenAll(SendAsync(request), SendAsync(request));
        Assert.All(drafts, result => Assert.True(result.IsSuccess, result.Error.Message));
        Assert.Equal(drafts[0].Value.Id, drafts[1].Value.Id);
        Assert.Equal(before.Revision, (await HealthAsync()).Revision);
        var review = new ReviewMealTasteFeedbackCommand(beneficiary, drafts[0].Value.Id, true, before.Revision);
        var approved = await Task.WhenAll(SendAsync(review), SendAsync(review));
        Assert.All(approved, result => Assert.True(result.IsSuccess, result.Error.Message));
        var after = await HealthAsync();
        Assert.Equal(before.Revision + 1, after.Revision);
        Assert.All(approved, result => Assert.Equal(after.Revision, result.Value.AppliedHealthRevision));
        Assert.Equal(before.Allergies!.Value.GetRawText(), after.Allergies!.Value.GetRawText());
        Assert.Equal("keep", after.HealthHistory!.Value.GetProperty("legacy").GetProperty("note").GetString());
        var nutrition = after.HealthHistory.Value.GetProperty("nutrition");
        Assert.Equal("Cá hấp", nutrition.GetProperty("preferredFoods").GetString());
        Assert.Equal("", nutrition.GetProperty("dislikedFoods").GetString());
        Assert.Equal("approved", (await SendAsync(request)).Value.Status);
        Assert.Equal("nutrition.feedback_key_conflict", (await SendAsync(request with { Feedback = "disliked" })).Error.Code);
        Assert.Equal("nutrition.feedback_reviewed", (await SendAsync(review with { Approve = false })).Error.Code);
    }

    [PostgresFact]
    public async Task Owner_revision_is_checked_and_rejection_never_mutates_health()
    {
        var before = await HealthAsync();
        var draft = (await SendAsync(Submit())).Value;
        var wrong = await SendAsync(new ReviewMealTasteFeedbackCommand(beneficiary, draft.Id, true, before.Revision + 1));
        Assert.Equal("nutrition.profile_changed", wrong.Error.Code);
        var reject = await SendAsync(new ReviewMealTasteFeedbackCommand(beneficiary, draft.Id, false, 0));
        Assert.True(reject.IsSuccess);
        Assert.Equal(before.Revision, (await HealthAsync()).Revision);
        Assert.True((await SendAsync(Submit("want_again"))).IsSuccess);
        Assert.True((await SendAsync(new ListMealTasteFeedbackQuery(beneficiary, plan.Id), Guid.NewGuid())).IsFailure);
        Assert.True((await SendAsync(new ReviewMealTasteFeedbackCommand(beneficiary, draft.Id, true, before.Revision), owner, "CAREGIVER")).IsFailure);
    }

    [PostgresFact]
    public async Task Unowned_future_and_fabricated_meals_are_rejected()
    {
        Assert.True((await SendAsync(Submit() with { RecipeVersionId = Guid.NewGuid() })).IsFailure);
        Assert.True((await SendAsync(Submit(), snapshot: plan with { PlannedDate = plan.PlannedDate.AddDays(1) })).IsFailure);
        Assert.True((await SendAsync(Submit(), Guid.NewGuid())).IsFailure);
        Assert.True((await SendAsync(Submit(), owner, "CAREGIVER")).IsFailure);
        var before = await HealthAsync();
        Assert.Equal("Cá hấp", before.HealthHistory!.Value.GetProperty("nutrition").GetProperty("dislikedFoods").GetString());
    }

    private sealed class Actor(Guid id, string role) : ICurrentUser
    { public Guid? UserId => id; public IReadOnlyCollection<string> Roles => [role]; public bool IsInRole(string value) => value == role; }
    private sealed class Plans(MealPlanSnapshot plan) : IMealPlanSnapshotReader
    { public Task<Result<MealPlanSnapshot>> ReadAsync(Guid beneficiaryId, Guid planId, CancellationToken ct) => Task.FromResult<Result<MealPlanSnapshot>>(plan); }

    [PostgresFact]
    public async Task Row_security_hides_feedback_from_another_owner_for_a_non_superuser_role()
    {
        Assert.True((await SendAsync(Submit())).IsSuccess);
        var role = "taste_reader_" + Guid.NewGuid().ToString("N");
        await using var connection = await database.OpenConnectionAsync();
        await using (var setup = new NpgsqlCommand($"CREATE ROLE {role} NOLOGIN; GRANT USAGE ON SCHEMA people TO {role}; GRANT SELECT ON people.meal_taste_feedback TO {role};", connection))
            await setup.ExecuteNonQueryAsync();
        await using var transaction = await connection.BeginTransactionAsync();
        await using (var setRole = new NpgsqlCommand($"SET LOCAL ROLE {role}", connection, transaction)) await setRole.ExecuteNonQueryAsync();
        async Task<long> Count(Guid actor)
        {
            await using var context = new NpgsqlCommand("SELECT set_config('app.current_user_id',@actor,true)", connection, transaction);
            context.Parameters.AddWithValue("actor", actor.ToString()); await context.ExecuteNonQueryAsync();
            await using var query = new NpgsqlCommand("SELECT count(*) FROM people.meal_taste_feedback", connection, transaction);
            return (long)(await query.ExecuteScalarAsync())!;
        }
        Assert.Equal(0, await Count(Guid.NewGuid()));
        Assert.Equal(1, await Count(owner));
        await transaction.RollbackAsync();
    }
}
