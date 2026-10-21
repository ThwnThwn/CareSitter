# Tài Liệu Kỹ Thuật API — CareSitter Backend (.NET 8)

> **Phiên bản:** 1.0  
> **Backend:** `C# .NET 8 — Modular Monolith, PostgreSQL 16 + PostGIS, Entity Framework Core, MediatR (CQRS)`  
> **Cập nhật lần cuối:** 04/09/2026  
> **Build:** ✅ **0 Warning(s), 0 Error(s)**

---

## Tổng Quan Kiến Trúc

```
CareSitter Backend (.NET 8 Modular Monolith)
├── Modules/
│   ├── Identity/          → Xác thực, đăng ký, hồ sơ người dùng
│   ├── People/            → Caregiver, Beneficiary, KYC, Availability
│   ├── Booking/           → Vòng đời đặt lịch E2E (lifecycle)
│   ├── Payments/          → Ví, escrow, payout, webhook
│   ├── Catalog/           → Danh mục dịch vụ
│   └── Support/           → Đánh giá (Review) & Khiếu nại (Dispute)
├── Shared/
│   ├── CareSitter.Contracts/     → Interface xuyên module
│   ├── CareSitter.Infrastructure/ → JWT, Encryption, Time
│   └── CareSitter.SharedKernel/  → Result pattern, Error types
└── ApiHost/               → ASP.NET Core entry point, DI registration
```

---

## 1. Module Identity — Xác Thực & Hồ Sơ

### 1.1 `AuthController` — Route: `/api/v1/auth`

Controller xử lý toàn bộ luồng xác thực người dùng. Không yêu cầu token (trừ Logout).

| Method | Endpoint | Mô tả |
|:---:|---|---|
| `POST` | `/auth/send-otp` | Gửi mã OTP 6 chữ số đến địa chỉ email |
| `POST` | `/auth/login` | Đăng nhập bằng Email + OTP → trả JWT Access Token & Refresh Token |
| `POST` | `/auth/login/password` | Đăng nhập bằng Email/SĐT + Mật khẩu (BCrypt verify) → JWT |
| `POST` | `/auth/register` | Đăng ký tài khoản mới (CUSTOMER/CAREGIVER/ADMIN) → JWT |
| `POST` | `/auth/google/callback` | Đăng nhập/đăng ký qua Google Account (Google ID Token) → JWT |
| `POST` | `/auth/logout` | ⚠️ Yêu cầu Bearer Token — Thu hồi session (blacklist JTI) |

#### Chi tiết các phương thức:

**`SendOtp(SendOtpCommand command)`**
- Nhận: `{ email: string }`
- Xử lý: Tạo mã OTP 6 số, lưu vào Redis với TTL 5 phút, gửi email
- Trả về: `200 OK` hoặc `400 Bad Request` nếu email không hợp lệ

**`Login(LoginCommand command)`**
- Nhận: `{ email: string, otp: string }`
- Xử lý: Xác minh OTP từ Redis, ghi nhận thời gian đăng nhập, phát hành JWT
- Trả về: `200 OK` với `LoginResponse { accessToken, refreshToken, userId, roles, displayName }`

**`LoginWithPassword(LoginWithPasswordCommand command)`**
- Nhận: `{ email: string, password: string }` — `email` có thể là địa chỉ email hoặc SĐT
- Xử lý: Tìm user theo `email = identifier OR phone = identifier`, BCrypt.Verify password
- **Bảo mật:** Cùng thông báo lỗi dù sai tài khoản hay sai mật khẩu (chống user enumeration)
- Trả về: `200 OK` với `LoginResponse`

**`Register(RegisterCommand command)`**
- Nhận: `{ phone, fullName, email, roles[], password? }`
- Xử lý: Tạo User mới, hash password nếu có, phát hành JWT ngay
- Lỗi: `409 Conflict` nếu email/phone đã tồn tại
- Trả về: `201 Created` với `LoginResponse`

**`GoogleCallback(GoogleLoginCommand command)`**
- Nhận: `{ idToken: string, roles?: string[] }`
- Xử lý: Xác minh Google ID Token, tìm/tạo tài khoản, phát hành JWT
- Trả về: `200 OK` với `GoogleLoginResponse`

