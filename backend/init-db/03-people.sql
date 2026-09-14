-- ========================================================
-- 03-people.sql  |  Module schema "people"
-- ========================================================


SET search_path = people, public;


-- =====================================================================
-- 4. beneficiaries (medications gom vao cot jsonb)
-- =====================================================================
CREATE TABLE beneficiaries (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id              uuid NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  full_name                varchar(255) NOT NULL,
  date_of_birth            date,
  gender                   varchar(20) CHECK (gender IN ('MALE','FEMALE','OTHER','UNSPECIFIED')),
  relationship_to_customer varchar(100),
  phone                    varchar(20),
  default_address_id       uuid REFERENCES catalog.addresses(id) ON DELETE SET NULL,
  mobility_note            text,
  general_note             text,
  health_history           jsonb,   -- gom beneficiary_health_profiles
  allergies                jsonb,
  chronic_conditions       jsonb,
  care_instructions        text,
  emergency_contacts       jsonb,   -- gom emergency_contacts
  medications              jsonb,   -- gom medications: [{name,dosage,schedule,instruction,start_date,end_date,is_active}]
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  deleted_at               timestamptz
);

CREATE TABLE caregiver_profiles (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 uuid NOT NULL UNIQUE REFERENCES identity.users(id) ON DELETE CASCADE,
  full_name               varchar(255),
  date_of_birth           date,
  gender                  varchar(20) CHECK (gender IN ('MALE','FEMALE','OTHER','UNSPECIFIED')),
  cccd_number_encrypted   text,
  cccd_hash               text,
  cccd_front_url          text,
  cccd_back_url           text,
  certificate_urls        jsonb DEFAULT '[]'::jsonb,
  bio                     text,
  years_of_experience     int,
  rating_avg              numeric(3,2) NOT NULL DEFAULT 0,
  rating_count            int NOT NULL DEFAULT 0,
  kyc_status              varchar(50) NOT NULL DEFAULT 'DRAFT'
                          CHECK (kyc_status IN ('DRAFT','PENDING','APPROVED','REJECTED','SUSPENDED')),
  availability_status     varchar(20) NOT NULL DEFAULT 'OFFLINE'
                          CHECK (availability_status IN ('ONLINE','OFFLINE','BUSY')),
  skills                  jsonb,                 -- gom skills + caregiver_skills
  service_city            varchar(100),          -- gom caregiver_service_areas
  service_district        varchar(100),
  service_center_location geography(Point,4326),
  service_radius_meters   int,
  wallet_account_id       uuid,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  deleted_at              timestamptz
);

CREATE TRIGGER trg_caregiver_updated BEFORE UPDATE ON caregiver_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_beneficiaries_updated BEFORE UPDATE ON beneficiaries
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE beneficiaries FORCE ROW LEVEL SECURITY;

-- =====================================================================
-- 9. ROW-LEVEL SECURITY cho du lieu y te (beneficiaries)
--    App phai: SET LOCAL app.current_user_id = '<uuid>'; dau moi request.
--    FORCE (004): RLS van ap ca khi app ket noi bang role so huu bang.
--    -> app_rw la role NON-OWNER, khong BYPASSRLS; migrator BYPASSRLS de seed.
-- =====================================================================
ALTER TABLE beneficiaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY p_beneficiary_owner ON beneficiaries
  USING (customer_id = nullif(current_setting('app.current_user_id', true), '')::uuid);

CREATE POLICY p_beneficiary_assigned_caregiver_read ON beneficiaries
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM booking.bookings b
      JOIN caregiver_profiles c ON c.id = b.caregiver_id
      WHERE b.beneficiary_id = beneficiaries.id
        AND c.user_id = nullif(current_setting('app.current_user_id', true), '')::uuid
        AND b.status IN (
          'CAREGIVER_ACCEPTED',
          'CAREGIVER_EN_ROUTE',
          'IN_PROGRESS',
          'CHECKOUT_PENDING_REVIEW',
          'COMPLETED'
        )
    )
  );

CREATE POLICY p_beneficiary_admin_read ON beneficiaries
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM identity.users u
      WHERE u.id = nullif(current_setting('app.current_user_id', true), '')::uuid
        AND 'ADMIN' = ANY (u.roles)
        AND COALESCE(u.admin_is_active, true) = true
    )
  );
