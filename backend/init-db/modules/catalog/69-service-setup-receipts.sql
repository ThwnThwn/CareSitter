CREATE TABLE IF NOT EXISTS catalog.service_setup_receipts (
    admin_id uuid NOT NULL,
    request_id uuid NOT NULL,
    service_id uuid NOT NULL REFERENCES catalog.service_types(id) ON DELETE CASCADE,
    payload_hash text NOT NULL,
    PRIMARY KEY (admin_id, request_id)
);
