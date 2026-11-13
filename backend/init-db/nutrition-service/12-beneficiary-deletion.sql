-- Consume BeneficiaryDeleted atomically with the data purge and replay marker.
BEGIN;
CREATE TABLE nutrition.beneficiary_deletions (
 customer_id uuid NOT NULL, beneficiary_id uuid NOT NULL, event_id uuid NOT NULL,
 deleted_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (customer_id, beneficiary_id), UNIQUE (event_id)
);
CREATE TABLE nutrition.beneficiary_deletion_inbox (
 event_id uuid PRIMARY KEY, customer_id uuid NOT NULL, beneficiary_id uuid NOT NULL,
 processed_at timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'nutrition_app') THEN
  GRANT SELECT, INSERT ON nutrition.beneficiary_deletions, nutrition.beneficiary_deletion_inbox TO nutrition_app;
 END IF;
END $$;
COMMIT;
