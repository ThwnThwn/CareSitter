# Khôi phục mật khẩu trong ứng dụng CareSitter

**Cập nhật:** 06/10/2026. Đã triển khai backend và giao diện customer/caregiver.
Tài liệu này mô tả phần đang có trong source; chat hỗ trợ vẫn theo kế hoạch riêng.

## 1. Cách sử dụng

1. Trong màn hình đăng nhập, chọn **Quên mật khẩu?**.
2. Nhập email khôi phục đã xác minh; chọn **Gửi mã khôi phục**.
3. Nhập mã 6 chữ số nhận qua email, rồi đặt và xác nhận mật khẩu mới.
4. Sau thành công, đăng nhập lại. Mọi access/refresh session cũ đều bị thu hồi.

Mã khôi phục không phải OTP đăng nhập. Mã chỉ dùng một lần, mặc định có
hiệu lực 10 phút; sau xác minh, quyền đặt mật khẩu chỉ còn 5 phút.
Gửi lại phải chờ 60 giây; tối đa 5 yêu cầu/email/giờ và 5 lần thử mã.
Mật khẩu cần ít nhất 8 ký tự, một chữ hoa, một chữ số và tối đa 72 byte UTF-8.

Hai app có **Cài đặt → Email khôi phục** để xem trạng thái và xác minh.
Email đăng nhập cũng là email khôi phục. Đổi email của tài khoản dùng mật
khẩu cần mật khẩu hiện tại và mã gửi tới địa chỉ mới; email chỉ thay đổi
sau khi xác minh, rồi mọi phiên bị thu hồi. Form hồ sơ không đổi email trực tiếp.

## 2. Điều kiện tài khoản và dữ liệu cũ

Self-service reset dành cho CUSTOMER/CAREGIVER đang ACTIVE, chưa xóa,
có mật khẩu và email đã xác minh; loại trừ mọi tài khoản mang role ADMIN.
Không tự mở khóa LOCKED/SUSPENDED, không phục hồi tài khoản đã xóa.

- Email cũ không được tự đánh dấu đã xác minh. Người còn truy cập email
  có thể đăng nhập bằng OTP email để chứng minh quyền sở hữu, hoặc xác
  minh trong cài đặt khi đã đăng nhập.
- Google login chỉ chấp nhận email được Google xác minh; chỉ ghi nhận
  bằng chứng khi email Google khớp email hiện tại của user.
- Tài khoản Google/OTP chưa có mật khẩu tiếp tục dùng phương thức đó.
  Không tự cấp mật khẩu qua reset. Có thể xác minh email hiện tại; đổi
  email của tài khoản này cần quy trình hỗ trợ riêng.
- Mất email, nghi bị chiếm tài khoản, tài khoản có ADMIN hoặc bị khóa:
  cần đơn vị vận hành xác minh và xử lý. Chức năng này chưa tự động hóa
  việc xác minh danh tính hoặc hỗ trợ ngoài đăng nhập.
- Reset không thay đổi liên kết Google, vai trò hay trạng thái tài khoản.

Thông báo yêu cầu gửi mã giống nhau cho email đủ/không đủ điều kiện,
không công khai userId/role/trạng thái. SMTP chạy nền, không nằm trên đường
trả response. Request có sàn thời gian 250–349 ms để giảm chênh lệch;
đây không phải bảo đảm thời gian tuyệt đối khi DB/network quá tải.

## 3. API đã có

| Endpoint | Dữ liệu chính | Kết quả |
| --- | --- | --- |
| POST `/api/v1/auth/password-recovery/request` | email | 202; challengeId, expiresIn, resendAfter, message |
| POST `/api/v1/auth/password-recovery/verify` | challengeId, code | 200; resetToken, expiresIn |
| POST `/api/v1/auth/password-recovery/reset` | resetToken, newPassword, confirmPassword | 204; đổi mật khẩu và thu hồi phiên |
| POST `/api/v1/profile/recovery-email/request` | JWT, newEmail tùy chọn, currentPassword khi đổi email | 202; mã xác minh hoặc thay đổi chờ xác minh |
| POST `/api/v1/profile/recovery-email/confirm` | JWT, challengeId, code | 200; email, emailVerifiedAt, sessionsRevoked |
| GET `/api/v1/profile` | JWT | Thêm emailVerifiedAt và hasPassword |

