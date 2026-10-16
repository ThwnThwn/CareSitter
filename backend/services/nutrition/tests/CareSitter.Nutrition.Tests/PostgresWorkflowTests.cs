using System.Text.Json;
using System.Text.RegularExpressions;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Catalog;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;
using Npgsql;

namespace CareSitter.Nutrition.Tests;

public sealed class PostgresWorkflowTests : IAsyncLifetime
{
    private readonly string _name = "caresitter_nutrition_" + Guid.NewGuid().ToString("N");
    private readonly string _role = "nutrition_test_" + Guid.NewGuid().ToString("N");
    private readonly string _importerRole = "nutrition_importer_test_" + Guid.NewGuid().ToString("N");
    private readonly string _reviewerRole = "nutrition_reviewer_test_" + Guid.NewGuid().ToString("N");
    private readonly string _publisherRole = "nutrition_publisher_test_" + Guid.NewGuid().ToString("N");
    private string _admin = "", _database = ""; private NpgsqlDataSource _dataSource = null!;
    private string _importerConnection = "", _reviewerConnection = "", _publisherConnection = "";
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
        var catalogPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/03-catalog-governance.sql"));
        await using (var catalog = new NpgsqlCommand(await File.ReadAllTextAsync(catalogPath), db)) await catalog.ExecuteNonQueryAsync();
        var constraintPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/04-catalog-nutrient-constraints.sql"));
        await using (var constraints = new NpgsqlCommand(await File.ReadAllTextAsync(constraintPath), db)) await constraints.ExecuteNonQueryAsync();
        var citationPath = Path.GetFullPath(Path.Combine(ServiceArchitectureTests.FindRoot(), "../../init-db/nutrition-service/05-recipe-source-citations.sql"));
        await using (var citations = new NpgsqlCommand(await File.ReadAllTextAsync(citationPath), db)) await citations.ExecuteNonQueryAsync();
        var password = Guid.NewGuid().ToString("N");
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
            GRANT SELECT,INSERT,UPDATE,DELETE ON nutrition.assessments,nutrition.assessment_jobs,nutrition.recommendations,nutrition.meal_plans,nutrition.preferences TO "{_role}";
            GRANT SELECT ON nutrition.concepts,nutrition.rule_versions,nutrition.recipe_versions,nutrition.recipe_source_citations TO "{_role}";
            GRANT SELECT,UPDATE(id) ON nutrition.catalog_state TO "{_role}";
            """, db)) await role.ExecuteNonQueryAsync();
        _dataSource = NpgsqlDataSource.Create(new NpgsqlConnectionStringBuilder(_database) { Username = _role, Password = password }.ConnectionString);
        _importerConnection = new NpgsqlConnectionStringBuilder(_database) { Username = _importerRole, Password = importerPassword }.ConnectionString;
        _reviewerConnection = new NpgsqlConnectionStringBuilder(_database) { Username = _reviewerRole, Password = reviewerPassword }.ConnectionString;
        _publisherConnection = new NpgsqlConnectionStringBuilder(_database) { Username = _publisherRole, Password = publisherPassword }.ConnectionString;
        _store = new NutritionStore(_dataSource); _people = new People(_owner, EligibilityTests.Healthy());
    }
    public async Task DisposeAsync()
    {
        if (_database.Length == 0) return;
        if (_dataSource is not null) await _dataSource.DisposeAsync();
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
                RecommendMealsCommand recommend => new RecommendMealsCommandHandler(scope, new()).Handle(recommend, ct),
                ReplaceMealCommand replace => new ReplaceMealCommandHandler(scope, new()).Handle(replace, ct),
                SaveMealPlanCommand save => new SaveMealPlanCommandHandler(scope, new()).Handle(save, ct),
                _ => throw new ArgumentException("Unknown test command.")
            };
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
    public async Task Structured_flow_confirms_and_returns_no_content_without_demo()
    {
        var id = await AssessAsync(); await ProcessAsync();
        var analyzed = await ReadAsync("assessment", id); Assert.Equal("awaiting_confirmation", analyzed.Value.Status);
        var confirmed = await Handler().Handle(Request("confirm", id), default); Assert.Equal("confirmed", confirmed.Value.Status);
        var meal = await Handler().Handle(Request("recommend", assessment: id), default); Assert.Equal("no_content", meal.Value.Status);
        Assert.Equal(0, meal.Value.Data.GetProperty("meals").GetArrayLength());
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
        Assert.Equal("nutrition.ai_unavailable", failed.Value.Data.GetProperty("errorCode").GetString());
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
    [PostgresFact]
    public async Task Catalog_roles_enforce_import_review_publish_retire_and_runtime_can_recommend()
    {
        var bundle = CatalogBundleTests.Bundle();
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

        var reviewed = await CatalogFunctionAsync(_reviewerConnection, "SELECT nutrition.review_catalog_bundle(@id,@digest)", command =>
        {
            command.Parameters.AddWithValue("id", packageId); command.Parameters.AddWithValue("digest", digest);
        });
        Assert.Equal("reviewed", reviewed.GetProperty("status").GetString());

        var published = await CatalogFunctionAsync(_publisherConnection, "SELECT nutrition.publish_catalog_bundle(@id,@digest)", command =>
        {
            command.Parameters.AddWithValue("id", packageId); command.Parameters.AddWithValue("digest", digest);
        });
        Assert.Equal("published", published.GetProperty("status").GetString());
        await using (var runtime = await _dataSource.OpenConnectionAsync())
        {
            await using var count = new NpgsqlCommand("SELECT count(*)::int FROM nutrition.recipe_versions WHERE status='published'", runtime);
            Assert.Equal(3, await count.ExecuteScalarAsync());
            await using var sourceCount = new NpgsqlCommand("SELECT count(*)::int FROM nutrition.recipe_source_citations", runtime);
            Assert.Equal(3, await sourceCount.ExecuteScalarAsync());
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
    public async Task P2_technical_bundle_runs_end_to_end_only_in_disposable_test_database()
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
        await CatalogFunctionAsync(_reviewerConnection, "SELECT nutrition.review_catalog_bundle(@id,@digest)", command =>
        {
            command.Parameters.AddWithValue("id", packageId);
            command.Parameters.AddWithValue("digest", digest);
        });
        await CatalogFunctionAsync(_publisherConnection, "SELECT nutrition.publish_catalog_bundle(@id,@digest)", command =>
        {
            command.Parameters.AddWithValue("id", packageId);
            command.Parameters.AddWithValue("digest", digest);
        });

        _people.Source = _people.Source with
        {
            ChronicConditions = JsonSerializer.SerializeToElement(new[] { "Tăng huyết áp" }),
            HealthHistory = EligibilityTests.History(conditionsStatus: "reported_present")
        };
        var assessment = await AssessAsync();
        await ProcessAsync();
        await Handler().Handle(Request("confirm", assessment), default);
        var recommendation = await Handler().Handle(Request("recommend", assessment: assessment), default);

        Assert.Equal("suggested", recommendation.Value.Status);
        var meals = recommendation.Value.Data.GetProperty("meals").EnumerateArray().ToArray();
        Assert.Equal(3, meals.Length);
        Assert.True(meals.Sum(meal => meal.GetProperty("nutrients").GetProperty("sodium_mg").GetDecimal()) <= 2000);
        Assert.All(meals, meal => Assert.Equal(2, meal.GetProperty("sourceDetails").GetArrayLength()));
        Assert.Single(recommendation.Value.Data.GetProperty("appliedRules").EnumerateArray());
        var replacements = await new ReplacementOptionsQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features())
            .Handle(new(_people.Source.BeneficiaryId, recommendation.Value.Id, "lunch"), default);
        Assert.Equal(3, replacements.Value.Count);
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
