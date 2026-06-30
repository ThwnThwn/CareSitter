# 🏥 CareSitter — Customer App

> **Flutter mobile app** dành cho khách hàng (người cần chăm sóc / gia đình) của nền tảng CareSitter.  
> Kết nối với backend **.NET 8 Modular Monolith** qua REST API + SignalR.

---

## 📋 Mục lục

1. [Tổng quan dự án](#1-tổng-quan-dự-án)
2. [Yêu cầu môi trường](#2-yêu-cầu-môi-trường)
3. [Cài đặt & Chạy dự án](#3-cài-đặt--chạy-dự-án)
4. [Xem giao diện (Preview UI)](#4-xem-giao-diện-preview-ui)
5. [Kiến trúc dự án](#5-kiến-trúc-dự-án)
6. [Cấu trúc thư mục](#6-cấu-trúc-thư-mục)
7. [Design System & Màu sắc](#7-design-system--màu-sắc)
8. [State Management (Riverpod)](#8-state-management-riverpod)
9. [Routing & Navigation](#9-routing--navigation)
10. [API & Authentication](#10-api--authentication)
11. [Các màn hình chính](#11-các-màn-hình-chính)
12. [Luồng người dùng](#12-luồng-người-dùng)
13. [Cấu hình Test Mode](#13-cấu-hình-test-mode)
14. [Kết nối Backend thật](#14-kết-nối-backend-thật)

---

## 1. Tổng quan dự án

CareSitter Customer App là ứng dụng mobile cho phép khách hàng:

- 📱 Đăng ký / đăng nhập bằng số điện thoại (OTP)
- 👤 Quản lý hồ sơ người được chăm sóc (Beneficiary)
- 📅 Đặt lịch dịch vụ chăm sóc (Booking)
- 👩‍⚕️ Chọn & xem hồ sơ Caregiver
- 📍 Theo dõi ca chăm sóc theo thời gian thực
- ⭐ Đánh giá sau mỗi ca
- 💬 Chat với Caregiver / CSKH

### Stack công nghệ

| Layer | Công nghệ |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| State Management | Riverpod 2.x |
| Navigation | Go Router |
| HTTP Client | Dio 5.x |
| Local Storage | Flutter Secure Storage |
| Realtime | SignalR (signalr_netcore) |
| Maps | Flutter Map + Geolocator |
| UI | Material 3 + Custom Design System |

---

## 2. Yêu cầu môi trường

### Bắt buộc
```
Flutter SDK >= 3.10.0
Dart SDK >= 3.0.0
```

### Kiểm tra cài đặt
```bash
flutter doctor
```

Kết quả mong muốn — tất cả dấu ✅:
```
[✓] Flutter
[✓] Android toolchain
[✓] Chrome (for web)
[✓] Connected device
```

### Để chạy trên Android Emulator (tùy chọn)
- Cài **Android Studio** → mở **Virtual Device Manager** → tạo **Pixel 7** với API 34
- Hoặc cắm **điện thoại Android thật** qua USB (bật USB Debugging)

---

## 3. Cài đặt & Chạy dự án

### Bước 1: Clone / mở project
```bash
cd d:\EXE\caresitter-customer
```

### Bước 2: Cài dependencies
```bash
flutter pub get
```

### Bước 3: Chạy app

**Trên Chrome (Web):**
```bash
flutter run -d chrome
```

**Trên Android Emulator (sau khi tạo emulator):**
```bash
flutter run -d emulator-5554
```

**Trên điện thoại thật (cắm USB):**
```bash
flutter run
# Flutter tự nhận thiết bị
```

**Xem danh sách thiết bị khả dụng:**
```bash
flutter devices
```

---

## 4. Xem giao diện (Preview UI)

### 🌐 Cách nhanh nhất — Chrome DevTools (không cần cài gì)

Sau khi chạy `flutter run -d chrome`, trình duyệt Chrome sẽ tự mở. Để xem giao diện mobile:

```
1. Nhấn F12          → Mở DevTools
2. Ctrl + Shift + M  → Bật chế độ giả lập thiết bị
3. Chọn thiết bị     → "Pixel 7" hoặc "iPhone 14 Pro"
4. Ctrl + Shift + R  → Reload để render lại đúng tỉ lệ
```

> 💡 Không cần cài extension hay phần mềm nào thêm!

### 🔄 Hot Reload & Hot Restart

Khi app đang chạy, trong terminal Flutter:

| Phím | Tác dụng | Khi nào dùng |
|------|----------|--------------|
| `r` | Hot reload | Thay đổi UI nhỏ (widget, style) |
| `R` | Hot restart | Thay đổi state, logic, route |
| `q` | Thoát app | Khi muốn dừng |

---

## 5. Kiến trúc dự án

```
┌─────────────────────────────────────────┐
│              Flutter App                │
│                                         │
│  ┌──────────┐  ┌──────────────────────┐ │
│  │   UI     │  │   State (Riverpod)   │ │
│  │ Screens  │◄─┤   Providers          │ │
│  │ Widgets  │  │   Notifiers          │ │
│  └────┬─────┘  └──────────┬───────────┘ │
│       │                   │             │
│  ┌────▼───────────────────▼───────────┐ │
│  │         Repository Layer           │ │
│  │  (Business Logic + Data Access)    │ │
│  └────────────────┬───────────────────┘ │
│                   │                     │
│  ┌────────────────▼───────────────────┐ │
│  │          Dio HTTP Client           │ │
│  │  (JWT Interceptor + Auto Refresh)  │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
                    │
                    ▼
         Backend .NET 8 API
         (REST + SignalR)
```

### Luồng dữ liệu

```
User Action → Widget → Provider → Repository → API
                                              ↓
UI tự rebuild ←── State update ←── Response ◄─┘
```

---

## 6. Cấu trúc thư mục

```
lib/
├── main.dart                    # Entry point
├── app.dart                     # Root widget + Theme
│
├── core/                        # Dùng chung toàn app
│   ├── theme/
│   │   └── app_theme.dart       # Màu sắc, typography, component styles
│   ├── router/
│   │   ├── app_router.dart      # Toàn bộ routes + auth guard
│   │   └── shell_scaffold.dart  # Bottom navigation bar wrapper
│   ├── api/
│   │   └── dio_client.dart      # HTTP client + JWT interceptor
│   ├── auth/
│   │   ├── auth_state.dart      # Model trạng thái đăng nhập
│   │   └── auth_notifier.dart   # Logic xử lý auth + kDebugBypassAuth
│   └── widgets/
│       └── app_widgets.dart     # AppButton, GlassCard, GradientHeader...
│
└── features/                    # Mỗi tính năng trong 1 folder riêng
    ├── auth/
    │   ├── data/
    │   │   └── auth_repository.dart
    │   └── presentation/
    │       └── screens/
    │           ├── phone_input_screen.dart   # Nhập SĐT
    │           └── otp_verify_screen.dart    # Nhập OTP
    │
    ├── home/
    │   └── presentation/
    │       └── home_screen.dart             # Dashboard chính
    │
    ├── beneficiary/
    │   └── presentation/
    │       └── screens/
    │           ├── beneficiary_list_screen.dart
    │           ├── beneficiary_create_screen.dart
    │           └── beneficiary_detail_screen.dart
    │
    ├── booking/
    │   └── presentation/
    │       └── screens/
    │           ├── booking_wizard_screen.dart   # Luồng đặt lịch (4 bước)
    │           ├── booking_list_screen.dart
    │           └── booking_detail_screen.dart
    │
    ├── caregiver/
    │   └── presentation/
    │       ├── caregiver_list_screen.dart
    │       └── caregiver_profile_screen.dart
    │
    ├── shift_tracking/
    │   └── presentation/
    │       ├── shift_tracking_screen.dart    # Theo dõi ca theo thời gian thực
    │       └── care_timeline_screen.dart     # Timeline hoạt động chăm sóc
    │
    ├── review/
    │   └── presentation/
    │       ├── review_screen.dart            # Đánh giá sau ca
    │       └── dispute_screen.dart           # Khiếu nại
    │
    ├── catalog/
    │   └── presentation/
    │       └── catalog_screen.dart           # Danh mục dịch vụ
    │
    └── settings/
        └── presentation/
            └── settings_screen.dart
```

---

## 7. Design System & Màu sắc

### Bảng màu chính (Teal Palette)

| Token | Hex | Dùng cho |
|-------|-----|----------|
| `primary` | `#2F7F7F` | Nút chính, accent, icon active |
| `secondary` | `#3A8D8C` | Gradient, secondary actions |
| `primaryLight` | `#E8F5F5` | Background chip, badge |
| `primaryContainer` | `#C8E6E6` | Input focus ring |
| `background` | `#F7FAFA` | Nền toàn app |
| `cardBackground` | `#FFFFFF` | Card, bottom sheet |
| `textPrimary` | `#1A2E2E` | Tiêu đề, text chính |
| `textSecondary` | `#4A6B6B` | Mô tả, placeholder |
| `textHint` | `#8FA8A8` | Hint text |
| `success` | `#27AE60` | Trạng thái thành công |
| `warning` | `#F39C12` | Cảnh báo |
| `error` | `#E74C3C` | Lỗi |

### Gradient hero
```dart
AppColors.heroGradient = LinearGradient(
  colors: [Color(0xFF2F7F7F), Color(0xFF1A5C5C)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

### Typography
Font: **Google Fonts — Inter** (được load qua `google_fonts` package)

| Style | Size | Weight |
|-------|------|--------|
| Heading 1 | 28px | Bold 700 |
| Heading 2 | 22px | SemiBold 600 |
| Body | 14px | Regular 400 |
| Caption | 12px | Regular 400 |

---

## 8. State Management (Riverpod)

Dự án dùng **Riverpod 2.x** — không cần `BuildContext` để đọc state.

### Các Provider chính

```dart
// Trạng thái đăng nhập
final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(...);

// Ví dụ đọc trong Widget:
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return authState.when(
      loading: () => CircularProgressIndicator(),
      error: (e, _) => Text('Lỗi: $e'),
      data: (state) => state.isAuthenticated
        ? HomeScreen()
        : LoginScreen(),
    );
  }
}
```

### Quy tắc

- `ref.watch()` → theo dõi & rebuild UI khi state thay đổi
- `ref.read()` → đọc 1 lần, không rebuild (dùng trong `onPressed`)
- `AsyncNotifier` → cho các tác vụ bất đồng bộ (API call)

---

## 9. Routing & Navigation

Dùng **Go Router** với Auth Guard tự động.

### Danh sách Routes

| Route | Màn hình | Yêu cầu auth |
|-------|----------|--------------|
| `/login` | PhoneInputScreen | ❌ |
| `/otp` | OtpVerifyScreen | ❌ |
| `/home` | HomeScreen | ✅ |
| `/beneficiary` | BeneficiaryListScreen | ✅ |
| `/beneficiary/create` | BeneficiaryCreateScreen | ✅ |
| `/beneficiary/:id` | BeneficiaryDetailScreen | ✅ |
| `/catalog` | CatalogScreen | ✅ |
| `/booking/new` | BookingWizardScreen | ✅ |
| `/booking` | BookingListScreen | ✅ |
| `/booking/:id` | BookingDetailScreen | ✅ |
| `/caregiver` | CaregiverListScreen | ✅ |
| `/caregiver/:id` | CaregiverProfileScreen | ✅ |
| `/shift/:id` | ShiftTrackingScreen | ✅ |
| `/shift/:id/timeline` | CareTimelineScreen | ✅ |
| `/review/:bookingId` | ReviewScreen | ✅ |
| `/settings` | SettingsScreen | ✅ |

### Navigate

```dart
// Navigate đến màn hình
context.go('/booking');

// Navigate với params
context.go('/booking/$bookingId');

// Push (giữ lại màn hình trước)
context.push('/review/$bookingId');

// Quay lại
context.pop();
```

---

## 10. API & Authentication

### Luồng xác thực

```
1. Nhập SĐT → POST /api/auth/request-otp
2. Nhập OTP → POST /api/auth/verify-otp
              ← { accessToken, refreshToken, userId }
3. Lưu token vào FlutterSecureStorage (mã hóa)
4. Mọi API call sau: tự gắn Authorization: Bearer <token>
5. Token hết hạn (401) → tự gọi POST /api/auth/refresh → retry
```

### Cấu hình API Base URL

Mở file `lib/core/api/dio_client.dart`:

```dart
// 🔧 Thay đổi URL này khi deploy
const String baseUrl = 'https://api.caresitter.vn';
// Hoặc local development:
// const String baseUrl = 'http://10.0.2.2:5000'; // Android Emulator → localhost
// const String baseUrl = 'http://localhost:5000'; // Web
```

> ⚠️ Trên Android Emulator, dùng `10.0.2.2` thay vì `localhost` để kết nối với backend chạy trên máy host.

---

## 11. Các màn hình chính

### 📱 Màn hình đăng nhập (`PhoneInputScreen`)
- Nhập số điện thoại Việt Nam (+84)
- Validate format SĐT
- Gọi API request OTP

### 🏠 Home Dashboard (`HomeScreen`)
- Hiển thị lịch hẹn sắp tới
- Shortcut đặt lịch mới
- Thông báo mới nhất

### 👤 Hồ sơ người cần chăm sóc (`BeneficiaryScreen`)
- Danh sách người được chăm sóc trong gia đình
- Tạo/chỉnh sửa hồ sơ (thông tin sức khỏe, dị ứng, ghi chú)

### 📅 Đặt lịch (`BookingWizardScreen`)
Luồng 4 bước:
```
Bước 1: Chọn người được chăm sóc
Bước 2: Chọn dịch vụ + thời gian
Bước 3: Chọn Caregiver (hoặc để hệ thống chọn)
Bước 4: Xác nhận & thanh toán
```

### 📍 Theo dõi ca (`ShiftTrackingScreen`)
- Xem GPS Caregiver theo thời gian thực (SignalR)
- Xem timeline hoạt động chăm sóc
- Liên hệ trực tiếp với Caregiver

### ⭐ Đánh giá (`ReviewScreen`)
- Đánh giá sau khi ca kết thúc (1-5 sao)
- Nhận xét chi tiết
- Tip tùy chọn

---

## 12. Luồng người dùng

```
Mở app
  │
  ├─ Chưa đăng nhập ──→ [Phone Input] → [OTP Verify] → [Home]
  │
  └─ Đã đăng nhập ────→ [Home Dashboard]
                              │
              ┌───────────────┼────────────────┐
              │               │                │
         [Đặt lịch]    [Hồ sơ người        [Lịch sử]
              │          chăm sóc]              │
         [Chọn dịch vụ]                   [Chi tiết booking]
              │                                 │
         [Chọn Caregiver]              [Theo dõi ca trực tiếp]
              │                                 │
         [Xác nhận]                    [Timeline + GPS]
              │                                 │
         [Booking tạo]                    [Ca kết thúc]
                                               │
                                         [Đánh giá]
```

---

## 13. Cấu hình Test Mode

Khi **chưa có backend**, bật chế độ bypass để test UI tự do:

Mở file `lib/core/auth/auth_notifier.dart`:

```dart
// ─────────────────────────────────────────────────────────────
// 🔧 UI TEST MODE
const kDebugBypassAuth = true;   // ← true = bỏ qua đăng nhập
//                                    false = cần đăng nhập thật
// ─────────────────────────────────────────────────────────────
```

Khi `kDebugBypassAuth = true`:
- App **bỏ qua màn hình đăng nhập**
- Dùng user giả `mock_user_001` / SĐT `0901234567`
- Truy cập được **toàn bộ màn hình** để test UI

> ⚠️ **Nhớ đặt lại `false`** trước khi build production!

---

## 14. Kết nối Backend thật

### Checklist trước khi kết nối

- [ ] Đặt `kDebugBypassAuth = false`
- [ ] Cập nhật `baseUrl` trong `dio_client.dart`
- [ ] Backend đang chạy và có thể truy cập
- [ ] Đã test API `/health` trả về 200

### Test API connection
```bash
# Kiểm tra backend chạy chưa (thay đổi URL cho phù hợp)
curl http://localhost:5000/health
```

### Build production (Android APK)
```bash
flutter build apk --release
# File xuất ra: build/app/outputs/flutter-apk/app-release.apk
```

### Build production (Web)
```bash
flutter build web --release
# File xuất ra: build/web/
```

---

## ❓ FAQ

**Q: Tại sao app mở lên không có màn hình đăng nhập?**  
A: Đang bật `kDebugBypassAuth = true` để test UI. Đổi thành `false` là có lại.

**Q: Hot reload không thấy thay đổi?**  
A: Thử `R` (Hot restart) thay vì `r` (Hot reload). Restart reset toàn bộ state.

**Q: Trên Android Emulator không gọi được API localhost?**  
A: Dùng `10.0.2.2` thay vì `localhost` trong `baseUrl`.

**Q: Muốn thêm màn hình mới?**  
A: Tạo file trong `lib/features/<tên_feature>/presentation/screens/`, thêm route trong `app_router.dart`.

---

*Cập nhật lần cuối: 25/06/2026 — CareSitter Dev Team*
