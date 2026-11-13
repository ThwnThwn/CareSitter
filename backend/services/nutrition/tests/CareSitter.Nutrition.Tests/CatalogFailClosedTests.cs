using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;
using Npgsql;

namespace CareSitter.Nutrition.Tests;

public sealed class CatalogFailClosedTests
{
    internal static Recipe Meal(string type) => new(Guid.NewGuid(), "Fixture " + type, type, 1,
        [new("RICE", "Rice", 100, "g", "raw")], [], new() { ["energy_kcal"] = 100 },
        ["Cook"], ["Fixture"], true);
    internal static HealthFact[] Allergies => [new("food_allergy", "SHRIMP", "Fixture", "present",
        "current", "allergies/0", "Fixture", "beneficiary")];

    [Theory]
    [InlineData("ai")]
    [InlineData("rejected")]
    [InlineData("unavailable")]
    [InlineData("ungrounded")]
    public async Task Incomplete_allergen_data_is_excluded_before_ranking_and_in_every_fallback(string mode)
    {
        var safe = new[] { Meal("breakfast"), Meal("lunch"), Meal("dinner") };
        var incomplete = safe.Select(m => m with { VersionId = Guid.NewGuid(), AllergenDataComplete = false }).ToArray();
        var ranker = new Ranker(mode, incomplete);
        var result = await new MealRecommendationEngine(new Knowledge(mode), ranker).RecommendAsync(
            new(7, [.. incomplete, .. safe], Allergies, [], "regular", "maintain"), default);
        Assert.Equal(safe.Select(m => m.VersionId), result.Meals!.Select(m => m.VersionId));
        Assert.Equal(mode == "ai", result.Trace.UsedAi);
        Assert.Equal(mode != "ungrounded", ranker.Called);
        if (mode == "rejected") Assert.Contains("meal_ranking_rejected", result.Trace.Warnings);
    }

    [Fact]
    public async Task Incomplete_only_catalog_returns_no_match_without_calling_ai()
    {
        var recipes = new[] { Meal("breakfast"), Meal("lunch"), Meal("dinner") }
            .Select(m => m with { AllergenDataComplete = false }).ToArray();
        var ranker = new Ranker("ai", recipes);
        var result = await new MealRecommendationEngine(new Knowledge("ai"), ranker)
            .RecommendAsync(new(7, recipes, Allergies, [], "regular", "maintain"), default);
        Assert.Null(result.Meals);
        Assert.Contains("constraints_not_matched", result.Trace.Warnings);
        Assert.False(ranker.Called);
    }

    private sealed class Knowledge(string mode) : IMealKnowledgeRetriever
    {
        public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct) =>
            Task.FromResult(mode == "ungrounded" ? MealKnowledgeResult.Unavailable("fixture_unavailable") :
                new(true, "fixture", "graph", [new("e1", "Fixture", null, "1", "page:1", "Fixture", "Fixture")], []));
    }
    private sealed class Ranker(string mode, Recipe[] incomplete) : IMealCandidateRanker
    {
        public bool Called { get; private set; }
        public Task<MealCandidateRankingResult> RankAsync(MealCandidateRankingRequest request, CancellationToken ct)
        {
            Called = true;
            Assert.All(request.CandidateSets.SelectMany(s => s), m => Assert.True(m.AllergenDataComplete));
            var ids = (mode == "rejected" ? incomplete : request.CandidateSets[0]).Select(m => m.VersionId).ToArray();
            return Task.FromResult(new MealCandidateRankingResult(mode != "unavailable", ids, "fixture", "v1", [], []));
        }
    }
}

