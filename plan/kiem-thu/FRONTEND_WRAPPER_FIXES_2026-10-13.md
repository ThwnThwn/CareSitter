# Dọn wrapper và trách nhiệm widget frontend — 13/10/2026

## Kết quả và phạm vi

Đã xử lý mục 2 của [kết luận đợt rà cấu trúc](PROJECT_STRUCTURE_FIXES_2026-10-13.md): Customer Profile edit, Change password, Saved addresses, Auth và Live map; Caregiver Auth, Home header/notification, route map và danh sách ca. Thay đổi lưu local theo yêu cầu; **chưa stage, commit, push hoặc build APK**. Giữ các thay đổi có sẵn trong working tree.

Đọc rule repository, toàn bộ quy ước code/secret và rule.frontend trước khi sửa. Đây là kết quả cho các nhóm trên; vẫn còn phần frontend khác cần đọc chain dữ liệu, không coi toàn bộ dự án đã clean.

## Những phần đã sửa

| Nhóm | Trách nhiệm sau sửa | Source chính |
| --- | --- | --- |
| Customer Profile edit | Form dựng Avatar/Contact/Birthdate/Save trực tiếp; bỏ lớp Fields chuyển tiếp; header và initials do widget sở hữu; app bar/nút lưu nhận `busy` và `onSave` | [form](../../frontend/customer-app/lib/features/settings/presentation/widgets/profile_edit_form.dart), [contact](../../frontend/customer-app/lib/features/settings/presentation/widgets/profile_contact_fields.dart) |
| Customer Change password | Form gồm ba input cụ thể; từng input giữ trạng thái ẩn/hiện; validation thuần Dart; controller giữ khóa gửi, hủy request và kiểm tra phiên | [screen](../../frontend/customer-app/lib/features/settings/presentation/screens/change_password_screen.dart), [controller](../../frontend/customer-app/lib/features/settings/presentation/controllers/password_controller.dart), [rules](../../frontend/customer-app/lib/features/settings/domain/settings_input_rules.dart) |
| Customer Saved addresses | List dựng card trực tiếp; gom Surface/Details vào card; icon/header/action được dựng tại widget sở hữu; bỏ các builder và ref chuyển tiếp | [list](../../frontend/customer-app/lib/features/settings/presentation/widgets/saved_address_list.dart), [card](../../frontend/customer-app/lib/features/settings/presentation/widgets/saved_address_card.dart) |
| Customer Auth | Bỏ RecoveryEmailBody, PasswordRecoveryContent và LoginAuthFormContainer; OTP có input/notice cụ thể; login có layout responsive riêng; validation thuộc domain; một callback submit dùng cho bàn phím và nút | [login layout](../../frontend/customer-app/lib/features/auth/presentation/widgets/login_responsive_layout.dart), [OTP](../../frontend/customer-app/lib/features/auth/presentation/widgets/otp_input_row.dart), [recovery form](../../frontend/customer-app/lib/features/auth/presentation/widgets/password_recovery_form.dart), [rules](../../frontend/customer-app/lib/features/auth/domain/recovery_input_rules.dart) |
| Customer Live map | Bỏ MapLayout chuyển tiếp; viewport nhận map đã dựng; banner/pin/button là widget cụ thể; fallback tự đọc tile provider; controller camera và animation vẫn thuộc LiveCaregiverMap | [map](../../frontend/customer-app/lib/features/shift_tracking/presentation/widgets/live_caregiver_map.dart), [viewport](../../frontend/customer-app/lib/features/shift_tracking/presentation/widgets/live_map_viewport.dart) |
| Caregiver Auth | Change action tự nhận ref qua ConsumerWidget; gom InputFields/InputStep; bỏ ref và validator truyền qua nhiều lớp; luồng quên mật khẩu dùng form cụ thể, callback có tên; login dùng domain validation và callback đổi phương thức có kiểu bool | [recovery form](../../frontend/caregiver-app/lib/features/auth/presentation/widgets/password_recovery_form.dart), [email input](../../frontend/caregiver-app/lib/features/auth/presentation/widgets/recovery_email_input_fields.dart), [login form](../../frontend/caregiver-app/lib/features/auth/presentation/widgets/login_form.dart) |
| Caregiver Home | Header/bell sở hữu provider; badge chỉ chọn trạng thái có thông báo chưa đọc; bỏ các hàm dựng widget chỉ chuyển tiếp trong HomeScreen; hiển thị tiền/ngày dùng formatter chung | [home](../../frontend/caregiver-app/lib/features/home/presentation/screens/home_screen.dart), [header](../../frontend/caregiver-app/lib/features/home/presentation/widgets/home_sticky_header.dart), [bell](../../frontend/caregiver-app/lib/features/home/presentation/widgets/home_notification_button.dart) |
| Caregiver route map/list | Map và list tự nhận ref; screen dựng ShiftListContent trực tiếp; giữ lọc tab, PageStorageKey, refresh, quyền từ chối lời mời và route ca đang làm | [map](../../frontend/caregiver-app/lib/features/shifts/presentation/widgets/shift_route_map.dart), [list](../../frontend/caregiver-app/lib/features/shifts/presentation/widgets/shift_list_content.dart), [screen](../../frontend/caregiver-app/lib/features/shifts/presentation/screens/shift_list_screen.dart) |

