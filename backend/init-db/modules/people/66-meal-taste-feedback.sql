-- Phản hồi chỉ là đề xuất; duyệt sở thích và cập nhật hồ sơ trong cùng transaction People.
CREATE TABLE IF NOT EXISTS people.meal_taste_feedback (
    id uuid PRIMARY KEY,
    owner_id uuid NOT NULL,
    beneficiary_id uuid NOT NULL REFERENCES people.beneficiaries(id),
    plan_id uuid NOT NULL, planned_date date NOT NULL,
    recipe_version_id uuid NOT NULL,
    meal_type varchar(20) NOT NULL CHECK (meal_type IN ('breakfast','lunch','dinner')),
    meal_name varchar(255) NOT NULL CHECK (length(trim(meal_name)) > 0),
    feedback varchar(20) NOT NULL CHECK (feedback IN ('liked','disliked','want_again')),
    status varchar(20) NOT NULL CHECK (status IN ('pending','approved','rejected')),
    submitted_by uuid NOT NULL CHECK (submitted_by = owner_id), submitted_by_role varchar(20) NOT NULL CHECK (submitted_by_role = 'CUSTOMER'),
    submitted_at timestamptz NOT NULL,
    idempotency_key uuid NOT NULL, fingerprint varchar(64) NOT NULL,
    reviewed_by uuid, reviewed_at timestamptz, applied_health_revision bigint,
    CHECK ((status = 'pending' AND reviewed_by IS NULL AND reviewed_at IS NULL) OR
           (status <> 'pending' AND reviewed_by IS NOT NULL AND reviewed_by = owner_id AND reviewed_at IS NOT NULL)),
    CHECK ((status = 'approved' AND applied_health_revision IS NOT NULL AND applied_health_revision >= 1) OR
           (status <> 'approved' AND applied_health_revision IS NULL)),
    UNIQUE (owner_id, beneficiary_id, submitted_by, idempotency_key)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_meal_taste_feedback_active ON people.meal_taste_feedback
    (owner_id, beneficiary_id, plan_id, recipe_version_id, submitted_by) WHERE status <> 'rejected';
CREATE INDEX IF NOT EXISTS ix_meal_taste_feedback_plan ON people.meal_taste_feedback (owner_id, beneficiary_id, plan_id, submitted_at DESC);
ALTER TABLE people.meal_taste_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE people.meal_taste_feedback FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS meal_taste_feedback_read ON people.meal_taste_feedback;
CREATE POLICY meal_taste_feedback_read ON people.meal_taste_feedback FOR SELECT USING
    (owner_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid OR
     submitted_by = NULLIF(current_setting('app.current_user_id', true), '')::uuid);
DROP POLICY IF EXISTS meal_taste_feedback_insert ON people.meal_taste_feedback;
CREATE POLICY meal_taste_feedback_insert ON people.meal_taste_feedback FOR INSERT WITH CHECK
    (submitted_by = NULLIF(current_setting('app.current_user_id', true), '')::uuid);
DROP POLICY IF EXISTS meal_taste_feedback_review ON people.meal_taste_feedback;
CREATE POLICY meal_taste_feedback_review ON people.meal_taste_feedback FOR UPDATE USING
    (owner_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid) WITH CHECK
    (owner_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid);
