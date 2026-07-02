-- ========================================================
-- 01-identity.sql  |  Module schema "identity"
-- ========================================================


SET search_path = identity, public;


-- ========================================================
-- 01-schema.sql (intermediate)
-- ========================================================

-- =====================================================================
-- 1. users (gom customer_profiles + admin_profiles + user_roles)
--    FK avatar_media_id / default_address_id them sau (ALTER o cuoi muc 1).
-- =====================================================================
CREATE TABLE users (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone              varchar(20) NOT NULL,
  email              varchar(255),
  display_name       varchar(255),
  avatar_media_id    uuid,
  status             varchar(50) NOT NULL DEFAULT 'ACTIVE'
                     CHECK (status IN ('ACTIVE','SUSPENDED','LOCKED','DELETED')),
  roles              varchar(20)[] NOT NULL DEFAULT '{}'
                     CHECK (roles <@ ARRAY['CUSTOMER','CAREGIVER','ADMIN']::varchar[]),
  -- customer fields (gom customer_profiles)
  full_name          varchar(255),
  date_of_birth      date,
  gender             varchar(20) CHECK (gender IN ('MALE','FEMALE','OTHER','UNSPECIFIED')),
  default_address_id uuid,
  -- admin fields (gom admin_profiles, chi set khi la admin)
  admin_department   varchar(50) CHECK (admin_department IN ('OPERATIONS','CSKH','ACCOUNTING','MANAGEMENT')),
  admin_role         varchar(50) CHECK (admin_role IN ('SUPER_ADMIN','OPERATIONS','CSKH','ACCOUNTING')),
  admin_permissions  jsonb,
  admin_is_active    boolean,
  last_login_at      timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  deleted_at         timestamptz
);

-- =====================================================================
-- 2. user_devices + audit_logs
-- =====================================================================
CREATE TABLE user_devices (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform          varchar(20) NOT NULL CHECK (platform IN ('IOS','ANDROID','WEB')),
  push_token        text,
  device_name       varchar(255),
  biometric_enabled boolean NOT NULL DEFAULT false,
  last_seen_at      timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- audit_logs (gom booking_status_history + kyc history). MVP: bang thuong, partition khi scale.
CREATE TABLE audit_logs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  actor_role    varchar(50),
  action        varchar(150) NOT NULL,
  entity_type   varchar(100) NOT NULL,
  entity_id     uuid,
  before_data   jsonb,
  after_data    jsonb,
  ip_address    inet,
  user_agent    text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
