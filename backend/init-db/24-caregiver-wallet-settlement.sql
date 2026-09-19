-- Repair caregiver settlement ownership and wallet balances.
-- caregiverId in booking is CaregiverProfile.Id; wallet and payout ownership use Identity User.Id.
-- Safe to run repeatedly.

BEGIN;

-- Existing code stores PayoutRequest.CaregiverId as the authenticated User.Id.
-- Convert legacy rows, then align the foreign key with that contract.
UPDATE payments.payout_requests payout
SET caregiver_id = profile.user_id
FROM people.caregiver_profiles profile
WHERE payout.caregiver_id = profile.id;

ALTER TABLE payments.payout_requests
  DROP CONSTRAINT IF EXISTS payout_requests_caregiver_id_fkey;
ALTER TABLE payments.payout_requests
  ADD CONSTRAINT payout_requests_caregiver_id_fkey
  FOREIGN KEY (caregiver_id) REFERENCES identity.users(id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_wallet_caregiver_user
  ON payments.wallet_accounts (user_id)
  WHERE account_type = 'CAREGIVER' AND user_id IS NOT NULL;

INSERT INTO payments.wallet_accounts (
  id, user_id, account_type, available_balance, pending_balance, currency, created_at, updated_at
)
SELECT gen_random_uuid(), profile.user_id, 'CAREGIVER', 0, 0, 'VND', now(), now()
FROM people.caregiver_profiles profile
WHERE profile.deleted_at IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM payments.wallet_accounts wallet
    WHERE wallet.user_id = profile.user_id AND wallet.account_type = 'CAREGIVER'
  );

-- Earlier settlement code addressed the ledger with CaregiverProfile.Id, which made
-- the earning invisible to wallet history queried by Identity User.Id.
ALTER TABLE payments.ledger_entries DISABLE TRIGGER trg_ledger_no_update;
UPDATE payments.ledger_entries ledger
SET credit_account = 'wallet:caregiver:' || profile.user_id
FROM booking.bookings booking
JOIN people.caregiver_profiles profile ON profile.id = booking.caregiver_id
WHERE ledger.booking_id = booking.id
  AND ledger.transaction_type = 'CAREGIVER_EARNING'
  AND ledger.credit_account <> 'wallet:caregiver:' || profile.user_id;
ALTER TABLE payments.ledger_entries ENABLE TRIGGER trg_ledger_no_update;

-- Rebuild the cached available balance from immutable earning entries, minus payout
-- requests that already reserved or transferred funds. Rejected/failed requests do
-- not reduce the balance.
UPDATE payments.wallet_accounts wallet
SET available_balance = GREATEST(
      COALESCE((
        SELECT sum(ledger.amount)
        FROM payments.ledger_entries ledger
        WHERE ledger.transaction_type = 'CAREGIVER_EARNING'
          AND ledger.credit_account = 'wallet:caregiver:' || wallet.user_id
      ), 0)
      - COALESCE((
        SELECT sum(payout.amount)
        FROM payments.payout_requests payout
        WHERE payout.caregiver_id = wallet.user_id
          AND payout.status IN ('PENDING', 'APPROVED', 'PROCESSING', 'PAID')
      ), 0),
      0),
    updated_at = now()
WHERE wallet.account_type = 'CAREGIVER' AND wallet.user_id IS NOT NULL;

COMMIT;
