# CareSitter Database Plan (Lean 25 bang)

Nguon yeu cau: `CareSitter_SRS_v1_0_2.docx`. **Schema thuc thi (nguon su that): `caresitter_lean.dbml` + `migrations/002_caresitter_lean.sql` + `migrations/003_checkout_review_hardening.sql`** — tai lieu nay mo ta kem, neu lech thi lay cac file kia lam chuan.

Tai lieu nay mo ta database CareSitter ban tinh gon (lean) cho MVP: 25 bang nghiep vu, toi uu cho doi 2 fullstack. `customer_profiles` va `admin_profiles` **gom thang vao `users`** (users giu cot identity + customer_* + admin_*); chi `caregiver_profiles` tach rieng vi nhieu field + KYC. So voi ban day du ~46 bang, ban nay da:

- Gom cac bang 1-1 va list nho vao `jsonb` (gom ca `medications` -> `beneficiaries.medications`).
- Day du lieu ephemeral (OTP login, refresh token, checkout OTP, matching tam, live GPS) sang Redis.
- Hoan cac bang Phase 2 (blog/CMS, analytics base table, offline sync, booking extension).
- MVP **khong partition** (gps_tracks/care_timeline_events/audit_logs la bang thuong); partition khi scale.

So voi ban 23 bang truoc do: them `reviews` (F-04.03), `notifications` (F-15.03), `checkout_reviews` (F-07.03 fallback checkout); them cot subscription tren `bookings` (`parent_booking_id`, `recurrence`).

Pham vi van giu duong mo rong cho GPS realtime, escrow, dispute. Khi scale lon co the tach nguoc lai cac bang da gom (xem muc 13).

## 1. Cach doc tai lieu

Ky hieu:

- `PK`: primary key.
- `FK`: foreign key.
- `UQ`: unique constraint.
- `IDX`: index nen tao.
- `jsonb`: du lieu linh hoat/snapshot, khong nen dung de thay the field can query thuong xuyen.
- Money: luu bang `bigint` don vi VND, khong dung float/decimal.
- GPS/location: dung PostGIS `geography(Point, 4326)`.

Field chuan nen co o hau het bang nghiep vu:

| Field | Kieu PostgreSQL | Muc dich |
| --- | --- | --- |
| `id` | `uuid` | Dinh danh duy nhat. |
| `created_at` | `timestamptz` | Thoi diem tao record. |
| `updated_at` | `timestamptz` | Thoi diem cap nhat cuoi. |
| `deleted_at` | `timestamptz` | Soft delete neu record user-facing can giu lich su. |

## 1.1. Type mapping chuan

| Nhom du lieu | Kieu PostgreSQL | Ghi chu |
| --- | --- | --- |
| ID | `uuid` | `gen_random_uuid()` (pgcrypto). |
| Text ngan | `varchar(n)` | code/name/phone/status text. |
| Text dai | `text` | note, description, payload text. |
| Thoi gian | `timestamptz` | Luon timezone-aware. |
| Ngay | `date` | ngay sinh, ngay le. |
| Tien VND | `bigint` | Don vi VND, khong dung float. |
| So nguyen | `int` | dem, duration, attempts, priority. |
| Ty le/he so | `numeric(5,2)` | 15.00%, x1.30, x2.00. |
| Rating | `numeric(3,2)` | 4.85. |
| Boolean | `boolean` | flag. |
| JSON | `jsonb` | snapshot, payload, list nho da gom. |
| Dia ly | `geography(Point,4326)` | can PostGIS. |
| IP | `inet` | audit. |
| Enum | `varchar(50)` + CHECK | MVP dung varchar+check de migration linh hoat. |
| Mang enum | `role_code[]` | vd `users.roles`. |

## 2. Stack de xuat

- Primary DB: PostgreSQL (14+).
- Extension: `postgis`, `pgcrypto`, `btree_gist`.
- Cache/Realtime/Ephemeral: **Redis** (bat buoc, xem muc 11).
- File storage: AWS S3 hoac Cloudinary. DB chi luu metadata.
- Search: MVP dung PostgreSQL full-text + PostGIS; scale dung Elasticsearch.

## 3. Tong quan quan he chinh

```text
users 1-1 caregiver_profiles        (chi user co role CAREGIVER)
users 1-n user_devices
users 1-n beneficiaries             (customer = user role CUSTOMER, qua customer_id)
users 1-n bookings                  (customer_id)
users 1-n notifications

beneficiaries 1-n bookings
beneficiaries .medications (jsonb)  (gom bang medications cu)

caregiver_profiles 1-1 wallet_accounts
caregiver_profiles 1-n caregiver_availability
caregiver_profiles 1-n bookings
caregiver_profiles 1-n payout_requests
caregiver_profiles 1-n reviews      (rating_avg/count = trigger tinh tu reviews)

bookings 1-n booking_assignments
bookings 1-n care_tasks
bookings 1-n care_timeline_events
bookings 1-n gps_tracks
bookings 1-n ledger_entries
bookings 0/1-1 checkout_reviews
bookings 0/1-1 disputes
bookings 0/1-1 reviews
bookings self-ref parent_booking_id (subscription: template -> cac ky con)

payment_intents 1-n ledger_entries
wallet_accounts -> balance cache (movement suy ra tu ledger_entries)

media_assets: avatar, KYC doc, anh timeline (gom caregiver_documents)
audit_logs: action history + booking status history + kyc history
```

Danh sach 25 bang theo nhom:

- **Identity (3)**: `users` (gom customer_profiles + admin_profiles), `user_devices`, `audit_logs`.
- **People (3)**: `beneficiaries` (gom medications jsonb), `caregiver_profiles`, `caregiver_availability`.
- **Shared (4)**: `media_assets`, `addresses`, `service_types`, `pricing_rules`.
- **Booking (6)**: `bookings`, `booking_assignments`, `care_tasks`, `care_timeline_events`, `gps_tracks`, `checkout_reviews`.
- **Money (5)**: `wallet_accounts`, `payment_intents`, `payment_webhooks`, `ledger_entries`, `payout_requests`.
- **Support & Engagement (4)**: `disputes`, `support_tickets`, `reviews`, `notifications`.

