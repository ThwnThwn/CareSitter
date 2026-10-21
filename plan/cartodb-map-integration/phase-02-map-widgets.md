# Phase 02: Cập nhật URL CartoDB trong các Map Widget

## Mục tiêu
Đồng bộ các màn hình hiển thị bản đồ sang CARTO Voyager kèm tham số `key` theo tài liệu hiện hành, đồng thời hỗ trợ `subdomains` `['a', 'b', 'c', 'd']`. CARTO là mặc định; Google Maps chỉ được tải khi chọn riêng.

## File cần chỉnh sửa
1. `frontend/customer-app/lib/features/shift_tracking/presentation/widgets/live_caregiver_map.dart`
   - Cập nhật fallback tile layer hoặc tile layer chính sang CartoDB Voyager kèm `EnvConfig.cartoApiKey`.
   - Nếu `cartoApiKey` rỗng, giữ fallback về OpenStreetMap gốc để không làm hỏng app khi chưa có key.
2. `frontend/caregiver-app/lib/features/shifts/presentation/screens/shift_detail_screen.dart`
   - Dùng cấu hình tile chung có `?key=...` khi có key, ghi nguồn luôn hiển thị.
3. `frontend/caregiver-app/lib/features/shifts/presentation/screens/shift_map_screen.dart`
   - Chuyển `urlTemplate` sang CARTO Voyager kèm `subdomains` và `key`.

## Tiêu chí hoàn thành
- Mã tích hợp hoàn tất; widget test xác minh cả ba màn, ghi nguồn và cấu hình URL. Bản đồ CARTO thật cần key Basemaps hợp lệ; token local đầu tiên chưa được dịch vụ chấp nhận.
