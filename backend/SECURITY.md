# CareSitter security operations

Cập nhật: 2026-09-21.

Tài liệu này mô tả các kiểm soát đang có, quy trình khoá tài khoản/thu hồi phiên và cách xử lý sự cố truy cập. Không ghi token, mật khẩu, OTP, CCCD, số tài khoản, API key hoặc connection string vào ticket, chat hay log.

## Kiểm soát đang áp dụng

- Access token có thời hạn 5–60 phút, bắt buộc có `jti` và `sid`.
- `sid` liên kết access token với refresh session trong PostgreSQL. Request bị từ chối nếu session đã revoke/hết hạn hoặc tài khoản không còn `ACTIVE`.
- Refresh token chỉ lưu SHA-256 hash, rotate một lần và thu hồi toàn bộ session khi phát hiện reuse.
- Logout thu hồi session theo `sid`; đổi mật khẩu, khoá tài khoản hoặc đổi role thu hồi toàn bộ session của user.
- OTP hết hạn sau 10 phút, cooldown 60 giây, tối đa 5 lần gửi/giờ cho một định danh và khoá 15 phút sau 5 lần nhập sai.
- Auth endpoint có rate limit theo IP; password login dùng thông báo và BCrypt timing gần như nhau cho tài khoản không tồn tại hoặc sai mật khẩu.
- Google self-registration tách endpoint Customer/Caregiver; request chỉ nhận ID token và backend gán cứng role. Luồng này không thể tạo hoặc nâng quyền ADMIN.
- Endpoint nhạy cảm khai báo role boundary; application/domain vẫn kiểm tra ownership và state transition.
- Upload giới hạn 10 MB, chỉ nhận JPEG/PNG/WEBP và kiểm tra extension lẫn magic bytes.
- Production bắt buộc cấu hình JWT, encryption key và CORS allowlist; không có secret mặc định.
- Audit log lưu actor, role, action, entity, before/after, IP, user agent và thời gian. Payload nhạy cảm bị redaction.

## Khoá tài khoản và thu hồi phiên

1. Admin xác minh đúng user ID và lý do xử lý; không thao tác chỉ dựa trên tên hiển thị.
2. Gọi `PATCH /api/v1/admin/users/{id}/status` với `{"status":"LOCKED"}` hoặc thao tác tương ứng trên admin web.
3. API lưu trạng thái, thu hồi toàn bộ refresh session và ghi `ADMIN_USER_STATUS_UPDATED` vào `identity.audit_logs`.
4. Xác minh access token hiện tại nhận `401`, refresh token cũ không thể rotate và user không thể đăng nhập lại.
5. Ghi mã sự cố/ticket vào hồ sơ vận hành bên ngoài hệ thống; không đưa bằng chứng chứa secret vào audit payload.

Đổi role cũng thu hồi toàn bộ session để token cũ không tiếp tục mang role claim đã lỗi thời. Đổi mật khẩu thực hiện cùng chính sách.

## Xử lý sự cố quyền truy cập

### 1. Phát hiện và phân loại

- **Critical:** truy cập chéo ownership/role, chiếm quyền admin, sai escrow/wallet/ledger hoặc secret production bị lộ.
- **High:** session không thể thu hồi, brute force đang diễn ra, upload độc hại vượt kiểm soát hoặc audit bị mất trên thao tác nhạy cảm.
- **Medium/Low:** không có bằng chứng khai thác và không ảnh hưởng dữ liệu/tài chính tức thời.

Lưu thời điểm UTC, user/entity ID, route, correlation/request ID và action audit liên quan. Không sao chép raw token hoặc dữ liệu định danh nhạy cảm.

### 2. Cô lập

1. Khoá tài khoản bị nghi ngờ và xác minh toàn bộ session đã revoke.
2. Nếu có dấu hiệu lộ secret, rotate secret tại secret manager trước; sau đó restart workload và thu hồi credential cũ.
3. Nếu ảnh hưởng thanh toán, dừng thao tác admin reconciliation/payout nhưng không xoá ledger hoặc audit log.
4. Nếu lỗi phân quyền có thể khai thác rộng, tắt route/tính năng tại gateway hoặc rollback bản phát hành.

### 3. Điều tra

Các truy vấn mẫu chỉ trả metadata, không trả payload nhạy cảm:

```sql
SELECT created_at, actor_user_id, actor_role, action, entity_type, entity_id
FROM identity.audit_logs
WHERE actor_user_id = :user_id OR entity_id = :entity_id
ORDER BY created_at DESC;

SELECT id, user_id, device_id, issued_at, expires_at, revoked_at, replaced_by_id, ip_address
FROM identity.refresh_tokens
WHERE user_id = :user_id
ORDER BY issued_at DESC;
```

Đối chiếu `payment_intents`, `payout_requests` và `ledger_entries` bằng ID; không chỉnh sửa trực tiếp để “sửa số”. Mọi điều chỉnh tài chính phải đi qua command/endpoint idempotent có audit.

### 4. Khôi phục

1. Vá nguyên nhân gốc và thêm regression test âm tính.
2. Chạy `backend/scripts/security-check.ps1` và test PostgreSQL race trước khi triển khai.
3. Mở khoá tài khoản chỉ sau khi người dùng đổi credential và chủ sở hữu sự cố chấp thuận.
4. Theo dõi audit/auth/payment error tối thiểu 24 giờ sau khôi phục.
5. Viết post-incident review: timeline, impact, root cause, detection gap, corrective action và owner/deadline.

## Kiểm tra định kỳ

Chạy từ thư mục repo:

```powershell
powershell -ExecutionPolicy Bypass -File backend/scripts/security-check.ps1
```

Trước release còn phải chạy 7 PostgreSQL race test bằng `backend/scripts/test-races.ps1`. Kết quả mặc định của `dotnet test` có thể báo pass nhưng vẫn skip các test này nếu thiếu `CARESITTER_TEST_ADMIN_CONNECTION`.

## Rủi ro còn lại đã ghi nhận

- Counter rate-limit theo định danh đang dùng thao tác read/modify/write qua distributed cache; trước khi scale nhiều API replica cần chuyển sang Redis `INCR`/Lua nguyên tử. Mức hiện tại: medium.
- Magic-byte validation giảm file giả mạo nhưng chưa thay thế antivirus/content-disarm. Trước public launch cần bật Cloudinary transformation bắt buộc và cân nhắc malware scan. Mức hiện tại: medium.
- Access-session validation truy vấn PostgreSQL trên request xác thực; cần theo dõi latency và chỉ thêm cache nếu vẫn giữ cơ chế revoke fail-closed. Rủi ro hiện tại là hiệu năng, không phải bypass bảo mật.
- External penetration test chưa được thực hiện. Dependency audit và security contract test không thay thế kiểm thử xâm nhập độc lập.
