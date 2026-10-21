# Quy ước code, tài liệu và quản lý secret — CareSitter

> Cập nhật: 19/10/2026. Dựa trên bản quy ước được gửi và cấu trúc source hiện tại.
> Đây là quy tắc cho thay đổi mới và tiêu chí rà soát code cũ; không phải chứng nhận toàn bộ dự án đã tuân thủ.
> Các đường dẫn source và lệnh bên dưới tính từ thư mục repository `CareSitter`, trừ khi ghi rõ khác.

## 0. Rule bắt buộc trước khi code

- [AGENTS.md ở gốc repository](../AGENTS.md) yêu cầu đọc **toàn bộ tài liệu này trong tác vụ hiện tại trước khi viết/sửa code, cấu hình, migration hoặc test**. Không chỉ dựa vào trí nhớ hoặc bản tóm tắt từ tác vụ trước; đọc lại nếu nội dung thay đổi.
- [AGENTS.md ở workspace](../../AGENTS.md) dẫn vào rule repository khi bắt đầu làm việc từ `D:\EXE`. Thư mục con có `AGENTS.md` áp dụng thêm hướng dẫn riêng của phần đó.
- Rule điều khiển công cụ là ngoại lệ của việc gom tài liệu vào `plan/`; giữ đúng vị trí tự tìm. Nếu quy ước bị thiếu/không đọc được, khôi phục tham chiếu trước khi sửa source.
- Yêu cầu rõ của người dùng được ưu tiên hơn hướng dẫn trong các file rule. Không dùng rule để hỏi lại quyền cho việc đã được cho phép.

## 1. Tổ chức tài liệu Markdown

- Tài liệu dự án tập trung trong **`plan/`**, dùng tên này thay cho việc tạo thêm `plans/` hoặc rải Markdown cạnh source.
- Bắt đầu từ [mục lục](README.md). [Kiến trúc](tong-quan/ARCHITECTURE.md) mô tả hệ thống; [báo cáo chức năng](tong-quan/BAOCAO_CHUC_NANG.md) phân biệt phần đã có và chưa có.
- Tài liệu mới, phần giải thích và cập nhật viết bằng **tiếng Việt**. Giữ nguyên tên class, API, biến môi trường, mã lỗi và lệnh.
- Nhóm tài liệu theo `tong-quan/`, `backend/`, `frontend/`, `deploy/`, `docs/`, `bao-cao/`, `kiem-thu/` và thư mục kế hoạch từng tính năng. Không dùng nhiều bản khác nhau làm nguồn chuẩn cho cùng một quy tắc.
- Mỗi kế hoạch/báo cáo có ngày cập nhật, phạm vi, trạng thái thực tế, việc còn lại và cách kiểm chứng. Ghi rõ “đã có code”, “đã test local” hay “đã chạy production”; không đánh dấu hoàn thành chỉ vì đã viết kế hoạch.
- Liên kết Markdown dùng đường dẫn tương đối từ chính tài liệu. Khi di chuyển/đổi tên phải sửa cả mục lục, liên kết, ảnh và hướng dẫn tham chiếu. Đường dẫn source trong code block phải nói rõ thư mục gốc dùng để chạy lệnh.
- Ngoại lệ: `AGENTS.md`, `CLAUDE.md`, `SKILL.md` và tệp hướng dẫn mà công cụ cần tự tìm giữ đúng vị trí công cụ yêu cầu. Markdown trong dependency, build, snapshot và bản sao kiểm thử thuộc vòng đời của chúng, không gom vào tài liệu nguồn.
- **Theo yêu cầu hiện tại, Markdown chỉ lưu local; không commit/push, kể cả xóa/đổi tên Markdown đã tracked, nếu chưa được yêu cầu riêng.** `plan/` được ignore. Không dùng `git add .`/`git add -A` để gom lẫn thay đổi tài liệu và source; phải xem danh sách staged trước khi commit.

## 2. Backend .NET: cấu trúc và ranh giới

