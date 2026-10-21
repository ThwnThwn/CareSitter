# Tách các file frontend đang gom nhiều trách nhiệm

Cập nhật: 12/10/2026, Asia/Saigon. Phạm vi: năm mục ưu tiên trong Customer và Caregiver. Tuân thủ [rule.frontend](../frontend/RULE_FRONTEND.md) và [quy ước chung](../QUY_UOC_CODE_VA_SECRET.md). Giữ API/JSON/status hiện có và các thay đổi local khác. Không build APK theo yêu cầu người dùng.

## Kết quả theo thứ tự đã thực hiện

Số dòng tính cả dòng trống; chỉ dùng để hỗ trợ đánh giá, không thay thế việc xem trách nhiệm của từng lớp.

| Mục | Trước | Sau | Trách nhiệm còn lại và phần đã tách |
| --- | ---: | ---: | --- |
| [Customer Booking controller](../../frontend/customer-app/lib/features/booking/presentation/controllers/booking_controller.dart) | 526 | 159 | Giữ provider/cache phiên và cổng công khai. Tách state cache, action, payment, review, tasks, sync cursor và subscription realtime thành các controller riêng. |
| [Caregiver Shift list controller](../../frontend/caregiver-app/lib/features/shifts/presentation/controllers/shift_list_controller.dart) | 445 | 97 | Giữ cache và cổng công khai của một phiên. Tách sync, realtime/polling, lifecycle và tasks; repository hợp nhất/mapping assigned shifts + offers và trả DTO có kiểu cho các thao tác task. |
| [Customer Booking model](../../frontend/customer-app/lib/features/booking/data/models/booking_model.dart) | 536 | 220 | Một DTO Booking chính. Tách CareTask, GPS và response phân trang; codec status ở data; luật trạng thái/số tiền ở domain; formatter/nhãn ở presentation. Giữ các export DTO tương thích. |
| [Customer Nutrition controller](../../frontend/customer-app/lib/features/nutrition/presentation/controllers/nutrition_controller.dart) | 307 | 262 | Điều phối request state/cache. Tách operation scope/cancellation, assessment poller và actions/khóa retry. Thêm DTO decision, fact, meal, ingredient, recipe option và meal plan summary; UI dùng các trường có kiểu. |
| [Customer Booking wizard controller](../../frontend/customer-app/lib/features/booking/presentation/controllers/booking_wizard_controller.dart) | 314 | 237 | Giữ các bước, input và khóa submit của flow. Submission và reconciliation thuộc hai use case; adapter Riverpod nối các provider công khai. |

Các delegate có trách nhiệm cụ thể; không dùng `part`/mixin để chia một lớp lớn thành nhiều file. Store cũ vẫn cung cấp các method công khai để các màn hình/provider liên quan tiếp tục hoạt động.

## Bất biến giữ lại và bổ sung

- Booking full refresh/delta/task trả về muộn không được ghi vào phiên đã đóng. Cache và khóa thanh toán được reset khi thay tài khoản. Full refresh mới hơn thắng response cũ; delta có version thấp không ghi đè mutation mới.
- Thao tác hủy lịch từ phiên đã đóng không gửi request hoặc báo thành công từ response muộn. UI vẫn chờ backend, chặn bấm lặp và giữ booking khi request bị từ chối.
- Caregiver giữ khóa lifecycle theo booking; không khởi động GPS từ response en-route của phiên cũ. Hủy timer/subscription do danh sách sở hữu, không dừng hub dùng chung.
- Booking có ID sau POST vẫn giữ lại nếu chọn caregiver lỗi. Kết quả POST chưa rõ giữ đúng draft để đối soát; reconciliation chỉ có cổng GET, không tự lặp POST.
- Reconciliation chỉ trả booking khi đã đọc hết phạm vi và có đúng một kết quả khớp. Nhiều kết quả hoặc chạm giới hạn 10 trang không được coi là đã xác minh.
- Nutrition giữ health revision, beneficiary/session ownership, cùng key cho retry transport và key mới cho yêu cầu phân tích lại rõ ràng. Poller dừng khi terminal/cancel; response cũ không phục hồi nội dung. DTO mới giữ trường server chưa biết qua `toJson()`.
- Hai test UI hủy lịch được bổ sung phiên đăng nhập rõ ràng trong fixture; giữ nguyên assertion về lỗi, trạng thái chờ và chống thao tác lặp.

## Kiểm chứng

Flutter 3.44.4 stable, Dart 3.12.2, Windows. Lệnh chạy trong từng app:

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

| Kiểm tra cuối | Customer | Caregiver |
| --- | --- | --- |
| Analyze | 0 issue | 0 issue |
| Full suite | 232 pass, 0 fail, 0 skip | 84 pass, 0 fail, 0 skip |
| Dart trong lib | 717 | 360 |
| File UI | 530 | 261 |
| File UI > 300 dòng | 0 | 0 |
| UI build/_build > 80 dòng | 0 | 0 |

Đã thêm 23 test Customer và 3 test Caregiver so với mốc 209/81 trước đợt này. Có test trực tiếp cho session/cache, late response, khóa thanh toán, submission/reconciliation, luật trạng thái/số tiền, task/GPS, poller và DTO giữ trường chưa biết. Full suite bao gồm các bài kiểm tra kiến trúc hiện hữu.

Dependency test Customer `analyzer` và `fake_async` được pin đúng phiên bản đang có trong lockfile (7.6.0/1.3.3). `flutter pub get --offline` chỉ đổi hai mục từ transitive sang direct dev, không đổi phiên bản package.

Log và inventory local: `backend/artifacts/frontend-logic-20261012/`. `git diff --cached --check` sạch. Scan staged dùng một số mẫu secret có độ tin cậy cao; không thay cho kiểm toán bảo mật toàn dự án.

## Phạm vi Git và giới hạn

Đợt chốt source bao gồm phần Customer refactor đã local từ đợt trước và các thay đổi lần này, cùng phần tách Shift của Caregiver. Chỉ stage source/test Flutter, analysis options và manifest/lock cần thiết. Markdown, ảnh preview, `.kombai`, thay đổi backend/admin/deploy và mẫu config Nutrition đang local không nằm trong commit.

Đã commit/push lên `develop`: [`972414c50f88e133888c67cc6008cbbd6b253ee4`](https://github.com/ThwnThwn/CareSitter/commit/972414c50f88e133888c67cc6008cbbd6b253ee4), tiêu đề `refactor(frontend): finish customer boundaries and split booking flows`. Commit có 717 file, bao gồm phần Customer refactor của đợt trước; không có Markdown/ảnh preview. Đã xác nhận `refs/heads/develop` trên remote trùng SHA bằng `git ls-remote`; index sạch sau commit. Chưa dùng remote CI làm bằng chứng pass. Không build APK trong đợt này; không nghiệm thu thiết bị thật, iOS hay môi trường thanh toán production.

Backend `POST /bookings` vẫn cần idempotency lưu bền và đối chiếu payload. Việc tách frontend không giải quyết giới hạn này.

Các file hạ tầng dài chưa thuộc năm mục ưu tiên lần này: Customer `core/theme/app_theme.dart` (540 dòng), `core/realtime/care_signalr_service.dart` (436 dòng), `app/router/app_router.dart` (432 dòng), Caregiver `app/router/app_router.dart` (356 dòng). Chưa tuyên bố toàn bộ frontend hết mọi vấn đề về phân chia trách nhiệm.
