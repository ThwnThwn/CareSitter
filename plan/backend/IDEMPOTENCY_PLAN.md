# Kế hoạch triển khai idempotency cho CareSitter

Ngày lập: 06/10/2026. Trạng thái: **kế hoạch, chưa triển khai các thay đổi bên dưới**.

## 1. Mục tiêu và phạm vi

Một lần đặt lịch hoặc tạo yêu cầu rút tiền phải có một mã thao tác riêng. Khi
người dùng bấm lại, mạng gửi lại, token được refresh hoặc app mở lại sau lỗi,
hệ thống nhận ra thao tác đó và trả kết quả đã ghi nhận. Chỉ một booking hoặc
một yêu cầu rút tiền được tạo, số dư và lượt ưu đãi chỉ thay đổi một lần.

Phạm vi triển khai lần này:

1. Tạo booking từ customer app, gồm booking có ưu đãi.
2. Hoàn thiện hợp đồng idempotency của API tạo yêu cầu rút tiền.
3. Giữ mã thao tác và phục hồi kết quả trong hai app Flutter.
4. Migration, kiểm thử đồng thời, kiểm thử mất phản hồi và hướng dẫn vận hành.

Idempotency của payment callback, ledger, redeem/release và Kafka được giữ
lại, kèm kiểm thử hồi quy liên quan. Kết nối chi hộ VNPAY, refund, tranh chấp,
chat và các API ghi khác là các đầu việc riêng trong
[kế hoạch production](PRODUCTION_PLAN.md).

## 2. Hiện trạng đã đối chiếu

| Luồng | Đã có | Khoảng trống cần xử lý |
| --- | --- | --- |
| Tạo booking | Kiểm tra lịch ở Application; migration 27 có trigger/constraint chống lịch trùng tại PostgreSQL | Request, command và app chưa có key; retry chưa trả lại booking đã tạo |
| Booking có ưu đãi | Reservation duy nhất theo `booking_id`; có release nếu bước lưu booking lỗi | Booking và Promotion đang tự quản lý transaction; tiến trình chết sau reserve có thể để lại lượt giữ chưa gắn với booking đã lưu |
| Tạo yêu cầu rút tiền | Key trong body/header; unique `(caregiver_id, idempotency_key)`; transaction giữ số dư; trả yêu cầu cũ | Chưa so nội dung khi dùng lại key; body được ưu tiên khi hai vị trí khác nhau |
| Caregiver app | Gửi key khi tạo yêu cầu rút tiền; khóa nút trong lúc gửi | Repository tạo UUID mới mỗi lần gọi; controller chỉ trả `bool`, làm mất phân biệt lỗi mạng/kết quả chưa rõ; phản hồi lặp có thể bị trừ số dư hiển thị thêm |
| Thanh toán/ledger | Khóa transaction, trạng thái đã thành công và unique business key | Kiểm thử hồi quy; không thay hợp đồng tạo payment intent trong đợt này |
| Ưu đãi | Redeem/release lặp trên cùng booking không phát sinh thêm lượt dùng | Phải bảo đảm retry tạo booking luôn dùng lại đúng booking ban đầu |
| Kafka | Có Inbox chống xử lý lặp theo consumer/handler/event trong transaction | Phân biệt bảo vệ event với bảo vệ HTTP; Inbox không tự bảo vệ API tạo booking |

Nguồn mã chính:

- [Tạo booking](../../backend/caresitter-be/Modules/Booking/Application/Commands/Bookings/CreateBooking/CreateBookingCommandHandler.cs),
  [controller](../../backend/caresitter-be/Modules/Booking/Controllers/BookingsController.cs) và
  [ràng buộc lịch PostgreSQL](../../backend/init-db/27-phase8-transaction-integrity.sql).
- [Tạo payout](../../backend/caresitter-be/Modules/Payments/Application/Commands/Payouts/CreatePayout/CreatePayoutCommandHandler.cs),
  [transaction payout](../../backend/caresitter-be/Modules/Payments/Infrastructure/PayoutStore.cs).
