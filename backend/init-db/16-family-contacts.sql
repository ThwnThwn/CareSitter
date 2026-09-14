-- Danh ba gia dinh dung chung cho cac ho so nguoi duoc cham soc.
-- An toan khi chay lai tren database da ton tai.

BEGIN;

CREATE TABLE IF NOT EXISTS people.family_contacts (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id  uuid NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  full_name    varchar(255) NOT NULL,
  phone_number varchar(20) NOT NULL,
  note         varchar(500),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_family_contacts_customer_phone_active
  ON people.family_contacts (customer_id, phone_number)
  WHERE deleted_at IS NULL;

DROP TRIGGER IF EXISTS trg_family_contacts_updated ON people.family_contacts;
CREATE TRIGGER trg_family_contacts_updated BEFORE UPDATE ON people.family_contacts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE people.family_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE people.family_contacts FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_family_contact_owner ON people.family_contacts;
CREATE POLICY p_family_contact_owner ON people.family_contacts
  USING (customer_id = nullif(current_setting('app.current_user_id', true), '')::uuid)
  WITH CHECK (customer_id = nullif(current_setting('app.current_user_id', true), '')::uuid);

COMMIT;
