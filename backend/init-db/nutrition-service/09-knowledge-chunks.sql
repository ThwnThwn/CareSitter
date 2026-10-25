BEGIN;

-- Raw source passages are evidence for internal review, never published recipes/rules.
CREATE TABLE nutrition.knowledge_sources (
 source_revision_id text PRIMARY KEY,
 source_id text NOT NULL,
 title text NOT NULL,
 source_sha256 text NOT NULL CHECK (source_sha256 ~ '^[a-f0-9]{64}$'),
 chunks_sha256 text NOT NULL CHECK (chunks_sha256 ~ '^[a-f0-9]{64}$'),
 rights_status text NOT NULL CHECK (rights_status IN ('permitted','synthetic')),
 chunk_count integer NOT NULL CHECK (chunk_count > 0),
 imported_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE nutrition.knowledge_chunks (
 chunk_id text PRIMARY KEY,
 source_revision_id text NOT NULL REFERENCES nutrition.knowledge_sources(source_revision_id),
 pdf_page integer NOT NULL CHECK (pdf_page > 0),
 printed_page text,
 ordinal_on_page integer NOT NULL CHECK (ordinal_on_page > 0),
 content_type text NOT NULL CHECK (content_type IN ('text','table_candidate')),
 review_status text NOT NULL CHECK (review_status IN ('ready_for_retrieval_eval','manual_review_required')),
 index_eligible boolean NOT NULL,
 token_count integer NOT NULL CHECK (token_count > 0 AND token_count <= 1200),
 headings jsonb NOT NULL CHECK (jsonb_typeof(headings) = 'array'),
 content text NOT NULL CHECK (length(content) > 0),
 text_sha256 text NOT NULL CHECK (text_sha256 ~ '^[a-f0-9]{64}$'),
 UNIQUE (source_revision_id,pdf_page,ordinal_on_page),
 CHECK (index_eligible = (review_status = 'ready_for_retrieval_eval')),
 CHECK (index_eligible = (content_type = 'text' AND token_count >= 80))
);

CREATE INDEX ix_nutrition_knowledge_chunks_source_page
 ON nutrition.knowledge_chunks(source_revision_id,pdf_page,ordinal_on_page);

REVOKE ALL ON nutrition.knowledge_sources,nutrition.knowledge_chunks FROM PUBLIC;
-- nutrition_app intentionally receives no read/write grant; no app/runtime ingestion yet.

COMMIT;