Callback cho hành động thật vẫn được giữ; bỏ cách đặt tên `callbackActionN` trong các luồng Auth vừa dọn. Widget layout nhận `child` là composition có mục đích; không thay builder bằng một chuỗi wrapper mới.

## Phiên, request và realtime

- Đổi mật khẩu khóa gửi ngay khi bắt đầu, hủy transport khi controller bị dispose và bỏ response thuộc phiên cũ. Trong khoảng chờ một giây trước logout, screen kiểm tra lại mounted, controller và `sessionGeneration`, kể cả lần đăng nhập mới của cùng user.
- Customer Recovery email reset email/password/code khi đổi phiên; provider theo dõi cả generation để bỏ controller của lần đăng nhập trước. Bản nháp được giữ khi người dùng chuyển về bước đổi thông tin trong cùng phiên.
- OTP giữ focus tiến/lùi và tự submit đủ sáu số; input co theo chiều rộng ở màn hình 320 px. Đổi email trên screen đang dùng lại sẽ xóa mã cũ; kết quả xác minh cũ không xóa dữ liệu của email mới. Countdown vẫn thuộc controller và được dispose theo provider.
- Giữ luồng upload/save hồ sơ, xác nhận xóa địa chỉ và chọn địa chỉ đã xác minh. Không thêm repo/API call trong widget.
- Live map giữ Google/fallback, animation marker, tạm dừng/resume follow, fit hai điểm, GPS stale và khả năng thay tile provider. Không chỉnh vòng đời kết nối SignalR dùng chung hoặc các controller GPS/realtime của Caregiver.

## Chỉ dấu cấu trúc

Mốc trước là working tree sau đợt A1–A6. Đếm toàn bộ file hiện có trong lib, gồm untracked và loại file đã xóa; số liệu trong [metrics.json](../../backend/artifacts/frontend-wrapper-fixes-20261013/metrics.json).

| Chỉ dấu | Customer trước → sau | Caregiver trước → sau |
| --- | ---: | ---: |
| File Dart trong lib | 701 → 708 | 366 → 367 |
| File chứa callbackActionN | 84 → 56 | 56 → 26 |
| Trường WidgetRef chuyển tiếp | 19 → 8 | 8 → 0 |
| Trường Widget Function | 45 → 27 | 0 → 0 |

File tăng vì có các widget/form/domain rules có trách nhiệm cụ thể. Không dùng việc giảm số file để đánh giá clean. Profile edit 187 dòng; Change password 110; Saved addresses 177; Customer Login 59; Live map 272; Caregiver Home 154; Shift list screen 73.

## Kiểm chứng cuối

| Phạm vi | Kết quả | Log |
| --- | --- | --- |
| Customer analyze | Không lỗi | [analyze](../../backend/artifacts/frontend-wrapper-fixes-20261013/customer-app-analyze-final.log) |
| Customer toàn bộ test | **267 pass**, không fail/skip | [suite](../../backend/artifacts/frontend-wrapper-fixes-20261013/customer-app-tests-final.log) |
| Caregiver analyze | Không lỗi | [analyze](../../backend/artifacts/frontend-wrapper-fixes-20261013/caregiver-app-analyze-final.log) |
| Caregiver toàn bộ test | **96 pass**, không fail/skip | [suite](../../backend/artifacts/frontend-wrapper-fixes-20261013/caregiver-app-tests-final.log) |
| Guard kiến trúc hai app | 6 kiểm tra pass trong hai suite: dependency cycle/hướng tầng, import/operation và giới hạn file/build | Hai suite trên |
| Whitespace và index | `git diff --check` pass; index trống | Kiểm tra từ root repository |

Thêm **19 ca regression**: 12 Customer và 7 Caregiver. Bao gồm gửi trùng, request thất bại/retry, hủy và response trễ, đăng nhập lại cùng user trước logout, rời màn hình khi đang chờ, giữ bản nháp, OTP đổi email/focus, email/code/password validation, unread badge, đổi phương thức login, route ca đang làm và cập nhật sau từ chối lời mời. Các regression Google/fallback và REST/Hub/polling cũ vẫn qua.

Lệnh cuối chạy tại thư mục mỗi app:

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

Các lỗi fixture/compile và cleanup timer trong lần chạy test đầu đã được sửa, sau đó chạy lại toàn suite trên source cuối. Không bỏ test hoặc nới guard để có kết quả xanh.

## Phần còn lại ngoài đợt này

Customer còn 8 trường ref chuyển tiếp ở Self recipient, Caregiver list/search, Nearby caregiver và Notifications app bar; 27 builder field nằm ở Home, Catalog, danh sách/profile caregiver, Beneficiary list và Dispute. CallbackActionN còn ở những luồng khác của hai app. Cần đọc và dọn theo chức năng, có regression tương ứng; số đếm không tự chứng minh từng trường là lỗi.

Chưa chạy trên thiết bị thật hoặc xác nhận CI từ thay đổi này. Backend/Admin/Landing không được chạy lại trong đợt frontend này; kết quả và giới hạn Docker/PostGIS của đợt trước xem [báo cáo cấu trúc dự án](PROJECT_STRUCTURE_FIXES_2026-10-13.md).
