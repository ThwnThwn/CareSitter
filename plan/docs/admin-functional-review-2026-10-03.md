# Rà soát chức năng Admin — CareSitter

Ngày: 03/10/2026. Mã nguồn tại thời điểm rà soát: `89cff7e`, nhánh `feat/google-sign-in-account-chooser`.

## 1. Kết luận

Admin đã có 8 màn hình nghiệp vụ kết nối API thật: tổng quan, booking, KYC, thanh toán, hỗ trợ, tranh chấp, dịch vụ/checklist và tài khoản. Có xác thực ADMIN ở backend, nhiều quy tắc chuyển trạng thái, nhật ký cho các thao tác quản trị và bảo vệ đồng thời ở một số luồng thanh toán. Đây không chỉ là giao diện mẫu.

Tuy nhiên, chưa đủ cơ sở xác nhận admin sẵn sàng vận hành tiền thật. Cần ưu tiên khép kín vòng đời tranh chấp và chi trả, sửa thời gian bảng giá, hoàn thiện đăng xuất và bổ sung kiểm thử đồng thời xuyên module. Build thành công không chứng minh các nghiệp vụ này đã an toàn.

Đây là báo cáo đánh giá; chưa sửa mã nghiệp vụ, chưa commit/push/deploy, chưa thay đổi dữ liệu trên hệ thống thật.

### Phương pháp và giới hạn

- Đọc luồng UI của cả 8 màn hình, API client, shell, drawer và các controller/handler/domain/repository liên quan.
- Chạy lại build admin và toàn bộ bộ kiểm thử backend hiện có.
- Tái hiện riêng phép chuyển đổi thời gian bảng giá bằng Node với múi giờ Việt Nam.
- Chưa thực hiện đầy đủ thao tác end-to-end bằng tài khoản admin trên môi trường có dữ liệu thật. Các bước tái hiện bên dưới là kịch bản kiểm chứng đề xuất, trừ phép thử múi giờ đã chạy.
- Những thiếu sót về nghiệp vụ được phân biệt với lỗi logic. Các rủi ro đồng thời/phục hồi cần kiểm thử PostgreSQL được ghi rõ, không coi là sự cố đã xảy ra.
- Hướng dẫn `fk` được dùng cho phần trạng thái giao diện, biểu mẫu và khả năng thao tác; báo cáo này không phải chứng nhận kiểm thử thiết kế hay accessibility trên trình duyệt.

### Kiểm tra đã chạy

| Kiểm tra | Kết quả |
|---|---|
| `npm run build` tại admin-web | Thành công: TypeScript và Vite |
| `dotnet test backend/CareSitter.sln --no-restore --verbosity minimal` | 183 đạt, 0 lỗi, 14 bỏ qua |
| PostgreSQL race tests | Bỏ qua do chưa đặt `CARESITTER_TEST_ADMIN_CONNECTION`; chưa xác nhận hành vi đồng thời thật |
| Test riêng cho frontend admin | Chưa có script test hoặc bộ test tìm thấy trong project admin |
| Phép thử giờ bảng giá | UTC đầu vào 09:00 bị lưu thành 02:00 UTC khi chạy ở UTC+7 |

## 2. Bản đồ chức năng hiện có

| Nhóm | Đã có trong mã nguồn | Khoảng trống chính | Đánh giá |
|---|---|---|---|
| Đăng nhập / phiên | Email/mật khẩu, yêu cầu role ADMIN, sessionStorage, metadata từ server | Chưa gọi logout server, chưa refresh phiên; 403 cũng bị đăng xuất | Cần hoàn thiện trước vận hành |
| Tổng quan | Chỉ số từ các module, hàng đợi, làm mới, liên kết sang màn hình | Mất ưu tiên CRITICAL khi gộp; không mở đúng hồ sơ/tab; chưa tự cập nhật | Dùng để quan sát cơ bản |
| Booking | Phân trang, lọc trạng thái, thông tin ca, checklist, timeline, xác nhận hoàn tất | Tìm kiếm chỉ trong trang; thiếu bằng chứng khi duyệt; thông báo giải ngân gây hiểu nhầm | Có luồng chính, thiếu công cụ điều hành |
| KYC | Hàng đợi, xem ảnh CCCD/chứng chỉ, duyệt/từ chối | Lý do từ chối không có trong hồ sơ đọc lại; thiếu lịch sử và xử lý duyệt đồng thời | Chưa khép kín vòng bổ sung hồ sơ |
| Thanh toán | Đối soát thủ công, mã VNPay, ghi chú; duyệt/từ chối rút tiền | Chưa khép kín chuyển khoản/PAID/FAILED; chưa có màn sổ cái; đối soát giới hạn 100 | Ưu tiên cao nhất |
| Hỗ trợ | Lọc trạng thái/loại/ưu tiên, nhận xử lý, đổi trạng thái, tệp đính kèm | Chưa có trả lời, ghi chú, chuyển người xử lý, SLA; chủ yếu hiển thị UUID | Quản lý hàng đợi cơ bản |
| Tranh chấp | Danh sách, ba phán quyết, hoàn tiền/chế tài, hủy hồ sơ | Hủy để lại booking disputed; rủi ro lưu lệch giữa module; thiếu xem bằng chứng và dự toán tiền | Ưu tiên cao nhất |
| Dịch vụ / checklist | Tạo/sửa gói, bảng giá, thời gian hiệu lực, mẫu công việc, bật/tắt/xóa, việc phát sinh | Lệch múi giờ; giá hiện hành sai; hệ số lễ chưa nối đúng; form checklist giữ nhầm ngữ cảnh | Nhiều chức năng nhưng cần sửa logic |
| Tài khoản | Tìm kiếm server-side, lọc, khóa/mở/tạm ngưng, đổi vai trò | Chưa phân quyền theo nhiệm vụ; chưa xem lịch sử/phiên; thiếu xác nhận cấp ADMIN | Bảo vệ backend khá hơn UI thể hiện |

