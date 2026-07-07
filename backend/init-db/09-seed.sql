-- ========================================================
-- 03-seed.sql  |  Du lieu khoi tao mac dinh (SEED DATA)
-- CareSitter - dich vu cham soc nguoi gia tai nha
-- PHAM VI: PHI Y TE, TAI NHA - chi ho tro sinh hoat, cham soc tai nha, nhac lich thuoc.
--          KHONG chan doan, KHONG dieu tri, KHONG thuc hien thao tac y khoa.
-- Idempotent: UUID co dinh + ON CONFLICT (id) DO NOTHING
-- ========================================================

-- 1. Admin + vi nen tang (PLATFORM)
INSERT INTO identity.users (id, phone, email, display_name, full_name, roles, status,
                   admin_department, admin_role, admin_is_active)
VALUES
    ('a0000000-0000-0000-0000-0000000000a1', '0900000001', 'admin@caresitter.vn',
     'Super Admin', 'Quan Tri Vien', ARRAY['ADMIN']::varchar[], 'ACTIVE',
     'MANAGEMENT', 'SUPER_ADMIN', TRUE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO payments.wallet_accounts (id, user_id, account_type, available_balance, currency)
VALUES
    ('a0000000-0000-0000-0000-000000000001', NULL, 'PLATFORM', 0, 'VND')
ON CONFLICT (id) DO NOTHING;

-- 2. Loai dich vu (cac goi cham soc nguoi gia tai nha)
INSERT INTO catalog.service_types (id, code, name, description, default_duration_minutes, is_active)
VALUES
    ('a0000000-0000-0000-0000-0000000000f1', 'HOMECARE_HOURLY',
     'Cham soc tai nha theo gio', 'Ho tro sinh hoat hang ngay tai nha theo gio linh hoat', 60, TRUE),
    ('a0000000-0000-0000-0000-0000000000f2', 'HOMECARE_FULLDAY',
     'Cham soc tai nha nguyen ngay', 'Cham soc & ho tro sinh hoat tai nha tron ngay (8 tieng), phi y te', 480, TRUE),
    ('a0000000-0000-0000-0000-0000000000f3', 'POST_HOSPITAL_HOMECARE',
     'Cham soc tai nha sau xuat vien', 'Ho tro sinh hoat tai nha sau xuat vien (phi y te, khong dieu duong)', 120, TRUE),
    ('a0000000-0000-0000-0000-0000000000f4', 'MEAL_MEDICATION_REMINDER',
     'Ho tro bua an & nhac uong thuoc', 'Chuan bi bua an, nhac lich uong thuoc dung gio (khong cap phat/tiem thuoc)', 120, TRUE),
    ('a0000000-0000-0000-0000-0000000000f5', 'PERSONAL_CARE_ASSIST',
     'Ho tro ve sinh ca nhan tai nha', 'Ho tro tam rua, ve sinh ca nhan & di chuyen trong nha cho nguoi cao tuoi', 90, TRUE)
ON CONFLICT (id) DO NOTHING;

-- 3. Bang gia (VND/gio, phi nen tang 15%)
INSERT INTO catalog.pricing_rules (id, name, service_type_id, base_hourly_price,
                           night_multiplier, holiday_multiplier, platform_fee_percent,
                           dispute_window_hours, created_by_admin_id)
VALUES
    ('a0000000-0000-0000-0000-0000000000d1', 'Gia Cham soc tai nha theo gio',
     'a0000000-0000-0000-0000-0000000000f1', 70000, 1.30, 1.50, 15.00, 48,
     'a0000000-0000-0000-0000-0000000000a1'),
    ('a0000000-0000-0000-0000-0000000000d2', 'Gia Cham soc tai nha nguyen ngay',
     'a0000000-0000-0000-0000-0000000000f2', 65000, 1.30, 1.50, 15.00, 48,
     'a0000000-0000-0000-0000-0000000000a1'),
    ('a0000000-0000-0000-0000-0000000000d3', 'Gia Cham soc tai nha sau xuat vien',
     'a0000000-0000-0000-0000-0000000000f3', 90000, 1.30, 1.50, 15.00, 48,
     'a0000000-0000-0000-0000-0000000000a1'),
    ('a0000000-0000-0000-0000-0000000000d4', 'Gia Ho tro bua an ',
     'a0000000-0000-0000-0000-0000000000f4', 80000, 1.30, 1.50, 15.00, 48,
     'a0000000-0000-0000-0000-0000000000a1'),
    ('a0000000-0000-0000-0000-0000000000d5', 'Gia Ho tro ve sinh ca nhan tai nha',
     'a0000000-0000-0000-0000-0000000000f5', 75000, 1.30, 1.50, 15.00, 48,
     'a0000000-0000-0000-0000-0000000000a1')
ON CONFLICT (id) DO NOTHING;

-- 4. Du lieu mau (dev/test): 1 nguoi than + 1 nguoi cao tuoi + 1 nguoi cham
INSERT INTO identity.users (id, phone, email, display_name, full_name, gender, roles, status)
VALUES
    ('a0000000-0000-0000-0000-0000000000c1', '0911111111', 'nguoithan@example.com',
     'Chi Lan', 'Nguyen Thi Lan', 'FEMALE', ARRAY['CUSTOMER']::varchar[], 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

INSERT INTO people.beneficiaries (id, customer_id, full_name, date_of_birth, gender,
                           relationship_to_customer, mobility_note, allergies,
                           chronic_conditions, medications, care_instructions)
VALUES
    ('a0000000-0000-0000-0000-0000000000b1', 'a0000000-0000-0000-0000-0000000000c1',
     'Ong Nguyen Van Ba', '1948-03-22', 'MALE', 'Cha ruot',
     'Di lai kho khan, can gay/khung tap di, tranh cau thang',
     '["hai san"]'::jsonb,
     '["cao huyet ap","tieu duong type 2"]'::jsonb,
     '[{"name":"Amlodipine","dosage":"5mg","schedule":"07:00 moi ngay","instruction":"uong sau an sang","is_active":true},{"name":"Metformin","dosage":"500mg","schedule":"07:00 & 19:00","instruction":"uong cung bua an","is_active":true}]'::jsonb,
     'Chuan bi bua an nhat & it duong, nhac uong thuoc dung gio (nguoi gia tu uong), di ngu truoc 21h. Neu co dau hieu bat thuong -> bao nguoi than/goi 115, khong tu xu ly y te')
ON CONFLICT (id) DO NOTHING;

INSERT INTO identity.users (id, phone, email, display_name, full_name, gender, roles, status)
VALUES
    ('a0000000-0000-0000-0000-0000000000e1', '0922222222', 'nguoicham@example.com',
     'Co Hoa', 'Tran Thi Hoa', 'FEMALE', ARRAY['CAREGIVER']::varchar[], 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

INSERT INTO payments.wallet_accounts (id, user_id, account_type, available_balance, currency)
VALUES
    ('a0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-0000000000e1',
     'CAREGIVER', 0, 'VND')
ON CONFLICT (id) DO NOTHING;

INSERT INTO people.caregiver_profiles (id, user_id, full_name, gender, bio,
                                years_of_experience, hourly_rate_expected,
                                kyc_status, availability_status, skills,
                                service_city, service_district,
                                service_center_location, service_radius_meters,
                                wallet_account_id)
VALUES
    ('a0000000-0000-0000-0000-0000000000e2', 'a0000000-0000-0000-0000-0000000000e1',
     'Tran Thi Hoa', 'FEMALE', 'Nguoi cham 5 nam kinh nghiem, chuyen cham soc nguoi cao tuoi tai nha',
     5, 75000, 'APPROVED', 'ONLINE',
     '["cham soc tai nha nguoi cao tuoi","ho tro ve sinh ca nhan","chuan bi bua an","nhac lich uong thuoc","don dep sinh hoat","so cuu co ban"]'::jsonb,
     'Ho Chi Minh', 'Quan 1',
     ST_SetSRID(ST_MakePoint(106.700, 10.776), 4326)::geography, 5000,
     'a0000000-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- 5. Dia chi mau cho customer Lan
INSERT INTO catalog.addresses (id, owner_user_id, label, full_address, ward, district, city, location, note)
VALUES
    ('a0000000-0000-0000-0000-000000000071', 'a0000000-0000-0000-0000-0000000000c1',
     'Nha rieng', '123 Nguyen Hue, Phuong Ben Nghe, Quan 1, TP. Ho Chi Minh',
     'Ben Nghe', 'Quan 1', 'Ho Chi Minh',
     ST_SetSRID(ST_MakePoint(106.702, 10.775), 4326)::geography, 'Chung cu lau 5')
ON CONFLICT (id) DO NOTHING;

UPDATE identity.users
SET default_address_id = 'a0000000-0000-0000-0000-000000000071'
WHERE id = 'a0000000-0000-0000-0000-0000000000c1' AND default_address_id IS NULL;

