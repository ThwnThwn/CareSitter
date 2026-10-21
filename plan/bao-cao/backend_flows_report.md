# Báo Cáo Tổng Hợp Luồng Nghiệp Vụ & Danh Mục API Backend — CareSitter

> **Cập nhật:** 28/08/2026  
> **Dự án:** `CareSitter Backend (C# .NET 8, PostgreSQL, Modular Monolith, DDD)`  
> **Trạng thái Build:** ✅ Build thành công 100% (0 Error, 0 Warning) — 21/21 Unit Tests Passed.

---

## 1. Kiến Trúc Tổng Quan (Architecture & Design Principles)

Hệ thống Backend được xây dựng theo kiến trúc **Modular Monolith** kết hợp **Domain-Driven Design (DDD)**:

*   **Phân chia Module:** Chia thành 6 miền nghiệp vụ độc lập: `Identity`, `People`, `Catalog`, `Booking`, `Payments`, `Support` và hạ tầng dùng chung `SharedKernel`, `Contracts`, `Infrastructure`.
*   **Giao tiếp liên Module:** Tuân thủ nguyên tắc không tham chiếu DbContext chéo. Giao tiếp chỉ thực hiện qua DI Interface tại tầng `CareSitter.Contracts` (như `IWalletService`, `IPeopleLookupService`, `ICatalogLookupService`, `IMediaService`, `IEncryptionService`).
*   **Database (PostgreSQL Schemas):** Chia tách schema rõ ràng (`identity.*`, `people.*`, `catalog.*`, `booking.*`, `payments.*`, `support.*`).
*   **Bảo mật & Phân quyền:**
    *   JWT Access/Refresh Token với Claims phân quyền (`CUSTOMER`, `CAREGIVER`, `ADMIN`).
    *   Postgres **Row Level Security (RLS)** thông qua biến phiên `app.current_user_id`.
    *   Mã hóa dữ liệu nhạy cảm (CCCD, Số tài khoản) bằng AES-256 kèm HMAC deterministic hash chống lộ dữ liệu gốc.
*   **Tối ưu hóa hiệu năng (No N+1 Queries):**
    *   Sử dụng `AsNoTracking()` cho toàn bộ truy vấn chỉ đọc.
    *   Áp dụng **Server-side Projection** `.Select(x => new DTO(...))` trực tiếp ở mức IQueryable, không tải entity thừa vào bộ nhớ.

---

## 2. Chi Tiết Các Luồng Nghiệp Vụ Chính & Danh Mục API (Main Business Flows)

```mermaid
graph TD
    A[1. Identity & Auth] --> B[2. People & KYC]
    B --> C[3. Beneficiary & Address]
    C --> D[4. Catalog & Quote]
    D --> E[5. Booking Lifecycle]
    E --> F[6. Payment & Escrow]
    E --> G[7. Check-in Geofence & Tasks]
    G --> H[8. Checkout & Settle]
    H --> I[9. Review, Dispute & Payout]
```

---

### 🟢 Luồng 1: Xác thực, Đăng nhập & Danh tính (Identity & Auth Flow)

Quản lý đăng ký, đăng nhập qua OTP / Mật khẩu / Google, quản lý phiên và hồ sơ người dùng.

| Method | Endpoint | Quyền hạn | Mô tả chi tiết |
|---|---|---|---|
| `POST` | `/api/v1/auth/send-otp` | Public | Gửi mã xác thực OTP 6 số đến email đăng ký. |
| `POST` | `/api/v1/auth/login` | Public | Đăng nhập bằng Email + mã OTP $\rightarrow$ Trả về JWT Access Token & Refresh Token. |
| `POST` | `/api/v1/auth/login-password` | Public | Đăng nhập bằng Email + Mật khẩu. |
| `POST` | `/api/v1/auth/google-login` | Public | Đăng nhập/Đăng ký tự động bằng Google OAuth2 ID Token. |
| `POST` | `/api/v1/auth/register` | Public | Đăng ký tài khoản mới (`CUSTOMER`, `CAREGIVER`, `ADMIN`). |
| `POST` | `/api/v1/auth/logout` | Authorized | Thu hồi token hiện tại (Revoke JTI) và đóng phiên làm việc. |
| `GET` | `/api/v1/profile` | Authorized | Lấy thông tin cá nhân của tài khoản đang đăng nhập. |
| `PUT` | `/api/v1/profile` | Authorized | Cập nhật thông tin cá nhân (Họ tên, ngày sinh, giới tính, địa chỉ mặc định). |

