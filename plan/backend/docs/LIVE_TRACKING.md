# Theo dõi caregiver đang đến — MVP

Source triển khai ngày 05/10/2026. MVP chạy một API instance và hai app ở foreground. Tính năng mặc định tắt để áp migration trước khi bật.

## Cấu hình bằng env

Các khóa dưới đây đã có trong `backend/.env.example`, `.env` local và hai env mẫu của deploy. ASP.NET đọc dấu `__` thành section tương ứng; không cần appsettings.

```dotenv
LiveTracking__Enabled=false
LiveTracking__SendIntervalSeconds=10
LiveTracking__LeaseSeconds=120
LiveTracking__RetentionHours=24
LiveTracking__MaxSampleAgeSeconds=60
LiveTracking__MaxFutureSkewSeconds=30
```

Áp dụng `init-db/33-booking-live-locations.sql` theo [quy trình SQL](MIGRATIONS.md), đối chiếu schema/role của môi trường, sau đó đặt `LiveTracking__Enabled=true` và khởi động lại API. Không cần đổi endpoint bản đồ. Code và test không tự áp migration lên DB hiện có.

SQL có một trigger theo dõi status/caregiver_id. Cả đường API, admin, job tự hoàn tất và hoàn tiền đều đi qua trigger khi cập nhật booking. Test PostgreSQL chạy các trạng thái COMPLETED/CANCELLED/REFUNDED, hai thứ tự tranh chấp GPS với complete, FK cascade, hết hạn, chuyển phiên và quyền của role không sở hữu bảng. Quyền role production cần đối chiếu riêng: USAGE schema, SELECT/INSERT/UPDATE/DELETE bảng, USAGE sequence; trigger không nâng quyền SECURITY DEFINER.

## Luồng API và app

1. Caregiver bấm bắt đầu đi → cập nhật booking sang en-route → GET trạng thái để xác minh → xin quyền vị trí → `POST /api/v1/bookings/{id}/gps/session` với `sourceInstanceId` UUID.
2. API trả sessionId, version, leaseUntil, sendIntervalSeconds và serverTime. Retry cùng source còn lease trả lại cùng phiên, không gia hạn nếu chưa có fix mới.
3. `POST .../gps` nhận sessionId, latitude, longitude, capturedAt và tùy chọn accuracyMeters/speed/heading. Backend kiểm JWT → People mapping → phân công trong transaction → trạng thái → phiên/lease → thời gian/rate → ghi vị trí. Body không nhận caregiverId.
4. HTTP 204 cho mẫu đã xử lý; gói có capturedAt trùng/cũ không ghi lại, không gia hạn lease, không phát event. 429/503 có Retry-After. 409 phiên hết hạn cần xác minh booking rồi cấp lại; 403/404/409 trạng thái hoặc 410 dừng sender.
5. Customer đăng ký listener trước khi join group rồi GET `.../gps/latest` (`Cache-Control: no-store`). Hợp nhất snapshot/event theo version; bỏ tọa độ của người được phân công trước đó. GET 404 nghĩa là chưa có vị trí hợp lệ, 410 nghĩa là flag đang tắt.
6. SignalR reconnect chờ join lại thành công mới báo sẵn sàng; mọi kết quả ngoài `ok` giữ chế độ dự phòng. Retry cả lỗi kết nối lần đầu. Mỗi 30 giây màn hình đang mở đối chiếu booking/latest để phục hồi gói bị mất, kể cả broadcast thất bại sau commit.
7. Sau check-in, dừng sender và chỉ hiện trạng thái chăm sóc. Mẫu gửi trễ bị từ chối. Khi hoàn thành/hủy/hoàn tiền, trigger xóa dòng; cleanup theo hạn lưu xử lý dữ liệu còn sót.

## Giảm ghi DB và bảo vệ dữ liệu

