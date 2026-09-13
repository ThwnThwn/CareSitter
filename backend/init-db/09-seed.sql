-- ========================================================
-- 03-seed.sql  |  Du lieu khoi tao mac dinh (SEED DATA)
-- CareSitter - dich vu cham soc nguoi gia tai nha
-- PHAM VI: PHI Y TE, TAI NHA - chi ho tro sinh hoat, cham soc tai nha, nhac lich thuoc.
--          KHONG chan doan, KHONG dieu tri, KHONG thuc hien thao tac y khoa.
-- Idempotent: UUID co dinh + ON CONFLICT (id) DO NOTHING
-- ========================================================

-- 1. Admin + vi nen tang (PLATFORM)
INSERT INTO identity.users (id, phone, email, display_name, full_name, roles, status,
                   admin_department, admin_role, admin_is_active, password_hash)
VALUES
    ('a0000000-0000-0000-0000-0000000000a1', '0900000001', 'admin@caresitter.vn',
     'Super Admin', 'Quan Tri Vien', ARRAY['ADMIN']::varchar[], 'ACTIVE',
     'MANAGEMENT', 'SUPER_ADMIN', TRUE, '$2a$12$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy')
ON CONFLICT (id) DO UPDATE SET password_hash = EXCLUDED.password_hash;

INSERT INTO payments.wallet_accounts (id, user_id, account_type, available_balance, currency)
VALUES
    ('a0000000-0000-0000-0000-000000000001', NULL, 'PLATFORM', 0, 'VND')
ON CONFLICT (id) DO NOTHING;

-- 2. Loai dich vu (6 goi cham soc nguoi cao tuoi chuan Genki)
INSERT INTO catalog.service_types (id, code, name, description, default_duration_minutes, is_active)
VALUES
    ('a0000000-0000-0000-0000-0000000000f1', 'GENKI_DUONG',
     'Gói DƯỠNG (Thể chất & Sinh hoạt)', 'Hỗ trợ vệ sinh cá nhân, chuẩn bị bữa ăn dinh dưỡng, nhắc lịch thuốc, vận động nhẹ nhàng', 120, TRUE),
    ('a0000000-0000-0000-0000-0000000000f2', 'GENKI_AN',
     'Gói AN (Trí lực & Thư giãn)', 'Gói Dưỡng + Kích hoạt trí não (chơi cờ, vẽ tranh, đọc sách), xoa bóp bấm huyệt, đo huyết áp', 240, TRUE),
    ('a0000000-0000-0000-0000-0000000000f3', 'GENKI_TAM',
     'Gói TÂM (Toàn diện & Phục hồi)', 'Gói An + Hỗ trợ phục hồi chức năng, lăn trở chống loét, chế độ ăn bệnh lý, Caregiver chuẩn Kaigo 1:1', 480, TRUE),
    ('a0000000-0000-0000-0000-0000000000f4', 'GENKI_PHUCHOI',
     'Gói PHỤC HỒI (Vận động & Trị liệu)', 'Phục hồi chức năng sau tai biến/chấn thương, bài tập vận động Kaigo, xoa bóp bấm huyệt lưu thông khí huyết', 120, TRUE),
    ('a0000000-0000-0000-0000-0000000000f5', 'GENKI_DONGHANH',
     'Gói ĐỒNG HÀNH (Khám bệnh & Tản bộ)', 'Đồng hành cùng người cao tuổi đi khám bệnh định kỳ, nhận thuốc, tản bộ ngoài trời, hỗ trợ xe lăn an toàn', 180, TRUE),
    ('a0000000-0000-0000-0000-0000000000f6', 'GENKI_DEM',
     'Gói ĐÊM (Trực đêm & Giấc ngủ)', 'Chăm sóc và túc trực ban đêm (22h - 6h), hỗ trợ đi vệ sinh đêm chống té ngã, nhắc uống thuốc và xử lý khẩn cấp', 480, TRUE)
ON CONFLICT (id) DO UPDATE SET
    code = EXCLUDED.code,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    default_duration_minutes = EXCLUDED.default_duration_minutes,
    is_active = EXCLUDED.is_active;

-- 3. Bang gia (VND/gio, phi nen tang 15%)
INSERT INTO catalog.pricing_rules (id, name, service_type_id, base_hourly_price,
                           night_multiplier, holiday_multiplier, platform_fee_percent,
                           dispute_window_hours, created_by_admin_id)