## 4. Identity

### 4.1 `users`

Muc dich: bang goc identity **da gom `customer_profiles` + `admin_profiles`**. Vai tro luu o mang `roles`; cot customer_* va admin_* set theo role tuong ung. Chi `caregiver_profiles` tach rieng.

Quan he:

- `users.id` -> `caregiver_profiles.user_id` (UQ, chi role CAREGIVER)
- `users.id` -> `beneficiaries.customer_id`, `bookings.customer_id`, `payment_intents.customer_id`
- `users.avatar_media_id` -> `media_assets.id`
- `users.default_address_id` -> `addresses.id`

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh user. | PK |
| `phone` | varchar(20) | SDT dang nhap OTP. | UQ (partial WHERE deleted_at IS NULL) |
| `email` | varchar(255) | Email thong bao. | UQ partial, nullable |
| `display_name` | varchar(255) | Ten hien thi. |  |
| `avatar_media_id` | uuid | Anh dai dien. | FK `media_assets.id`, nullable |
| `status` | varchar(50) | active/suspended/locked/deleted. | IDX |
| `roles` | role_code[] | Mang vai tro: CUSTOMER/CAREGIVER/ADMIN (gom `user_roles`). |  |
| `full_name` | varchar(255) | (customer) Ten day du. | gom customer_profiles |
| `date_of_birth` | date | (customer) KYC/phan tich. | nullable |
| `gender` | varchar(20) | (customer). | nullable |
| `default_address_id` | uuid | (customer) Dia chi mac dinh. | FK `addresses.id`, nullable |
| `admin_department` | varchar(50) | (admin) OPERATIONS/CSKH/ACCOUNTING/MANAGEMENT. | gom admin_profiles, nullable |
| `admin_role` | varchar(50) | (admin) SUPER_ADMIN/OPERATIONS/CSKH/ACCOUNTING. | nullable |
| `admin_permissions` | jsonb | (admin) List ma quyen (gom RBAC). | nullable |
| `admin_is_active` | boolean | (admin) Con dung dashboard. | nullable |
| `last_login_at` | timestamptz | Lan dang nhap cuoi. |  |
| `created_at` | timestamptz |  |  |
| `updated_at` | timestamptz |  |  |
| `deleted_at` | timestamptz | Soft delete. | nullable |

> Ghi chu: customer/admin gom vao `users` de giam join cho doi 2 dev. Khi can RBAC phuc tap hoac tach micro-service co the tach nguoc ra `customer_profiles`/`admin_profiles`.

### 4.2 `user_devices`

Muc dich: device/push token de gui notification + biometric login.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh thiet bi. | PK |
| `user_id` | uuid | Chu thiet bi. | FK `users.id`, IDX |
| `platform` | varchar(20) | IOS/ANDROID/WEB. |  |
| `push_token` | text | Token FCM/APNS. | IDX nullable |
| `device_name` | varchar(255) | Ten may. |  |
| `biometric_enabled` | boolean | Bat FaceID/TouchID. |  |
| `last_seen_at` | timestamptz | Thiet bi con active. | IDX |
| `created_at` | timestamptz |  |  |

Ghi chu: OTP login va refresh token **khong** co bang rieng, luu o Redis (muc 11).

### 4.3 `audit_logs`

Muc dich: log bat bien moi hanh dong quan trong **va** gom `booking_status_history` + lich su duyet KYC. PARTITION theo thang.

Quan he:

- `audit_logs.actor_user_id` -> `users.id`
- `entity_type/entity_id` polymorphic.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh log. | PK (id, created_at) |
| `actor_user_id` | uuid | Actor. | FK `users.id`, nullable |
| `actor_role` | varchar(50) | Role luc thuc hien. | IDX |
| `action` | varchar(150) | vd `kyc.approve`, `booking.status_change`, `payout.reject`. | IDX |
| `entity_type` | varchar(100) | Loai doi tuong (vd `booking`). | IDX |
| `entity_id` | uuid | ID doi tuong. | IDX |
| `before_data` | jsonb | Snapshot truoc. | nullable |
| `after_data` | jsonb | Snapshot sau (vd from/to status). | nullable |
| `ip_address` | inet | IP actor. |  |
| `user_agent` | text | Thiet bi actor. |  |
| `created_at` | timestamptz |  | IDX, partition key |

## 5. Shared: Media & Address

### 5.1 `media_assets`

Muc dich: metadata file (anh timeline, avatar, file y te) + **gom** `caregiver_documents` (KYC). File that o object storage.

Quan he:

- `media_assets.owner_user_id` -> `users.id`
- `media_assets.booking_id` -> `bookings.id`
- `media_assets.reviewed_by_admin_id` -> `users.id`

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh media. | PK |
| `owner_user_id` | uuid | Chu file (vd caregiver). | FK `users.id`, IDX nullable |
| `booking_id` | uuid | Booking neu la anh timeline. | FK `bookings.id`, nullable |
| `storage_provider` | varchar(50) | S3/CLOUDINARY. |  |
| `bucket` | varchar(255) | Bucket/folder. |  |
| `object_key` | text | Key tao signed URL. | UQ |
| `url` | text | URL; file sensitive khong public. | nullable |
| `mime_type` | varchar(100) | Loai file. |  |
| `size_bytes` | bigint | Kich thuoc. |  |
| `checksum` | text | Kiem tra trung/toan ven. | IDX nullable |
| `media_type` | varchar(50) | PHOTO/DOCUMENT/CERTIFICATE/AVATAR/MEDICAL_FILE. | IDX |
| `is_sensitive` | boolean | Can signed URL/quyen admin. | IDX |
| `exif_metadata` | jsonb | timestamp, GPS, device. |  |
| `document_type` | varchar(50) | CCCD_FRONT... (set khi la KYC doc). | nullable, gom caregiver_documents |
| `verification_status` | varchar(50) | PENDING/APPROVED/REJECTED. | nullable |
| `rejected_reason` | text | Ly do tu choi. | nullable |
| `reviewed_by_admin_id` | uuid | Admin duyet doc. | FK `users.id`, nullable |
| `reviewed_at` | timestamptz | Thoi diem duyet. | nullable |
| `created_at` | timestamptz |  | IDX |

