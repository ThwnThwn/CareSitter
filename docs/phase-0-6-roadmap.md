# CareSitter roadmap: Phase 0–6

## Nguyên tắc thực hiện

- Backend và database là nguồn dữ liệu chuẩn; giao diện không tự báo thành công.
- Mỗi phase phải hoàn thành đủ contract, phân quyền, trạng thái UI, kiểm thử và tài liệu liên quan.
- Không chuyển phase khi còn lỗi build hoặc happy path chính của phase chưa chạy được.

## Phase 0 — Chuẩn hóa nền tảng

**Mục tiêu:** loại bỏ hành vi giả và thống nhất cách ứng dụng phản hồi lỗi thật.

**Phạm vi**

- Chuẩn hóa lỗi Dio cho Customer và Caregiver.
- Hiển thị rõ lỗi validation, mạng, timeout, xác thực, phân quyền, conflict và lỗi server.
- Không ép `application/json` cho multipart upload.
- Loại bỏ `Future.delayed` dùng để giả lập thao tác thành công.
- Các tính năng chưa có contract phải hiện trạng thái chưa hỗ trợ.
- Rà loading, empty và error state của các luồng gọi API.

**Tiêu chí hoàn thành**

- Không còn màn hình báo thành công khi backend chưa ghi nhận dữ liệu.
- Upload `FormData` không bị header JSON làm hỏng.
- Hai app không có lỗi build mới từ thay đổi Phase 0.

**Trạng thái:** đã hoàn thành baseline; các thay đổi đang nằm trên branch `update/upload-asset`.

## Phase 1 — Hoàn thiện API contract KYC và Support

**Mục tiêu:** mở lại hai chức năng đã bị khóa ở Phase 0 bằng luồng thật end-to-end.

**Phạm vi**

- Mở rộng KYC để lưu ảnh mặt trước, mặt sau CCCD và danh sách chứng chỉ.
- Upload ảnh qua media endpoint vào thư mục Cloudinary dành riêng cho KYC.
- Chỉ chuyển KYC sang `PENDING` sau khi đủ CCCD và URL ảnh bắt buộc.
- Trả dữ liệu tài liệu KYC thật trong hồ sơ caregiver.
- Mở rộng Support Ticket với tiêu đề, mô tả và danh sách tệp đính kèm.
- Validate loại ticket, độ ưu tiên, độ dài nội dung và URL.
- Kết nối form Support Caregiver với API thật; có loading và lỗi backend.
- Bổ sung script nâng cấp cho database đang tồn tại.

**Tiêu chí hoàn thành**

- Caregiver nộp KYC thành công và DB lưu đủ URL tài liệu.
- Màn trạng thái đọc đúng trạng thái và danh sách tài liệu từ backend.
- Form hỗ trợ tạo được ticket thật và trả về mã ticket.
- Backend build, Flutter analyze phần thay đổi và test contract đều đạt.

## Phase 2 — Hoàn thiện hồ sơ Customer/Caregiver

**Mục tiêu:** mọi chỉnh sửa hồ sơ quan trọng được lưu server và tải lại nhất quán.

**Phạm vi**

- CRUD người được chăm sóc, lịch sử sức khỏe, dị ứng, thuốc và liên hệ khẩn cấp.
- Hồ sơ Customer, avatar và địa chỉ mặc định.
- Hồ sơ Caregiver, kỹ năng, kinh nghiệm, vùng phục vụ và trạng thái sẵn sàng.
- Kiểm tra ownership cho Customer/Caregiver và quyền đọc/duyệt của Admin.
- Đồng bộ cache local với server, xử lý refresh và dữ liệu rỗng.

**Tiêu chí hoàn thành**

- Dữ liệu vẫn đúng sau logout/login hoặc cài lại app.
- User không đọc/sửa được hồ sơ không thuộc quyền của mình.
- Các màn profile có loading, empty, error và retry rõ ràng.

## Phase 3 — Ổn định Booking và Matching

**Mục tiêu:** tạo booking, giữ lịch và phân phối ca không trùng hoặc mất trạng thái.

**Phạm vi**

