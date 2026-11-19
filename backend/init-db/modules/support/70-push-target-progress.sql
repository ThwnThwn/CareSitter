ALTER TABLE support.notification_deliveries
    ADD COLUMN IF NOT EXISTS completed_push_targets text[] NOT NULL DEFAULT '{}';
