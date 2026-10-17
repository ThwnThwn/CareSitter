-- Apply to existing CareSitter databases after 11-phase1-kyc-support-contracts.sql.
-- Fresh databases already receive this column from 04-booking.sql.
ALTER TABLE booking.booking_assignments
  ADD COLUMN IF NOT EXISTS decline_reason varchar(200);