VALUES
    ('a0000000-0000-0000-0000-0000000000d1', 'Giá Gói DƯỠNG',
     'a0000000-0000-0000-0000-0000000000f1', 75000, 1.30, 1.50, 15.00, 48,
     'a0000000-0000-0000-0000-0000000000a1'),
    ('a0000000-0000-0000-0000-0000000000d2', 'Giá Gói AN',
     'a0000000-0000-0000-0000-0000000000f2', 95000, 1.30, 1.50, 15.00, 48,
     'a0000000-0000-0000-0000-0000000000a1'),
    ('a0000000-0000-0000-0000-0000000000d3', 'Giá Gói TÂM',
     'a0000000-0000-0000-0000-0000000000f3', 130000, 1.30, 1.50, 15.00, 48,
     'a0000000-0000-0000-0000-0000000000a1'),
    ('a0000000-0000-0000-0000-0000000000d4', 'Giá Gói PHỤC HỒI',
     'a0000000-0000-0000-0000-0000000000f4', 110000, 1.30, 1.50, 15.00, 48,
     'a0000000-0000-0000-0000-0000000000a1'),
    ('a0000000-0000-0000-0000-0000000000d5', 'Giá Gói ĐỒNG HÀNH',
     'a0000000-0000-0000-0000-0000000000f5', 85000, 1.30, 1.50, 15.00, 48,
     'a0000000-0000-0000-0000-0000000000a1'),
    ('a0000000-0000-0000-0000-0000000000d6', 'Giá Gói ĐÊM',
     'a0000000-0000-0000-0000-0000000000f6', 105000, 1.30, 1.50, 15.00, 48,
     'a0000000-0000-0000-0000-0000000000a1')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    service_type_id = EXCLUDED.service_type_id,
    base_hourly_price = EXCLUDED.base_hourly_price,
    night_multiplier = EXCLUDED.night_multiplier,
    holiday_multiplier = EXCLUDED.holiday_multiplier,
    platform_fee_percent = EXCLUDED.platform_fee_percent,
    dispute_window_hours = EXCLUDED.dispute_window_hours,
    created_by_admin_id = EXCLUDED.created_by_admin_id;

-- 4. Du lieu mau (dev/test): 1 nguoi than + 1 nguoi cao tuoi + 1 nguoi cham
INSERT INTO identity.users (id, phone, email, display_name, full_name, gender, roles, status, password_hash)
VALUES
    ('a0000000-0000-0000-0000-0000000000c1', '0911111111', 'nguoithan@example.com',
     'Chi Lan', 'Nguyen Thi Lan', 'FEMALE', ARRAY['CUSTOMER']::varchar[], 'ACTIVE', '$2a$12$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy')
ON CONFLICT (id) DO UPDATE SET password_hash = EXCLUDED.password_hash;

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

INSERT INTO identity.users (id, phone, email, display_name, full_name, gender, roles, status, password_hash)
VALUES
    ('a0000000-0000-0000-0000-0000000000e1', '0922222222', 'nguoicham@example.com',
     'Co Hoa', 'Tran Thi Hoa', 'FEMALE', ARRAY['CAREGIVER']::varchar[], 'ACTIVE', '$2a$12$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy')
ON CONFLICT (id) DO UPDATE SET password_hash = EXCLUDED.password_hash;

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

-- Caregiver 2: Nguyen Thi Bich Ngoc
INSERT INTO identity.users (id, phone, email, display_name, full_name, gender, roles, status, password_hash)
VALUES ('a0000000-0000-0000-0000-0000000000e3', '0912333444', 'bichngoc@example.com',
        'Co Ngoc', 'Nguyen Thi Bich Ngoc', 'FEMALE', ARRAY['CAREGIVER']::varchar[], 'ACTIVE', '$2a$12$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy')
ON CONFLICT (id) DO UPDATE SET password_hash = EXCLUDED.password_hash;

INSERT INTO payments.wallet_accounts (id, user_id, account_type, available_balance, currency)
VALUES ('a0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-0000000000e3', 'CAREGIVER', 0, 'VND')
ON CONFLICT (id) DO NOTHING;

INSERT INTO people.caregiver_profiles (id, user_id, full_name, gender, bio,
                                years_of_experience, hourly_rate_expected,
                                kyc_status, availability_status, skills,
                                service_city, service_district,
                                service_center_location, service_radius_meters,
                                wallet_account_id)
VALUES ('a0000000-0000-0000-0000-0000000000e4', 'a0000000-0000-0000-0000-0000000000e3',
        'Nguyen Thi Bich Ngoc', 'FEMALE', 'Caregiver 5 nam kinh nghiem, chuyen cham soc tre em va nguoi cao tuoi, co chung chi Montessori',
        5, 85000, 'APPROVED', 'ONLINE',
        '["cham soc tre em","dong hanh nguoi cao tuoi","nau an","day ky nang song","ho tro ve sinh ca nhan"]'::jsonb,
        'Ho Chi Minh', 'Quan 3',
        ST_SetSRID(ST_MakePoint(106.688, 10.782), 4326)::geography, 6000,
        'a0000000-0000-0000-0000-000000000003')
