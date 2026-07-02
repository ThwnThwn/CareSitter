# CareSitter — Bản đồ Module

Kiến trúc: **modular monolith** (.NET 8, EF Core 8, PostgreSQL + PostGIS).
Mỗi module = 1 project + 1 schema Postgres, sở hữu tập bảng riêng.
Ranh giới giữ bằng **FK qua Guid** (không navigation chéo) và **interface qua `CareSitter.Contracts`** (không query DbContext chéo).

Tổng: **25 bảng / 6 module**.

## Tổng quan

| # | Module | Schema | Vai trò | Số bảng |
|---|---|---|---|---|
| 1 | **Identity** | `identity` | Danh tính, tài khoản, thiết bị, nhật ký kiểm toán | 3 |
| 2 | **Catalog** | `catalog` | Dữ liệu tham chiếu: media, địa chỉ, loại dịch vụ, quy tắc giá | 4 |
| 3 | **People** | `people` | Hồ sơ con người: người được chăm sóc + caregiver | 3 |
| 4 | **Booking** | `booking` | Vòng đời đơn chăm sóc, phân công, check-in/out, GPS | 6 |
| 5 | **Payments** | `payments` | Ví, thanh toán, sổ cái, rút tiền | 5 |
| 6 | **Support** | `support` | Khiếu nại, ticket, đánh giá, thông báo | 4 |

---

## 1. Identity — *"ai là ai"*

Quản lý tài khoản & vai trò. **Không có bảng `customers`/`admins` riêng** — CUSTOMER/CAREGIVER/ADMIN chỉ là giá trị trong mảng `users.roles`; trường customer và admin gộp chung trên `users`.

| Bảng | Nội dung |
|---|---|
| `users` | Tài khoản gốc + trường customer + trường admin (gộp `customer_profiles`, `admin_profiles`, `user_roles`) |
| `user_devices` | Thiết bị + push token (FCM), biometric |
| `audit_logs` | Nhật ký thay đổi toàn hệ thống (gộp cả booking status history) |

## 2. Catalog — *"dữ liệu tham chiếu & tài sản"*

Những thứ được các module khác **tra cứu**: file media, địa chỉ (PostGIS), danh mục dịch vụ, bảng giá. Sở hữu `IPricingService` (báo giá cho Booking).

| Bảng | Nội dung |
|---|---|
| `media_assets` | File ảnh/tài liệu/KYC (gộp `caregiver_documents`) |
| `addresses` | Địa chỉ + `geography(Point,4326)` |
| `service_types` | Loại dịch vụ (mã, tên, thời lượng mặc định) |
| `pricing_rules` | Giá giờ, hệ số đêm/lễ, phí nền tảng, chính sách hủy |

## 3. People — *"hồ sơ con người"*

Hồ sơ chi tiết của **người được chăm sóc** và **caregiver** (danh tính vẫn ở Identity, đây là phần nghiệp vụ mở rộng). Chứa dữ liệu y tế nhạy cảm → có Row-Level Security.

| Bảng | Nội dung |
|---|---|
| `beneficiaries` | Người được chăm sóc: bệnh sử, dị ứng, thuốc men (jsonb) — RLS theo customer |
| `caregiver_profiles` | Hồ sơ CSV: KYC, CCCD mã hóa, rating, vùng phục vụ, ví |
| `caregiver_availability` | Lịch rảnh/bận (có EXCLUDE constraint chống double-book) |

## 4. Booking — *"trái tim nghiệp vụ"*

Module giàu logic nhất: state machine 12 trạng thái, geofence khi check-in, escrow snapshot, GPS, đặt lịch định kỳ. Module duy nhất đã có đủ tầng `Application` + `Endpoints`.

