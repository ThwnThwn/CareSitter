using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Infrastructure;
using Npgsql;

namespace CareSitter.Nutrition.Tests;

public sealed partial class PostgresWorkflowTests
{
    // Raw fixtures exercise command rules independently of catalog release review. Attach
    // synthetic package provenance explicitly; production legacy rows get no automatic backfill.
    private async Task RegisterRawCatalogFixtureAsync() => await SqlAsync("""
        BEGIN;
        ALTER TABLE nutrition.catalog_package_entries DISABLE TRIGGER materialize_recipe_source_citations;
        WITH payload AS (
          SELECT jsonb_build_object('recipes',coalesce((SELECT jsonb_agg(jsonb_build_object(
            'recipeId',recipe_id,'version',version,'payload',payload) ORDER BY id)
            FROM nutrition.recipe_versions WHERE status='published'),'[]'::jsonb),
            'rules',coalesce((SELECT jsonb_agg(jsonb_build_object('ruleId',rule_id,'version',version,'payload',payload) ORDER BY id)
            FROM nutrition.rule_versions WHERE status='published'),'[]'::jsonb)) value
        )
        INSERT INTO nutrition.catalog_packages(id,package_key,version,status,payload,payload_digest,
          imported_by,reviewed_by,reviewed_at,published_by,published_at)
        SELECT gen_random_uuid(),'raw-fixture',1,'published',value,nutrition.catalog_payload_digest(value),
          'fixture','fixture',now(),'fixture',now() FROM payload;
        INSERT INTO nutrition.catalog_package_entries
        SELECT p.id,'recipe',r.id,r.recipe_id,r.version FROM nutrition.catalog_packages p
          CROSS JOIN nutrition.recipe_versions r WHERE p.package_key='raw-fixture' AND r.status='published'
        UNION ALL
        SELECT p.id,'rule',r.id,r.rule_id,r.version FROM nutrition.catalog_packages p
          CROSS JOIN nutrition.rule_versions r WHERE p.package_key='raw-fixture' AND r.status='published';
        ALTER TABLE nutrition.catalog_package_entries ENABLE TRIGGER materialize_recipe_source_citations;
        COMMIT;
        """);

