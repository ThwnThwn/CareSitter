BEGIN;
-- Migration owner controls this singleton. Runtime/reviewer roles receive no mutation grant.
CREATE TABLE IF NOT EXISTS nutrition.catalog_review_policy (
 id integer PRIMARY KEY CHECK(id=1),
 review_policy text NOT NULL CHECK(review_policy IN ('source_and_clinical','non_medical_reference'))
);
INSERT INTO nutrition.catalog_review_policy VALUES (1,'source_and_clinical') ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS nutrition.catalog_review_policy_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 old_policy text NOT NULL, new_policy text NOT NULL,
 changed_by text NOT NULL, changed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 reason text NOT NULL CHECK(length(trim(reason))>=5)
);
REVOKE ALL ON nutrition.catalog_review_policy,nutrition.catalog_review_policy_audit FROM PUBLIC;
REVOKE ALL ON nutrition.catalog_review_policy,nutrition.catalog_review_policy_audit FROM nutrition_catalog_reviewer;
CREATE OR REPLACE FUNCTION nutrition.catalog_review_policy_audit_change() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,nutrition AS $$
BEGIN
 IF TG_OP<>'UPDATE' THEN RAISE EXCEPTION 'Use set_catalog_review_policy' USING ERRCODE='42501'; END IF;
 IF length(trim(coalesce(current_setting('nutrition.catalog_policy_reason',true),'')))<5 THEN
  RAISE EXCEPTION 'Explicit policy change reason is required' USING ERRCODE='22023';
 END IF;
 INSERT INTO nutrition.catalog_review_policy_audit(old_policy,new_policy,changed_by,reason)
 VALUES(OLD.review_policy,NEW.review_policy,session_user,current_setting('nutrition.catalog_policy_reason'));
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS audit_catalog_review_policy ON nutrition.catalog_review_policy;
CREATE TRIGGER audit_catalog_review_policy BEFORE UPDATE OR DELETE ON nutrition.catalog_review_policy
 FOR EACH ROW EXECUTE FUNCTION nutrition.catalog_review_policy_audit_change();
CREATE OR REPLACE FUNCTION nutrition.set_catalog_review_policy(policy text, reason text) RETURNS text
LANGUAGE plpgsql SET search_path=pg_catalog,nutrition AS $$
BEGIN
 IF policy NOT IN ('source_and_clinical','non_medical_reference') OR policy IS NULL
    OR length(trim(coalesce(reason,'')))<5 THEN
  RAISE EXCEPTION 'Supported policy and explicit reason required' USING ERRCODE='22023';
 END IF;
 -- Invoker rights: only the owner/migration role can update this table.
 PERFORM set_config('nutrition.catalog_policy_reason',reason,true);
 UPDATE nutrition.catalog_review_policy SET review_policy=policy WHERE id=1;
 RETURN policy;
END $$;
CREATE OR REPLACE FUNCTION nutrition.current_catalog_review_policy() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
 SELECT review_policy FROM nutrition.catalog_review_policy WHERE id=1
$$;
ALTER TABLE nutrition.catalog_packages ADD COLUMN IF NOT EXISTS review_policy text NOT NULL DEFAULT 'source_and_clinical'
 CHECK(review_policy IN ('source_and_clinical','non_medical_reference'));
CREATE OR REPLACE FUNCTION nutrition.is_non_medical_catalog_metadata(value jsonb) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog,nutrition AS $$
 SELECT coalesce(value @> '{"review_policy":"non_medical_reference","clinical_review_performed":false,
 "independent_clinical_review":false,"clinical_review_not_performed_reason":"no_clinical_reviewer_non_medical_reference",
 "intended_use":"academic_reference_non_medical","production_public_release":false}'::jsonb,false)
$$;
-- Recursively reject clinical claims/roles even inside review records, not just the root.
CREATE OR REPLACE FUNCTION nutrition.catalog_has_clinical_claim(value jsonb) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog,nutrition AS $$
 SELECT jsonb_path_exists(value, '$.** ? (@.clinicalReview != null || @.clinical_review != null || @.clinical_relevance_review != null || @.reviewerRole == "dietitian" || @.reviewerRole == "physician" || @.reviewer_role == "dietitian" || @.reviewer_role == "physician" || @.role == "dietitian" || @.role == "physician" || @.clinical_review_performed == true || @.independent_clinical_review == true)')
