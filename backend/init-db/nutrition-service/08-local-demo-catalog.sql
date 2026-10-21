BEGIN;

CREATE TABLE IF NOT EXISTS nutrition.local_demo_catalog (
 package_key text PRIMARY KEY CHECK(package_key ~ '^[a-z0-9]+(-[a-z0-9]+)*-local-demo$'),
 revision bigint NOT NULL CHECK(revision > 0),
 payload jsonb NOT NULL,
 payload_digest text NOT NULL CHECK(payload_digest ~ '^[a-f0-9]{64}$'),
 imported_by text NOT NULL CHECK(length(trim(imported_by)) > 0),
 imported_at timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON nutrition.local_demo_catalog FROM PUBLIC;

DROP FUNCTION IF EXISTS nutrition.import_local_demo_catalog(text,jsonb);

CREATE FUNCTION nutrition.import_local_demo_catalog(p_package_key text, p_payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE
 next_revision bigint;
 actual_digest text;
BEGIN
 PERFORM nutrition.require_catalog_role('nutrition_catalog_importer');
 IF p_package_key IS NULL OR p_package_key !~ '^[a-z0-9]+(-[a-z0-9]+)*-local-demo$' THEN
  RAISE EXCEPTION 'Local demo package key must end in -local-demo' USING ERRCODE='22023';
 END IF;
 IF p_payload IS NULL OR jsonb_typeof(p_payload)<>'object'
    OR coalesce(p_payload->>'schemaVersion','') NOT IN ('1','2')
    OR coalesce(p_payload->>'packageKey','')<>p_package_key
    OR coalesce(jsonb_typeof(p_payload->'supportedScopes'),'')<>'array'
    OR coalesce(jsonb_typeof(p_payload->'citations'),'')<>'array'
    OR coalesce(jsonb_typeof(p_payload->'concepts'),'')<>'array'
    OR coalesce(jsonb_typeof(p_payload->'recipes'),'')<>'array'
    OR coalesce(jsonb_typeof(p_payload->'rules'),'')<>'array' THEN
  RAISE EXCEPTION 'Local demo catalog payload failed boundary validation' USING ERRCODE='22023';
 END IF;
 IF jsonb_array_length(p_payload->'supportedScopes')=0
    OR jsonb_array_length(p_payload->'citations')=0
    OR jsonb_array_length(p_payload->'recipes')<3
    OR jsonb_array_length(p_payload->'rules')<>0 THEN
  RAISE EXCEPTION 'Local demo catalog requires scope, citation, three meals and no disease rules' USING ERRCODE='22023';
 END IF;
 IF EXISTS (
   SELECT 1 FROM jsonb_array_elements(p_payload->'supportedScopes') scope
  WHERE coalesce(scope->>'population','')<>'adult'
     OR coalesce(scope->>'medicationPolicy','')<>'reported_none_only'
     OR coalesce(jsonb_typeof(scope->'conditionCodes'),'')<>'array'
     OR jsonb_array_length(scope->'conditionCodes')<>0
     OR coalesce(jsonb_typeof(scope->'blockedSpecialNeeds'),'')<>'array'
     OR NOT scope->'blockedSpecialNeeds' @> '["KIDNEY_DISEASE","DYSPHAGIA","TUBE_FEEDING","FLUID_RESTRICTION","ELECTROLYTE_RESTRICTION"]'::jsonb
 ) THEN
  RAISE EXCEPTION 'Local demo catalog must be an adult baseline without disease conditions' USING ERRCODE='22023';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(p_payload->'recipes') value WHERE value->'payload'->>'mealType'='breakfast')
    OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(p_payload->'recipes') value WHERE value->'payload'->>'mealType'='lunch')
    OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(p_payload->'recipes') value WHERE value->'payload'->>'mealType'='dinner')
    OR EXISTS (
       SELECT 1 FROM jsonb_array_elements(p_payload->'recipes') value
      WHERE coalesce(value->'payload'->>'name','') NOT LIKE '[DEMO] %'
         OR coalesce(value->>'recipeId','') !~ '^[0-9a-fA-F-]{36}$'
         OR coalesce(value->'payload'->>'versionId','') !~ '^[0-9a-fA-F-]{36}$'
    ) THEN
  RAISE EXCEPTION 'Local demo recipes require all meal types, remapped IDs and visible demo labels' USING ERRCODE='22023';
 END IF;

 PERFORM pg_advisory_xact_lock(hashtextextended('nutrition.local-demo.'||p_package_key,0));
 SELECT coalesce(current.revision,0)+1 INTO next_revision
 FROM (SELECT 1) seed LEFT JOIN nutrition.local_demo_catalog current ON current.package_key=p_package_key;
 actual_digest:=nutrition.catalog_payload_digest(p_payload);
 INSERT INTO nutrition.local_demo_catalog(package_key,revision,payload,payload_digest,imported_by,imported_at)
 VALUES(p_package_key,next_revision,p_payload,actual_digest,session_user,now())
 ON CONFLICT(package_key) DO UPDATE SET
  revision=excluded.revision,payload=excluded.payload,payload_digest=excluded.payload_digest,
  imported_by=excluded.imported_by,imported_at=excluded.imported_at;
 RETURN jsonb_build_object(
   'packageKey',p_package_key,'revision',next_revision,'status','local_demo',
  'digest',actual_digest,'productionPublishable',false);
END $$;

REVOKE ALL ON FUNCTION nutrition.import_local_demo_catalog(text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION nutrition.import_local_demo_catalog(text,jsonb) TO nutrition_catalog_importer;

DO $$
BEGIN
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='nutrition_app') THEN
  GRANT SELECT ON nutrition.local_demo_catalog TO nutrition_app;
 END IF;
END $$;

COMMIT;
