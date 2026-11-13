\set ON_ERROR_STOP on
-- Integrity alone is true for an empty catalog; require all three published meals too.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT nutrition.published_catalog_integrity()
 AND EXISTS (SELECT 1 FROM nutrition.catalog_state WHERE id=1 AND revision>0)
 AND NOT EXISTS (
   SELECT 1 FROM (VALUES ('breakfast'),('lunch'),('dinner')) meal(kind)
   WHERE NOT EXISTS (
     SELECT 1 FROM nutrition.recipe_versions r
     WHERE r.status='published' AND r.payload->>'mealType'=meal.kind
       AND r.reviewed_by IS NOT NULL AND r.reviewed_at IS NOT NULL AND r.published_at IS NOT NULL
   )
 ) AS catalog_valid \gset
\if :catalog_valid
\else
\echo 'Published catalog missing or invalid. Complete independent review and publish before deployment.'
\quit 3
\endif
-- Production base never accepts the academic non_medical_reference catalog policy (R2c).
-- SQL 11 is applied by migrate.sh first; a missing function fails closed.
SELECT nutrition.current_catalog_review_policy()='source_and_clinical'
 AND NOT 'non_medical_reference'=ANY(nutrition.published_catalog_review_policies()) AS policy_valid \gset
\if :policy_valid
\else
\echo 'Catalog review policy is non_medical_reference. That policy is for the academic demo only, never production.'
\quit 3
\endif
COMMIT;
