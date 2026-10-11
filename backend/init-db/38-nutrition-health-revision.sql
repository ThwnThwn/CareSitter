BEGIN;
ALTER TABLE people.beneficiaries
    ADD COLUMN health_profile_revision bigint NOT NULL DEFAULT 1,
    ADD COLUMN food_allergy_status text NOT NULL DEFAULT 'unknown',
    ADD COLUMN food_allergy_confirmed_at timestamptz,
    ADD COLUMN food_allergy_confirmed_by uuid;
ALTER TABLE people.beneficiaries ADD CONSTRAINT ck_beneficiary_allergy_status
    CHECK (food_allergy_status IN ('unknown', 'reported_present', 'reported_none'));
ALTER TABLE people.beneficiaries ADD CONSTRAINT ck_beneficiary_health_revision
    CHECK (health_profile_revision > 0);

-- Bảo vệ cả PUT cũ và writer SQL: thay dữ liệu sức khỏe luôn tăng revision.
-- Xác nhận dị ứng cũ bị hủy khi danh sách đổi mà không có xác nhận tường minh mới.
CREATE FUNCTION people.advance_health_revision() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.allergies IS DISTINCT FROM OLD.allergies AND
       NEW.food_allergy_confirmed_at IS NOT DISTINCT FROM OLD.food_allergy_confirmed_at THEN
        NEW.food_allergy_status := 'unknown';
        NEW.food_allergy_confirmed_at := NULL;
        NEW.food_allergy_confirmed_by := NULL;
    END IF;
    IF ROW(NEW.date_of_birth, NEW.general_note, NEW.care_instructions,
           NEW.mobility_note, NEW.care_level, NEW.health_history, NEW.allergies,
           NEW.chronic_conditions, NEW.medications, NEW.food_allergy_status,
           NEW.food_allergy_confirmed_at, NEW.food_allergy_confirmed_by)
       IS DISTINCT FROM
       ROW(OLD.date_of_birth, OLD.general_note, OLD.care_instructions,
           OLD.mobility_note, OLD.care_level, OLD.health_history, OLD.allergies,
           OLD.chronic_conditions, OLD.medications, OLD.food_allergy_status,
           OLD.food_allergy_confirmed_at, OLD.food_allergy_confirmed_by) THEN
        NEW.health_profile_revision := OLD.health_profile_revision + 1;
    ELSE
        NEW.health_profile_revision := OLD.health_profile_revision;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_beneficiaries_health_revision BEFORE UPDATE ON people.beneficiaries
    FOR EACH ROW EXECUTE FUNCTION people.advance_health_revision();
COMMIT;
