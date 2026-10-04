# VNPAY — đọc tài liệu cho FIN01 và FIN02

Cập nhật 04/10/2026. Hướng dẫn chuẩn bị tích hợp, không bật giao dịch tiền thật.

## 1. Phân biệt hai luồng của CareSitter

| Task | Tiền đi đâu? | Phần đang có trong code | Chưa hoàn thành |
| --- | --- | --- | --- |
| FIN01 | Hoàn cho customer về phương thức thanh toán gốc | Adapter refund/querydr, chữ ký, snapshot, kiểm thử HTTP giả lập | Transaction hủy + refund request/outbox, worker/recovery, ledger và UI; sandbox acceptance |
| FIN02 | Chi tiền công cho caregiver | Luồng yêu cầu/duyệt payout hiện tại | API chi hộ, phân biệt Approved/Paid, xác nhận chuyển tiền, recovery và đối soát |

Không dùng refund của giao dịch customer để chuyển tiền cho caregiver. FIN01 đang tắt và chưa nối CancelBooking; FIN02 chưa có tài liệu API chi hộ/sandbox từ provider. VNPAY công bố có dịch vụ hỗ trợ thu hộ/chi hộ, nhưng điều đó không chứng minh merchant CareSitter đã được cấp API hoặc đủ điều kiện sử dụng. [Thông tin chính thức](https://vnpay.vn/vnpay-cong-bo-thong-tin-theo-quy-dinh-ve-hoat-dong-cung-ung-dich-vu-trung-gian-thanh-toan-0q6bssvjstgd).

## 2. Đọc PAY trước, không đọc code mẫu ngay

Mở [hướng dẫn PAY chính thức](https://sandbox.vnpayment.vn/apis/docs/thanh-toan-pay/pay.html), theo thứ tự: Thông tin cấu hình → Tạo URL thanh toán → IPN → ReturnURL. Cấu hình sandbox cần TmnCode, HashSecret và endpoint; trang này có link đăng ký thử nghiệm. IPN cập nhật kết quả; ReturnURL chỉ kiểm tra/hiển thị. Amount trên wire nhân 100: 100.000 VND thành 10.000.000; thời gian dùng GMT+7.

Trong CareSitter, đối chiếu PaymentIntent, VNPayService và PaymentPortal. Tự trả lời: mã nào thuộc merchant, mã nào thuộc VNPAY; số tiền thực thu lưu ở đâu; ngày tạo giao dịch gốc lưu ở đâu; callback lặp có thay đổi tiền hai lần không?

## 3. FIN01: đọc querydr/refund và bảng mã

Mở [đặc tả querydr/refund](https://sandbox.vnpayment.vn/apis/docs/truy-van-hoan-tien/querydr%26refund.html). Hai API dùng POST JSON. Đọc tham số request, checksum riêng của từng command, response rồi bảng mã.

| Trường | Điều cần nhớ |
| --- | --- |
| vnp_TxnRef / vnp_TransactionNo | Tham chiếu merchant / mã provider |
| vnp_TransactionDate | Ngày tạo payment gốc, không phải ngày hoàn |
| vnp_CreateDate / vnp_RequestId | Ngày / mã yêu cầu mới |
| vnp_TransactionType | 02 hoàn toàn phần; 03 hoàn một phần |
| vnp_ResponseCode / vnp_TransactionStatus | Kết quả API / trạng thái giao dịch, không đánh đồng |

Status 05/06 vẫn đang xử lý, chưa được thông báo “đã hoàn”. Mã refund 94 yêu cầu đã được gửi, không gửi lại mù quáng. Xác minh chữ ký và giao dịch trả về.

Đối chiếu `VNPayFullRefundRequest` và `VNPayRefundGateway`. Quy tắc của dự án: hoàn số tiền thực thu theo policy đã chốt; lưu request trước khi gửi; timeout chuyển Unknown để đối soát; query ra payment gốc thành công không chứng minh refund thành công. Adapter pass unit test không đủ để bật `Payments:VNPayRefund:Enabled`.

## 4. Thông tin cần xin cho FIN01

Đây là checklist chuẩn bị của dự án, không khẳng định VNPAY hỗ trợ sẵn mọi mục:

- Merchant sandbox đã được phép refund qua API chưa? Nếu devreg chỉ cấp PAY, quy trình mở quyền refund là gì?
- Endpoint/phiên bản refund và query; giao dịch test nào được hoàn; số tiền/giới hạn/thời gian hoàn theo từng phương thức.
- Cách tra cứu chính xác refund khi timeout sau khi provider nhận lệnh; querydr trả payment hay refund trong từng tình huống?
- Quy tắc RequestId trùng, retry, thời gian chờ, SLA và dấu hiệu xác nhận cuối cùng.
- IP whitelist/callback nếu áp dụng; report đối soát và đầu mối hỗ trợ tích hợp.

Sau khi có quyền: test payment sandbox → xác nhận IPN → hủy trước ca → refund request → xác nhận/đối soát. Mỗi bước đối chiếu DB/ledger; còn phải test mất mạng, callback lặp và restart worker. Không chuyển sang live chỉ vì happy path pass.

## 5. FIN02: xin đúng tài liệu chi hộ

Không suy ra endpoint chi hộ từ tài liệu PAY/refund. Dùng [kênh liên hệ VNPAY chính thức](https://vnpay.vn/lien-he) hoặc đầu mối merchant hiện có. Cần provider xác nhận có hỗ trợ mô hình CareSitter và cấp đúng bộ tài liệu:

- Tạo lệnh chi, tra cứu, callback; API xác minh người hưởng nếu có.
- Auth/chữ ký, version, môi trường sandbox, tài khoản/người hưởng test.
- Idempotency, mã tham chiếu ngoài, trạng thái pending/unknown và điều kiện final Paid.
- Nguồn tiền, hạn mức, phí, SLA, ngân hàng hỗ trợ và báo cáo đối soát.
- Điều kiện ký hợp đồng, vận hành và chuyển sang live.

Trong code, cần sửa việc approve ghi PAYOUT trước xác nhận thực chi. Approved chỉ là được duyệt; Paid phải có bằng chứng provider. Thiếu hợp đồng API thì giữ tích hợp chưa hoàn thành, không tự dựng API hoặc chuyển tiền thử bằng tài khoản thật.

## 6. Mẫu nội dung bạn gửi VNPAY

> Chào VNPAY, bên mình phát triển CareSitter: customer thanh toán dịch vụ chăm sóc qua cổng VNPAY; khi customer hủy trước ca, cần hoàn 100% thực thu về phương thức gốc. Sau ca, cần chi tiền công vào tài khoản caregiver. Nhờ xác nhận sản phẩm và điều kiện phù hợp cho mô hình này, cung cấp đặc tả refund/query và chi hộ/payout, quyền sandbox, bộ giao dịch thử, quy tắc timeout/idempotency/callback, SLA và báo cáo đối soát. Xin hướng dẫn quy trình đăng ký/quyền API và đầu mối kỹ thuật.

Bạn tự gửi qua kênh chính thức; chưa có tin nhắn nào được gửi thay bạn. Khi nhận tài liệu, gửi link hoặc bản đã che thông tin nhạy cảm. Không gửi HashSecret, API key, mật khẩu, OTP hay sao kê thật vào chat; không commit credential vào Git hoặc nhúng vào Flutter/admin. Giữ cấu hình sandbox/live tách biệt.
