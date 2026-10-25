BEGIN;

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
    OR (release_profile='adult_baseline_source_reference_v1' AND (
      coalesce(jsonb_typeof(review->'releaseAuthorityIds'),'')<>'array'
      OR jsonb_array_length(review->'releaseAuthorityIds')=0
      OR release_authority_id=''
      OR NOT review->'releaseAuthorityIds' ? release_authority_id))
    OR (release_profile<>'adult_baseline_source_reference_v1' AND (
      coalesce(jsonb_typeof(review->'clinicalReviewerIds'),'')<>'array'
      OR jsonb_array_length(review->'clinicalReviewerIds')=0
      OR clinical_reviewer_id=''
      OR NOT review->'clinicalReviewerIds' ? clinical_reviewer_id)) THEN
  RAISE EXCEPTION 'Complete permitted knowledge review evidence is required' USING ERRCODE='22023';
 END IF;
 RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS require_catalog_knowledge_review ON nutrition.catalog_release_evidence;
CREATE TRIGGER require_catalog_knowledge_review
 BEFORE INSERT OR UPDATE OF evidence ON nutrition.catalog_release_evidence
 FOR EACH ROW EXECUTE FUNCTION nutrition.require_catalog_knowledge_review();

REVOKE ALL ON FUNCTION nutrition.require_catalog_knowledge_review() FROM PUBLIC;

COMMIT;