- Rà contract tạo booking và toàn bộ state transition.
- Kiểm tra caregiver availability và caregiver slot hold.
- Chống hai khách giữ cùng caregiver/khung giờ bằng constraint và xử lý `409`.
- Matching top candidates, offer, accept, decline, hết hạn và mở rộng offer.
- Thông báo rõ khi không còn caregiver phù hợp.
- Bảo đảm thao tác lặp không tạo assignment trùng.

**Tiêu chí hoàn thành**

- Một slot chỉ có một booking thắng khi request đồng thời.
- Accept/decline/expire đều đưa booking và assignment về trạng thái hợp lệ.
- Có test state transition, race và idempotency chính.

## Phase 4 — Thanh toán VNPay và Escrow

**Mục tiêu:** thanh toán quyết định booking chính xác, an toàn và có thể đối soát.

**Phạm vi**

- Chuẩn hóa biến môi trường VNPay Sandbox và URL công khai.
- Xác minh HMAC SHA512, amount, `TxnRef` và trạng thái giao dịch.
- Gom Return/IPN về một dịch vụ finalize idempotent.
- Đồng bộ PaymentIntent, slot hold, booking và matching sau thanh toán.
- Ghi ledger escrow, phí nền tảng và thu nhập caregiver không trùng.
- Hết hạn hoặc thất bại phải release slot.
- Bổ sung test Payments đang còn thiếu.

**Tiêu chí hoàn thành**

- IPN lặp không tạo ledger/offer trùng.
- Số tiền trên Customer, Caregiver, PaymentIntent và ledger khớp nhau.
- Happy path, sai chữ ký, sai amount, timeout và payment fail đều được test.

## Phase 5 — Thực hiện ca và báo cáo công việc

**Mục tiêu:** caregiver thực hiện ca từ di chuyển đến hoàn tất với bằng chứng thật.

**Phạm vi**

- En-route, GPS, check-in và kiểm tra điều kiện thời gian/vị trí.
- Checklist nhiệm vụ, ghi chú và upload ảnh minh chứng.
- SOS và cảnh báo check-in trễ.
- Checkout request, customer/admin review, auto-confirm và dispute.
- Hoàn tất ca, giải ngân escrow và cập nhật thu nhập.
- Timeline hiển thị cùng một nguồn dữ liệu cho hai app.

**Tiêu chí hoàn thành**

- Không thể nhảy sai thứ tự trạng thái ca.
- Ảnh/báo cáo được upload, lưu URL và xem lại được.
- Checkout chỉ giải ngân một lần; dispute chặn auto-settlement đúng cách.

## Phase 6 — Realtime và thông báo

**Mục tiêu:** hai app nhận thay đổi kịp thời nhưng vẫn phục hồi đúng khi mất kết nối.

**Phạm vi**

- SignalR cho booking, matching, GPS, checklist và checkout.
- Reconnect có backoff, refresh token và chống tạo nhiều connection.
- Cấu hình Firebase thật cho Android/iOS và backend service account.
- Đăng ký, refresh và thu hồi FCM token theo thiết bị/user.
- Push cho booking offer, thanh toán, thay đổi ca, SOS và support.
- Deep link từ notification vào đúng booking/ticket.
- Đồng bộ lại từ REST sau reconnect để không phụ thuộc hoàn toàn vào event.

**Tiêu chí hoàn thành**

- Mất mạng rồi kết nối lại không mất trạng thái và không nhận event trùng.
- Push hoạt động khi app foreground, background và terminated.
- Logout không còn nhận notification của tài khoản cũ.

## Thứ tự thực hiện

1. Khóa baseline Phase 0 bằng build/analyze và diff review.
2. Thực hiện Phase 1 theo thứ tự database → backend → app → test.
3. Chỉ bắt đầu Phase 2 sau khi KYC và Support chạy thật.
4. Phase 3 và 4 được kiểm thử cùng nhau ở các case race/timeout.
5. Phase 5 dùng state machine đã ổn định từ Phase 3–4.
6. Phase 6 hoàn thiện realtime/push trên các event đã ổn định từ Phase 3–5.