Backend dùng .NET 8, Modular Monolith và tổ chức các tầng trong từng module. Tên thư mục thực tế:

```text
backend/
├── CareSitter.sln
├── caresitter-be/
│   ├── ApiHost/                         # composition root, API dùng chung
│   ├── Modules/
│   │   └── <Module>/                    # Identity, People, Catalog, Booking,
│   │       ├── Domain/                  # Payments, Support, Promotion
│   │       ├── Application/
│   │       ├── Infrastructure/
│   │       └── Controllers/
│   ├── Shared/
│   │   ├── CareSitter.SharedKernel/
│   │   ├── CareSitter.Contracts/
│   │   ├── CareSitter.Infrastructure/
│   │   ├── CareSitter.Messaging.Contracts/
│   │   ├── CareSitter.Messaging.Abstractions/
│   │   ├── CareSitter.Messaging.Kafka/
│   │   └── CareSitter.Messaging.Persistence/
│   └── Services/NotificationWorker/
├── init-db/                             # nguồn schema SQL
├── scripts/
├── tests/
├── docker-compose.yml
├── .env.example                         # mẫu không chứa secret thật
└── .env                                 # cấu hình local, không đưa lên Git
```

| Tầng | Phụ thuộc được phép | Quy tắc |
| --- | --- | --- |
| Domain | SharedKernel, kiểu thuần nghiệp vụ | Không phụ thuộc EF, HTTP, Controller hoặc implementation hạ tầng |
| Application | Domain, hợp đồng/port công khai cần thiết | Điều phối use case; không khởi tạo implementation DB/HTTP |
| Infrastructure | Domain, Application, adapter/hạ tầng chung | Thực thi port, truy cập DB và dịch vụ ngoài |
| Controllers | Application và framework HTTP | Nhận request, gọi use case, chuyển kết quả sang HTTP |
| ApiHost | Module và hạ tầng cần đăng ký | Nối dependency và cấu hình; không là nơi nhét nghiệp vụ |

- Module không gọi class nội bộ, `DbContext` hoặc bảng của module khác để bỏ qua nghiệp vụ. Giao tiếp qua `CareSitter.Contracts`/port công khai và integration event được công bố.
- Domain event nội bộ và integration event qua Kafka có vòng đời khác nhau; không coi MediatR event là thông điệp đã lưu bền.
- Entity bảo vệ trạng thái bằng phương thức nghiệp vụ và setter có phạm vi phù hợp. Use case kiểm tra quyền và điều phối; Controller không quyết định số tiền/trạng thái booking.
- Input/output là DTO; không serialize EF entity/tracking object ra API. Validate dữ liệu ở Application; validation HTTP chỉ hỗ trợ kiểm tra định dạng.
- I/O dùng `async/await`, truyền `CancellationToken`; tránh `.Result`/`.Wait()`. Không bỏ tác vụ nền không được quản lý.
- Transaction, row/advisory lock và retry đặt ở Store/Repository hoặc adapter tương ứng. Comment nêu bất biến được bảo vệ, phạm vi khóa và lý do cần retry.
- Không nuốt lỗi. Dùng `ILogger`, thông báo có mã lỗi/ngữ cảnh và correlation ID khi cần; không in credential, OTP, token, nội dung KYC hay tọa độ cá nhân vào log thông thường.
- Thời điểm lưu/truyền theo UTC với offset rõ ràng. Khi hiển thị và xử lý lịch theo giờ Việt Nam phải chuyển múi giờ đúng một lần; khoảng cách dùng đơn vị rõ ràng.
- Giới hạn nghiệp vụ đưa vào cấu hình/hằng số có tên; thay đổi phải xét cả API, background job và app.

### Đặt tên và giữ hợp đồng