## 3. Các vấn đề ưu tiên cao

Quy ước: P1 = cần xử lý trước vận hành nghiệp vụ thật; P2 = lỗi chức năng/thiếu kiểm soát đáng kể; P3 = hoàn thiện trải nghiệm. Mức ưu tiên là đánh giá kỹ thuật, không phải kết quả sự cố production.

### ADM-01 — P1: Hủy tranh chấp để lại booking ở trạng thái `disputed`

- Bằng chứng: [CancelDisputeCommandHandler.cs](../../backend/caresitter-be/Modules/Support/Application/Commands/Disputes/CancelDispute/CancelDisputeCommandHandler.cs:22) chỉ gọi `dispute.Cancel()` rồi lưu Support, không cập nhật Booking.
- `CompleteBookingCommandHandler` chỉ nhận `checkout_pending_review`; job giải ngân chỉ chọn `completed`. Vì vậy, sau khi hủy hồ sơ, booking disputed không có đường đi tiếp qua hai luồng này.
- Tác động: hồ sơ khiếu nại có vẻ đã xử lý nhưng ca và khoản tiền giữ chờ có thể mắc kẹt. Đóng dispute không đồng nghĩa đã hoàn tiền hoặc đã trả caregiver.
- Kịch bản: ca đang chờ hoàn tất → khách mở tranh chấp → admin hủy → kiểm tra cả trạng thái dispute, booking và settlement.
- Hướng sửa: xác định rõ ý nghĩa “hủy khiếu nại”; lưu trạng thái booking trước tranh chấp, thực hiện chuyển trạng thái có kiểm soát và bảo đảm gọi lại không gây thêm tác động. Không tự chọn người thắng khi chỉ hủy hồ sơ.
- Tiêu chí đạt: không còn cặp `CANCELLED dispute` + booking bị treo `disputed`; thời hạn khiếu nại và tiền giữ chờ vẫn đúng chính sách đã thống nhất.

### ADM-02 — P1: Quyết định tranh chấp chưa có cơ chế hoàn tất nhất quán xuyên module

- Bằng chứng: [ResolveDisputeCommandHandler.cs](../../backend/caresitter-be/Modules/Support/Application/Commands/Disputes/ResolveDispute/ResolveDisputeCommandHandler.cs:43) lần lượt cập nhật tiền → Booking → lưu Support. Payments và Booking tự commit transaction riêng.
- Nhánh lỗi cụ thể: Payments thành công, Booking thành công, nhưng lưu Support lỗi. Khi thử lại, đầu handler yêu cầu booking vẫn `disputed`, trong khi booking đã `completed/refunded`; hồ sơ chưa chốt có thể không tự phục hồi được.
- Rủi ro đồng thời: khóa tiền ở Payments không đồng nghĩa đã khóa phán quyết Support. `HasDisputeResolutionMarkerAsync` chọn dấu vết theo loại quyết định (`REFUND` hoặc `CAREGIVER_EARNING`), chưa thể hiện một quyết định duy nhất bất biến cho cả hồ sơ. Cần thử hai admin ra phán quyết trái nhau, không chỉ thử gửi lại cùng một phán quyết.
- Phạm vi chứng minh: đã đối chiếu thứ tự commit và điều kiện retry trong code; chưa mô phỏng lỗi DB hoặc cuộc đua xuyên module trên PostgreSQL.
- Hướng sửa: tạo bản ghi quyết định duy nhất có version/idempotency key; dùng transaction phù hợp hoặc quy trình có outbox và bước phục hồi; không để mỗi lần retry tự chọn một quyết định khác.
- Tiêu chí đạt: ngắt ở từng bước rồi retry đều hội tụ; chỉ một phán quyết được chấp nhận; tổng tiền không vượt escrow; hồ sơ, booking và sổ cái nhất quán.

