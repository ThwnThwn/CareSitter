-- Preserve the exact vnp_CreateDate sent to VNPAY for new payment attempts.
-- NEVER infer this from created_at or a callback's vnp_PayDate for old rows.
-- Deploy this additive migration before the updated application. Replay-safe.
ALTER TABLE payments.payment_intents
    ADD COLUMN IF NOT EXISTS provider_create_date varchar(14);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'payments.payment_intents'::regclass
          AND conname = 'ck_payment_intent_provider_create_date'
    ) THEN
        ALTER TABLE payments.payment_intents
            ADD CONSTRAINT ck_payment_intent_provider_create_date CHECK (
                provider_create_date IS NULL OR
                (provider = 'VNPAY' AND provider_create_date ~ '^[0-9]{14}$')
            );
    END IF;
END $$;