| Thành phần | Quy ước |
| --- | --- |
| Class, method, property C# | PascalCase |
| Biến cục bộ/tham số | camelCase |
| Field private | `_camelCase` |
| Interface | `I...` |
| Phương thức bất đồng bộ mới | Hậu tố `Async`, theo chữ ký framework khi có yêu cầu riêng |
| DTO | Hậu tố `Request`, `Response` hoặc `Dto` |
| Event | Tên diễn tả việc đã xảy ra, ví dụ `PaymentSucceeded` |
| Giá trị DB/JSON | Theo codec/hợp đồng hiện hữu; không tự đổi casing |

Booking đang dùng `lower_snake_case` trong API; một số trạng thái tác vụ dùng chữ hoa. Không đổi tất cả sang `UPPER_SNAKE` bằng một quy tắc đặt tên. Thay đổi giá trị trên dây phải có tương thích hoặc phiên bản mới và cập nhật model/test phía client.

## 3. API, quyền truy cập và nghiệp vụ nhạy cảm

- API mới theo `api/v1/<tai-nguyen>`, tài nguyên viết thường, dùng danh từ và gạch ngang khi cần. Giữ tương thích với endpoint hiện có.
- Mặc định yêu cầu đăng nhập. Endpoint công khai phải được khai báo rõ, có cơ chế xác thực/giới hạn phù hợp riêng cho OTP, OAuth và webhook.
- Kiểm tra **role và quyền sở hữu dữ liệu** trên server cho từng booking, hồ sơ, tranh chấp, file KYC và nhóm realtime. Ẩn nút ở UI không thay thế authorization.
- Không tin `customerId`/`caregiverId`, giá tiền, trạng thái thanh toán hoặc quyền do client gửi. Lấy danh tính từ phiên được xác thực và đối chiếu bản ghi nghiệp vụ.
- Truy vấn danh sách có phân trang, giới hạn kích thước và trường sort/filter được cho phép. Không trả dữ liệu nhạy cảm ngoài phạm vi tài khoản.
- Giữ mã lỗi/hình dạng response nhất quán với client. Không trả stack trace, SQL hay thông tin provider nội bộ cho người dùng; UI có loading, rỗng, lỗi và thao tác thử lại phù hợp.
- File upload kiểm tra kích thước, loại nội dung và quyền đọc; KYC dùng đường dẫn được cấp quyền có thời hạn, không biến file riêng tư thành URL public.

### Thanh toán và idempotency

- Tiền tính trên server bằng kiểu tiền/số nguyên hoặc `decimal` phù hợp hợp đồng, không dùng số thực dấu phẩy động cho cộng/trừ tiền. Ghi rõ VND, quy tắc làm tròn và phí.
- Chặn bấm lặp khi loading trên UI, đồng thời bảo vệ ở server bằng khóa idempotency, unique constraint, transaction/lock và state transition có điều kiện cho từng nghiệp vụ. Chặn nút riêng lẻ không đủ chống request đồng thời hoặc retry.
- Cùng khóa, cùng tài khoản và cùng payload phải trả lại kết quả cũ; cùng khóa nhưng payload khác phải bị từ chối. Giới hạn scope, thời gian lưu và quy tắc retry phải được định nghĩa trong use case.
- Tạo link, nhận webhook, finalize booking, giữ/hoàn tiền, settlement và payout phải chịu được lặp/chạy lại mà không ghi tiền hai lần. Kiểm thử concurrent request trên PostgreSQL thật khi dựa vào constraint/lock.
- **Không báo thanh toán thành công dựa vào return URL, query string hoặc app quay về màn hình.** Đối chiếu trạng thái từ backend/provider, chữ ký, mã đơn, số tiền và trạng thái hiện tại.
- Webhook xác thực chữ ký và validate payload trước; chỉ báo nhận thành công sau khi kết quả đã được lưu bền/commit. Sự kiện hợp lệ đã xử lý được ACK an toàn. Chữ ký sai/request sai không được trả thành công vô điều kiện; lỗi tạm thời dùng response phù hợp cơ chế retry của provider.
- Xử lý nặng có thể chuyển sang job sau khi đã ghi bền qua outbox/inbox. Không trả `200` rồi mới lưu bằng tác vụ dễ mất khi process dừng.
- Đối soát xử lý timeout/mất callback/trạng thái chưa rõ trước khi cho tạo giao dịch khác. Ledger, trạng thái nghiệp vụ và side effect phải có cách phục hồi khi lỗi giữa các bước.
- Booking hết giờ không tự coi là đã hoàn tất để giải ngân nếu chưa thỏa điều kiện nghiệp vụ. Quy trình quá hạn phải tách khỏi xác nhận thực hiện ca và xử lý tranh chấp.