### ADM-03 — P1: Duyệt rút tiền đã ghi sổ chi trả nhưng chưa có xác nhận chuyển tiền

- Bằng chứng: [PayoutStore.cs](D:/EXE/CareSitter/backend/caresitter-be/Modules/Payments/Infrastructure/PayoutStore.cs:64) chuyển `APPROVED`, tạo bút toán `PAYOUT` sang `bank:external`, đánh dấu `POSTED`, trừ `pending_balance` trong cùng transaction.
- Domain có `MarkProcessing/MarkPaid/MarkFailed`, nhưng không tìm thấy lời gọi triển khai các bước này trong luồng ứng dụng hiện tại. UI chỉ có duyệt hoặc từ chối; không có mã chuyển khoản, biên nhận hay xác nhận đã trả.
- Tác động: hệ thống có thể ghi nhận tiền đã rời ví trong khi chưa có bằng chứng tiền đến ngân hàng. Không nên hiểu nút “Duyệt chuyển tiền” là hệ thống đã tự chuyển tiền thật.
- Điểm tốt: đã dùng khóa dòng và transaction để ngăn duyệt/từ chối một yêu cầu cùng lúc; không phải hoàn toàn thiếu bảo vệ tiền.
- Hướng sửa: tách phê duyệt với thực hiện chi trả. Nếu chuyển tay, cần bước xác nhận đã chuyển kèm mã giao dịch/biên nhận; nếu dùng nhà cung cấp, cần callback, retry và đối soát. Quy định rõ thời điểm hạch toán cuối cùng và cách trả lại tiền khi thất bại.
- Tiêu chí đạt: `PENDING → APPROVED → PROCESSING → PAID/FAILED` có bằng chứng, lịch sử và khả năng phục hồi; không thanh toán hai lần.

### ADM-04 — P1: Sửa bảng giá làm lệch thời gian hiệu lực 7 giờ

- Bằng chứng: [ServicesPage.tsx](D:/EXE/CareSitter/frontend/admin-web/src/pages/ServicesPage.tsx:51) cắt chuỗi ISO trực tiếp để đưa vào `datetime-local`; lúc lưu lại chuyển bằng `new Date(...).toISOString()` ở dòng 63.
- Đã chạy phép thử đúng hai phép biến đổi trong code tại UTC+7:
  - Server: `2026-10-03T09:00:00+00:00`.
  - Giá trị form: `2026-10-03T09:00`.
  - Payload lưu: `2026-10-03T02:00:00.000Z`.
- Tác động: chỉ mở rồi lưu, không sửa giờ, cũng đổi thời điểm áp dụng giá/phí. Giá trị mặc định tạo mới dùng UTC cắt chuỗi có cùng vấn đề hiển thị.
- Hướng sửa: chuyển ISO sang giờ địa phương đúng cách hoặc dùng múi giờ nghiệp vụ cố định và ghi rõ UTC+7; bảo toàn thời điểm khi mở/lưu.
- Tiêu chí đạt: create/edit round-trip không đổi timestamp; kiểm tra giờ giáp ngày, `effectiveTo`, máy UTC và máy Việt Nam.

### ADM-05 — P1: Đăng xuất chỉ xóa token trên trình duyệt

- Bằng chứng: [main.tsx](D:/EXE/CareSitter/frontend/admin-web/src/main.tsx:101) chỉ xóa sessionStorage và đổi state, không gọi endpoint logout sẵn có.
- Tác động: bản sao access token đã lấy trước đó vẫn có thể dùng tới khi hết hạn hoặc bị thu hồi bởi cơ chế khác; bấm đăng xuất chưa thu hồi phiên ở server.
- Hướng sửa: gọi logout server bằng phiên hiện tại, xóa token local kể cả khi request lỗi, thông báo phù hợp nếu không xác nhận thu hồi được. Không lưu khóa/token vào log hay báo cáo.
- Tiêu chí đạt: lấy token test, đăng xuất, gọi lại API bảo vệ bằng token đó phải bị từ chối. Đây là kiểm thử cần chạy trên môi trường test, chưa thực hiện trong lượt audit này.
- Phân biệt: khóa tài khoản/đổi vai trò ở backend đã có thu hồi phiên. Vấn đề này nằm ở nút đăng xuất của admin, không phải toàn bộ hệ thống không có revoke.

## 4. Chi tiết các lỗi và thiếu sót còn lại

### Tổng quan vận hành