### 5.2 `addresses`

Muc dich: dia chi + toa do cho booking, geo-fencing, nearest caregiver.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh dia chi. | PK |
| `owner_user_id` | uuid | Chu dia chi. | FK `users.id`, nullable |
| `label` | varchar(100) | Nha me, Benh vien... |  |
| `full_address` | text | Dia chi day du. |  |
| `ward` | varchar(100) | Phuong/xa. | IDX nullable |
| `district` | varchar(100) | Quan/huyen. | IDX |
| `city` | varchar(100) | Tinh/thanh. | IDX |
| `country` | varchar(100) | Mac dinh Vietnam. |  |
| `location` | geography(Point,4326) | Query khoang cach/geofence. | GiST IDX |
| `latitude` | double | Generated tu `location`. |  |
| `longitude` | double | Generated tu `location`. |  |
| `note` | text | Huong dan vao nha. | nullable |
| `created_at` | timestamptz |  |  |
| `updated_at` | timestamptz |  |  |

### 5.3 `service_types`

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh dich vu. | PK |
| `code` | varchar(100) | Ma dich vu. | UQ |
| `name` | varchar(255) | Ten hien thi. |  |
| `description` | text | Mo ta. | nullable |
| `default_duration_minutes` | int | Thoi luong mac dinh. |  |
| `is_active` | boolean | An/hien. | IDX |

### 5.4 `pricing_rules`

Muc dich: cau hinh gia dong + **gom** `holidays` va `cancellation_policies` vao jsonb.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh rule. | PK |
| `name` | varchar(255) | Ten rule. |  |
| `service_type_id` | uuid | Cho dich vu nao. | FK `service_types.id`, IDX |
| `base_hourly_price` | bigint | Gia co ban/gio. |  |
| `night_multiplier` | numeric(5,2) | He so gio dem. |  |
| `holiday_multiplier` | numeric(5,2) | He so ngay le mac dinh. |  |
| `platform_fee_percent` | numeric(5,2) | Phan tram platform giu. |  |
| `dispute_window_hours` | int | Thoi gian giu pending, mac dinh 48h. |  |
| `holidays` | jsonb | `[{date, multiplier}]` (gom bang holidays). |  |
| `cancellation_policy` | jsonb | Tier huy/refund/penalty (gom bang cancellation_policies). |  |
| `effective_from` | timestamptz | Hieu luc tu. | IDX |
| `effective_to` | timestamptz | Het hieu luc. | nullable |
| `is_active` | boolean | Dang ap dung. | IDX |
| `created_by_admin_id` | uuid | Admin tao. | FK `users.id` |

## 6. People

### 6.1 `beneficiaries`

Muc dich: nguoi thu huong. **Gom** `beneficiary_health_profiles`, `emergency_contacts` va `medications` vao jsonb.

Quan he:

- `beneficiaries.customer_id` -> `users.id` (user role CUSTOMER)
- `beneficiaries.id` -> `bookings.beneficiary_id`

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh. | PK |
| `customer_id` | uuid | Customer quan ly. | FK `users.id`, IDX |
| `full_name` | varchar(255) | Ten. |  |
| `date_of_birth` | date | Tinh tuoi. |  |
| `gender` | varchar(20) |  | nullable |
| `relationship_to_customer` | varchar(100) | bo/me/ong/ba... |  |
| `phone` | varchar(20) | Lien he truc tiep. | nullable |
| `default_address_id` | uuid | Noi cham soc. | FK `addresses.id`, nullable |
| `mobility_note` | text | Ghi chu di lai. |  |
| `general_note` | text | Luu y tong quat. |  |
| `health_history` | jsonb | Tien su benh (gom health_profiles). |  |
| `allergies` | jsonb | Di ung. |  |
| `chronic_conditions` | jsonb | Benh man tinh. |  |
| `care_instructions` | text | Huong dan cham soc. |  |
| `emergency_contacts` | jsonb | `[{name, phone, relationship, priority}]` (gom bang emergency_contacts). |  |
| `medications` | jsonb | `[{name, dosage, schedule, instruction, start_date, end_date, is_active}]` (gom bang medications). |  |
| `created_at` | timestamptz |  |  |
| `updated_at` | timestamptz |  |  |
| `deleted_at` | timestamptz | Soft delete. | nullable |

> Ghi chu: MVP phi y te chi hien thi/nhac thuoc o muc co ban -> gom `medications` vao jsonb, khong can bang rieng. Khi can query thuoc xuyen beneficiary (vd nhac lich tu dong) thi tach lai thanh bang.

### 6.3 `caregiver_profiles`

Muc dich: ho so caregiver. **Gom** `skills`/`caregiver_skills` (jsonb) va `caregiver_service_areas` (cac cot service_*).

Quan he:

- `caregiver_profiles.user_id` -> `users.id`
- `caregiver_profiles.wallet_account_id` -> `wallet_accounts.id`
- `caregiver_profiles.id` -> `bookings.caregiver_id`, `caregiver_availability`, `payout_requests`

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh. | PK |
| `user_id` | uuid | Tai khoan. | FK `users.id`, UQ |
| `full_name` | varchar(255) | Ten theo KYC. |  |
| `date_of_birth` | date |  | nullable |
| `gender` | varchar(20) |  | nullable |
| `cccd_number_encrypted` | text | CCCD ma hoa (key o KMS). | sensitive |
| `cccd_hash` | text | HMAC de check trung khong lo CCCD. | UQ partial |
| `bio` | text | Gioi thieu. |  |
| `years_of_experience` | int | Kinh nghiem. | IDX optional |
| `hourly_rate_expected` | bigint | Gia ky vong/gio. |  |
| `rating_avg` | numeric(3,2) | Diem TB. | IDX |
| `rating_count` | int | So luot rating. |  |
| `kyc_status` | varchar(50) | DRAFT/PENDING/APPROVED/REJECTED/SUSPENDED. | IDX |
| `availability_status` | varchar(20) | ONLINE/OFFLINE/BUSY (dong bo Redis). | IDX |
| `skills` | jsonb | `[{code, level}]` (gom skills + caregiver_skills). |  |
| `service_city` | varchar(100) | Khu vuc nhan ca (gom service_areas). |  |
| `service_district` | varchar(100) |  |  |
| `service_center_location` | geography(Point,4326) | Tam khu vuc. | GiST IDX |
| `service_radius_meters` | int | Ban kinh nhan ca. |  |
| `wallet_account_id` | uuid | Vi nhan tien. | FK `wallet_accounts.id`, nullable |
| `created_at` | timestamptz |  |  |
| `updated_at` | timestamptz |  |  |
| `deleted_at` | timestamptz |  | nullable |

