BEGIN;

DO $$ BEGIN
 IF to_regclass('nutrition.catalog_release_evidence') IS NULL
    AND EXISTS (SELECT 1 FROM nutrition.catalog_packages WHERE status IN ('reviewed','published')) THEN
  RAISE EXCEPTION 'Existing reviewed or published catalog packages require evidence reconciliation before migration 06' USING ERRCODE='55000';
 END IF;
END $$;

CREATE TABLE IF NOT EXISTS nutrition.catalog_release_evidence (
 package_id uuid PRIMARY KEY REFERENCES nutrition.catalog_packages(id),
 payload_digest text NOT NULL CHECK(payload_digest ~ '^[a-f0-9]{64}$'),
 bundle_file_sha256 text NOT NULL CHECK(bundle_file_sha256 ~ '^[a-f0-9]{64}$'),
 evidence jsonb NOT NULL,
 evidence_digest text NOT NULL CHECK(evidence_digest ~ '^[a-f0-9]{64}$'),
 recorded_by text NOT NULL CHECK(length(trim(recorded_by)) > 0),
 recorded_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON nutrition.catalog_release_evidence FROM PUBLIC;

CREATE OR REPLACE FUNCTION nutrition.record_catalog_release_evidence(
 package_id uuid, expected_digest text, bundle jsonb, evidence jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE
 package nutrition.catalog_packages%ROWTYPE;
 file_sha text;
 evidence_sha text;
 release_profile text;
BEGIN
 PERFORM nutrition.require_catalog_role('nutrition_catalog_reviewer');
 SELECT * INTO package FROM nutrition.catalog_packages p WHERE p.id=package_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Catalog package not found' USING ERRCODE='P0002'; END IF;
 IF package.status<>'draft' THEN RAISE EXCEPTION 'Catalog package must be draft' USING ERRCODE='55000'; END IF;
 IF package.imported_by=session_user THEN RAISE EXCEPTION 'Importer cannot record release evidence' USING ERRCODE='42501'; END IF;
 IF package.payload_digest<>expected_digest OR nutrition.catalog_payload_digest(package.payload)<>expected_digest
    OR bundle IS DISTINCT FROM package.payload THEN
  RAISE EXCEPTION 'Catalog bundle or digest changed' USING ERRCODE='40001';
 END IF;
 IF evidence IS NULL OR jsonb_typeof(evidence)<>'object'
    OR coalesce(evidence->>'schemaVersion','')<>'1'
    OR coalesce(evidence->>'packageKey','')<>package.package_key
    OR coalesce(evidence->>'contentStatus','')<>'review_ready'
    OR coalesce(jsonb_typeof(evidence->'recipes'),'')<>'array'
    OR coalesce(jsonb_typeof(evidence->'rules'),'')<>'array' THEN
  RAISE EXCEPTION 'Approved catalog release evidence is required' USING ERRCODE='22023';
 END IF;
 release_profile:=coalesce(evidence->>'releaseProfile','adult_condition_v1');
 IF release_profile='adult_baseline_source_reference_v1' THEN
  IF coalesce(jsonb_typeof(evidence->'sourcePublication'),'')<>'object'
     OR coalesce(evidence->'sourcePublication'->>'decision','')<>'verified'
     OR length(trim(coalesce(evidence->'sourcePublication'->>'sourceId','')))=0
     OR length(trim(coalesce(evidence->'sourcePublication'->>'sourceRevisionId','')))=0
     OR coalesce(evidence->'sourcePublication'->>'documentSha256','') !~ '^[a-fA-F0-9]{64}$'
     OR length(trim(coalesce(evidence->'sourcePublication'->>'organization','')))=0
     OR coalesce(evidence->'sourcePublication'->>'publicationYear','') !~ '^[1-9][0-9]{3}$'
     OR length(trim(coalesce(evidence->'sourcePublication'->>'verifiedAt','')))=0
     OR NOT EXISTS (
       SELECT 1 FROM jsonb_array_elements(package.payload->'citations') citation
       WHERE citation->>'id'=evidence->'sourcePublication'->>'sourceId'
         AND citation->>'organization'=evidence->'sourcePublication'->>'organization'
         AND citation->>'year'=evidence->'sourcePublication'->>'publicationYear'
         AND lower(coalesce(citation->>'fileSha256',''))=lower(evidence->'sourcePublication'->>'documentSha256'))
     OR coalesce(jsonb_typeof(evidence->'releaseAuthorization'),'')<>'object'
     OR coalesce(evidence->'releaseAuthorization'->>'authorityType','')<>'product_owner'
     OR coalesce(evidence->'releaseAuthorization'->>'decision','')<>'approved'
     OR length(trim(coalesce(evidence->'releaseAuthorization'->>'authorizationId','')))=0
     OR length(trim(coalesce(evidence->'releaseAuthorization'->>'authorizedBy','')))=0
     OR length(trim(coalesce(evidence->'releaseAuthorization'->>'authorizedAt','')))=0 THEN
   RAISE EXCEPTION 'Verified publication and product-owner authorization are required for a source-reference release' USING ERRCODE='22023';
  END IF;
 ELSE
  IF coalesce(jsonb_typeof(evidence->'clinicalReview'),'')<>'object'
     OR coalesce(evidence->'clinicalReview'->>'decision','')<>'approved'
     OR length(trim(coalesce(evidence->'clinicalReview'->>'reviewerName','')))=0
     OR length(trim(coalesce(evidence->'clinicalReview'->>'credentials','')))=0
     OR length(trim(coalesce(evidence->'clinicalReview'->>'reviewedAt','')))=0 THEN
   RAISE EXCEPTION 'Approved clinical review is required' USING ERRCODE='22023';
  END IF;
 END IF;
 file_sha:=lower(coalesce(evidence->>'bundleFileSha256',''));
 IF file_sha !~ '^[a-f0-9]{64}$' THEN
  RAISE EXCEPTION 'Bundle file SHA-256 is required' USING ERRCODE='22023';
 END IF;
 IF jsonb_array_length(package.payload->'recipes')<>12 OR EXISTS (
  SELECT 1 FROM (VALUES ('breakfast'),('lunch'),('dinner')) AS meal(kind)
  WHERE (SELECT count(*) FROM jsonb_array_elements(package.payload->'recipes') recipe
   WHERE recipe->'payload'->>'mealType'=meal.kind)<>4
 ) THEN
  RAISE EXCEPTION 'Release requires four recipes per meal type' USING ERRCODE='22023';
 END IF;
 IF (SELECT count(DISTINCT recipe->'payload'->>'versionId')
     FROM jsonb_array_elements(package.payload->'recipes') recipe)<>12 THEN
  RAISE EXCEPTION 'Release recipe version ids must be distinct' USING ERRCODE='22023';
 END IF;
 IF coalesce(jsonb_typeof(evidence->'requiredNutrients'),'')<>'array' OR EXISTS (
  SELECT 1 FROM (VALUES ('energy_kcal'),('protein_g'),('carbohydrate_g'),('fat_g'),('fiber_g'),('sodium_mg')) nutrient(key)
  WHERE NOT evidence->'requiredNutrients' ? nutrient.key
 ) THEN
  RAISE EXCEPTION 'Release nutrient coverage is incomplete' USING ERRCODE='22023';
 END IF;
 IF release_profile IN ('adult_baseline_v1','adult_baseline_source_reference_v1') THEN
  IF jsonb_array_length(package.payload->'rules')<>0 OR EXISTS (
   SELECT 1 FROM jsonb_array_elements(package.payload->'supportedScopes') scope
   WHERE jsonb_array_length(scope->'conditionCodes')<>0
  ) THEN RAISE EXCEPTION 'Baseline release cannot enable disease rules or scopes' USING ERRCODE='22023'; END IF;
 ELSIF release_profile='adult_condition_v1' THEN
  IF jsonb_array_length(package.payload->'rules')=0 THEN
   RAISE EXCEPTION 'Condition release requires a disease rule' USING ERRCODE='22023';
  END IF;
 ELSE
  RAISE EXCEPTION 'Unsupported catalog release profile' USING ERRCODE='22023';
 END IF;
 IF jsonb_array_length(evidence->'recipes')<>jsonb_array_length(package.payload->'recipes')
    OR EXISTS (
     SELECT 1 FROM jsonb_array_elements(package.payload->'recipes') recipe
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(evidence->'recipes') item
       WHERE item->>'recipeVersionId'=recipe->'payload'->>'versionId')
    )
    OR EXISTS (SELECT 1 FROM jsonb_array_elements(evidence->'recipes') item
      WHERE coalesce(jsonb_typeof(item->'unresolvedItems'),'')<>'array'
         OR item->'unresolvedItems'<>'[]'::jsonb
         OR coalesce(jsonb_typeof(item->'ingredients'),'')<>'array'
         OR coalesce(jsonb_typeof(item->'nutrients'),'')<>'array')
    OR (SELECT count(DISTINCT item->>'recipeVersionId')
        FROM jsonb_array_elements(evidence->'recipes') item)<>12
    OR EXISTS (SELECT 1 FROM jsonb_array_elements(package.payload->'recipes') recipe
      CROSS JOIN LATERAL jsonb_array_elements_text(evidence->'requiredNutrients') nutrient(key)
      WHERE recipe->'payload'->'nutrients'->nutrient.key IS NULL OR NOT EXISTS (
       SELECT 1 FROM jsonb_array_elements(evidence->'recipes') item
       CROSS JOIN LATERAL jsonb_array_elements(item->'nutrients') supplied
       WHERE item->>'recipeVersionId'=recipe->'payload'->>'versionId'
         AND supplied->>'key'=nutrient.key
         AND supplied->'value'=recipe->'payload'->'nutrients'->nutrient.key
      )) THEN
  RAISE EXCEPTION 'Recipe evidence is incomplete or unresolved' USING ERRCODE='22023';
 END IF;
 IF jsonb_array_length(evidence->'rules')<>jsonb_array_length(package.payload->'rules')
    OR EXISTS (
     SELECT 1 FROM jsonb_array_elements(package.payload->'rules') rule
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(evidence->'rules') item
       WHERE item->>'ruleVersionId'=rule->'payload'->>'versionId')
    )
    OR EXISTS (SELECT 1 FROM jsonb_array_elements(evidence->'rules') item
      WHERE coalesce(jsonb_typeof(item->'unresolvedItems'),'')<>'array'
         OR item->'unresolvedItems'<>'[]'::jsonb
         OR coalesce(jsonb_typeof(item->'sourceIds'),'')<>'array'
         OR length(trim(coalesce(item->>'sourceLocator','')))=0) THEN
  RAISE EXCEPTION 'Rule evidence is incomplete or unresolved' USING ERRCODE='22023';
 END IF;
 evidence_sha:=nutrition.catalog_payload_digest(evidence);
 INSERT INTO nutrition.catalog_release_evidence(
   package_id,payload_digest,bundle_file_sha256,evidence,evidence_digest,recorded_by)
 VALUES(package_id,expected_digest,file_sha,evidence,evidence_sha,session_user);
 RETURN jsonb_build_object('packageId',package_id,'bundleFileSha256',file_sha,'evidenceDigest',evidence_sha);
