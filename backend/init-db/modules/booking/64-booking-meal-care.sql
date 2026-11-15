-- Chia sẻ thực đơn phi y tế theo ca; giữ snapshot món ăn, không sao chép hồ sơ sức khỏe.
CREATE TABLE IF NOT EXISTS booking.booking_meal_plans (
    id uuid PRIMARY KEY,
    booking_id uuid NOT NULL REFERENCES booking.bookings(id),
    plan_id uuid NOT NULL,
    planned_date date NOT NULL,
    meals_json jsonb NOT NULL CHECK (jsonb_typeof(meals_json) = 'array'),
    shared_by uuid NOT NULL,
    shared_at timestamptz NOT NULL,
    revoked_at timestamptz,
    UNIQUE (booking_id, planned_date)
);

CREATE TABLE IF NOT EXISTS booking.booking_meal_records (
    id uuid PRIMARY KEY,
    booking_id uuid NOT NULL REFERENCES booking.bookings(id),
    plan_id uuid NOT NULL,
    planned_date date NOT NULL,
    recipe_version_id uuid NOT NULL,
    meal_type varchar(20) NOT NULL CHECK (meal_type IN ('breakfast','lunch','dinner')),
    outcome varchar(20) NOT NULL CHECK (outcome IN ('eaten','partly_eaten','not_eaten')),
    note varchar(1000),
    recorded_by uuid NOT NULL,
    recorded_at timestamptz NOT NULL,
    idempotency_key uuid NOT NULL,
    timeline_event_id uuid NOT NULL REFERENCES booking.care_timeline_events(id),
    UNIQUE (booking_id, idempotency_key),
    UNIQUE (booking_id, planned_date, meal_type)
);
