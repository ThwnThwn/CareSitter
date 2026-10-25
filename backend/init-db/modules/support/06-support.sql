-- ========================================================
-- 06-support.sql  |  Module schema "support"
-- ========================================================


SET search_path = support, public;


-- =====================================================================
-- 8. disputes + support_tickets + booking.checkout_reviews
-- =====================================================================
CREATE TABLE disputes (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id               uuid NOT NULL UNIQUE REFERENCES booking.bookings(id),
  raised_by_user_id        uuid NOT NULL REFERENCES identity.users(id),
  reason                   varchar(255),
  description              text,
  status                   varchar(20) NOT NULL DEFAULT 'OPEN'
                           CHECK (status IN ('OPEN','INVESTIGATING','RESOLVED','CANCELLED')),
  evidence                 jsonb,   -- gom dispute_evidence
  -- gom dispute_decisions
  decision                 varchar(20) CHECK (decision IN ('CUSTOMER_WINS','CAREGIVER_WINS','PARTIAL_REFUND')),
  refund_amount            bigint,
  caregiver_penalty_amount bigint,
  decided_by_admin_id      uuid REFERENCES identity.users(id),
  opened_at                timestamptz NOT NULL DEFAULT now(),
  resolved_at              timestamptz
);

CREATE TABLE support_tickets (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES identity.users(id),
  booking_id        uuid REFERENCES booking.bookings(id),
  type              varchar(20) NOT NULL CHECK (type IN ('COMPLAINT','SOS','PAYMENT','KYC','CHECKOUT_REVIEW','GENERAL')),
  status            varchar(20) NOT NULL DEFAULT 'NEW'
                    CHECK (status IN ('NEW','IN_PROGRESS','RESOLVED','CLOSED')),
  priority          varchar(20) NOT NULL DEFAULT 'MEDIUM'
                    CHECK (priority IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  title             varchar(255) NOT NULL,
  description       text NOT NULL,
  attachment_urls   jsonb NOT NULL DEFAULT '[]'::jsonb,
  assigned_admin_id uuid REFERENCES identity.users(id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- =====================================================================
-- 8b. reviews (F-04.03) + notifications (F-15.03)
-- =====================================================================
-- reviews: 1 review / booking; tu dong cap nhat rating_avg/count tren caregiver.
CREATE TABLE reviews (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id      uuid NOT NULL UNIQUE REFERENCES booking.bookings(id) ON DELETE CASCADE,
  caregiver_id    uuid NOT NULL REFERENCES people.caregiver_profiles(id) ON DELETE CASCADE,
  customer_id     uuid NOT NULL REFERENCES identity.users(id),
  rating          int  NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment         text,
  experience_tags jsonb,   -- ['Dung gio','Tan tam','Ky nang chuyen mon tot','Giao tiep tot']
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- notifications: inbox da doc/chua doc; push thuc te qua FCM (identity.user_devices.push_token).
CREATE TABLE notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  type       varchar(20) NOT NULL
             CHECK (type IN ('BOOKING','CARE_TIMELINE','PAYMENT','PROMOTION','SYSTEM','SOS','BOOKING_OFFER','MATCHING_FAILED')),
  title      varchar(255) NOT NULL,
  body       text,
  data       jsonb,        -- payload + deep_link
  read_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Dong bo rating_avg / rating_count tren people.caregiver_profiles khi review insert/update/delete.
CREATE OR REPLACE FUNCTION refresh_caregiver_rating(p_caregiver_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE people.caregiver_profiles c SET
    rating_count = (
      SELECT count(*) FROM support.reviews r WHERE r.caregiver_id = p_caregiver_id
    ),
    rating_avg = COALESCE((
      SELECT round(avg(r.rating), 2) FROM support.reviews r WHERE r.caregiver_id = p_caregiver_id
    ), 0)
  WHERE c.id = p_caregiver_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_caregiver_rating()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM support.refresh_caregiver_rating(OLD.caregiver_id);
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.caregiver_id IS DISTINCT FROM NEW.caregiver_id THEN
    PERFORM support.refresh_caregiver_rating(OLD.caregiver_id);
  END IF;

  PERFORM support.refresh_caregiver_rating(NEW.caregiver_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ticket_updated BEFORE UPDATE ON support_tickets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_review_sync_rating
  AFTER INSERT OR UPDATE OR DELETE ON reviews
  FOR EACH ROW EXECUTE FUNCTION sync_caregiver_rating();
