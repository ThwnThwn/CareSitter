# Kết quả hoàn thiện kiến trúc Customer

> Đây là kết quả của đợt trước. Đợt tiếp theo tách controller/model và trạng thái Git hiện tại được ghi tại [báo cáo tách logic](FRONTEND_LOGIC_SEPARATION_2026-10-12.md).

Cập nhật: 12/10/2026, Asia/Saigon. Phạm vi: `frontend/customer-app`. Thực hiện theo yêu cầu hoàn thiện Customer trước rồi mới tiếp tục Caregiver. Source và tài liệu đang local; chưa stage/commit/push.

## Kết quả đợt này

Đã xử lý phần UI lớn còn lại của Customer, chuyển các luồng nghiệp vụ chính sang controller và mở rộng kiểm tra kiến trúc cho toàn app. Analyze sạch; toàn bộ **209 test pass, 0 fail, 0 skip** ở lần chạy cuối; build APK Android debug thành công. Không sửa Caregiver trong đợt này.

Đọc [rule.frontend](../frontend/RULE_FRONTEND.md) và [quy ước chung](../QUY_UOC_CODE_VA_SECRET.md) trong từng tác vụ trước khi sửa tiếp. Rule bắt buộc vẫn được nối từ `AGENTS.md` gốc và `frontend/AGENTS.md`.

## Các nhóm đã sửa

| Nhóm | Thay đổi |
| --- | --- |
| Home, danh mục, tìm/chọn người chăm sóc, hoạt động | Chia header, banner, danh sách, thẻ và trạng thái thành component riêng. Giữ route/query tìm kiếm, cách chọn booking thật gần nhất và định dạng hiển thị. |
| Đặt lịch và thanh toán | Tách danh sách/chi tiết, tiến trình, thông tin lịch, tài chính và action theo trạng thái. `PaymentResultController` sở hữu polling và kết quả được backend xác nhận; `PaymentCheckoutController` sở hữu chọn provider, khóa submit và kiểm tra URL qua domain. UI mở trình duyệt và điều hướng. |
| Tạo/sửa người thụ hưởng | Dùng `BeneficiaryFormController` chung cho ID địa chỉ, giới tính, quan hệ, mức chăm sóc, tag, avatar và trạng thái lưu. Entity địa chỉ được lấy từ store theo ID. Tách trường nhập và liên hệ khẩn cấp; giữ draft khi lưu lỗi; phát hiện số điện thoại trùng sau chuẩn hóa. |
| Theo dõi ca | `ShiftTrackingController` quản lý GPS snapshot/push, watermark, polling, lỗi, foreground/visibility và subscription. Hủy timer khi không còn theo dõi; bỏ response cũ; chỉ rời membership do flow sở hữu, không dừng SignalR dùng chung. Tách bản đồ, caregiver card, task, tiến độ và action. |
| Tài khoản | Tách `RegistrationController`, `OtpController`, `PasswordRecoveryController`, `RecoveryEmailController`. Quản lý khóa gửi, cooldown, thời hạn challenge/grant và kết quả muộn. Reset token không còn giữ trong widget; UI giữ TextEditingController và xử lý thông báo/điều hướng. |
| Hồ sơ cá nhân | `ProfileEditController` điều phối đọc ảnh, upload rồi lưu profile; kiểm tra lifecycle trước bước ghi tiếp theo. Giữ ảnh khi upload lỗi. `ProfileStore` kiểm tra user/session và dùng số thứ tự operation để response upload cũ không gỡ khóa upload của phiên mới. |
| Widget dùng chung và tên file | Tách bộ widget/animation, shell navigation và các widget trong màn hình lớn. Component mới có tên theo vai trò; loại lớp bọc không được sử dụng; formatter và theme tiếp tục nằm trong `core`. |

## Kiểm chứng