**ADM-06 — P2: Hàng đợi tổng hợp có thể đẩy ticket khẩn ra khỏi màn hình.** `AdminSupportReader` ưu tiên CRITICAL, nhưng [AdminDashboardController.cs](D:/EXE/CareSitter/backend/caresitter-be/ApiHost/Controllers/AdminDashboardController.cs:43) gộp tất cả rồi sắp xếp lại theo thời gian, lấy 12 phần tử. Nếu có đủ việc cũ, ticket CRITICAL mới có thể bị loại. Cần mang trường ưu tiên vào kết quả gộp, giữ SOS/CRITICAL ở vị trí dễ thấy và có hàng đợi khẩn riêng.

**Điều hướng chưa đến đúng việc:** [DashboardPage.tsx](D:/EXE/CareSitter/frontend/admin-web/src/pages/DashboardPage.tsx:56) chỉ truyền tên trang, bỏ `item.id`. Bấm yêu cầu rút tiền còn mở tab đối soát mặc định thay vì tab payout. Cần liên kết kèm loại hồ sơ, id, tab và bộ lọc; hỗ trợ URL mở trực tiếp.

**Chưa có tự cập nhật:** chỉ tải khi mở/làm mới. `generatedAt` chưa được hiển thị. Nên có thời điểm đồng bộ gần nhất, cảnh báo dữ liệu cũ và cơ chế cập nhật phù hợp; không dùng màn hình này như hệ thống cảnh báo SOS duy nhất.

**Thiếu góc nhìn quản lý:** doanh thu/tiền giữ chờ, lượng booking theo ngày, ca trễ, thời gian xử lý KYC/ticket, backlog theo người phụ trách. Đây là đề xuất mở rộng, không phải lỗi của bộ đếm hiện có.

### Booking

**ADM-07 — P2: Tìm kiếm chỉ trong 20 dòng đã tải.** [BookingsPage.tsx](D:/EXE/CareSitter/frontend/admin-web/src/pages/BookingsPage.tsx:30) lọc `result.items`; query gửi API không có từ khóa. Một booking ở trang 2 sẽ bị báo không tìm thấy khi tìm từ trang 1. Cần search server-side trước phân trang và trả tổng theo query.

**Duyệt khi chưa xem được chi tiết:** nút complete dựa vào object từ danh sách, không khóa theo `loading/error`. Khi một request trong nhóm detail/tasks/timeline lỗi, admin vẫn có thể bấm hoàn tất nếu list ghi `checkout_pending_review`. Backend có kiểm tra trạng thái, nhưng chưa bảo đảm admin đã xem đủ dữ liệu để quyết định. Nên khóa nút khi dữ liệu quan trọng chưa tải, cho retry từng khu vực.

**Thông báo tiền chưa đúng:** hộp xác nhận nói escrow sẽ được giải ngân; backend ghi `BOOKING_COMPLETED_AWAITING_SETTLEMENT`, chờ cửa sổ tranh chấp. Nên hiển thị thời hạn thực tế và phân biệt “xác nhận hoàn tất” với “tiền đã khả dụng”.

**Checklist/timeline chưa đủ để điều tra:** hiện hiển thị tên, mô tả, trạng thái, thời gian; chưa có đầy đủ ảnh minh chứng, lý do bỏ việc, giờ check-in/out thực tế, thông tin liên hệ và liên kết tranh chấp/ticket. Màn hình có chức năng xem, nhưng chưa đủ mạnh cho duyệt ngoại lệ.

**Mở rộng nên có:** tìm ngày/quận/caregiver/khách, xuất dữ liệu có kiểm soát, xử lý ca không tìm được người, hủy có lý do và xem trước tác động tiền. Luồng điều phối lại người chăm sóc cần thiết kế nghiệp vụ riêng, không chỉ thêm nút đổi ID.

### KYC

**ADM-08 — P2: Vòng phản hồi lý do từ chối chưa khép kín.** [RejectCaregiverKycCommandHandler.cs](../../backend/caresitter-be/Modules/People/Application/Commands/Kyc/RejectCaregiverKyc/RejectCaregiverKycCommandHandler.cs:27) ghi lý do vào audit và response tức thời, nhưng profile/DTO đọc lại không có lý do; handler không gửi thông báo cho caregiver. UI nói nhập lý do để caregiver bổ sung nhưng chưa có đường đọc lại rõ ràng. Không phải lý do mất hoàn toàn: audit có lưu, chỉ chưa cung cấp trong luồng hồ sơ.

Cần lưu quyết định KYC với người duyệt, thời gian, lý do, phiên bản tài liệu; trả về cho người có quyền xem; thông báo và cho caregiver nộp lại đúng tài liệu. Backend validator từ chối hiện chưa thực thi mức tối thiểu 5 ký tự như UI.

**Số tài liệu chưa chính xác:** UI luôn tính `2 + số chứng chỉ`, kể cả hồ sơ DRAFT thiếu ảnh CCCD. Chỉ đếm URL có thật; có trạng thái tải ảnh lỗi và không mặc định mọi chứng chỉ đều là ảnh.

