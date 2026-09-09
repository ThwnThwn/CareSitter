-- ========================================================
-- 04-booking.sql  |  Module schema "booking"
-- ========================================================


SET search_path = booking, public;


-- =====================================================================
-- 6. bookings + assignments + care + gps
-- =====================================================================
CREATE TABLE bookings (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id              uuid NOT NULL REFERENCES identity.users(id),
  beneficiary_id           uuid NOT NULL REFERENCES people.beneficiaries(id),
  caregiver_id             uuid REFERENCES people.caregiver_profiles(id),
  address_id               uuid NOT NULL REFERENCES catalog.addresses(id),
  service_type_id          uuid NOT NULL REFERENCES catalog.service_types(id),
  scheduled_start          timestamptz NOT NULL,
  scheduled_end            timestamptz NOT NULL,
  actual_start             timestamptz,
  actual_end               timestamptz,
  duration_minutes         int,
  required_skills          jsonb,
  care_notes               text,
  status                   varchar(50) NOT NULL DEFAULT 'DRAFT'
                           CHECK (status IN ('DRAFT','PENDING_PAYMENT','CONFIRMED','CAREGIVER_ACCEPTED',
                                  'MATCHING_FAILED',
                                  'CAREGIVER_EN_ROUTE','IN_PROGRESS','CHECKOUT_PENDING_REVIEW',
                                  'COMPLETED','CANCELLED','CRISIS','DISPUTED','REFUNDED')),
  escrow_amount            bigint NOT NULL DEFAULT 0,
  platform_fee_amount      bigint NOT NULL DEFAULT 0,
  caregiver_earning_amount bigint NOT NULL DEFAULT 0,
  price_snapshot           jsonb,
  geofence_radius_meters   int NOT NULL DEFAULT 50,
  -- subscription / dat goi dinh ky (F-02.01): tren booking-template recurrence != NULL,
  -- moi ky sinh 1 booking con voi parent_booking_id = id template.
  parent_booking_id        uuid REFERENCES bookings(id) ON DELETE SET NULL,
  recurrence               jsonb,   -- {frequency:'WEEKLY', days_of_week:[2,4,6], months:3, until:'...'}
  -- gom booking_cancellations
  cancelled_at             timestamptz,
  cancelled_by_user_id     uuid REFERENCES identity.users(id) ON DELETE SET NULL,
  cancelled_by_role        varchar(20) CHECK (cancelled_by_role IN ('CUSTOMER','CAREGIVER','ADMIN','SYSTEM')),
  cancel_reason            text,
  refund_amount            bigint,
  penalty_amount           bigint,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  -- HARDENING (004): chan ca co thoi luong <= 0
  CONSTRAINT bookings_schedule_window_check CHECK (scheduled_end > scheduled_start)
);

CREATE TABLE booking_assignments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id      uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  caregiver_id    uuid NOT NULL REFERENCES people.caregiver_profiles(id),
  assignment_type varchar(20) NOT NULL DEFAULT 'PRIMARY'
                  CHECK (assignment_type IN ('PRIMARY','REPLACEMENT','MANUAL_OVERRIDE')),
  status          varchar(20) NOT NULL DEFAULT 'OFFERED'
                  CHECK (status IN ('SUGGESTED','OFFERED','ACCEPTED','REJECTED','EXPIRED','CANCELLED')),
  rank            int,                 -- gom matching_candidates
  distance_meters int,
  score           numeric,
  score_breakdown jsonb,
  offered_at      timestamptz NOT NULL DEFAULT now(),
  responded_at    timestamptz,
  expires_at      timestamptz
);

-- HARDENING: 1 booking chi co 1 assignment ACCEPTED

CREATE TABLE care_tasks (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id     uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  name           varchar(255) NOT NULL,
  description    text,
  is_required    boolean NOT NULL DEFAULT false,
  requires_photo boolean NOT NULL DEFAULT false,
  sort_order     int NOT NULL DEFAULT 0,
  status         varchar(20) NOT NULL DEFAULT 'PENDING'
                 CHECK (status IN ('PENDING','DONE','SKIPPED')),
  completed_at   timestamptz
);

