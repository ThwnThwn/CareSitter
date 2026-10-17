-- Refund về phương thức thanh toán gốc. Provider được xác nhận trước khi ghi ledger.
-- Safe to replay on an existing database.

BEGIN;

CREATE TABLE IF NOT EXISTS payments.refund_requests (
  id                               uuid PRIMARY KEY,
  booking_id                       uuid NOT NULL REFERENCES booking.bookings(id),
  payment_intent_id                uuid NOT NULL REFERENCES payments.payment_intents(id),
  customer_id                      uuid NOT NULL REFERENCES identity.users(id),
  provider                         varchar(20) NOT NULL
                                   CHECK (provider IN ('VNPAY','PAYOS','MOMO','CARD')),
  amount                           bigint NOT NULL CHECK (amount > 0),
  currency                         char(3) NOT NULL DEFAULT 'VND',
  reason                           varchar(100) NOT NULL,
  request_id                       varchar(32) NOT NULL,
  original_provider_order_ref      varchar(100),
  original_provider_transaction_id varchar(255),
  original_provider_create_date    varchar(14),
  status                           varchar(30) NOT NULL
                                   CHECK (status IN ('PENDING','PROCESSING','UNKNOWN',
                                                     'MANUAL_REQUIRED','SUCCEEDED','FAILED')),
  provider_response_id             varchar(255),
  provider_refund_id               varchar(255),
  provider_transaction_status      varchar(100),
  last_error_code                  varchar(100),
  attempt_count                    int NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  requested_at                     timestamptz NOT NULL,
  submission_started_at            timestamptz,
  last_attempt_at                  timestamptz,
  next_attempt_at                  timestamptz,
  lease_id                         uuid,
  lease_until                      timestamptz,
  completed_at                     timestamptz,
  confirmed_by_admin_id            uuid REFERENCES identity.users(id),
  admin_confirmation_note          text
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_refund_request_booking
  ON payments.refund_requests (booking_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_refund_request_payment_intent
  ON payments.refund_requests (payment_intent_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_refund_request_provider_request
  ON payments.refund_requests (provider, request_id);
CREATE INDEX IF NOT EXISTS ix_refund_request_provider_work
  ON payments.refund_requests (next_attempt_at, requested_at)
  WHERE provider = 'VNPAY'
    AND status IN ('PENDING','PROCESSING','UNKNOWN');
CREATE INDEX IF NOT EXISTS ix_refund_request_manual_queue
  ON payments.refund_requests (requested_at)
  WHERE status = 'MANUAL_REQUIRED';

COMMIT;