ON CONFLICT (id) DO NOTHING;

-- Caregiver 3: Le Van Hung
INSERT INTO identity.users (id, phone, email, display_name, full_name, gender, roles, status, password_hash)
VALUES ('a0000000-0000-0000-0000-0000000000e5', '0934555666', 'levanhung@example.com',
        'Anh Hung', 'Le Van Hung', 'MALE', ARRAY['CAREGIVER']::varchar[], 'ACTIVE', '$2a$12$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy')
ON CONFLICT (id) DO UPDATE SET password_hash = EXCLUDED.password_hash;

INSERT INTO payments.wallet_accounts (id, user_id, account_type, available_balance, currency)
VALUES ('a0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-0000000000e5', 'CAREGIVER', 0, 'VND')
ON CONFLICT (id) DO NOTHING;

INSERT INTO people.caregiver_profiles (id, user_id, full_name, gender, bio,
                                years_of_experience, hourly_rate_expected,
                                kyc_status, availability_status, skills,
                                service_city, service_district,
                                service_center_location, service_radius_meters,
                                wallet_account_id)
VALUES ('a0000000-0000-0000-0000-0000000000e6', 'a0000000-0000-0000-0000-0000000000e5',
        'Le Van Hung', 'MALE', 'Caregiver 3 nam kinh nghiem, dong hanh nguoi lon tuoi, lai xe dua don, nau an theo khau vi',
        3, 75000, 'APPROVED', 'ONLINE',
        '["dong hanh nguoi cao tuoi","lai xe dua don","nau an","don dep nha","ho tro van dong nhe"]'::jsonb,
        'Ho Chi Minh', 'Binh Thanh',
        ST_SetSRID(ST_MakePoint(106.712, 10.804), 4326)::geography, 7000,
        'a0000000-0000-0000-0000-000000000004')
ON CONFLICT (id) DO NOTHING;

-- Caregiver 4: Tran Thi Thanh Mai
INSERT INTO identity.users (id, phone, email, display_name, full_name, gender, roles, status, password_hash)
VALUES ('a0000000-0000-0000-0000-0000000000e7', '0978777888', 'thanhmai@example.com',
        'Co Mai', 'Tran Thi Thanh Mai', 'FEMALE', ARRAY['CAREGIVER']::varchar[], 'ACTIVE', '$2a$12$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy')
ON CONFLICT (id) DO UPDATE SET password_hash = EXCLUDED.password_hash;

INSERT INTO payments.wallet_accounts (id, user_id, account_type, available_balance, currency)
VALUES ('a0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-0000000000e7', 'CAREGIVER', 0, 'VND')
ON CONFLICT (id) DO NOTHING;

INSERT INTO people.caregiver_profiles (id, user_id, full_name, gender, bio,
                                years_of_experience, hourly_rate_expected,
                                kyc_status, availability_status, skills,
                                service_city, service_district,
                                service_center_location, service_radius_meters,
                                wallet_account_id)
VALUES ('a0000000-0000-0000-0000-0000000000e8', 'a0000000-0000-0000-0000-0000000000e7',
        'Tran Thi Thanh Mai', 'FEMALE', 'Cu nhan Giao duc Mam non 7 nam kinh nghiem, chuyen trong tre so sinh va tre nho, chung chi Montessori',
        7, 95000, 'APPROVED', 'ONLINE',
        '["trong tre so sinh","trong tre nho","giao duc som","to chuc hoat dong vui choi","cham soc nguoi cao tuoi"]'::jsonb,
        'Ho Chi Minh', 'Quan 7',
        ST_SetSRID(ST_MakePoint(106.723, 10.731), 4326)::geography, 8000,
        'a0000000-0000-0000-0000-000000000005')
ON CONFLICT (id) DO NOTHING;

-- 5. Dia chi mau cho customer Lan
INSERT INTO catalog.addresses (id, owner_user_id, label, full_address, ward, district, city, place_id, provider, verified_at, location, note)
VALUES
    ('a0000000-0000-0000-0000-000000000071', 'a0000000-0000-0000-0000-0000000000c1',
     'Nha rieng', '123 Nguyen Hue, Phuong Ben Nghe, Quan 1, TP. Ho Chi Minh',
     'Ben Nghe', 'Quan 1', 'Ho Chi Minh',
     'seed:nguyen-hue-q1-hcm', 'SEED', now(),
     ST_SetSRID(ST_MakePoint(106.702, 10.775), 4326)::geography, 'Chung cu lau 5')
ON CONFLICT (id) DO NOTHING;

UPDATE identity.users
SET default_address_id = 'a0000000-0000-0000-0000-000000000071'
WHERE id = 'a0000000-0000-0000-0000-0000000000c1' AND default_address_id IS NULL;