**`Logout()`** — `[Authorize]`
- Lấy `jti` (JWT ID) và `exp` từ claim
- Blacklist JTI trong Redis cho đến khi token hết hạn
- Trả về: `204 No Content`

---

### 1.2 `ProfileController` — Route: `/api/v1/profile`

Quản lý hồ sơ cá nhân của tài khoản đang đăng nhập. Toàn bộ endpoint yêu cầu Bearer Token.

| Method | Endpoint | Mô tả |
|:---:|---|---|
| `GET` | `/profile` | Lấy hồ sơ đầy đủ của user hiện tại từ DB |
| `PUT` | `/profile` | Cập nhật thông tin cá nhân (FullName, Email, DateOfBirth, Gender) |

**`Get()`**
- Truy vấn DB theo `UserId` từ JWT claim
- Trả về: `ProfileResponse { id, phone, email, fullName, displayName, dateOfBirth, gender, avatarMediaId, defaultAddressId, roles[] }`

**`Update(UpdateProfileCommand command)`**
- Nhận: `{ fullName, email, displayName?, dateOfBirth?, gender? }`
- Xử lý qua MediatR `UpdateProfileHandler`
- Lỗi: `409 Conflict` nếu email mới đã tồn tại ở tài khoản khác
- Trả về: `200 OK` với `ProfileResponse` đã cập nhật

---

## 2. Module People — Caregiver & Beneficiary

### 2.1 `CaregiversController` — Route: `/api/v1/caregivers`

Cung cấp API tìm kiếm và xem thông tin caregiver đã được duyệt KYC.

| Method | Endpoint | Mô tả |
|:---:|---|---|
| `GET` | `/caregivers` | Tìm kiếm danh sách caregiver với nhiều bộ lọc, phân trang |
| `GET` | `/caregivers/{id}` | Xem hồ sơ đầy đủ của một caregiver đã APPROVED |
| `GET` | `/caregivers/{id}/availability` | Lấy danh sách khung giờ rảnh của caregiver |

**`List(city?, district?, skill?, minRating?, availabilityStatus?, start?, end?, page, pageSize)`**
- Lọc chỉ `KycStatus == "APPROVED"` và chưa bị xóa
- Hỗ trợ lọc: thành phố, quận, kỹ năng (ILIKE), điểm đánh giá tối thiểu, khung giờ rảnh
- Sắp xếp: `RatingAvg DESC, RatingCount DESC`; Phân trang tối đa 50
- Trả về: `{ items: CaregiverResponse[], total, page, pageSize }`

**`Get(id)`**
- Chỉ trả về caregiver `KycStatus == "APPROVED"` và chưa bị xóa
- Trả về: `CaregiverResponse { id, userId, fullName, bio, yearsOfExperience, hourlyRateExpected, ratingAvg, ratingCount, availabilityStatus, skills, serviceCity, serviceDistrict }`

**`GetAvailability(id, from?, to?)`**
- Lấy các slot `Status == "AVAILABLE"` lọc theo khoảng thời gian
- Trả về: `AvailabilityResponse[] { id, startAt, endAt, status }` sắp xếp theo thời gian

---

### 2.2 `AvailabilityController` — Route: `/api/v1/caregivers/me/availability`

Caregiver tự quản lý lịch rảnh. Profile được xác định tự động từ JWT.

| Method | Endpoint | Mô tả |
|:---:|---|---|
| `POST` | `/caregivers/me/availability` | Đăng ký khung giờ rảnh mới (Source = "CAREGIVER") |
| `GET` | `/caregivers/me/availability` | Xem tất cả lịch rảnh, lọc theo `from`/`to` |
| `DELETE` | `/caregivers/me/availability/{id}` | Xóa vật lý khung giờ rảnh (kiểm tra chủ sở hữu) |

**`Create(req)`** — Nhận `{ startAt, endAt, status? }`, tạo slot `AVAILABLE` cho profile hiện tại  
**`ListMy(from?, to?)`** — Trả về tất cả slots của caregiver đang đăng nhập  
**`Delete(id)`** — Xóa slot nếu thuộc profile hiện tại, trả về `204 No Content`

---

### 2.3 `CaregiverKycController`

Quy trình xác minh danh tính (KYC) cho Caregiver.

