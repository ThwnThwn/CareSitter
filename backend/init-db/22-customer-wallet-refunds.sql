-- Ví CareSitter cho khách hàng và hoàn tiền tự động khi không ghép được caregiver.
-- Safe to run repeatedly on an existing database.

BEGIN;

ALTER TABLE payments.wallet_accounts
  DROP CONSTRAINT IF EXISTS wallet_accounts_account_type_check;

ALTER TABLE payments.wallet_accounts
  ADD CONSTRAINT wallet_accounts_account_type_check
  CHECK (account_type IN ('CUSTOMER', 'CAREGIVER', 'PLATFORM'));

CREATE UNIQUE INDEX IF NOT EXISTS ux_wallet_customer_user
  ON payments.wallet_accounts (user_id)
  WHERE account_type = 'CUSTOMER' AND user_id IS NOT NULL;

-- A booking can only be credited once, even if a retrying background job races.
DROP INDEX IF EXISTS payments.ux_ledger_booking_transaction_type;
DROP INDEX IF EXISTS payments.uq_ledger_booking_transaction_type;
CREATE UNIQUE INDEX ux_ledger_booking_transaction_type
  ON payments.ledger_entries (booking_id, transaction_type)
  WHERE booking_id IS NOT NULL
    AND transaction_type IN ('ESCROW_LOCK', 'PLATFORM_FEE', 'CAREGIVER_EARNING', 'REFUND');

COMMIT;
