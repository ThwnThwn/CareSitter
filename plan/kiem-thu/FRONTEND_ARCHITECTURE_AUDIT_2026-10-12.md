# Rà soát kiến trúc Frontend Flutter + Riverpod

> Báo cáo lịch sử trước refactor. Source và một số đường dẫn/số dòng bên dưới đã thay đổi. Xem [kết quả refactor hiện tại](FRONTEND_REFACTOR_2026-10-12.md) để theo dõi năm ưu tiên, test và phần còn lại.

Cập nhật: 12/10/2026, Asia/Saigon. Phạm vi: source hiện tại của `frontend/customer-app/lib` và `frontend/caregiver-app/lib`, gồm thay đổi local chưa commit. Đối chiếu bộ 10 quy tắc người dùng gửi trong tác vụ này. Trạng thái: đã rà tĩnh và đọc các vị trí có dấu hiệu vi phạm; không refactor source, không chạy lại Flutter test/analyze. Báo cáo và bằng chứng chỉ lưu local.

## Kết luận

**Chưa tuân thủ đầy đủ.** Hai app có nền feature-first, repository, model và Riverpod. Những điểm chưa đạt tập trung ở hướng phụ thuộc, ranh giới UI/controller/repository, state nghiệp vụ trong màn hình, kích thước UI và hợp đồng lỗi/idempotency.

CI đang kiểm tra analyze/test/build; các kiểm tra đó chưa thực thi bộ quy tắc kiến trúc này. Không dùng CI xanh làm chứng nhận tuân thủ cấu trúc mới.

## Phạm vi và số liệu

| Chỉ số | Customer | Caregiver |
| --- | ---: | ---: |
| File Dart trong lib | 127 | 78 |
| Feature | 11 | 7 |
| File UI vượt 300 dòng | 28 | 11 |
| File UI có tham chiếu RepositoryProvider, đã đọc đối chiếu các lời gọi | 13 | 4 |
| Import/export từ core sang feature | 38 | 25 |
| Import data sang presentation | 1 | 0 |
| Import controller sang screens/widgets | 0 | 0 |
| Model trong data/models import Flutter/Riverpod | 0 | 0 |
| Controller import Dio | 3 | 1 |
| File Dart trong test | 39 | 11 |

Số liệu import là số cạnh phụ thuộc, không phải số file. Các import từ feature sang controller của feature khác cần xét ngoại lệ provider công khai: không kết luận mọi import presentation đều sai. Phần được xác minh rõ gồm bốn import widget chéo feature ở customer và một repository phụ thuộc controller.

## Đối chiếu 10 nhóm quy tắc

| Quy tắc | Kết quả | Nhận xét |
| --- | --- | --- |
| 1. Cấu trúc tổng | Một phần | Có core/features/data/presentation; bootstrap ở app.dart thay vì app/. Nutrition còn đặt repository/controller/screen/widget trực tiếp dưới data/presentation. Domain là tùy chọn, không coi thiếu thư mục domain là lỗi tự thân. |
| 2. Nội dung từng tầng | Chưa đạt | Model không import UI và controller không gọi UI trong phạm vi quét, nhưng UI gọi repository; một số repository trả Map thay vì model; luật nghiệp vụ nằm ở widget/model. |
| 3. Hướng phụ thuộc | Chưa đạt | Core biết feature; AuthRepository customer import ProfileStore presentation; widget được dùng chéo feature. |
| 4. Đặt tên/chia file | Một phần | Phần lớn tên file snake_case; tên BookingStore không khớp booking_controller.dart; state và nhiều class public còn gộp cùng file. Một file có nhiều class public là dấu hiệu cần review, không tự coi mọi helper class là một vi phạm riêng. |
| 5. Kích thước | Chưa đạt | 39 file UI trên 300 dòng; wizard chưa chia từng step thành widget; một số _buildXxx lớn hơn 80 dòng. |
| 6. State/Riverpod | Một phần | Có autoDispose, session guard và hủy request ở các luồng mới; vẫn có state nghiệp vụ trong State, getter UI dùng ref.read, flow giữ object/Map API và side effect từ build. |
| 7. Tái sử dụng | Chưa đạt | Format tiền lặp, chưa có core/utils thống nhất; spacing/font/radius còn ghi trực tiếp; một số mã lỗi là chuỗi trong UI. |
| 8. API/lỗi/idempotency | Chưa đạt | DioException còn đi qua controller/UI; booking không gửi key; payout tạo key mới mỗi lần gọi repository. Nutrition đã có key ổn định theo thao tác trong phiên. |
| 9. Test | Một phần | Có unit/controller và widget test cho các luồng quan trọng; chưa thấy unit test trực tiếp cho nhiều controller và chưa có kiểm tra import boundary. Test chưa phản chiếu đầy đủ cấu trúc lib. |
| 10. Checklist code mới | Chưa được thực thi tự động | Những sai lệch trên cho thấy checklist chưa được áp dụng đều; chưa thấy custom lint/architecture check cho các quy tắc này trong CI và cấu hình analyzer đã đọc. |

