# Phase 03: File mẫu cấu hình cục bộ và tài liệu

## Mục tiêu
Tạo điều kiện cho lập trình viên chạy app nhanh chóng bằng cách thêm cấu hình mẫu và cập nhật tài liệu.

## File cần chỉnh sửa
1. `frontend/customer-app/maps.local.example.json`
   - Bổ sung trường `"CARTO_API_KEY": ""`
2. `frontend/caregiver-app/maps.local.example.json` (tạo mới nếu chưa có)
   - Thêm file mẫu cấu hình tương tự.
3. Cập nhật tài liệu hướng dẫn chạy lệnh `flutter run --dart-define-from-file=...`.
4. Lưu token vào `.env.local` được Git bỏ qua ở cả hai app; thêm `MAP_PROVIDER` vào file mẫu. Không ghi token vào `.env` public đã được Git theo dõi của customer-app.

## Tiêu chí hoàn thành
- Không commit key thật vào git repository.
