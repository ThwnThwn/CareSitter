-- Race-condition hardening for payout idempotency and ledger ownership.
-- Safe to run repeatedly.

BEGIN;

ALTER TABLE payments.payout_requests
  ADD COLUMN IF NOT EXISTS idempotency_key varchar(100);

UPDATE payments.payout_requests
SET idempotency_key = id::text
WHERE idempotency_key IS NULL OR btrim(idempotency_key) = '';

ALTER TABLE payments.payout_requests
  ALTER COLUMN idempotency_key SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_payout_caregiver_idempotency
  ON payments.payout_requests (caregiver_id, idempotency_key);

ALTER TABLE payments.ledger_entries
  ADD COLUMN IF NOT EXISTS payout_request_id uuid;

UPDATE payments.ledger_entries ledger
SET payout_request_id = (ledger.metadata->>'payout_request_id')::uuid
WHERE ledger.payout_request_id IS NULL
  AND ledger.transaction_type = 'PAYOUT'
  AND ledger.metadata ? 'payout_request_id'
  AND ledger.metadata->>'payout_request_id'
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ledger_entries_payout_request_id_fkey'
      AND connamespace = 'payments'::regnamespace
  ) THEN
    ALTER TABLE payments.ledger_entries
      ADD CONSTRAINT ledger_entries_payout_request_id_fkey
      FOREIGN KEY (payout_request_id) REFERENCES payments.payout_requests(id);
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_ledger_payout_request
  ON payments.ledger_entries (payout_request_id)
  WHERE payout_request_id IS NOT NULL;

-- Legacy requests deducted available_balance directly. Reconstruct the amount
-- still reserved for requests that have not yet been approved or rejected.
UPDATE payments.wallet_accounts wallet
SET pending_balance = COALESCE((
      SELECT sum(payout.amount)
      FROM payments.payout_requests payout
      WHERE payout.wallet_account_id = wallet.id
        AND payout.status IN ('PENDING', 'PROCESSING')
    ), 0),
    updated_at = now()
WHERE wallet.account_type = 'CAREGIVER';

COMMIT;
