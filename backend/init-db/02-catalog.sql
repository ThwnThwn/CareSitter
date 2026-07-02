-- ========================================================
-- 02-catalog.sql  |  Module schema "catalog"
-- ========================================================


SET search_path = catalog, public;


-- media_assets (gom caregiver_documents). booking_id FK them o muc 6.
CREATE TABLE media_assets (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id        uuid REFERENCES identity.users(id) ON DELETE SET NULL,
  booking_id           uuid,
  storage_provider     varchar(50) NOT NULL CHECK (storage_provider IN ('S3','CLOUDINARY')),
  bucket               varchar(255) NOT NULL,
  object_key           text NOT NULL UNIQUE,
  url                  text,
  mime_type            varchar(100),
  size_bytes           bigint,
  checksum             text,
  media_type           varchar(50) NOT NULL
                       CHECK (media_type IN ('PHOTO','DOCUMENT','CERTIFICATE','AVATAR','MEDICAL_FILE')),
  is_sensitive         boolean NOT NULL DEFAULT false,
  exif_metadata        jsonb,
  -- gom caregiver_documents (KYC)
  document_type        varchar(50)
                       CHECK (document_type IN ('CCCD_FRONT','CCCD_BACK','PORTRAIT','NURSING_CERT',
                              'HEALTH_CERT','CRIMINAL_RECORD','OTHER')),
  verification_status  varchar(50) CHECK (verification_status IN ('PENDING','APPROVED','REJECTED')),
  rejected_reason      text,
  reviewed_by_admin_id uuid REFERENCES identity.users(id) ON DELETE SET NULL,
  reviewed_at          timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now()
);

-- addresses
CREATE TABLE addresses (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid REFERENCES identity.users(id) ON DELETE SET NULL,
  label         varchar(100),
  full_address  text NOT NULL,
  ward          varchar(100),
  district      varchar(100),
  city          varchar(100),
  country       varchar(100) NOT NULL DEFAULT 'Vietnam',
  location      geography(Point,4326) NOT NULL,
  latitude      double precision GENERATED ALWAYS AS (ST_Y(location::geometry)) STORED,
  longitude     double precision GENERATED ALWAYS AS (ST_X(location::geometry)) STORED,
  note          text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- =====================================================================
-- 5. service_types + pricing_rules
-- =====================================================================
CREATE TABLE service_types (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                     varchar(100) NOT NULL UNIQUE,
  name                     varchar(255) NOT NULL,
  description              text,
  default_duration_minutes int NOT NULL DEFAULT 60,
  is_active                boolean NOT NULL DEFAULT true
);

CREATE TABLE pricing_rules (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                 varchar(255) NOT NULL,
  service_type_id      uuid NOT NULL REFERENCES service_types(id),
  base_hourly_price    bigint NOT NULL,
  night_multiplier     numeric(5,2) NOT NULL DEFAULT 1.00,
  holiday_multiplier   numeric(5,2) NOT NULL DEFAULT 1.00,
  platform_fee_percent numeric(5,2) NOT NULL DEFAULT 15.00,
  dispute_window_hours int NOT NULL DEFAULT 48,
  holidays             jsonb,   -- gom holidays: [{date, multiplier}]
  cancellation_policy  jsonb,   -- gom cancellation_policies
  effective_from       timestamptz NOT NULL DEFAULT now(),
  effective_to         timestamptz,
  is_active            boolean NOT NULL DEFAULT true,
  created_by_admin_id  uuid REFERENCES identity.users(id)
);

CREATE TRIGGER trg_addresses_updated BEFORE UPDATE ON addresses
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