$$;
CREATE OR REPLACE FUNCTION nutrition.valid_catalog_data_review(value jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog,nutrition AS $$
BEGIN
 IF coalesce(value->>'decision','')<>'approved' OR coalesce(value->>'reviewerRole','')<>'data_steward'
    OR length(trim(coalesce(value->>'reviewerId','')))=0
    OR coalesce(value->>'reviewedAt','') !~ '(Z|[+-][0-9]{2}:[0-9]{2})$' THEN RETURN false; END IF;
 RETURN isfinite((value->>'reviewedAt')::timestamptz);
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RETURN false;
END $$;
CREATE OR REPLACE FUNCTION nutrition.record_catalog_release_evidence(
 package_id uuid, expected_digest text, bundle jsonb, evidence jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE
 package nutrition.catalog_packages%ROWTYPE;
 file_sha text;
 evidence_sha text;
 release_profile text;
 db_policy text;
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

 SELECT review_policy INTO db_policy FROM nutrition.catalog_review_policy WHERE id=1 FOR SHARE;
 IF db_policy='non_medical_reference' THEN
  IF NOT nutrition.is_non_medical_catalog_metadata(evidence)
     OR NOT nutrition.is_non_medical_catalog_metadata(bundle)
     OR nutrition.catalog_has_clinical_claim(evidence) OR nutrition.catalog_has_clinical_claim(bundle)
     OR coalesce(evidence->>'releaseProfile','')<>'adult_baseline_v1'
     OR EXISTS (SELECT 1 FROM jsonb_array_elements(bundle->'recipes') r
       WHERE NOT nutrition.is_non_medical_catalog_metadata(r->'payload'))
     OR EXISTS (SELECT 1 FROM jsonb_array_elements(evidence->'recipes') r
       WHERE NOT nutrition.valid_catalog_data_review(r->'dataReview')) THEN
   RAISE EXCEPTION 'Non-medical metadata and approved data_steward reviews required; clinical claims forbidden' USING ERRCODE='22023';
  END IF;
 ELSIF coalesce(evidence->>'review_policy','source_and_clinical')<>'source_and_clinical'
    OR coalesce(bundle->>'review_policy','source_and_clinical')<>'source_and_clinical'
    OR EXISTS (SELECT 1 FROM jsonb_array_elements(bundle->'recipes') r
      WHERE coalesce(r->'payload'->>'review_policy','source_and_clinical')<>'source_and_clinical') THEN
  RAISE EXCEPTION 'Catalog review policy differs from database policy' USING ERRCODE='22023';
 END IF;
 release_profile:=coalesce(evidence->>'releaseProfile','adult_condition_v1');
 IF db_policy='non_medical_reference' THEN
  NULL; -- Verified data reviews replace only the clinical gate.
 ELSIF release_profile='adult_baseline_source_reference_v1' THEN
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
 UPDATE nutrition.catalog_packages SET review_policy=db_policy WHERE id=package_id;
 evidence_sha:=nutrition.catalog_payload_digest(evidence);
 INSERT INTO nutrition.catalog_release_evidence(
   package_id,payload_digest,bundle_file_sha256,evidence,evidence_digest,recorded_by)
 VALUES(package_id,expected_digest,file_sha,evidence,evidence_sha,session_user);
 RETURN jsonb_build_object('packageId',package_id,'bundleFileSha256',file_sha,'evidenceDigest',evidence_sha);
END $$;

CREATE OR REPLACE FUNCTION nutrition.require_catalog_knowledge_review() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE
 review jsonb;
 clinical_reviewer_id text;
 release_authority_id text;
 release_profile text;
BEGIN
 review:=NEW.evidence->'knowledgeReview';
 clinical_reviewer_id:=trim(coalesce(NEW.evidence->'clinicalReview'->>'reviewerId',''));
 release_authority_id:=trim(coalesce(NEW.evidence->'releaseAuthorization'->>'authorizationId',''));
 release_profile:=coalesce(NEW.evidence->>'releaseProfile','adult_condition_v1');
 IF review IS NULL OR jsonb_typeof(review)<>'object'
    OR coalesce(review->>'schemaVersion','')<>'1'
    OR coalesce(review->>'decision','')<>'approved'
    OR coalesce(review->>'candidateGraphSha256','') !~ '^[a-fA-F0-9]{64}$'
    OR coalesce(review->>'decisionLedgerSha256','') !~ '^[a-fA-F0-9]{64}$'
    OR coalesce(review->>'reviewedGraphSha256','') !~ '^[a-fA-F0-9]{64}$'
    OR coalesce(review->>'candidateCount','') !~ '^[1-9][0-9]*$'
    OR coalesce(review->>'approvedCount','')<>coalesce(review->>'candidateCount','')
    OR coalesce(review->>'pendingCount','')<>'0'
    OR coalesce(review->>'rejectedCount','')<>'0'
    OR coalesce(jsonb_typeof(review->'sources'),'')<>'array'
    OR jsonb_array_length(review->'sources')=0
    OR EXISTS (
      SELECT 1 FROM jsonb_array_elements(review->'sources') source
      WHERE length(trim(coalesce(source->>'sourceRevisionId','')))=0
         OR coalesce(source->>'rightsStatus','')<>'permitted')
    OR (SELECT count(*) FROM jsonb_array_elements(review->'sources')) <>
       (SELECT count(DISTINCT source->>'sourceRevisionId') FROM jsonb_array_elements(review->'sources') source)
    OR (NEW.evidence->>'review_policy'='non_medical_reference' AND (
      NOT nutrition.is_non_medical_catalog_metadata(review)
      OR coalesce(jsonb_typeof(review->'dataReviewerIds'),'')<>'array'
      OR coalesce(review->'clinicalReviewerIds','[]'::jsonb)<>'[]'::jsonb
      OR EXISTS (SELECT 1 FROM jsonb_array_elements(NEW.evidence->'recipes') r
        WHERE NOT review->'dataReviewerIds' ? (r->'dataReview'->>'reviewerId'))))
    OR (coalesce(NEW.evidence->>'review_policy','source_and_clinical')<>'non_medical_reference' AND release_profile='adult_baseline_source_reference_v1' AND (
      coalesce(jsonb_typeof(review->'releaseAuthorityIds'),'')<>'array'
      OR jsonb_array_length(review->'releaseAuthorityIds')=0
      OR release_authority_id=''
      OR NOT review->'releaseAuthorityIds' ? release_authority_id))
    OR (coalesce(NEW.evidence->>'review_policy','source_and_clinical')<>'non_medical_reference' AND release_profile<>'adult_baseline_source_reference_v1' AND (
      coalesce(jsonb_typeof(review->'clinicalReviewerIds'),'')<>'array'
      OR jsonb_array_length(review->'clinicalReviewerIds')=0
      OR clinical_reviewer_id=''
      OR NOT review->'clinicalReviewerIds' ? clinical_reviewer_id)) THEN
  RAISE EXCEPTION 'Complete permitted knowledge review evidence is required' USING ERRCODE='22023';
 END IF;
 RETURN NEW;
END $$;


-- Bind the recorded package policy to review/publish; serialize against policy changes.
CREATE OR REPLACE FUNCTION nutrition.require_catalog_package_policy() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE policy text;
BEGIN
 IF NEW.status IN ('reviewed','published') AND NEW.status IS DISTINCT FROM OLD.status THEN
  SELECT review_policy INTO policy FROM nutrition.catalog_review_policy WHERE id=1 FOR SHARE;
  IF NEW.review_policy IS DISTINCT FROM policy THEN
   RAISE EXCEPTION 'Package policy differs from database policy' USING ERRCODE='22023';
  END IF;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS require_catalog_package_policy ON nutrition.catalog_packages;
CREATE TRIGGER require_catalog_package_policy BEFORE UPDATE ON nutrition.catalog_packages
 FOR EACH ROW EXECUTE FUNCTION nutrition.require_catalog_package_policy();
CREATE OR REPLACE FUNCTION nutrition.published_catalog_review_policies() RETURNS text[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
 SELECT coalesce(array_agg(DISTINCT review_policy),ARRAY[]::text[]) FROM nutrition.catalog_packages WHERE status='published'
$$;
REVOKE ALL ON FUNCTION nutrition.catalog_review_policy_audit_change(),nutrition.set_catalog_review_policy(text,text),
 nutrition.current_catalog_review_policy(),nutrition.is_non_medical_catalog_metadata(jsonb),
 nutrition.catalog_has_clinical_claim(jsonb),nutrition.valid_catalog_data_review(jsonb),
 nutrition.record_catalog_release_evidence(uuid,text,jsonb,jsonb),nutrition.require_catalog_knowledge_review(),
 nutrition.require_catalog_package_policy(),nutrition.published_catalog_review_policies() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION nutrition.record_catalog_release_evidence(uuid,text,jsonb,jsonb) TO nutrition_catalog_reviewer;
GRANT EXECUTE ON FUNCTION nutrition.current_catalog_review_policy(),nutrition.published_catalog_review_policies() TO nutrition_catalog_reviewer,nutrition_catalog_publisher;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='nutrition_app') THEN
  REVOKE ALL ON nutrition.catalog_review_policy,nutrition.catalog_review_policy_audit FROM nutrition_app;
  GRANT EXECUTE ON FUNCTION nutrition.current_catalog_review_policy(),nutrition.published_catalog_review_policies() TO nutrition_app;
 END IF;
END $$;
COMMIT;
