-- ========================================================
-- 07-constraints.sql  |  Khoa ngoai lien schema (deferred)
-- Chay SAU khi tat ca bang o 01-06 da ton tai
-- ========================================================

-- FK vong cho identity.users
ALTER TABLE identity.users
  ADD CONSTRAINT fk_users_avatar FOREIGN KEY (avatar_media_id)
    REFERENCES catalog.media_assets(id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_users_default_address FOREIGN KEY (default_address_id)
    REFERENCES catalog.addresses(id) ON DELETE SET NULL;

-- FK vong: catalog.media_assets.booking_id -> booking.bookings
ALTER TABLE catalog.media_assets
  ADD CONSTRAINT fk_media_booking FOREIGN KEY (booking_id)
    REFERENCES booking.bookings(id) ON DELETE SET NULL;

-- Evidence integrity: timeline/GPS records must point to real records.
ALTER TABLE booking.care_timeline_events
  ADD CONSTRAINT fk_timeline_booking
    FOREIGN KEY (booking_id) REFERENCES booking.bookings(id),
  ADD CONSTRAINT fk_timeline_caregiver
    FOREIGN KEY (caregiver_id) REFERENCES people.caregiver_profiles(id),
  ADD CONSTRAINT fk_timeline_task
    FOREIGN KEY (task_id) REFERENCES booking.care_tasks(id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_timeline_media
    FOREIGN KEY (media_id) REFERENCES catalog.media_assets(id) ON DELETE SET NULL;

ALTER TABLE booking.gps_tracks
  ADD CONSTRAINT fk_gps_booking
    FOREIGN KEY (booking_id) REFERENCES booking.bookings(id),
  ADD CONSTRAINT fk_gps_caregiver
    FOREIGN KEY (caregiver_id) REFERENCES people.caregiver_profiles(id);

ALTER TABLE people.caregiver_profiles
  ADD CONSTRAINT fk_caregiver_wallet FOREIGN KEY (wallet_account_id)
  REFERENCES payments.wallet_accounts(id) ON DELETE SET NULL;