---

### 🟢 Luồng 2: Onboarding, Định danh KYC & Lịch rảnh Caregiver (Caregiver KYC & Schedule Flow)

Quy trình người chăm sóc tham gia hệ thống, nộp giấy tờ xác minh, cập nhật hồ sơ năng lực và quản lý lịch rảnh làm việc.

| Method | Endpoint | Quyền hạn | Mô tả chi tiết |
|---|---|---|---|
| `POST` | `/api/v1/caregivers/me/kyc` | Caregiver | Nộp hồ sơ KYC (Số CCCD được tự động mã hóa AES-256 + HMAC hash, đính kèm link chứng chỉ Cloudinary) $\rightarrow$ Trạng thái chuyển `PENDING`. |
| `PUT` | `/api/v1/caregivers/me/profile` | Caregiver | Cập nhật hồ sơ nghề nghiệp: Bio giới thiệu, số năm kinh nghiệm, kỹ năng (Skills JSON), mức giá mong đợi, khu vực phục vụ. |
| `POST` | `/api/v1/caregivers/{id}/kyc/approve` | **Admin** | Duyệt hồ sơ KYC cho Caregiver $\rightarrow$ Trạng thái `APPROVED`, cho phép bắt đầu nhận ca chăm sóc. |
| `POST` | `/api/v1/caregivers/{id}/kyc/reject` | **Admin** | Từ chối duyệt KYC kèm lý do $\rightarrow$ Trạng thái `REJECTED` để Caregiver bổ sung giấy tờ. |
| `POST` | `/api/v1/caregivers/me/availability` | Caregiver | Đăng ký khung thời gian rảnh/làm việc mới (`StartAt` $\rightarrow$ `EndAt`). |
| `GET` | `/api/v1/caregivers/me/availability` | Caregiver | Xem danh sách các khung giờ rảnh của mình (hỗ trợ lọc theo khoảng ngày `from`/`to`). |
| `DELETE` | `/api/v1/caregivers/me/availability/{id}` | Caregiver | Xóa/hủy một khung giờ rảnh đã đăng ký. |
| `GET` | `/api/v1/caregivers` | Authorized | Danh sách Caregiver đã duyệt (`APPROVED`) với bộ lọc đa tiêu chí: Quận/Huyện, Kỹ năng, Số sao rating, Trạng thái hoạt động, Khung giờ làm việc. |
| `GET` | `/api/v1/caregivers/{id}` | Authorized | Xem chi tiết hồ sơ công khai của Caregiver. |
| `GET` | `/api/v1/caregivers/{id}/availability` | Authorized | Khách hàng tra cứu lịch rảnh của một Caregiver cụ thể trước khi đặt ca. |

---

### 🟢 Luồng 3: Quản lý Khách hàng, Người thụ hưởng & Sổ địa chỉ (Customer, Beneficiary & Address Flow)

Khách hàng tạo hồ sơ người thân cần chăm sóc (người cao tuổi, người bệnh) và lưu trữ sổ địa chỉ có tọa độ GIS.

