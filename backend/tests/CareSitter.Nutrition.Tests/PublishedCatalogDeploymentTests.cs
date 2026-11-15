using System.Text.Json.Nodes;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Infrastructure;
using Npgsql;

namespace CareSitter.Nutrition.Tests;

public sealed partial class PostgresWorkflowTests
{
    [PostgresFact]
    public async Task Baseline_without_clinical_review_cannot_record_evidence_or_publish()
    {
        var source = ReleaseFixture();
        var bundle = source with
        {
            Rules = [],
            SupportedScopes = [source.SupportedScopes[0] with { ConditionCodes = [] }]
        };
        var id = Guid.NewGuid();
        var imported = await CatalogFunctionAsync(_importerConnection,
            "SELECT nutrition.import_catalog_bundle(@id,@key,@payload::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", id);
                command.Parameters.AddWithValue("key", bundle.PackageKey);
                command.Parameters.AddWithValue("payload", NutritionJson.Write(bundle));
            });
        var digest = imported.GetProperty("digest").GetString()!;
        var evidence = JsonNode.Parse(FixtureEvidenceJson(bundle, includeKnowledgeReview: true))!;
        evidence["clinicalReview"] = null;
        var rejected = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_reviewerConnection,
            "SELECT nutrition.record_catalog_release_evidence(@id,@digest,@bundle::jsonb,@evidence::jsonb)", command =>
            {
                command.Parameters.AddWithValue("id", id);
                command.Parameters.AddWithValue("digest", digest);
                command.Parameters.AddWithValue("bundle", NutritionJson.Write(bundle));
                command.Parameters.AddWithValue("evidence", evidence.ToJsonString());
            }));
        Assert.Equal("22023", rejected.SqlState);
        var publish = await Assert.ThrowsAsync<PostgresException>(() => CatalogFunctionAsync(_publisherConnection,
            "SELECT nutrition.publish_catalog_bundle(@id,@digest)", command =>
            {
                command.Parameters.AddWithValue("id", id);
                command.Parameters.AddWithValue("digest", digest);
            }));
        Assert.Equal("55000", publish.SqlState);
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var count = new NpgsqlCommand("SELECT count(*) FROM nutrition.recipe_versions WHERE status='published'", connection);
        Assert.Equal(0L, await count.ExecuteScalarAsync());
    }

    [PostgresFact]
    public async Task Deployment_preflight_rejects_empty_or_corrupt_catalog_using_runtime_role()
    {
        var root = new DirectoryInfo(AppContext.BaseDirectory);
        while (root is not null && !File.Exists(Path.Combine(root.FullName, "deploy/nutrition/check-published-catalog.sql"))) root = root.Parent;
        Assert.NotNull(root);
        var sql = await File.ReadAllTextAsync(Path.Combine(root.FullName, "deploy/nutrition/check-published-catalog.sql"));
        // Execute the exact production predicate, without psql's client-side control commands.
        var start = sql.IndexOf("SELECT nutrition.published_catalog_integrity()", StringComparison.Ordinal);
        sql = sql[start..sql.IndexOf("\\gset", start, StringComparison.Ordinal)];
        await using var connection = await _dataSource.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        Assert.Equal(false, await command.ExecuteScalarAsync()); // Integrity alone accepts an empty DB.
        await ConcurrentMealFixtureAsync();
        Assert.Equal(true, await command.ExecuteScalarAsync());
        await SqlAsync("UPDATE nutrition.catalog_packages SET payload_digest=repeat('0',64)");
        Assert.Equal(false, await command.ExecuteScalarAsync());
    }
    [PostgresFact]
    public async Task Catalog_policy_readiness_rejects_non_medical_and_malformed_metadata()
    {
        await ConcurrentMealFixtureAsync();
        Assert.Null(await MealGroundingReadiness.CatalogPolicyFailureAsync(_dataSource, false, default));
        // Intentional materialized-payload drift isolates the policy predicate. The HTTP caller
        // separately requires published_catalog_integrity, whose drift gate is tested elsewhere.
        await SqlAsync("""
            ALTER TABLE nutrition.recipe_versions DISABLE TRIGGER immutable_published_recipes;
            UPDATE nutrition.recipe_versions SET payload=payload || '{
              "review_policy":"non_medical_reference",
              "intended_use":"academic_reference_non_medical",
              "clinical_review_performed":false,"independent_clinical_review":false,
              "production_public_release":false,
              "clinical_review_not_performed_reason":"no_clinical_reviewer_non_medical_reference"
            }'::jsonb WHERE status='published';
            ALTER TABLE nutrition.recipe_versions ENABLE TRIGGER immutable_published_recipes;
            """);
        Assert.Equal(ReleaseReviewPolicy.NotAllowed,
            await MealGroundingReadiness.CatalogPolicyFailureAsync(_dataSource, false, default));
        Assert.Null(await MealGroundingReadiness.CatalogPolicyFailureAsync(_dataSource, true, default));
        await SqlAsync("ALTER TABLE nutrition.recipe_versions DISABLE TRIGGER immutable_published_recipes; UPDATE nutrition.recipe_versions SET payload=payload-'review_policy' WHERE status='published'; ALTER TABLE nutrition.recipe_versions ENABLE TRIGGER immutable_published_recipes");
        Assert.Equal("grounding_release_invalid",
            await MealGroundingReadiness.CatalogPolicyFailureAsync(_dataSource, true, default));
    }
}