### OTP, khôi phục mật khẩu và phiên đăng nhập

- Không tiết lộ email có tồn tại qua response công khai; giới hạn gửi lại, số lần thử và thời hạn mã. Không lưu/log OTP dạng rõ trong cơ chế lưu lâu dài.
- Mã khôi phục dùng đúng mục đích, dùng một lần và không thay thế mã đăng nhập/đăng ký. Đổi mật khẩu thành công phải thu hồi mọi phiên cũ theo cơ chế phiên của backend.
- Tài khoản bị admin khóa cần quy trình xét duyệt riêng; reset mật khẩu không tự mở khóa hoặc gỡ quyết định admin.
- Refresh token hết hạn/được thu hồi phải dẫn đến kết thúc phiên và dọn subscription liên quan. Tránh nhiều request cùng thực hiện refresh cạnh tranh.

## 4. Kafka, realtime và vị trí

- Integration event có event ID, loại và phiên bản schema ổn định, thời điểm, correlation và khóa phân vùng phù hợp. Consumer phải xử lý lặp; không giả định broker đảm bảo nghiệp vụ chỉ chạy đúng một lần.
- Khi dùng outbox, ghi event cùng transaction với thay đổi nghiệp vụ thuộc cùng DB. Inbox/unique key bảo vệ consumer; chỉ ACK/commit offset sau mức xử lý đã được bảo đảm theo thiết kế.
- Retry có giới hạn/backoff, phân biệt lỗi tạm thời và lỗi dữ liệu. Có DLQ, cách quan sát backlog và quy trình replay; replay không được ghi tiền/gửi thông báo sai thêm lần nữa.
- Không nhét secret, OTP hoặc hồ sơ nhạy cảm vào payload sự kiện chung. Dịch vụ nội bộ phải có xác thực, không chỉ dựa vào URL khó đoán.
- SignalR phải kiểm tra người dùng được vào group. GPS chỉ gửi cho bên được quyền theo booking còn hợp lệ; rời nhóm/ngừng gửi khi đổi tài khoản, kết thúc hoặc mất quyền.
- Màn hình hủy subscription, timer, stream và membership do nó tạo. **Không gọi stop kết nối SignalR dùng chung từ một màn hình**; service quản lý lifecycle/ref-count/reconnect và vào lại nhóm.
- GPS kiểm tra khoảng giá trị lat/lng, timestamp, độ cũ và trạng thái ca. UI thể hiện vị trí cũ/mất kết nối; polling có giới hạn. Không tự dùng tọa độ demo khi thiếu quyền hoặc chưa có dữ liệu thật.
- Phân biệt tracking khi app đang mở với background tracking. Chỉ báo hỗ trợ nền khi đã có quyền, triển khai và test trên thiết bị thật; định nghĩa chính sách lưu/xóa dữ liệu vị trí trước production.
- Bản đồ dùng **CARTO làm luồng chính**, Google Maps là tùy chọn có cấu hình rõ. Giữ attribution; theo dõi hạn mức nhà cung cấp. Không tuyên bố tất cả dịch vụ bản đồ miễn phí hoặc token nào cũng dùng được cho Basemaps.

## 5. Flutter và giao diện web

### Hai app Flutter

```text
frontend/<customer-app|caregiver-app>/lib/
├── core/                       # config, theme, network, router, realtime, maps
└── features/<feature>/
    ├── data/                   # model, datasource, repository
    ├── domain/                 # khi tính năng cần tầng này
    └── presentation/           # screen, widget, state/provider
```