| Method | Endpoint | Quyền | Mô tả |
|:---:|---|:---:|---|
| `POST` | `/caregivers/me/kyc` | Caregiver | Nộp CCCD (AES mã hóa + HMAC) → PENDING |
| `PUT` | `/caregivers/me/profile` | Caregiver | Cập nhật bio, skills, khu vực |
| `POST` | `/caregivers/{id}/kyc/approve` | **ADMIN** | Duyệt KYC → APPROVED |
| `POST` | `/caregivers/{id}/kyc/reject` | **ADMIN** | Từ chối KYC → REJECTED (kèm lý do) |

**`SubmitKyc(req { cccdNumber, certificateUrls? })`**
- Mã hóa CCCD bằng **AES** (lưu vào DB) và tính **HMAC** (kiểm tra trùng lặp)
- Trạng thái KYC: `DRAFT` → `PENDING` (chờ Admin duyệt)

**`ApproveKyc(id)` / `RejectKyc(id, reason?)`**
- Chỉ ADMIN mới gọi được (Forbid nếu không có role ADMIN)
- Sau khi APPROVED: caregiver xuất hiện trong tìm kiếm và có thể nhận ca

---

### 2.4 `BeneficiariesController` — Route: `/api/v1/beneficiaries`

Quản lý hồ sơ người thân. Áp dụng **PostgreSQL RLS** để cách ly dữ liệu.

| Method | Endpoint | Mô tả |
|:---:|---|---|
| `GET` | `/beneficiaries` | Danh sách người thân của user hiện tại |
| `GET` | `/beneficiaries/{id}` | Chi tiết hồ sơ người thân (kiểm tra quyền sở hữu) |
| `POST` | `/beneficiaries` | Tạo hồ sơ người thân mới |
| `PUT` | `/beneficiaries/{id}` | Cập nhật hồ sơ (chỉ owner) |
| `DELETE` | `/beneficiaries/{id}` | Soft-delete (gán `DeletedAt`) |

> ⚠️ **RLS Pattern:** Mỗi mutation mở transaction và gọi `SET app.current_user_id = userId` trước khi thao tác, đảm bảo không có data leak giữa các tài khoản khác nhau.

---

## 3. Module Booking — Vòng Đời Ca Chăm Sóc

### 3.1 `BookingsController` — Route: `/api/v1/bookings`

Quản lý toàn bộ lifecycle booking. Phân quyền tự động theo role JWT.

#### Quyền theo Role:

| Role | Quyền truy cập danh sách | Quyền thao tác lifecycle |
|---|---|---|
| `CUSTOMER` | Booking của mình | Tạo, hủy, thanh toán, hoàn tất (xác nhận) |
| `CAREGIVER` | Ca được giao; Ca mở (`status=open`) | Accept, en-route, check-in, checkout, complete |
| `ADMIN` | Tất cả | Hoàn tất ca thay caregiver |

#### CRUD:

| Method | Endpoint | Mô tả |
|:---:|---|---|
| `POST` | `/bookings` | Tạo booking mới qua MediatR, trạng thái ban đầu: `PENDING_PAYMENT` |
| `GET` | `/bookings` | Lấy danh sách booking (role-aware, phân trang) |
| `GET` | `/bookings/{id}` | Chi tiết booking (403 nếu không có quyền) |
| `POST` | `/bookings/{id}/cancel` | Hủy booking (Customer), ghi lý do |
| `PUT` | `/bookings/{id}/schedule` | Dời lịch: kiểm tra caregiver rảnh, tính lại giá |
| `PUT` | `/bookings/{id}/caregiver` | Chọn caregiver cho booking |

#### Lifecycle Endpoints:

