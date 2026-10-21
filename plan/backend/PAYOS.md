# Thanh toán payOS trong CareSitter

## Trạng thái hiện tại

Đã tích hợp payOS bên cạnh VNPAY ở backend và app khách hàng. App lấy danh sách cổng từ backend, chỉ cho chọn cổng đã mở, gửi mã booking và cổng thanh toán. Backend tự lấy số tiền cần thu từ booking, bao gồm ưu đãi đã áp dụng.

**Local đã bật theo yêu cầu ngày 14/10/2026:** `backend/.env` đặt `Payments__PayOS__Enabled=true` và `CustomerWebUrl=http://localhost:55709` cho phiên Flutter web hiện tại. Domain ngrok đã chuyển tiếp đến API local; payOS `confirm-webhook` trả `code=00` và xác nhận URL webhook. Ngày 16/10/2026 đã nghiệm thu một giao dịch thật 2.000 VND: backend truy vấn payOS, payment intent chuyển `SUCCEEDED`, booking chuyển `CONFIRMED` và chỉ có một `ESCROW_LOCK`. Các mẫu triển khai vẫn mặc định tắt. Không đưa khóa vào Flutter, Git hoặc tin nhắn chat.

Theo [tài liệu môi trường thử nghiệm của payOS](https://payos.vn/docs/moi-truong-test/), payOS dùng môi trường production, không có sandbox riêng. Các kiểm thử tự động của dự án giả lập ngân hàng; chưa thay thế kiểm tra tiền thật trên tài khoản của bạn.

## Các chức năng đã thêm

- Chọn payOS hoặc VNPAY khi thanh toán booking; phương thức chưa mở có trạng thái rõ ràng.
- Mở trang payOS để thanh toán VietQR/chuyển khoản ngân hàng. Kiểm tra tên người nhận và số tiền trên trang trước khi chuyển khoản.
- Tạo mã đơn và lưu vào PostgreSQL trước khi gọi payOS. Khi mất phản hồi, truy vấn lại mã cũ; không tự sinh mã thanh toán khác.
- Xác minh chữ ký HMAC của phản hồi API và webhook; kiểm tra mã đơn, payment link, tiền tệ và số tiền. `data.accountNumber` trong callback thật là tài khoản người chuyển nên không được so với tài khoản nhận từ create-link.
- Ghi nhận giao dịch, ledger và sự kiện xác nhận booking bằng luồng hoàn tất thanh toán đã có.
- Truy vấn trạng thái khi xem kết quả, nhận callback và chạy công việc đối soát nền.
- Callback về app Android/iOS bằng scheme `caresitter-customer`, hoặc về web khách hàng khi cấu hình `CustomerWebUrl`.
- Màn hình kết quả chỉ báo thành công sau khi tải được booking đã xác nhận từ backend. Tham số `result=success` trên URL không phải bằng chứng đã nhận tiền.
- Admin thấy các giao dịch cần kiểm tra tại **Thanh toán → Đối soát thanh toán**. Giao dịch/booking đã đóng hoặc có tiền chuyển thêm không được dùng thao tác duyệt để mở lại lịch hẹn.

## Chống thanh toán và ghi nhận lặp

1. App khóa nút, lựa chọn cổng và thao tác đóng khi đang tạo/mở thanh toán.
2. PostgreSQL chỉ cho một giao dịch `CREATED/PENDING` trên mỗi booking, dùng chung cho mọi cổng. Hai yêu cầu đồng thời bị ràng buộc bởi unique index.
3. Yêu cầu lại trên payOS tái sử dụng mã đơn và URL đã lưu. Booking đang chờ VNPAY không được mở thêm payOS và ngược lại.
4. Webhook có biên nhận duy nhất theo mã đơn + mã chuyển khoản. Hoàn tất thanh toán khóa dòng payment intent và chỉ ghi ledger/sự kiện một lần.

Các lớp này ngăn bấm nút lặp, retry tạo nhiều đơn và webhook ghi sổ nhiều lần. Người dùng vẫn có thể chủ động chuyển tiền hai lần từ ứng dụng ngân hàng. Khi webhook và tổng tiền payOS cho thấy tiền thừa/chuyển thêm, hệ thống đưa vào đối soát và không ghi có lần hai. Việc hoàn khoản dư hiện cần thao tác ngân hàng theo quy trình vận hành.

## Cấu hình sau khi có kênh thanh toán

### Các bước sau khi tài khoản đã xác thực

Hướng dẫn cập nhật ngày 08/10/2026 theo [tài liệu tạo kênh thu](https://payos.vn/docs/huong-dan-su-dung/kenh-thu/tao-kenh-thanh-toan/) và [kết nối ngân hàng qua Cas](https://payos.vn/docs/huong-dan-su-dung/ket-noi-tai-khoan-ngan-hang/).

1. Đăng nhập [my.payos.vn](https://my.payos.vn). Nếu chưa liên kết ngân hàng, vào phần ngân hàng, chọn ngân hàng và tiếp tục theo hướng dẫn Cas. Tài khoản ngân hàng cần đứng tên đúng cá nhân/tổ chức đã xác thực. Nếu ngân hàng đã kết nối thành công, bỏ qua bước này.
2. Mở mục kênh thanh toán và tạo kênh cho **CareSitter**. Nhập tên, logo rồi chọn tài khoản ngân hàng nhận tiền. Hoàn thành việc tạo kênh và mở trang thông tin kết nối.
3. Chép Client ID, API Key, Checksum Key vào các biến tương ứng trong `backend/.env`. Giữ `Enabled=false` trong lúc cấu hình. Không gửi khóa lên chat hoặc chụp ảnh trang khóa chưa che.
4. Chuẩn bị HTTPS cho backend. Dự án local đã có dịch vụ ngrok trong Compose, chuyển tiếp vào cổng `5033`. Điền authtoken ngrok trong `.env` nếu chưa có. Mở Docker Desktop, rồi chạy trong `D:\EXE\CareSitter\backend`:

   ```powershell
   docker compose up -d db redis ngrok
   ```

   Mở terminal khác ở cùng thư mục và chạy backend:

   ```powershell
   dotnet run --project caresitter-be/ApiHost/CareSitter.ApiHost.csproj --no-launch-profile --urls http://0.0.0.0:5033
   ```

   Mở `http://localhost:4040` để xem URL HTTPS của tunnel. Giữ backend và tunnel chạy trong lúc kiểm tra. URL cần chuyển tiếp được tới backend; khởi động ngrok chưa chứng minh API đã hoạt động.
5. Đặt `ReturnUrl` và `CancelUrl` theo URL HTTPS vừa lấy, sử dụng các đường dẫn trong khối cấu hình bên dưới. Để trống `CustomerWebUrl` cho app native; web triển khai dùng origin HTTPS. Khi thử Flutter web local ở môi trường Development, có thể dùng origin loopback HTTP đúng cổng đang chạy, chẳng hạn `http://localhost:55709`. Môi trường ngoài Development từ chối origin HTTP này. Khởi động lại backend để nạp cấu hình mới.
6. Mở kênh CareSitter trên payOS và lưu URL webhook `https://DOMAIN_CUA_BAN/api/v1/payments/payos/webhook`. payOS kiểm tra bằng giao dịch mẫu có chữ ký; backend phải chạy và đã có đúng Checksum Key. Không dùng URL return/cancel làm webhook. Xác minh webhook không cần bật tạo giao dịch mới, vì backend vẫn kiểm tra chữ ký khi `Enabled=false` và đã có khóa.
7. Sau khi webhook xác thực thành công, đổi `Payments__PayOS__Enabled=true`, khởi động lại backend và mở bản app/web đã có tích hợp. Thử một booking giá trị nhỏ có thật trong hệ thống; chuyển đúng số tiền, kiểm tra tiền về tài khoản nhận và booking được xác nhận. payOS dùng tiền thật, không có sandbox riêng.

Khi chuyển từ local sang production, cập nhật callback/webhook sang domain HTTPS của server và khởi động lại backend. Nếu dùng tunnel có URL thay đổi, cần cập nhật lại cả cấu hình backend và webhook trong kênh payOS.

Tạo kênh tại payOS và hoàn thành các bước xác minh/liên kết tài khoản ngân hàng do payOS yêu cầu. Chép **Client ID, API Key, Checksum Key** vào `backend/.env` ở máy chạy backend, hoặc kho bí mật của môi trường triển khai.

```dotenv
Payments__PayOS__Enabled=false
Payments__PayOS__ClientId=
Payments__PayOS__ApiKey=
Payments__PayOS__ChecksumKey=
Payments__PayOS__ReturnUrl=https://api.ten-mien-cua-ban.vn/api/v1/payments/payos/return
Payments__PayOS__CancelUrl=https://api.ten-mien-cua-ban.vn/api/v1/payments/payos/cancel
Payments__PayOS__CustomerWebUrl=
```

- App Android/iOS: để trống `CustomerWebUrl` để callback mở app bằng scheme đã khai báo.
- Web khách hàng: đặt `CustomerWebUrl=https://khachhang.ten-mien-cua-ban.vn`; không thêm `/#/` hoặc `/payment-result`.
- Web local Development: dùng `CustomerWebUrl=http://localhost:<cong-Flutter-web>`; nếu đổi cổng, cập nhật `.env` rồi khởi động lại backend. Cần mở lại màn chọn thanh toán để tải danh sách cổng mới.
- Dùng URL HTTPS truy cập công khai cho callback/webhook. Điện thoại không truy cập backend qua `localhost` của máy phát triển.
- Local có thể dùng URL HTTPS của tunnel đã cấu hình. Nếu domain thay đổi, cập nhật các URL và cấu hình webhook ở payOS.

### Domain local hiện đã cấu hình

Ngày 08/10/2026, URL payOS trong `backend/.env` đã đồng bộ với domain backend/ngrok đang được cấu hình cho VNPAY:

```dotenv
Payments__PayOS__ReturnUrl=https://uncrystallized-subtransversal-chantel.ngrok-free.dev/api/v1/payments/payos/return
Payments__PayOS__CancelUrl=https://uncrystallized-subtransversal-chantel.ngrok-free.dev/api/v1/payments/payos/cancel
```

URL cần điền vào mục webhook của kênh CareSitter trên payOS:

```text
https://uncrystallized-subtransversal-chantel.ngrok-free.dev/api/v1/payments/payos/webhook
```

Việc thay URL chưa xác nhận tunnel đang hoạt động hoặc webhook đã được đăng ký. Bật Docker/ngrok và backend theo các bước phía trên, đối chiếu URL tại `http://localhost:4040`, rồi đăng ký webhook trên payOS. Nếu ngrok trả về domain khác, thay domain trong cả hai callback và webhook. Khởi động lại backend sau khi thay `.env`.

Các mẫu `deploy/production.env.example` và `deploy/staging.env.example` dùng cùng domain với `Public__ApiBaseUrl` tương ứng. Khi triển khai, thay bằng domain HTTPS thực tế của backend.

### Xử lý lỗi 502 khi đăng ký webhook local

Ngrok đang chạy chưa đủ: backend phải đang nghe tại cổng `5033`. Ngày 08/10/2026, lỗi 502 xuất hiện do chưa có tiến trình backend ở cổng này. Đã khởi động Redis và backend, kiểm tra domain ngrok trả HTTP 200. Yêu cầu webhook không có chữ ký trả HTTP 400, chứng minh route đã tới API và vẫn kiểm tra chữ ký.

Kiểm tra tiếp bằng webhook thử có chữ ký phát hiện lỗi 500 do database local thiếu cột `payments.payment_intents.provider_create_date`. Đã áp dụng migration có sẵn `init-db/31-vnpay-original-create-date.sql` để bổ sung cột; không suy đoán hay ghi đè ngày tạo giao dịch cũ. Database local cần đủ các migration trước migration 36.

Sau khi cập nhật schema, webhook thử tự ký bằng Checksum Key đã cấu hình trả HTTP 200; yêu cầu không có chữ ký vẫn trả HTTP 400. Payload thử dùng mã đã kiểm tra không thuộc booking thật, không ghi nhận tiền. Đây là kiểm tra API của dự án; chưa xác nhận payOS đã lưu webhook hoặc có giao dịch tiền thật.

Nếu gặp lại, mở terminal tại thư mục `backend`, khởi động các dịch vụ local rồi chạy API:

```powershell
docker compose up -d db redis ngrok
$env:ASPNETCORE_ENVIRONMENT = 'Development'
dotnet run --project caresitter-be/ApiHost/CareSitter.ApiHost.csproj --no-launch-profile --urls http://0.0.0.0:5033
```

Giữ tiến trình API chạy. Cần bind `0.0.0.0:5033` để ngrok trong Docker truy cập được qua `host.docker.internal:5033`. Nếu cấu hình `KAFKA_ENABLED=true`, chạy thêm `docker compose up -d kafka kafka-init`.

Kiểm tra `http://localhost:5033/health/ready` và URL tương ứng trên domain HTTPS ngrok. Nếu vẫn 502, kiểm tra đúng cổng, tiến trình API và URL tunnel tại `http://localhost:4040`.

Sau khi hết 502, điền đủ `Payments__PayOS__ClientId`, `Payments__PayOS__ApiKey`, `Payments__PayOS__ChecksumKey` của đúng kênh trong `backend/.env`, khởi động lại API rồi lưu webhook trên payOS. Các khóa đã được điền và API đã được khởi động lại trong lần xử lý này; việc kênh payOS xác minh thành công vẫn cần kiểm tra bằng thao tác lưu webhook trên payOS. Có thể giữ `Payments__PayOS__Enabled=false` trong bước xác minh; chỉ bật sau khi webhook thành công.
- Khởi động backend sau khi cập nhật biến môi trường. Chỉ chuyển `Enabled=true` sau khi đã có khóa đúng và các URL hoạt động. Backend từ chối khởi động với cấu hình payOS bật nhưng thiếu khóa hoặc callback HTTPS.
- Giữ khóa để tiếp tục kiểm tra giao dịch đang mở khi tạm tắt tạo giao dịch mới. Xoay khóa theo quy trình payOS; không xóa khóa giữa lúc còn giao dịch chưa đối soát.

Đăng ký URL webhook trong kênh payOS:

```text
https://api.ten-mien-cua-ban.vn/api/v1/payments/payos/webhook
```

payOS gửi giao dịch mẫu có chữ ký khi kiểm tra webhook. Mã đơn không thuộc CareSitter được trả `200`, không tạo ledger hoặc xác nhận booking.

## Cập nhật cơ sở dữ liệu

Chạy `init-db/36-payos-payments.sql` trước khi chạy backend mới. Compose chỉ tự chạy thư mục `init-db` khi tạo volume PostgreSQL mới; database đã có dữ liệu cần áp dụng migration riêng.

Ví dụ local với database/user mặc định của Compose:

```powershell
Get-Content -Raw backend/init-db/36-payos-payments.sql |
  docker exec -i caresitter-db psql -U caresitter -d caresitter -v ON_ERROR_STOP=1
```

Thay user/database theo cấu hình thực tế. Migration thêm cột payOS và unique index dùng chung. Nếu dữ liệu cũ đã có nhiều intent đang mở trên cùng booking, migration dừng để đối soát trước; không tự xóa hoặc đóng các giao dịch đó. Chạy lại migration sau khi xử lý dữ liệu là an toàn.

## API

| Endpoint | Quyền | Chức năng |
| --- | --- | --- |
| `GET /api/v1/payments/providers` | Đăng nhập | Danh sách cổng và trạng thái khả dụng |
| `POST /api/v1/payments/intents` | Chủ booking | Body `{ "bookingId": "...", "provider": "PAYOS" }`; không nhận số tiền từ app |
| `GET /api/v1/payments/intents/{id}` | Chủ giao dịch | Đọc trạng thái và truy vấn payOS nếu đang chờ |
| `POST /api/v1/payments/payos/webhook` | Chữ ký payOS | Tiếp nhận thông báo chuyển tiền |
| `GET /api/v1/payments/payos/return` | Công khai | Truy vấn backend rồi chuyển về app/web |
| `GET /api/v1/payments/payos/cancel` | Công khai | Kiểm tra trạng thái thực tế; tham số hủy của trình duyệt không tự đóng giao dịch |

Webhook sai chữ ký/dữ liệu nhận `400`. Lỗi truy vấn chưa xác minh hoặc lỗi tạm thời nhận `503/500` để payOS gửi lại. Webhook hợp lệ cần xử lý thủ công được lưu và trả `200` sau khi ghi nhận đối soát.

## Các trường hợp cần vận hành

- Chuyển thiếu: đưa booking vào đối soát. Nếu nhận đủ tổng tiền qua nhiều chuyển khoản và truy vấn có chữ ký xác nhận tổng khớp, chỉ hoàn tất một lần.
- Chuyển thừa hoặc chuyển thêm sau khi đã thành công: giữ biên nhận, đưa vào danh sách đối soát; không ghi có phần dư tự động.
- Tiền đến sau khi intent/booking đã đóng hoặc số tiền booking đã thay đổi: không mở lại lịch hẹn; admin đối chiếu sao kê và xử lý khoản tiền.
- Không truy vấn được payOS: giữ trạng thái chưa xác minh, không tự coi đã thành công hoặc thu lại bằng mã khác.
- Payout caregiver đã có worker create/query qua payOS, credential tách biệt, lease/idempotency và chỉ ghi ledger khi provider xác nhận thành công. Mặc định vẫn tắt cho đến khi merchant được kích hoạt Payout và có bộ credential riêng; chưa chạy chuyển tiền thật.
- payOS không được giả định có refund API. Refund payOS được đưa vào trạng thái `MANUAL_REQUIRED`; admin chỉ xác nhận sau khi đã hoàn qua merchant portal/ngân hàng và có mã chứng từ. VNPAY có worker refund/query riêng, mặc định tắt đến khi merchant được cấp quyền và nghiệm thu sandbox.

Admin không được xác nhận tiền chỉ dựa vào ảnh chụp, callback trình duyệt hoặc màn hình khách hàng. Đối chiếu mã đơn/link, biên lai ngân hàng và tổng tiền payOS trước khi quyết định. Hàng đợi `Thanh toán → Hoàn tiền` cho phép ghi nhận refund thủ công, nhưng chỉ sau khi merchant portal/ngân hàng đã xác nhận; thao tác này mới tạo ledger refund.

## Kiểm tra trước khi mở nhận tiền

Kiểm tra tự động đã chạy thành công ngày 07/10/2026:

- 125 kiểm thử Payments, gồm fixture chữ ký chính thức payOS, kiểm tra response giả mạo và số tiền/trạng thái không khớp.
- 19 kiểm thử PostgreSQL/HTTP cho payOS và hồi quy thanh toán: 12 yêu cầu đồng thời, tranh chấp giữa hai cổng, mất phản hồi POST, 12 webhook lặp, quyền sở hữu, thiếu/thừa tiền, khoản chuyển thêm, tiền đến muộn và công việc đối soát.
- 30 kiểm thử ranh giới kiến trúc module.
- 14 kiểm thử Flutter liên quan booking/thanh toán/deep link và 58 kiểm thử admin web. Đã kiểm tra màn hình 320px với cỡ chữ lớn và chụp giao diện thực tế bằng Flutter để rà soát.
- Backend build, Flutter analyze, bản Android debug, bản web khách hàng và bản admin web đã kiểm tra. Chưa build/chạy native iOS trên Windows và chưa thử trên điện thoại thật.

Các trường hợp ngân hàng trong kiểm thử dùng adapter/HTTP giả lập; không gửi yêu cầu tạo giao dịch tới tài khoản payOS thật.

Sau khi có cấu hình thật, kiểm tra một booking giá trị nhỏ bằng tài khoản ngân hàng của bạn:

1. Chọn payOS, kiểm tra tên tài khoản nhận và số tiền sau ưu đãi.
2. Bấm nhanh nhiều lần và thử hai thiết bị; chỉ có một mã đơn/link đang mở.
3. Chuyển tiền, quay lại app trước webhook; màn hình chờ xác nhận rồi chuyển sang thành công khi backend xác nhận booking.
4. Gửi lại webhook hợp lệ; chỉ có một ledger và một sự kiện xác nhận payment.
5. Kiểm tra hủy/hết hạn, thiếu/thừa tiền và trạng thái đối soát bằng cách phù hợp với hướng dẫn payOS; không tự tạo nhiều giao dịch thật để chạy kiểm thử tự động.
6. Đối chiếu sao kê ngân hàng với ledger, nhật ký đối soát và trạng thái booking.

Tài liệu chính thức: [API payOS](https://payos.vn/docs/api/), [webhook](https://payos.vn/docs/du-lieu-tra-ve/webhook/), [return URL](https://payos.vn/docs/du-lieu-tra-ve/return-url/).
