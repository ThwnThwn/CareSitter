# Kết quả refactor Frontend Flutter + Riverpod

> Mốc trước các đợt hoàn thiện Customer và Caregiver. Xem [kết quả Customer](CUSTOMER_ARCHITECTURE_REFACTOR_2026-10-12.md) và [kết quả Caregiver](CAREGIVER_ARCHITECTURE_REFACTOR_2026-10-12.md); số file UI còn lại bên dưới là số liệu lịch sử.

Cập nhật: 12/10/2026, Asia/Saigon. Phạm vi: `frontend/customer-app` và `frontend/caregiver-app`. Source và tài liệu của đợt này đang local, chưa commit/push. Giữ nguyên các thay đổi local đã có từ trước.

## Trạng thái

Đã triển khai đủ năm nhóm ưu tiên người dùng yêu cầu. Hai app analyze sạch và toàn bộ test pass. Đây là kết quả cho working tree hiện tại; chưa phải xác nhận toàn bộ app tuân thủ mọi quy tắc, chưa được kiểm chứng bằng CI trên remote cho phần refactor này.

Đọc [rule.frontend](../frontend/RULE_FRONTEND.md) trước khi sửa Flutter. [AGENTS gốc](../../AGENTS.md) và [AGENTS frontend](../../frontend/AGENTS.md) đã gắn yêu cầu đọc toàn bộ rule và quy ước chung trong từng tác vụ.

[Báo cáo rà soát trước refactor](FRONTEND_ARCHITECTURE_AUDIT_2026-10-12.md) là số liệu lịch sử; kết quả hiện tại nằm trong tài liệu này.

## Năm nhóm đã triển khai

| Ưu tiên | Thay đổi | Kết quả |
| --- | --- | --- |
| 1. Ranh giới repository/controller | Repository xử lý I/O và DTO; auth session controller quản lý đăng nhập/đăng xuất/profile. Chuẩn hóa lỗi qua `AppApiException`; cancellation không lộ Dio ra presentation. Đưa router/app/push orchestration vào `app/`, widget dùng chung vào `core/`. | Không phát hiện core → feature, data → presentation, presentation → Dio, UI gọi repository trực tiếp hoặc import UI giữa các feature trong lượt rà tĩnh. |
| 2. Booking wizard | Tách screen thành các bước/widget; controller sở hữu state, submit và đối soát. Tách quy tắc lịch, thời lượng, bước và chọn caregiver vào domain. Giữ state theo ID/input, lấy entity qua provider. | Screen còn 93 dòng. Giữ thời lượng 2–12 giờ, xác nhận trước khi tạo hồ sơ tự đặt, chặn gửi đồng thời và giữ booking đã tạo khi chọn caregiver lỗi. |
| 3. Nutrition | Chuẩn hóa data/domain/presentation; DTO boundary có kiểu, request state tách khỏi snapshot cache. Tách form sức khỏe/result/widgets khỏi screen; quản lý lifecycle theo user/session/beneficiary. | Screen còn 225 dòng. Giữ cancellation, polling, revision, key theo request và chặn kết quả cũ ghi vào phiên mới. |
| 4. Caregiver shift active | Controller sở hữu timer, check-in, ảnh, task, ghi chú, checkout và incident. UI nhận state/kết quả action; tách widget và domain rules. | Screen còn 89 dòng. Khóa từng action, không checkout khi task chưa giải quyết hoặc lưu ghi chú lỗi; timer không tràn ở màn hình nhỏ/chữ lớn trong widget test. |
| 5. Formatter và tokens | Gom tiền/ngày/giờ/thời lượng/số điện thoại vào `core/utils`; dùng token màu/font size/spacing/radius. | Rà source không còn literal màu và font size trong UI thuộc tiêu chí scan; formatter giữ cách hiển thị hiện có của từng nơi gọi. |

## Kiểm chứng

| Kiểm tra | Customer | Caregiver |
| --- | ---: | ---: |
| `flutter analyze --no-pub` | Không có issue | Không có issue |
| Toàn bộ `flutter test --no-pub --reporter expanded` | 186 test pass | 52 test pass |
| core → feature | 0 | 0 |
| data → presentation | 0 | 0 |
| presentation → Dio | 0 | 0 |
| UI gọi repository trực tiếp | 0 | 0 |
| Import UI giữa feature | 0 | 0 |
| Literal màu/font size ngoài theme theo scan | 0 / 0 | 0 / 0 |
| File UI cũ còn vượt 300 dòng trong toàn `lib/` | 27 | 12 |