## Dẫn chứng đã xác minh

### A. Repository phụ thuộc ngược vào presentation

[AuthRepository customer](../../frontend/customer-app/lib/features/auth/data/repositories/auth_repository.dart), dòng 6, import `features/settings/presentation/controllers/profile_controller.dart`. Các dòng 109, 121–124 reset/cập nhật/fetch `profileStoreProvider` từ repository.

Đây là vi phạm trực tiếp quy tắc data không biết presentation. Đưa điều phối phiên và profile vào controller/coordinator, giữ repository trả kết quả API qua hợp đồng dữ liệu.

### B. UI gọi repository trực tiếp

- [PaymentResultScreen](../../frontend/customer-app/lib/features/booking/presentation/screens/payment_result_screen.dart), dòng 50: đọc bookingRepositoryProvider rồi gọi API intent/booking trong màn hình.
- [Payment checkout sheet](../../frontend/customer-app/lib/features/booking/presentation/screens/payment_checkout_sheet.dart), dòng 31, 42, 131: lấy provider thanh toán và tạo intent từ UI.
- [VerifiedAddressField](../../frontend/customer-app/lib/features/catalog/presentation/widgets/verified_address_field.dart), dòng 92, 124: widget tự gọi autocomplete và chi tiết địa chỉ.
- [Password recovery caregiver](../../frontend/caregiver-app/lib/features/auth/presentation/screens/password_recovery_screen.dart), dòng 70, 113: gọi recovery repository từ màn hình.
- [Reviews caregiver](../../frontend/caregiver-app/lib/features/settings/presentation/screens/reviews_screen.dart), dòng 35: tải dữ liệu repository từ màn hình.

Chuyển tải dữ liệu, debounce, trạng thái request và lỗi vào controller của từng flow. UI nhận state và gọi action của controller.

### C. Wizard và màn hình quá lớn, chứa nghiệp vụ

| File | Số dòng |
| --- | ---: |
| customer booking_wizard_screen.dart | 2.363 |
| customer shift_tracking_screen.dart | 1.945 |
| customer home_screen.dart | 1.761 |
| customer booking_detail_screen.dart | 1.301 |
| caregiver shift_active_screen.dart | 1.852 |
| caregiver schedule_screen.dart | 1.385 |
| caregiver home_screen.dart | 1.271 |
| caregiver shift_detail_screen.dart | 1.191 |

[BookingWizardScreen](../../frontend/customer-app/lib/features/booking/presentation/screens/booking_wizard_screen.dart):

- Dòng 39–59 giữ lựa chọn người nhận/dịch vụ/caregiver, thời gian, địa chỉ, consent và trạng thái submit trong State.
- Dòng 143–172: getter dùng ref.read để lấy object được UI sử dụng. Màn hình có watch một số store nên không kết luận mọi getter đều làm mất cập nhật; cách tổ chức vẫn khác quy tắc selector được đưa ra.
- Dòng 173–250: kiểm lịch hợp lệ, làm tròn giờ, lọc và chấm điểm caregiver, quyết định bước tiếp theo nằm trong screen.
- `_buildTimeStep` bắt đầu dòng 906 và kết thúc dòng 1.588: 683 dòng; vượt xa ngưỡng 80.
- Các bước hiện là _buildServiceStep/_buildBeneficiaryStep/_buildTimeStep/... trong cùng file, chưa là widget trong widgets/<flow>/steps/.

Tách BookingWizardController/BookingWizardState, rule lịch và selector; từng step nhận state/callback và nằm trong file widget riêng. Tách file theo trách nhiệm, không chỉ đổi tên method.

### D. Side effect từ build