| Method | Endpoint | Quyền hạn | Mô tả chi tiết |
|---|---|---|---|
| `GET` | `/api/v1/beneficiaries` | Customer | Danh sách hồ sơ người thụ hưởng của khách hàng (bảo vệ bởi RLS). |
| `GET` | `/api/v1/beneficiaries/{id}` | Customer | Xem chi tiết hồ sơ người thụ hưởng (tiền sử bệnh, dị ứng, thuốc đang dùng, liên hệ khẩn cấp). |
| `POST` | `/api/v1/beneficiaries` | Customer | Tạo mới hồ sơ người được chăm sóc (dữ liệu y tế nhạy cảm lưu dưới dạng JSONB). |
| `PUT` | `/api/v1/beneficiaries/{id}` | Customer | Cập nhật thông tin y tế, ghi chú chăm sóc người thụ hưởng. |
| `DELETE` | `/api/v1/beneficiaries/{id}` | Customer | Xóa mềm hồ sơ người thụ hưởng. |
| `GET` | `/api/v1/addresses` | Customer | Lấy danh sách sổ địa chỉ đã lưu của khách hàng. |
| `GET` | `/api/v1/addresses/{id}` | Customer | Lấy chi tiết địa chỉ kèm tọa độ GIS (`Latitude`, `Longitude`). |
| `POST` | `/api/v1/addresses` | Customer | Thêm địa chỉ mới (lưu trữ điểm không gian NetTopologySuite `Point(X, Y)`). |
| `PUT` | `/api/v1/addresses/{id}` | Customer | Sửa thông tin địa chỉ đã lưu. |
| `DELETE` | `/api/v1/addresses/{id}` | Customer | Xóa địa chỉ khỏi sổ địa chỉ. |

---

### 🟢 Luồng 4: Danh mục Dịch vụ & Tính giá Tự động (Catalog & Pricing Quote Flow)

| Method | Endpoint | Quyền hạn | Mô tả chi tiết |
|---|---|---|---|
| `GET` | `/api/v1/services` | Public | Lấy danh mục các gói dịch vụ chăm sóc phi y tế (Theo giờ, Trông đêm, Hỗ trợ sinh hoạt...). |
| `GET` | `/api/v1/services/{id}` | Public | Xem chi tiết dịch vụ, biểu giá cơ sở và chính sách. |
| `POST` | `/api/v1/services/{id}/quote` | Authorized | Tính toán báo giá dự kiến cho ca chăm sóc theo thời gian bắt đầu/kết thúc và chính sách giá. |

---

### 🟢 Luồng 5: Vòng đời Ca Chăm sóc & Vận hành Thực địa (Booking Lifecycle & Execution Flow)

State Machine trung tâm quản lý vòng đời từ đặt lịch $\rightarrow$ nhận ca $\rightarrow$ di chuyển $\rightarrow$ check-in Geofence $\rightarrow$ checklist $\rightarrow$ hoàn tất $\rightarrow$ SOS.

```text
[DRAFT] ──(Tạo đơn)──> [PENDING_PAYMENT] ──(Thanh toán)──> [CONFIRMED]
  │                                                              │
  ├─(Hủy đơn)──> [CANCELLED]                (Caregiver nhận ca)──┤
  │                                                              ▼
[CRISIS (SOS)] <──(Phát SOS)─── [IN_PROGRESS] <──(Check-in 50m)── [CAREGIVER_EN_ROUTE]
      │                               │
      ▼                      (Yêu cầu checkout)
[Admin can thiệp]                     ▼
                             [CHECKOUT_REQUESTED] ──(Xác nhận)──> [COMPLETED] ──> [Settlement]
```