Các screen/widget vừa tách ở booking wizard, Nutrition, shift active và widget dùng chung được kiểm tra kích thước file; không có file vượt 300 dòng trong phạm vi này. Đo AST các phương thức `build`, `_build*`, `_result` trong phạm vi đó không có phương thức vượt 80 dòng. Kiểm tra này không áp dụng cho toàn bộ UI cũ.

Test gồm các trường hợp mất response, POST trả thành công nhưng body không đọc được, khóa gửi đồng thời, đổi phiên khi request còn chạy, giữ draft tự đặt, lỗi nghiệp vụ/transport/cancellation, formatter, Nutrition và checkout ca chăm sóc. Có kiểm tra ranh giới kiến trúc trong test của cả hai app để phát hiện một số loại phụ thuộc sai ở các lần sửa sau.

`git diff --check -- frontend` không có lỗi whitespace. Chưa chạy build APK hoặc kiểm tra app trên thiết bị thật trong đợt này.

Bằng chứng local: [`backend/artifacts/frontend-architecture-20261012/`](../../backend/artifacts/frontend-architecture-20261012/), gồm `static-after.json`, `analyze-customer-app.log`, `analyze-caregiver-app.log`, `tests-customer-app.log`, `tests-caregiver-app.log` và script đo AST `measure_ui.dart`.

## Những phần vẫn còn

1. **Idempotency bền của backend cho `POST /bookings` chưa hoàn thành.** Frontend đã gửi header key theo request. Khi kết quả POST có thể không xác định, wizard khóa gửi tiếp và chỉ dùng GET để đối soát; không tự gửi lại POST. Header phía client chưa đủ để bảo đảm không tạo trùng sau restart/mất response nếu backend chưa lưu key và kết quả bền vững.
2. **39 file UI cũ còn vượt 300 dòng**: 27 customer, 12 caregiver. Ví dụ customer `home_screen.dart`, `shift_tracking_screen.dart`, `booking_detail_screen.dart`; caregiver `schedule_screen.dart`, `home_screen.dart`, `shift_detail_screen.dart`. Danh sách và số dòng từng file có trong `static-after.json`. Các phần này cần đợt tách riêng; không đánh dấu toàn app tuân thủ 100%.
3. Những màn hình cũ ngoài ba luồng chính vẫn cần kiểm tra sâu quyền sở hữu state nghiệp vụ và độ dài từng `build`. Scan import không chứng minh toàn bộ logic đã đặt đúng tầng.
4. Nutrition có DTO boundary đã chuẩn hóa; một số payload kết quả chi tiết vẫn giữ dưới dạng map để bảo toàn field chưa biết. Chưa chuyển toàn bộ schema kết quả thành model riêng cho từng loại dữ liệu.
5. Booking wizard và shift active đã chia lại thành widget Material nhỏ; bố cục có thay đổi. Cần duyệt giao diện trên thiết bị thật và đối chiếu thiết kế trước phát hành. Widget test pass chưa thay thế bước duyệt này.
6. Toàn bộ source refactor còn local. CI xanh của lần sửa backend trước đó không kiểm tra phần thay đổi local này. Tài liệu/rule tiếp tục chỉ lưu local theo yêu cầu.

## Điểm bắt đầu khi sửa tiếp

- [Booking wizard controller](../../frontend/customer-app/lib/features/booking/presentation/controllers/booking_wizard_controller.dart)
- [Nutrition controller](../../frontend/customer-app/lib/features/nutrition/presentation/controllers/nutrition_controller.dart)
- [Caregiver shift active controller](../../frontend/caregiver-app/lib/features/shifts/presentation/controllers/shift_active_controller.dart)
- [Kiểm tra kiến trúc customer](../../frontend/customer-app/test/architecture/frontend_boundaries_test.dart)
- [Kiểm tra kiến trúc caregiver](../../frontend/caregiver-app/test/architecture/frontend_boundaries_test.dart)

Trước mọi thay đổi tiếp theo, đọc đầy đủ [quy ước chung](../QUY_UOC_CODE_VA_SECRET.md) và [rule.frontend](../frontend/RULE_FRONTEND.md) trong tác vụ hiện tại.
