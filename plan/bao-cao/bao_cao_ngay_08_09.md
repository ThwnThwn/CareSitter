# Báo cáo ngày 09/08 - Ghi chú luồng chính CareSitter

## 1. Hiện trạng luồng booking chính

Luồng customer đặt lịch sang caregiver hiện đã chạy theo booking thật từ backend:

- Customer app gọi backend `POST /api/v1/bookings` để tạo booking.
- Booking được lưu trong PostgreSQL tại bảng `booking.bookings`.
- Demo flow hiện tự gọi `POST /api/v1/bookings/{id}/confirm-payment` để chuyển booking từ `pending_payment` sang `confirmed`.
- Caregiver app lấy ca mở từ backend qua `GET /api/v1/bookings?status=open`.
- Ca mở chỉ là booking thật có `status = CONFIRMED` và `caregiver_id = null`.
- Caregiver có thể nhận ca qua `POST /api/v1/bookings/{id}/accept`.
- Caregiver có thể từ chối ca qua `POST /api/v1/bookings/{id}/decline`.
- Nếu caregiver đã từ chối một ca, backend lưu record `REJECTED` trong `booking.booking_assignments`, nên ca đó không hiện lại cho caregiver đó sau khi app refresh/polling.

## 2. Các chỉnh sửa đã thực hiện gần đây

- Bỏ auto booking ảo/mock bên caregiver. Caregiver app không tự seed sample booking nữa.
- Sửa customer khi chọn hệ thống tự tìm caregiver: không gửi cố định `caregiverId`, để booking thành ca mở thật cho caregiver nhận.
- Sửa demo payment: sau khi tạo booking, customer app tự confirm payment để booking đi sang trạng thái `confirmed`.
- Sửa caregiver polling mỗi 10 giây để tự kéo booking mới khi app đang mở.
- Sửa backend trả thêm thông tin hiển thị cho booking response: `beneficiaryName`, `caregiverName`, `addressText`, `serviceName`.
- Sửa caregiver app dùng các field thật từ backend thay vì fallback ID/địa chỉ/dịch vụ giả.
- Sửa customer app parse datetime từ API sang giờ local/VN để đồng bộ giờ với caregiver.

## 3. Firebase hiện dùng để làm gì

Firebase hiện chỉ dùng cho Firebase Cloud Messaging (FCM):

- App lấy FCM token sau khi user đăng nhập.
- App gửi token lên backend qua `POST /api/v1/auth/devices`.
- Backend dùng Firebase Admin SDK để gửi push notification khi cần.

Firebase hiện chưa dùng cho:

- Auth chính.
- Lưu booking.
- Lưu user/caregiver/customer.
- Realtime booking chính.
- Upload ảnh KYC.

Luồng hiện tại:

- App đang mở: dùng API polling và SignalR.
- App chạy nền/tắt: dùng Firebase FCM push notification.

## 4. Hangfire hiện dùng để làm gì

Hangfire đang chạy các job nền cho lifecycle booking:

- `expire-pending-payments`: chạy mỗi 1 phút, tự hủy booking `pending_payment` quá 15 phút.
- `alert-late-checkins`: chạy mỗi 5 phút, cảnh báo caregiver trễ check-in.
- `auto-complete-shifts`: chạy mỗi 5 phút, tự hoàn tất ca `in_progress` quá giờ kết thúc 30 phút.

Lưu ý: job `alert-late-checkins` đang có khả năng lỗi do event type `LATE_CHECKIN` chưa khớp check constraint trong database. Đây là lỗi phụ cần dọn để log sạch, không phải nguyên nhân banner booking sai.

## 5. Phần còn thiếu để lên production

Phần lớn nhất còn thiếu là thanh toán thật:

- Chưa tích hợp cổng thanh toán thật như MoMo, ZaloPay, VNPay hoặc Stripe.
- Hiện `confirm-payment` đang là demo escrow bằng ledger nội bộ.
- Chưa có webhook/IPN production từ cổng thanh toán để tự xác nhận giao dịch.
- Chưa hoàn chỉnh refund/cancel sau khi thanh toán thật.

Ngoài thanh toán, vẫn còn các phần cần hoàn thiện:

- Hoàn thiện thêm matching nâng cao và kiểm thử với dữ liệu production lớn.
- KYC gating chặt hơn: chỉ caregiver đã duyệt KYC mới thấy/nhận ca.
- Dọn lỗi Hangfire `LATE_CHECKIN` với DB constraint.
- Hoàn thiện report/checklist/timeline và ảnh bằng chứng cho ca chăm sóc thật.

## 6. Kết luận hiện tại

Nếu mục tiêu là demo end-to-end:

- Customer tạo booking thật.
- Booking lưu backend/PostgreSQL.
- Caregiver thấy ca thật.
- Caregiver nhận hoặc từ chối ca.
- Nếu từ chối thì ca không hiện lại cho caregiver đó.

Nếu mục tiêu là app production:

- Thanh toán thật vẫn là phần quan trọng nhất cần làm tiếp.
- Matching caregiver và push notification cho ca mở đã được nối vào bước confirm thanh toán; phần cần làm tiếp là kiểm thử với dữ liệu thật và hoàn thiện cổng thanh toán.

## 7. Matching 3 phase đã triển khai

- Phase 1 - Hard Filter: chỉ xét caregiver `APPROVED`, đang `ONLINE`, đúng quận hoặc nằm trong bán kính phục vụ, đủ kỹ năng bắt buộc, có slot rảnh theo đúng khung giờ, không trùng booking và chưa từ chối booking.
- Phase 2 - Soft Ranking: chấm điểm theo khoảng cách, rating, kỹ năng, kinh nghiệm và các trọng số trung lập cho acceptance/response time. Kết quả được lưu vào `booking.booking_assignments` cùng rank, score và breakdown để audit.
- Phase 3 - Offer Expansion: sau khi customer confirm thanh toán, hệ thống mời top N caregiver và lưu trạng thái `OFFERED`; sau thời gian cấu hình, Hangfire đánh dấu `EXPIRED`, mở rộng sang nhóm tiếp theo và gửi thông báo mới.

Cấu hình matching nằm trong `ApiHost/appsettings.json` ở section `Matching`. Hiện `AllowCaregiversWithoutAvailabilitySlots=true` để tương thích dữ liệu demo chưa có slot; khi caregiver đã khai báo availability đầy đủ có thể chuyển thành `false`.
