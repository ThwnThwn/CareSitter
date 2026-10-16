BEGIN;

CREATE TABLE IF NOT EXISTS nutrition.recipe_source_citations (
 recipe_version_id uuid NOT NULL REFERENCES nutrition.recipe_versions(id),
 package_id uuid NOT NULL REFERENCES nutrition.catalog_packages(id),
 source_id text NOT NULL CHECK(source_id ~ '^[A-Z][A-Z0-9_]*$'),
 title text NOT NULL CHECK(length(trim(title)) > 0),
 organization text NOT NULL CHECK(length(trim(organization)) > 0),
 year integer NOT NULL CHECK(year BETWEEN 1900 AND 2100),
 edition text,
 chapter text,
 printed_pages text,
 pdf_pages text,
 locator text NOT NULL CHECK(length(trim(locator)) > 0),
 reference text NOT NULL CHECK(length(trim(reference)) > 0),
 verified_on date NOT NULL,
 PRIMARY KEY(recipe_version_id,source_id)
);
CREATE INDEX IF NOT EXISTS ix_nutrition_recipe_source_citations_package
 ON nutrition.recipe_source_citations(package_id);

REVOKE ALL ON nutrition.recipe_source_citations FROM PUBLIC;
DO $$
BEGIN
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='nutrition_app') THEN
  GRANT SELECT ON nutrition.recipe_source_citations TO nutrition_app;
 END IF;
END $$;

CREATE OR REPLACE FUNCTION nutrition.materialize_recipe_source_citations() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nutrition AS $$
DECLARE
 package_payload jsonb;
 recipe_entry jsonb;
 expected_count integer;
 inserted_count integer;
BEGIN
 IF NEW.content_kind<>'recipe' THEN RETURN NEW; END IF;

 SELECT p.payload INTO package_payload FROM nutrition.catalog_packages p WHERE p.id=NEW.package_id;
 SELECT value INTO recipe_entry
 FROM jsonb_array_elements(package_payload->'recipes') value
 WHERE value->'payload'->>'versionId'=NEW.version_id::text;
 IF recipe_entry IS NULL THEN
  RAISE EXCEPTION 'Catalog recipe entry is missing for source materialization' USING ERRCODE='22023';
 END IF;

 expected_count:=jsonb_array_length(recipe_entry->'payload'->'sources');
 INSERT INTO nutrition.recipe_source_citations(
  recipe_version_id,package_id,source_id,title,organization,year,edition,chapter,
  printed_pages,pdf_pages,locator,reference,verified_on)
 SELECT NEW.version_id,NEW.package_id,source.source_id,citation->>'title',citation->>'organization',
  (citation->>'year')::integer,citation->>'edition',citation->>'chapter',citation->>'printedPages',
  citation->>'pdfPages',citation->>'locator',citation->>'reference',(citation->>'verifiedOn')::date
 FROM jsonb_array_elements_text(recipe_entry->'payload'->'sources') source(source_id)
 JOIN LATERAL jsonb_array_elements(package_payload->'citations') citation
  ON citation->>'id'=source.source_id
 ON CONFLICT(recipe_version_id,source_id) DO NOTHING;
 GET DIAGNOSTICS inserted_count = ROW_COUNT;
 IF inserted_count<>expected_count THEN
  RAISE EXCEPTION 'Every recipe source must resolve to one catalog citation' USING ERRCODE='22023';
 END IF;
 RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS materialize_recipe_source_citations ON nutrition.catalog_package_entries;
CREATE TRIGGER materialize_recipe_source_citations
 AFTER INSERT ON nutrition.catalog_package_entries
 FOR EACH ROW EXECUTE FUNCTION nutrition.materialize_recipe_source_citations();

INSERT INTO nutrition.recipe_source_citations(
 recipe_version_id,package_id,source_id,title,organization,year,edition,chapter,
 printed_pages,pdf_pages,locator,reference,verified_on)
SELECT entry.version_id,entry.package_id,source.source_id,citation->>'title',citation->>'organization',
 (citation->>'year')::integer,citation->>'edition',citation->>'chapter',citation->>'printedPages',
 citation->>'pdfPages',citation->>'locator',citation->>'reference',(citation->>'verifiedOn')::date
FROM nutrition.catalog_package_entries entry
JOIN nutrition.catalog_packages package ON package.id=entry.package_id
CROSS JOIN LATERAL jsonb_array_elements(package.payload->'recipes') recipe
CROSS JOIN LATERAL jsonb_array_elements_text(recipe->'payload'->'sources') source(source_id)
JOIN LATERAL jsonb_array_elements(package.payload->'citations') citation
 ON citation->>'id'=source.source_id
WHERE entry.content_kind='recipe' AND recipe->'payload'->>'versionId'=entry.version_id::text
ON CONFLICT(recipe_version_id,source_id) DO NOTHING;

DO $$
BEGIN
 IF EXISTS (
  SELECT 1
  FROM nutrition.catalog_package_entries entry
  JOIN nutrition.catalog_packages package ON package.id=entry.package_id
  CROSS JOIN LATERAL jsonb_array_elements(package.payload->'recipes') recipe
  CROSS JOIN LATERAL jsonb_array_elements_text(recipe->'payload'->'sources') source(source_id)
  LEFT JOIN nutrition.recipe_source_citations materialized
   ON materialized.recipe_version_id=entry.version_id AND materialized.source_id=source.source_id
  WHERE entry.content_kind='recipe' AND recipe->'payload'->>'versionId'=entry.version_id::text
    AND materialized.recipe_version_id IS NULL
 ) THEN
  RAISE EXCEPTION 'Existing catalog contains an unresolved recipe citation' USING ERRCODE='22023';
 END IF;
END $$;

REVOKE ALL ON FUNCTION nutrition.materialize_recipe_source_citations() FROM PUBLIC;
COMMIT;