- [Reservation ưu đãi](../../backend/caresitter-be/Modules/Promotion/Infrastructure/PromotionApplicationService.cs).
- [Repository booking](../../frontend/customer-app/lib/features/booking/data/repositories/booking_repository.dart),
  [repository rút tiền](../../frontend/caregiver-app/lib/features/earnings/data/repositories/earnings_repository.dart),
  [controller thu nhập](../../frontend/caregiver-app/lib/features/earnings/presentation/controllers/earnings_controller.dart).

## 3. Hợp đồng API đề xuất

### Quy tắc key và nội dung

- App tạo UUID v4 **một lần trước lần gửi đầu tiên**, sau khi người dùng xác nhận.
- Backend chấp nhận key dạng chuỗi opaque 1–100 ký tự ASCII hiển thị, không
  có khoảng trắng/control character; giữ tương thích key payout đang tồn tại.
- Phạm vi key là `(người dùng đã xác thực, loại thao tác, key)`. Hai người
  dùng khác nhau không thể đọc kết quả của nhau dù gửi cùng key.
- Cùng key và cùng nội dung: trả tài nguyên đã tạo; không chạy lại nghiệp vụ.
- Cùng key nhưng khác nội dung: `409`, mã `idempotency.payload_mismatch`.
- Thiếu/sai key khi endpoint đã bật yêu cầu bắt buộc: `400`, mã
  `idempotency.key_required` hoặc `idempotency.key_invalid`.
- Payout tiếp tục nhận key trong body để hỗ trợ app cũ. Nếu body và header
  cùng có nhưng khác nhau: `400 idempotency.key_conflict`; không tự chọn một.
- App mới dùng header `Idempotency-Key` cho cả hai endpoint.

### Endpoint và kết quả

| Endpoint | Hành vi |
| --- | --- |
| `POST /api/v1/bookings` | Nhận header key và body hiện có; lần tạo đầu `201`, retry thành công `200`, cùng `bookingId` và `Location` |
| `POST /api/v1/payments/payouts` | Lần tạo đầu `201`, retry thành công `200`, cùng `payoutId` |
| `GET /api/v1/bookings/submission` | Tra cứu bằng header key, chỉ cho customer sở hữu thao tác |
| `GET /api/v1/payments/payouts/submission` | Tra cứu bằng header key, chỉ cho caregiver sở hữu thao tác |

Response thành công do replay có header `Idempotency-Replayed: true`.
Response trả trạng thái hiện tại của **cùng tài nguyên**, không cam kết JSON
giống từng byte nếu booking/payout đã chuyển trạng thái. Tra cứu chưa có
kết quả commit trả `404`; app được gửi lại cùng key và cùng payload.

POST đang cạnh tranh cùng key trả `409 idempotency.in_progress` và
`Retry-After: 2`. Lỗi này có thể retry bằng chính key đó. Khóa giao dịch của
worker cũ được PostgreSQL giải phóng khi transaction kết thúc hoặc kết nối
bị ngắt; không dùng một cờ `PROCESSING` tồn tại vô hạn trong Redis.

Xác thực, role và ownership luôn được kiểm tra. Khi replay một thao tác đã
commit, không kiểm lại điều kiện dành cho **tạo mới** như lịch phải ở tương
lai hay số dư phải còn đủ; những điều kiện đó có thể đã thay đổi sau lần đầu.
Tài nguyên bị xóa theo chính sách dữ liệu trả `410`; giữ dấu key đã dùng để
không biến retry thành lần tạo mới.

### Chuẩn hóa nội dung

Fingerprint có phiên bản, được tính từ DTO đã chuẩn hóa, không phụ thuộc
thứ tự property JSON. Dùng cùng quy tắc chuẩn hóa với nghiệp vụ hiện có.