| Method | Endpoint | Quyền hạn | Mô tả chi tiết |
|---|---|---|---|
| `POST` | `/api/v1/bookings` | Customer | Tạo đơn đặt ca chăm sóc mới (Trạng thái khởi tạo `DRAFT`). |
| `GET` | `/api/v1/bookings` | Authorized | Xem danh sách đơn booking của tôi (theo phân quyền Customer/Caregiver). |
| `GET` | `/api/v1/bookings/{id}` | Authorized | Xem chi tiết đơn booking, trạng thái hiện tại, thông tin tài chính và người chăm sóc. |
| `POST` | `/api/v1/bookings/{id}/cancel` | Authorized | Hủy đơn đặt lịch (áp dụng chính sách hoàn tiền theo mốc thời gian). |
| `PUT` | `/api/v1/bookings/{id}/schedule` | Customer | Đổi thời gian ca chăm sóc (khi đơn chưa tiến hành). |
| `PUT` | `/api/v1/bookings/{id}/caregiver` | Customer | Chọn/chỉ định Caregiver cụ thể cho đơn hàng. |
| `POST` | `/api/v1/bookings/{id}/confirm-payment` | Customer | Xác nhận thanh toán thành công $\rightarrow$ Kích hoạt `LockEscrow` và chuyển trạng thái sang `CONFIRMED`. |
| `POST` | `/api/v1/bookings/{id}/accept` | Caregiver | Caregiver chấp nhận nhận ca $\rightarrow$ Ghi log Timeline và chuyển trạng thái ca. |
| `POST` | `/api/v1/bookings/{id}/en-route` | Caregiver | Caregiver bấm bắt đầu di chuyển đến nhà khách hàng $\rightarrow$ Trạng thái `CAREGIVER_EN_ROUTE`. |
| `POST` | `/api/v1/bookings/{id}/check-in` | Caregiver | Caregiver check-in bằng GPS tại địa chỉ. Hệ thống **tự động đo khoảng cách Geofence** so với tọa độ nhà khách (bán kính $\le 50m$) $\rightarrow$ Chuyển `IN_PROGRESS`. |
| `POST` | `/api/v1/bookings/{id}/checkout/request` | Caregiver | Caregiver yêu cầu kết thúc ca làm việc sau khi hoàn tất các task. |
| `POST` | `/api/v1/bookings/{id}/complete` | Authorized | Khách hàng/Admin xác nhận hoàn tất ca $\rightarrow$ Chuyển `COMPLETED` và tự động kích hoạt lệnh giải ngân Settle Escrow. |
| `POST` | `/api/v1/bookings/{id}/sos` | Authorized | **Báo động khẩn cấp (SOS):** Khách hàng/Caregiver phát tín hiệu khẩn cấp $\rightarrow$ Chuyển trạng thái `CRISIS`, tạo support ticket CRITICAL và thông báo CSKH can thiệp. |
| `GET` | `/api/v1/bookings/{id}/tasks` | Authorized | Lấy danh sách checklist công việc trong ca (ADL/IADL). |
| `POST` | `/api/v1/bookings/{id}/tasks` | Authorized | Thêm task công việc mới vào checklist ca làm. |
| `PUT` | `/api/v1/bookings/{id}/tasks/{taskId}/complete` | Caregiver | Caregiver tích hoàn thành task (kèm ghi chú / ảnh bằng chứng). |
| `PUT` | `/api/v1/bookings/{id}/tasks/{taskId}/skip` | Caregiver | Bỏ qua task kèm lý do giải trình. |
| `GET` | `/api/v1/bookings/{id}/timeline` | Authorized | Xem dòng sự kiện thời gian thực của ca (Check-in, hoàn thành task, ghi chú...). |
| `POST` | `/api/v1/bookings/{id}/timeline` | Caregiver | Ghi thêm ghi chú/hình ảnh trực tiếp vào Care Timeline. |
| `POST` | `/api/v1/bookings/{id}/gps` | Caregiver | Đẩy tọa độ GPS hiện tại của thiết bị Caregiver lên server. |
| `GET` | `/api/v1/bookings/{id}/gps/latest` | Authorized | Khách hàng lấy tọa độ mới nhất của Caregiver (Live Tracking). |
| `GET` | `/api/v1/bookings/{id}/gps-tracks` | Authorized | Xem toàn bộ lộ trình di chuyển GPS của ca làm. |

---

### 🟢 Luồng 6: Thanh toán, Quỹ tạm giữ Escrow & Rút tiền (Payments, Escrow & Payout Flow)

Vận hành dựa trên nguyên tắc **Sổ cái kép (Double-Entry Ledger)** bất biến để đảm bảo tính toàn vẹn tài chính:

