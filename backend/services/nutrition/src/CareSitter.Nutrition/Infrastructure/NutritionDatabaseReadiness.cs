using Npgsql;

namespace CareSitter.Nutrition.Infrastructure;

internal static class NutritionDatabaseReadiness
{
    public static async Task<bool> CheckAsync(NpgsqlDataSource db, CancellationToken ct)
    {
        await using var connection = await db.OpenConnectionAsync(ct);
        await using var command = new NpgsqlCommand("""
            WITH expected(table_name,column_name,type_name) AS (VALUES
              ('assessments','id','uuid'),('assessments','customer_id','uuid'),('assessments','beneficiary_id','uuid'),
              ('assessments','health_revision','int8'),('assessments','status','text'),('assessments','payload','jsonb'),
              ('assessments','idempotency_key','uuid'),('assessments','fingerprint','text'),
              ('assessments','attempt_count','int4'),('assessments','lease_token','uuid'),('assessments','lease_until','timestamptz'),
              ('assessments','created_at','timestamptz'),('assessments','updated_at','timestamptz'),
              ('assessment_jobs','assessment_id','uuid'),('assessment_jobs','customer_id','uuid'),
              ('assessment_jobs','beneficiary_id','uuid'),('assessment_jobs','lease_token','uuid'),
              ('assessment_jobs','lease_until','timestamptz'),('assessment_jobs','attempt_count','int4'),('assessment_jobs','created_at','timestamptz'),
              ('recommendations','id','uuid'),('recommendations','customer_id','uuid'),('recommendations','beneficiary_id','uuid'),
              ('recommendations','health_revision','int8'),('recommendations','status','text'),('recommendations','payload','jsonb'),
              ('recommendations','idempotency_key','uuid'),('recommendations','fingerprint','text'),
              ('recommendations','created_at','timestamptz'),('recommendations','updated_at','timestamptz'),
              ('meal_plans','id','uuid'),('meal_plans','customer_id','uuid'),('meal_plans','beneficiary_id','uuid'),
              ('meal_plans','health_revision','int8'),('meal_plans','status','text'),('meal_plans','payload','jsonb'),
              ('meal_plans','idempotency_key','uuid'),('meal_plans','fingerprint','text'),
              ('meal_plans','created_at','timestamptz'),('meal_plans','updated_at','timestamptz'),
              ('preferences','beneficiary_id','uuid'),('preferences','customer_id','uuid'),('preferences','revision','int8'),
              ('preferences','payload','jsonb'),('preferences','updated_at','timestamptz'),
              ('concepts','code','text'),('concepts','kind','text'),('concepts','aliases','jsonb'),('concepts','version','int4'),
              ('recipe_versions','id','uuid'),('recipe_versions','recipe_id','uuid'),('recipe_versions','version','int4'),
              ('recipe_versions','status','text'),('recipe_versions','payload','jsonb'),('recipe_versions','reviewed_by','text'),
              ('recipe_versions','reviewed_at','timestamptz'),('recipe_versions','published_at','timestamptz'),
              ('rule_versions','id','uuid'),('rule_versions','rule_id','uuid'),('rule_versions','version','int4'),
              ('rule_versions','status','text'),('rule_versions','payload','jsonb'),('rule_versions','reviewed_by','text'),
              ('rule_versions','reviewed_at','timestamptz'),('rule_versions','published_at','timestamptz'),
              ('catalog_state','id','int4'),('catalog_state','revision','int8')
            ), relations AS (
              SELECT c.oid,c.relname,c.relrowsecurity,c.relforcerowsecurity
              FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='nutrition' AND c.relkind='r'
            )
            SELECT
              NOT EXISTS (SELECT 1 FROM expected e WHERE NOT EXISTS (
                SELECT 1 FROM relations r JOIN pg_attribute a ON a.attrelid=r.oid JOIN pg_type t ON t.oid=a.atttypid
                WHERE r.relname=e.table_name AND a.attname=e.column_name AND NOT a.attisdropped AND t.typname=e.type_name))
              AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname=current_user AND NOT rolsuper AND NOT rolbypassrls AND NOT rolcreatedb AND NOT rolcreaterole)
              AND EXISTS (SELECT 1 FROM pg_namespace n WHERE n.nspname='nutrition'
                AND has_schema_privilege(n.oid,'USAGE') AND NOT has_schema_privilege(n.oid,'CREATE'))
              AND NOT EXISTS (SELECT 1 FROM relations r WHERE r.relname IN ('assessments','recommendations','meal_plans','preferences')
                AND (NOT r.relrowsecurity OR NOT r.relforcerowsecurity OR NOT EXISTS (
                  SELECT 1 FROM pg_policy p WHERE p.polrelid=r.oid AND p.polname='owner_access')))
              AND NOT EXISTS (SELECT 1 FROM relations r WHERE NOT has_table_privilege(r.oid,'SELECT'))
              AND NOT EXISTS (SELECT 1 FROM relations r WHERE r.relname IN ('assessments','assessment_jobs','recommendations','meal_plans','preferences')
                AND (NOT has_table_privilege(r.oid,'INSERT') OR NOT has_table_privilege(r.oid,'UPDATE') OR NOT has_table_privilege(r.oid,'DELETE')))
              AND NOT EXISTS (SELECT 1 FROM relations r WHERE r.relname IN ('recipe_versions','rule_versions','concepts')
                AND (has_table_privilege(r.oid,'INSERT') OR has_table_privilege(r.oid,'UPDATE') OR has_table_privilege(r.oid,'DELETE')))
              AND EXISTS (SELECT 1 FROM relations r JOIN pg_attribute a ON a.attrelid=r.oid AND a.attname='id'
                WHERE r.relname='catalog_state' AND has_column_privilege(r.oid,a.attnum,'UPDATE'))
            """, connection) { CommandTimeout = 5 };
        if (await command.ExecuteScalarAsync(ct) is not true) return false;
        command.CommandText = "SELECT EXISTS(SELECT 1 FROM nutrition.catalog_state WHERE id=1 AND revision>0)";
        return await command.ExecuteScalarAsync(ct) is true;
    }
}
