# Phase 7 acceptance — Baseline có thể lặp lại

- Thời gian: 26/09/2026, 20:26–20:30 (UTC+7).
- Baseline commit: `9a2da180f29212d0419b1c0087e057c31e919038`.
- Runner: `backend/scripts/test-phase7.ps1` với cấu hình mặc định `Repeat=2`.
- Kết quả kỹ thuật: **đạt hai vòng liên tiếp**.
- Trạng thái quản trị: baseline đã được đưa vào `main` ngày 28/09/2026; Phase 7 chuyển sang “Hoàn thành”.

## Phạm vi được xác minh

| Gate | Vòng 1 | Vòng 2 |
| --- | --- | --- |
| PostgreSQL và Redis Docker Compose healthy | Đạt | Đạt |
| Database tạm sạch chạy toàn bộ migration `00–28` | Đạt | Đạt |
| Nâng cấp bản legacy `00–25` lên `26–28` | Đạt | Đạt |
| Dữ liệu seed trước/sau nâng cấp không thay đổi số lượng | Đạt | Đạt |
| Liveness, readiness, catalog và anonymous auth boundary | Đạt | Đạt |
| Login seed account ADMIN/CUSTOMER/CAREGIVER | Đạt | Đạt |
| Backend build Release | 0 warning, 0 error | 0 warning, 0 error |
| Backend automated tests | 161/161, 0 skip | 161/161, 0 skip |
| Customer app | Analyze sạch, 26/26 test | Analyze sạch, 26/26 test |
| Caregiver app | Analyze sạch, 15/15 test | Analyze sạch, 15/15 test |
| Admin web | Production build đạt | Production build đạt |

## Dữ liệu kiểm tra

Hai database sạch và hai lần nâng cấp legacy đều cho cùng chữ ký dữ liệu seed:

```text
users=6, services=6, addresses=1, beneficiaries=1,
caregivers=4, wallets=5, bookings=0, disputes=0
```

Runner sử dụng container PostgreSQL tạm và tự dọn sau khi chạy, không xóa hoặc thay đổi database local hiện có. Raw log và TRX nằm trong thư mục ignored `backend/artifacts/phase7/20260926-202617`; file tổng hợp là `summary.json`.

## Lỗi phát hiện và sửa trong acceptance

Clean install ban đầu thiếu hai cột mà Identity EF model đang đọc: `identity.users.avatar_url` và `identity.users.notification_prefs`. Lỗi làm đăng nhập mật khẩu trả HTTP 500 dù health check và catalog vẫn xanh.

Migration forward-only `28-identity-avatar-url.sql` đã bổ sung hai cột nullable, không xóa hoặc backfill dữ liệu cũ. Sau sửa, login ba role và toàn bộ acceptance đều đạt hai lần liên tiếp.

## Quy trình tái kiểm tra

```powershell
powershell -ExecutionPolicy Bypass -File backend/scripts/test-phase7.ps1
```

Để dựng lại database local từ đầu và chuẩn hóa mật khẩu seed, dùng lệnh có xác nhận phá hủy rõ ràng:

```powershell
powershell -ExecutionPolicy Bypass -File backend/scripts/reset-local.ps1 -Force
```

Lệnh reset chỉ nhắm các service và named volume thuộc `backend/docker-compose.yml`.
