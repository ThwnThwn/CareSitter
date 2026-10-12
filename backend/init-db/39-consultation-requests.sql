-- Public consultation requests are separate from authenticated bookings.
CREATE TABLE support.consultation_requests (
    id uuid PRIMARY KEY,
    contact_name varchar(120) NOT NULL,
    phone varchar(10) NOT NULL,
    service_category varchar(40) NOT NULL,
    preferred_date date NOT NULL,
    hours smallint NOT NULL CHECK (hours IN (2, 4, 8, 12)),
    caregiver_preference varchar(120),
    note varchar(1000),
    consent_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    payload_hash varchar(64) NOT NULL,
    CONSTRAINT consultation_service CHECK
        (service_category IN ('elderly_care', 'daily_companionship', 'mobility_support'))
);
CREATE INDEX ix_consultation_requests_created_at
    ON support.consultation_requests (created_at DESC, id);