-- care_timeline_events (gom geo_events). MVP: bang thuong, partition khi scale.
CREATE TABLE care_timeline_events (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id                 uuid NOT NULL,
  caregiver_id               uuid,
  task_id                    uuid,
  event_type                 varchar(30) NOT NULL
                             CHECK (event_type IN ('CHECKIN','CHECKIN_VALID','CHECKIN_OUTSIDE_GEOFENCE',
                                     'TASK_DONE','PHOTO_UPLOADED','NOTE','CHECKOUT',
                                     'CHECKOUT_OTP_SENT','CHECKOUT_VALID',
                                     'CHECKOUT_MANUAL_REQUESTED','CHECKOUT_MANUAL_APPROVED',
                                     'CHECKOUT_MANUAL_REJECTED','GPS_LOST','SOS','SYNC_DELAYED',
                                     'LATE_CHECKIN','AUTO_CHECKOUT')),
  title                      varchar(255),
  note                       text,
  media_id                   uuid,
  coordinates                geography(Point,4326),
  distance_to_address_meters numeric,
  recorded_at                timestamptz NOT NULL DEFAULT now(),
  synced_at                  timestamptz,
  source                     varchar(20) NOT NULL DEFAULT 'ONLINE'
                             CHECK (source IN ('ONLINE','OFFLINE_SYNC','ADMIN','SYSTEM')),
  metadata                   jsonb
);

-- gps_tracks. MVP: bang thuong, partition khi scale. Live-tracking o Redis.
CREATE TABLE gps_tracks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id      uuid NOT NULL,
  caregiver_id    uuid NOT NULL,
  location        geography(Point,4326) NOT NULL,
  accuracy_meters numeric,
  speed           numeric,
  heading         numeric,
  recorded_at     timestamptz NOT NULL DEFAULT now(),
  received_at     timestamptz NOT NULL DEFAULT now()
);

-- checkout_reviews: fallback checkout thu cong khi khong lay duoc OTP nguoi nha.
CREATE TABLE checkout_reviews (
  id                            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id                    uuid NOT NULL UNIQUE REFERENCES bookings(id),
  requested_by_caregiver_id      uuid NOT NULL REFERENCES people.caregiver_profiles(id),
  reason                        text,
  evidence_snapshot             jsonb NOT NULL DEFAULT '{}'::jsonb,
  contact_attempts              jsonb NOT NULL DEFAULT '[]'::jsonb,
  status                        varchar(20) NOT NULL DEFAULT 'PENDING'
                                CHECK (status IN ('PENDING','APPROVED','REJECTED','AUTO_APPROVED')),
  requested_at                  timestamptz NOT NULL DEFAULT now(),
  reviewed_by_admin_id          uuid REFERENCES identity.users(id),
  reviewed_at                   timestamptz,
  admin_note                    text,
  auto_approve_at               timestamptz,
  resolved_at                   timestamptz,
  CHECK (jsonb_typeof(evidence_snapshot) = 'object'),
  CHECK (jsonb_typeof(contact_attempts) = 'array'),
  CHECK (
    (status = 'PENDING' AND resolved_at IS NULL)
    OR (status <> 'PENDING' AND resolved_at IS NOT NULL)
  )
);

-- HARDENING: status booking doi -> ghi identity.audit_logs (gom booking_status_history)
CREATE OR REPLACE FUNCTION log_booking_status()
RETURNS trigger AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO identity.audit_logs (actor_user_id, actor_role, action, entity_type, entity_id, after_data, created_at)
    VALUES (NULL, 'SYSTEM', 'booking.status_change', 'booking', NEW.id,
            jsonb_build_object('from', OLD.status, 'to', NEW.status), now());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bookings_updated BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_booking_status_audit
  AFTER UPDATE OF status ON bookings
  FOR EACH ROW EXECUTE FUNCTION log_booking_status();
