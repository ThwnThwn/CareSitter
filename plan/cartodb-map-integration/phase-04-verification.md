# Phase 04: Xác minh tự động và kiểm thử

## Mục tiêu
Đảm bảo tất cả các bài kiểm tra tự động của cả hai ứng dụng đều vượt qua và không phát sinh lỗi phân tích mã tĩnh (lint/analyze).

## Các bước kiểm tra
1. `customer-app`:
   ```powershell
   flutter analyze --no-pub
   flutter test --no-pub test/core/maps test/features/shift_tracking test/core/realtime/gps_update_test.dart test/core/realtime/care_signalr_service_test.dart
   ```
2. `caregiver-app`:
   ```powershell
   flutter analyze --no-pub
   flutter test --no-pub test/core/maps test/features/shifts
   ```

## Tiêu chí hoàn thành
- 36 kiểm thử liên quan đều qua: 19 customer-app, 17 caregiver-app; analyze toàn bộ hai app không báo lỗi.
- Build Web hai app thành công. Kiểm tra giao diện ở 320 px với cỡ chữ 140%; ghi nguồn bên ngoài thẻ thông tin/nút mở preview. Không có yêu cầu Google Maps trong chế độ mặc định/dự phòng.
- Kiểm tra trực tiếp token đầu tiên: hai ảnh tile trả HTTP 200 nhưng nội dung là `API KEY REQUIRED`; chưa đạt tiêu chí bản đồ CARTO thật. Chờ key Basemaps mới, không coi HTTP 200 là đủ để xác minh key.
- Chưa build iOS trên Mac hoặc kiểm tra CARTO với giới hạn header app native. Kiểm thử SDK Google dùng adapter giả, không gọi dịch vụ Google trả phí.