| Thao tác | Nội dung phải đối chiếu |
| --- | --- |
| Booking | Beneficiary, address, service, giờ bắt đầu/kết thúc quy về UTC, caregiver nếu hợp đồng cho phép, required skills và mã ưu đãi |
| Payout | Số tiền nguyên VND, ngân hàng, tên chủ tài khoản và số tài khoản dạng chuỗi giữ số 0 ở đầu |

Không đưa token, thời điểm retry, trace ID hay giá do app tự khai vào
fingerprint. `null`, giá trị mặc định và trim phải được quy định nhất quán;
chỉ sắp xếp/loại trùng skills nếu nghiệp vụ coi chúng là một tập hợp.

Fingerprint payout dùng HMAC phía server để bảo vệ dữ liệu tài khoản ngân
hàng có không gian giá trị nhỏ. Lưu `hash_version`/`hash_key_id`, giữ key cũ
trong keyring để đối chiếu bản ghi cũ khi xoay khóa. Không log key bí mật,
payload thô hay số tài khoản. Key idempotency không phải token xác thực.

## 4. Backend và PostgreSQL

### 4.1. Bản ghi kết quả tạo booking

Dự kiến thêm migration `37-request-idempotency.sql`; kiểm tra lại số migration
khi bắt đầu triển khai để tránh trùng với thay đổi mới.

Bảng do Booking sở hữu: `booking.creation_requests`.

| Trường | Vai trò |
| --- | --- |
| `id`, `customer_id`, `operation`, `idempotency_key` | Định danh và unique key theo người dùng/thao tác |
| `request_hash`, `hash_version`, `hash_key_id` | Phát hiện dùng cùng key với nội dung khác |
| `booking_id` | Tham chiếu booking đã tạo; sinh ID ở server |
| `created_at`, `completed_at` | Đối chiếu và vận hành |
| `retired_at` | Giữ dấu key đã dùng khi tài nguyên bị xóa hợp lệ |

Bản ghi thành công được commit **cùng booking, sync event và reservation ưu
đãi**. Không chỉ ghi key sau khi trả response. Unique index và transaction
là nguồn xác nhận; Redis chỉ có thể làm cache hỗ trợ về sau.

### 4.2. Phối hợp Booking và Promotion trong một transaction

CareSitter hiện dùng các module trong cùng tiến trình và cùng PostgreSQL.
Chọn phối hợp transaction cho bước tạo booking này để tránh bổ sung một
workflow phục hồi liên module phức tạp chỉ để giữ lượt ưu đãi.

1. Xác thực; kiểm tra cấu trúc/key; chuẩn hóa payload.
2. Tra cứu kết quả đã commit. Nếu có, so fingerprint rồi trả đúng booking.
3. Bắt đầu transaction; thử khóa PostgreSQL theo customer/operation/key.
   Nếu chưa lấy được khóa, trả lỗi đang xử lý có thời gian retry.
4. Tra cứu lại trong transaction để bắt trường hợp request khác vừa commit.
5. Kiểm tra điều kiện tạo mới, lấy báo giá và sinh booking ID ở server.
6. Nếu có ưu đãi, reserve bằng chính booking ID đó và cùng transaction.
7. Lưu booking, sync event và `creation_requests`; commit một lần.
8. Map response sau commit. Nếu map/HTTP phản hồi lỗi, lần gửi lại vẫn tìm
   được booking đã commit.

Infrastructure dùng connection/transaction được phối hợp qua một coordinator
chung. Các adapter Booking và Promotion tham gia cùng transaction bằng cơ
chế EF Core phù hợp; Application gọi qua port, không đọc bảng/DbContext của
module khác. Dự kiến port `IBookingCreationTransaction` trong Booking và
adapter tham gia transaction trong Promotion; chốt tên cụ thể khi implement.