- Theo feature-first và Riverpod hiện có. UI gọi repository/service qua state quản lý use case; không tự ghép HTTP hoặc nhúng nghiệp vụ server vào widget.
- Không import presentation của feature khác để dùng lại logic; chuyển hợp đồng/widget dùng chung về chỗ phù hợp. File `snake_case.dart`, class `PascalCase`.
- Model khớp DTO, xử lý null/enum chưa biết có chủ đích; thay DTO phải cập nhật hai app/admin liên quan trong cùng thay đổi.
- Mỗi thao tác bất đồng bộ kiểm tra lifecycle trước khi cập nhật UI; hủy tài nguyên do màn hình sở hữu. Retry request ghi dữ liệu cần cùng idempotency key của lần thao tác tương ứng.
- Dữ liệu hiển thị thuộc tài khoản đăng nhập. Mock/demo chỉ trong luồng test/debug rõ ràng, không thay dữ liệu production khi API lỗi.
- Tái sử dụng theme/tokens; trạng thái loading, lỗi, rỗng, mất mạng và quyền vị trí bị từ chối phải có thông báo tiếng Việt. Kiểm tra màn hình nhỏ, text scale và nhãn trợ năng cho thao tác chính.
- Email giao dịch dùng màu xanh chủ đạo hiện có và **không dùng gradient**, theo yêu cầu giao diện của dự án.
- Token phiên trên mobile lưu qua secure storage, không lưu SharedPreferences/file cấu hình. Trên web, không coi storage phía client là kho bí mật; hạn chế XSS và quyền truy cập token theo cơ chế đăng nhập đã chọn.

### Admin web và landing page

- Admin dùng React/TypeScript/Vite. Gọi API qua lớp `src/api.ts`, DTO qua `src/types.ts`; không rải URL/token/ép kiểu `any` để bỏ qua lỗi hợp đồng.
- Khóa nút khi request đang chạy, giữ draft khi lỗi, xác nhận thao tác phá hủy, hiển thị lỗi nghiệp vụ có thể xử lý. Server vẫn phải kiểm tra quyền và chống request lặp.
- Landing page dùng Next.js: giữ ranh giới client/server; credential của endpoint AI/email chỉ nằm ở server. Biến `VITE_*` và `NEXT_PUBLIC_*` được đưa ra client, không chứa backend secret.
- Giữ lockfile, theo phiên bản SDK/runtime đã pin trong `global.json`, CI và manifest. Không nâng dependency lớn chỉ để sửa tài liệu/UI nhỏ.

## 6. Migration và dữ liệu

- **Nguồn schema duy nhất là `backend/init-db/*.sql`**. EF Core phục vụ mapping/query; không chạy `dotnet ef migrations add/database update`, `Database.Migrate` hoặc `EnsureCreated` cho DB này.
- SQL mới dùng số thứ tự tiếp theo, tên rõ nghĩa; không sửa migration đã áp dụng. Đồng bộ mapping, DTO và test chịu ảnh hưởng. Chi tiết: [quy trình migration](backend/docs/MIGRATIONS.md).
- DB mới bootstrap bằng init SQL; DB đã có dữ liệu nâng cấp bằng `backend/scripts/update-db.ps1` với đích và mốc phù hợp. Restart Docker không tự nâng cấp volume cũ.
- Không coi script trả thành công là tất cả migration đã được áp dụng. Đối chiếu schema/checksum; chỉ một runner thay schema hoạt động tại một thời điểm.
- Ưu tiên expand/contract, backfill có kiểm soát và rollback code tương thích schema. Migration phá hủy/reset/restore dữ liệu thật cần runbook, backup đã diễn tập phục hồi và xác nhận đúng môi trường.
- Archive EF cũ vẫn nằm ở `backend/docs/legacy-ef-migrations/identity/`; chỉ Markdown mô tả archive chuyển vào `plan/`. Không di chuyển/biên dịch/chạy lại source archive khi dọn tài liệu.