### 6.4 `caregiver_availability`

Muc dich: lich ranh/ban/da book; chong trung ca.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh slot. | PK |
| `caregiver_id` | uuid | Caregiver. | FK `caregiver_profiles.id`, IDX |
| `start_at` | timestamptz | Bat dau. | IDX |
| `end_at` | timestamptz | Ket thuc. | IDX |
| `status` | varchar(20) | AVAILABLE/BLOCKED/BOOKED. | IDX |
| `source` | varchar(20) | CAREGIVER/BOOKING/ADMIN. |  |

Hardening: `EXCLUDE USING gist` chong 2 ca BOOKED chong gio (muc 12).

## 7. Booking

### 7.1 `bookings`

Muc dich: don cham soc. **Gom** `booking_requests` (status DRAFT) va `booking_cancellations` (cac cot cancel_*).

Quan he:

- `bookings.customer_id` -> `users.id`
- `bookings.beneficiary_id` -> `beneficiaries.id`
- `bookings.caregiver_id` -> `caregiver_profiles.id`
- `bookings.address_id` -> `addresses.id`
- `bookings.service_type_id` -> `service_types.id`
- `bookings.id` -> assignments/tasks/timeline/gps/checkout_reviews/ledger/dispute

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh. | PK |
| `customer_id` | uuid | Nguoi dat/chi tra. | FK `users.id`, IDX |
| `beneficiary_id` | uuid | Nguoi duoc cham soc. | FK `beneficiaries.id`, IDX |
| `caregiver_id` | uuid | Caregiver. | FK `caregiver_profiles.id`, IDX nullable |
| `address_id` | uuid | Noi thuc hien. | FK `addresses.id` |
| `service_type_id` | uuid | Loai dich vu. | FK `service_types.id` |
| `scheduled_start` | timestamptz | Gio bat dau du kien. | IDX |
| `scheduled_end` | timestamptz | Gio ket thuc du kien. | IDX |
| `actual_start` | timestamptz | Check-in thuc te. | nullable |
| `actual_end` | timestamptz | Check-out thuc te. | nullable |
| `duration_minutes` | int | Thoi luong. |  |
| `required_skills` | jsonb | Skill can co. |  |
| `care_notes` | text | Yeu cau rieng. |  |
| `status` | varchar(50) | DRAFT...REFUNDED (gom booking_requests). | IDX |
| `escrow_amount` | bigint | Tien tam giu. |  |
| `platform_fee_amount` | bigint | Phi nen tang. |  |
| `caregiver_earning_amount` | bigint | Thu nhap caregiver. |  |
| `price_snapshot` | jsonb | Snapshot rule gia. |  |
| `geofence_radius_meters` | int | Ban kinh check-in, vd 50m. |  |
| `cancelled_at` | timestamptz | Thoi diem huy (gom booking_cancellations). | nullable |
| `cancelled_by_user_id` | uuid | Ai huy. | FK `users.id`, nullable |
| `cancelled_by_role` | varchar(20) | CUSTOMER/CAREGIVER/ADMIN/SYSTEM. | nullable |
| `cancel_reason` | text | Ly do huy. | nullable |
| `refund_amount` | bigint | Tien hoan. | nullable |
| `penalty_amount` | bigint | Phi phat. | nullable |
| `parent_booking_id` | uuid | Subscription: booking con tro ve template. | FK `bookings.id`, nullable, IDX |
| `recurrence` | jsonb | Tren template: `{frequency, days_of_week, months, until}` (F-02.01 dat goi dinh ky). | nullable |
| `created_at` | timestamptz |  |  |
| `updated_at` | timestamptz |  |  |

Trang thai: DRAFT, PENDING_PAYMENT, CONFIRMED, CAREGIVER_ACCEPTED, CAREGIVER_EN_ROUTE, IN_PROGRESS, CHECKOUT_PENDING_REVIEW, COMPLETED, CANCELLED, CRISIS, DISPUTED, REFUNDED.

Lich su trang thai ghi sang `audit_logs` (`entity_type='booking'`).

Subscription (dat goi dinh ky): tao 1 booking **template** co `recurrence != NULL`; he thong sinh moi ky thanh 1 booking con voi `parent_booking_id = template.id`. Khong can bang series rieng.

### 7.2 `booking_assignments`

Muc dich: offer/chi dinh caregiver. **Gom** `matching_candidates` (rank/score).

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh. | PK |
| `booking_id` | uuid | Booking. | FK `bookings.id`, IDX |
| `caregiver_id` | uuid | Caregiver offer/chi dinh. | FK `caregiver_profiles.id`, IDX |
| `assignment_type` | varchar(20) | PRIMARY/REPLACEMENT/MANUAL_OVERRIDE. | IDX |
| `status` | varchar(20) | SUGGESTED/OFFERED/ACCEPTED/REJECTED/EXPIRED/CANCELLED. | IDX |
| `rank` | int | Thu hang goi y (gom matching_candidates). | nullable |
| `distance_meters` | int | Khoang cach. | nullable |
| `score` | numeric | Diem tong hop. | nullable |
| `score_breakdown` | jsonb | Ly do tinh diem. | nullable |
| `offered_at` | timestamptz | Gui offer. |  |
| `responded_at` | timestamptz | Phan hoi. | nullable |
| `expires_at` | timestamptz | Het han offer. | IDX |

Ghi chu: ranking tam thoi luc dispatch nen o Redis; chi ghi xuong day candidate duoc offer/chi dinh.