`ReserveAsync` hiện tự mở transaction nên phải được sửa để hỗ trợ hai chế
độ rõ ràng: transaction riêng cho lời gọi độc lập, hoặc tham gia transaction
được coordinator cấp. Không mở transaction lồng nhau và không giả định hai
DbContext tự động dùng cùng transaction vì có cùng connection string.

Không giữ transaction qua lời gọi HTTP/provider, SMTP hay Kafka. Báo giá và
lookup cần thiết trong đường ghi phải dùng adapter nội bộ phù hợp; mọi phát
sự kiện bên ngoài đi qua outbox sau commit. Giữ thứ tự khóa nhất quán
request → promotion → các bản ghi booking và xác minh không tạo deadlock
với các luồng hiện có. Constraint chống lịch trùng tiếp tục là chốt bảo vệ
khi hai thao tác **khác key** đặt cùng lịch.

Khi tiến trình chết trước commit, cả booking, reservation và receipt rollback.
Khi chết sau commit, receipt tồn tại để replay. Bước này phải có test chứng
minh rollback thực tế ở cả hai schema, không chỉ test giả lập service.

Nếu sau này tách Promotion sang database/dịch vụ khác, phải thay cơ chế
phối hợp bằng outbox/workflow có ID ổn định, checkpoint và compensation;
không mang giả định một transaction này sang kiến trúc đó.

### 4.3. Hoàn thiện payout

- Giữ unique `(caregiver_id, idempotency_key)` và transaction số dư hiện có.
- Bổ sung fingerprint/version/key ID vào `payments.payout_requests`.
- Khi thấy bản ghi cũ, so payload trước khi trả response. Request thua
  unique race cũng phải so payload với bản ghi thắng; khác payload trả `409`.
- Payout lịch sử chưa có fingerprint: đối chiếu với dữ liệu bất biến gốc,
  gồm số tài khoản được giải mã chỉ trong backend; ghi fingerprint theo
  transaction phù hợp. Không tự coi hash thiếu là cùng payload.
- Chỉ thay đổi số dư khi tạo payout mới. API tra cứu và replay không đổi ví.
- Receipt payout được ghi cùng giao dịch giữ số dư. Lỗi audit sau commit
  không được khiến client tạo payout mới: retry tìm lại receipt, audit thiếu
  cần được sửa thành ghi cùng transaction hoặc outbox có business key.

### 4.4. Thời hạn và lưu trữ

- Không xóa mapping thành công chỉ vì hết TTL cache; giữ mapping tối thiểu
  theo vòng đời tài nguyên và chính sách lưu dữ liệu nghiệp vụ.
- Chỉ lưu fingerprint/ID cần thiết, không lưu bản sao response chứa dữ liệu
  cá nhân. Khi cần xóa dữ liệu, giữ tombstone tối thiểu theo chính sách được
  áp dụng, đồng thời trả `410` cho key đã hết khả năng khôi phục.
- GET `404` không chứng minh request đầu chưa từng chạy nếu migration hoặc
  dữ liệu lịch sử thiếu receipt. Chỉ tự replay các thao tác được tạo bằng
  hợp đồng mới; thao tác legacy chưa rõ phải tra lịch sử hoặc hỗ trợ xử lý.

## 5. Luồng app và trải nghiệm khi mạng lỗi

Giữ giao diện và `AppColors` hiện có. Đây là bổ sung trạng thái cho form đặt
lịch/rút tiền đang dùng; không tạo màn hình kỹ thuật bắt người dùng nhập key.
Người dùng Việt Nam thao tác trên điện thoại khi bận hoặc lo lắng, nên trạng
thái, số tiền và hành động tiếp theo phải dễ đọc, rõ ràng.

### Mã thao tác tồn tại qua retry và mở lại app

- Trước lần POST đầu, lưu `PendingSubmission`: key, owner user ID, loại thao
  tác, payload đã xác nhận, thời điểm và resource ID nếu đã biết.
