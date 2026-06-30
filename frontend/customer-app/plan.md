# 🗺️ Kế hoạch Triển khai — CareSitter Customer App
> Cập nhật: 27/06/2026 | Phiên làm việc: Audit Booking Flow 5.1

---

## 📌 Mục tiêu
Hoàn thiện toàn bộ tính năng Customer App theo spec, sẵn sàng cho demo/beta.

---

## ✅ Đã hoàn thành (tính đến 27/06/2026)

| # | Task | Màn hình / File | Ghi chú |
|---|------|-----------------|---------|
| ✅ | Tạo hồ sơ người được chăm sóc (beneficiary) | `beneficiary_create_screen.dart` | Đủ field: tên, tuổi, dị ứng, thuốc, liên hệ khẩn cấp |
| ✅ | Chỉnh sửa / xem hồ sơ beneficiary | `beneficiary_edit_screen.dart`, `beneficiary_detail_screen.dart` | |
| ✅ | Booking Wizard 6 bước | `booking_wizard_screen.dart` | Dịch vụ → Người thân → Caregiver → Thời gian → Đồng ý → Confirm |
| ✅ | Consent Form (FR-CUS-09) | Step 4 của Wizard | 6 mục điều khoản + checkbox bắt buộc |
| ✅ | Danh sách lịch hẹn (tabs) | `booking_list_screen.dart` | Tab: Sắp tới / Đang diễn ra / Hoàn thành |
| ✅ | Chi tiết lịch hẹn + actions theo status | `booking_detail_screen.dart` | pending/confirmed/in_progress/completed/cancelled |
| ✅ | Theo dõi ca (shift tracking) + map mockup | `shift_tracking_screen.dart` | GPS illustration, checklist |
| ✅ | Nhật ký chăm sóc timeline | `care_timeline_screen.dart` | 7 sự kiện timeline có icon + màu |
| ✅ | Xác nhận hoàn thành ca (thay OTP checkout) | `booking_detail_screen.dart`, `shift_tracking_screen.dart` | Dialog confirm + note admin tự xử lý sau 2h |
| ✅ | Gia hạn ca (bottom sheet) | `booking_detail_screen.dart`, `shift_tracking_screen.dart` | Chọn 1–4h, ước tính phí |
| ✅ | Đánh giá dịch vụ sau ca | `review_screen.dart` | Rating 5 sao, tags, nhận xét |
| ✅ | Khiếu nại / dispute + đính kèm bằng chứng | `dispute_screen.dart` | Upload ảnh/video |
| ✅ | Chỉnh sửa hồ sơ cá nhân | `profile_edit_screen.dart` | |
| ✅ | Phương thức thanh toán (stub) | `payment_methods_screen.dart` | |
| ✅ | Địa chỉ đã lưu (stub) | `saved_addresses_screen.dart` | |
| ✅ | Đổi mật khẩu | `change_password_screen.dart` | |
| ✅ | Xác thực 2 yếu tố (stub) | `two_factor_auth_screen.dart` | |
| ✅ | FAQ | `faq_screen.dart` | |
| ✅ | Hỗ trợ / liên hệ | `support_screen.dart` | |
| ✅ | Danh sách & hồ sơ caregiver | `caregiver_list_screen.dart`, `caregiver_profile_screen.dart` | |
| ✅ | Catalog dịch vụ | `catalog_screen.dart` | |
| ✅ | Home dashboard + active shift banner | `home_screen.dart` | Stats, upcoming bookings |
| ✅ | Auth (phone + OTP) — bypass mode | `phone_input_screen.dart`, `otp_verify_screen.dart` | kDebugBypassAuth = true |
| ✅ | Router đầy đủ (go_router) | `app_router.dart` | 20+ routes |

---

## ❌ Còn thiếu — Cần làm

### 🔴 Ưu tiên cao (ảnh hưởng UX trực tiếp)

#### T-N01: Thêm step chọn địa chỉ vào Booking Wizard
- **Vấn đề**: BookingWizardScreen không có step chọn địa chỉ. MockBooking.address tồn tại nhưng không được capture khi tạo booking.
- **File**: `lib/features/booking/presentation/screens/booking_wizard_screen.dart`
- **Cách làm**:
  - Thêm step mới "Địa chỉ" (hoặc nhúng vào step "Xác nhận")
  - Hiển thị danh sách địa chỉ đã lưu từ MockData.savedAddresses
  - Cho phép nhập địa chỉ mới
  - Lưu `_selectedAddress` vào state wizard
- **Ước tính**: ~1–1.5h

#### T-N02: Sau khi xác nhận booking → navigate sang BookingDetail
- **Vấn đề**: Hiện tại bấm "Xác nhận đặt lịch" chỉ show SnackBar rồi context.pop(). Booking mới không được tạo và không navigate đúng.
- **File**: `booking_wizard_screen.dart` (L756–760)
- **Cách làm**: Tạo mock booking mới với ID ngẫu nhiên → `context.go('/bookings/{newId}')`
- **Ước tính**: ~30–45 phút

#### T-N03: Màn hình Thông báo (Notifications)
- **Vấn đề**: Icon chuông trên HomeScreen navigate sai sang `/bookings`. MockData.notifications đã có 5 bản ghi nhưng chưa có màn hình.
- **Cần tạo**: `lib/features/home/presentation/notifications_screen.dart`
- **Route mới**: `/notifications`
- **Ước tính**: ~1h

