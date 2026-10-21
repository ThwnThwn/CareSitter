# Kafka cho môi trường local

`docker-compose.yml` khởi động Apache Kafka 3.9.1 ở chế độ KRaft trong nhóm
Compose `backend` hiện có. Dữ liệu Kafka được lưu trong volume; API tiếp tục
chạy trực tiếp trên Windows.

Chạy các lệnh sau từ thư mục gốc của repository:

```powershell
docker compose -f backend/docker-compose.yml up -d kafka kafka-init
docker compose -f backend/docker-compose.yml ps -a kafka kafka-init kafka-storage-init
```

Container `caresitter-kafka` cần có trạng thái `healthy`. Hai container khởi tạo
cần kết thúc với mã `0` (`Exited (0)`): một container thiết lập quyền ghi cho
volume, container còn lại tạo các topic. Có thể chạy lại bước khởi tạo topic
mà không tạo trùng các topic đã tồn tại.

API hoặc worker chạy trên Windows kết nối qua `localhost:9092`. Tiến trình
chạy trong mạng Compose kết nối qua `kafka:29092`. Cổng dành cho Windows chỉ
được mở trên địa chỉ loopback. Nếu đổi `KAFKA_PORT` trong `backend/.env`,
hãy đổi cổng trong `KAFKA_BOOTSTRAP_SERVERS` cho khớp.

Ba topic sự kiện có 3 partition mỗi topic; mỗi topic `.dlq` có 1 partition.
Partition là phần chia của topic để phân phối dữ liệu cho consumer. DLQ là
topic lưu các bản tin chưa xử lý được sau khi áp dụng chính sách lỗi.
Cả 6 topic giữ dữ liệu trong 7 ngày và dùng hệ số nhân bản bằng 1.
Tên topic và tên DLQ tùy chỉnh dùng cùng các biến `KAFKA_TOPIC_*` như môi trường triển khai.

## Cấu hình API

Chép phần cấu hình Kafka từ `backend/.env.example` vào `backend/.env`.
Với database local đã tồn tại, cần áp dụng migration SQL bổ sung trước khi
đặt `KAFKA_ENABLED=true`. Chạy từ thư mục gốc của repository:

```powershell
powershell -ExecutionPolicy Bypass -File backend/scripts/update-db.ps1 -From 34 -ContainerName caresitter-db -SkipStart
```

Khởi động lại API sau khi thay đổi biến môi trường. Từ thư mục gốc, chuyển
vào `backend` rồi chạy API để DotNetEnv tìm được `backend/.env`:

```powershell
Set-Location backend
dotnet run --project caresitter-be/ApiHost/CareSitter.ApiHost.csproj
```

Các cờ bật từng luồng mặc định là `false`. Vì vậy, luồng thông báo và thanh
toán hiện có vẫn hoạt động khi hạ tầng Kafka đã sẵn sàng. Khi cần phát sự kiện
thanh toán qua Kafka, đặt `KAFKA_FLOW_PAYMENTS_ENABLED=true`.
Giữ luồng Nutrition ở trạng thái tắt cho đến khi có nghiệp vụ phát sự kiện thực tế.

Luồng thông báo cần thêm `NotificationWorker` chạy riêng, cùng một khóa dịch
vụ giữa API và worker, và thông tin xác thực của nhà cung cấp gửi thông báo.
Compose local chỉ khởi động hạ tầng; API và `NotificationWorker` được chạy riêng.
Để chạy worker trên Windows, cung cấp các biến môi trường cho tiến trình,
đặt cả `KAFKA_ENABLED` và `KAFKA_FLOW_NOTIFICATIONS_ENABLED` thành `true`,
và dùng `KAFKA_SUPPORT_API_URL=http://localhost:5033/`.
Worker đọc biến môi trường của tiến trình, không tự nạp `backend/.env`.

Lệnh sau chạy từ thư mục gốc của repository:

```powershell
dotnet run --project backend/caresitter-be/Services/NotificationWorker/CareSitter.NotificationWorker.csproj
```

## Kiểm tra và khởi động lại

Chạy từ thư mục gốc của repository:

```powershell
docker exec caresitter-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:29092 --describe
docker compose -f backend/docker-compose.yml restart kafka
```

Khởi động lại broker vẫn giữ volume `backend_caresitter-kafkadata`.
Hệ số nhân bản bằng 1 cho phép phục hồi sau khi broker khởi động lại nếu
volume còn nguyên; cấu hình này không bảo vệ dữ liệu khi mất volume.