**Rủi ro cần test thêm:** hai admin cùng duyệt/từ chối một hồ sơ. Domain chặn chuyển trạng thái sai trong một instance, nhưng chưa thấy khóa/version trên đường đọc rồi ghi này. Cần optimistic concurrency hoặc thao tác cập nhật có điều kiện và trả 409 khi hồ sơ đã đổi.

### Thanh toán và rút tiền

Ngoài ADM-03, cần các phần sau:

- **Đối soát giới hạn 100:** [PaymentReconciliationProcessor.cs](D:/EXE/CareSitter/backend/caresitter-be/Modules/Payments/Infrastructure/PaymentReconciliationProcessor.cs:23) dùng `Take(100)`; không có phân trang/tổng số cho UI. Search cũng chỉ tìm trong mảng đã trả. Cần tránh để admin hiểu 100 dòng là toàn bộ backlog. Đặc biệt nên lọc điều kiện booking hợp lệ trước khi áp giới hạn hoặc có cơ chế duyệt hết dữ liệu.
- **Xác nhận hai bước:** đối soát ảnh hưởng tiền/booking nhưng nút xác nhận/từ chối chưa có bước xem lại số tiền, booking, mã VNPay và lý do trước khi gửi.
- **Sổ cái:** backend đã có GET `/api/v1/payments/ledger` dành cho ADMIN tại [PaymentsController.cs](D:/EXE/CareSitter/backend/caresitter-be/Modules/Payments/Controllers/PaymentsController.cs:65), nhưng admin chưa có màn tra cứu tương ứng.
- **Hồ sơ chi trả:** nên hiện người duyệt, giờ duyệt, lịch sử trạng thái, liên kết ví và sổ cái; che số tài khoản mặc định, chỉ lộ khi tác vụ cần và có quyền.
- **Không đánh đồng kết quả:** đối soát thu tiền, hoàn vào ví khách và chuyển khoản về ngân hàng là các luồng khác nhau; mỗi luồng cần trạng thái và bằng chứng riêng.

### Tranh chấp

Ngoài ADM-01/02:

**ADM-09 — P2: Form tài chính có thể thể hiện khác quyết định thực tế.** [DisputesPage.tsx](D:/EXE/CareSitter/frontend/admin-web/src/pages/DisputesPage.tsx:65) cho nhập hoàn tiền/chế tài ở mọi quyết định. Backend tự hoàn toàn bộ escrow cho `CUSTOMER_WINS`, hoàn 0 cho `CAREGIVER_WINS`, và chỉ khấu trừ chế tài từ phần caregiver trong `PARTIAL_REFUND`; các chế tài ở quyết định thắng toàn phần chỉ là giá trị ghi nhận hành chính. UI chưa giải thích khác biệt này.

Ví dụ chọn khách thắng nhưng ô tiền hoàn vẫn 0 có thể khiến người duyệt hiểu sai tác động. Cần bảng xem trước: tiền khách nhận, caregiver nhận, phí nền tảng, chế tài thực khấu trừ; khóa trường không áp dụng. Không cho gửi `PARTIAL_REFUND` khi thiếu escrow để tính giới hạn.

**Thiếu dữ liệu ra quyết định:** chưa tải hồ sơ dispute chi tiết dù đã có endpoint, chưa hiện bằng chứng, checklist liên quan, giao dịch gốc, lịch sử quyết định, thông tin hai bên và lý do phân xử. Chưa có thao tác bắt đầu điều tra dù domain có trạng thái INVESTIGATING.

**Quy trình cần bổ sung:** người xử lý, trạng thái điều tra, ghi chú nội bộ, bằng chứng, lý do quyết định bắt buộc, version để chống hai người ghi đè và xác nhận tác động tiền. Duyệt kép cho khoản lớn là lựa chọn nghiệp vụ cần thống nhất, không phải sửa tự động mặc định.

### Hỗ trợ

**Đã có:** các loại COMPLAINT, SOS, PAYMENT, KYC, CHECKOUT_REVIEW, GENERAL; lọc mức ưu tiên; nhận ticket cho bản thân; backend kiểm soát chuyển trạng thái.

**Chưa có vòng trao đổi:** chưa có trả lời khách/caregiver, ghi chú nội bộ, lịch sử trao đổi, thông báo kết quả xử lý hoặc yêu cầu bổ sung. Đổi trạng thái ticket không thay thế việc xử lý và phản hồi.

**Phân công còn hạn chế:** UI vô hiệu hóa “Nhận xử lý” khi có bất kỳ admin phụ trách; không có chuyển giao/unassign. Backend `AssignAdmin` lại cho ghi đè người phụ trách, không có điều kiện “chưa ai nhận”. Hai người mở ticket chưa phân công có thể tranh nhau nhận; cần version hoặc quy tắc chuyển giao rõ ràng.

