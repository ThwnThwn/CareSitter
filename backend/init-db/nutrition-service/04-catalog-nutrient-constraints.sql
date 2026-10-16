BEGIN;

CREATE OR REPLACE FUNCTION nutrition.import_catalog_bundle(package_id uuid, package_key text, payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE
 next_version integer;
 actual_digest text;
 schema_version text;
BEGIN
 PERFORM nutrition.require_catalog_role('nutrition_catalog_importer');
 IF package_id IS NULL OR package_id='00000000-0000-0000-0000-000000000000'::uuid THEN RAISE EXCEPTION 'Package ID is required' USING ERRCODE='22023'; END IF;
 IF package_key IS NULL OR package_key !~ '^[a-z0-9]+(-[a-z0-9]+)*$' THEN RAISE EXCEPTION 'Invalid package key' USING ERRCODE='22023'; END IF;
 schema_version:=coalesce(payload->>'schemaVersion','');
 IF payload IS NULL OR jsonb_typeof(payload)<>'object' OR schema_version NOT IN ('1','2') OR coalesce(payload->>'packageKey','')<>package_key
    OR coalesce(jsonb_typeof(payload->'supportedScopes'),'')<>'array'
    OR coalesce(jsonb_typeof(payload->'citations'),'')<>'array'
    OR jsonb_typeof(payload->'concepts')<>'array' OR jsonb_typeof(payload->'recipes')<>'array'
    OR jsonb_typeof(payload->'rules')<>'array' THEN
  RAISE EXCEPTION 'Catalog payload failed database boundary validation' USING ERRCODE='22023';
 END IF;
 IF jsonb_array_length(payload->'supportedScopes')=0 OR jsonb_array_length(payload->'citations')=0 OR jsonb_array_length(payload->'recipes')<3 THEN
  RAISE EXCEPTION 'Catalog payload requires scope, citation and three meals' USING ERRCODE='22023';
 END IF;
 IF EXISTS (
  SELECT 1 FROM jsonb_array_elements(payload->'supportedScopes') scope
  WHERE jsonb_typeof(scope)<>'object' OR coalesce(scope->>'population','')<>'adult'
     OR coalesce(scope->>'medicationPolicy','')<>'reported_none_only'
     OR coalesce(jsonb_typeof(scope->'conditionCodes'),'')<>'array'
     OR coalesce(jsonb_typeof(scope->'blockedSpecialNeeds'),'')<>'array'
     OR NOT coalesce(scope->'blockedSpecialNeeds','[]'::jsonb) @> '["KIDNEY_DISEASE","DYSPHAGIA","TUBE_FEEDING","FLUID_RESTRICTION","ELECTROLYTE_RESTRICTION"]'::jsonb
 ) THEN RAISE EXCEPTION 'Catalog scope is outside the P0 safety boundary' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(payload->'recipes') value WHERE value->'payload'->>'mealType'='breakfast')
    OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(payload->'recipes') value WHERE value->'payload'->>'mealType'='lunch')
    OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(payload->'recipes') value WHERE value->'payload'->>'mealType'='dinner') THEN
  RAISE EXCEPTION 'Catalog payload requires breakfast, lunch and dinner' USING ERRCODE='22023';
 END IF;
 IF EXISTS (
  SELECT 1 FROM jsonb_array_elements(payload->'recipes') value
  WHERE jsonb_typeof(value)<>'object' OR coalesce(value->>'recipeId','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
     OR coalesce(value->>'version','') !~ '^[1-9][0-9]*$' OR coalesce(value->'payload'->>'versionId','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
     OR coalesce(jsonb_typeof(value->'payload'->'sources'),'')<>'array'
 ) OR EXISTS (
  SELECT 1 FROM jsonb_array_elements(payload->'rules') value
  WHERE jsonb_typeof(value)<>'object' OR coalesce(value->>'ruleId','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
     OR coalesce(value->>'version','') !~ '^[1-9][0-9]*$' OR coalesce(value->'payload'->>'versionId','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
     OR coalesce(jsonb_typeof(value->'payload'->'prerequisites'),'')<>'array'
     OR coalesce(jsonb_typeof(value->'payload'->'sources'),'')<>'array'
 ) THEN RAISE EXCEPTION 'Catalog version entry failed database boundary validation' USING ERRCODE='22023'; END IF;

 IF schema_version='1' AND EXISTS (
  SELECT 1 FROM jsonb_array_elements(payload->'rules') value WHERE value->'payload' ? 'nutrientConstraints'
 ) THEN RAISE EXCEPTION 'Schema version 1 cannot contain nutrient constraints' USING ERRCODE='22023'; END IF;
 IF schema_version='2' AND EXISTS (
  SELECT 1 FROM jsonb_array_elements(payload->'rules') value
  WHERE coalesce(jsonb_typeof(value->'payload'->'nutrientConstraints'),'')<>'array'
 ) THEN RAISE EXCEPTION 'Schema version 2 requires nutrient constraint arrays' USING ERRCODE='22023'; END IF;
 IF schema_version='2' AND EXISTS (
  SELECT 1
  FROM jsonb_array_elements(payload->'rules') rule_value
  CROSS JOIN LATERAL jsonb_array_elements(rule_value->'payload'->'nutrientConstraints') constraint_value
  WHERE jsonb_typeof(constraint_value)<>'object'
     OR coalesce(constraint_value->>'nutrientKey','')=''
     OR coalesce(constraint_value->>'scope','') NOT IN ('daily','meal')
     OR NOT (constraint_value ? 'mealType') OR NOT (constraint_value ? 'minimum') OR NOT (constraint_value ? 'maximum')
     OR coalesce(jsonb_typeof(constraint_value->'minimum'),'missing') NOT IN ('number','null')
     OR coalesce(jsonb_typeof(constraint_value->'maximum'),'missing') NOT IN ('number','null')
     OR (jsonb_typeof(constraint_value->'minimum')<>'number' AND jsonb_typeof(constraint_value->'maximum')<>'number')
     OR CASE WHEN constraint_value->>'scope'='daily' THEN jsonb_typeof(constraint_value->'mealType')<>'null'
             WHEN constraint_value->>'scope'='meal' THEN coalesce(constraint_value->>'mealType','') NOT IN ('breakfast','lunch','dinner')
             ELSE true END
     OR CASE WHEN jsonb_typeof(constraint_value->'minimum')='number' THEN (constraint_value->>'minimum')::numeric<0 ELSE false END
     OR CASE WHEN jsonb_typeof(constraint_value->'maximum')='number' THEN (constraint_value->>'maximum')::numeric<0 ELSE false END
     OR CASE WHEN jsonb_typeof(constraint_value->'minimum')='number' AND jsonb_typeof(constraint_value->'maximum')='number'
             THEN (constraint_value->>'minimum')::numeric>(constraint_value->>'maximum')::numeric ELSE false END
 ) THEN RAISE EXCEPTION 'Catalog nutrient constraint failed database boundary validation' USING ERRCODE='22023'; END IF;
 IF schema_version='2' AND EXISTS (
  SELECT 1
  FROM jsonb_array_elements(payload->'rules') rule_value
  CROSS JOIN LATERAL (
   SELECT constraint_value->>'nutrientKey',constraint_value->>'scope',constraint_value->>'mealType'
   FROM jsonb_array_elements(rule_value->'payload'->'nutrientConstraints') constraint_value
   GROUP BY constraint_value->>'nutrientKey',constraint_value->>'scope',constraint_value->>'mealType'
   HAVING count(*)>1
  ) duplicate_constraint
 ) THEN RAISE EXCEPTION 'Catalog nutrient constraints contain duplicates' USING ERRCODE='22023'; END IF;
 IF schema_version='2' AND EXISTS (
  SELECT 1
  FROM jsonb_array_elements(payload->'rules') rule_value
  CROSS JOIN LATERAL jsonb_array_elements(rule_value->'payload'->'nutrientConstraints') constraint_value
  CROSS JOIN jsonb_array_elements(payload->'recipes') recipe_value
  WHERE (constraint_value->>'scope'='daily' OR recipe_value->'payload'->>'mealType'=constraint_value->>'mealType')
    AND (
     coalesce(jsonb_typeof(recipe_value->'payload'->'nutrients'->(constraint_value->>'nutrientKey')),'missing')<>'number'
     OR CASE WHEN jsonb_typeof(recipe_value->'payload'->'nutrients'->(constraint_value->>'nutrientKey'))='number'
             THEN (recipe_value->'payload'->'nutrients'->>(constraint_value->>'nutrientKey'))::numeric<0 ELSE false END
    )
 ) THEN RAISE EXCEPTION 'Every applicable recipe must provide each constrained nutrient' USING ERRCODE='22023'; END IF;

 PERFORM pg_advisory_xact_lock(hashtextextended('nutrition.catalog.'||package_key,0));
 SELECT coalesce(max(version),0)+1 INTO next_version FROM nutrition.catalog_packages p WHERE p.package_key=import_catalog_bundle.package_key;
 actual_digest:=nutrition.catalog_payload_digest(payload);
 INSERT INTO nutrition.catalog_packages(id,package_key,version,status,payload,payload_digest,imported_by)
 VALUES(package_id,package_key,next_version,'draft',payload,actual_digest,session_user);
 INSERT INTO nutrition.catalog_audit(package_id,package_key,package_version,action,actor,payload_digest)
 VALUES(package_id,package_key,next_version,'imported',session_user,actual_digest);
 RETURN jsonb_build_object('packageId',package_id,'packageKey',package_key,'version',next_version,'status','draft','digest',actual_digest);
END $$;

COMMIT;