### 7.3 `care_tasks`

Muc dich: checklist cong viec trong ca.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh task. | PK |
| `booking_id` | uuid | Booking. | FK `bookings.id`, IDX |
| `name` | varchar(255) | Ten dau viec. |  |
| `description` | text | Huong dan. | nullable |
| `is_required` | boolean | Bat buoc. |  |
| `requires_photo` | boolean | Bat buoc chup anh. |  |
| `sort_order` | int | Thu tu. | IDX |
| `status` | varchar(20) | PENDING/DONE/SKIPPED. | IDX |
| `completed_at` | timestamptz |  | nullable |

### 7.4 `care_timeline_events`

Muc dich: dong thoi gian cham soc. **Gom** `geo_events` (event_type CHECKIN_VALID/GPS_LOST...). PARTITION theo thang.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh event. | PK (id, recorded_at) |
| `booking_id` | uuid | Booking. | FK, IDX |
| `caregiver_id` | uuid | Caregiver. | FK, IDX |
| `task_id` | uuid | Task lien quan. | FK `care_tasks.id`, nullable |
| `event_type` | varchar(30) | checkin/task/photo/note/checkout/SOS + geo events. | IDX |
| `title` | varchar(255) | Tieu de. |  |
| `note` | text | Ghi chu. | nullable |
| `media_id` | uuid | Anh lien quan. | FK `media_assets.id`, nullable |
| `coordinates` | geography(Point,4326) | Vi tri. | GiST nullable |
| `distance_to_address_meters` | numeric | Khoang cach toi dia chi (geo event). | nullable |
| `recorded_at` | timestamptz | Thoi diem tren thiet bi. | IDX, partition key |
| `synced_at` | timestamptz | Dong bo len server. | nullable |
| `source` | varchar(20) | ONLINE/OFFLINE_SYNC/ADMIN. | IDX |
| `metadata` | jsonb | EXIF, offline id, app version. |  |

### 7.5 `gps_tracks`

Muc dich: log hanh trinh caregiver. PARTITION theo thang. Live-tracking o Redis, day batch xuong day.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh point. | PK (id, recorded_at) |
| `booking_id` | uuid | Ca. | FK, IDX |
| `caregiver_id` | uuid | Caregiver. | FK, IDX |
| `location` | geography(Point,4326) | Toa do. | GiST IDX |
| `accuracy_meters` | numeric | Do chinh xac. |  |
| `speed` | numeric | Toc do. | nullable |
| `heading` | numeric | Huong. | nullable |
| `recorded_at` | timestamptz | Tren thiet bi. | IDX, partition key |
| `received_at` | timestamptz | Server nhan. | IDX |

### 7.6 `checkout_reviews`

Muc dich: luu yeu cau checkout thu cong khi CSV khong lien lac duoc nguoi nha de lay OTP ket thuc ca. Bang nay giu bang chung tai thoi diem yeu cau, log lien he va quyet dinh approve/reject/auto-approve.

Quan he:

- `checkout_reviews.booking_id` -> `bookings.id` (UQ, 0/1 review / booking)
- `checkout_reviews.requested_by_caregiver_id` -> `caregiver_profiles.id`
- `checkout_reviews.reviewed_by_admin_id` -> `users.id`

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh yeu cau review. | PK |
| `booking_id` | uuid | Booking can checkout thu cong. | FK `bookings.id`, UQ |
| `requested_by_caregiver_id` | uuid | CSV gui yeu cau. | FK `caregiver_profiles.id`, IDX |
| `reason` | text | Ly do khong lay duoc OTP / ghi chu ban giao. | nullable |
| `evidence_snapshot` | jsonb | Snapshot link toi timeline, GPS, media, checklist luc yeu cau. | object |
| `contact_attempts` | jsonb | Danh sach lan lien he nguoi nha/lien he khan cap. | array |
| `status` | varchar(20) | PENDING/APPROVED/REJECTED/AUTO_APPROVED. | IDX |
| `requested_at` | timestamptz | Thoi diem CSV gui yeu cau. | IDX |
| `reviewed_by_admin_id` | uuid | Admin review neu co. | FK `users.id`, nullable |
| `reviewed_at` | timestamptz | Thoi diem Admin review. | nullable |
| `admin_note` | text | Ly do approve/reject. | nullable |
| `auto_approve_at` | timestamptz | Moc tu dong approve neu khong co phan doi. | IDX partial |
| `resolved_at` | timestamptz | Thoi diem dong review. | nullable |

## 8. Money, Escrow, Wallet & Ledger

Nguyen tac:

- Provider payment chi xac nhan tien vao/ra.
- Ledger la su that tai chinh noi bo, **bat bien**: khong sua/xoa entry da POSTED, sai thi tao entry REVERSE.
- Wallet balance la cache, movement suy ra tu ledger; doi soat dinh ky.
- Moi request thanh toan/refund/payout can idempotency.

### 8.1 `wallet_accounts`

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh vi. | PK |
| `user_id` | uuid | Chu vi. | FK `users.id`, IDX |
| `account_type` | varchar(20) | CAREGIVER/PLATFORM. | IDX |
| `available_balance` | bigint | So du rut duoc (cache, >=0). |  |
| `pending_balance` | bigint | So du tam giu dispute window. |  |
| `currency` | char(3) | VND. |  |
| `created_at` | timestamptz |  |  |
| `updated_at` | timestamptz | Cap nhat cache. |  |

### 8.2 `payment_intents`

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh intent. | PK |
| `booking_id` | uuid | Booking. | FK, IDX |
| `customer_id` | uuid | Nguoi tra. | FK `users.id`, IDX |
| `provider` | varchar(20) | VNPAY/MOMO/CARD. | IDX |
| `amount` | bigint | So tien. |  |
| `currency` | char(3) | VND. |  |
| `status` | varchar(20) | CREATED/PENDING/SUCCEEDED/FAILED/CANCELLED/EXPIRED. | IDX |
| `provider_transaction_id` | varchar(255) | Ma giao dich provider. | IDX nullable |
| `idempotency_key` | varchar(255) | Chong tru tien trung. | UQ |
| `request_payload` | jsonb | Payload gui provider. |  |
| `response_payload` | jsonb | Response provider. |  |
| `created_at` | timestamptz |  |  |
| `updated_at` | timestamptz |  |  |

