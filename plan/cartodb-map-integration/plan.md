# Plan: Tích hợp CartoDB Map Tiles cho CareSitter

Mức rủi ro: thông thường — Cập nhật cấu hình tile và EnvConfig trên hai app. Không thay đổi schema DB, xác thực hay nghiệp vụ backend.

## Mục tiêu
1. Cho phép ứng dụng tải bản đồ CartoDB Voyager mượt mà, sắc nét, không bị dính watermark `API KEY REQUIRED`.
2. Hỗ trợ cấu hình `CARTO_API_KEY` linh hoạt qua `EnvConfig` (`--dart-define`, file config hoặc fallback an toàn).
3. Đồng bộ trải nghiệm hiển thị bản đồ nhất quán giữa Customer App (theo dõi live) và Caregiver App (xem chi tiết ca, bản đồ ca).

## Tiến độ
- [x] `phase-01-env-config`: Cấu hình `CARTO_API_KEY`, `MAP_PROVIDER`; CARTO là mặc định, Google Maps cần bật riêng trên customer-app.
- [x] `phase-02-map-widgets`: Cấu hình tile chung cho cả ba màn; tham số đúng `key`, subdomain, retina, ghi nguồn luôn hiển thị và fallback khi thiếu key.
- [x] `phase-03-local-config-docs`: File JSON mẫu, `.env.local` được Git bỏ qua ở cả hai app và hướng dẫn bằng tiếng Việt.
- [x] `phase-04-verification`: 19 kiểm thử customer-app và 17 kiểm thử caregiver-app đã qua; analyze cả hai app không báo lỗi. Build Web cả hai app thành công.
- [ ] Xác minh CARTO hiển thị bản đồ thật bằng key Basemaps hợp lệ. Token đầu tiên đã lưu trong env nhưng CDN trả ảnh `API KEY REQUIRED` với HTTP 200; local tạm dùng `MAP_PROVIDER=osm`, người dùng đang cập nhật key mới.

Hướng dẫn chạy và bật tùy chọn Google: [hướng dẫn sử dụng](huong-dan-su-dung.md).