| Bảng | Nội dung |
|---|---|
| `bookings` | Đơn chăm sóc — aggregate root, 12 trạng thái, escrow, recurrence |
| `booking_assignments` | Phân công CSV (gộp matching_candidates: rank, score, distance) |
| `care_tasks` | Danh sách việc cần làm trong ca |
| `care_timeline_events` | Dòng thời gian: check-in, task done, ảnh, SOS (gộp geo_events) |
| `gps_tracks` | Vệt GPS thời gian thực |
| `checkout_reviews` | Duyệt checkout thủ công khi không lấy được OTP người nhà |

## 5. Payments — *"dòng tiền"*

Ví escrow, cổng thanh toán (VNPay/MoMo), sổ cái bất biến (POSTED không sửa/xóa), yêu cầu rút tiền. Sở hữu `IWalletService`.

| Bảng | Nội dung |
|---|---|
| `wallet_accounts` | Ví CSV/nền tảng (available + pending balance) |
| `payment_intents` | Giao dịch thanh toán + idempotency key |
| `payment_webhooks` | Webhook từ cổng thanh toán (idempotent) |
| `ledger_entries` | Sổ cái kép bất biến (escrow lock, fee, earning, refund…) |
| `payout_requests` | Yêu cầu rút tiền + snapshot ngân hàng |

## 6. Support — *"chăm sóc sau vận hành"*

Khiếu nại/tranh chấp, ticket CSKH, đánh giá (tự đồng bộ rating về caregiver), thông báo inbox.

| Bảng | Nội dung |
|---|---|
| `disputes` | Tranh chấp đơn (gộp evidence + decision) |
| `support_tickets` | Ticket hỗ trợ (complaint, SOS, payment, KYC…) |
| `reviews` | Đánh giá 1–5 sao (trigger cập nhật `caregiver_profiles.rating_avg`) |
| `notifications` | Hộp thư inbox (đọc/chưa đọc) |

---

## Quan hệ cross-module

Vai trò con người phân bố **bất đối xứng** — cần nhớ khi nối FK:

| Vai trò | Dữ liệu nằm ở đâu | FK trỏ tới |
|---|---|---|
| Customer | `identity.users` (không bảng riêng) | `identity.users(id)` |
| Admin | `identity.users` (cột `admin_*`) | `identity.users(id)` |
| Caregiver | `identity.users` + `people.caregiver_profiles` | `people.caregiver_profiles(id)` |

Ví dụ trên `booking.bookings`:

```sql
customer_id  uuid NOT NULL REFERENCES identity.users(id)            -- trỏ thẳng users
caregiver_id uuid          REFERENCES people.caregiver_profiles(id) -- trỏ profile, KHÔNG phải users
```

### Phụ thuộc qua interface (Contracts)

- `Booking` → `IPricingService` (Catalog) để báo giá.
- `Booking` → `IWalletService` (Payments) để khóa escrow / quyết toán.
- `IMediaService`, `IAuditLogger` (Contracts) dùng chung cho nhiều module.

---

## Cấu trúc thư mục mỗi module

```
Modules/<Module>/
├── <Module>Module.cs             # đăng ký DI (DbContext + services) qua IModule
├── Domain/                       # 1 file entity / bảng
│   └── <Entity>.cs               # Entity | AggregateRoot, ctor private + factory Create()
├── Infrastructure/
│   └── <Module>DbContext.cs      # DbSet + Fluent mapping cột snake_case
├── Application/   (chỉ Booking)  # command + handler (MediatR)
└── Endpoints/     (chỉ Booking)  # map HTTP minimal API
```

Quy ước mapping:
- Cột `CHECK(...)` varchar → property `string` (kèm XML doc liệt kê giá trị), **không dùng enum** để tránh lệch chuỗi DB.
- `jsonb` → `string?` + `.HasColumnType("jsonb")`.
- `geography(Point,4326)` → NetTopologySuite `Point` + `.HasColumnType("geography(Point,4326)")`.
- Cột GENERATED (`latitude`, `longitude`, `time_range`) → **bỏ map** (DB tự sinh).
- Mỗi property map **tường minh** `.HasColumnName("snake_case")`.
- DB do `init-db/*.sql` quản lý → **không sinh EF migration** cho các module này.
