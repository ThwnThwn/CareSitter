-- payOS caregiver payouts: provider state is durable and wallet money is only
-- released after a signed provider response confirms success.
-- Safe to run repeatedly.

BEGIN;

ALTER TABLE payments.payout_requests
  ADD COLUMN IF NOT EXISTS bank_bin varchar(6),
  ADD COLUMN IF NOT EXISTS provider varchar(20) NOT NULL DEFAULT 'PAYOS',
  ADD COLUMN IF NOT EXISTS provider_reference_id varchar(100),
  ADD COLUMN IF NOT EXISTS provider_payout_id varchar(100),
  ADD COLUMN IF NOT EXISTS provider_state varchar(100),
  ADD COLUMN IF NOT EXISTS provider_transaction_id varchar(255),
  ADD COLUMN IF NOT EXISTS provider_error_code varchar(100),
  ADD COLUMN IF NOT EXISTS provider_attempt_count int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS processing_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_provider_check_at timestamptz,
  ADD COLUMN IF NOT EXISTS next_provider_check_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;

UPDATE payments.payout_requests
SET provider_reference_id = 'CS' || replace(id::text, '-', '')
WHERE provider_reference_id IS NULL;

ALTER TABLE payments.payout_requests
  ALTER COLUMN provider_reference_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'payout_requests_bank_bin_check'
      AND connamespace = 'payments'::regnamespace
  ) THEN
    ALTER TABLE payments.payout_requests
      ADD CONSTRAINT payout_requests_bank_bin_check
      CHECK (bank_bin IS NULL OR bank_bin ~ '^[0-9]{6}$');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'payout_requests_provider_check'
      AND connamespace = 'payments'::regnamespace
  ) THEN
    ALTER TABLE payments.payout_requests
      ADD CONSTRAINT payout_requests_provider_check
      CHECK (provider = 'PAYOS');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'payout_requests_provider_attempt_count_check'
      AND connamespace = 'payments'::regnamespace
  ) THEN
    ALTER TABLE payments.payout_requests
      ADD CONSTRAINT payout_requests_provider_attempt_count_check
      CHECK (provider_attempt_count >= 0);
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_payout_provider_reference
  ON payments.payout_requests (provider, provider_reference_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_payout_provider_id
  ON payments.payout_requests (provider, provider_payout_id)
  WHERE provider_payout_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_payout_provider_work
  ON payments.payout_requests (next_provider_check_at, requested_at)
  WHERE bank_bin IS NOT NULL AND status IN ('APPROVED', 'PROCESSING');

COMMIT;