END $$;

CREATE OR REPLACE FUNCTION nutrition.require_catalog_release_evidence() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE proof nutrition.catalog_release_evidence%ROWTYPE;
BEGIN
 IF NEW.status IN ('reviewed','published') AND NEW.status IS DISTINCT FROM OLD.status THEN
  SELECT * INTO proof FROM nutrition.catalog_release_evidence WHERE package_id=NEW.id;
  IF NOT FOUND OR proof.payload_digest<>NEW.payload_digest
     OR proof.payload_digest<>nutrition.catalog_payload_digest(NEW.payload)
     OR proof.evidence_digest<>nutrition.catalog_payload_digest(proof.evidence)
     OR proof.recorded_by IS DISTINCT FROM NEW.reviewed_by THEN
   RAISE EXCEPTION 'Catalog release evidence is missing or changed' USING ERRCODE='55000';
  END IF;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS require_catalog_release_evidence ON nutrition.catalog_packages;
CREATE TRIGGER require_catalog_release_evidence
 BEFORE UPDATE OF status ON nutrition.catalog_packages
 FOR EACH ROW EXECUTE FUNCTION nutrition.require_catalog_release_evidence();

REVOKE ALL ON FUNCTION nutrition.record_catalog_release_evidence(uuid,text,jsonb,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION nutrition.record_catalog_release_evidence(uuid,text,jsonb,jsonb) TO nutrition_catalog_reviewer;
REVOKE ALL ON FUNCTION nutrition.require_catalog_release_evidence() FROM PUBLIC;

COMMIT;