// A disposable database with deliberately damaged metadata; no active catalog is modified.
public sealed class CatalogMetadataFailClosedTests : IAsyncLifetime
{
    private readonly string _name = "caresitter_wp2_" + Guid.NewGuid().ToString("N");
    private string? _admin;
    private NpgsqlConnection? _db;
    public async Task InitializeAsync()
    {
        var configured = Environment.GetEnvironmentVariable("CARESITTER_TEST_ADMIN_CONNECTION");
        if (string.IsNullOrWhiteSpace(configured)) return;
        _admin = new NpgsqlConnectionStringBuilder(configured) { Database = "postgres", Pooling = false }.ConnectionString;
        await using var admin = new NpgsqlConnection(_admin); await admin.OpenAsync();
        await using (var create = new NpgsqlCommand($"CREATE DATABASE \"{_name}\"", admin)) await create.ExecuteNonQueryAsync();
        _db = new(new NpgsqlConnectionStringBuilder(configured) { Database = _name, Pooling = false }.ConnectionString);
        await _db.OpenAsync();
        await SqlAsync("""
            CREATE SCHEMA nutrition;
            CREATE TABLE nutrition.catalog_state(id integer,revision bigint);
            INSERT INTO nutrition.catalog_state VALUES(1,7);
            CREATE TABLE nutrition.local_demo_catalog(package_key text,revision bigint,payload jsonb,payload_digest text);
            CREATE TABLE nutrition.catalog_packages(id uuid,status text,payload jsonb,payload_digest text);
            CREATE TABLE nutrition.catalog_package_entries(package_id uuid,content_kind text,version_id uuid,logical_id uuid,version int);
            CREATE TABLE nutrition.recipe_versions(id uuid,recipe_id uuid,version int,status text,payload jsonb);
            CREATE TABLE nutrition.rule_versions(id uuid,rule_id uuid,version int,status text,payload jsonb);
            CREATE FUNCTION nutrition.catalog_payload_digest(payload jsonb) RETURNS text
              LANGUAGE sql IMMUTABLE STRICT AS 'SELECT encode(sha256(convert_to(payload::text,''UTF8'')),''hex'')';
            """);
        var integrityPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/10-published-catalog-integrity.sql"));
        await SqlAsync(await File.ReadAllTextAsync(integrityPath));
    }
    private async Task SqlAsync(string sql)
    { await using var command = new NpgsqlCommand(sql, _db); await command.ExecuteNonQueryAsync(); }

    [PostgresFact]
    public async Task Missing_or_invalid_published_revision_fails_with_clear_catalog_error()
    {
        foreach (var state in new[] { "DELETE FROM nutrition.catalog_state", "INSERT INTO nutrition.catalog_state VALUES(1,0)" })
        {
            await SqlAsync(state);
            await using var tx = await _db!.BeginTransactionAsync();
            var reader = new NutritionCatalogReader(_db, tx, LocalDemoCatalogOptions.Disabled);
            var error = await Assert.ThrowsAsync<InvalidOperationException>(() => reader.CatalogRevisionAsync(default));
            Assert.Contains("catalog", error.Message, StringComparison.OrdinalIgnoreCase);
            await tx.RollbackAsync();
        }
    }

    [PostgresFact]
    public async Task Enabled_demo_missing_revision_digest_or_payload_never_falls_back_to_published_catalog()
    {
        var states = new[]
        {
            "", // missing configured package
            "INSERT INTO nutrition.local_demo_catalog VALUES('fixture-local-demo',NULL,'{}',NULL)",
            "INSERT INTO nutrition.local_demo_catalog VALUES('fixture-local-demo',0,'{}',NULL)",
            "INSERT INTO nutrition.local_demo_catalog VALUES('fixture-local-demo',1,'{}',NULL)",
            "INSERT INTO nutrition.local_demo_catalog VALUES('fixture-local-demo',1,'{}','')",
            "INSERT INTO nutrition.local_demo_catalog VALUES('fixture-local-demo',1,'{}',repeat('0',64))",
            "INSERT INTO nutrition.local_demo_catalog VALUES('fixture-local-demo',1,'{}',encode(sha256(convert_to('{}','UTF8')),'hex'))"
        };
        foreach (var state in states)
        {
            await SqlAsync("DELETE FROM nutrition.local_demo_catalog");
            if (state.Length > 0) await SqlAsync(state);
            await using var tx = await _db!.BeginTransactionAsync();
            var reader = new NutritionCatalogReader(_db, tx, new(true, "fixture-local-demo"));
            var error = await Assert.ThrowsAsync<InvalidOperationException>(() => reader.CatalogRevisionAsync(default));
            Assert.Contains("catalog", error.Message, StringComparison.OrdinalIgnoreCase);
            await tx.RollbackAsync();
        }
    }
    public async Task DisposeAsync()
    {
        if (_db is null) return;
        await _db.DisposeAsync();
        await using var admin = new NpgsqlConnection(_admin); await admin.OpenAsync();
        await using var drop = new NpgsqlCommand($"DROP DATABASE \"{_name}\" WITH (FORCE)", admin);
        await drop.ExecuteNonQueryAsync();
    }
}
