BEGIN;
-- Runtime sees one integrity result, never release evidence or package payloads.
CREATE FUNCTION nutrition.published_catalog_integrity() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
 WITH packages AS (
   SELECT * FROM nutrition.catalog_packages WHERE status='published'
 ), expected AS (
   SELECT p.id package_id,'recipe'::text kind,item->'payload'->>'versionId' version_id,
     item->>'recipeId' logical_id,item->>'version' version,item->'payload' payload
   FROM packages p CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(p.payload->'recipes')='array' THEN p.payload->'recipes' ELSE '[]'::jsonb END) item
   UNION ALL
   SELECT p.id,'rule',item->'payload'->>'versionId',item->>'ruleId',item->>'version',item->'payload'
   FROM packages p CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(p.payload->'rules')='array' THEN p.payload->'rules' ELSE '[]'::jsonb END) item
 ), materialized AS (
   SELECT 'recipe'::text kind,id,recipe_id logical_id,version,status,payload FROM nutrition.recipe_versions
   UNION ALL SELECT 'rule',id,rule_id,version,status,payload FROM nutrition.rule_versions
 )
 SELECT NOT EXISTS (
   SELECT 1 FROM packages p WHERE p.payload_digest IS NULL OR p.payload_digest !~ '^[a-f0-9]{64}$'
     OR p.payload_digest IS DISTINCT FROM nutrition.catalog_payload_digest(p.payload)
     OR jsonb_typeof(p.payload->'recipes') IS DISTINCT FROM 'array'
     OR jsonb_typeof(p.payload->'rules') IS DISTINCT FROM 'array'
 ) AND NOT EXISTS (
   SELECT 1 FROM expected GROUP BY kind,version_id HAVING count(*)<>1
 ) AND NOT EXISTS (
   SELECT 1 FROM expected x FULL JOIN
     (SELECT e.* FROM nutrition.catalog_package_entries e JOIN packages p ON p.id=e.package_id) e
     ON x.package_id=e.package_id AND x.kind=e.content_kind AND x.version_id=e.version_id::text
   WHERE x.package_id IS NULL OR e.package_id IS NULL
      OR x.logical_id IS DISTINCT FROM e.logical_id::text OR x.version IS DISTINCT FROM e.version::text
 ) AND NOT EXISTS (
   SELECT 1 FROM expected x LEFT JOIN materialized m ON m.kind=x.kind AND m.id::text=x.version_id
   WHERE m.id IS NULL OR m.logical_id::text IS DISTINCT FROM x.logical_id
     OR m.version::text IS DISTINCT FROM x.version OR m.payload IS DISTINCT FROM x.payload
 ) AND NOT EXISTS (
   SELECT 1 FROM materialized m WHERE m.status='published' AND NOT EXISTS (
     SELECT 1 FROM expected x WHERE x.kind=m.kind AND x.version_id=m.id::text)
 )
$$;
REVOKE ALL ON FUNCTION nutrition.published_catalog_integrity() FROM PUBLIC;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='nutrition_app') THEN
   GRANT EXECUTE ON FUNCTION nutrition.published_catalog_integrity() TO nutrition_app;
 END IF;
END $$;
COMMIT;
