using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Catalog;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;
using Npgsql;

namespace CareSitter.Nutrition.Tests;

public sealed partial class PostgresWorkflowTests : IAsyncLifetime
{
    private readonly string _name = "caresitter_nutrition_" + Guid.NewGuid().ToString("N");
    private readonly string _role = "nutrition_test_" + Guid.NewGuid().ToString("N");
    private readonly string _importerRole = "nutrition_importer_test_" + Guid.NewGuid().ToString("N");
    private readonly string _reviewerRole = "nutrition_reviewer_test_" + Guid.NewGuid().ToString("N");
    private readonly string _publisherRole = "nutrition_publisher_test_" + Guid.NewGuid().ToString("N");
    private string _admin = "", _database = "", _rolePassword = ""; private NpgsqlDataSource _dataSource = null!;
    private string _importerConnection = "", _reviewerConnection = "", _publisherConnection = "";
    private readonly Guid _owner = Guid.NewGuid(); private People _people = null!;
    private NutritionStore _store = null!;
    private RecommendationLockDataSource _lockDataSource = null!;
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
        var catalogPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/03-catalog-governance.sql"));
        await using (var catalog = new NpgsqlCommand(await File.ReadAllTextAsync(catalogPath), db)) await catalog.ExecuteNonQueryAsync();
        var constraintPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/04-catalog-nutrient-constraints.sql"));
        await using (var constraints = new NpgsqlCommand(await File.ReadAllTextAsync(constraintPath), db)) await constraints.ExecuteNonQueryAsync();
        var citationPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/05-recipe-source-citations.sql"));
        await using (var citations = new NpgsqlCommand(await File.ReadAllTextAsync(citationPath), db)) await citations.ExecuteNonQueryAsync();
        var evidencePath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/06-catalog-release-evidence.sql"));
        await using (var evidence = new NpgsqlCommand(await File.ReadAllTextAsync(evidencePath), db)) await evidence.ExecuteNonQueryAsync();
        var knowledgeReviewPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/07-catalog-knowledge-review-gate.sql"));
        await using (var knowledgeReview = new NpgsqlCommand(await File.ReadAllTextAsync(knowledgeReviewPath), db)) await knowledgeReview.ExecuteNonQueryAsync();
        var localDemoPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/08-local-demo-catalog.sql"));
        await using (var localDemo = new NpgsqlCommand(await File.ReadAllTextAsync(localDemoPath), db)) await localDemo.ExecuteNonQueryAsync();
        var knowledgeChunksPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/09-knowledge-chunks.sql"));
        await using (var knowledgeChunks = new NpgsqlCommand(await File.ReadAllTextAsync(knowledgeChunksPath), db)) await knowledgeChunks.ExecuteNonQueryAsync();
        var integrityPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/10-published-catalog-integrity.sql"));
        await using (var integrity = new NpgsqlCommand(await File.ReadAllTextAsync(integrityPath), db)) await integrity.ExecuteNonQueryAsync();
        var reviewPolicyPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/11-catalog-review-policy.sql"));
        await using (var reviewPolicy = new NpgsqlCommand(await File.ReadAllTextAsync(reviewPolicyPath), db)) await reviewPolicy.ExecuteNonQueryAsync();
        var deletionPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/12-beneficiary-deletion.sql"));
        await using (var deletion = new NpgsqlCommand(await File.ReadAllTextAsync(deletionPath), db)) await deletion.ExecuteNonQueryAsync();
        var password = Guid.NewGuid().ToString("N");
        _rolePassword = password;
        var importerPassword = Guid.NewGuid().ToString("N");
        var reviewerPassword = Guid.NewGuid().ToString("N");
        var publisherPassword = Guid.NewGuid().ToString("N");
        await using (var role = new NpgsqlCommand($"""
            CREATE ROLE "{_role}" LOGIN PASSWORD '{password}';
            CREATE ROLE "{_importerRole}" LOGIN PASSWORD '{importerPassword}';
            CREATE ROLE "{_reviewerRole}" LOGIN PASSWORD '{reviewerPassword}';
            CREATE ROLE "{_publisherRole}" LOGIN PASSWORD '{publisherPassword}';
            GRANT nutrition_catalog_importer TO "{_importerRole}";
            GRANT nutrition_catalog_reviewer TO "{_reviewerRole}";
            GRANT nutrition_catalog_publisher TO "{_publisherRole}";
            GRANT USAGE ON SCHEMA nutrition TO "{_role}";
            GRANT EXECUTE ON FUNCTION nutrition.published_catalog_integrity() TO "{_role}";
            GRANT SELECT,INSERT,UPDATE,DELETE ON nutrition.assessments,nutrition.assessment_jobs,nutrition.recommendations,nutrition.meal_plans,nutrition.preferences TO "{_role}";
            GRANT SELECT,INSERT ON nutrition.beneficiary_deletions,nutrition.beneficiary_deletion_inbox TO "{_role}";
            GRANT SELECT ON nutrition.concepts,nutrition.rule_versions,nutrition.recipe_versions,nutrition.recipe_source_citations,nutrition.local_demo_catalog TO "{_role}";
            GRANT SELECT,UPDATE(id) ON nutrition.catalog_state TO "{_role}";
            """, db)) await role.ExecuteNonQueryAsync();
        _dataSource = NpgsqlDataSource.Create(new NpgsqlConnectionStringBuilder(_database) { Username = _role, Password = password }.ConnectionString);
        _importerConnection = new NpgsqlConnectionStringBuilder(_database) { Username = _importerRole, Password = importerPassword }.ConnectionString;
        _reviewerConnection = new NpgsqlConnectionStringBuilder(_database) { Username = _reviewerRole, Password = reviewerPassword }.ConnectionString;
        _publisherConnection = new NpgsqlConnectionStringBuilder(_database) { Username = _publisherRole, Password = publisherPassword }.ConnectionString;
        _lockDataSource = new RecommendationLockDataSource(new NpgsqlConnectionStringBuilder(_database) { Username = _role, Password = password }.ConnectionString);
        _store = new NutritionStore(_dataSource, _lockDataSource); _people = new People(_owner, EligibilityTests.Healthy());
    }
    public async Task DisposeAsync()
    {
        if (_database.Length == 0) return;
        if (_dataSource is not null) await _dataSource.DisposeAsync();
        if (_lockDataSource is not null) await _lockDataSource.DisposeAsync();
        await using var connection = new NpgsqlConnection(_admin); await connection.OpenAsync();
        await using (var kill = new NpgsqlCommand("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname=@name AND pid<>pg_backend_pid()", connection))
        { kill.Parameters.AddWithValue("name", _name); await kill.ExecuteNonQueryAsync(); }
        await using (var drop = new NpgsqlCommand($"DROP DATABASE \"{_name}\"; DROP ROLE \"{_role}\"; DROP ROLE \"{_importerRole}\"; DROP ROLE \"{_reviewerRole}\"; DROP ROLE \"{_publisherRole}\";", connection)) await drop.ExecuteNonQueryAsync();
    }
    private CommandDispatcher Handler(Guid? owner = null, string role = "CUSTOMER") =>
        new(new NutritionWriteScope(_people, _store, new Actor(owner ?? _owner, role), new Features()));
    private NutritionWriteCommand Request(string op = "assess", Guid? id = null, Guid? assessment = null)
    {
        var beneficiary = _people.Source.BeneficiaryId;
        var input = new NutritionWriteInput(_people.Source.Revision, Guid.NewGuid(), assessment);
        return op switch
        {
            "assess" => new AssessNutritionCommand(beneficiary, input),
            "confirm" => new ConfirmNutritionCommand(beneficiary, id ?? Guid.Empty, input),
            "recommend" => new RecommendMealsCommand(beneficiary, input),
            "replace" => new ReplaceMealCommand(beneficiary, id ?? Guid.Empty, input),
            "save" => new SaveMealPlanCommand(beneficiary, id ?? Guid.Empty, input),
            _ => throw new ArgumentException("Unknown test operation.")
        };
    }
    private sealed class CommandDispatcher(NutritionWriteScope scope)
    {
        public Task<Primitives.Result<ResourceResponse>> Handle(NutritionWriteCommand command, CancellationToken ct) =>
            command switch
            {
                AssessNutritionCommand assess => new AssessNutritionCommandHandler(scope).Handle(assess, ct),
                ConfirmNutritionCommand confirm => new ConfirmNutritionCommandHandler(scope).Handle(confirm, ct),
                RecommendMealsCommand recommend => new RecommendMealsCommandHandler(scope, new(),
                    new MealRecommendationEngine(new UnavailableMealKnowledgeRetriever(),
                        new UnavailableMealCandidateRanker())).Handle(recommend, ct),
                ReplaceMealCommand replace => new ReplaceMealCommandHandler(scope, new()).Handle(replace, ct),
                SaveMealPlanCommand save => new SaveMealPlanCommandHandler(scope, new()).Handle(save, ct),
                _ => throw new ArgumentException("Unknown test command.")
            };
    }
    private sealed class PausedRecommendationEngine : IMealRecommendationEngine
    {
        public TaskCompletionSource Entered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource Resume { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task<MealRecommendationResult> RecommendAsync(MealRecommendationRequest request, CancellationToken ct)
        {
            Entered.TrySetResult();
            await Resume.Task.WaitAsync(ct);
            return await new MealRecommendationEngine(new UnavailableMealKnowledgeRetriever(),
                new UnavailableMealCandidateRanker()).RecommendAsync(request, ct);
        }
    }

    private async Task<Guid> AssessAsync()
    {
        var result = await Handler().Handle(Request(), default); Assert.True(result.IsSuccess); return result.Value.Id;
    }
    private async Task ProcessAsync(IHealthDescriptionParser? parser = null)
    {
        var job = await _store.ClaimAsync(default); Assert.NotNull(job);
        await new AssessmentProcessor(_people, _store, parser ?? new UnconfiguredHealthParser()).ProcessAsync(job.Value, default);
    }
    private Task<Primitives.Result<ResourceResponse>> ReadAsync(string kind, Guid id) =>
        new NutritionResourceQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features()).Handle(new NutritionResourceQuery(kind, _people.Source.BeneficiaryId, id), default);

    [PostgresFact]
    public async Task Knowledge_chunks_exist_but_runtime_role_cannot_read_or_write_them()
    {
        await using var db = new NpgsqlConnection(_database); await db.OpenAsync();
        await using var command = new NpgsqlCommand("""
            SELECT to_regclass('nutrition.knowledge_chunks') IS NOT NULL,
                   has_table_privilege(@role, 'nutrition.knowledge_chunks', 'SELECT'),
                   has_table_privilege(@role, 'nutrition.knowledge_chunks', 'INSERT')
            """, db);
        command.Parameters.AddWithValue("role", _role);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        Assert.True(reader.GetBoolean(0));
        Assert.False(reader.GetBoolean(1));
        Assert.False(reader.GetBoolean(2));
    }

    [PostgresFact]
    public async Task Separate_database_and_restricted_role_enforce_owner_and_idempotency()
    {
        var request = Request(); var results = await Task.WhenAll(Enumerable.Range(0, 12).Select(_ => Handler().Handle(request, default)));
        Assert.All(results, r => Assert.True(r.IsSuccess)); Assert.Single(results.Select(r => r.Value.Id).Distinct());
        var conflict = await Handler().Handle(request with { BeneficiaryId = Guid.NewGuid() }, default);
        Assert.True(conflict.IsFailure);
        var sameKeyDifferentPayload = await Handler().Handle(request with { Input = request.Input with { PlannedDate = new DateOnly(2027, 1, 1) } }, default);
        Assert.Equal("nutrition.idempotency_conflict", sameKeyDifferentPayload.Error.Code);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using (var command = new NpgsqlCommand("SELECT count(*)::int FROM nutrition.assessments", connection)) Assert.Equal(0, await command.ExecuteScalarAsync());
        await using (var command = new NpgsqlCommand("SELECT to_regclass('people.beneficiaries') IS NULL", connection)) Assert.Equal(true, await command.ExecuteScalarAsync());
    }
    [PostgresFact]
    public async Task Readiness_requires_full_schema_restricted_role_and_owner_policies()
    {
        Assert.True(await NutritionDatabaseReadiness.CheckAsync(_dataSource, default));
        await using var admin = NpgsqlDataSource.Create(_database);
        Assert.False(await NutritionDatabaseReadiness.CheckAsync(admin, default));
        await SqlAsync($"REVOKE USAGE ON SCHEMA nutrition FROM \"{_role}\"");
        Assert.False(await NutritionDatabaseReadiness.CheckAsync(_dataSource, default));
        await SqlAsync($"GRANT USAGE ON SCHEMA nutrition TO \"{_role}\"; GRANT INSERT ON nutrition.recipe_versions TO \"{_role}\"");
        Assert.False(await NutritionDatabaseReadiness.CheckAsync(_dataSource, default));
        await SqlAsync($"REVOKE INSERT ON nutrition.recipe_versions FROM \"{_role}\"; DELETE FROM nutrition.catalog_state");
        Assert.False(await NutritionDatabaseReadiness.CheckAsync(_dataSource, default));
        await SqlAsync("INSERT INTO nutrition.catalog_state VALUES(1,1)");
        await SqlAsync("ALTER TABLE nutrition.meal_plans DISABLE ROW LEVEL SECURITY");
        Assert.False(await NutritionDatabaseReadiness.CheckAsync(_dataSource, default));
        await SqlAsync("ALTER TABLE nutrition.meal_plans ENABLE ROW LEVEL SECURITY; ALTER TABLE nutrition.preferences RENAME COLUMN payload TO missing_payload");
        Assert.False(await NutritionDatabaseReadiness.CheckAsync(_dataSource, default));
    }
    [PostgresFact]
    public async Task Readiness_requires_reviewed_published_meals_when_recommendations_are_enabled()
    {
        Assert.False(await NutritionDatabaseReadiness.CheckAsync(
            _dataSource, default, requirePublishedCatalog: true));

        foreach (var meal in new[] { "breakfast", "lunch", "dinner" })
        {
            var recipe = EligibilityTests.Recipe(meal, 1);
            await using var db = new NpgsqlConnection(_database);
            await db.OpenAsync();
            await using var command = new NpgsqlCommand("""
                INSERT INTO nutrition.recipe_versions(
                    id,recipe_id,version,status,payload,reviewed_by,reviewed_at,published_at)
                VALUES(@id,@id,1,'published',@payload::jsonb,'fixture reviewer',now(),now())
                """, db);
            command.Parameters.AddWithValue("id", recipe.VersionId);
            command.Parameters.AddWithValue("payload", NutritionJson.Write(recipe));
            await command.ExecuteNonQueryAsync();
        }

        await RegisterRawCatalogFixtureAsync();
        Assert.True(await NutritionDatabaseReadiness.CheckAsync(
            _dataSource, default, requirePublishedCatalog: true));
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
    public async Task Local_demo_catalog_is_visible_only_when_explicitly_enabled()
        => await VerifyLocalCatalogAsync("adult-baseline-book-demo.bundle.json", 12, 1);

    [PostgresFact]
    public async Task Expanded_variety_catalog_supports_save_and_non_repeating_recommendation()
        => await VerifyLocalCatalogAsync("adult-baseline-variety-demo.bundle.json", 78, 20);

    private async Task VerifyLocalCatalogAsync(string fileName, int catalogCount, int eligibleLunchCount)
    {
        var path = Path.Combine(
            ServiceArchitectureTests.FindRoot(),
            "catalog",
            "drafts",
            fileName);
        var source = NutritionJson.Read<CatalogBundle>(await File.ReadAllTextAsync(path));
        var prepared = CatalogLocalDemoPolicy.Prepare(source);
        Assert.True(prepared.IsValid, string.Join(Environment.NewLine, prepared.Issues.Select(issue => issue.Message)));
        var bundle = prepared.Bundle!;
        await CatalogFunctionAsync(_importerConnection, "SELECT nutrition.import_local_demo_catalog(@key,@payload::jsonb)", command =>
        {
            command.Parameters.AddWithValue("key", bundle.PackageKey);
            command.Parameters.AddWithValue("payload", NutritionJson.Write(bundle));
        });

        var hidden = await _store.InOwnerScopeAsync(_owner, session => session.RecipesAsync(default), default);
        var demoStore = new NutritionStore(_dataSource, _lockDataSource, new(true, bundle.PackageKey));
        var visible = await demoStore.InOwnerScopeAsync(_owner, session => session.RecipesAsync(default), default);

        Assert.Empty(hidden);
        Assert.Equal(catalogCount, visible.Count);
        Assert.Equal(catalogCount / 3, visible.Count(recipe => recipe.MealType == "breakfast"));
        Assert.Equal(catalogCount / 3, visible.Count(recipe => recipe.MealType == "lunch"));
        Assert.Equal(catalogCount / 3, visible.Count(recipe => recipe.MealType == "dinner"));
        Assert.Equal(eligibleLunchCount, visible.Count(recipe =>
            recipe.MealType == "lunch" && MealConstraintPolicy.ValidRecipe(recipe)));
        if (source.Recipes.All(recipe => recipe.Payload.Images is { Length: > 0 }))
            Assert.All(visible, recipe => Assert.NotEmpty(recipe.Images!));
        Assert.All(visible, recipe => Assert.StartsWith("[DEMO] ", recipe.Name, StringComparison.Ordinal));

        var demoHandler = new CommandDispatcher(new NutritionWriteScope(
            _people,
            demoStore,
            new Actor(_owner, "CUSTOMER"),
            new Features()));
        var assessment = await demoHandler.Handle(Request(), default);
        Assert.True(assessment.IsSuccess);
        var job = await demoStore.ClaimAsync(default);
        Assert.NotNull(job);
        await new AssessmentProcessor(_people, demoStore, new UnconfiguredHealthParser())
            .ProcessAsync(job.Value, default);
        var confirmation = await demoHandler.Handle(Request("confirm", assessment.Value.Id), default);
        Assert.Equal("confirmed", confirmation.Value.Status);
        var recommendation = await demoHandler.Handle(
            Request("recommend", assessment: assessment.Value.Id),
            default);

        Assert.Equal("suggested", recommendation.Value.Status);
        var meals = recommendation.Value.Data.GetProperty("meals").EnumerateArray().ToArray();
        Assert.Equal(3, meals.Length);
        if (source.Recipes.All(recipe => recipe.Payload.Images is { Length: > 0 }))
            Assert.All(meals, meal => Assert.InRange(meal.GetProperty("images").GetArrayLength(), 1, 3));
        Assert.All(meals, meal =>
            Assert.StartsWith("[DEMO] ", meal.GetProperty("name").GetString(), StringComparison.Ordinal));

        var options = await new ReplacementOptionsQueryHandler(
                _people,
                demoStore,
                new Actor(_owner, "CUSTOMER"),
                new Features())
            .Handle(new(_people.Source.BeneficiaryId, recommendation.Value.Id, "lunch"), default);
        Assert.True(options.IsSuccess);
        Assert.Equal(eligibleLunchCount - 1, options.Value.Count);

        if (eligibleLunchCount == 1)
        {
            var onlyPlan = await demoHandler.Handle(Request("save", recommendation.Value.Id), default);
            Assert.Equal("saved", onlyPlan.Value.Status);
            return;
        }

        var chosen = options.Value[0];
        var replacement = ((ReplaceMealCommand)Request("replace", recommendation.Value.Id)) with
        {
            Input = new(
                _people.Source.Revision,
                Guid.NewGuid(),
                RecipeVersionId: chosen.VersionId,
                MealType: "lunch")
        };
        var replaced = await demoHandler.Handle(replacement, default);
        Assert.Equal("suggested", replaced.Value.Status);
        Assert.NotEqual(recommendation.Value.Id, replaced.Value.Id);

        var saved = await demoHandler.Handle(Request("save", replaced.Value.Id), default);
        Assert.Equal("saved", saved.Value.Status);

        var nextRequest = Request("recommend", assessment: assessment.Value.Id);
        var next = await demoHandler.Handle(nextRequest, default);
        Assert.True(next.IsSuccess);
        var previousIds = saved.Value.Data.GetProperty("meals").EnumerateArray()
            .Select(item => item.GetProperty("versionId").GetGuid()).ToHashSet();
        var nextIds = next.Value.Data.GetProperty("meals").EnumerateArray()
            .Select(item => item.GetProperty("versionId").GetGuid()).ToArray();
        Assert.Equal(3, nextIds.Length);
        if (fileName.Contains("variety", StringComparison.Ordinal))
            Assert.DoesNotContain(nextIds, previousIds.Contains);
        var replay = await demoHandler.Handle(nextRequest, default);
        Assert.Equal(next.Value.Id, replay.Value.Id);
    }
    [PostgresFact]
    public async Task Missing_information_exposes_bounded_questions_through_the_resource_payload()
    {
        _people.Source = _people.Source with
        {
            AllergyStatus = "unknown",
            AllergyConfirmedAt = null
        };

        var id = await AssessAsync();
        await ProcessAsync();
        var analyzed = await ReadAsync("assessment", id);

        Assert.Equal("needs_information", analyzed.Value.Status);
        var questions = analyzed.Value.Data.GetProperty("decision").GetProperty("questions").EnumerateArray().ToArray();
        Assert.InRange(questions.Length, 1, 3);
        Assert.Equal("food-allergy-status.v1", questions[0].GetProperty("id").GetString());
        Assert.Equal("foodAllergyStatus", questions[0].GetProperty("sourceField").GetString());
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
        Assert.Equal("nutrition.ai_not_configured", failed.Value.Data.GetProperty("errorCode").GetString());
        _people.Source = _people.Source with { Revision = 3 };
        Assert.Equal("stale", (await ReadAsync("assessment", id)).Value.Status);
        Assert.Equal("nutrition.profile_changed", (await Handler().Handle(Request("confirm", id), default)).Error.Code);
    }
    [PostgresFact]
    public async Task GraphRag_context_is_versioned_validated_and_recorded_with_parser_result()
    {
        await using (var db = new NpgsqlConnection(_database))
        {
            await db.OpenAsync();
            await using var concept = new NpgsqlCommand("INSERT INTO nutrition.concepts VALUES('HYPERTENSION','condition','[\"tăng huyết áp\"]'::jsonb,1)", db);
            await concept.ExecuteNonQueryAsync();
        }
        _people.Source = _people.Source with { GeneralNote = "Beni tăng huyết áp.", Revision = 2 };
        var parser = new CapturingParser();

        var id = await AssessAsync();
        await ProcessAsync(parser);
        var assessment = await ReadAsync("assessment", id);

        Assert.NotNull(parser.Request);
        Assert.Equal(parser.Request.DictionaryRevision, parser.Request.Graph.Revision);
        Assert.Contains(parser.Request.Graph.Nodes, node => node.Id == "concept:condition:HYPERTENSION");
        Assert.Equal("fixture-parser.v1", assessment.Value.Data.GetProperty("parserPromptVersion").GetString());
        Assert.Equal(HealthKnowledgeGraphRetriever.Strategy,
            assessment.Value.Data.GetProperty("parserRetrievalStrategy").GetString());
        Assert.Equal(parser.Request.Graph.Revision, assessment.Value.Data.GetProperty("parserGraphRevision").GetInt64());
    }
    [PostgresFact]
    public async Task Catalog_change_during_parser_call_marks_assessment_stale()
    {
        _people.Source = _people.Source with { GeneralNote = "Ghi chú cần phân tích.", Revision = 2 };
        var parser = new CatalogMutatingParser(() => SqlAsync(
            "UPDATE nutrition.catalog_state SET revision=revision+1 WHERE id=1"));

        var id = await AssessAsync();
        await ProcessAsync(parser);
        var assessment = await ReadAsync("assessment", id);

        Assert.Equal("stale", assessment.Value.Status);
        Assert.Equal("nutrition.content_changed", assessment.Value.Data.GetProperty("errorCode").GetString());
        Assert.Contains("catalog_changed", assessment.Value.Data.GetProperty("decision")
            .GetProperty("reasonCodes").EnumerateArray().Select(item => item.GetString()));
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
    public async Task Source_change_between_commit_and_response_returns_committed_resource_stale()
    {
        var request = Request();
        _people.OnRead = read => { if (read == 2) _people.Source = _people.Source with { Revision = 2 }; };
        var result = await Handler().Handle(request, default);
        Assert.True(result.IsSuccess);
        Assert.Equal("stale", result.Value.Status);
        Assert.Equal(1, result.Value.HealthRevision);
        var stored = await _store.InOwnerScopeAsync(_owner,
            session => session.FindByKeyAsync("assessment", request.IdempotencyKey, default), default);
        Assert.Equal(result.Value.Id, stored!.Id);
        Assert.Equal("queued", stored.Status);
        Assert.Equal("stale", (await ReadAsync("assessment", stored.Id)).Value.Status);
    }

    [PostgresFact]
    public async Task Retry_same_payload_after_post_commit_revision_change_returns_same_stale_resource()
    {
        var request = Request();
        _people.OnRead = read => { if (read == 2) _people.Source = _people.Source with { Revision = 2 }; };
        await Handler().Handle(request, default);
        var stored = await _store.InOwnerScopeAsync(_owner,
            session => session.FindByKeyAsync("assessment", request.IdempotencyKey, default), default);
        var retry = await Handler().Handle(request, default);
        Assert.True(retry.IsSuccess);
        Assert.Equal(stored!.Id, retry.Value.Id);
        Assert.Equal("stale", retry.Value.Status);
        Assert.Equal(1, retry.Value.HealthRevision);
        Assert.Equal(stored.CreatedAt, retry.Value.CreatedAt);
        Assert.Equal(1, await _store.InOwnerScopeAsync(_owner, s => s.AssessmentCountAsync(default), default));
        var freshKey = request with { Input = request.Input with { IdempotencyKey = Guid.NewGuid() } };
        Assert.Equal("nutrition.profile_changed", (await Handler().Handle(freshKey, default)).Error.Code);
    }

    [PostgresFact]
    public async Task Retry_changed_payload_after_post_commit_revision_change_conflicts()
    {
        var request = Request();
        _people.OnRead = read => { if (read == 2) _people.Source = _people.Source with { Revision = 2 }; };
        await Handler().Handle(request, default);
        var retry = request with { Input = request.Input with { ExpectedHealthRevision = 2 } };
        Assert.Equal("nutrition.idempotency_conflict", (await Handler().Handle(retry, default)).Error.Code);
        retry = request with { Input = request.Input with { PlannedDate = new DateOnly(2027, 1, 3) } };
        Assert.Equal("nutrition.idempotency_conflict", (await Handler().Handle(retry, default)).Error.Code);
        Assert.Equal(1, await _store.InOwnerScopeAsync(_owner, s => s.AssessmentCountAsync(default), default));
    }

    [PostgresFact]
    public async Task Profile_deleted_or_transferred_after_commit_hides_resource_from_all_old_owner_reads()
    {
        foreach (var transfer in new[] { false, true })
        {
            _people.Deleted = false; _people.Owner = _owner;
            var request = Request();
            var afterCommit = _people.Reads + 2;
            _people.OnRead = read =>
            {
                if (read != afterCommit) return;
                if (transfer) _people.Owner = Guid.NewGuid(); else _people.Deleted = true;
            };
            Assert.Equal("nutrition.profile_not_found", (await Handler().Handle(request, default)).Error.Code);
            var stored = await _store.InOwnerScopeAsync(_owner,
                session => session.FindByKeyAsync("assessment", request.IdempotencyKey, default), default);
            Assert.NotNull(stored);
            Assert.Equal("nutrition.profile_not_found", (await Handler().Handle(request, default)).Error.Code);
            foreach (var kind in new[] { "assessment", "recommendation", "plan" })
                Assert.Equal("nutrition.profile_not_found", (await ReadAsync(kind, stored.Id)).Error.Code);
            var queries = new NutritionResourceQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features());
            Assert.Equal("nutrition.profile_not_found", (await queries.Handle(new ListMealPlansQuery(request.BeneficiaryId), default)).Error.Code);
            var options = new ReplacementOptionsQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features());
            Assert.Equal("nutrition.profile_not_found", (await options.Handle(new(request.BeneficiaryId, stored.Id, "lunch"), default)).Error.Code);
        }
    }
    [PostgresFact]
    public async Task Meal_writes_and_confirmation_return_stale_after_commit_and_replay_keeps_identity()
    {
        foreach (var meal in new[] { "breakfast", "lunch", "dinner", "lunch" })
        {
            var recipe = EligibilityTests.Recipe(meal, 1);
            await using var db = new NpgsqlConnection(_database); await db.OpenAsync();
            await using var command = new NpgsqlCommand("INSERT INTO nutrition.recipe_versions(id,recipe_id,version,status,payload,reviewed_by,reviewed_at,published_at) VALUES(@id,@id,1,'published',@payload::jsonb,'fixture reviewer',now(),now())", db);
            command.Parameters.AddWithValue("id", recipe.VersionId);
            command.Parameters.AddWithValue("payload", NutritionJson.Write(recipe));
            await command.ExecuteNonQueryAsync();
        }
        await RegisterRawCatalogFixtureAsync();
        var assessment = await AssessAsync(); await ProcessAsync();
        var confirm = Request("confirm", assessment);
        var confirmRead = _people.Reads + 2;
        _people.OnRead = read => { if (read == confirmRead) _people.Source = _people.Source with { Revision = 2 }; };
        var confirmed = await Handler().Handle(confirm, default);
        Assert.True(confirmed.IsSuccess); Assert.Equal("stale", confirmed.Value.Status);
        _people.OnRead = null; _people.Source = _people.Source with { Revision = 1 };
        Guid recommendation = Guid.Empty;
        Guid plan = Guid.Empty;
        NutritionWriteCommand? savedRequest = null;
        foreach (var operation in new[] { "recommend", "replace", "save" })
        {
            var request = Request(operation, recommendation, assessment);
            if (operation == "replace")
            {
                var options = await new ReplacementOptionsQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features())
                    .Handle(new(request.BeneficiaryId, recommendation, "lunch"), default);
                request = request with { Input = request.Input with { RecipeVersionId = options.Value[0].VersionId, MealType = "lunch" } };
            }
            var afterCommit = _people.Reads + (operation == "recommend" ? 4 : 2);
            _people.OnRead = read => { if (read == afterCommit) _people.Source = _people.Source with { Revision = 2 }; };
            var result = await Handler().Handle(request, default);
            Assert.True(result.IsSuccess); Assert.Equal("stale", result.Value.Status);
            Assert.Equal(1, result.Value.HealthRevision);
            var replay = await Handler().Handle(request, default);
            Assert.True(replay.IsSuccess); Assert.Equal(result.Value.Id, replay.Value.Id);
            Assert.Equal("stale", replay.Value.Status); Assert.Equal(1, replay.Value.HealthRevision);
            var different = request with { Input = request.Input with { ExpectedHealthRevision = 2 } };
            Assert.Equal("nutrition.idempotency_conflict", (await Handler().Handle(different, default)).Error.Code);
            if (operation == "save") { plan = result.Value.Id; savedRequest = request; }
            if (operation == "recommend")
            {
                recommendation = result.Value.Id;
                // Revalidate a replay again after its preparation transaction.
                _people.Source = _people.Source with { Revision = 1 };
                var afterReplay = _people.Reads + 2;
                _people.OnRead = read => { if (read == afterReplay) _people.Source = _people.Source with { Revision = 2 }; };
                Assert.Equal("stale", (await Handler().Handle(request, default)).Value.Status);
            }
            _people.OnRead = null; _people.Source = _people.Source with { Revision = 1 };
        }
        foreach (var transfer in new[] { false, true })
        {
            _people.Deleted = !transfer;
            _people.Owner = transfer ? Guid.NewGuid() : _owner;
            Assert.Equal("nutrition.profile_not_found", (await ReadAsync("assessment", assessment)).Error.Code);
            Assert.Equal("nutrition.profile_not_found", (await ReadAsync("recommendation", recommendation)).Error.Code);
            Assert.Equal("nutrition.profile_not_found", (await ReadAsync("plan", plan)).Error.Code);
            Assert.Equal("nutrition.profile_not_found", (await Handler().Handle(savedRequest!, default)).Error.Code);
            var queries = new NutritionResourceQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features());
            Assert.Equal("nutrition.profile_not_found", (await queries.Handle(new ListMealPlansQuery(_people.Source.BeneficiaryId), default)).Error.Code);
            var options = new ReplacementOptionsQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features());
            Assert.Equal("nutrition.profile_not_found", (await options.Handle(new(_people.Source.BeneficiaryId, recommendation, "lunch"), default)).Error.Code);
        }
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
        await RegisterRawCatalogFixtureAsync();
        var id = await AssessAsync(); await ProcessAsync(); await Handler().Handle(Request("confirm", id), default);
        var recommendationRequest = Request("recommend", assessment: id);
        var plannedDate = new DateOnly(2027, 1, 3);
        recommendationRequest = recommendationRequest with { Input = recommendationRequest.Input with { PlannedDate = plannedDate } };
        var recommendation = await Handler().Handle(recommendationRequest, default); Assert.Equal("suggested", recommendation.Value.Status);
        Assert.Equal("2027-01-03", recommendation.Value.Data.GetProperty("plannedDate").GetString());
        var saved = await Handler().Handle(Request("save", recommendation.Value.Id), default); Assert.Equal("saved", saved.Value.Status);
        Assert.Equal("2027-01-03", saved.Value.Data.GetProperty("plannedDate").GetString());
        await SqlAsync("""
            INSERT INTO nutrition.meal_plans(id,customer_id,beneficiary_id,health_revision,status,payload,idempotency_key,fingerprint,created_at)
            SELECT gen_random_uuid(), customer_id, beneficiary_id, health_revision, status,
                jsonb_set(payload, '{plannedDate}', to_jsonb(to_char(date '2027-02-01' + n, 'YYYY-MM-DD'))),
                gen_random_uuid(), fingerprint, created_at + interval '1 minute'
            FROM nutrition.meal_plans CROSS JOIN generate_series(0, 20) AS newer(n)
            WHERE payload->>'plannedDate' = '2027-01-03'
            """);
        var queries = new NutritionResourceQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features());
        var recent = await queries.Handle(new ListMealPlansQuery(recommendationRequest.BeneficiaryId), default);
        Assert.DoesNotContain(recent.Value, plan => plan.Id == saved.Value.Id);
        var week = await queries.Handle(new ListMealPlansQuery(recommendationRequest.BeneficiaryId, plannedDate), default);
        Assert.Equal(saved.Value.Id, Assert.Single(week.Value).Id);

        var weeklySave = Request("save", recommendation.Value.Id);
        weeklySave = weeklySave with { Input = weeklySave.Input with { PlannedDate = plannedDate } };
        Assert.Equal("nutrition.plan_date_occupied", (await Handler().Handle(weeklySave, default)).Error.Code);
        var nextDayRequest = Request("recommend", assessment: id);
        nextDayRequest = nextDayRequest with { Input = nextDayRequest.Input with { PlannedDate = plannedDate.AddDays(1) } };
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(8));
        var delayedRanking = new PausedRecommendationEngine();
        var recommendationHandler = new RecommendMealsCommandHandler(
            new NutritionWriteScope(_people, _store, new Actor(_owner, "CUSTOMER"), new Features()),
            new MealPreparationService(), delayedRanking);
        var pending = recommendationHandler.Handle((RecommendMealsCommand)nextDayRequest, deadline.Token);
        await delayedRanking.Entered.Task.WaitAsync(deadline.Token);
        try
        {
            using var readDeadline = new CancellationTokenSource(TimeSpan.FromSeconds(3));
            var whileRanking = await queries.Handle(new ListMealPlansQuery(recommendationRequest.BeneficiaryId, plannedDate),
                readDeadline.Token);
            Assert.Equal(saved.Value.Id, Assert.Single(whileRanking.Value).Id);
        }
        finally
        {
            delayedRanking.Resume.TrySetResult();
            await pending;
        }
        var nextDay = await pending;
        Assert.Equal("suggested", nextDay.Value.Status);
        Assert.NotEqual(recommendation.Value.Id, nextDay.Value.Id);
        Assert.Equal("2027-01-04", nextDay.Value.Data.GetProperty("plannedDate").GetString());
        await SqlAsync("UPDATE nutrition.recipe_versions SET status='retired'");
        Assert.Equal("stale", (await Handler().Handle(recommendationRequest, default)).Value.Status);
        Assert.Equal("stale", (await ReadAsync("plan", saved.Value.Id)).Value.Status);
        Assert.Equal("nutrition.content_changed", (await Handler().Handle(Request("save", recommendation.Value.Id), default)).Error.Code);
    }
    [PostgresFact]
    public async Task Catalog_roles_enforce_import_review_publish_retire_and_runtime_can_recommend()
    {
        var bundle = ReleaseFixture();
        var packageId = Guid.NewGuid();
        var invalidBundle = bundle with { SupportedScopes = [bundle.SupportedScopes[0] with { BlockedSpecialNeeds = [] }] };
        var boundary = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_importerConnection,
            "SELECT nutrition.import_catalog_bundle(@id,@key,@payload::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", Guid.NewGuid());
                command.Parameters.AddWithValue("key", invalidBundle.PackageKey);
                command.Parameters.AddWithValue("payload", NutritionJson.Write(invalidBundle));
            }));
        Assert.Equal("22023", boundary.SqlState);
        await using (var importer = new NpgsqlConnection(_importerConnection))
        {
            await importer.OpenAsync();
            await using var forbidden = new NpgsqlCommand("INSERT INTO nutrition.recipe_versions(id,recipe_id,version,status,payload) VALUES(gen_random_uuid(),gen_random_uuid(),1,'draft','{}')", importer);
            var permission = await Assert.ThrowsAsync<PostgresException>(() => forbidden.ExecuteNonQueryAsync());
            Assert.Equal("42501", permission.SqlState);
        }
        var imported = await CatalogFunctionAsync(_importerConnection, "SELECT nutrition.import_catalog_bundle(@id,@key,@payload::jsonb)", command =>
        {
            command.Parameters.AddWithValue("id", packageId);
            command.Parameters.AddWithValue("key", bundle.PackageKey);
            command.Parameters.AddWithValue("payload", NutritionJson.Write(bundle));
        });
        var digest = imported.GetProperty("digest").GetString()!;
        Assert.Equal("draft", imported.GetProperty("status").GetString());

        var digestMismatch = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_reviewerConnection,
            "SELECT nutrition.review_catalog_bundle(@id,@digest)", command =>
            {
                command.Parameters.AddWithValue("id", packageId); command.Parameters.AddWithValue("digest", new string('0', 64));
            }));
        Assert.Equal("40001", digestMismatch.SqlState);

        var missingEvidence = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_reviewerConnection,
            "SELECT nutrition.review_catalog_bundle(@id,@digest)", command =>
            {
                command.Parameters.AddWithValue("id", packageId); command.Parameters.AddWithValue("digest", digest);
            }));
        Assert.Equal("55000", missingEvidence.SqlState);
        var altered = bundle with { PackageKey = bundle.PackageKey + "-altered" };
        var alteredBundle = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_reviewerConnection,
            "SELECT nutrition.record_catalog_release_evidence(@id,@digest,@bundle::jsonb,@evidence::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", packageId);
                command.Parameters.AddWithValue("digest", digest);
                command.Parameters.AddWithValue("bundle", NutritionJson.Write(altered));
                command.Parameters.AddWithValue("evidence", "{}");
            }));
        Assert.Equal("40001", alteredBundle.SqlState);
        var missingKnowledgeReview = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_reviewerConnection,
            "SELECT nutrition.record_catalog_release_evidence(@id,@digest,@bundle::jsonb,@evidence::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", packageId);
                command.Parameters.AddWithValue("digest", digest);
                command.Parameters.AddWithValue("bundle", NutritionJson.Write(bundle));
                command.Parameters.AddWithValue("evidence", FixtureEvidenceJson(bundle, includeKnowledgeReview: false));
            }));
        Assert.Equal("22023", missingKnowledgeReview.SqlState);
        await RecordFixtureEvidenceAsync(bundle, packageId, digest);

        var reviewed = await CatalogFunctionAsync(_reviewerConnection, "SELECT nutrition.review_catalog_bundle(@id,@digest)", command =>
        {
            command.Parameters.AddWithValue("id", packageId); command.Parameters.AddWithValue("digest", digest);
        });
        Assert.Equal("reviewed", reviewed.GetProperty("status").GetString());

        await SqlAsync($"UPDATE nutrition.catalog_release_evidence SET evidence=jsonb_set(evidence,'{{contentStatus}}','\"technical_draft\"') WHERE package_id='{packageId}'");
        var modifiedEvidence = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_publisherConnection,
            "SELECT nutrition.publish_catalog_bundle(@id,@digest)", command =>
            {
                command.Parameters.AddWithValue("id", packageId); command.Parameters.AddWithValue("digest", digest);
            }));
        Assert.Equal("55000", modifiedEvidence.SqlState);
        await SqlAsync($"UPDATE nutrition.catalog_release_evidence SET evidence=jsonb_set(evidence,'{{contentStatus}}','\"review_ready\"') WHERE package_id='{packageId}'");

        var published = await CatalogFunctionAsync(_publisherConnection, "SELECT nutrition.publish_catalog_bundle(@id,@digest)", command =>
        {
            command.Parameters.AddWithValue("id", packageId); command.Parameters.AddWithValue("digest", digest);
        });
        Assert.Equal("published", published.GetProperty("status").GetString());
        await using (var runtime = await _dataSource.OpenConnectionAsync())
        {
            await using var count = new NpgsqlCommand("SELECT count(*)::int FROM nutrition.recipe_versions WHERE status='published'", runtime);
            Assert.Equal(12, await count.ExecuteScalarAsync());
            await using var sourceCount = new NpgsqlCommand("SELECT count(*)::int FROM nutrition.recipe_source_citations", runtime);
            Assert.Equal(12, await sourceCount.ExecuteScalarAsync());
            await using var writeSource = new NpgsqlCommand("DELETE FROM nutrition.recipe_source_citations", runtime);
            var sourcePermission = await Assert.ThrowsAsync<PostgresException>(() => writeSource.ExecuteNonQueryAsync());
            Assert.Equal("42501", sourcePermission.SqlState);
            await using var forbidden = new NpgsqlCommand("SELECT nutrition.publish_catalog_bundle(@id,@digest)", runtime);
            forbidden.Parameters.AddWithValue("id", packageId); forbidden.Parameters.AddWithValue("digest", digest);
            var permission = await Assert.ThrowsAsync<PostgresException>(() => forbidden.ExecuteScalarAsync());
            Assert.Equal("42501", permission.SqlState);
        }

        var assessment = await AssessAsync(); await ProcessAsync(); await Handler().Handle(Request("confirm", assessment), default);
        var recommendation = await Handler().Handle(Request("recommend", assessment: assessment), default);
        Assert.Equal("suggested", recommendation.Value.Status);
        Assert.Equal(3, recommendation.Value.Data.GetProperty("meals").GetArrayLength());
        var source = recommendation.Value.Data.GetProperty("meals")[0].GetProperty("sourceDetails")[0];
        Assert.Equal("Dinh dưỡng lâm sàng", source.GetProperty("title").GetString());
        Assert.Equal("Viện Dinh dưỡng", source.GetProperty("organization").GetString());
        Assert.False(source.TryGetProperty("fileSha256", out _));

        await using (var db = new NpgsqlConnection(_database))
        {
            await db.OpenAsync();
            await using var audit = new NpgsqlCommand("SELECT string_agg(actor||':'||action,',' ORDER BY id) FROM nutrition.catalog_audit WHERE package_id=@id", db);
            audit.Parameters.AddWithValue("id", packageId);
            Assert.Equal($"{_importerRole}:imported,{_reviewerRole}:reviewed,{_publisherRole}:published", await audit.ExecuteScalarAsync());
            await using var immutable = new NpgsqlCommand("UPDATE nutrition.recipe_versions SET payload='{}' WHERE status='published'", db);
            var rejected = await Assert.ThrowsAsync<PostgresException>(() => immutable.ExecuteNonQueryAsync());
            Assert.Equal("55000", rejected.SqlState);
        }

        var retired = await CatalogFunctionAsync(_publisherConnection, "SELECT nutrition.retire_catalog_bundle(@id,@reason)", command =>
        {
            command.Parameters.AddWithValue("id", packageId); command.Parameters.AddWithValue("reason", "Fixture completed");
        });
        Assert.Equal("retired", retired.GetProperty("status").GetString());
        await using var final = await _dataSource.OpenConnectionAsync();
        await using var remaining = new NpgsqlCommand("SELECT count(*)::int FROM nutrition.recipe_versions WHERE status='published'", final);
        Assert.Equal(0, await remaining.ExecuteScalarAsync());
    }
    [PostgresFact]
    public async Task Baseline_release_without_disease_rules_can_be_reviewed_and_published()
    {
        var source = ReleaseFixture();
        var bundle = source with
        {
            PackageKey = "baseline-test-only",
            Rules = [],
            SupportedScopes = [source.SupportedScopes[0] with { ConditionCodes = [] }]
        };
        var packageId = Guid.NewGuid();
        var imported = await CatalogFunctionAsync(_importerConnection,
            "SELECT nutrition.import_catalog_bundle(@id,@key,@payload::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", packageId);
                command.Parameters.AddWithValue("key", bundle.PackageKey);
                command.Parameters.AddWithValue("payload", NutritionJson.Write(bundle));
            });
        var digest = imported.GetProperty("digest").GetString()!;
        await RecordFixtureEvidenceAsync(bundle, packageId, digest);
        await CatalogFunctionAsync(_reviewerConnection, "SELECT nutrition.review_catalog_bundle(@id,@digest)", command =>
        {
            command.Parameters.AddWithValue("id", packageId); command.Parameters.AddWithValue("digest", digest);
        });
        var published = await CatalogFunctionAsync(_publisherConnection, "SELECT nutrition.publish_catalog_bundle(@id,@digest)", command =>
        {
            command.Parameters.AddWithValue("id", packageId); command.Parameters.AddWithValue("digest", digest);
        });
        Assert.Equal("published", published.GetProperty("status").GetString());
        await using var runtime = await _dataSource.OpenConnectionAsync();
        await using var count = new NpgsqlCommand("SELECT count(*)::int FROM nutrition.rule_versions WHERE status='published'", runtime);
        Assert.Equal(0, await count.ExecuteScalarAsync());
    }
    [PostgresFact]
    public async Task Published_source_reference_baseline_can_use_product_owner_authorization()
    {
        var source = ReleaseFixture();
        var bundle = source with
        {
            PackageKey = "baseline-source-reference-test-only",
            Rules = [],
            SupportedScopes = [source.SupportedScopes[0] with { ConditionCodes = [] }]
        };
        var packageId = Guid.NewGuid();
        var imported = await CatalogFunctionAsync(_importerConnection,
            "SELECT nutrition.import_catalog_bundle(@id,@key,@payload::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", packageId);
                command.Parameters.AddWithValue("key", bundle.PackageKey);
                command.Parameters.AddWithValue("payload", NutritionJson.Write(bundle));
            });
        var digest = imported.GetProperty("digest").GetString()!;
        var evidence = SourceReferenceEvidenceJson(bundle);
        await CatalogFunctionAsync(_reviewerConnection,
            "SELECT nutrition.record_catalog_release_evidence(@id,@digest,@bundle::jsonb,@evidence::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", packageId);
                command.Parameters.AddWithValue("digest", digest);
                command.Parameters.AddWithValue("bundle", NutritionJson.Write(bundle));
                command.Parameters.AddWithValue("evidence", evidence);
            });
        await CatalogFunctionAsync(_reviewerConnection,
            "SELECT nutrition.review_catalog_bundle(@id,@digest)", command =>
            {
                command.Parameters.AddWithValue("id", packageId);
                command.Parameters.AddWithValue("digest", digest);
            });
        var published = await CatalogFunctionAsync(_publisherConnection,
            "SELECT nutrition.publish_catalog_bundle(@id,@digest)", command =>
            {
                command.Parameters.AddWithValue("id", packageId);
                command.Parameters.AddWithValue("digest", digest);
            });
        Assert.Equal("published", published.GetProperty("status").GetString());
    }
    [PostgresFact]
    public async Task Non_medical_reference_catalog_requires_database_policy_and_data_steward_reviews()
    {
        // Synthetic data-steward fixture only. No clinical approval is created or implied.
        var bundle = NonMedicalBaseline(ReleaseFixture());
        var packageId = Guid.NewGuid();
        var imported = await CatalogFunctionAsync(_importerConnection,
            "SELECT nutrition.import_catalog_bundle(@id,@key,@payload::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", packageId);
                command.Parameters.AddWithValue("key", bundle.PackageKey);
                command.Parameters.AddWithValue("payload", NutritionJson.Write(bundle));
            });
        var digest = imported.GetProperty("digest").GetString()!;
        Task Record(string evidence) => CatalogFunctionAsync(_reviewerConnection,
            "SELECT nutrition.record_catalog_release_evidence(@id,@digest,@bundle::jsonb,@evidence::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", packageId);
                command.Parameters.AddWithValue("digest", digest);
                command.Parameters.AddWithValue("bundle", NutritionJson.Write(bundle));
                command.Parameters.AddWithValue("evidence", evidence);
            });
        Task Transition(string connection, string function) => CatalogFunctionAsync(connection,
            $"SELECT nutrition.{function}(@id,@digest)", command =>
            {
                command.Parameters.AddWithValue("id", packageId);
                command.Parameters.AddWithValue("digest", digest);
            });

        var valid = NonMedicalEvidenceJson(bundle);
        var defaultPolicy = await Assert.ThrowsAsync<PostgresException>(() => Record(valid));
        Assert.Equal("22023", defaultPolicy.SqlState);

        await Assert.ThrowsAsync<PostgresException>(() => OwnerSqlAsync("SELECT nutrition.set_catalog_review_policy('non_medical_reference','')"));
        await Assert.ThrowsAsync<PostgresException>(() => OwnerSqlAsync("UPDATE nutrition.catalog_review_policy SET review_policy='non_medical_reference'"));
        await Assert.ThrowsAsync<PostgresException>(() => OwnerSqlAsync("DELETE FROM nutrition.catalog_review_policy"));
        await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_reviewerConnection,
            "SELECT to_jsonb(nutrition.set_catalog_review_policy('non_medical_reference','reviewer cannot opt in'))", _ => { }));
        await OwnerSqlAsync("SELECT nutrition.set_catalog_review_policy('non_medical_reference','academic reference test')");
        Assert.Equal("non_medical_reference", await OwnerScalarAsync("SELECT nutrition.current_catalog_review_policy()"));
        Assert.Equal(1, await OwnerScalarAsync("SELECT count(*)::int FROM nutrition.catalog_review_policy_audit WHERE new_policy='non_medical_reference'"));

        var clinical = JsonNode.Parse(valid)!.AsObject();
        clinical["clinicalReview"] = new JsonObject { ["reviewerId"] = "x", ["decision"] = "approved" };
        Assert.Equal("22023", (await Assert.ThrowsAsync<PostgresException>(() => Record(clinical.ToJsonString()))).SqlState);
        var missingReview = JsonNode.Parse(valid)!.AsObject();
        missingReview["recipes"]![0]!.AsObject().Remove("dataReview");
        Assert.Equal("22023", (await Assert.ThrowsAsync<PostgresException>(() => Record(missingReview.ToJsonString()))).SqlState);
        var dietitian = JsonNode.Parse(valid)!.AsObject();
        dietitian["recipes"]![0]!["dataReview"]!["reviewerRole"] = "dietitian";
        Assert.Equal("22023", (await Assert.ThrowsAsync<PostgresException>(() => Record(dietitian.ToJsonString()))).SqlState);
        var unboundReviewer = JsonNode.Parse(valid)!.AsObject();
        unboundReviewer["knowledgeReview"]!["dataReviewerIds"] = new JsonArray("someone-else");
        Assert.Equal("22023", (await Assert.ThrowsAsync<PostgresException>(() => Record(unboundReviewer.ToJsonString()))).SqlState);

        await Record(valid);
        Assert.Equal("non_medical_reference", await OwnerScalarAsync($"SELECT review_policy FROM nutrition.catalog_packages WHERE id='{packageId}'"));
        await OwnerSqlAsync("SELECT nutrition.set_catalog_review_policy('source_and_clinical','switch back during test')");
        await Assert.ThrowsAsync<PostgresException>(() => Transition(_reviewerConnection, "review_catalog_bundle"));
        await OwnerSqlAsync("SELECT nutrition.set_catalog_review_policy('non_medical_reference','academic reference test')");
        await Transition(_reviewerConnection, "review_catalog_bundle");
        await Transition(_publisherConnection, "publish_catalog_bundle");
        Assert.Equal(new[] { "non_medical_reference" }, (string[])(await OwnerScalarAsync("SELECT nutrition.published_catalog_review_policies()"))!);
    }
    private async Task OwnerSqlAsync(string sql)
    {
        await using var db = new NpgsqlConnection(_database); await db.OpenAsync();
        await using var command = new NpgsqlCommand(sql, db); await command.ExecuteNonQueryAsync();
    }
    private async Task<object?> OwnerScalarAsync(string sql)
    {
        await using var db = new NpgsqlConnection(_database); await db.OpenAsync();
        await using var command = new NpgsqlCommand(sql, db); return await command.ExecuteScalarAsync();
    }
    private static CatalogBundle NonMedicalBaseline(CatalogBundle source) => source with
    {
        PackageKey = "baseline-non-medical-reference-test-only",
        Rules = [],
        SupportedScopes = [source.SupportedScopes[0] with { ConditionCodes = [] }],
        ReviewPolicy = CatalogReleaseValidator.NonMedicalReferencePolicy,
        IntendedUse = "academic_reference_non_medical",
        ClinicalReviewPerformed = false,
        IndependentClinicalReview = false,
        ProductionPublicRelease = false,
        ClinicalReviewNotPerformedReason = "no_clinical_reviewer_non_medical_reference",
        Recipes = source.Recipes.Select(recipe => recipe with
        {
            Payload = recipe.Payload with
            {
                ReviewPolicy = CatalogReleaseValidator.NonMedicalReferencePolicy,
                IntendedUse = "academic_reference_non_medical",
                ClinicalReviewPerformed = false,
                IndependentClinicalReview = false,
                ProductionPublicRelease = false,
                ClinicalReviewNotPerformedReason = "no_clinical_reviewer_non_medical_reference"
            }
        }).ToArray()
    };
    private static void AddNonMedicalMetadata(JsonObject target)
    {
        target["review_policy"] = CatalogReleaseValidator.NonMedicalReferencePolicy;
        target["intended_use"] = "academic_reference_non_medical";
        target["clinical_review_performed"] = false;
        target["independent_clinical_review"] = false;
        target["production_public_release"] = false;
        target["clinical_review_not_performed_reason"] = "no_clinical_reviewer_non_medical_reference";
    }
    private static string NonMedicalEvidenceJson(CatalogBundle bundle)
    {
        const string reviewerId = "synthetic-data-steward";
        var evidence = JsonNode.Parse(FixtureEvidenceJson(bundle, includeKnowledgeReview: true))!.AsObject();
        AddNonMedicalMetadata(evidence);
        evidence["clinicalReview"] = null;
        foreach (var recipe in evidence["recipes"]!.AsArray())
            recipe!["dataReview"] = new JsonObject
            {
                ["decision"] = "approved",
                ["reviewerRole"] = CatalogReleaseValidator.DataStewardRole,
                ["reviewerId"] = reviewerId,
                ["reviewedAt"] = "2026-11-10T08:00:00+07:00"
            };
        var knowledgeReview = evidence["knowledgeReview"]!.AsObject();
        AddNonMedicalMetadata(knowledgeReview);
        knowledgeReview["clinicalReviewerIds"] = new JsonArray();
        knowledgeReview["dataReviewerIds"] = new JsonArray(reviewerId);
        return evidence.ToJsonString();
    }
    [PostgresFact]
    public async Task Catalog_v2_constraint_ranges_are_checked_at_database_boundary()
    {
        var source = CatalogBundleTests.Bundle();
        var rule = source.Rules[0];
        var valid = source with
        {
            SchemaVersion = 2,
            PackageKey = "adult-constraint-v2",
            Rules = [rule with
            {
                Payload = rule.Payload with
                {
                    NutrientConstraints = [new("sodium_mg", "daily", null, 20, 100)]
                }
            }]
        };
        var imported = await CatalogFunctionAsync(_importerConnection,
            "SELECT nutrition.import_catalog_bundle(@id,@key,@payload::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", Guid.NewGuid());
                command.Parameters.AddWithValue("key", valid.PackageKey);
                command.Parameters.AddWithValue("payload", NutritionJson.Write(valid));
            });
        Assert.Equal("draft", imported.GetProperty("status").GetString());

        var invalidRule = valid.Rules[0] with
        {
            Payload = valid.Rules[0].Payload with
            {
                NutrientConstraints = [new("sodium_mg", "daily", null, 101, 100)]
            }
        };
        var invalid = valid with { PackageKey = "adult-invalid-constraint-v2", Rules = [invalidRule] };
        var rejected = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_importerConnection,
            "SELECT nutrition.import_catalog_bundle(@id,@key,@payload::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", Guid.NewGuid());
                command.Parameters.AddWithValue("key", invalid.PackageKey);
                command.Parameters.AddWithValue("payload", NutritionJson.Write(invalid));
            }));
        Assert.Equal("22023", rejected.SqlState);

        var missingNutrientRule = valid.Rules[0] with
        {
            Payload = valid.Rules[0].Payload with
            {
                NutrientConstraints = [new("calcium_mg", "daily", null, 1, null)]
            }
        };
        var missingNutrient = valid with { PackageKey = "adult-missing-nutrient-v2", Rules = [missingNutrientRule] };
        var missingRejected = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_importerConnection,
            "SELECT nutrition.import_catalog_bundle(@id,@key,@payload::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", Guid.NewGuid());
                command.Parameters.AddWithValue("key", missingNutrient.PackageKey);
                command.Parameters.AddWithValue("payload", NutritionJson.Write(missingNutrient));
            }));
        Assert.Equal("22023", missingRejected.SqlState);
    }
    [PostgresFact]
    public async Task P2_technical_bundle_cannot_cross_review_gate()
    {
        var path = Path.Combine(ServiceArchitectureTests.FindRoot(), "catalog", "drafts", "adult-hypertension-p2.bundle.json");
        var bundle = NutritionJson.Read<CatalogBundle>(await File.ReadAllTextAsync(path));
        Assert.True(CatalogBundleValidator.Validate(bundle).IsValid);
        var packageId = Guid.NewGuid();
        var imported = await CatalogFunctionAsync(_importerConnection, "SELECT nutrition.import_catalog_bundle(@id,@key,@payload::jsonb)", command =>
        {
            command.Parameters.AddWithValue("id", packageId);
            command.Parameters.AddWithValue("key", bundle.PackageKey);
            command.Parameters.AddWithValue("payload", NutritionJson.Write(bundle));
        });
        var digest = imported.GetProperty("digest").GetString()!;
        var sidecarPath = path.Replace(".bundle.json", ".evidence.json", StringComparison.Ordinal);
        var sidecar = await File.ReadAllTextAsync(sidecarPath);
        var draftRejected = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_reviewerConnection,
            "SELECT nutrition.record_catalog_release_evidence(@id,@digest,@bundle::jsonb,@evidence::jsonb)", command =>
        {
            command.Parameters.AddWithValue("id", packageId);
            command.Parameters.AddWithValue("digest", digest);
            command.Parameters.AddWithValue("bundle", NutritionJson.Write(bundle));
            command.Parameters.AddWithValue("evidence", sidecar);
        }));
        Assert.Equal("22023", draftRejected.SqlState);
        var reviewRejected = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_reviewerConnection,
            "SELECT nutrition.review_catalog_bundle(@id,@digest)", command =>
        {
            command.Parameters.AddWithValue("id", packageId);
            command.Parameters.AddWithValue("digest", digest);
        }));
        Assert.Equal("55000", reviewRejected.SqlState);
    }
    [PostgresFact]
    public async Task Concurrent_catalog_imports_receive_distinct_monotonic_versions()
    {
        var bundle = CatalogBundleTests.Bundle();
        async Task<JsonElement> ImportAsync() => await CatalogFunctionAsync(_importerConnection,
            "SELECT nutrition.import_catalog_bundle(@id,@key,@payload::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", Guid.NewGuid());
                command.Parameters.AddWithValue("key", bundle.PackageKey);
                command.Parameters.AddWithValue("payload", NutritionJson.Write(bundle));
            });
        var imported = await Task.WhenAll(ImportAsync(), ImportAsync());
        Assert.Equal([1, 2], imported.Select(x => x.GetProperty("version").GetInt32()).Order().ToArray());
        await using var db = new NpgsqlConnection(_database); await db.OpenAsync();
        await using var command = new NpgsqlCommand("SELECT count(*)::int FROM nutrition.catalog_packages WHERE package_key=@key", db);
        command.Parameters.AddWithValue("key", bundle.PackageKey);
        Assert.Equal(2, await command.ExecuteScalarAsync());
    }
    private static async Task<JsonElement> CatalogFunctionAsync(string connectionString, string sql, Action<NpgsqlCommand> configure)
    {
        await using var connection = new NpgsqlConnection(connectionString); await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection); configure(command);
        return JsonDocument.Parse((string)(await command.ExecuteScalarAsync())!).RootElement.Clone();
    }
    private static CatalogBundle ReleaseFixture()
    {
        var source = CatalogBundleTests.Bundle();
        var recipes = source.Recipes.SelectMany(recipe => Enumerable.Range(0, 4).Select(index => recipe with
        {
            RecipeId = index == 0 ? recipe.RecipeId : Guid.NewGuid(),
            Payload = recipe.Payload with
            {
                VersionId = index == 0 ? recipe.Payload.VersionId : Guid.NewGuid(),
                Name = recipe.Payload.Name + $" {index + 1}",
                Nutrients = new Dictionary<string, decimal?>
                {
                    ["energy_kcal"] = 200,
                    ["protein_g"] = 5,
                    ["carbohydrate_g"] = 20,
                    ["fat_g"] = 5,
                    ["fiber_g"] = 2,
                    ["sodium_mg"] = 10
                }
            }
        })).ToArray();
        return source with { Recipes = recipes };
    }
    private static string FixtureEvidenceJson(CatalogBundle bundle, bool includeKnowledgeReview)
    {
        object? knowledgeReview = includeKnowledgeReview ? new
        {
            schemaVersion = 1,
            candidateGraphSha256 = new string('b', 64),
            decisionLedgerSha256 = new string('c', 64),
            reviewedGraphSha256 = new string('d', 64),
            candidateCount = 20,
            approvedCount = 20,
            pendingCount = 0,
            rejectedCount = 0,
            sources = new[] { new { sourceRevisionId = "synthetic-source@1", rightsStatus = "permitted" } },
            clinicalReviewerIds = new[] { "synthetic-clinical-reviewer" },
            decision = "approved"
        } : null;
        var evidence = new
        {
            schemaVersion = 1,
            packageKey = bundle.PackageKey,
            bundleFileSha256 = new string('a', 64),
            contentStatus = "review_ready",
            releaseProfile = bundle.Rules.Length == 0 ? "adult_baseline_v1" : "adult_condition_v1",
            requiredNutrients = new[] { "energy_kcal", "protein_g", "carbohydrate_g", "fat_g", "fiber_g", "sodium_mg" },
            recipes = bundle.Recipes.Select(recipe => new
            {
                recipeVersionId = recipe.Payload.VersionId,
                ingredients = recipe.Payload.Ingredients,
                nutrients = recipe.Payload.Nutrients.Select(pair => new { key = pair.Key, value = pair.Value }),
                unresolvedItems = Array.Empty<string>()
            }),
            rules = bundle.Rules.Select(rule => new
            {
                ruleVersionId = rule.Payload.VersionId,
                sourceIds = rule.Payload.Sources,
                sourceLocator = "Synthetic test fixture",
                unresolvedItems = Array.Empty<string>()
            }),
            clinicalReview = new
            {
                reviewerName = "Synthetic test reviewer",
                credentials = "Automated test fixture only",
                reviewedAt = DateTimeOffset.UtcNow,
                decision = "approved",
                reviewerId = "synthetic-clinical-reviewer"
            },
            knowledgeReview
        };
        using var document = JsonDocument.Parse(JsonSerializer.Serialize(evidence));
        if (includeKnowledgeReview)
            return document.RootElement.GetRawText();
        var withoutKnowledgeReview = document.RootElement.EnumerateObject()
            .Where(property => property.Name != "knowledgeReview")
            .ToDictionary(property => property.Name, property => property.Value.Clone());
        return JsonSerializer.Serialize(withoutKnowledgeReview);
    }
    private static string SourceReferenceEvidenceJson(CatalogBundle bundle)
    {
        const string authorityId = "product-owner-release-2026-10-24";
        var evidence = JsonNode.Parse(FixtureEvidenceJson(bundle, includeKnowledgeReview: true))!.AsObject();
        evidence["releaseProfile"] = CatalogReleaseValidator.SourceReferenceReleaseProfile;
        evidence["clinicalReview"] = null;
        evidence["sourcePublication"] = new JsonObject
        {
            ["sourceId"] = "VIEN_DINH_DUONG_2019",
            ["sourceRevisionId"] = "VIEN_DINH_DUONG_2019@sha256:abea34b8",
            ["documentSha256"] = "ABEA34B8A6A63E9EABD25F57141C18BA6AC31012C1D4A8DCC15F9BA68DC7F737",
            ["organization"] = "Viện Dinh dưỡng",
            ["publicationYear"] = 2019,
            ["verifiedAt"] = "2026-10-24T08:00:00+07:00",
            ["decision"] = "verified"
        };
        evidence["releaseAuthorization"] = new JsonObject
        {
            ["authorizationId"] = authorityId,
            ["authorityType"] = "product_owner",
            ["authorizedBy"] = "project-owner",
            ["authorizedAt"] = "2026-10-24T08:05:00+07:00",
            ["decision"] = "approved",
            ["notes"] = "Published-source reference release for adult baseline only."
        };
        var knowledgeReview = evidence["knowledgeReview"]!.AsObject();
        knowledgeReview["clinicalReviewerIds"] = new JsonArray();
        knowledgeReview["releaseAuthorityIds"] = new JsonArray(authorityId);
        return evidence.ToJsonString();
    }
    private async Task RecordFixtureEvidenceAsync(CatalogBundle bundle, Guid packageId, string digest)
    {
        await CatalogFunctionAsync(_reviewerConnection,
            "SELECT nutrition.record_catalog_release_evidence(@id,@digest,@bundle::jsonb,@evidence::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", packageId);
                command.Parameters.AddWithValue("digest", digest);
                command.Parameters.AddWithValue("bundle", NutritionJson.Write(bundle));
                command.Parameters.AddWithValue("evidence", FixtureEvidenceJson(bundle, includeKnowledgeReview: true));
            });
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
            HealthHistory = EligibilityTests.History(conditionsStatus: "reported_present")
        };
        await RegisterRawCatalogFixtureAsync();
        var id = await AssessAsync(); await ProcessAsync(); await Handler().Handle(Request("confirm", id), default);
        var recommended = await Handler().Handle(Request("recommend", assessment: id), default); Assert.Equal("suggested", recommended.Value.Status);
        var options = await new ReplacementOptionsQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features())
            .Handle(new(_people.Source.BeneficiaryId, recommended.Value.Id, "lunch"), default);
        Assert.True(options.IsSuccess); Assert.NotEmpty(options.Value);
        Assert.DoesNotContain(options.Value, r => r.VersionId == unsafeSalt.VersionId || r.VersionId == unsafeAllergy.VersionId);
        var rejected = await Handler().Handle(((ReplaceMealCommand)Request("replace", recommended.Value.Id)) with
        { Input = new(_people.Source.Revision, Guid.NewGuid(), RecipeVersionId: unsafeSalt.VersionId, MealType: "lunch") }, default);
        Assert.Equal("nutrition.constraint", rejected.Error.Code);
        var chosen = options.Value[0]; var replaced = await Handler().Handle(((ReplaceMealCommand)Request("replace", recommended.Value.Id)) with
        { Input = new(_people.Source.Revision, Guid.NewGuid(), RecipeVersionId: chosen.VersionId, MealType: "lunch") }, default);
        Assert.Equal("suggested", replaced.Value.Status); Assert.NotEqual(recommended.Value.Id, replaced.Value.Id);
        _people.Deleted = true;
        var history = await new NutritionResourceQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features()).Handle(new ListMealPlansQuery(_people.Source.BeneficiaryId), default);
        Assert.Equal("nutrition.profile_not_found", history.Error.Code);
    }
    private sealed class People(Guid owner, BeneficiaryHealthSnapshot source) : IPeopleHealthClient
    {
        public BeneficiaryHealthSnapshot Source = source; public bool Deleted;
        public Guid Owner = owner;
        public Action<int>? OnRead; public int Reads;
        public Task<BeneficiaryHealthSnapshot?> ReadAsync(Guid actor, Guid beneficiary, CancellationToken ct)
        {
            OnRead?.Invoke(++Reads);
            return Task.FromResult(!Deleted && actor == Owner && beneficiary == Source.BeneficiaryId ? Source : null);
        }
    }
    private sealed class Actor(Guid owner, string role) : ICurrentUser
    { public Guid? UserId => owner; public IReadOnlyList<string> Roles => [role]; }
    private sealed class Features : INutritionFeatures
    { public bool Enabled => true; public bool AssessmentsEnabled => true; public bool RecommendationsEnabled => true; }
    private sealed class CapturingParser : IHealthDescriptionParser
    {
        public bool IsReady => true;
        public string PromptVersion => "fixture-parser.v1";
        public HealthParseRequest? Request { get; private set; }

        public Task<HealthParseResult> ParseAsync(HealthParseRequest request, CancellationToken ct)
        {
            Request = request;
            var source = request.Sources["generalNote"];
            var start = source.IndexOf("tăng huyết áp", StringComparison.Ordinal);
            return Task.FromResult(new HealthParseResult(request.SchemaVersion, request.DictionaryRevision,
                [new("condition", "HYPERTENSION", "Tăng huyết áp", "present", "current", "generalNote",
                    "tăng huyết áp", "beneficiary", start, start + "tăng huyết áp".Length)], [], []));
        }
    }
    private sealed class CatalogMutatingParser(Func<Task> mutate) : IHealthDescriptionParser
    {
        public bool IsReady => true;
        public string PromptVersion => "catalog-mutating-fixture.v1";

        public async Task<HealthParseResult> ParseAsync(HealthParseRequest request, CancellationToken ct)
        {
            await mutate();
            return new(request.SchemaVersion, request.DictionaryRevision, [], [], ["generalNote"]);
        }
    }
}

internal sealed class PostgresFactAttribute : FactAttribute
{
    public PostgresFactAttribute() { if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("CARESITTER_TEST_ADMIN_CONNECTION"))) Skip = "PostgreSQL test connection not configured."; }
}