**Vận hành nên có:** bộ lọc “của tôi/chưa nhận/quá hạn”, SLA, cảnh báo SOS, người liên hệ, liên kết booking và luồng escalations. Đóng ticket cần ghi nhận kết quả; reopen là yêu cầu nghiệp vụ mới cần thêm vào state machine nếu muốn hỗ trợ.

### Dịch vụ, bảng giá và checklist

**ADM-10 — P2: “Giá hiện hành” không theo quy tắc backend.** [ServicesPage.tsx](D:/EXE/CareSitter/frontend/admin-web/src/pages/ServicesPage.tsx:35) lấy rule đầu tiên `isActive`; [PricingService.cs](D:/EXE/CareSitter/backend/caresitter-be/Modules/Catalog/Infrastructure/PricingService.cs:27) còn kiểm tra thời gian hiệu lực và chọn rule có `effectiveFrom` mới nhất. Rule chưa đến hạn/hết hạn vẫn có thể bị UI gọi là giá hiện hành. Nên để backend trả active rule hoặc dùng chung tiêu chí và kiểm thử các ranh giới.

**ADM-11 — P2: Trường hệ số ngày lễ chưa nối vào phép báo giá như UI gợi ý.** UI sửa `holidayMultiplier`, nhưng `PricingService` lấy multiplier từ JSON `Holidays`; API quản trị hiện tại không có cấu hình lịch `Holidays`. Khi tắt `Pricing:EnableTimeMultipliers`, cả hệ số ban đêm/ngày lễ không áp dụng; UI cũng chưa báo chế độ này. Cần thống nhất nguồn cấu hình, có lịch ngày lễ và công cụ xem trước giá theo ngày/giờ.

**ADM-12 — P2: Đổi dịch vụ vẫn giữ form checklist của dịch vụ trước.** [ServicesPage.tsx](D:/EXE/CareSitter/frontend/admin-web/src/pages/ServicesPage.tsx:121) chỉ đổi `selectedId`, không reset `editing/form`. Đang sửa template A rồi chọn dịch vụ B, request sẽ gửi ID template A dưới URL B. Backend đã kiểm tra cặp service/template nên ngăn sửa nhầm bằng lỗi, nhưng luồng UI bị hỏng; bản nháp tạo mới cũng có thể bị đưa sang dịch vụ khác. Cần reset/xác nhận bản nháp khi đổi dịch vụ, đồng thời bỏ response cũ về muộn.

**ADM-13 — P2: Checklist mắc trạng thái loading khi chưa có dịch vụ hoặc tải dịch vụ lỗi.** Khởi tạo `loading=true`; request danh mục không có `finally` để kết thúc loading khi mảng rỗng/lỗi; `loadTemplates('')` trả sớm. Form thêm vẫn khả dụng dù thiếu service ID. Cần empty/error/retry riêng và chỉ cho lưu khi chọn được dịch vụ hợp lệ.

**Mở rộng nên có:** xem trước giá, cảnh báo không còn bảng giá hiệu lực, xem lịch sử sửa giá và phí, preview checklist, sắp thứ tự rõ ràng. Bảo toàn snapshot booking cũ khi sửa/xóa mẫu; đây là tiêu chí cần test với database, không chỉ dựa vào lời mô tả trên UI.

### Tài khoản và phân quyền

**Điểm tốt đã đối chiếu:** [handler đổi trạng thái tài khoản](../../backend/caresitter-be/Modules/Identity/Application/Commands/AdminUsers/SetAdminUserStatus/SetAdminUserStatusCommandHandler.cs:26) và [handler đổi vai trò](../../backend/caresitter-be/Modules/Identity/Application/Commands/AdminUsers/SetAdminUserRoles/SetAdminUserRolesCommandHandler.cs:16) chặn tự khóa/tạm ngưng, chặn tự gỡ ADMIN, kiểm tra còn admin hoạt động, chuẩn hóa vai trò, thu hồi phiên khi khóa/đổi quyền và ghi audit. Không nên báo rằng hệ thống chỉ ẩn nút mà không kiểm tra backend.

**Thiếu kiểm soát thao tác:** cấp ADMIN chỉ cần checkbox rồi lưu, chưa có xác nhận rõ quyền được cấp. Hiện quyền ADMIN là quyền rộng; chưa phân tách nhân sự KYC, hỗ trợ, tài chính, cấu hình và quản trị quyền. Việc chia vai trò là quyết định sản phẩm cần thống nhất trước triển khai.

**Thiếu tra cứu:** chưa có trang phiên đăng nhập/thu hồi phiên, lịch sử sửa quyền, lý do khóa và liên kết hồ sơ caregiver/khách. Không nên mở rộng thành chức năng xem mật khẩu hoặc để admin đặt mật khẩu tùy ý.