- [NutritionScreen](../../frontend/customer-app/lib/features/nutrition/presentation/nutrition_screen.dart), dòng 121: build gọi `_populate(health)`. Hàm ở dòng 71 thay TextEditingController, loaded revision và các dirty flag. Đây là side effect dù không gọi setState trực tiếp trong build.
- [ShiftActiveScreen caregiver](../../frontend/caregiver-app/lib/features/shifts/presentation/screens/shift_active_screen.dart), dòng 355–363: build đăng ký addPostFrameCallback để phục hồi state server và gọi tải task. Đúng kiểu scheduling side effect trong build mà rule mới cấm.

Dùng ref.listen/lifecycle phù hợp để đồng bộ controller nhập liệu, và để controller điều phối việc khôi phục/tải dữ liệu.

### E. Core biết feature và widget được dùng chéo feature

Hai `core/router/app_router.dart` import các screen của feature. Việc mapping route là cần thiết, nhưng theo bộ rule này nó thuộc composition root `app/router`; core/router giữ helper điều hướng và redirect generic.

- [Customer Firebase push](../../frontend/customer-app/lib/core/push/firebase_push_notifications.dart), dòng 11–12: phụ thuộc booking/home controller.
- [Caregiver Firebase push](../../frontend/caregiver-app/lib/core/push/firebase_push_notifications.dart), dòng 10–11: phụ thuộc home/shifts controller.
- [Customer SignalR](../../frontend/customer-app/lib/core/realtime/care_signalr_service.dart), dòng 6: import DTO từ feature booking.
- [SelfRecipientForm](../../frontend/customer-app/lib/features/booking/presentation/widgets/self_recipient_form.dart), dòng 4–5: import widget beneficiary.
- Home customer import caregiver_location_selector; saved_addresses_screen import verified_address_field của catalog.

Tách listener/adapter phối hợp feature sang app hoặc feature tương ứng. Widget dùng chung cần phần UI generic nhận dữ liệu/callback; không chuyển cả logic tải dữ liệu của feature vào core.

### F. Hợp đồng lỗi và DTO chưa được đóng ở data

[_ErrorInterceptor customer](../../frontend/customer-app/lib/core/api/dio_client.dart), dòng 201, vẫn chuyển tiếp một DioException chứa AppApiException trong error. Booking wizard, payment sheet, shift tracking và controller bắt DioException. Tương tự có ở caregiver live tracking và shift active.

Trong rule mới, repository/data adapter phải kết thúc phụ thuộc Dio và trả AppApiException hoặc kết quả lỗi thuần. Cơ chế hủy request cũng cần abstraction/handle thuần nếu yêu cầu controller hoàn toàn không biết Dio.

[BeneficiaryRepository](../../frontend/customer-app/lib/features/beneficiary/data/repositories/beneficiary_repository.dart), dòng 64, trả List<Map<String, dynamic>> cho danh sách; controller tiếp tục map sang BeneficiaryModel. [NutritionRepository](../../frontend/customer-app/lib/features/nutrition/data/nutrition_repository.dart) trả Map cho health/resource/capabilities; flow controller giữ và đọc JSON trực tiếp. Có thể giữ nội dung linh hoạt trong DTO có version, nhưng mapping hợp đồng API nên nằm ở data.

### G. State và rule thuần

- SelfRecipient ở dòng 20–23 giữ BeneficiaryModel cho flow; NutritionFlow ở dòng 33–34 giữ health/resource Map API. Khác yêu cầu state lựa chọn chỉ giữ ID/draft và lấy object qua provider dẫn xuất.
- SelfRecipient.isComplete chứa rule tên/liên hệ khẩn cấp/số điện thoại trong file controller; rule này nên có vị trí thuần Dart và unit test riêng.
- [ShiftModel caregiver](../../frontend/caregiver-app/lib/features/shifts/data/models/shift_model.dart), dòng 216–222: các rule canAccept/canStartEnRoute/canCheckIn/canWorkChecklist/canRequestCheckout nằm trong DTO. Đã có test policy, nhưng vị trí logic chưa theo domain của bộ rule mới.

Điểm cần chốt khi áp dụng: entity store là nguồn dữ liệu API và có thể cần giữ model; nên phân biệt store với state lựa chọn/draft của một flow. Không biến ngoại lệ này thành lý do tiếp tục giữ object lựa chọn ở mọi màn hình.

### H. Format và tokens còn lặp

Format tiền bằng replaceAllMapped lặp ở booking wizard/detail/list, home, activity, settings, wallet, caregiver list/profile và payment sheet của customer. Caregiver có formatter trong data/models/earning_model.dart và formatter riêng ở các screen khác. Chưa có thư mục core/utils trong hai app.