Các API verify/reset từ chối mã/token sai, hết hạn hoặc đã dùng. Reset
token không phải JWT và không cấp quyền cho API hồ sơ. HTTP có giới hạn
20 thao tác/10 phút/IP/ApiHost; giới hạn gửi theo email/user và thử mã
được bảo vệ bằng PostgreSQL. Khi chạy nhiều ApiHost, cần giới hạn IP
chia sẻ ở gateway; bộ đếm IP trong process không cộng dồn giữa instance.

## 4. Dữ liệu và giao dịch

Migration [35-identity-password-recovery.sql](../../backend/init-db/35-identity-password-recovery.sql):

- `identity.users`: thêm `email_verified_at`, `recovery_version`.
- `identity.recovery_challenges`: purpose, email binding, phiên bản,
  HMAC mã, số lần thử, thời hạn và dấu sử dụng; grant hash/thời hạn nằm
  cùng record sau verify, có unique index. Không có bảng grant riêng.
- `identity.recovery_email_outbox`: payload mã hóa AES-GCM, lease, retry,
  thời hạn, dấu hoàn tất và trạng thái PENDING/SENT/SKIPPED/FAILED.

Reset khóa user rồi challenge; kiểm điều kiện/phiên bản; đổi BCrypt hash,
thu hồi refresh session, vô hiệu mã/grant, audit và ghi email thông báo
trong cùng transaction. Verify đồng thời chỉ phát một grant; reset đồng
thời chỉ một lần thành công. Gửi mã mới vô hiệu cả mã/grant reset trước.

Issue/rotate session dùng khóa user. Kết quả kiểm mật khẩu cũ không được
phát phiên ở phiên bản mới. Access validation tiếp tục đọc database;
Redis cũ không cho phép hồi sinh phiên. OTP đăng nhập cũng gắn user/version,
nên mã phát trước reset/đổi email/trạng thái/quyền bị từ chối.

Kết nối care-tracking của user trên ApiHost xử lý reset được ngắt sau
commit. Watchdog kiểm phiên các kết nối mỗi 5 giây, gồm instance khác;
JWT hết hạn đóng kết nối. Không cam kết ngắt tức thời mọi replica.

Không còn nhập session Redis kiểu cũ vào DB. Thiết bị chỉ có session/OTP
ở định dạng cũ cần đăng nhập/yêu cầu mã lại. Redis lookup cache có thể
chưa hết TTL nhưng không được dùng thay cho trạng thái DB.

Audit lưu hành động/user, không lưu mã/token/password hay nội dung email.
Mapping IP audit dùng PostgreSQL `inet` với converter phù hợp.

## 5. Cấu hình và chạy local

Local đã áp dụng migration 35, bật feature và tạo khóa riêng trong
`backend/.env`. Khóa không nằm trong tài liệu hoặc Git.

| Key | Mặc định/ý nghĩa |
| --- | --- |
| PasswordRecovery__Enabled | Code mặc định false; local đã bật true |
| PasswordRecovery__SecretKey | Ít nhất 32 ký tự ngẫu nhiên, bảo vệ HMAC và payload email |
| PasswordRecovery__CodeMinutes | 10 |
| PasswordRecovery__GrantMinutes | 5 |
| PasswordRecovery__ResendSeconds | 60 |
| PasswordRecovery__RequestsPerHour | 5 |
| PasswordRecovery__MaxAttempts | 5 |
| PasswordRecovery__MetadataRetentionDays | 7; cho phép 1–30 |
| Smtp__* | Dùng SMTP hiện có; username, App Password, STARTTLS |

Giữ SecretKey ổn định qua restart và giữa các replica. Đổi khóa làm mã
đang chờ không xác minh được và payload cũ không giải mã được; cần tắt
feature, xử lý hàng đợi đang chờ và phát mã mới theo quy trình vận hành.