- Dùng storage bảo vệ phù hợp nền tảng; cả hai app đã có
  `flutter_secure_storage`. Không lưu số tài khoản/payload nhạy cảm vào
  SharedPreferences hoặc log. Bản web cần kiểm tra riêng cơ chế bảo vệ
  storage, không coi localStorage là kho mã hóa an toàn.
- Repository nhận key từ controller; không tự sinh UUID mỗi lần gửi.
- Token refresh, retry thủ công và khôi phục app đều dùng lại key/payload.
- Không cho sửa payload của thao tác đang chưa rõ kết quả rồi gửi với key cũ.
  Trước khi tạo thao tác mới, tra cứu/replay thao tác cũ để xác định kết quả.
- Dữ liệu pending tách theo user ID. Đổi tài khoản không gửi lại thao tác
  của tài khoản trước; logout xóa dữ liệu nhạy cảm trên máy. Đăng nhập lại
  sau logout phải đối chiếu lịch sử backend trước khi lặp thao tác chưa rõ.
- App khôi phục bằng GET submission; có kết quả thì nhận đúng tài nguyên.
  Nếu chưa có receipt của hợp đồng mới, retry POST cùng key/payload.
- Có lỗi mạng/5xx: giữ pending. Lỗi nghiệp vụ rõ ràng và chưa commit: cho
  chỉnh dữ liệu và tạo lần xác nhận mới. Có response thành công: lưu resource
  ID trước khi dọn pending để crash ở bước điều hướng không tạo thao tác mới.

### Trạng thái và nội dung tiếng Việt

| Trạng thái | Hiển thị và hành động |
| --- | --- |
| Sẵn sàng | Form hiện có; xác nhận lịch/chi phí hoặc số tiền/tài khoản |
| Đang gửi | Nút loading, khóa gửi lặp; không xóa dữ liệu đã xác nhận |
| Chưa rõ kết quả | “Chưa xác nhận được kết quả. Bạn có thể kiểm tra hoặc thử lại.”; nút “Kiểm tra kết quả” và “Thử lại” dùng thao tác cũ |
| Server đang xử lý | “Yêu cầu đang được xử lý”; retry theo `Retry-After`, tránh vòng lặp liên tục |
| Đã tạo booking | Điều hướng đến đúng booking ID; không hiển thị booking thứ hai |
| Đã tạo payout | “Đã tạo yêu cầu rút tiền”; thể hiện trạng thái chờ xử lý, không nói tiền đã vào ngân hàng |
| Khác payload | Giải thích thông tin đã thay đổi; khôi phục kết quả cũ trước khi xác nhận thao tác mới |
| Lỗi nghiệp vụ rõ ràng | Hiển thị lỗi cụ thể: lịch trùng, ưu đãi không còn hợp lệ hoặc số dư không đủ |

Controller rút tiền đổi từ `bool` sang kết quả có ID/trạng thái và loại lỗi.
Sau tạo/replay thành công, lấy số dư và lịch sử từ backend; merge theo payout
ID. Không luôn trừ số dư local hoặc thêm một giao dịch mới mỗi lần nhận `200`.
Lỗi refresh ví sau khi đã nhận payout thành công chỉ là lỗi tải lại ví,
không đổi kết quả thao tác thành thất bại.

Booking controller cũng merge theo booking ID; nếu các bước tiếp theo như
chọn caregiver/thanh toán lỗi, vẫn giữ booking đã tạo và tiếp tục trên ID đó.
Không khởi động lại POST tạo booking chỉ vì một bước sau bị lỗi.

Kiểm tra form ở 320/430/1024 px, chữ phóng lớn, bàn phím và screen reader;
nút chạm tối thiểu 44 px, thông báo trạng thái không chỉ dựa vào màu.

## 6. Các giai đoạn triển khai

