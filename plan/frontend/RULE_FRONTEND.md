# rule.frontend — Flutter + Riverpod

Cập nhật: 12/10/2026. Phạm vi: `frontend/customer-app` và `frontend/caregiver-app`. Đây là nguồn chuẩn cho kiến trúc frontend; [báo cáo rà soát](../kiem-thu/FRONTEND_ARCHITECTURE_AUDIT_2026-10-12.md) ghi tình trạng source, không thay thế rule.

## 1. Đọc bắt buộc

Đọc **toàn bộ** tài liệu này và [quy ước code/secret](../QUY_UOC_CODE_VA_SECRET.md) trong tác vụ hiện tại trước khi sửa source, cấu hình hoặc test Flutter. Đọc lại nếu cập nhật. [AGENTS gốc](../../AGENTS.md) và [AGENTS frontend](../../frontend/AGENTS.md) thực thi yêu cầu này. Không chỉ đọc mục lục hoặc dựa vào trí nhớ.

## 2. Cấu trúc thư mục

Đường dẫn dưới đây tính từ `frontend/<app>/lib/`:

```text
main.dart
app/                         # bootstrap, MaterialApp, composition root, route map
core/
  api/                       # HTTP adapter, interceptor, AppApiException
  auth/                      # session, token storage
  router/                    # navigation helper generic
  theme/                     # colors, spacing, radius, typography
  utils/                     # currency, date, phone, validators
  widgets/                   # widget generic dùng nhiều feature
  constants/
features/<feature>/
  data/
    models/                  # DTO JSON, enum trên dây
    repositories/            # gọi API, map lỗi, trả DTO
    sources/                 # optional remote/local datasource
  domain/                    # optional nghiệp vụ thuần Dart
  presentation/
    controllers/             # Notifier, state, selector, SubmitResult
    screens/                 # khung route, điều hướng, snackbar/dialog
    widgets/                 # UI feature; common/ cho phần tái sử dụng nội bộ
    models/                  # label/icon/view-model hiển thị
```

## 3. Ranh giới và hướng phụ thuộc

`screens/widgets → controllers → domain`; controller gọi repository; `repository → data/models`. Domain không import tầng khác. `core` không import `features`. Code ghép route hoặc nối lifecycle nhiều feature đặt trong `app/`, không đặt trong core.

| Tầng | Trách nhiệm | Cấm |
| --- | --- | --- |
| core | Hạ tầng/tiện ích generic | Import feature |
| data/models | Map JSON và enum API | Flutter UI, Riverpod |
| data/repositories | I/O, mapping DTO/lỗi | presentation, BuildContext |
| domain | Validation, tính toán, schedule/matcher | Flutter, Riverpod, Dio |
| controllers | State/use case, kết quả thao tác | BuildContext, Navigator, SnackBar, showDialog, screens/widgets, Dio |
| screens | Vẽ khung, điều hướng, thông báo | Gọi repository/API trực tiếp, nghiệp vụ |
| widgets | Vẽ UI, callback/provider công khai | Gọi repository/API trực tiếp |
| presentation/models | Format/label/màu/icon | Luật nghiệp vụ |

Không import presentation nội bộ của feature khác. Chỉ dùng data/models hoặc provider công khai của feature đó; widget generic dùng nhiều feature chuyển về core và nhận dữ liệu/callback. Repository không điều phối đăng nhập, profile store hoặc UI: controller/composition root sở hữu việc đó.

## 4. Tên và kích thước

- File `snake_case.dart`, hậu tố đúng vai trò: `_screen`, `_step`, `_controller`, `_state`, `_repository`, `_model`, `_selectors`.
- Provider `xxxProvider`, class `XxxController`/`XxxState`. Một file có một class public chính; tên file tương ứng.
- File UI trên 300 dòng phải tách widget. Method `build`/`_build...` trên 80 dòng tách thành widget thực sự, không chia thành nhiều method vẽ UI.
- Widget private trên khoảng 80 dòng tách file. State có trên 5 biến mutable nghiệp vụ chuyển sang Notifier.
- Wizard: mỗi bước trong `widgets/<flow>/steps/`; màn hình giữ khung và xử lý kết quả UI.

## 5. State và Riverpod