Lệnh chạy tại `frontend/customer-app`:

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build apk --debug --no-pub
```

| Kiểm tra | Kết quả |
| --- | --- |
| Analyze | Không có issue |
| Toàn bộ test | 209 pass, 0 fail, 0 skip |
| File UI >300 dòng | 0; trước đợt này còn 27 file |
| Method `build`/`_build*` >80 dòng trong class UI | 0 |
| Ranh giới core/data/model/domain/controller/UI | Kiểm tra kiến trúc pass |
| `git diff --check -- frontend/customer-app` | Không có lỗi whitespace |
| APK Android debug | Thành công; `build/app/outputs/flutter-apk/app-debug.apk` |

Test kiến trúc tại [frontend_boundaries_test.dart](../../frontend/customer-app/test/architecture/frontend_boundaries_test.dart) áp dụng giới hạn file và build cho toàn bộ Customer bằng AST, thay cho giới hạn chỉ ở wizard/Nutrition. Kiểm tra thêm model không phụ thuộc framework và controller không gọi thao tác UI.

Test hồi quy mới bao phủ gửi đồng thời, cooldown và mã/grant hết hạn, đổi thông tin khi request còn chạy, response đến sau dispose, provider thanh toán bị tắt, URL thanh toán không hợp lệ, giữ draft/ảnh khi lỗi và upload của hai phiên khác nhau. Các test cũ vẫn kiểm tra Home ở 320 px/chữ lớn, người thụ hưởng, booking, Nutrition, bản đồ và reconnect GPS.

Bằng chứng local nằm trong [`backend/artifacts/frontend-architecture-20261012/`](../../backend/artifacts/frontend-architecture-20261012/):

- `customer-final-analyze.log`
- `customer-final-tests.log`
- `customer-debug-apk-build.log`
- `customer-inventory-final.jsonl`
- `customer-long-builds.jsonl`
- `widget-name-map.json`
- `customer-final-static.json`

Script đo toàn `lib` có thể ghi `_buildLightTheme` ở theme; đây là method tạo `ThemeData`, không phải build của widget. Test AST giới hạn class UI mới là tiêu chí nghiệm thu kích thước UI.

## Giới hạn và phần tiếp theo

1. Kết quả này hoàn thiện đợt refactor kiến trúc Customer ở source local. Không phải chứng nhận mọi chức năng đã được nghiệm thu production hoặc toàn bộ hợp đồng backend đã hoàn tất.
2. **Backend `POST /bookings` vẫn cần idempotency lưu bền.** Frontend giữ key và đối soát kết quả chưa rõ; header phía client không thay thế bảo vệ trên server. Đợt này không sửa backend.
3. Cần duyệt giao diện và chạy hành trình thật trên thiết bị Android với API/provider thật trước phát hành. Test widget và build không thay thế kiểm tra này. Không có kiểm chứng iOS/production trong đợt này.
4. Nutrition giữ typed boundary và cache/lifecycle đã có từ đợt trước; một số payload kết quả chi tiết vẫn được giữ dạng map để bảo toàn field chưa biết.
5. Source chưa commit/push nên CI remote chưa xác nhận bản refactor hiện tại. Markdown/rule tiếp tục chỉ lưu local theo yêu cầu.
6. Caregiver giữ nguyên trong đợt này. Báo cáo trước có 12 file UI Caregiver >300 dòng; phải đo lại source khi bắt đầu phần Caregiver, không dùng số liệu cũ làm nghiệm thu.

## Điểm bắt đầu khi sửa tiếp

- [Controller form người thụ hưởng](../../frontend/customer-app/lib/features/beneficiary/presentation/controllers/beneficiary_form_controller.dart)
- [Controller checkout thanh toán](../../frontend/customer-app/lib/features/booking/presentation/controllers/payment_checkout_controller.dart)
- [Controller đối soát thanh toán](../../frontend/customer-app/lib/features/booking/presentation/controllers/payment_result_controller.dart)
- [Controller theo dõi ca](../../frontend/customer-app/lib/features/shift_tracking/presentation/controllers/shift_tracking_controller.dart)
- [Controller lưu hồ sơ cá nhân](../../frontend/customer-app/lib/features/settings/presentation/controllers/profile_edit_controller.dart)
- [Controller khôi phục mật khẩu](../../frontend/customer-app/lib/features/auth/presentation/controllers/password_recovery_controller.dart)
- [Kiểm tra kiến trúc Customer](../../frontend/customer-app/test/architecture/frontend_boundaries_test.dart)

[Báo cáo refactor hai app trước đó](FRONTEND_REFACTOR_2026-10-12.md) là mốc trước đợt Customer này; số 27 file UI Customer còn lại đã được xử lý trong đợt hiện tại.