| Giai đoạn | Công việc | Đầu ra nghiệm thu |
| --- | --- | --- |
| P1 — Hợp đồng và migration | DTO/header, fingerprint version, error codes, bảng booking receipt, cột payout, kế hoạch nâng cấp dữ liệu cũ | Migration chạy trên DB sạch và DB có dữ liệu; mẫu request/response thống nhất |
| P2 — Booking và ưu đãi | Port/coordinator transaction, replay trước kiểm tra tạo mới, receipt và reservation atomic, API tra cứu | Cùng key tạo đúng một booking/sync event/reservation; crash không để orphan mới |
| P3 — Payout | So payload, xử lý header/body, legacy fingerprint, API tra cứu, audit transaction/outbox | Cùng key chỉ giữ tiền một lần; khác payload bị từ chối cả khi race |
| P4 — Hai app | Pending store, key ổn định, kết quả có kiểu, phục hồi/mạng lỗi, copy rút tiền đúng trạng thái | Retry/restart dùng cùng key; một booking/payout trong UI; ví khớp backend |
| P5 — Kiểm thử và rollout | PostgreSQL/HTTP/race/crash, Flutter/browser/device, cấu hình local, tài liệu và quan sát | Bằng chứng kiểm thử đủ phạm vi; contract bắt buộc key bật theo đợt phát hành |

P2 và P3 phụ thuộc P1. P4 bắt đầu sau khi hợp đồng P1 ổn định và nghiệm thu
cùng P2/P3. P5 là điều kiện hoàn thành, không bỏ qua vì đã thấy API trả `200`.

## 7. Kiểm thử bắt buộc

| Nhóm | Kịch bản và kết quả cần chứng minh |
| --- | --- |
| Booking replay | Cùng key gửi lần lượt: cùng ID; 1 booking, 1 event Created, 1 reservation nếu có |
| Booking đồng thời | 20 request cùng key/payload qua ít nhất 2 ApiHost: 1 lần commit; request còn lại replay hoặc báo đang xử lý |
| Payload khác | Cùng key đổi lịch/beneficiary/promotion/amount/bank account: `409`; không có tác động mới |
| Khác key, trùng lịch | Constraint/trigger lịch vẫn chặn; lỗi được map thành lỗi nghiệp vụ, không thành 500 |
| Phản hồi bị mất | Commit thành công rồi ngắt HTTP; retry/GET trả tài nguyên cũ |
| Crash trước commit | Dừng tiến trình sau reserve ưu đãi, trước lưu/commit booking: cả hai schema rollback; retry có thể hoàn thành |
| Crash sau commit | Dừng tiến trình trước trả response: booking/payout/receipt tồn tại; retry không đổi tiền/quota |
| Mapping lỗi | Mapper/lookup response lỗi sau commit: lần sau phục hồi đúng ID |
| Payout race | Cùng key chỉ giữ số dư một lần; hai payload khác cùng key chỉ có một yêu cầu thắng |
| Payout lịch sử | Key cũ không có fingerprint vẫn replay đúng nội dung; nội dung khác bị chặn; không lộ số tài khoản |
| Ownership/auth | Cùng key khác user không đọc được kết quả của nhau; hết phiên phải đăng nhập; replay vẫn kiểm tra quyền |
| Điều kiện thay đổi | Retry sau số dư giảm, lịch đã qua hoặc promotion tắt vẫn trả kết quả đã commit; không tạo mới |
| App | Double tap, timeout, 401 refresh, offline/reconnect, force close, quay lại form, logout/đổi tài khoản |
| Ví và điều hướng | Response replay không trừ số dư hiển thị thêm; lỗi tải ví/bước sau booking không biến thao tác thành tạo mới |
| Dữ liệu và khóa | HMAC rotation, dữ liệu legacy, mapping retired, lỗi storage và lock timeout |

Tái sử dụng `PostgresRaceTestDatabase` và các test payment/booking hiện có;
không chạy kịch bản race bằng EF InMemory thay cho PostgreSQL. Dùng fault
injection ở đúng điểm commit/reserve/response; không gửi tiền thật để kiểm
thử idempotency của yêu cầu nội bộ.

