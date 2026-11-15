-- Nhu cầu khai báo: không suy diễn kỹ năng từ ghi chú hoặc bệnh lý.
ALTER TABLE catalog.service_types ADD COLUMN IF NOT EXISTS required_caregiver_skills text[] NOT NULL DEFAULT '{}';
ALTER TABLE people.beneficiaries ADD COLUMN IF NOT EXISTS required_caregiver_skills text[] NOT NULL DEFAULT '{}';

-- Phạm vi tối thiểu theo nội dung các dịch vụ phi y tế hiện có.
-- Không tự gán thêm kỹ năng cho caregiver; profile thiếu khai báo sẽ không được gợi ý cho yêu cầu đó.
UPDATE catalog.service_types SET required_caregiver_skills = ARRAY['ho tro ve sinh ca nhan','chuan bi bua an']
WHERE code IN ('NONMED_ESSENTIAL','NONMED_DAY') AND cardinality(required_caregiver_skills) = 0;
UPDATE catalog.service_types SET required_caregiver_skills = ARRAY['dong hanh nguoi cao tuoi']
WHERE code = 'NONMED_COMPANION' AND cardinality(required_caregiver_skills) = 0;
UPDATE catalog.service_types SET required_caregiver_skills = ARRAY['ho tro ve sinh ca nhan']
WHERE code = 'NONMED_NIGHT' AND cardinality(required_caregiver_skills) = 0;

-- Bản chia sẻ cũ không có revision phải được gia đình kiểm tra/chia sẻ lại.
ALTER TABLE booking.booking_meal_plans ADD COLUMN IF NOT EXISTS health_revision bigint NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS booking.booking_meal_corrections (
    id uuid PRIMARY KEY,
    booking_id uuid NOT NULL REFERENCES booking.bookings(id),
    record_id uuid NOT NULL REFERENCES booking.booking_meal_records(id),
    revision integer NOT NULL CHECK (revision >= 2),
    outcome varchar(20) NOT NULL CHECK (outcome IN ('eaten','partly_eaten','not_eaten')),
    note varchar(1000), reason varchar(500) NOT NULL CHECK (length(trim(reason)) > 0),
    corrected_by uuid NOT NULL, corrected_at timestamptz NOT NULL,
    idempotency_key uuid NOT NULL,
    timeline_event_id uuid NOT NULL REFERENCES booking.care_timeline_events(id),
    UNIQUE (booking_id, idempotency_key), UNIQUE (record_id, revision)
);