## 7. Secret và cấu hình theo môi trường

### Phân loại

| Loại | Cách xử lý |
| --- | --- |
| Mật khẩu DB, JWT signing key, encryption key, OAuth client secret | Chỉ phía server, kho secret/env riêng theo môi trường |
| Credential payOS/VNPAY, SMTP, storage, FCM service account, khóa gọi dịch vụ nội bộ/tunnel | Chỉ backend/worker; không đưa vào Flutter hoặc JS bundle |
| Google Routes/Geocoding key phía server | Backend giữ và giới hạn theo API/môi trường |
| Google Maps SDK key, CARTO Basemaps client token | Cấu hình build local; có thể bị đọc từ app/Web, không coi là server secret |
| Firebase client config/OAuth client ID, URL API/hub, feature flag | Cấu hình client; không thay thế authorization |

- Không đưa secret vào source, Markdown, ảnh/log kiểm thử, PR hay chat. Ví dụ chỉ dùng placeholder; bản env thật không đưa lên Git.
- Dev/staging/production dùng credential riêng, quyền tối thiểu và endpoint riêng. Feature tắt không được tự bật chỉ vì tìm thấy key; feature bật phải kiểm tra đầy đủ cấu hình bắt buộc.
- APK/IPA/Web và `--dart-define` có thể bị trích xuất. `.env.local` bị ignore chỉ ngăn commit nhầm, không giấu được dữ liệu đã bundle.
- Maps SDK key giới hạn đúng nền tảng/package + SHA-1/bundle ID/website và API cần dùng. Với CARTO, dùng đúng token Basemaps và giới hạn ứng dụng/origin nếu dịch vụ hỗ trợ; kiểm tra hoạt động thực tế trên web/mobile và theo dõi usage. Không suy diễn token hợp lệ chỉ vì HTTP `200`: tile có thể là ảnh báo lỗi.
- Firebase client config khác với JSON service account chứa private key. Không coi client API key là quyền truy cập dữ liệu; quyền phải được bảo vệ bằng backend/Firebase rules tương ứng.

### Tên cấu hình backend thực tế

.NET dùng `__` thay cho `:` trong biến môi trường. Dự án đang đọc các tên sau; không dùng tên mẫu khác làm cấu hình chạy thật:

```dotenv
ConnectionStrings__CareSitter=
Jwt__SecretKey=
Payments__PayOS__Enabled=false
Payments__PayOS__ClientId=
Payments__PayOS__ApiKey=
Payments__PayOS__ChecksumKey=
Payments__PayOS__ReturnUrl=https://api.example.com/api/v1/payments/payos/return
Payments__PayOS__CancelUrl=https://api.example.com/api/v1/payments/payos/cancel
Payments__PayOS__CustomerWebUrl=
```

- API hiện gọi `DotNetEnv.Env.TraversePath().Load()` trước khi tạo builder. Đây là loader riêng của dự án; .NET không mặc định tự đọc `.env`. Chọn đúng working directory và kiểm tra file được nạp; không giả định một worker/script khác cũng nạp giống API.
- Khi chạy backend qua AppHost local, cấu hình theo máy và secret đặt trong `backend/.env` (file local bị ignore). `CareSitter.AppHost/LocalConfiguration.cs` đọc file này, đổi dấu `__` thành `:` và dùng làm fallback; biến môi trường của process có ưu tiên cao hơn. Không thêm key hoặc giá trị local của máy vào `appsettings.json`, `appsettings.Development.json` hay `appsettings.Development.Local.json`. Appsettings chỉ giữ mặc định an toàn/không bí mật; các `Parameters` do AppHost tự sinh là cơ chế riêng của Aspire.
- Cấu hình HealthParser local bằng đúng tên biến backend, ví dụ:

  ```dotenv
  HealthParser__Enabled=true
  HealthParser__ApiKey=<OPENAI_API_KEY>
  HealthParser__DataProcessingApproved=false
  ```

  Chỉ đặt `HealthParser__DataProcessingApproved=true` sau khi dữ liệu được phép gửi cho provider theo chính sách/đồng ý áp dụng. AppHost chỉ chuyển API key vào tiến trình Nutrition khi HealthParser được bật; không đưa key vào app Flutter, `.env` frontend, mẫu env có tracking, log hoặc chat. Sau khi đổi cấu hình, khởi động lại AppHost.