Từ thư mục `backend`, chạy API hiện có:

```powershell
dotnet run --project caresitter-be/ApiHost/CareSitter.ApiHost.csproj
```

Hai app dùng BASE_URL trỏ tới API local như hiện tại. Hot reload chưa đủ
nếu API đang chạy binary cũ; cần restart API và chạy lại app với source mới.
Không cần bật Kafka để dùng khôi phục mật khẩu.

## 6. SMTP, retry và vận hành

Worker lấy mail theo lease `FOR UPDATE SKIP LOCKED`, tối đa 10 bản ghi
mỗi lượt; kiểm mã còn hiệu lực trước gửi. Lỗi SMTP retry theo backoff,
tối đa 5 lần. Payload bí mật bị xóa sau gửi/bỏ qua/hết lượt thử/hết hạn.
Email thông báo mật khẩu đã đổi không chứa mật khẩu và được gửi độc lập
với transaction reset. Mail lỗi không rollback mật khẩu đã đổi.

Không bảo đảm email chỉ gửi đúng một lần: crash sau SMTP nhận mail nhưng
trước ghi SENT có thể gửi lại cùng mã; việc dùng mã vẫn là một lần.
Mail FAILED cần người dùng yêu cầu mã mới, không khôi phục payload đã xóa.
Worker dọn metadata hết hạn/cũ theo thời hạn cấu hình mỗi giờ; audit giữ
theo chính sách audit hiện có. Theo dõi log cảnh báo/lỗi của worker và số
mail pending/failed; chưa bổ sung dashboard metric/alert tự động riêng.

```sql
SELECT status, count(*) FROM identity.recovery_email_outbox GROUP BY status;
SELECT min(created_at) FROM identity.recovery_email_outbox WHERE status = 'PENDING';
```

Trước production: áp dụng migration, đặt khóa qua secret manager, xác nhận
SMTP gửi được đến tài khoản thử được phép và chốt quy trình xử lý mất email.
Rollback tắt feature; giữ bảng/audit và không drop dữ liệu người dùng.

## 7. Bằng chứng kiểm tra

- Backend build .NET 8: không lỗi/cảnh báo.
- Identity unit: 15 trường hợp đạt; kiến trúc: 30 trường hợp đạt.
- Nhóm tích hợp auth/security/SQL/registration/result: 76 trường hợp đạt,
  gồm 11 kiểm thử khôi phục dùng database PostgreSQL riêng và HTTP/SignalR thật.
- Hai app: 20 widget test mới đạt; kiểm tra các bước, sai mã, timeout,
  token hết hạn, retry, chống bấm lặp, xác minh email và chữ lớn ở 320/430/1024.
- Flutter analyze phần thay đổi và build web hai app đạt.
- Browser QA dùng API fixture để kiểm luồng và hình ảnh; không thay cho
  kiểm SMTP thật hoặc nghiệm thu trên điện thoại Android/iOS.

Đã kiểm SMTP failure/retry qua adapter thử, chưa gửi email thật tới người
dùng hoặc nghiệm thu trên thiết bị thật trong lượt này.

Các nguyên tắc mã dùng một lần, phản hồi thống nhất, xác nhận mật khẩu và
thu hồi phiên tham khảo [OWASP Forgot Password](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html).

## 8. Source chính

- [PasswordRecoveryService](../../backend/caresitter-be/Modules/Identity/Infrastructure/PasswordRecoveryService.cs)
- [RecoveryEmailDispatcher](../../backend/caresitter-be/Modules/Identity/Infrastructure/RecoveryEmailDispatcher.cs)
- [PasswordRecoveryController](../../backend/caresitter-be/Modules/Identity/Controllers/PasswordRecoveryController.cs)
- [Customer recovery screen](../../frontend/customer-app/lib/features/auth/presentation/screens/password_recovery_screen.dart)
- [Caregiver recovery screen](../../frontend/caregiver-app/lib/features/auth/presentation/screens/password_recovery_screen.dart)
- [PostgreSQL/HTTP/SignalR tests](../../backend/tests/CareSitter.IntegrationTests/PasswordRecoveryTests.cs)
