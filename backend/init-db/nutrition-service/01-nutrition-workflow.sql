BEGIN;
CREATE SCHEMA nutrition;
CREATE TABLE nutrition.catalog_state (id integer PRIMARY KEY CHECK(id=1),revision bigint NOT NULL);
INSERT INTO nutrition.catalog_state VALUES (1,1);
CREATE TABLE nutrition.assessments (
 id uuid PRIMARY KEY, customer_id uuid NOT NULL, beneficiary_id uuid NOT NULL,
 health_revision bigint NOT NULL CHECK(health_revision > 0),
 status text NOT NULL CHECK(status IN ('queued','processing','needs_information','awaiting_confirmation','confirmed','needs_professional_guidance','failed','stale','cancelled')),
 payload jsonb NOT NULL, idempotency_key uuid NOT NULL, fingerprint text NOT NULL,
 attempt_count integer NOT NULL DEFAULT 0, lease_token uuid, lease_until timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(customer_id,idempotency_key)
);
CREATE INDEX ix_nutrition_assessment_work ON nutrition.assessments(status,lease_until,created_at);
-- Dispatcher chỉ thấy ID/scope; snapshot nhạy cảm luôn đọc trong owner scope.
CREATE TABLE nutrition.assessment_jobs (
 assessment_id uuid PRIMARY KEY REFERENCES nutrition.assessments(id) ON DELETE CASCADE,
 customer_id uuid NOT NULL, beneficiary_id uuid NOT NULL, lease_token uuid,
 lease_until timestamptz, attempt_count integer NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_nutrition_job_work ON nutrition.assessment_jobs(lease_until,created_at);
CREATE TABLE nutrition.recommendations (
 id uuid PRIMARY KEY, customer_id uuid NOT NULL, beneficiary_id uuid NOT NULL,
 health_revision bigint NOT NULL CHECK(health_revision > 0), status text NOT NULL,
 payload jsonb NOT NULL, idempotency_key uuid NOT NULL, fingerprint text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(customer_id,idempotency_key)
);
CREATE TABLE nutrition.meal_plans (LIKE nutrition.recommendations INCLUDING ALL);
CREATE INDEX ix_nutrition_recommendation_profile ON nutrition.recommendations(customer_id,beneficiary_id,created_at DESC);
CREATE INDEX ix_nutrition_plan_profile ON nutrition.meal_plans(customer_id,beneficiary_id,created_at DESC);
CREATE TABLE nutrition.preferences (
 beneficiary_id uuid PRIMARY KEY, customer_id uuid NOT NULL, revision bigint NOT NULL DEFAULT 1,
 payload jsonb NOT NULL DEFAULT '{}', updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE nutrition.concepts (code text PRIMARY KEY, kind text NOT NULL, aliases jsonb NOT NULL, version integer NOT NULL);
CREATE TABLE nutrition.recipe_versions (
 id uuid PRIMARY KEY, recipe_id uuid NOT NULL, version integer NOT NULL CHECK(version > 0),
 status text NOT NULL CHECK(status IN ('draft','published','retired')), payload jsonb NOT NULL,
 reviewed_by text, reviewed_at timestamptz, published_at timestamptz,
 UNIQUE(recipe_id,version),
 CHECK(status <> 'published' OR (reviewed_by IS NOT NULL AND length(trim(reviewed_by))>0 AND reviewed_at IS NOT NULL AND published_at IS NOT NULL))
);
CREATE TABLE nutrition.rule_versions (
 id uuid PRIMARY KEY, rule_id uuid NOT NULL, version integer NOT NULL CHECK(version > 0),
 status text NOT NULL CHECK(status IN ('draft','published','retired')), payload jsonb NOT NULL,
 reviewed_by text, reviewed_at timestamptz, published_at timestamptz,
 UNIQUE(rule_id,version),
 CHECK(status <> 'published' OR (reviewed_by IS NOT NULL AND length(trim(reviewed_by))>0 AND reviewed_at IS NOT NULL AND published_at IS NOT NULL))
);
CREATE FUNCTION nutrition.bump_catalog_revision() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN UPDATE nutrition.catalog_state SET revision=revision+1 WHERE id=1; RETURN NULL; END $$;
CREATE TRIGGER catalog_recipes AFTER INSERT OR UPDATE OR DELETE ON nutrition.recipe_versions FOR EACH STATEMENT EXECUTE FUNCTION nutrition.bump_catalog_revision();
CREATE TRIGGER catalog_rules AFTER INSERT OR UPDATE OR DELETE ON nutrition.rule_versions FOR EACH STATEMENT EXECUTE FUNCTION nutrition.bump_catalog_revision();
CREATE TRIGGER catalog_concepts AFTER INSERT OR UPDATE OR DELETE ON nutrition.concepts FOR EACH STATEMENT EXECUTE FUNCTION nutrition.bump_catalog_revision();
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['assessments','recommendations','meal_plans','preferences'] LOOP
  EXECUTE format('ALTER TABLE nutrition.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE nutrition.%I FORCE ROW LEVEL SECURITY',t);
  EXECUTE format('CREATE POLICY owner_access ON nutrition.%I USING (customer_id = nullif(current_setting(''app.current_user_id'',true),'''')::uuid) WITH CHECK (customer_id = nullif(current_setting(''app.current_user_id'',true),'''')::uuid)',t);
 END LOOP;
END $$;
-- Không seed món demo hoặc tự publish quy tắc y khoa.
COMMIT;