### 8.3 `payment_webhooks`

Muc dich: webhook provider, xu ly idempotent.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh. | PK |
| `provider` | varchar(20) | Nguon. | IDX |
| `provider_event_id` | varchar(255) | ID event provider. | UQ voi provider |
| `event_type` | varchar(100) | payment_success/refund_success... | IDX |
| `payload` | jsonb | Raw payload. |  |
| `processed_at` | timestamptz | Da xu ly. | nullable |
| `status` | varchar(20) | RECEIVED/PROCESSED/FAILED. | IDX |
| `created_at` | timestamptz |  |  |

Constraint: unique `(provider, provider_event_id)`.

### 8.4 `ledger_entries`

Muc dich: so cai bat bien. Wallet movement (`wallet_entries` cu) suy ra tu day.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh. | PK |
| `booking_id` | uuid | Booking. | FK, IDX nullable |
| `payment_intent_id` | uuid | Payment sinh ra entry. | FK, nullable |
| `transaction_type` | varchar(30) | ESCROW_LOCK/PLATFORM_FEE/CAREGIVER_EARNING/REFUND/PAYOUT/PENALTY/BONUS. | IDX |
| `debit_account` | varchar(100) | TK ghi no noi bo. |  |
| `credit_account` | varchar(100) | TK ghi co noi bo. |  |
| `amount` | bigint | So tien. |  |
| `currency` | char(3) | VND. |  |
| `status` | varchar(20) | PENDING/POSTED/REVERSED. | IDX |
| `metadata` | jsonb | refund id, payout id, dispute decision. |  |
| `created_at` | timestamptz |  | IDX |

### 8.5 `payout_requests`

Muc dich: yeu cau rut tien. **Gom** `bank_accounts` thanh snapshot bank tai thoi diem rut.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh. | PK |
| `caregiver_id` | uuid | Caregiver. | FK, IDX |
| `wallet_account_id` | uuid | Vi bi tru. | FK |
| `amount` | bigint | So tien rut, min 100000 VND. |  |
| `bank_name` | varchar(255) | Snapshot ngan hang (gom bank_accounts). |  |
| `account_holder_name` | varchar(255) | Ten chu TK. |  |
| `account_number_encrypted` | text | So TK ma hoa. | sensitive |
| `status` | varchar(20) | PENDING/APPROVED/REJECTED/PROCESSING/PAID/FAILED. | IDX |
| `requested_at` | timestamptz |  | IDX |
| `reviewed_by_admin_id` | uuid | Ke toan duyet. | FK `users.id`, nullable |
| `reviewed_at` | timestamptz |  | nullable |
| `reject_reason` | text |  | nullable |

## 9. Dispute & Support

### 9.1 `disputes`

Muc dich: khieu nai sau ca. **Gom** `dispute_evidence` (jsonb) va `dispute_decisions` (cac cot decision/refund).

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh. | PK |
| `booking_id` | uuid | Booking bi khieu nai. | FK, UQ |
| `raised_by_user_id` | uuid | Nguoi tao. | FK `users.id`, IDX |
| `reason` | varchar(255) | Ly do ngan. | IDX |
| `description` | text | Mo ta. |  |
| `status` | varchar(20) | OPEN/INVESTIGATING/RESOLVED/CANCELLED. | IDX |
| `evidence` | jsonb | `[{type, reference_id, desc}]` (gom dispute_evidence). |  |
| `decision` | varchar(20) | CUSTOMER_WINS/CAREGIVER_WINS/PARTIAL_REFUND (gom dispute_decisions). | nullable |
| `refund_amount` | bigint | Tien hoan customer. | nullable |
| `caregiver_penalty_amount` | bigint | Phat caregiver. | nullable |
| `decided_by_admin_id` | uuid | Admin phan quyet. | FK `users.id`, nullable |
| `opened_at` | timestamptz |  | IDX |
| `resolved_at` | timestamptz |  | nullable |

### 9.2 `support_tickets`

Muc dich: ticket CSKH/SOS/payment/KYC.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh. | PK |
| `user_id` | uuid | User lien quan. | FK `users.id`, IDX |
| `booking_id` | uuid | Booking neu co. | FK, nullable |
| `type` | varchar(20) | COMPLAINT/SOS/PAYMENT/KYC/GENERAL. | IDX |
| `status` | varchar(20) | NEW/IN_PROGRESS/RESOLVED/CLOSED. | IDX |
| `priority` | varchar(20) | LOW/MEDIUM/HIGH/CRITICAL. | IDX |
| `assigned_admin_id` | uuid | Admin phu trach. | FK `users.id`, nullable |
| `created_at` | timestamptz |  | IDX |
| `updated_at` | timestamptz |  |  |

### 9.3 `reviews`

Muc dich: danh gia sau ca (F-04.03, hien thi o F-02.02b). 1 review / booking. `caregiver_profiles.rating_avg`/`rating_count` la **cache**, cap nhat bang trigger khi co review moi.

Quan he:

- `reviews.booking_id` -> `bookings.id` (UQ)
- `reviews.caregiver_id` -> `caregiver_profiles.id`
- `reviews.customer_id` -> `users.id`

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh. | PK |
| `booking_id` | uuid | Ca duoc danh gia. | FK `bookings.id`, UQ |
| `caregiver_id` | uuid | CSV duoc danh gia. | FK `caregiver_profiles.id`, IDX |
| `customer_id` | uuid | Nguoi danh gia. | FK `users.id` |
| `rating` | int | 1..5 sao. | CHECK 1-5 |
| `comment` | text | Nhan xet van ban. | nullable |
| `experience_tags` | jsonb | `['Dung gio','Tan tam','Ky nang chuyen mon tot','Giao tiep tot']`. | nullable |
| `created_at` | timestamptz |  | IDX |

### 9.4 `notifications`

Muc dich: inbox thong bao trong app (F-15.03), trang thai da doc/chua doc. Push thuc te gui qua FCM (`user_devices.push_token`); bang nay luu lich su de hien Notification Center.

