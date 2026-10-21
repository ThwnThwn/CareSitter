# Quyết định và ghi nhớ — caregiver live tracking MVP

Cập nhật: 05/10/2026. Đã triển khai source backend và hai app; chưa triển khai lên môi trường đang dùng. Hướng dẫn: [LIVE_TRACKING.md](docs/LIVE_TRACKING.md).

## Quyết định đã áp dụng trong source

| Nội dung | Triển khai |
| --- | --- |
| Lưu dữ liệu | Một dòng/booking trong `booking.live_locations`; không ghi GPS định kỳ vào timeline/notification/gps_tracks. |
| Dừng/xóa | Check-in dừng gửi và GET không trả GPS; trigger xóa COMPLETED/CANCELLED/REFUNDED hoặc đổi phân công; FK cascade khi xóa booking. |
| Phiên | Session do server cấp, source ID theo lần chạy app, lease 120 giây; chặn thiết bị thứ hai khi lease còn hiệu lực. |
| Version | Sequence PostgreSQL toàn cục, không reset sau khi xóa/tạo lại. REST và SignalR cùng version. |
| Chu kỳ | 10 giây khi di chuyển, 30 giây khi đứng yên; một request đang gửi và một mẫu mới nhất chờ. |
| Lưu dự phòng | 24 giờ từ mẫu được chấp nhận; quá 60 giây hiện vị trí cũ; cleanup mỗi 5 phút. |
| Transaction | Khóa booking trước dòng vị trí; FOR SHARE khi ghi GPS, FOR UPDATE khi cấp phiên; phát event sau commit. |
| Quyền GPS | Group customer tự gán theo JWT nhận tọa độ; group booking chỉ nhận trạng thái/timeline. REST kiểm quyền riêng. |
| Topology | MVP một API instance; Redis cache hiện có chưa phải SignalR backplane. |
| Mobile | Foreground-only; vào nền dừng gửi; quay lại kiểm booking trên server. Không tự khôi phục GPS từ storage. |
| Bản đồ | Dùng lại flutter_map/OSM có attribution; bỏ ETA đường thẳng và khoảng cách cố định. |
| Cấu hình | `.env`/biến môi trường; không đặt tracking trong appsettings. Flag mặc định false đến khi áp migration 33. |
| Controller | 27 controller dùng constructor IMediator + `private readonly IMediator _mediator` + `_mediator.Send`. |
| Encoding | UTF-8; bổ sung comment giải thích cơ chế khóa, phiên và phạm vi chia sẻ. |

Các test tự động và giới hạn nghiệm thu được ghi trong runbook. Smoke tải SQL local: 200 booking, 577 cập nhật/30 giây, không lỗi, giữ 200 dòng và xóa còn 0 khi hoàn thành; số đo chi tiết nằm trong runbook. Deployment thực tế, pin, GPS ngoài đường, latency end-to-end, tải API/SignalR và Android/iOS máy thật chưa được đo. Module gợi ý thực đơn vẫn là đầu việc riêng trong `plan/tong-quan/MEAL_RECOMMENDATION_PLAN.md` và `NUTRITION_ANALYSIS_SPEC.md`.
