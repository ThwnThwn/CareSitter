-- ========================================================
-- 00-init.sql | Module bootstrap manifest
-- CareSitter backend (caresitter-be) - bootstrap manifest
-- ========================================================

\set ON_ERROR_STOP on

-- Bootstrap interface: Docker/PostgreSQL chỉ cần chạy file này. Nội dung schema
-- vẫn nằm theo module; thứ tự import giữ nguyên lịch sử migration và dependency.
\ir modules/shared/00-foundation.sql
\ir modules/identity/01-identity.sql
\ir modules/catalog/02-catalog.sql
\ir modules/people/03-people.sql
\ir modules/booking/04-booking.sql
\ir modules/payments/05-payments.sql
\ir modules/support/06-support.sql
\ir modules/shared/07-constraints.sql
\ir modules/booking/08-booking-sync.sql
\ir modules/shared/08-indexes.sql
\ir modules/shared/09-seed.sql
\ir modules/shared/10-vnpay-sandbox-upgrade.sql
\ir modules/shared/11-phase1-kyc-support-contracts.sql
\ir modules/booking/12-booking-offer-realtime.sql
\ir modules/payments/12-payments-outbox.sql
\ir modules/identity/13-notification-device-hardening.sql
\ir modules/identity/14-refresh-token-sessions.sql
\ir modules/shared/15-payment-reconciliation.sql
\ir modules/people/16-family-contacts.sql
\ir modules/shared/17-checklist-snapshots.sql
\ir modules/shared/18-checklist-ad-hoc-policy.sql
\ir modules/people/19-drop-caregiver-availability.sql
\ir modules/booking/20-backfill-active-booking-checklists.sql
\ir modules/people/21-drop-caregiver-hourly-rate.sql
\ir modules/payments/22-customer-wallet-refunds.sql
\ir modules/people/23-beneficiary-profile-fields.sql
\ir modules/payments/24-caregiver-wallet-settlement.sql
\ir modules/payments/25-race-condition-hardening.sql
\ir modules/shared/26-security-audit-hardening.sql
\ir modules/shared/27-phase8-transaction-integrity.sql
\ir modules/identity/28-identity-avatar-url.sql
\ir modules/promotion/29-promotions.sql
\ir modules/booking/30-booking-coordinate-columns.sql
\ir modules/payments/31-vnpay-original-create-date.sql
\ir modules/shared/32-secure-kyc-media.sql
\ir modules/booking/33-booking-live-locations.sql
\ir modules/shared/34-kafka-messaging.sql
\ir modules/identity/35-identity-password-recovery.sql
\ir modules/payments/36-payos-payments.sql
\ir modules/people/37-beneficiary-self-profile.sql
\ir modules/people/38-nutrition-health-revision.sql
\ir modules/support/39-consultation-requests.sql
\ir modules/support/40-support-chat.sql
\ir modules/payments/41-payos-caregiver-payouts.sql
\ir modules/payments/42-original-payment-refunds.sql
\ir modules/payments/43-fin03-dispute-refund-policy.sql