---

### 🟡 Ưu tiên trung bình

#### T-N04: Lọc caregiver thông minh trong Wizard
- **Vấn đề**: Step Caregiver chỉ lọc isAvailable, không xét dịch vụ/thời gian/khu vực đã chọn.
- **File**: `booking_wizard_screen.dart` (L263)
- **Cách làm**: Filter caregivers theo _selectedServiceId và _selectedDate
- **Ước tính**: ~1h

#### T-N05: Checklist trong ShiftTracking lấy từ booking thực tế
- **Vấn đề**: _tasks() trong shift_tracking_screen.dart hardcode 6 task cố định, không theo dịch vụ.
- **File**: `shift_tracking_screen.dart` (L305–312)
- **Cách làm**: Map task list theo bk.serviceName
- **Ước tính**: ~30 phút

#### T-N06: Tích hợp chọn phương thức thanh toán vào Wizard (stub)
- **Vấn đề**: Bước confirm chỉ hiển thị tổng tiền, không có chọn phương thức thanh toán.
- **File**: `booking_wizard_screen.dart` — _buildConfirmStep()
- **Cách làm**: Thêm selector phương thức thanh toán từ MockData.paymentMethods
- **Ước tính**: ~45 phút

---

### ⬜ Chờ Backend (không làm trong mock phase)

| Task | Mô tả | Điều kiện |
|------|-------|-----------|
| T-B01 | Bật OTP API thật, bỏ kDebugBypassAuth | Có endpoint POST /auth/verify-otp |
| T-B02 | GPS tracking thật (Google Maps + WebSocket) | Có GET /shifts/:id/location realtime |
| T-B03 | Thay toàn bộ MockData bằng Dio API calls | Backend hoàn chỉnh |
| T-B04 | Push notifications thật (FCM) | Firebase setup |
| T-B05 | Payment gateway (VNPay/MoMo) | Merchant account |
| T-B06 | Ghi nhận doanh thu/thu nhập | Admin/backend |

---

## 📊 Trạng thái Booking Flow 5.1 theo spec

| Bước spec | Mô tả | Trạng thái | Task liên quan |
|-----------|-------|------------|----------------|
| 1 | Customer tạo hồ sơ người cần chăm sóc | ✅ Xong | — |
| 2a | Chọn dịch vụ | ✅ Xong | — |
| 2b | Chọn thời gian | ✅ Xong | — |
| 2c | Chọn địa chỉ | ❌ Thiếu | T-N01 |
| 3 | Lọc caregiver phù hợp | ⚠️ Partial | T-N04 |
| 4 | Chọn caregiver | ✅ Xong | — |
| 5 | Xác nhận consent form | ✅ Xong | — |
| 6 | Thanh toán / xác nhận booking | ⚠️ Mock only | T-N06 |
| 7 | Caregiver nhận ca | 🔵 Caregiver app | — |
| 8 | Caregiver di chuyển | ⚠️ UI illustration | T-B02 |
| 9 | Caregiver check-in GPS | ⚠️ UI illustration | T-B02 |
| 10 | Checklist + timeline | ✅ UI xong | T-N05 (cải tiến) |
| 11–12 | Checkout: Customer bấm "Đã hoàn thành" | ✅ Xong — dialog + admin fallback 2h | — |
| 13 | Booking hoàn thành | ✅ Xong | — |
| 14 | Customer đánh giá | ✅ Xong | — |
| 15 | Ghi nhận doanh thu | 🔵 Backend | T-B06 |

---

## 🏃 Lộ trình tiếp theo (gợi ý)

```
ƯU TIÊN NGAY (~3h)
├── T-N01  Thêm step địa chỉ vào Wizard         [~1.5h]
├── T-N02  Navigate đúng sau khi tạo booking     [~45m]
└── T-N03  Màn hình Thông báo                   [~1h]

SPRINT NGẮN (~2.5h)
├── T-N04  Lọc caregiver thông minh              [~1h]
├── T-N05  Checklist theo dịch vụ               [~30m]
└── T-N06  Chọn phương thức thanh toán          [~45m]

KHI CÓ BACKEND
└── T-B01 → T-B06  Tích hợp API thật (~2–3 tuần)
```

---

## 📁 Cấu trúc file hiện tại

```
lib/
├── core/
│   ├── api/           dio_client.dart (stub)
│   ├── auth/          auth_notifier.dart [kDebugBypassAuth=true], auth_state.dart
│   ├── mock/          mock_data.dart
│   ├── router/        app_router.dart, shell_scaffold.dart
│   └── theme/         app_theme.dart
└── features/
    ├── auth/          phone_input_screen, otp_verify_screen
    ├── beneficiary/   create / edit / detail / list
    ├── booking/       wizard / list / detail
    ├── caregiver/     list / profile
    ├── catalog/       catalog_screen
    ├── home/          home_screen  ← [THIẾU notifications_screen]
    ├── review/        review_screen, dispute_screen
    ├── settings/      settings / profile_edit / payment / addresses
    │                  change_password / 2fa / faq / support
    └── shift_tracking/ shift_tracking_screen, care_timeline_screen
```

---

> **Ghi chú**: `kDebugBypassAuth = true` trong `auth_notifier.dart` — giữ nguyên cho đến khi có backend.
> File này là living plan — cập nhật sau mỗi phiên làm việc.
