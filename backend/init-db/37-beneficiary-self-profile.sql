-- Hồ sơ bản thân được tạo/link tường minh; không suy đoán hồ sơ cũ theo tên.
ALTER TABLE people.beneficiaries
    ADD COLUMN IF NOT EXISTS is_self boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS ux_beneficiaries_active_self_customer
    ON people.beneficiaries (customer_id)
    WHERE is_self = true AND deleted_at IS NULL;
