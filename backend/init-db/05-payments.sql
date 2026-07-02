-- ========================================================
-- 05-payments.sql  |  Module schema "payments"
-- ========================================================


SET search_path = payments, public;


-- =====================================================================
-- 3. wallet_accounts + people.caregiver_profiles + people.caregiver_availability
-- =====================================================================
CREATE TABLE wallet_accounts (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid REFERENCES identity.users(id) ON DELETE SET NULL,
  account_type      varchar(20) NOT NULL CHECK (account_type IN ('CAREGIVER','PLATFORM')),
  available_balance bigint NOT NULL DEFAULT 0 CHECK (available_balance >= 0),
  pending_balance   bigint NOT NULL DEFAULT 0 CHECK (pending_balance >= 0),
  currency          char(3) NOT NULL DEFAULT 'VND',
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- =====================================================================
-- 7. payment_intents + webhooks + ledger + payout
-- =====================================================================
CREATE TABLE payment_intents (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id              uuid NOT NULL REFERENCES booking.bookings(id),
  customer_id             uuid NOT NULL REFERENCES identity.users(id),
  provider                varchar(20) NOT NULL CHECK (provider IN ('VNPAY','MOMO','CARD')),
  amount                  bigint NOT NULL CHECK (amount >= 0),
  currency                char(3) NOT NULL DEFAULT 'VND',
  status                  varchar(20) NOT NULL DEFAULT 'CREATED'
                          CHECK (status IN ('CREATED','PENDING','SUCCEEDED','FAILED','CANCELLED','EXPIRED')),
  provider_transaction_id varchar(255),
  idempotency_key         varchar(255) NOT NULL UNIQUE,
  request_payload         jsonb,
  response_payload        jsonb,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE payment_webhooks (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider          varchar(20) NOT NULL CHECK (provider IN ('VNPAY','MOMO','CARD')),
  provider_event_id varchar(255) NOT NULL,
  event_type        varchar(100),
  payload           jsonb,
  processed_at      timestamptz,
  status            varchar(20) NOT NULL DEFAULT 'RECEIVED'
                    CHECK (status IN ('RECEIVED','PROCESSED','FAILED')),
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_webhook_event UNIQUE (provider, provider_event_id)
);

CREATE TABLE ledger_entries (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id        uuid REFERENCES booking.bookings(id),
  payment_intent_id uuid REFERENCES payment_intents(id),
  transaction_type  varchar(30) NOT NULL
                    CHECK (transaction_type IN ('ESCROW_LOCK','PLATFORM_FEE','CAREGIVER_EARNING',
                           'REFUND','PAYOUT','PENALTY','BONUS')),
  debit_account     varchar(100) NOT NULL,
  credit_account    varchar(100) NOT NULL,
  amount            bigint NOT NULL CHECK (amount >= 0),
  currency          char(3) NOT NULL DEFAULT 'VND',
  status            varchar(20) NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING','POSTED','REVERSED')),
  metadata          jsonb,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE payout_requests (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  caregiver_id             uuid NOT NULL REFERENCES people.caregiver_profiles(id),
  wallet_account_id        uuid NOT NULL REFERENCES wallet_accounts(id),
  amount                   bigint NOT NULL CHECK (amount >= 100000),
  -- snapshot bank (gom bank_accounts)
  bank_name                varchar(255) NOT NULL,
  account_holder_name      varchar(255) NOT NULL,
  account_number_encrypted text NOT NULL,
  status                   varchar(20) NOT NULL DEFAULT 'PENDING'
                           CHECK (status IN ('PENDING','APPROVED','REJECTED','PROCESSING','PAID','FAILED')),
  requested_at             timestamptz NOT NULL DEFAULT now(),
  reviewed_by_admin_id     uuid REFERENCES identity.users(id),
  reviewed_at              timestamptz,
  reject_reason            text
);

-- HARDENING: ledger bat bien (POSTED khong sua/xoa)
CREATE OR REPLACE FUNCTION prevent_ledger_mutation()
RETURNS trigger AS $$
BEGIN
  IF OLD.status = 'POSTED' THEN
    RAISE EXCEPTION 'Ledger entry % da POSTED, khong duoc sua/xoa. Tao entry REVERSE.', OLD.id
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- HARDENING: cap nhat vi an toan (khoa hang + validate + update balance cung txn)
-- Wallet movement suy ra tu ledger; ham nay dung khi can dieu chinh balance cache.
CREATE OR REPLACE FUNCTION wallet_apply(
  p_wallet_id    uuid,
  p_balance_type varchar,   -- 'AVAILABLE' | 'PENDING'
  p_amount       bigint
) RETURNS void AS $$
BEGIN
  IF p_balance_type NOT IN ('AVAILABLE', 'PENDING') THEN
    RAISE EXCEPTION 'Invalid wallet balance type: %', p_balance_type
      USING ERRCODE = 'check_violation';
  END IF;

  PERFORM 1 FROM wallet_accounts WHERE id = p_wallet_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet account % not found', p_wallet_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  IF p_balance_type = 'AVAILABLE' THEN
    UPDATE wallet_accounts SET available_balance = available_balance + p_amount,
           updated_at = now() WHERE id = p_wallet_id;
  ELSE
    UPDATE wallet_accounts SET pending_balance = pending_balance + p_amount,
           updated_at = now() WHERE id = p_wallet_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_wallet_updated BEFORE UPDATE ON wallet_accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- HARDENING: idempotency provider + 1 payment SUCCEEDED / booking
CREATE TRIGGER trg_payint_updated BEFORE UPDATE ON payment_intents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_ledger_no_update BEFORE UPDATE ON ledger_entries
  FOR EACH ROW WHEN (OLD.status = 'POSTED') EXECUTE FUNCTION prevent_ledger_mutation();

CREATE TRIGGER trg_ledger_no_delete BEFORE DELETE ON ledger_entries
  FOR EACH ROW EXECUTE FUNCTION prevent_ledger_mutation();