- Tab, animation, TextEditingController là state UI tạm thời; business/shared state thuộc Notifier.
- Flow state lưu ID và input người dùng. Entity suy ra từ store + ID qua provider dẫn xuất. Store repository có thể giữ DTO để cache dữ liệu; không sao chép DTO vào flow state.
- `build` dùng `ref.watch`, ưu tiên `select` cho slice nhỏ. Callback dùng `ref.read`; không đọc provider trong getter mà UI phụ thuộc.
- Controller trả kết quả thao tác/SubmitResult (sealed khi có nhiều nhánh); màn hình quyết định snackbar và navigation.
- Không cập nhật state hoặc tạo side effect trong build, kể cả post-frame. Dùng `ref.listen` hoặc controller. Listener nhận dữ liệu mới phải bảo vệ input đã sửa và revision.
- Reset flow bằng watch user/session ID trong Notifier build. Dùng autoDispose; hủy request, timer/subscription thuộc flow khi dispose/đổi phiên, bỏ kết quả request cũ. Không dừng SignalR dùng chung từ màn hình.

## 6. Dùng chung và tokens

- Format tiền/ngày/phone qua hàm duy nhất trong `core/utils/`, như `formatVnd`, `formatDate`, `formatPhone`. Không rải regex format tiền.
- Màu/spacing/radius/typography dùng tokens `core/theme/`; không tạo bản sao literal ở widget. Giữ thiết kế hiện có khi refactor.
- Widget dùng từ hai feature: `core/widgets`; một feature: `presentation/widgets/common`.
- Mã lỗi API là constant/enum trong data/domain, không chuỗi trần trong UI.

## 7. API, lỗi và retry

- Chỉ repository/data adapter biết Dio. Controller/UI dùng `AppApiException` với code/message và phân loại cancellation/transport/status khi cần.
- Map lỗi tại biên data/API, giữ thông tin lỗi nghiệp vụ và phân biệt response bị mất với request bị từ chối.
- Ghi quan trọng dùng `Idempotency-Key` sinh phía client; retry cùng thao tác giữ cùng key. Chỉ tuyên bố retry an toàn khi backend lưu bền key và đối chiếu payload. Khi backend chưa hỗ trợ, giữ trạng thái chưa rõ và đối soát; không tự gửi lại POST booking chỉ vì thêm header.
- Không thay endpoint/JSON/status/ownership chỉ để đơn giản hóa refactor. Token lưu secure storage; không thêm secret vào app.

## 8. Test và kiểm chứng

- Domain và controller thay đổi có unit test trực tiếp, không bắt buộc dựng widget.
- Repository test mock HTTP/Dio cho DTO, lỗi và contract key/cancellation.
- Widget test các bước/luồng quan trọng, session reset, loading/error và điều hướng. `test/` phản chiếu `lib/`.
- Chạy `flutter analyze` và test chịu tác động trong mỗi app; full suite khi hoàn tất đợt refactor. Ghi lệnh, pass/fail/skip và giới hạn. Không coi test skip là pass.

## 9. Thứ tự refactor đã chốt

1. Ranh giới repository/controller: bỏ data → presentation, UI → repository, Dio → controller.
2. Booking wizard: controller/state + domain schedule + widget từng bước, giữ luồng tự đặt/đặt người thân và xử lý booking chưa rõ kết quả.
3. Nutrition: models/repositories/controllers/screens/widgets đúng thư mục; DTO có kiểu; giữ cancellation, revision, session ownership và idempotency hiện có.
4. Caregiver shift active: controller nghiệp vụ + widget check-in/checklist/checkout; bỏ side effect build; giữ GPS/realtime và điều kiện ca.
5. Formatter/tokens: gom các bản sao, không thay thiết kế hoặc nội dung nghiệp vụ.

Chỉ đánh dấu từng phần hoàn thành khi code và kiểm chứng đã thực hiện. Các màn hình cũ còn vi phạm ngoài đợt này phải được ghi trong báo cáo; không giảm ngưỡng rule để làm báo cáo đẹp.

## 10. Checklist trước khi kết thúc

- [ ] Đã đọc rule đầy đủ trong tác vụ hiện tại.
- [ ] JSON/API trong data; rule trong domain; state trong controller; widget chỉ vẽ/nhận callback.
- [ ] Không phụ thuộc ngược hoặc dùng presentation nội bộ feature khác.
- [ ] Không vượt ngưỡng UI/build/business state của code vừa sửa.
- [ ] Session/lifecycle và kết quả request cũ được xử lý.
- [ ] Formatter/tokens/mã lỗi không bị nhân bản.
- [ ] Test cần thiết pass; báo rõ việc còn lại và trạng thái local.
- [ ] Markdown chưa stage/commit/push nếu chưa được yêu cầu riêng.