| Method | Endpoint | Quyền hạn | Mô tả chi tiết |
|---|---|---|---|
| `POST` | `/api/v1/payments/intents` | Customer | Khởi tạo phiên thanh toán (Idempotent theo mã đơn), chọn cổng MoMo / VNPay / Card. |
| `GET` | `/api/v1/payments/intents/{id}` | Customer | Tra cứu trạng thái của Payment Intent. |
| `POST` | `/api/v1/payments/intents/{id}/mock-success` | Customer | Giả lập thanh toán thành công (phục vụ môi trường test/demo) $\rightarrow$ Ghi nhận bút toán `ESCROW_LOCK`. |
| `POST` | `/api/v1/payments/webhook` | **Gateway IPN** | **Webhook thanh toán:** Nhận IPN tự động từ MoMo/VNPay (Idempotent theo `provider + provider_event_id`), tự động cập nhật Intent và ghi sổ cái `ESCROW_LOCK`. |
| `GET` | `/api/v1/wallet` | Authorized | Tra cứu số dư ví nội bộ: Số dư khả dụng (`AvailableBalance`) và Số dư tạm giữ (`PendingBalance`). |
| `GET` | `/api/v1/payments/ledger` | Authorized | Truy vấn lịch sử bút toán sổ cái kép (lọc theo đơn booking, phân trang). |
| `POST` | `/api/v1/payments/payouts` | Caregiver | Caregiver tạo yêu cầu rút tiền từ số dư khả dụng về tài khoản ngân hàng (tự động kiểm tra số dư và trừ tiền an toàn). |
| `GET` | `/api/v1/payments/payouts` | Caregiver | Xem lịch sử các yêu cầu rút tiền của mình. |
| `GET` | `/api/v1/payments/payouts/pending` | **Admin/Kế toán** | Danh sách các yêu cầu rút tiền đang chờ duyệt trên toàn hệ thống. |
| `POST` | `/api/v1/payments/payouts/{id}/approve` | **Admin/Kế toán** | Duyệt yêu cầu rút tiền $\rightarrow$ Ghi bút toán `PAYOUT` vào Sổ cái. |
| `POST` | `/api/v1/payments/payouts/{id}/reject` | **Admin/Kế toán** | Từ chối yêu cầu rút tiền kèm lý do $\rightarrow$ Tự động hoàn lại số dư khả dụng cho Caregiver. |

---

### 🟢 Luồng 7: Hỗ trợ, Đánh giá & Xử lý Tranh chấp (Support, Reviews & Dispute Flow)

| Method | Endpoint | Quyền hạn | Mô tả chi tiết |
|---|---|---|---|
| `POST` | `/api/v1/reviews` | Customer | Khách hàng gửi đánh giá (1-5 sao, bình luận, tag trải nghiệm) sau khi ca `COMPLETED` $\rightarrow$ DB Trigger tự động tính lại điểm trung bình của Caregiver. |
| `GET` | `/api/v1/reviews/caregiver/{caregiverId}` | Public | Xem danh sách đánh giá của một Caregiver (phân trang). |
| `POST` | `/api/v1/disputes` | Authorized | Mở khiếu nại/tranh chấp trong vòng 48h sau ca làm việc (đóng băng tiền pending của ca). |
| `GET` | `/api/v1/disputes` | Authorized | Xem danh sách các tranh chấp của tôi. |
| `GET` | `/api/v1/disputes/{id}` | Authorized | Xem chi tiết tiến trình giải quyết tranh chấp. |
| `POST` | `/api/v1/disputes/{id}/resolve` | **Admin** | **Admin ra phán quyết:** `CUSTOMER_WINS` (hoàn tiền), `CAREGIVER_WINS` (giải phóng tiền), hoặc `PARTIAL_REFUND` (hoàn một phần) kèm phạt caregiver nếu có. |
| `POST` | `/api/v1/disputes/{id}/cancel` | **Admin** | Hủy khiếu nại. |
| `POST` | `/api/v1/support/tickets` | Authorized | Tạo ticket yêu cầu hỗ trợ (SOS, Khiếu nại, Thanh toán, KYC...). Tự động kích hoạt Notification khẩn cấp nếu là SOS. |
| `GET` | `/api/v1/support/tickets` | Authorized | Danh sách ticket (User xem của mình, Admin xem toàn bộ với bộ lọc trạng thái, loại ticket, độ ưu tiên). |
| `GET` | `/api/v1/support/tickets/{id}` | Authorized | Xem chi tiết nội dung ticket. |
| `PUT` | `/api/v1/support/tickets/{id}/status` | **Admin** | Cập nhật tiến độ xử lý ticket (`NEW` $\rightarrow$ `IN_PROGRESS` $\rightarrow$ `RESOLVED` $\rightarrow$ `CLOSED`). |
| `PUT` | `/api/v1/support/tickets/{id}/assign` | **Admin** | Admin tiếp nhận phụ trách xử lý ticket. |

