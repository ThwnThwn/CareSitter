using System.Text.Json;
using System.Text.RegularExpressions;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;
using Npgsql;

namespace CareSitter.Nutrition.Tests;

public sealed class PostgresWorkflowTests : IAsyncLifetime
{
    private readonly string _name = "caresitter_nutrition_" + Guid.NewGuid().ToString("N");
    private readonly string _role = "nutrition_test_" + Guid.NewGuid().ToString("N");
    private string _admin = "", _database = ""; private NpgsqlDataSource _dataSource = null!;
    private readonly Guid _owner = Guid.NewGuid(); private People _people = null!;
    private NutritionStore _store = null!;
    public async Task InitializeAsync()
    {
        var configured = Environment.GetEnvironmentVariable("CARESITTER_TEST_ADMIN_CONNECTION");
        if (string.IsNullOrWhiteSpace(configured)) return;
        _admin = new NpgsqlConnectionStringBuilder(configured) { Database = "postgres", Pooling = false }.ConnectionString;
        await using var connection = new NpgsqlConnection(_admin); await connection.OpenAsync();
        if (!Regex.IsMatch(_name, "^caresitter_nutrition_[a-f0-9]{32}$")) throw new InvalidOperationException();
        await using (var create = new NpgsqlCommand($"CREATE DATABASE \"{_name}\"", connection)) await create.ExecuteNonQueryAsync();
        _database = new NpgsqlConnectionStringBuilder(configured) { Database = _name }.ConnectionString;
        await using var db = new NpgsqlConnection(_database); await db.OpenAsync();
        var schemaPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/01-nutrition-workflow.sql"));
        await using (var schema = new NpgsqlCommand(await File.ReadAllTextAsync(schemaPath), db)) await schema.ExecuteNonQueryAsync();
        var password = Guid.NewGuid().ToString("N");
        await using (var role = new NpgsqlCommand($"""
            CREATE ROLE "{_role}" LOGIN PASSWORD '{password}';
            GRANT USAGE ON SCHEMA nutrition TO "{_role}";
            GRANT SELECT,INSERT,UPDATE,DELETE ON nutrition.assessments,nutrition.assessment_jobs,nutrition.recommendations,nutrition.meal_plans,nutrition.preferences TO "{_role}";
            GRANT SELECT ON nutrition.concepts,nutrition.rule_versions,nutrition.recipe_versions TO "{_role}";
            GRANT SELECT,UPDATE(id) ON nutrition.catalog_state TO "{_role}";
            """, db)) await role.ExecuteNonQueryAsync();
        _dataSource = NpgsqlDataSource.Create(new NpgsqlConnectionStringBuilder(_database) { Username = _role, Password = password }.ConnectionString);
        _store = new NutritionStore(_dataSource); _people = new People(_owner, EligibilityTests.Healthy());
    }
    public async Task DisposeAsync()
    {
        if (_database.Length == 0) return;
        if (_dataSource is not null) await _dataSource.DisposeAsync();
        await using var connection = new NpgsqlConnection(_admin); await connection.OpenAsync();
        await using (var kill = new NpgsqlCommand("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname=@name AND pid<>pg_backend_pid()", connection))
        { kill.Parameters.AddWithValue("name", _name); await kill.ExecuteNonQueryAsync(); }
        await using (var drop = new NpgsqlCommand($"DROP DATABASE \"{_name}\"; DROP ROLE \"{_role}\";", connection)) await drop.ExecuteNonQueryAsync();
    }
    private NutritionCommandHandler Handler(Guid? owner = null, string role = "CUSTOMER") => new(_people, _store, new Actor(owner ?? _owner, role), new Features());
    private NutritionCommand Request(string op = "assess", Guid? id = null, Guid? assessment = null) => new(op, _people.Source.BeneficiaryId, _people.Source.Revision, Guid.NewGuid(), id, assessment);
    private async Task<Guid> AssessAsync()
    {
        var result = await Handler().Handle(Request(), default); Assert.True(result.IsSuccess); return result.Value.Id;
    }
    private async Task ProcessAsync()
    {
        var job = await _store.ClaimAsync(default); Assert.NotNull(job);
        await new AssessmentProcessor(_people, _store, new UnconfiguredHealthParser()).ProcessAsync(job.Value, default);
    }
    private Task<Primitives.Result<ResourceResponse>> ReadAsync(string kind, Guid id) =>
        new NutritionResourceQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features()).Handle(new NutritionResourceQuery(kind, _people.Source.BeneficiaryId, id), default);

    [PostgresFact]
    public async Task Separate_database_and_restricted_role_enforce_owner_and_idempotency()
    {
        var request = Request(); var results = await Task.WhenAll(Enumerable.Range(0, 12).Select(_ => Handler().Handle(request, default)));
        Assert.All(results, r => Assert.True(r.IsSuccess)); Assert.Single(results.Select(r => r.Value.Id).Distinct());
        var conflict = await Handler().Handle(request with { BeneficiaryId = Guid.NewGuid() }, default);
        Assert.True(conflict.IsFailure);
        var sameKeyDifferentPayload = await Handler().Handle(request with { PlannedDate = new DateOnly(2027, 1, 1) }, default);
        Assert.Equal("nutrition.idempotency_conflict", sameKeyDifferentPayload.Error.Code);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using (var command = new NpgsqlCommand("SELECT count(*)::int FROM nutrition.assessments", connection)) Assert.Equal(0, await command.ExecuteScalarAsync());
        await using (var command = new NpgsqlCommand("SELECT to_regclass('people.beneficiaries') IS NULL", connection)) Assert.Equal(true, await command.ExecuteScalarAsync());
    }
    [PostgresFact]
    public async Task Structured_flow_confirms_and_returns_no_content_without_demo()
    {
        var id = await AssessAsync(); await ProcessAsync();
        var analyzed = await ReadAsync("assessment", id); Assert.Equal("awaiting_confirmation", analyzed.Value.Status);
        var confirmed = await Handler().Handle(Request("confirm", id), default); Assert.Equal("confirmed", confirmed.Value.Status);
        var meal = await Handler().Handle(Request("recommend", assessment: id), default); Assert.Equal("no_content", meal.Value.Status);
        Assert.Equal(0, meal.Value.Data.GetProperty("meals").GetArrayLength());
    }
    [PostgresFact]
    public async Task Quota_is_atomic_and_idempotent_retry_is_not_charged_twice()
    {
        var request = Request();
        for (var i = 0; i < 20; i++) Assert.True((await Handler().Handle(i == 0 ? request : Request(), default)).IsSuccess);
        Assert.True((await Handler().Handle(request, default)).IsSuccess);
        var rejected = await Handler().Handle(Request(), default);
        Assert.Equal("nutrition.quota", rejected.Error.Code);
        Assert.Equal(Primitives.ErrorType.RateLimited, rejected.Error.Type);
    }
    [PostgresFact]
    public async Task AI_failure_and_revision_change_never_become_success()
    {
        _people.Source = _people.Source with { GeneralNote = "Thông tin cần đọc", Revision = 2 };
        var id = await AssessAsync(); await ProcessAsync();
        var failed = await ReadAsync("assessment", id); Assert.Equal("failed", failed.Value.Status);
        Assert.Equal("nutrition.ai_unavailable", failed.Value.Data.GetProperty("errorCode").GetString());
        _people.Source = _people.Source with { Revision = 3 };
        Assert.Equal("stale", (await ReadAsync("assessment", id)).Value.Status);
        Assert.Equal("nutrition.profile_changed", (await Handler().Handle(Request("confirm", id), default)).Error.Code);
    }
    [PostgresFact]
    public async Task Lost_owner_or_deleted_profile_releases_no_snapshot_and_rejects_wrong_role()
    {
        var id = await AssessAsync();
        Assert.Equal("nutrition.forbidden", (await Handler(role: "CAREGIVER").Handle(Request(), default)).Error.Code);
        Assert.Equal("nutrition.profile_not_found", (await Handler(Guid.NewGuid()).Handle(Request(), default)).Error.Code);
        _people.Deleted = true; await ProcessAsync();
        Assert.Equal("nutrition.profile_not_found", (await ReadAsync("assessment", id)).Error.Code);
    }
    [PostgresFact]
    public async Task Expired_worker_cannot_write_over_new_lease()
    {
        var id = await AssessAsync(); var first = (await _store.ClaimAsync(default))!.Value;
        await SqlAsync("UPDATE nutrition.assessment_jobs SET lease_until=now()-interval '1 second'");
        var second = (await _store.ClaimAsync(default))!.Value; Assert.NotEqual(first.Token, second.Token);
        var update = await _store.InOwnerScopeAsync(_owner, async s =>
        {
            var r = (await s.GetAsync("assessment", _people.Source.BeneficiaryId, id, default))!;
            return await s.UpdateAsync("assessment", r with { Status = "failed" }, first.Token, default);
        }, default);
        Assert.False(update);
        await new AssessmentProcessor(_people, _store, new UnconfiguredHealthParser()).ProcessAsync(second, default);
        Assert.Equal("awaiting_confirmation", (await ReadAsync("assessment", id)).Value.Status);
    }
    [PostgresFact]
    public async Task Source_change_between_commit_and_response_rejects_old_operation()
    {
        var request = Request();
        _people.OnRead = read => { if (read == 2) _people.Source = _people.Source with { Revision = 2 }; };
        var result = await Handler().Handle(request, default);
        Assert.Equal("nutrition.profile_changed", result.Error.Code);
        _people.OnRead = null;
        var id = await _store.InOwnerScopeAsync(_owner, async session => (await session.FindByKeyAsync("assessment", request.IdempotencyKey, default))!.Id, default);
        Assert.Equal("stale", (await ReadAsync("assessment", id)).Value.Status);
        _people.OnRead = _ => _people.Deleted = true;
        Assert.Equal("nutrition.profile_not_found", (await ReadAsync("assessment", id)).Error.Code);
    }
    [PostgresFact]
    public async Task Published_fixture_can_be_saved_and_retirement_invalidates_it()
    {
        foreach (var meal in new[] { "breakfast", "lunch", "dinner" })
        {
            var recipe = EligibilityTests.Recipe(meal, 1);
            await using var db = new NpgsqlConnection(_database); await db.OpenAsync();
            await using var command = new NpgsqlCommand("INSERT INTO nutrition.recipe_versions(id,recipe_id,version,status,payload,reviewed_by,reviewed_at,published_at) VALUES(@id,@id,1,'published',@payload::jsonb,'fixture reviewer',now(),now())", db);
            command.Parameters.AddWithValue("id", recipe.VersionId); command.Parameters.AddWithValue("payload", NutritionJson.Write(recipe)); await command.ExecuteNonQueryAsync();
        }
        var id = await AssessAsync(); await ProcessAsync(); await Handler().Handle(Request("confirm", id), default);
        var recommendationRequest = Request("recommend", assessment: id);
        var recommendation = await Handler().Handle(recommendationRequest, default); Assert.Equal("suggested", recommendation.Value.Status);
        var saved = await Handler().Handle(Request("save", recommendation.Value.Id), default); Assert.Equal("saved", saved.Value.Status);
        await SqlAsync("UPDATE nutrition.recipe_versions SET status='retired'");
        Assert.Equal("stale", (await Handler().Handle(recommendationRequest, default)).Value.Status);
        Assert.Equal("stale", (await ReadAsync("plan", saved.Value.Id)).Value.Status);
        Assert.Equal("nutrition.content_changed", (await Handler().Handle(Request("save", recommendation.Value.Id), default)).Error.Code);
    }
    private async Task SqlAsync(string sql)
    { await using var db = new NpgsqlConnection(_database); await db.OpenAsync(); await using var c = new NpgsqlCommand(sql, db); await c.ExecuteNonQueryAsync(); }
    [PostgresFact]
    public async Task Replacement_candidates_and_write_enforce_daily_limits_and_allergies()
    {
        var concepts = new[] { new NutritionConcept("A", "condition", ["A"], 1), new NutritionConcept("SHRIMP", "food_allergy", ["Tôm"], 1) };
        await using var db = new NpgsqlConnection(_database); await db.OpenAsync();
        foreach (var concept in concepts)
        {
            await using var command = new NpgsqlCommand("INSERT INTO nutrition.concepts VALUES(@code,@kind,@aliases::jsonb,1)", db);
            command.Parameters.AddWithValue("code", concept.Code); command.Parameters.AddWithValue("kind", concept.Kind);
            command.Parameters.AddWithValue("aliases", NutritionJson.Write(concept.Aliases)); await command.ExecuteNonQueryAsync();
        }
        var rule = new DietaryRule(Guid.NewGuid(), "A", [], [], new() { { "sodium_mg", 40 } }, ["Fixture source"]);
        await using (var command = new NpgsqlCommand("INSERT INTO nutrition.rule_versions VALUES(@id,@id,1,'published',@payload::jsonb,'fixture reviewer',now(),now())", db))
        { command.Parameters.AddWithValue("id", rule.VersionId); command.Parameters.AddWithValue("payload", NutritionJson.Write(rule)); await command.ExecuteNonQueryAsync(); }
        var safe = EligibilityTests.Recipe("lunch", 12) with { Name = "Safe replacement" };
        var unsafeSalt = EligibilityTests.Recipe("lunch", 99); var unsafeAllergy = EligibilityTests.Recipe("lunch", 1) with { Allergens = ["SHRIMP"] };
        var recipes = new[] { EligibilityTests.Recipe("breakfast", 10), EligibilityTests.Recipe("lunch", 10), EligibilityTests.Recipe("dinner", 10), safe, unsafeSalt, unsafeAllergy };
        foreach (var recipe in recipes)
        {
            await using var command = new NpgsqlCommand("INSERT INTO nutrition.recipe_versions VALUES(@id,@id,1,'published',@payload::jsonb,'fixture reviewer',now(),now())", db);
            command.Parameters.AddWithValue("id", recipe.VersionId); command.Parameters.AddWithValue("payload", NutritionJson.Write(recipe)); await command.ExecuteNonQueryAsync();
        }
        _people.Source = _people.Source with
        {
            AllergyStatus = "reported_present",
            Allergies = JsonSerializer.SerializeToElement(new[] { "Tôm" }),
            ChronicConditions = JsonSerializer.SerializeToElement(new[] { "A" }),
            HealthHistory = JsonSerializer.SerializeToElement(new { nutrition = new { schemaVersion = 1, conditionsStatus = "reported_present" } })
        };
        var id = await AssessAsync(); await ProcessAsync(); await Handler().Handle(Request("confirm", id), default);
        var recommended = await Handler().Handle(Request("recommend", assessment: id), default); Assert.Equal("suggested", recommended.Value.Status);
        var options = await new ReplacementOptionsQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features())
            .Handle(new(_people.Source.BeneficiaryId, recommended.Value.Id, "lunch"), default);
        Assert.True(options.IsSuccess); Assert.NotEmpty(options.Value);
        Assert.DoesNotContain(options.Value, r => r.VersionId == unsafeSalt.VersionId || r.VersionId == unsafeAllergy.VersionId);
        var rejected = await Handler().Handle(Request("replace", recommended.Value.Id) with { RecipeVersionId = unsafeSalt.VersionId, MealType = "lunch" }, default);
        Assert.Equal("nutrition.constraint", rejected.Error.Code);
        var chosen = options.Value[0]; var replaced = await Handler().Handle(Request("replace", recommended.Value.Id) with { RecipeVersionId = chosen.VersionId, MealType = "lunch" }, default);
        Assert.Equal("suggested", replaced.Value.Status); Assert.NotEqual(recommended.Value.Id, replaced.Value.Id);
        _people.Deleted = true;
        var history = await new NutritionResourceQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features()).Handle(new ListMealPlansQuery(_people.Source.BeneficiaryId), default);
        Assert.Equal("nutrition.profile_not_found", history.Error.Code);
    }
    private sealed class People(Guid owner, BeneficiaryHealthSnapshot source) : IPeopleHealthClient
    {
        public BeneficiaryHealthSnapshot Source = source; public bool Deleted;
        public Action<int>? OnRead; public int Reads;
        public Task<BeneficiaryHealthSnapshot?> ReadAsync(Guid actor, Guid beneficiary, CancellationToken ct)
        {
            OnRead?.Invoke(++Reads);
            return Task.FromResult(!Deleted && actor == owner && beneficiary == Source.BeneficiaryId ? Source : null);
        }
    }
    private sealed class Actor(Guid owner, string role) : ICurrentUser
    { public Guid? UserId => owner; public IReadOnlyList<string> Roles => [role]; }
    private sealed class Features : INutritionFeatures
    { public bool Enabled => true; public bool AssessmentsEnabled => true; public bool RecommendationsEnabled => true; }
}

internal sealed class PostgresFactAttribute : FactAttribute
{
    public PostgresFactAttribute() { if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("CARESITTER_TEST_ADMIN_CONNECTION"))) Skip = "PostgreSQL test connection not configured."; }
}
