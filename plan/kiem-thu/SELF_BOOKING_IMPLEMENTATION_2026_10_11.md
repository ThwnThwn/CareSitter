# Triển khai đặt lịch cho bản thân

> Ngày: 11/10/2026 (Asia/Saigon). Trạng thái: **đã có code, đã kiểm thử local; chưa chạy migration trên DB ứng dụng/chưa phát hành**. Phạm vi: People API, migration 37, customer app. Tài liệu chỉ lưu local.

## Kết quả

- `37-beneficiary-self-profile.sql` thêm cờ `is_self` mặc định `false` và unique index cho một hồ sơ self đang hoạt động trên mỗi customer. Bản ghi cũ không được suy đoán hay tự gắn self.
- People API thêm `GET/POST /api/v1/beneficiaries/self` và `PUT /api/v1/beneficiaries/self/link`. Owner lấy từ phiên; POST lặp trả hồ sơ đã lưu, không ghi đè draft. Transaction và advisory lock theo customer, unique index bảo vệ race. Link giữ beneficiary ID, health JSONB và booking lịch sử. GET không tạo dữ liệu.
- PUT thông thường giữ dữ liệu sức khỏe không sửa; self không được đổi quan hệ. DELETE self trả `409 beneficiary.self_managed`.
- Customer wizard có hai lựa chọn “Tôi / Người thân”. Lần đầu đọc mới `/profile`, thu thập dữ liệu chăm sóc và hai liên hệ khẩn cấp ngay trong wizard. Chỉ lưu self khi xác nhận cuối, dùng beneficiary ID thật để tạo booking. Hồ sơ self đã lưu được dùng lại; có lựa chọn liên kết hồ sơ cũ rõ ràng. Danh sách hồ sơ hiển thị “Thông tin chăm sóc của tôi” một lần.
- Trước khi đặt lịch bằng hồ sơ self đã lưu, app đọc lại hồ sơ đúng ID. Nếu dữ liệu chăm sóc hoặc sức khỏe đã đổi trên thiết bị khác, yêu cầu xem lại nội dung mới.
- Điều hướng thêm người thân trả đúng ID vừa tạo. Deep link chờ tải đúng hồ sơ; ID không có không fallback sang hồ sơ khác. Lỗi trả theo mã. Timeout POST booking giữ trạng thái chưa xác định và cho kiểm tra danh sách; không tự gửi lại. Booking đã tạo nhưng chọn caregiver lỗi giữ booking ID và mở chi tiết lịch.

## Kiểm chứng local

| Kiểm tra | Kết quả |
| --- | --- |
| `dotnet test backend/CareSitter.sln --nologo --verbosity quiet` | 562 passed, 0 failed, 0 skipped; bao gồm 265 integration tests trên PostgreSQL test tạm. |
| `SelfBeneficiaryTests` trên PostgreSQL 16 + PostGIS tạm | 9 passed: migration DB mới/nâng cấp, RLS/owner, POST đồng thời, POST vs link, hai link, dữ liệu sức khỏe, xóa/đổi quan hệ, race link vs delete. |
| `dotnet test backend/tests/CareSitter.Modules.People.UnitTests --nologo --verbosity quiet` | 14 passed, 0 failed, 0 skipped sau chỉnh sửa cuối. |
| `dotnet test backend/tests/CareSitter.ArchitectureTests --nologo --verbosity quiet` | 30 passed, 0 failed, 0 skipped. |
| `flutter test --no-pub` | 148 passed, 0 failed; gồm regression customer app. |
| `flutter test --no-pub test/features/booking/self_booking_test.dart` | 21 passed; gồm đi hết wizard, timeout, thay đổi dị ứng từ thiết bị khác, 320/390 px, text scale 1.3/2.0 và deep link. |
| `flutter analyze --no-pub` | Không có issue. |
| `flutter build web --no-pub` | Build thành công. |

Log kiểm thử nằm trong `plan/kiem-thu/self-backend-all.log`, `self-flutter-all-final.log` và `self-web-build.log` tại máy local. Lượt full backend đã chạy trước chỉnh sửa regex số điện thoại ở client; People unit và architecture test đã chạy lại sau đó. Không tính lượt chạy lại integration bị lỗi kết nối khi Docker Desktop đã dừng là test code thất bại.

## Giới hạn và phát hành

Chưa áp dụng migration 37 lên DB ứng dụng hoặc production; Docker test tạm chỉ dùng DB ngẫu nhiên và đã dừng. Chưa nghiệm thu trên Android/iOS thật hoặc đi qua backend chạy thật với app. Cần chạy migration theo [quy trình nâng cấp DB](../backend/docs/MIGRATIONS.md), xác nhận cột/index, rồi phát hành backend trước app. Schema mới có thể giữ khi rollback UI. Chưa có idempotency bền cho `POST /bookings`, nên app không tự retry khi response chưa rõ. Nutrition và màn hình thực đơn là plan riêng, chưa triển khai.
