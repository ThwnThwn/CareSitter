-- FIN03: một nguồn refund, marker phán quyết và hoàn tác ưu đãi theo tỷ lệ.
-- Safe to replay on an existing database.

BEGIN;

ALTER TABLE payments.ledger_entries
  DROP CONSTRAINT IF EXISTS ledger_entries_transaction_type_check;
ALTER TABLE payments.ledger_entries
  ADD CONSTRAINT ledger_entries_transaction_type_check CHECK (
    transaction_type IN ('ESCROW_LOCK','PLATFORM_FEE','CAREGIVER_EARNING',
      'REFUND','PAYOUT','PENALTY','BONUS','PROMOTION_SUBSIDY',
      'PROMOTION_REVERSAL','DISPUTE_RESOLUTION'));

DROP INDEX IF EXISTS payments.ux_ledger_booking_transaction_type;
CREATE UNIQUE INDEX ux_ledger_booking_transaction_type
  ON payments.ledger_entries (booking_id, transaction_type)
  WHERE booking_id IS NOT NULL
    AND transaction_type IN ('ESCROW_LOCK','PLATFORM_FEE','CAREGIVER_EARNING',
      'REFUND','PROMOTION_REVERSAL','DISPUTE_RESOLUTION');

CREATE INDEX IF NOT EXISTS ix_refund_request_customer_history
  ON payments.refund_requests (customer_id, requested_at DESC);

COMMIT;