- Options bind theo section thực tế, validate khi khởi động. payOS dùng `Payments:PayOS`; `PayOSOptions.IsValid` chỉ yêu cầu credential/URL HTTPS khi `Enabled=true`.
- `appsettings.json`/`appsettings.Development.json` tracked chỉ chứa cấu hình public/placeholder. Có thể dùng .NET User Secrets khi project đã cấu hình `UserSecretsId`; không chạy lệnh ví dụ rồi cho rằng API tự nạp khi chưa thiết lập.
- Docker Compose `.env`/`--env-file` phục vụ nội suy `${...}`; `env_file` trong service mới đưa giá trị vào container. Một file không tự làm được cả hai nếu chưa được cấu hình tương ứng.
- Backend trong container gọi dependency bằng tên service và cổng nội bộ. App trên điện thoại không dùng `localhost` để gọi máy tính: dùng IP LAN hoặc domain HTTPS. Android Emulator dùng địa chỉ host thích hợp; API và hub phải cùng môi trường.
- Production không public DB/Redis; lưu secret bên ngoài image/repo, giới hạn quyền file và quyền truy cập của container.

### Cấu hình Flutter đang dùng

Tạo `frontend/<app>/.env.local` từ mẫu tương ứng và chạy trong thư mục app:

```dotenv
BASE_URL=https://api.example.com/api/v1
HUB_BASE_URL=https://api.example.com
MAP_PROVIDER=carto
CARTO_API_KEY=<TOKEN_BASEMAPS_DANH_CHO_CLIENT>
```

```powershell
flutter run --dart-define-from-file=.env.local
```

- `BASE_URL` và `HUB_BASE_URL` là tên thực tế; không thay bằng `API_BASE_URL` rồi mong config hiện tại đọc được.
- Customer ưu tiên dart-define cho cấu hình Maps/OAuth, có fallback từ `.env` public được bundle. **Không ghi secret thật vào `.env` public/asset của customer app.** URL API/hub vẫn đọc theo dart-define tương ứng.
- Caregiver đọc cấu hình qua dart-define, không tự load `.env.local` lúc runtime. Chỉ tạo file mà không truyền `--dart-define-from-file` không làm app đổi cấu hình.
- `maps.local.json` dùng cho cấu hình client Google tùy chọn; không chứa khóa server. Customer chọn `MAP_PROVIDER=google` mới dùng SDK Google; caregiver hiện dùng CARTO/OSM cho bản đồ trong app.
- `.env.example`, `.env.local.example`, `maps.local.example.json` chỉ là mẫu; phải được cập nhật cùng tên biến mới và không có token thật.

### Gitignore và vận hành credential

- Ignore env thật, `*.local.json`, file signing/certificate (`*.jks`, `*.keystore`, `*.p12`, `*.pfx`), service account, build và log chứa dữ liệu nhạy cảm. Mẫu cấu hình phải có ngoại lệ rõ để có thể theo dõi theo nhu cầu.
- `.gitignore` **không bỏ tracking file đã tracked**. Kiểm tra `git ls-files`/staged diff theo tên file; nếu có credential thật thì xử lý tracking và sự cố riêng, không chỉ thêm ignore.
- Nếu credential bị lộ: thu hồi/tạo lại key, cập nhật môi trường bị ảnh hưởng và kiểm chứng; dọn lịch sử Git phối hợp riêng nếu cần. Xóa chuỗi ở commit mới không vô hiệu key cũ.
- Không xoay JWT/encryption key mù: xác định ảnh hưởng phiên và dữ liệu mã hóa, có lộ trình đổi key. Không thực hiện việc này chỉ vì đang chỉnh tài liệu.
- Onboarding lấy giá trị qua kênh riêng/kho secret; backup secret có kiểm soát riêng, không chép vào repo. Ghi người sở hữu, nơi dùng và ngày/điều kiện cần xoay; không ghi giá trị vào bảng theo dõi.

