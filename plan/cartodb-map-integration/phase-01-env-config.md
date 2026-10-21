# Phase 01: Cấu hình CARTO_API_KEY trong EnvConfig

## Mục tiêu
Khai báo biến môi trường `CARTO_API_KEY` trong `EnvConfig` của cả 2 ứng dụng Flutter để đọc từ `--dart-define` hoặc file `.env` cục bộ.

## File cần chỉnh sửa
1. `frontend/customer-app/lib/core/config/env_config.dart`
   - Đọc `CARTO_API_KEY` và `MAP_PROVIDER` qua define, sau đó fallback về cấu hình public `.env` hiện có.
   - Bổ sung helper getter hoặc fallback an toàn nếu không truyền key.
2. `frontend/caregiver-app/lib/core/config/env_config.dart`
   - Đọc và trim `CARTO_API_KEY`, mặc định `MAP_PROVIDER=carto`. File `.env.local` được đọc qua `--dart-define-from-file` khi build.

## Tiêu chí hoàn thành
- Cả hai app biên dịch được mà không phụ thuộc cứng vào key bí mật trong git.