| Field | Kieu | Muc dich | Lien quan |
| --- | --- | --- | --- |
| `id` | uuid | Dinh danh. | PK |
| `user_id` | uuid | Nguoi nhan. | FK `users.id`, IDX |
| `type` | varchar(20) | BOOKING/CARE_TIMELINE/PAYMENT/PROMOTION/SYSTEM/SOS. | IDX |
| `title` | varchar(255) | Tieu de. |  |
| `body` | text | Noi dung. | nullable |
| `data` | jsonb | Payload + deep_link. | nullable |
| `read_at` | timestamptz | NULL = chua doc. | IDX partial |
| `created_at` | timestamptz |  | IDX |

## 10. Du lieu da day sang Redis (khong tao bang)

| Du lieu cu | Bang cu | Xu ly Redis |
| --- | --- | --- |
| OTP login/checkout/payout | `otp_sessions` | Key `otp:{phone}:{purpose}` co TTL; attempt = INCR. |
| Refresh token | `refresh_tokens` | Allowlist/denylist token co TTL. |
| Checkout OTP | `checkout_otps` | Key theo booking co TTL; neu khong lay duoc OTP thi luu review lau dai o `checkout_reviews` va audit_logs. |
| Caregiver online/offline | (cot status) | Redis hash; chi sync trang thai cuoi xuong `caregiver_profiles`. |
| Live GPS hien tai | (live tracking) | `GEOADD`/pub-sub; lich su ghi batch xuong `gps_tracks`. |
| Matching ranking tam | `matching_candidates` | Tinh trong Redis; chi candidate offer/chi dinh ghi `booking_assignments`. |

## 11. Phase 2 (chua tao o MVP lean)

- Blog/CMS SEO: `blog_categories`, `blog_posts`, `blog_tags`, `blog_post_tags`.
- Analytics base table `analytics_daily_metrics` + materialized views (MVP dung MV truc tiep tren replica).
- `offline_sync_batches` (sync offline day du).
- `booking_extensions` (gia han ca giua chung).
- Tach nguoc khi scale: `skills`/`caregiver_skills`, `caregiver_service_areas`, `wallet_entries`, `bank_accounts`, RBAC admin chi tiet.

## 12. Hardening (ap o tang DB)

1. **Ledger bat bien**: trigger chan UPDATE/DELETE entry `status='POSTED'`; role app khong co quyen DELETE tren `ledger_entries`/`payment_intents`/`audit_logs`.
2. **Khoa vi chong race**: ham `wallet_apply()` khoa hang `wallet_accounts` (FOR UPDATE), validate balance type, cap nhat balance trong cung transaction; job reconcile so sanh ledger vs balance hang ngay.
3. **Chong double-book**: `EXCLUDE USING gist (caregiver_id, tstzrange(start_at,end_at)) WHERE status IN ('BOOKED','BLOCKED')`.
4. **Soft-delete an toan UQ**: partial unique index `WHERE deleted_at IS NULL` cho `users.phone`, `users.email`.
5. **Booking status -> audit_logs**: trigger ghi history khi `bookings.status` doi.
6. **Toa do 1 nguon su that**: `latitude/longitude` GENERATED tu `location`.
7. **Bang lon**: MVP de `gps_tracks`, `care_timeline_events`, `audit_logs` la bang thuong. Khi volume lon -> partition theo thang + pg_partman retention.
8. **PII**: `cccd_number_encrypted`, `account_number_encrypted` ma hoa tang app (key KMS); `cccd_hash` HMAC de check trung; RLS tren `beneficiaries` (medications nam trong jsonb cua bang nay) cho du lieu y te; media sensitive dung signed URL.
9. **Idempotency**: `payment_intents.idempotency_key` UQ; `payment_webhooks(provider, provider_event_id)` UQ; `payment_intents(provider, provider_transaction_id)` UQ partial; 1 successful payment / booking.
10. **Checkout fallback**: `checkout_reviews` luu evidence snapshot/contact attempts; `bookings.status` co `CHECKOUT_PENDING_REVIEW`; event timeline co manual checkout events.
11. **Assignment race**: partial unique index dam bao 1 booking chi co 1 assignment `ACCEPTED`.
12. **RLS caregiver/admin**: caregiver duoc phan cong ca hop le va admin active co policy doc beneficiary lien quan.

## 13. Enum definitions de xuat

MVP dung `varchar(50)` + CHECK; co the doi sang PostgreSQL enum khi on dinh.

