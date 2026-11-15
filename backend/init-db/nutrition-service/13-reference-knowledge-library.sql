BEGIN;
-- Owner-authorized reference material is separate from clinically reviewed meal rules.
-- A source-use authorization must never be presented as an independent clinical review.
CREATE TABLE nutrition.reference_knowledge_releases (
 release_key text PRIMARY KEY CHECK (release_key ~ '^[a-z0-9][a-z0-9-]{2,119}$'),
 corpus bytea NOT NULL CHECK (octet_length(corpus) BETWEEN 1 AND 10485760),
 graph bytea NOT NULL CHECK (octet_length(graph) BETWEEN 1 AND 10485760),
 corpus_sha256 text NOT NULL CHECK (corpus_sha256 = encode(sha256(corpus),'hex')),
 graph_sha256 text NOT NULL CHECK (graph_sha256 = encode(sha256(graph),'hex')),
 rights_confirmed boolean NOT NULL CHECK (rights_confirmed),
 authorized_by text NOT NULL CHECK (length(trim(authorized_by)) BETWEEN 3 AND 200),
 authorization_reference text NOT NULL CHECK (length(trim(authorization_reference)) BETWEEN 10 AND 1000),
 intended_use text NOT NULL CHECK (intended_use='nutrition_reference'),
 independent_clinical_review boolean NOT NULL DEFAULT false CHECK (NOT independent_clinical_review),
 enabled boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON nutrition.reference_knowledge_releases FROM PUBLIC;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='nutrition_app') THEN
  GRANT SELECT ON nutrition.reference_knowledge_releases TO nutrition_app;
 END IF;
END $$;
COMMIT;
