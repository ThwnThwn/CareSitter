# Rà soát và bổ sung quy ước CareSitter

> Ngày: 08/10/2026. Phạm vi: đối chiếu tài liệu được gửi với source/config/CI hiện tại; tổ chức lại tài liệu local. Không phải audit bảo mật toàn hệ thống.

Quy ước đầy đủ nằm ở [QUY_UOC_CODE_VA_SECRET.md](QUY_UOC_CODE_VA_SECRET.md). Bản gốc là nền tảng tốt cho backend/Flutter và phân tách secret, nhưng một số tên và quy tắc chưa khớp repository.

## Những chỗ đã sửa

| Điểm trong bản được gửi | Điều chỉnh và lý do |
| --- | --- |
| `Shared.Domain`, module `Caregiver`/`Payment` | Dùng `CareSitter.SharedKernel`, `CareSitter.Contracts`, module `People`/`Payments` và cấu trúc thực tế trong repository |
| Mọi thay đổi schema tạo EF migration | Dự án dùng SQL trong `backend/init-db`; EF runtime migration bị chặn. Không tạo hai cơ chế nâng schema cạnh tranh |
| Webhook luôn trả `200` nhanh | Xác thực và lưu bền trước ACK, xử lý bản tin hợp lệ lặp an toàn; lỗi chữ ký/dữ liệu và lỗi tạm thời theo hợp đồng phản hồi |
| Đóng SignalR trong mọi `dispose()` | Chỉ dọn subscription/group do màn hình sở hữu; service dùng chung quản lý kết nối và reconnect |
| JSON/DB enum quy về `UPPER_SNAKE` | Giữ codec hiện tại, tránh làm gãy status booking đang dùng `lower_snake_case` |
| Env `PayOS__*`, `Jwt__SigningKey`, `ConnectionStrings__Default` | Tên chạy thật là `Payments__PayOS__*`, `Jwt__SecretKey`, `ConnectionStrings__CareSitter` |
| Flutter dùng `API_BASE_URL` | Dùng `BASE_URL`/`HUB_BASE_URL`; caregiver đọc dart-define, customer chỉ fallback asset cho một số cấu hình public |
| Validate ApiKey ở mọi lần startup | Validate theo cờ Enabled; provider tắt không yêu cầu credential và không tự bật |
| Cách nạp `.env`/User Secrets chưa rõ | API có DotNetEnv trước builder; không suy diễn .NET/worker mặc định đọc env hoặc User Secrets khi chưa cấu hình |
| `.gitignore` đủ ngăn secret lên Git | File đã tracked vẫn được Git theo dõi; phải review staged diff và xử lý credential đã lộ riêng |

## Những phần trước đây còn thiếu

- Quy tắc gom Markdown vào `plan/`, viết tiếng Việt, cập nhật link, ngày/trạng thái/bằng chứng và không push MD theo yêu cầu hiện tại.
- Admin React/TypeScript/Vite và landing Next.js, đặc biệt biến client public và nơi giữ credential server.
- Authorization theo quyền sở hữu bản ghi, giới hạn API/upload và cách giữ response tương thích.
- Idempotency ở server/DB, payment state/ledger/đối soát; không tin return URL để xác nhận tiền.
- OTP/khôi phục mật khẩu: mã riêng một lần, giới hạn thử, thu hồi phiên và không tự mở tài khoản admin khóa.
- Kafka outbox/inbox, phiên bản event, retry/DLQ/replay; MediatR event không tự trở thành message bền.
- Quyền và lifecycle GPS, vị trí cũ, giới hạn polling, phân biệt foreground/background tracking.
- CARTO là provider chính, Google là tùy chọn; client token có thể bị đọc sau build, cần quản lý scope/usage thay vì coi env là kho giấu key.
- Test PostgreSQL thật cho lock/tiền, không tính skip là pass; chọn kiểm tra theo rủi ro và tách test local khỏi nghiệm thu thiết bị/provider thật.
- Migration, backup/restore/rollback và release gate có bằng chứng.

## Giới hạn cần theo dõi tiếp

1. Các quy tắc bổ sung là chuẩn cho thay đổi mới. Chưa rà từng endpoint, module và job để chứng nhận toàn bộ code cũ tuân thủ.
2. Chưa cài/xác minh secret scanner tự động hoặc rà toàn bộ lịch sử Git trong công việc này. Quy tắc ignore certificate/credential trong tài liệu không thay thế việc kiểm tra từng đường dẫn khi thêm file mới.
3. Migration runner còn hạn chế đã được mô tả trong [runbook](backend/docs/MIGRATIONS.md), gồm lịch sử checksum bootstrap và bảo đảm chỉ một runner. Đổi quy ước không tự sửa runner.
4. Bản đồ CARTO còn cần key Basemaps hợp lệ như [hướng dẫn](cartodb-map-integration/huong-dan-su-dung.md). Không bật thử provider/đổi credential trong đợt dọn Markdown này.
5. Tài liệu lịch sử giữ ngày và kết quả đã ghi; chuyển thư mục không làm báo cáo cũ trở thành xác nhận trạng thái ngày hôm nay. Các tên API, enum và mã lỗi giữ nguyên để dễ đối chiếu source.

## Bằng chứng đối chiếu

- [API startup và loader env](../backend/caresitter-be/ApiHost/Program.cs).
- [Module Payments và Options](../backend/caresitter-be/Modules/Payments/PaymentsModule.cs), [PayOSOptions](../backend/caresitter-be/Modules/Payments/Application/Models/PayOSOptions.cs), [Controller webhook](../backend/caresitter-be/Modules/Payments/Controllers/PayOSController.cs).
- [Backend env mẫu](../backend/.env.example), [migration SQL](../backend/init-db), [Gitignore](../.gitignore).
- [Booking status codec](../backend/caresitter-be/Modules/Booking/Infrastructure/BookingStatusCodec.cs).
- [Customer config](../frontend/customer-app/lib/core/config/env_config.dart), [caregiver config](../frontend/caregiver-app/lib/core/config/env_config.dart).
- [SignalR dùng chung](../frontend/customer-app/lib/core/realtime/care_signalr_service.dart).
- [Admin API](../frontend/admin-web/src/api.ts), [manifest admin](../frontend/admin-web/package.json), [CI](../.github/workflows/ci.yml).
