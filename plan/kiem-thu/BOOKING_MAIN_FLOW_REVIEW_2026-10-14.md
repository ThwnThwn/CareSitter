# Kiểm tra luồng đặt lịch chính

Cập nhật: 14/10/2026. Phạm vi: source hiện có của Booking/Payments, các test luồng chính và Customer booking. Các thay đổi source trước đó vẫn local, chưa commit/push. Đợt này rà source và chạy kiểm thử, giữ nguyên hành vi nghiệp vụ.

## Kết luận

Luồng chuẩn đã có đủ và qua kiểm thử local: chọn hồ sơ/dịch vụ/địa chỉ/giờ, tạo booking, chọn hoặc ghép caregiver, thanh toán, nhận ca, di chuyển/check-in, công việc và checkout/hoàn tất. Có kiểm owner, giá server, giữ chỗ, chuyển trạng thái, hủy/dời lịch, đối soát thanh toán và bảo vệ tiền khi xử lý đồng thời. Chưa chốt hoàn tất production vì tạo booking chưa có idempotency bền, còn nợ delivery thông báo và nghiệm thu ứng dụng/provider thật.

## Kiểm thử mới

Docker local đã hoạt động ngày 14/10; dùng container PostGIS riêng do runner tạo, không dùng DB ứng dụng hoặc container của dự án khác. Container test đã được dọn khi kết thúc.

| Phạm vi | Kết quả |
| --- | --- |
| Booking unit | 60 pass, 0 fail/skip |
| Payments unit | 134 pass, 0 fail/skip |
| Luồng Booking/Payments integration và race | **46/46 trong 3 lần liên tiếp**, 0 fail/skip; gồm 41 test dùng PostgreSQL/PostGIS thật và 5 test logic/ownership |
| Customer `test/features/booking` | **81 pass**, không fail |

Các ca integration gồm chặn trùng khung giờ, hủy và giải phóng slot, dời lịch rollback cùng hold, KYC khi nhận ca, check-in/timeline/GPS/checkout/hoàn tất, không tự hoàn tất ca thiếu task hoặc cần review, thanh toán sai giá, finalization/hoàn tiền/settlement lặp, một payOS checkout, mất response tạo link thanh toán, webhook trùng/sai chữ ký/thanh toán thiếu/trễ và đối soát trước hết hạn.

Lệnh từ gốc repo:

```powershell
./backend/scripts/test-races.ps1 -Repeat 3 -Filter 'FullyQualifiedName~MainBookingFlowTests|FullyQualifiedName~BookingTransactionIntegrityTests|FullyQualifiedName~PaymentRaceTests|FullyQualifiedName~PayOSPaymentTests|FullyQualifiedName~BookingFlowTests' -ArtifactsDirectory backend/artifacts/booking-flow-review-20261014/postgres
dotnet test backend/tests/CareSitter.Modules.Booking.UnitTests --no-restore
dotnet test backend/tests/CareSitter.Modules.Payments.UnitTests --no-restore
```

Trong `frontend/customer-app`:

```powershell
flutter test --no-pub test/features/booking --reporter expanded
```

Bằng chứng: [log integration và 3 lượt](../../backend/artifacts/booking-flow-review-20261014/postgres-run.log), [Booking unit](../../backend/artifacts/booking-flow-review-20261014/booking-unit.log), [Payments unit](../../backend/artifacts/booking-flow-review-20261014/payments-unit.log), [Customer booking](../../backend/artifacts/booking-flow-review-20261014/customer-booking.log).

## Phần còn thiếu theo ưu tiên

1. **Idempotency bền cho `POST /api/v1/bookings`.** Client tạo/gửi `Idempotency-Key`, nhưng controller/command/handler hiện chưa đọc và lưu key cùng kết quả/fingerprint theo owner. Mất response sau khi server commit chưa có cách gửi lại cùng key để nhận lại booking cũ; khóa chống trùng thời gian không thay replay kết quả. App hiện chuyển sang trạng thái chưa xác định và GET đối soát danh sách theo hồ sơ/địa chỉ/dịch vụ/giờ, không tự POST lại. Cần thêm lưu bền và test response loss, chạy đồng thời, key khác payload/owner và restart trước khi coi retry đã hoàn tất.
2. **Delivery sau commit của Booking.** Delta sync đã ghi bền và app có GET/polling phục hồi trạng thái. SignalR/notification hiện gọi qua `BookingPostCommitService.RunAsync`, lỗi được log nhưng chưa có replay bền riêng cho toàn bộ side effect Booking; domain events chưa tự dispatch/persist. Không nhầm với payment outbox đã có. Xem [issue đang có](../backend/docs/issues/booking-domain-events-not-dispatched-or-outboxed.md).
3. **Nghiệm thu thật.** PayOS tests dùng PostgreSQL thật và FakeBank, chưa gọi ngân hàng thật. Chưa đi hết hai app trên Android/iOS/staging với thanh toán thật, reconnect, logout và GPS thiết bị. Test xanh không chứng minh các bước này đã được nghiệm thu.

Nhánh ngoài geofence hiện từ chối check-in; timeline `CHECKIN_OUTSIDE_GEOFENCE` không được lưu do domain guard trả lỗi trước. Luồng trong geofence qua test; xem [issue](../backend/docs/issues/booking-checkin-outside-geofence-unreachable.md) khi xử lý yêu cầu quan sát lượt check-in bị từ chối.

Source đã đối chiếu: [create controller](../../backend/caresitter-be/Modules/Booking/Controllers/BookingsController.cs), [create handler](../../backend/caresitter-be/Modules/Booking/Application/Commands/Bookings/CreateBooking/CreateBookingCommandHandler.cs), [GET reconciliation](../../frontend/customer-app/lib/features/booking/presentation/controllers/booking_reconciliation_controller.dart), [payment result](../../frontend/customer-app/lib/features/booking/presentation/controllers/payment_result_controller.dart), [PayOS test fixture](../../backend/tests/CareSitter.IntegrationTests/PayOSPaymentTests.cs).
