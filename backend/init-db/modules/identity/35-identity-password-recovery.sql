-- Khôi phục mật khẩu, xác minh email và hàng đợi SMTP bền vững.
-- Không tự xác minh email cũ: chỉ ghi nhận từ bằng chứng OTP/Google hoặc mã profile.
BEGIN;
ALTER TABLE identity.users ADD COLUMN IF NOT EXISTS email_verified_at timestamptz;
ALTER TABLE identity.users ADD COLUMN IF NOT EXISTS recovery_version bigint NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS identity.recovery_challenges (
    id uuid PRIMARY KEY,
    user_id uuid REFERENCES identity.users(id) ON DELETE CASCADE,
    purpose varchar(30) NOT NULL CHECK (purpose IN ('RESET', 'VERIFY_EMAIL', 'CHANGE_EMAIL')),
    email varchar(255) NOT NULL,
    target_email varchar(255) NOT NULL,
    rate_key varchar(64) NOT NULL,
    recovery_version bigint NOT NULL,
    code_hash varchar(64) NOT NULL,
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    created_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    code_consumed_at timestamptz,
    grant_hash varchar(64),
    grant_expires_at timestamptz,
    consumed_at timestamptz,
    CHECK (expires_at > created_at)
);
CREATE INDEX IF NOT EXISTS ix_recovery_rate ON identity.recovery_challenges(rate_key, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_recovery_user ON identity.recovery_challenges(user_id) WHERE consumed_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_recovery_expiry ON identity.recovery_challenges(expires_at);
CREATE UNIQUE INDEX IF NOT EXISTS ux_recovery_grant ON identity.recovery_challenges(grant_hash) WHERE grant_hash IS NOT NULL;

CREATE TABLE IF NOT EXISTS identity.recovery_email_outbox (
    id uuid PRIMARY KEY,
    challenge_id uuid REFERENCES identity.recovery_challenges(id) ON DELETE CASCADE,
    payload text,
    created_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    next_attempt_at timestamptz NOT NULL,
    attempts integer NOT NULL DEFAULT 0,
    lease_until timestamptz,
    lease_id uuid,
    completed_at timestamptz,
    status varchar(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SENT', 'SKIPPED', 'FAILED'))
);
ALTER TABLE identity.recovery_email_outbox ADD COLUMN IF NOT EXISTS status varchar(20) NOT NULL DEFAULT 'PENDING';
CREATE INDEX IF NOT EXISTS ix_recovery_email_pending ON identity.recovery_email_outbox(next_attempt_at, created_at) WHERE completed_at IS NULL;
COMMIT;