```text
user_status:        ACTIVE, SUSPENDED, LOCKED, DELETED
role_code:          CUSTOMER, CAREGIVER, ADMIN
admin_department:   OPERATIONS, CSKH, ACCOUNTING, MANAGEMENT
device_platform:    IOS, ANDROID, WEB
gender:             MALE, FEMALE, OTHER, UNSPECIFIED

caregiver_kyc_status:          DRAFT, PENDING, APPROVED, REJECTED, SUSPENDED
caregiver_availability_status: ONLINE, OFFLINE, BUSY
caregiver_document_type:       CCCD_FRONT, CCCD_BACK, PORTRAIT, NURSING_CERT, HEALTH_CERT, CRIMINAL_RECORD, OTHER
verification_status:           PENDING, APPROVED, REJECTED
availability_slot_status:      AVAILABLE, BLOCKED, BOOKED
availability_source:           CAREGIVER, BOOKING, ADMIN

booking_status:          DRAFT, PENDING_PAYMENT, CONFIRMED, CAREGIVER_ACCEPTED, CAREGIVER_EN_ROUTE, IN_PROGRESS, CHECKOUT_PENDING_REVIEW, COMPLETED, CANCELLED, CRISIS, DISPUTED, REFUNDED
booking_cancelled_by_role: CUSTOMER, CAREGIVER, ADMIN, SYSTEM
assignment_type:         PRIMARY, REPLACEMENT, MANUAL_OVERRIDE
assignment_status:       SUGGESTED, OFFERED, ACCEPTED, REJECTED, EXPIRED, CANCELLED

care_task_status:  PENDING, DONE, SKIPPED
care_event_type:   CHECKIN, CHECKIN_VALID, CHECKIN_OUTSIDE_GEOFENCE, TASK_DONE, PHOTO_UPLOADED, NOTE, CHECKOUT, CHECKOUT_OTP_SENT, CHECKOUT_VALID, CHECKOUT_MANUAL_REQUESTED, CHECKOUT_MANUAL_APPROVED, CHECKOUT_MANUAL_REJECTED, GPS_LOST, SOS, SYNC_DELAYED
event_source:      ONLINE, OFFLINE_SYNC, ADMIN

storage_provider:  S3, CLOUDINARY
media_type:        PHOTO, DOCUMENT, CERTIFICATE, AVATAR, MEDICAL_FILE

payment_provider:        VNPAY, MOMO, CARD
payment_status:          CREATED, PENDING, SUCCEEDED, FAILED, CANCELLED, EXPIRED
webhook_status:          RECEIVED, PROCESSED, FAILED
wallet_account_type:     CAREGIVER, PLATFORM
ledger_transaction_type: ESCROW_LOCK, PLATFORM_FEE, CAREGIVER_EARNING, REFUND, PAYOUT, PENALTY, BONUS
ledger_status:           PENDING, POSTED, REVERSED
payout_status:           PENDING, APPROVED, REJECTED, PROCESSING, PAID, FAILED

dispute_status:          OPEN, INVESTIGATING, RESOLVED, CANCELLED
dispute_decision:        CUSTOMER_WINS, CAREGIVER_WINS, PARTIAL_REFUND
checkout_review_status:  PENDING, APPROVED, REJECTED, AUTO_APPROVED
support_ticket_type:     COMPLAINT, SOS, PAYMENT, KYC, CHECKOUT_REVIEW, GENERAL
support_ticket_status:   NEW, IN_PROGRESS, RESOLVED, CLOSED
support_ticket_priority: LOW, MEDIUM, HIGH, CRITICAL

notification_type:       BOOKING, CARE_TIMELINE, PAYMENT, PROMOTION, SYSTEM, SOS
```

## 14. Index plan tong hop

Identity:

- `users(phone)` partial unique WHERE deleted_at IS NULL.
- `users(email)` partial unique.
- `user_devices(user_id)`, `user_devices(push_token)`.
- `audit_logs(entity_type, entity_id, created_at)`, `audit_logs(actor_user_id, created_at)`.

People/Caregiver:

- `beneficiaries(customer_id)`.
- `medications(beneficiary_id, is_active)`.
- `caregiver_profiles(kyc_status)`, `caregiver_profiles(availability_status, rating_avg)`.
- `caregiver_profiles(cccd_hash)` partial unique.
- `caregiver_availability(caregiver_id, start_at, end_at)` + EXCLUDE gist.
- `caregiver_profiles(service_center_location)` GiST.

Geo:

- `addresses(location)` GiST.
- `gps_tracks(location)` GiST, `gps_tracks(booking_id, recorded_at)`.
- `care_timeline_events(coordinates)` GiST.

Booking:

- `bookings(status, scheduled_start)`, `bookings(customer_id, scheduled_start)`, `bookings(caregiver_id, scheduled_start)`.
- `booking_assignments(booking_id, rank)`, partial unique `booking_id WHERE status='ACCEPTED'`.
- `care_timeline_events(booking_id, recorded_at)`, `care_tasks(booking_id, sort_order)`.
- `checkout_reviews(status, requested_at)`, `checkout_reviews(auto_approve_at) WHERE status='PENDING'`.

Money:

- `payment_intents(idempotency_key)` unique, `payment_intents(booking_id)`, `payment_intents(provider, provider_transaction_id)` unique partial, `payment_intents(booking_id) WHERE status='SUCCEEDED'` unique.
- `payment_webhooks(provider, provider_event_id)` unique.
- `ledger_entries(booking_id, created_at)`.
- `payout_requests(status, requested_at)`.

Dispute/Support/Engagement:

- `disputes(status, opened_at)`.
- `support_tickets(status, priority, created_at)`.
- `reviews(caregiver_id, created_at)`, `reviews(booking_id)` unique.
- `notifications(user_id, created_at DESC)`, `notifications(user_id) WHERE read_at IS NULL` (partial).

## 15. Migration order

1. `users`, `media_assets`, `addresses` (xu ly FK vong `users.avatar_media_id` va `media_assets.booking_id` bang ALTER sau).
2. `user_devices`, `audit_logs`.
3. `wallet_accounts`, `caregiver_profiles`, `caregiver_availability`.
4. `beneficiaries` (medications nam trong jsonb).
5. `service_types`, `pricing_rules`.
6. `bookings`, `booking_assignments`, `care_tasks`, `care_timeline_events`, `gps_tracks`.
7. `payment_intents`, `payment_webhooks`, `ledger_entries`, `payout_requests`.
8. `disputes`, `support_tickets`, `reviews`, `notifications`.
9. Trigger/constraint hardening (muc 12), RLS, role phan quyen. (MVP chua partition.)
10. Migration 003: `checkout_reviews`, `CHECKOUT_PENDING_REVIEW`, FK timeline/GPS, assignment/payment unique guards, RLS caregiver/admin, review trigger update/delete.

## 16. Cac diem can chot truoc khi viet migration chi tiet

1. Escrow la giu tien that tren provider hay chi ledger noi bo? MVP: ledger noi bo, provider charge/refund.
2. Bank account snapshot tai payout co du khong, hay can vault rieng? Neu luu so TK thi bat buoc encrypt.
3. Anh CCCD/chung chi: signed URL het han, khong public.
4. GPS tracking tan suat bao nhieu giay? Anh huong thoi diem can partition va chi phi.
5. Dispute window 48h ap dung moi service type hay cau hinh theo pricing rule?
6. Subscription (F-02.01): sinh truoc N ky booking con luc dat hay sinh dan theo cron? Anh huong cach dung `parent_booking_id`.
7. Chat/masked call (F-03.04) va saved payment methods (F-15.05) hoan Phase 2 — chot lai voi mentor de SRS va DB khong lech ky vong.
```
