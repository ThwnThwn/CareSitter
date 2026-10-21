# Kết quả hoàn thiện kiến trúc Caregiver

> Đợt tiếp theo tách Shift list và trạng thái Git mới được ghi tại [báo cáo tách logic](FRONTEND_LOGIC_SEPARATION_2026-10-12.md).

Cập nhật: 12/10/2026, Asia/Saigon. Phạm vi: `frontend/caregiver-app`, tiếp tục sau Customer. Người dùng yêu cầu ưu tiên source để push và dừng build APK. Tài liệu này chỉ lưu local.

Source/test/cấu hình Caregiver đã commit và push lên `origin/develop`: [99a91ed](https://github.com/ThwnThwn/CareSitter/commit/99a91ed1509e04cd909572282f80b4fe6efec026). Push gồm 5 commit Caregiver đã có local và commit chốt này; không kèm Markdown hoặc các thay đổi Customer/backend/admin web còn local. CI remote chưa được dùng làm kết quả pass trong báo cáo này.

## Kết quả source

Analyze sạch; toàn bộ **81 test pass, 0 fail, 0 skip**. Quét 354 file Dart trong `lib`, trong đó 261 file có class UI: không còn file UI >300 dòng hoặc method UI `build`/`_build*` >80 dòng. Không còn literal font size/mã màu hex ngoài theme.

Lần rà source local đầu đợt này còn 6 file UI >300 dòng. Số 12 ở báo cáo trước là mốc lịch sử, trước các bước tách nhỏ đã có trên working tree.

## Các nhóm đã sửa

| Nhóm | Kết quả |
| --- | --- |
| Home | Tách header, KPI, offer, timeline, chart và cảnh báo thành widget. Derived provider quản lý đồng hồ/lọc ca; domain giữ luật lịch và khoảng chuyển ca. Controller khóa nhận/từ chối và bỏ kết quả sau dispose/đổi phiên. |
| Lịch làm việc | Lọc ngày/trạng thái/giờ qua domain và provider có kiểu; bỏ `dynamic`. Tách header/chọn ngày/lưới tháng/timeline/thẻ ca. Xóa sheet lịch rảnh không có nơi gọi, do API availability đã được gỡ từ trước. |
| Chi tiết ca, bản đồ, báo cáo | Tách thông tin ca/người thụ hưởng/checklist/bản đồ/action/summary/báo cáo. Giữ route, CARTO attribution và trường hợp chưa có vị trí hiện tại. |
| Khôi phục tài khoản | Controller giữ challenge ID, grant token, cooldown, thời hạn, request lock và generation. Model JSON nằm trong data; UI giữ ô nhập/điều hướng, dọn dữ liệu nhạy cảm khi đổi phiên. |
| Store theo tài khoản | Profile/ca/thu nhập/thông báo reset theo identity. Bỏ response cũ, hủy listener checklist, xử lý lỗi tải task khi reconnect. Upload avatar cũ không gỡ khóa của tài khoản mới. |
| KYC và hỗ trợ | Cancellation xuyên controller/repository/HTTP; có khóa và snapshot tệp. Dừng pipeline khi đổi phiên/dispose. Widget con nhận callback xóa tệp, không tự sửa danh sách qua `setState` của màn hình. |
| Rút tiền | Controller cấp và giữ key/payload khi chưa rõ kết quả trong cùng phiên; chặn payload khác. UI phân biệt đã gửi/bị từ chối/chưa rõ kết quả. Đọc số dư server thay vì trừ tiền local sau response retry; giới hạn tiền nằm trong domain. |
| Data/tokens | Mapper ca chuyển về data. Thiếu thời gian server hiển thị chưa có dữ liệu, không dựng giờ mẫu. Dùng tokens font/màu/spacing/radius. |
| Kiểm tra kiến trúc | AST kiểm tra mọi widget, bỏ ngoại lệ UI cũ; kiểm tra phụ thuộc tầng và UI giữa feature. Script PowerShell gọi cùng test, không duy trì bộ rule thứ hai. |

Test Home ở 320 px/text scale 1.4 phát hiện tràn ngang phần địa chỉ. Đã cho thông tin người thụ hưởng/thu nhập xếp dọc khi thiếu chỗ; bố cục rộng giữ hàng ngang. Test kiểm tra nhận/từ chối không mở chi tiết và offer hết hạn/đang xử lý khóa cả hai nút.

## Kiểm chứng

Windows, Flutter 3.44.4 stable, Dart 3.12.2, cùng Flutter của CI tracked. `analyzer` 7.6.0 đã có trong lockfile; chỉ khai báo rõ thành dev dependency cho AST, không nâng phiên bản.

Lệnh trong `frontend/caregiver-app`:

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
./scripts/check-refactor-rules.ps1 -FlutterCommand C:/src/flutter/bin/flutter.bat
```

Analyze không có issue; 81 test pass; kiểm tra kích thước/ranh giới tầng pass; `git diff --check -- frontend/caregiver-app` pass. **Build APK đã dừng theo yêu cầu; không tính là build thành công.**

Bằng chứng local tại [`backend/artifacts/frontend-architecture-20261012/`](../../backend/artifacts/frontend-architecture-20261012/): `caregiver-final-analyze.log`, `caregiver-final-tests.log`, `caregiver-final-static.json`, `caregiver-inventory-final.jsonl`, `caregiver-home-widgets.log`, `caregiver-rule-script.log`.

## Giới hạn và việc còn lại

1. Đây là refactor source và test local, không phải nghiệm thu production. Test kích thước/import không chứng minh mọi luật nghiệp vụ đã chuyển hết sang domain.
2. Chưa nghiệm thu thiết bị thật/iOS/production. Không có kết quả build Android được nghiệm thu cho đợt này.
3. Key payout chưa rõ kết quả giữ trong bộ nhớ theo phiên, chưa phục hồi sau khi đóng app. Frontend giữ đúng payload; không tuyên bố đã xử lý mọi restart hoặc toàn bộ payout backend. Backend tìm theo user/key, cần rà payload conflict/đối soát trước nghiệm thu tiền thật.
4. Hủy KYC/hỗ trợ không xóa side effect đã được server nhận. Cần kiểm chứng file tạm và response bị mất trên môi trường thật.
5. Backend `POST /bookings` vẫn cần idempotency lưu bền như đợt Customer; không sửa backend trong đợt này. Shared SignalR/refresh token/background GPS cần nghiệm thu theo thiết bị và quyền server.
6. Customer/backend/admin web/cấu hình ngoài Caregiver còn local. Markdown/rule và xóa Markdown đã tracked giữ local, không đưa vào commit Caregiver.

## Điểm bắt đầu khi sửa tiếp

- [Controller thao tác offer](../../frontend/caregiver-app/lib/features/home/presentation/controllers/offer_action_controller.dart)
- [Provider Home](../../frontend/caregiver-app/lib/features/home/presentation/controllers/home_selectors.dart)
- [Provider lịch](../../frontend/caregiver-app/lib/features/schedule/presentation/controllers/schedule_selectors.dart)
- [Store ca](../../frontend/caregiver-app/lib/features/shifts/presentation/controllers/shift_list_controller.dart)
- [Controller ca đang thực hiện](../../frontend/caregiver-app/lib/features/shifts/presentation/controllers/shift_active_controller.dart)
- [Controller khôi phục](../../frontend/caregiver-app/lib/features/auth/presentation/controllers/password_recovery_controller.dart)
- [Controller hỗ trợ](../../frontend/caregiver-app/lib/features/settings/presentation/controllers/support_submission_controller.dart)
- [Store thu nhập/retry payout](../../frontend/caregiver-app/lib/features/earnings/presentation/controllers/earnings_controller.dart)
- [Test kiến trúc](../../frontend/caregiver-app/test/architecture/frontend_boundaries_test.dart)

Đọc đầy đủ [quy ước chung](../QUY_UOC_CODE_VA_SECRET.md) và [rule.frontend](../frontend/RULE_FRONTEND.md) trong từng tác vụ tiếp theo. [Kết quả Customer](CUSTOMER_ARCHITECTURE_REFACTOR_2026-10-12.md) là đợt trước đó.