## 8. Kiểm chứng, Git và phát hành

- Nhánh hiện dùng `main` ổn định, `develop` tích hợp, `feature/<ten>`/`fix/<ten>` cho thay đổi. Commit tập trung một việc, dạng `feat:`, `fix:`, `refactor:`, `docs:` hoặc `chore:`.
- Không gộp thay đổi của người khác, dữ liệu local, env, build hoặc Markdown vào commit source. Không force push, merge hoặc deploy khi chưa có yêu cầu/phạm vi đã được chấp thuận.
- Kiểm thử theo rủi ro: đổi quyền, tiền, state machine, OTP, retry hoặc transaction cần regression cho ca sai/lặp/đồng thời. Sửa tài liệu cần kiểm tra nội dung và liên kết; không chạy lại toàn bộ suite chỉ để di chuyển Markdown.
- Test skip không tính là pass. `dotnet test` thông thường chưa đủ kiểm chứng PostgreSQL nếu thiếu cấu hình test DB. Xem [hướng dẫn PostgreSQL](backend/tests/POSTGRESQL_TESTS.md).
- SDK/version lấy theo `global.json`, CI và lockfile; kết quả test ghi rõ ngày, lệnh, môi trường, số pass/fail/skip và phạm vi chưa kiểm chứng. CI hiện có backend baseline, Flutter analyze/test và admin test/build; không coi đó là nghiệm thu ngân hàng hay iOS thật.

| Thay đổi | Kiểm tra phù hợp, chạy tại thư mục được nêu |
| --- | --- |
| Backend | Từ repo: `dotnet test backend/CareSitter.sln --nologo`, hoặc project/suite chịu tác động |
| Tiền/lock/concurrency | Từ repo: `./backend/scripts/test-races.ps1 -Repeat 3`, dùng DB/container test tạm |
| Baseline/migration | Từ repo: `./backend/scripts/test-phase7.ps1 -Repeat 2 -SkipFrontend`, đọc phạm vi runner trước khi chạy |
| Customer/caregiver | Trong từng app: `flutter analyze`, `flutter test` và build nền tảng chịu tác động |
| Admin web | Trong `frontend/admin-web`: `npm test`, `npm run build` |
| Markdown | Mục lục, đường dẫn tài liệu/source/ảnh và bảo toàn nội dung sau khi chuyển |

Trước commit/push:

- [ ] `git status --short` và `git diff --cached --name-status` chỉ có file được phép; không có Markdown nếu chưa được yêu cầu.
- [ ] `git diff --cached --check` không lỗi whitespace; review cả phần thêm và xóa, không chỉ danh sách untracked.
- [ ] Env/key/signing/service account không nằm trong staged diff; config client không chứa backend secret.
- [ ] Mẫu config, model client và tài liệu local được cập nhật khi đổi hợp đồng/cấu hình.
- [ ] Kiểm tra phù hợp đã chạy; giới hạn/skip/failure còn lại được ghi rõ.

Có thể dùng `rg -l -i 'apikey|password|secret|token'` trong các file source chịu tác động để tìm vị trí cần review; kết quả chỉ là tên file, từ khóa không chứng minh có secret. Secret scanner tự động là hạng mục hardening cần thiết lập/kiểm chứng riêng, không được ghi là đã có chỉ từ checklist này.

Trước production cần có cấu hình HTTPS/CORS đúng origin, health/readiness, log/metric có kiểm soát dữ liệu, xử lý backlog/DLQ, backup/restore đã thử, rollback tương thích schema và nghiệm thu flow trên thiết bị/provider thật. Không tắt chữ ký, authorization hoặc DB constraint để vượt release gate.
