# Kế hoạch phối hợp REST, gRPC, Kafka và SignalR

> Cập nhật: 16/10/2026. Trạng thái: **backlog sau khi hoàn thiện Nutrition**. Tài liệu ghi lại quyết định kiến trúc đã đối chiếu với source hiện tại; chưa phải bằng chứng đã benchmark hoặc chạy production. Markdown lưu local, không commit/push nếu chưa có yêu cầu riêng.

## 1. Quyết định cốt lõi

CareSitter giữ mô hình giao tiếp theo ranh giới triển khai và nhu cầu phản hồi:

| Ranh giới | Cơ chế | Quyết định |
| --- | --- | --- |
| Flutter → ApiHost | REST/JSON | Giữ public API ổn định, dễ xác thực, quan sát và hỗ trợ mobile |
| ApiHost → Nutrition service | gRPC/Protobuf trên HTTP/2 | Giữ gateway hiện tại; bổ sung kiểm thử lỗi, tracing và vận hành |
| Nutrition → People trong ApiHost | Internal REST/JSON | Giữ cho đến khi số liệu tải/độ trễ hoặc việc tách People thành service độc lập chứng minh cần đổi |
| Module cùng tiến trình ApiHost | Interface/MediatR | Không tạo network hop giữa các module đang cùng process |
| Sự kiện sau khi nghiệp vụ đã commit | Kafka + transactional outbox/inbox | Dùng cho notification, analytics và side effect không cần trả kết quả ngay |
| Theo dõi ca và chat trực tiếp | SignalR | Giữ cho cập nhật realtime có kiểm tra quyền theo booking/conversation |

Không dùng Kafka cho request cần kết quả đồng bộ. Không đưa hồ sơ bệnh lý đầy đủ lên event chung. Không mở gRPC trực tiếp cho Flutter trong phạm vi hiện tại.

## 2. Hiện trạng đã có trong source

- `ApiHost/Nutrition/NutritionGatewayController.cs` cung cấp REST public cho ứng dụng.
- `ApiHost/Nutrition/NutritionGrpcGateway.cs` gọi Nutrition bằng gRPC, truyền bearer token, service key, deadline và giới hạn message.
- `services/nutrition/protos/nutrition.proto` có các RPC capabilities, command, đọc resource, danh sách meal plan và lựa chọn đổi bữa.
- AppHost cấu hình endpoint Nutrition gRPC dùng HTTP/2 riêng.
- `PeopleHealthClient` đọc health snapshot bằng internal REST có service authentication và timeout.
- ApiHost đã đăng ký Kafka event `MealPlanSelected`; shared messaging đã có nền outbox/inbox.
- ApiHost đã dùng SignalR cho care tracking và support chat.

Các điểm trên chỉ xác nhận wiring trong source. Chưa có benchmark so sánh REST/gRPC và chưa xác nhận toàn bộ đường truyền trên production.

## 3. Backlog triển khai sau Nutrition

### P0 — kiểm chứng đường truyền

1. Chạy smoke `Flutter/HTTP client → ApiHost REST → Nutrition gRPC → People REST → PostgreSQL` trên môi trường test.
2. Ghi latency từng chặng, status/error, trace ID và tỷ lệ timeout; không ghi raw health profile.
3. Kiểm tra khi Nutrition dừng, People timeout, token hết hạn và response gRPC sai contract.
4. Xác nhận HTTP/2, TLS và service credential ở staging.

### P1 — độ tin cậy và quan sát

1. Chuẩn hóa mapping `DeadlineExceeded`, `Unavailable`, `Unauthenticated`, `PermissionDenied`, validation và conflict sang HTTP.
2. Truyền cancellation/deadline xuyên suốt; đặt ngân sách thời gian cho toàn chuỗi thay vì cộng timeout độc lập.
3. Chỉ retry read hoặc lệnh ghi có idempotency được kiểm chứng; không retry ghi mù.
4. Nối distributed tracing REST → gRPC → REST, metric latency/error và cảnh báo Kafka consumer lag/DLQ.

### P2 — contract và sự kiện

1. Sau khi schema Nutrition ổn định, thay dần `data_json` trong Protobuf bằng message có kiểu; giữ tương thích phiên bản cũ trong giai đoạn chuyển đổi.
2. Mọi integration event có `eventId`, schema version, occurred time, correlation ID và partition key phù hợp.
3. Producer ghi outbox cùng transaction nghiệp vụ; consumer dùng inbox/unique key và chịu được phát lại.
4. Event Nutrition chỉ mang định danh/version và dữ liệu tối thiểu; consumer cần chi tiết phải gọi API nội bộ được cấp quyền.

### P3 — quyết định mở rộng gRPC bằng số liệu

Chỉ cân nhắc chuyển Nutrition → People sang gRPC hoặc tách thêm service khi có ít nhất một lý do đo được: cần deploy độc lập, contract được nhiều service dùng, tải đồng bộ cao, payload/latency REST trở thành nút thắt hoặc yêu cầu streaming. Nếu các module còn cùng process, tiếp tục dùng interface/MediatR.

## 4. Checklist nghiệm thu

- [ ] Public REST không lộ endpoint/credential nội bộ.
- [ ] gRPC service chỉ nhận caller và user identity hợp lệ.
- [ ] Deadline, cancellation và giới hạn message có test lỗi.
- [ ] Lệnh ghi có idempotency key; retry không tạo resource trùng.
- [ ] Trace nối được REST → gRPC → People và không chứa dữ liệu sức khỏe nhạy cảm.
- [ ] Kafka producer có outbox; consumer có inbox/dedup, retry hữu hạn và DLQ.
- [ ] Có runbook khi Nutrition/People/Kafka không khả dụng.
- [ ] Có số liệu staging trước khi đổi thêm REST sang gRPC.