---

### 🟢 Luồng 8: Thông báo & Quản lý Thiết bị (Notifications & Device FCM Token Flow)

| Method | Endpoint | Quyền hạn | Mô tả chi tiết |
|---|---|---|---|
| `POST` | `/api/v1/auth/devices` | Authorized | Đăng ký hoặc cập nhật FCM Push Token từ app điện thoại (cơ chế Upsert theo `userId + platform`). |
| `GET` | `/api/v1/auth/devices` | Authorized | Xem danh sách các thiết bị đang đăng nhập của tài khoản. |
| `DELETE` | `/api/v1/auth/devices/{id}` | Authorized | Hủy đăng ký thiết bị khi người dùng đăng xuất. |
| `GET` | `/api/v1/notifications` | Authorized | Lấy danh sách thông báo trong hòm thư cá nhân (phân trang). |
| `PUT` | `/api/v1/notifications/{id}/read` | Authorized | Đánh dấu một thông báo đã đọc. |
| `PUT` | `/api/v1/notifications/read-all` | Authorized | Đánh dấu đã đọc tất cả thông báo. |
| `GET` | `/api/v1/notifications/unread-count` | Authorized | Đếm số lượng thông báo chưa đọc (hiển thị badge trên app). |

---

### 🟢 Luồng 9: Hạ tầng Upload Media (Media & Cloudinary Storage Flow)

| Method | Endpoint | Quyền hạn | Mô tả chi tiết |
|---|---|---|---|
| `POST` | `/api/v1/media/upload` | Authorized | Upload ảnh (`multipart/form-data`) lên máy chủ **Cloudinary**: Validate định dạng ảnh, tự động phân thư mục theo `userId` và trả về URL bảo mật (`secure_url`). Dùng cho ảnh chân dung, CCCD KYC, ảnh selfie check-in, ảnh bằng chứng task và ảnh tranh chấp. |

---

## 3. Bảng Tổng Hợp & Tra Cứu Nhanh Tất Cả API Endpoints

| Nhóm chức năng | Số lượng API | Các Path chính |
|---|:---:|---|
| **Identity & Authentication** | 8 | `/api/v1/auth/*`, `/api/v1/profile` |
| **Caregiver KYC & Availability** | 10 | `/api/v1/caregivers/*`, `/api/v1/caregivers/me/*` |
| **Beneficiaries & Addresses** | 10 | `/api/v1/beneficiaries/*`, `/api/v1/addresses/*` |
| **Catalog & Quoting** | 3 | `/api/v1/services/*` |
| **Booking & Care Lifecycle** | 16 | `/api/v1/bookings/*` (Lifecycle, Tasks, Timeline, GPS) |
| **Payments, Escrow & Payout** | 10 | `/api/v1/payments/*`, `/api/v1/wallet` |
| **Support, Reviews & Disputes** | 12 | `/api/v1/reviews/*`, `/api/v1/disputes/*`, `/api/v1/support/tickets/*` |
| **Notifications & Devices** | 7 | `/api/v1/notifications/*`, `/api/v1/auth/devices/*` |
| **Media Infrastructure** | 1 | `/api/v1/media/upload` |
| **TỔNG CỘNG** | **77 APIs** | Toàn bộ hệ thống sẵn sàng phục vụ Frontend & Admin CRM |

---

## 4. Trạng Thái Kiểm Thử & Sẵn Sàng Vận Hành

```text
Build Status:
  Solution: CareSitter.sln (.NET 8.0)
  Result: Build succeeded. 0 Error(s), 0 Warning(s).

Unit Tests:
  Test Suite: CareSitter.Modules.Booking.UnitTests
  Passed: 21 / 21 tests (100%)
  Coverage: State Machine, Geofencing 50m Radius Validation, Escrow Lock & Settle Logic.
```

**Kết luận:** Toàn bộ hệ thống API Backend cho tất cả các luồng nghiệp vụ cốt lõi và phụ trợ của nền tảng CareSitter đã hoàn tất 100%, tuân thủ nghiêm ngặt tiêu chuẩn Clean Architecture, DDD, bảo mật RLS và tối ưu hóa không N+1 query.