Các bước kiểm tra: unit fingerprint/contract; integration HTTP + PostgreSQL;
architecture tests bảo vệ ranh giới module; Flutter controller/repository và
widget tests; build/static analysis; browser và thiết bị thật cho vòng đời
app/storage. Ghi rõ kiểm thử nào dùng fixture và kiểm thử nào dùng DB thật.

## 8. Rollout và vận hành

1. Áp dụng migration cộng thêm; giữ dữ liệu booking, payout, ledger và key cũ.
2. Phát hành backend nhận hợp đồng mới và xử lý replay trước; dùng cấu hình
   `Idempotency:RequireBookingKey` cho thời gian chuyển tiếp app cũ.
3. Phát hành customer/caregiver app giữ pending; kiểm tra local và staging.
4. Bật bắt buộc key sau khi client phù hợp đã phát hành/được nâng cấp theo
   chính sách phiên bản app. Request thiếu key trong giai đoạn tương thích
   vẫn có ràng buộc lịch nhưng chưa có bảo đảm replay của hợp đồng mới.
5. Theo dõi số replay, mismatch, in-progress, lỗi transaction và thời gian
   khóa; thử phục hồi mất phản hồi/restart trước khi nghiệm thu production.

Metrics không dùng key, user ID hoặc số tài khoản làm label. Log có request
correlation và resource ID phù hợp quyền truy cập; không ghi payload nhạy cảm.

Rollback phải giữ schema và khả năng nhận ra key đã commit. Không quay về
binary tạo mới mà bỏ qua receipt, vì có thể phá bảo đảm của request đang
retry. Nếu cần rollback khẩn cấp, tạm dừng endpoint tạo mới hoặc dùng bản
rollback đã giữ hỗ trợ idempotency; ưu tiên sửa tiếp trên schema cộng thêm.

## 9. Điều kiện hoàn thành

- [ ] Backend và cả hai app dùng cùng hợp đồng key/payload/result.
- [ ] Cùng key không tạo thêm booking, payout, giữ tiền hoặc giữ lượt ưu đãi.
- [ ] Cùng key khác nội dung luôn bị từ chối, kể cả khi gửi đồng thời.
- [ ] Booking + Promotion + receipt rollback/commit cùng nhau trong DB thật.
- [ ] Mất phản hồi và mở lại app phục hồi được kết quả đã commit.
- [ ] UI không trừ số dư lặp, không tạo mới vì bước sau thất bại và mô tả payout đúng trạng thái.
- [ ] Migration nâng cấp, dữ liệu payout cũ, key rotation và rollback được kiểm tra.
- [ ] Kiểm thử liên quan, build/analyze và ranh giới module đạt; có evidence.
- [ ] Báo cáo chức năng và kiến trúc cập nhật sau triển khai; ghi riêng local/staging/production.

## 10. Tài liệu kỹ thuật tham chiếu

Chính sách key, trạng thái HTTP, lưu trữ và replay phía trên là thiết kế đề
xuất cho CareSitter, không phải hợp đồng bắt buộc của nhà cung cấp thanh toán.

- [PostgreSQL: khóa dòng, advisory lock và deadlock](https://www.postgresql.org/docs/current/explicit-locking.html):
  cơ sở cho việc tuần tự hóa request và giải phóng khóa theo transaction.
- [EF Core: transaction giữa nhiều DbContext](https://learn.microsoft.com/en-us/ef/core/saving/transactions#cross-context-transaction):
  cần dùng chung cả connection và transaction; phải đọc và kiểm tra với phiên bản repo khi implement.
- [Stripe: idempotent requests](https://docs.stripe.com/api/idempotent_requests):
  tham khảo việc dùng key cho retry và đối chiếu tham số. CareSitter chọn trả
  tài nguyên hiện tại, không sao chép cơ chế cache nguyên response của Stripe.