| Method | Endpoint | Người thực hiện | Chuyển trạng thái | Hành động phụ |
|:---:|---|:---:|---|---|
| `POST` | `/bookings/{id}/confirm-payment` | Customer | `PENDING_PAYMENT` → `CONFIRMED` | `WalletService.LockEscrowAsync()` |
| `POST` | `/bookings/{id}/accept` | Caregiver | `CONFIRMED` → `ASSIGNED` | Ghi timeline `CHECKIN` |
| `POST` | `/bookings/{id}/en-route` | Caregiver | `ASSIGNED` → `EN_ROUTE` | Ghi timeline `CHECKIN` |
| `POST` | `/bookings/{id}/check-in` | Caregiver + GPS | `EN_ROUTE` → `IN_PROGRESS` | Ghi `GpsTrack` + timeline `CHECKIN_VALID/OUTSIDE` |
| `POST` | `/bookings/{id}/checkout/request` | Caregiver | `IN_PROGRESS` → `CHECKOUT_PENDING` | Ghi timeline `CHECKOUT_MANUAL_REQUESTED` |
| `POST` | `/bookings/{id}/complete` | Caregiver/Admin | `CHECKOUT_PENDING` → `COMPLETED` | `WalletService.SettleAsync()` + timeline `CHECKOUT` |
| `POST` | `/bookings/{id}/sos` | Customer | (không đổi status) | Ghi timeline `SOS` |

---

## 4. Service Xuyên Module — `IPeopleLookupService`

Được đăng ký bởi PeopleModule, được sử dụng bởi BookingModule và các Handler. Không cho phép import DbContext trực tiếp giữa các module.

| Phương thức | Mô tả | Điều kiện trả về `true` | Nơi sử dụng |
|---|---|---|---|
| `BeneficiaryBelongsToAsync(beneficiaryId, customerId)` | Kiểm tra người thân thuộc về customer qua **PostgreSQL RLS** | `CustomerId == customerId AND DeletedAt == null` | `CreateBookingHandler` |
| `CaregiverIsAvailableAsync(caregiverId, start, end)` | KYC APPROVED + có slot rảnh phủ kín khung giờ | `KycStatus == APPROVED AND slot.StartAt <= start AND slot.EndAt >= end` | `Reschedule`, `SelectCaregiver` |
| `IsCaregiverApprovedAsync(caregiverId)` | Kiểm tra nhanh KYC APPROVED | `KycStatus == APPROVED AND DeletedAt == null` | Booking creation validation |
| `IsCaregiverForBookingAsync(caregiverId, userId)` | Người gọi API chính là chủ của CaregiverProfile | `CaregiverProfile.UserId == userId AND DeletedAt == null` | `Accept`, `EnRoute`, `CheckIn`, `Checkout` |
| `GetCaregiverProfileIdByUserIdAsync(userId)` | Map JWT userId → CaregiverProfile.Id | — | `BookingsController.List/Get` khi role = CAREGIVER |

---

## 5. State Machine Booking

```
PENDING_PAYMENT  ←── Booking mới tạo
       │
       │  POST /confirm-payment  (Customer · LockEscrow)
       ▼
  CONFIRMED  ←── Booking đang chờ caregiver nhận
       │
       │  POST /accept  (Caregiver)
       ▼
  ASSIGNED
       │
       │  POST /en-route  (Caregiver)
       ▼
  EN_ROUTE
       │
       │  POST /check-in  (Caregiver + GPS)
       ▼
  IN_PROGRESS
       │
       │  POST /checkout/request  (Caregiver)
       ▼
  CHECKOUT_PENDING_REVIEW
       │
       │  POST /complete  (Caregiver / Admin · SettleEscrow)
       ▼
  COMPLETED ─── Escrow giải ngân → Caregiver nhận tiền
       │
       ├── Customer: POST /reviews
       └── Customer: POST /disputes (→ DISPUTED)

Từ PENDING_PAYMENT / CONFIRMED / ASSIGNED:
  POST /cancel  (Customer) → CANCELLED
```

---

## 6. Build Status

```
Backend:       dotnet build → ✅ Build succeeded. 0 Warning(s), 0 Error(s)
Customer App:  flutter analyze --no-fatal-infos → ✅ 0 Errors
Caregiver App: flutter analyze --no-fatal-infos → ✅ 0 Errors
```

---

## 7. Seed Data — Tài Khoản Kiểm Thử

| Email | SĐT | Mật khẩu | Role |
|---|---|---|:---:|
| `nguoithan@example.com` | `0911111111` | `Password123!` | CUSTOMER |
| `bichngoc@example.com` | `0912333444` | `Password123!` | CAREGIVER |
| `levanhung@example.com` | `0912444555` | `Password123!` | CAREGIVER |
| `nguoicham@example.com` | `0922222222` | `Password123!` | CAREGIVER |
| `admin@caresitter.vn` | — | `Password123!` | ADMIN |