    [PostgresFact]
    public async Task Published_catalog_digest_mismatch_fails_closed_at_runtime()
    {
        var assessment = await ConcurrentMealFixtureAsync();
        await SqlAsync("UPDATE nutrition.catalog_packages SET payload_digest=repeat('0',64)");
        var error = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            Handler().Handle(Request("recommend", assessment: assessment), default));
        Assert.Contains("catalog", error.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(0, await RowCountAsync("recommendations"));
        Assert.False(await NutritionDatabaseReadiness.CheckAsync(_dataSource, default, requirePublishedCatalog: true));
    }
    [PostgresFact]
    public async Task Published_catalog_missing_metadata_or_changed_payload_blocks_recommend_and_replace()
    {
        await using (var db = new NpgsqlConnection(_database))
        {
            await db.OpenAsync();
            var rule = new CareSitter.Nutrition.Domain.DietaryRule(Guid.NewGuid(), "UNUSED", [], [], new(), ["Fixture"]);
            await using var insert = new NpgsqlCommand("INSERT INTO nutrition.rule_versions VALUES(@id,@id,1,'published',@payload::jsonb,'fixture',now(),now())", db);
            insert.Parameters.AddWithValue("id", rule.VersionId);
            insert.Parameters.AddWithValue("payload", NutritionJson.Write(rule));
            await insert.ExecuteNonQueryAsync();
        }
        var assessment = await ConcurrentMealFixtureAsync();
        var original = await Handler().Handle(Request("recommend", assessment: assessment), default);
        Assert.True(original.IsSuccess);
        var recommend = Request("recommend", assessment: assessment);
        var options = new CareSitter.Nutrition.Application.ReplacementOptionsQueryHandler(_people, _store,
            new Actor(_owner, "CUSTOMER"), new Features());
        var query = new CareSitter.Nutrition.Application.ReplacementOptionsQuery(
            recommend.BeneficiaryId, original.Value.Id, "lunch");
        var choices = await options.Handle(query, default);
        var replace = Request("replace", original.Value.Id);
        replace = replace with { Input = replace.Input with { MealType = "lunch", RecipeVersionId = choices.Value[0].VersionId } };
        await SqlAsync("""
            CREATE TABLE fixture_state AS TABLE nutrition.catalog_state;
            CREATE TABLE fixture_packages AS TABLE nutrition.catalog_packages;
            CREATE TABLE fixture_entries AS TABLE nutrition.catalog_package_entries;
            CREATE TABLE fixture_recipes AS TABLE nutrition.recipe_versions;
            CREATE TABLE fixture_rules AS TABLE nutrition.rule_versions;
            ALTER TABLE nutrition.catalog_packages ALTER COLUMN payload_digest DROP NOT NULL;
            ALTER TABLE nutrition.catalog_packages DROP CONSTRAINT catalog_packages_payload_digest_check;
            """);
        var faults = new[]
        {
            "UPDATE nutrition.catalog_packages SET payload_digest=NULL",
            "UPDATE nutrition.catalog_packages SET payload_digest=''",
            "UPDATE nutrition.catalog_packages SET payload_digest=repeat('0',64)",
            "UPDATE nutrition.catalog_packages SET status='draft'", // legacy/orphan published content
            "DELETE FROM nutrition.catalog_package_entries",
            "UPDATE nutrition.catalog_packages SET payload=payload-'rules'; UPDATE nutrition.catalog_packages SET payload_digest=nutrition.catalog_payload_digest(payload)",
            "UPDATE nutrition.catalog_packages SET payload=jsonb_set(payload,'{recipes}','{}'); UPDATE nutrition.catalog_packages SET payload_digest=nutrition.catalog_payload_digest(payload)",
            "ALTER TABLE nutrition.rule_versions DISABLE TRIGGER immutable_published_rules; UPDATE nutrition.rule_versions SET payload='{}'; ALTER TABLE nutrition.rule_versions ENABLE TRIGGER immutable_published_rules",
            "UPDATE nutrition.catalog_package_entries SET version=version+1",
            "UPDATE nutrition.catalog_packages SET payload=jsonb_set(payload,'{recipes,0,payload,name}','\"Changed fixture\"')",
            "UPDATE nutrition.catalog_packages SET payload=jsonb_set(payload,'{recipes,0,payload,name}','\"Changed fixture\"'); UPDATE nutrition.catalog_packages SET payload_digest=nutrition.catalog_payload_digest(payload)",
            "ALTER TABLE nutrition.recipe_versions DISABLE TRIGGER immutable_published_recipes; UPDATE nutrition.recipe_versions SET payload=jsonb_set(payload,'{name}','\"Changed fixture\"'); ALTER TABLE nutrition.recipe_versions ENABLE TRIGGER immutable_published_recipes"
        };
        foreach (var fault in faults)
        {
            await SqlAsync(fault);
            var error = await Assert.ThrowsAsync<InvalidOperationException>(() => Handler().Handle(recommend, default));
            Assert.Contains("catalog", error.Message, StringComparison.OrdinalIgnoreCase);
            await Assert.ThrowsAsync<InvalidOperationException>(() => Handler().Handle(replace, default));
            await Assert.ThrowsAsync<InvalidOperationException>(() => options.Handle(query, default));
            Assert.Equal(1, await RowCountAsync("recommendations"));
            await SqlAsync("""
                BEGIN;
                ALTER TABLE nutrition.catalog_packages DISABLE TRIGGER require_catalog_release_evidence;
                UPDATE nutrition.catalog_packages p SET status=b.status,payload=b.payload,payload_digest=b.payload_digest
                  FROM fixture_packages b WHERE p.id=b.id;
                ALTER TABLE nutrition.catalog_packages ENABLE TRIGGER require_catalog_release_evidence;
                ALTER TABLE nutrition.recipe_versions DISABLE TRIGGER immutable_published_recipes;
                UPDATE nutrition.recipe_versions r SET payload=b.payload FROM fixture_recipes b WHERE r.id=b.id;
                ALTER TABLE nutrition.recipe_versions ENABLE TRIGGER immutable_published_recipes;
                ALTER TABLE nutrition.rule_versions DISABLE TRIGGER immutable_published_rules;
                UPDATE nutrition.rule_versions r SET payload=b.payload FROM fixture_rules b WHERE r.id=b.id;
                ALTER TABLE nutrition.rule_versions ENABLE TRIGGER immutable_published_rules;
                ALTER TABLE nutrition.catalog_package_entries DISABLE TRIGGER materialize_recipe_source_citations;
                DELETE FROM nutrition.catalog_package_entries;
                INSERT INTO nutrition.catalog_package_entries SELECT * FROM fixture_entries;
                ALTER TABLE nutrition.catalog_package_entries ENABLE TRIGGER materialize_recipe_source_citations;
                UPDATE nutrition.catalog_state s SET revision=b.revision FROM fixture_state b WHERE s.id=b.id;
                COMMIT;
                """);
        }
        Assert.True((await Handler().Handle(replace, default)).IsSuccess);
        await using var runtime = await _dataSource.OpenConnectionAsync();
        foreach (var sql in new[] { "SELECT * FROM nutrition.catalog_packages", "SELECT * FROM nutrition.catalog_package_entries",
            "UPDATE nutrition.recipe_versions SET payload='{}'", "SELECT nutrition.publish_catalog_bundle(gen_random_uuid(),'')" })
        {
            await using var forbidden = new NpgsqlCommand(sql, runtime);
            var denied = await Assert.ThrowsAsync<PostgresException>(() => forbidden.ExecuteNonQueryAsync());
            Assert.Equal("42501", denied.SqlState);
        }
    }

}

