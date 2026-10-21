# Hướng dẫn vận hành Kafka messaging

Tài liệu này dành cho stack triển khai trong thư mục `deploy`.
Để chạy trên máy Windows, xem [hướng dẫn Kafka local](../../backend/KAFKA_LOCAL.md).

## Cấu hình và bật luồng

1. Kiểm tra và áp dụng `backend/init-db/34-kafka-messaging.sql` bằng công cụ
   chạy migration SQL có đánh số hiện có. Không thêm EF migration lúc chạy
   ứng dụng hoặc sửa file SQL đã áp dụng. Migration mới chỉ bổ sung cấu
   trúc và yêu cầu các schema Support, Payments đã tồn tại.
2. Chép các biến cần dùng từ `deploy/kafka.env.example` vào `deploy/.env`.
   Tạo `KAFKA_INTERNAL_SERVICE_KEY` ngẫu nhiên dài 32–256 ký tự và dùng cùng
   một khóa cho API, worker. Giữ tất cả cờ bật luồng ở trạng thái tắt khi
   triển khai schema lần đầu.
3. Cấu hình thông tin xác thực nhà cung cấp bằng `GOOGLE_APPLICATION_CREDENTIALS`
   hoặc `Firebase__ServiceAccountPath`. Với email, dùng `Smtp__UserName`,
   `Smtp__Password` và tùy chọn `Smtp__FromName`. Không commit thông tin
   xác thực lên Git.
4. Sau khi kiểm tra việc chuyển sang luồng mới, bật thông báo bằng stack
   tùy chọn. Chạy lệnh từ thư mục gốc của repository:

```sh
docker compose --env-file deploy/.env -f deploy/compose.yml -f deploy/compose.kafka.yml up -d --build
```

File Compose bổ sung mặc định bật transport Kafka và luồng thông báo;
Payments vẫn tắt nếu chưa được bật rõ ràng. Worker chạy riêng chỉ đăng ký
nhận `NotificationRequested`. Endpoint HTTP nội bộ kiểm tra trạng thái
sẵn sàng là `/health/ready`; cổng worker không được mở ra ngoài.
Worker tham gia mạng `edge` để gọi nhà cung cấp qua Internet và mạng
`data` để truy cập broker, API nội bộ. Caddy vẫn chặn endpoint gửi thông báo nội bộ.

Bước khởi tạo bộ lưu trữ Kafka chỉ đổi chủ sở hữu thư mục log đã mount
sang UID/GID 1000, không xóa dữ liệu hiện có. Broker và container khởi tạo
dùng chung named volume, mạng và không mở cổng listener ra ngoài trong stack triển khai này.

Để dùng tên DLQ riêng, cấu hình `KAFKA_TOPIC_NOTIFICATIONS_DLQ`,
`KAFKA_TOPIC_PAYMENTS_DLQ` hoặc `KAFKA_TOPIC_NUTRITION_DLQ` nhất quán giữa
bước khởi tạo topic và các host. Nếu không cấu hình tên riêng, DLQ mặc định
là tên topic chính cộng thêm `.dlq`.

## Khi không kết nối được broker

Kiểm tra trạng thái health, log của broker và quyền sở hữu volume.
Không xóa volume để sửa lỗi khởi động. API commit dữ liệu nghiệp vụ và
outbox độc lập với việc Kafka có sẵn hay không. Các lần gửi thất bại giữ
nguyên ID sự kiện và tăng dần khoảng chờ thử lại, tối đa 5 phút cộng
một khoảng dao động ngẫu nhiên (jitter). Trạng thái readiness chuyển sang
`Degraded` khi không thể kết nối broker.

Khi Kafka hoạt động trở lại, các bản ghi chờ sẽ nhận lease và được phát.
Consumer lag là độ trễ giữa vị trí dữ liệu mới và vị trí consumer đã xử lý.
Chỉ số này được lưu lại sau mỗi lần commit thành công nên chỉ phản ánh
gần đúng; dùng công cụ quản lý consumer group của Kafka để xem trạng thái hiện tại.