- Chỉ giữ một hàng/booking, không lưu lộ trình. Một hàng vẫn sinh phiên bản MVCC/WAL khi update; không đồng nghĩa dung lượng vật lý luôn cố định. Fillfactor 70, autovacuum riêng và không index cột tọa độ/thời gian thường thay đổi giúp giảm chi phí.
- Lease chặn hai thiết bị gửi đồng thời. Sequence toàn cục giữ thứ tự qua lần xóa/tạo lại.
- GPS gửi vào group `customer-{customerId}` do Hub gán từ JWT. Caregiver cũ còn trong group booking không nhận tọa độ của người thay thế. Không ghi tọa độ hoặc token vào log.
- Dữ liệu đã xóa khỏi bảng vẫn có thể tồn tại trong WAL/backup theo chính sách lưu trữ hệ thống.
- Redis dùng cho cache chưa giải quyết fanout SignalR. Không scale API nhiều instance trước khi có backplane và kiểm thử phân tán.

## Kiểm thử và nghiệm thu

Kiểm thử tự động mới:

- `LiveLocationPostgresTests`: dữ liệu mới nhất, stale/duplicate, lease/takeover, timestamp/rate, cleanup, terminal trigger với role thường, hai thứ tự race, REST handler phân quyền, dừng sau check-in, FK cascade.
- `LiveLocationSecurityTests`: số không hữu hạn/ngoài phạm vi, session thiếu, phạm vi broadcast riêng customer.
- `live_tracking_controller_test.dart`: từ chối quyền, chỉ một upload, giữ mẫu mới nhất, logout lúc request đang chạy, dừng lúc kiểm trạng thái, pause/resume, Retry-After.
- `gps_update_test.dart`: dữ liệu lỗi, REST cũ hơn SignalR, hoàn thành/đổi người, version sau xóa/tạo lại.
- `care_signalr_service_test.dart`: rejoin trước thông báo, từ chối mọi kết quả khác ok, nhiều màn hình cùng group, retry kết nối đầu.

Baseline backend đã **qua 2 lượt liên tiếp**, mỗi lượt 439 test (25 architecture, 221 integration và 193 unit), schema sạch + nâng cấp + replay cùng smoke HTTP. Bằng chứng: `backend/artifacts/phase7/20261005-081815-dc5e2e5b/summary.json` và TRX trong thư mục cùng tên. Lệnh chạy lại: `./backend/scripts/test-phase7.ps1 -Repeat 2 -SkipFrontend -ApiPort 5137`. Hai app cũng đã qua `flutter analyze --no-pub` và `flutter test --no-pub`.

### Số đo DB local ban đầu — 05/10/2026

PostgreSQL 16.4 trong Docker, DB riêng, 200 booking giả lập, 20 client, 4 worker, 30 giây, nhịp tổng mục tiêu 20 transaction/giây, seed 42. Script khóa booking FOR SHARE rồi cập nhật một dòng live location; đây là tải SQL qua Unix socket, **không bao gồm EF/API, JWT, mạng di động hoặc SignalR**. Bảng đã chạy một lượt warm-up trước lần ghi nhận này.

| Chỉ số | Kết quả |
| --- | --- |
| Giao dịch / lỗi | 577 / 0 |
| Tốc độ thực tế | 19,26 transaction/giây |
| Độ trễ SQL trung bình / độ lệch chuẩn | 2,957 ms / 0,718 ms |
| Hàng sau tải / sau hoàn thành tất cả ca | 200 / 0 |
| HOT updates / tổng updates | 577 / 577 |
| Dead tuples lúc lấy mẫu | 6 |
| Tổng kích thước relation (cả index) | 90.112 byte |
| WAL cluster tăng trong khoảng đo | 174.216 byte |

Log và script được lưu local tại `backend/artifacts/gps-bench-*.sql`, `gps-bench-load-final.log`, `gps-bench-results-final.log`. Đây là smoke test dung lượng/khóa/xóa, chưa xác định tải tối đa hoặc cam kết hiệu năng production. WAL là chênh lệch cluster, có thể bao gồm tác vụ nền.

Hai app đã qua analyze: caregiver 23 test, customer 63 test. Chưa nghiệm thu thiết bị thật: GPS ngoài đường, khóa màn hình, pin, chênh đồng hồ, độ trễ end-to-end và tải API/SignalR. Android/iOS background chưa triển khai. Customer thấy vị trí cũ sau 60 giây; caregiver được thông báo chỉ chia sẻ khi mở ứng dụng. Không công bố ETA hoặc số đo end-to-end khi chưa thử.