**Rủi ro cần test:** kiểm tra “admin cuối cùng” là đếm rồi ghi; cần thử hai admin đồng thời khóa/gỡ quyền lẫn nhau, bảo đảm ràng buộc vẫn đúng sau cả hai transaction. Chưa xác nhận bằng race test trong lượt này.

## 5. Các lỗi dùng chung

### ADM-14 — P2: Xử lý mục cuối của trang có thể làm người dùng mắc ở trang trống

[Common.tsx](D:/EXE/CareSitter/frontend/admin-web/src/components/Common.tsx:52) ẩn Pagination nếu `total <= pageSize`, trong khi các trang không điều chỉnh số trang sau khi xử lý hồ sơ.

Kịch bản: hàng đợi có 21 mục, mở trang 2, duyệt mục cuối → còn 20 mục → tải lại vẫn page 2 → không có dòng và không có nút quay lại. Cần tự giảm trang về trang hợp lệ rồi tải lại. Áp dụng KYC, payout, tranh chấp, support và các bộ lọc tương tự.

### ADM-15 — P2: Response cũ có thể ghi đè bộ lọc/ngữ cảnh mới

Các trang dùng `useEffect + fetch` nhưng chưa hủy hoặc loại response cũ; reset page nằm trong effect khác. Ví dụ chọn trạng thái A rồi B nhanh trên mạng chậm, response A về sau sẽ ghi đè danh sách B. Search người dùng có debounce nhưng debounce không hủy request đã gửi.

Cần request sequence/AbortController hoặc tầng truy vấn có query key; reset page cùng thao tác đổi filter; test response cố tình trả sai thứ tự. Với thao tác tiền/quyền, tải lại bản ghi chi tiết/version trước quyết định và xử lý 409 rõ ràng.

### Phiên, lỗi và accessibility

- API coi 401 và 403 như nhau, đều đăng xuất. 403 nên giải thích không đủ quyền, không mặc định phá phiên hợp lệ.
- Không có refresh token ở admin, cảnh báo hết phiên hay bảo vệ bản nháp khi phiên hết hạn.
- Drawer có Escape/backdrop nhưng thiếu quản lý focus vào/ra và giữ focus trong modal; chưa bảo vệ dữ liệu chưa lưu.
- Skip link dùng `#main-content`, xung đột router `#/...`: router không nhận fragment này nên có thể đưa trang về dashboard.
- Tabs có role nhưng chưa đầy đủ điều hướng bàn phím/quan hệ tab-panel.
- `DetailList` dùng `value || '—'`, làm số 0 biến thành dấu gạch. Nên phân biệt 0 với null/undefined.
- ErrorBanner luôn ghi “Không thể tải dữ liệu”, kể cả lỗi lưu/duyệt. Cần thông báo đúng hành động và trạng thái retry.
- Sau lỗi tải lần đầu, nhiều màn hình vẫn hiện empty state khẳng định không có hồ sơ bên dưới thông báo lỗi. Cần phân biệt “đã tải và không có dữ liệu” với “chưa biết vì tải thất bại”.

## 6. Kế hoạch nâng cấp theo thứ tự

### Đợt A — An toàn nghiệp vụ và tiền

1. Thống nhất ý nghĩa hủy dispute và quy trình payout thực tế (chuyển tay hay nhà cung cấp).
2. Sửa ADM-01/02/03, thêm quyết định bất biến, kiểm soát đồng thời và phục hồi khi lỗi giữa chừng.
3. Sửa ADM-04/05; bổ sung kiểm thử múi giờ và thu hồi phiên.
4. Chạy PostgreSQL tests trên database test biệt lập; thêm các trường hợp xuyên module hiện chưa có.

Điều kiện hoàn thành: không còn booking mắc kẹt, không quyết toán hai lần, không có payout được hạch toán cuối cùng mà thiếu quy trình xác nhận, logout thực sự thu hồi phiên.

### Đợt B — Làm đầy đủ 8 luồng vận hành

1. Dashboard ưu tiên khẩn, thời điểm dữ liệu, mở thẳng đúng hồ sơ/tab.
2. Booking search server-side, liên kết bằng chứng/ticket/dispute, trạng thái settlement rõ ràng.
3. KYC có lý do đọc lại, lịch sử, thông báo và xử lý xung đột.
4. Thanh toán có phân trang, lịch sử chi trả và màn sổ cái.
5. Tranh chấp có hồ sơ bằng chứng và bảng xem trước phân bổ tiền.
6. Support có trao đổi, ghi chú, chuyển giao, SLA và escalations.
7. Giá/checklist sửa các lỗi ngữ cảnh, múi giờ, hiệu lực và cấu hình ngày lễ.
8. User management có xác nhận cấp quyền, lịch sử, phiên và phân quyền theo nhiệm vụ nếu được duyệt.

### Đợt C — Trải nghiệm, hồi quy và bàn giao

