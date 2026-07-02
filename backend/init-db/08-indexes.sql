-- ========================================================
-- 08-indexes.sql  |  B-tree / GiST / partial-unique (schema-qualified)
-- ========================================================

CREATE UNIQUE INDEX uq_users_phone_active
  ON identity.users (phone) WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX uq_users_email_active
  ON identity.users (email) WHERE deleted_at IS NULL AND email IS NOT NULL;

CREATE INDEX idx_users_status ON identity.users (status);

CREATE INDEX idx_media_owner ON catalog.media_assets (owner_user_id);

CREATE INDEX idx_media_booking ON catalog.media_assets (booking_id);

CREATE INDEX idx_media_type ON catalog.media_assets (media_type);

CREATE INDEX idx_media_sensitive ON catalog.media_assets (is_sensitive);

CREATE INDEX idx_media_checksum ON catalog.media_assets (checksum) WHERE checksum IS NOT NULL;

CREATE INDEX idx_media_kyc ON catalog.media_assets (verification_status) WHERE document_type IS NOT NULL;

CREATE INDEX idx_addresses_location ON catalog.addresses USING gist (location);

CREATE INDEX idx_addresses_district ON catalog.addresses (district);

CREATE INDEX idx_addresses_city ON catalog.addresses (city);

CREATE INDEX idx_addresses_ward ON catalog.addresses (ward);

CREATE INDEX idx_user_devices_user ON identity.user_devices (user_id);

CREATE INDEX idx_user_devices_push ON identity.user_devices (push_token) WHERE push_token IS NOT NULL;

CREATE INDEX idx_user_devices_seen ON identity.user_devices (last_seen_at);

CREATE INDEX idx_audit_entity ON identity.audit_logs (entity_type, entity_id, created_at);

CREATE INDEX idx_audit_actor  ON identity.audit_logs (actor_user_id, created_at);

CREATE INDEX idx_wallet_user ON payments.wallet_accounts (user_id);

CREATE INDEX idx_wallet_type ON payments.wallet_accounts (account_type);

CREATE INDEX idx_caregiver_kyc ON people.caregiver_profiles (kyc_status);

CREATE INDEX idx_caregiver_avail_rating ON people.caregiver_profiles (availability_status, rating_avg);

CREATE INDEX idx_caregiver_service_loc ON people.caregiver_profiles USING gist (service_center_location);

CREATE UNIQUE INDEX uq_caregiver_cccd_hash
  ON people.caregiver_profiles (cccd_hash) WHERE cccd_hash IS NOT NULL;

CREATE INDEX idx_avail_caregiver_time ON people.caregiver_availability (caregiver_id, start_at, end_at);

CREATE INDEX idx_avail_status ON people.caregiver_availability (status);

CREATE INDEX idx_beneficiaries_customer ON people.beneficiaries (customer_id);

CREATE INDEX idx_service_active ON catalog.service_types (is_active);

CREATE INDEX idx_pricing_service ON catalog.pricing_rules (service_type_id);

CREATE INDEX idx_pricing_active ON catalog.pricing_rules (is_active);

CREATE INDEX idx_bookings_status_start ON booking.bookings (status, scheduled_start);

CREATE INDEX idx_bookings_customer ON booking.bookings (customer_id, scheduled_start);

CREATE INDEX idx_bookings_caregiver ON booking.bookings (caregiver_id, scheduled_start);

CREATE INDEX idx_bookings_parent ON booking.bookings (parent_booking_id) WHERE parent_booking_id IS NOT NULL;

CREATE INDEX idx_assign_booking_rank ON booking.booking_assignments (booking_id, rank);

CREATE INDEX idx_assign_caregiver ON booking.booking_assignments (caregiver_id);

CREATE INDEX idx_assign_status ON booking.booking_assignments (status);

CREATE INDEX idx_assign_expires ON booking.booking_assignments (expires_at);

CREATE UNIQUE INDEX uq_one_accepted_assignment_per_booking
  ON booking.booking_assignments (booking_id)
  WHERE status = 'ACCEPTED';

CREATE INDEX idx_caretask_booking ON booking.care_tasks (booking_id, sort_order);

CREATE INDEX idx_caretask_status ON booking.care_tasks (status);

CREATE INDEX idx_timeline_booking ON booking.care_timeline_events (booking_id, recorded_at);

CREATE INDEX idx_timeline_caregiver ON booking.care_timeline_events (caregiver_id);

CREATE INDEX idx_timeline_type ON booking.care_timeline_events (event_type);

CREATE INDEX idx_timeline_coords ON booking.care_timeline_events USING gist (coordinates);

CREATE INDEX idx_gps_location ON booking.gps_tracks USING gist (location);

CREATE INDEX idx_gps_booking ON booking.gps_tracks (booking_id, recorded_at);

CREATE INDEX idx_payint_booking ON payments.payment_intents (booking_id);

CREATE INDEX idx_payint_customer ON payments.payment_intents (customer_id);

CREATE INDEX idx_payint_status ON payments.payment_intents (status);

CREATE INDEX idx_payint_ptxn ON payments.payment_intents (provider_transaction_id) WHERE provider_transaction_id IS NOT NULL;

CREATE UNIQUE INDEX uq_provider_transaction_id
  ON payments.payment_intents (provider, provider_transaction_id)
  WHERE provider_transaction_id IS NOT NULL;

CREATE UNIQUE INDEX uq_one_successful_payment_per_booking
  ON payments.payment_intents (booking_id)
  WHERE status = 'SUCCEEDED';

CREATE INDEX idx_webhook_status ON payments.payment_webhooks (status);

CREATE INDEX idx_webhook_type ON payments.payment_webhooks (event_type);

CREATE INDEX idx_ledger_booking ON payments.ledger_entries (booking_id, created_at);

CREATE INDEX idx_ledger_payint ON payments.ledger_entries (payment_intent_id);

CREATE INDEX idx_ledger_type ON payments.ledger_entries (transaction_type);

CREATE INDEX idx_ledger_status ON payments.ledger_entries (status);

CREATE INDEX idx_payout_caregiver ON payments.payout_requests (caregiver_id);

CREATE INDEX idx_payout_status ON payments.payout_requests (status, requested_at);

CREATE INDEX idx_dispute_raised ON support.disputes (raised_by_user_id);

CREATE INDEX idx_dispute_status ON support.disputes (status, opened_at);

CREATE INDEX idx_ticket_user ON support.support_tickets (user_id);

CREATE INDEX idx_ticket_queue ON support.support_tickets (status, priority, created_at);

CREATE INDEX idx_checkout_reviews_status
  ON booking.checkout_reviews (status, requested_at);

CREATE INDEX idx_checkout_reviews_auto_approve
  ON booking.checkout_reviews (auto_approve_at)
  WHERE status = 'PENDING' AND auto_approve_at IS NOT NULL;

CREATE INDEX idx_checkout_reviews_caregiver
  ON booking.checkout_reviews (requested_by_caregiver_id, requested_at);

CREATE INDEX idx_reviews_caregiver ON support.reviews (caregiver_id, created_at);

CREATE INDEX idx_notif_user ON support.notifications (user_id, created_at DESC);

CREATE INDEX idx_notif_unread ON support.notifications (user_id) WHERE read_at IS NULL;