## Khi số bản ghi outbox chờ tăng

Kiểm tra `outbox_pending`, `outbox_oldest_age_seconds`, log relay và bảng
`kafka_outbox_messages` của module sở hữu. Không tự đánh dấu bản ghi đã
phát chỉ để giảm số lượng chờ. Kiểm tra đăng ký sự kiện, tên topic, quyền
truy cập và phân loại lỗi trong `last_error`.
Lease hết hạn có thể được phục hồi tự động; relay cũ không thể hoàn tất
lượt xử lý đã được một chủ sở hữu mới nhận.

Trong MVP, giữ một relay cho mỗi host. Không tăng số instance relay của
API để kỳ vọng thứ tự toàn cục; bản thân việc thử lại outbox đã có thể
làm thay đổi thứ tự sự kiện.

## Khi DLQ tăng hoặc consumer dừng

Đối chiếu topic, partition, offset nguồn, ID sự kiện, tên consumer, số lần
thử và phân loại lỗi trong header của DLQ. Nếu phát vào DLQ thất bại,
offset nguồn chưa được commit và readiness bị suy giảm. Consumer quay
lại bản tin đó trước khi đọc bản tin tiếp theo.

Chính sách `Skip` commit offset nguồn sau khi đưa bản tin vào DLQ thành công.
Chính sách `Halt` đặt readiness thành `Unhealthy` và giữ offset nguồn chưa
commit. Cần điều tra, triển khai bản sửa rồi mới khởi động lại.
Hệ thống chưa có cơ chế tự phát lại DLQ.

Khi phát lại có kiểm soát, giữ nguyên `eventId` và xác nhận khoảng thời gian
chống trùng còn bao phủ sự kiện. Không reset hàng loạt offset của consumer
group production khi chưa kiểm tra rõ phạm vi.

## Quay về luồng xử lý cũ

Xử lý hết các bản ghi outbox chờ trước khi tắt transport hoặc thay luồng.
Một thông báo đã được đưa vào luồng worker phải hoàn tất ở đó; không đồng
thời gửi trực tiếp lần nữa. Tắt cờ của một luồng chỉ ảnh hưởng các sự kiện mới.

Nếu tắt luồng thông báo, cần dừng hoặc cấu hình lại worker tương ứng vì
worker yêu cầu cờ thông báo được bật khi khởi động.
File Compose triển khai gốc `deploy/compose.yml` giữ stack cũ không có Kafka.

Outbox MediatR của Payments độc lập và vẫn hoạt động với cả hai giá trị
của `KAFKA_FLOW_PAYMENTS_ENABLED`. Việc phát qua Kafka không thay đổi
`processed_on_utc` trong bảng outbox cũ. Cờ Nutrition phải giữ ở `false`
cho đến khi có producer và nghiệp vụ thực tế.

## Lệnh kiểm thử

Docker cần hoạt động để chạy bộ test messaging. Bộ test tạo các container
Apache Kafka và PostgreSQL độc lập, đồng thời dùng bộ gửi giả lập thay
cho nhà cung cấp thực tế. Chạy các lệnh từ thư mục gốc của repository:

```sh
dotnet test backend/tests/CareSitter.Messaging.Tests/CareSitter.Messaging.Tests.csproj
dotnet test backend/tests/CareSitter.ArchitectureTests/CareSitter.ArchitectureTests.csproj
dotnet test backend/CareSitter.sln --filter "Category!=MessagingDocker&Category!=PostgreSQL"
docker build -f backend/NotificationWorker.Dockerfile -t caresitter-notification-worker backend
```

Các kiểm tra này chưa xác nhận thông tin xác thực nhà cung cấp thực tế,
quyền role database production, khả năng phục hồi khi mất dữ liệu trên
đĩa hoặc luồng nghiệp vụ Nutrition. Cần kiểm tra các nội dung đó trong
môi trường triển khai trước khi bật luồng tương ứng.
