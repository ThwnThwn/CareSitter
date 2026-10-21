# Rà soát các luồng chính backend — 03/10/2026

Phạm vi: backend .NET 8 trong `D:\EXE\CareSitter`; thay đổi local, chưa commit/push.

## Các lỗi đã sửa

| Luồng | Lỗi được xác nhận | Thay đổi |
| --- | --- | --- |
| Nhận ca, check-in, checkout | EF ghi `latitude/longitude` nhưng schema timeline thiếu cột; nhận ca che lỗi này bằng thông báo trùng lịch. | Migration 30 bổ sung cột timeline/GPS, backfill tọa độ PostGIS và đồng bộ hai cách lưu bằng trigger. Chỉ bắt lỗi constraint lịch/slot và concurrency thực sự. |
| Nhận ca | Caregiver đã được chọn trước hoặc có offer không được kiểm tra lại KYC. | Kiểm tra KYC APPROVED ngay trong transaction nhận ca. |
| Hủy ca | `Release()` bỏ qua slot COMMITTED, khiến slot ca đã hủy tiếp tục chặn lịch. | Giải phóng cả HELD và COMMITTED. Test chứng minh booking khác có thể giữ lại cùng slot. |
| Dời lịch | Booking đổi giờ nhưng slot giữ nguyên; giá và phí của booking đã thanh toán có thể bị ghi đè. | Cập nhật booking và slot cùng transaction. Từ chối thay đổi tổng tiền đã thu; giữ snapshot phí/thu nhập/thời hạn khiếu nại đã thanh toán. Dời lịch cùng giá vẫn được phép. |
| Checkout có bất thường | Customer/job có thể hoàn tất ca có cờ NeedsReview; job không kiểm tra checklist chưa xong. | Ca NeedsReview phải được admin duyệt. Job bỏ qua ca cần review, task pending hoặc task bắt buộc bị bỏ qua. Ca quá giờ với checklist chưa xong được gắn NeedsReview. |
| Đồng bộ trạng thái | Job tự yêu cầu checkout/tự hoàn tất thiếu delta-sync; thông báo checkout được gửi trước khi lưu. | Ghi sync event cùng thay đổi trạng thái và lưu trước khi phát thông báo. |
| Callback thanh toán | Sự kiện PaymentSucceeded gửi lại khi booking đã được nhận gây lỗi; số tiền sự kiện không được đối chiếu với booking. | Dùng sync event xác nhận đã lưu làm dấu xử lý để nhận lại sự kiện an toàn; kiểm tra số tiền trước khi xác nhận. |

## Kiểm chứng

- Trước sửa: 185 test pass, 14 test PostgreSQL chưa được bật. Bộ test mới tái hiện các lỗi slot, dời lịch, KYC, review và schema timeline; hai test bổ sung tái hiện lỗi callback lệch tiền/gửi lại.
- Sau sửa: **214/214 test pass, 0 fail, 0 skip** trên toàn bộ `backend/CareSitter.sln`.
- Có **15 test mới** trong `MainBookingFlowTests.cs`, chạy handler và persistence trên PostgreSQL thật. Mỗi test có database tạm riêng và tự dọn sau khi chạy.
- Chuỗi kiểm chứng: sự kiện thanh toán → sinh checklist → nhận ca → di chuyển → từ chối check-in ngoài geofence → check-in đúng GPS → hoàn thành checklist → yêu cầu checkout → customer xác nhận; có kiểm tra timeline, tọa độ PostGIS và delta-sync.
- Các test sẵn có về đăng nhập, phân quyền, refresh token, webhook, tranh chấp, refund, payout, settlement, khuyến mãi và race condition cũng pass.
- Bằng chứng chạy toàn bộ: `backend/artifacts/main-flow-review-2026-10-03/*.trx`.

## Cách dùng thay đổi trên database local

Migration mới được kiểm tra trên database tạm; chưa áp dụng vào database phát triển hiện có. Khi cập nhật local, chạy từ gốc repository:

```powershell
./backend/scripts/update-db.ps1 -From 30 -SkipStart
```

Migration 30 là thay đổi bổ sung cột/trigger, không xóa booking, timeline hoặc dữ liệu GPS. Không cần reset database.

## Phần còn cần quyết định hoặc kiểm thử ngoài môi trường test

- **Khách hủy đơn đã thanh toán:** code hiện chưa có quy trình hoàn tiền tương ứng. Tỷ lệ hoàn/phạt và cách xử lý cần được chủ sản phẩm chốt; đã hỏi người dùng, chưa tự áp dụng chính sách hoàn 100% hoặc trừ phí. Sửa nhả slot không đồng nghĩa đã hoàn tiền.
- **Callback lệch số tiền:** hiện ngăn xác nhận sai và giữ sự kiện chưa xử lý trong outbox để retry/điều tra. Chưa có quy trình tự động bù chênh lệch/hoàn tiền hoặc màn hình xử lý riêng cho trường hợp này.
- Test dùng stub cho dịch vụ ngoài như routing, gửi thông báo và catalog lookup. Chưa chạy giao dịch thật qua VNPay, gửi OTP/email/push thật, hay nghiệm thu end-to-end ba frontend.
- Đây là đợt rà soát tập trung vào luồng chính; không phải chứng nhận đã kiểm tra hết mọi endpoint và tình huống vận hành.