1. Dùng chung query state, pagination, confirm dialog, trạng thái lỗi và version conflict.
2. Kiểm tra bàn phím, focus, màn nhỏ, ảnh/tệp hỏng và mạng chậm.
3. Bộ test UI cho từng màn hình; end-to-end với dữ liệu test và ít nhất hai tài khoản admin.
4. Checklist phát hành, tài liệu thao tác cho đội vận hành, giám sát lỗi và hướng dẫn phục hồi.

Không gộp “có thêm nút” với “nghiệp vụ đã hoàn thiện”. Mỗi chức năng chỉ nghiệm thu khi UI, API, dữ liệu, phân quyền, lịch sử và tình huống lỗi đều khớp.

## 7. Checklist nghiệm thu đề xuất

Các mục dưới đây là test cần bổ sung/chạy, không phải danh sách đã đạt.

| Nhóm | Các ca bắt buộc |
|---|---|
| Phiên và quyền | CUSTOMER/CAREGIVER không vào admin; gọi API trực tiếp bị chặn; token sau logout bị chặn; hết hạn khi đang nhập form; 403 không tự đăng xuất; khóa/đổi role thu hồi phiên |
| Dashboard | 12 việc cũ + 1 CRITICAL mới; payout mở đúng tab/id; số liệu đổi sau xử lý; timestamp rõ; API một module lỗi có thông báo đúng |
| Booking | Tìm ở trang khác; đổi filter nhanh; detail lỗi thì không duyệt mù; hoàn tất không giải ngân sớm; đang tranh chấp không complete; ảnh checklist/timeline truy xuất đúng quyền |
| KYC | Thiếu CCCD không submit; approve/reject chỉ từ PENDING; hai admin xử lý cùng lúc; lý do từ chối đọc lại sau tải trang; nộp lại có lịch sử; 21 → 20 hồ sơ không mắc trang |
| Đối soát | Hơn 100 mục; mã giao dịch trùng/sai; hai admin quyết định trái nhau; gọi lại sau timeout; VNPay callback đến cùng lúc thao tác admin; số tiền/booking nhất quán |
| Payout | Không đủ số dư; gửi lại cùng key; hai yêu cầu đồng thời; approve/reject cạnh tranh; chuyển tiền lỗi; callback/retry trùng; đối soát PAID với số dư và ledger |
| Tranh chấp | Ba loại quyết định; giới hạn tiền hoàn/phạt; hủy phục hồi booking; hai admin phán quyết trái nhau; ngắt sau từng commit rồi retry; tổng phân bổ không vượt escrow |
| Support | Hai admin nhận cùng ticket; chuyển giao có lịch sử; CLOSED không chuyển sai trạng thái; phản hồi chỉ gửi cho đúng người; SOS nổi bật; attachment không truy cập vượt quyền |
| Giá | Mở/lưu không đổi giờ; giá tương lai/hết hạn; nhiều rule hiệu lực; ranh giới effectiveTo; day/night/holiday có và không bật hệ số; booking cũ giữ snapshot |
| Checklist | Dịch vụ rỗng/API lỗi; đổi A sang B đang sửa; response A về muộn; tên trùng; xóa/tắt mẫu không phá booking cũ; không lưu khi thiếu service ID |
| Tài khoản | Không tự khóa/gỡ ADMIN; hai admin khóa lẫn nhau; cấp ADMIN có xác nhận; đổi role trùng thời điểm; tìm theo tên/email/điện thoại; lịch sử trước/sau rõ ràng |
| UI dùng chung | Tab/Shift+Tab/Escape; đóng drawer khi chưa lưu; refresh/retry không gửi trùng thao tác tiền; dữ liệu 0; trang cuối rỗng; 401/403/409/500/offline được phân biệt |

## 8. Quyết định sản phẩm cần chốt trước khi viết phần mở rộng

1. “Hủy khiếu nại” nghĩa là rút hồ sơ, đóng vì không hợp lệ hay caregiver thắng? Ba ý nghĩa này có tác động tiền khác nhau.
2. Chi trả caregiver là chuyển khoản tay hay tích hợp nhà cung cấp? Ai xác nhận hoàn thành, có cần người duyệt thứ hai không?
3. Có chia ADMIN thành tài chính/KYC/hỗ trợ/quản lý hệ thống không? Ai được cấp quyền ADMIN?
4. Những ticket nào cần phản hồi tức thời, thời hạn xử lý và người nhận cảnh báo là ai?
5. Bảng giá dùng giờ Việt Nam cố định hay múi giờ người quản trị? Hệ số ngày lễ áp theo danh sách ngày nào?

Các quyết định này không ngăn việc sửa lỗi chắc chắn như múi giờ, tìm kiếm, pagination hoặc reset checklist; nhưng không nên tự suy đoán khi thay đổi quy trình tiền và quyền.
