-- Idempotency boundary between Booking's durable report queue and Support tickets.
SET search_path = support, public;

CREATE TABLE booking_chat_report_ticket_sources (
    report_id uuid PRIMARY KEY,
    ticket_id uuid NOT NULL UNIQUE REFERENCES support_tickets(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL
);