Wizard còn nhiều fontSize/radius/spacing ghi trực tiếp dù theme đã có AppSpacing/AppRadius. Customer có 10 file presentation chứa Color(0x...) trong quét; caregiver không có mẫu Color(0x...) đó nhưng vẫn có kích thước chữ/khoảng cách ghi trực tiếp.

Mã booking.caregiver.schedule_conflict và các mã beneficiary/nutrition vẫn xuất hiện trong UI/controller. Dùng hằng số/enum lỗi và một formatter thống nhất theo app.

### I. Idempotency chưa thống nhất cho thao tác ghi

- [BookingRepository](../../frontend/customer-app/lib/features/booking/data/repositories/booking_repository.dart), dòng 70: createBooking chưa truyền khóa idempotency. App có xử lý kết quả chưa xác định nhưng đó là cơ chế phục hồi khác với replay theo key.
- createPaymentIntent ở dòng 41 không truyền key phía client. Backend hiện có cơ chế tái sử dụng giao dịch; thiếu key theo bộ rule frontend không đủ để kết luận mọi thanh toán đều bị tạo trùng.
- [EarningsRepository caregiver](../../frontend/caregiver-app/lib/features/earnings/data/repositories/earnings_repository.dart), dòng 35: sinh Uuid mới mỗi lần gọi requestWithdrawal; caller không truyền key để giữ một thao tác logic qua các lần người dùng thử lại. Retry cùng RequestOptions ở interceptor có thể vẫn giữ body cũ; vấn đề ở lần gọi nghiệp vụ mới.
- Nutrition đã giữ key theo route/thao tác trong controller và truyền trong body. Nó chưa dùng header Idempotency-Key như tên trong rule, nhưng không nên đổi vị trí key nếu backend chưa hỗ trợ cùng hợp đồng.

Giải quyết đồng thời client và backend: xác định scope key, giữ key qua retry, so payload và trả lại booking/payout cũ theo key. Không chỉ thêm header ở app rồi coi việc chống ghi lặp đã hoàn tất.

### J. Test và kiểm tra kiến trúc

Có unit test thực sự cho self-recipient, booking store, nearby caregiver và live tracking; có widget test cho wizard, payment, nutrition, đăng nhập, địa chỉ và các màn hình quan trọng. Tuy nhiên, qua inventory import chưa thấy unit test trực tiếp cho login controller của hai app, family contact/wallet customer và nhiều controller caregiver như earnings/check-in/profile/schedule. Một số controller có thể được chạy gián tiếp qua widget test; số liệu inventory không phải coverage runtime.

Test hiện được nhóm theo feature, chưa phản chiếu đầy đủ domain/controllers/repositories/screens. Có FakeRepository/Dio adapter ở một số ca; chưa xác minh mọi repository đều có test riêng cho mapping và lỗi.

## Thứ tự refactor đề xuất

1. Đóng ranh giới data: AuthRepository không phụ thuộc ProfileStore; lỗi/DTO kết thúc ở repository; UI gọi controller.
2. Booking wizard: state/controller/selector, rule lịch, từng step widget và idempotency thống nhất backend-client.
3. Nutrition: DTO có version, controller/screen/widgets vào đúng thư mục, đồng bộ form qua listener và giữ state/lifecycle hiện có.
4. Caregiver shift active và schedule: tách state nghiệp vụ, flow check-in/task, bỏ scheduling từ build; thêm unit test controller.
5. Composition root app/router/push, widget generic và format/tokens dùng chung.
6. Bổ sung kiểm tra import boundary/kích thước vào CI theo từng đợt; chạy regression theo feature sau mỗi đợt, giữ nguyên hành vi và hợp đồng backend.

## Bằng chứng và giới hạn

- Quét toàn bộ 205 file Dart hiện có; đối chiếu thủ công các vị trí chính đã nêu.
- [Static scan JSON](../../backend/artifacts/frontend-architecture-20261012/static-scan.json).
- [Inventory test](../../backend/artifacts/frontend-architecture-20261012/test-inventory.json).
- Phân tích dựa trên source và import; không đo performance, coverage, hành vi thiết bị hoặc kích thước mọi method bằng AST.
- Không sửa source/app/config, không stage/commit/push báo cáo. Các thay đổi local có sẵn vẫn được giữ.
