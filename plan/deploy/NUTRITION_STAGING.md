# Triển khai staging Nutrition

Cập nhật: 13/10/2026. Đã viết cấu hình và kiểm thử local; **chưa triển khai trên server**. Docker local chưa chạy. Chưa có VPS/domain/SSH đích để thực hiện deploy, lấy chứng chỉ công khai hoặc kiểm kết nối thật. Tài liệu này giữ local, không commit/push.

## Phạm vi và ranh giới

Gói ở `deploy/nutrition/` bổ sung vào deployment VM hiện có, không thay Compose/AppHost dùng cho development. Đọc thêm [runbook Nutrition](../backend/NUTRITION_SERVICE_RUNBOOK.md) và [deployment chính](README.md).

```text
Customer → HTTPS công khai/Caddy → REST ApiHost
                                → gRPC HTTPS/HTTP2 Nutrition:8443
Nutrition → HTTPS ApiHost:8443 → People profile + Identity session
Nutrition → PostgreSQL nutrition-db → volume nutrition_pgdata riêng
```

Chỉ Caddy public 80/443. API, Nutrition, hai PostgreSQL và Redis không publish cổng host. `nutrition-data` là network nội bộ. Endpoint HTTP của Nutrition chỉ listen loopback trong container để phục vụ readiness; gRPC dùng TLS. Hai client kiểm CA nội bộ, hostname, thời hạn và server-auth EKU; không bỏ kiểm chứng chỉ.

API đợi Nutrition healthy; Nutrition đợi DB healthy. Readiness Nutrition kiểm DB/schema/role/RLS, không gọi API để tránh phụ thuộc khởi động vòng. Kiểm People/Identity là bước smoke sau khi toàn stack chạy.

Ba feature flag mặc định false. Triển khai hạ tầng không tự bật AI hoặc công thức. Provider AI thật, catalog đã review và nghiệm thu người dùng vẫn là phần việc riêng.

## Chuẩn bị trên Linux VM

Các lệnh bên dưới chạy **từ gốc repository trên VM**. Host cần Docker Compose, OpenSSL và `age-keygen`/`age`. Dùng [age chính chủ](https://github.com/FiloSottile/age) hoặc package đã xác minh. Ops image có PostgreSQL 16, age và curl hỗ trợ HTTP2.

1. Cấu hình DNS/domain/HTTPS, credential staging và `deploy/.env` theo deployment chính. `APP_ENVIRONMENT=Staging`; public API/CORS/callback phải đúng domain. JWT signing key/issuer/audience của Nutrition lấy cùng Identity staging; script không xoay JWT. Giữ cấu hình Vercel tự deploy tắt theo quyết định hiện tại.
2. Main DB cần schema hiện hành, gồm cột/trigger SQL 38. SQL 37–38 **đã áp local ngày 11/10**, chưa phải bằng chứng staging đã có. Kiểm schema/ledger của đúng main DB, sao lưu và chuẩn bị phục hồi trước nâng cấp theo [migration chính](../backend/docs/MIGRATIONS.md). Nếu volume/schema có trước mà chưa có ledger, phải đối chiếu nguồn SQL và baseline trước; không chạy lại CREATE SCHEMA/ROLE tùy tiện. Không bật migration phá hủy chỉ để vượt lỗi.
3. Tạo cấu hình Nutrition và secret trên host:

```sh
cp deploy/nutrition.env.example deploy/nutrition.env
chmod 600 deploy/.env deploy/nutrition.env
sh deploy/nutrition/prepare-secrets.sh
sh deploy/nutrition/preflight.sh
```

Không dùng secret dev/production để tạo staging. Không gửi giá trị secret qua chat/log. `deploy/secrets/` và `deploy/backups/` bị ignore. `prepare-secrets.sh` bảo toàn file đã có; bộ TLS dở dang hoặc recipient không khớp identity thì dừng để kiểm tra. Không xóa secret của volume cũ để tự tạo lại mật khẩu.

| File | Nơi dùng |
| --- | --- |
| `secrets/nutrition/db-admin-password` | DB bootstrap, migration, backup/restore |
| `secrets/nutrition/db-app-password` | Runtime role `nutrition_app` |
| `secrets/nutrition/gateway-key` | ApiHost gọi gRPC Nutrition |
| `secrets/nutrition/people-key` | Nutrition gọi People nội bộ |
| `secrets/nutrition/ca.pem`, `api.pfx`, `nutrition.pfx`, `tls-password` | Trust CA và TLS của hai host |
| `secrets/nutrition/ca-key.pem` | Chỉ phát hành/gia hạn certificate trên host; không mount runtime |
| `secrets/nutrition/backup-recipient` | Public recipient để mã hóa backup |
| `secrets/nutrition-recovery/age-identity` | Chỉ mount job restore; giữ bản phục hồi qua kho riêng ngoài VM |

Parent hai thư mục secret có mode 0700. Private CA key và recovery identity 0600. Các file mount cho APP_UID ở mode 0444 **bên trong parent 0700**, vì Compose file secrets dùng bind mount; không giả định khai báo uid/mode sẽ đổi owner của bind mount. `.env` 0600. Preflight kiểm các quyền Linux, recipient/identity và certificate còn ít nhất bảy ngày.

Không in kết quả `docker compose config` có giá trị credential ra terminal/CI; dùng `config --quiet`. `compose.sh` nạp main env và Nutrition env cho nội suy, đồng thời chỉ định main env đưa vào container API. Có thể đặt `CARESITTER_DEPLOY_ENV_FILE` và `NUTRITION_DEPLOY_ENV_FILE` để chọn file khác.

## Migration Nutrition và khởi động

Gói mặc định dùng DB `nutrition` riêng trên `nutrition-db`. Chỉ runner migration dùng admin. Runtime dùng role không superuser/BYPASSRLS và không có quyền publish catalog.

```sh
sh deploy/nutrition/compose.sh up -d nutrition-db
sh deploy/nutrition/compose.sh --profile nutrition-migrate run --rm nutrition-migrate
sh deploy/nutrition/compose.sh up -d --build nutrition api admin proxy
sh deploy/nutrition/compose.sh ps
```

Main DB/Redis và schema phải được chuẩn bị trước theo runbook chính. Không chạy đồng thời runner main DB.

Runner Nutrition chỉ nhận `PGDATABASE=nutrition`. Nguồn SQL bất biến ở `backend/init-db/nutrition-service/`. Advisory lock giữ cho toàn phiên; mỗi migration và bản ghi ledger được commit cùng transaction. Checksum SHA256 chuẩn hóa CRLF thành LF để checkout Windows/Linux không gây sai khác; nội dung SQL đổi vẫn bị từ chối. Ledger là `public.nutrition_schema_migrations`. Migration mới phải transactional, đánh số tiếp theo; runner không dùng EF hoặc reset volume.

Khi migration lỗi, phần file đang chạy rollback và khóa được nhả khi phiên đóng. File đã commit không chạy lại. Nếu schema cũ tồn tại mà chưa có ledger, runner dừng khi CREATE gặp xung đột; cần xác minh/baseline đúng schema trước khi dùng gói này. Không tự ghi ledger để bỏ qua lỗi.

## Kiểm kết nối thật

Tạo một customer staging và hồ sơ do tài khoản đó sở hữu qua luồng ứng dụng hiện hành. Đặt UUID vào `NUTRITION_SMOKE_OWNER_ID` và `NUTRITION_SMOKE_BENEFICIARY_ID` của `deploy/nutrition.env`. Lưu access token hiện hành vào file `deploy/secrets/nutrition/customer-token` với mode 0600, không đưa token vào tham số CLI/chat. Token phải còn phiên Identity active; không dùng token giả tự ký để thay kiểm session thật.

```sh
sh deploy/nutrition/compose.sh --profile nutrition-smoke run --rm --build nutrition-smoke
```

Smoke chỉ đọc: public readiness 200; capabilities không token 401; session nội bộ HTTPS 204; People HTTPS trả đúng beneficiary/revision; gRPC TLS/HTTP2 trả HTTP 200 và grpc-status 0; public REST chuyển tiếp gRPC trả đúng capabilities. Không log token hoặc nội dung hồ sơ, không tạo assessment/đổi dữ liệu. Flags false vẫn có thể kiểm transport; capabilities không chứng minh AI/catalog sẵn sàng.

## Backup mã hóa và diễn tập restore

```sh
sh deploy/nutrition/compose.sh --profile nutrition-ops run --rm --build nutrition-backup
sh deploy/nutrition/compose.sh --profile nutrition-ops run --rm nutrition-restore-check /backups/nutrition/NUTRITION_BACKUP_FILE.dump.age
```

Thay tên placeholder bằng file backup thực tế trong `deploy/backups/nutrition/`. Backup dùng pg_dump custom, kiểm archive, mã hóa bằng public recipient, chỉ công bố file sau khi hoàn tất; kèm SHA256 của ciphertext. Plaintext tạm được dọn khi job kết thúc. Backup job không nhận private recovery key.

Restore kiểm SHA256 trước, giải mã vào thư mục tạm, tạo DB `nutrition_restore_<random>` mới, restore một transaction và kiểm schema, ledger, ACL, FORCE RLS/policy/role. Job dọn đúng DB tạm do nó tạo, không dùng `--clean` vào DB nguồn. Bản backup chứa grant cho `nutrition_app`; trên cluster phục hồi mới phải cấp lại role và credential từ secret đã quản lý trước khi restore. Mật khẩu role không nằm trong pg_dump.

Đây là diễn tập, chưa phải lệnh phục hồi thay DB đang chạy. Khi cần phục hồi thật: dừng writer, xác định backup/mốc dữ liệu, xác minh trên DB mới, cập nhật kết nối và kiểm smoke; chỉ chuyển traffic sau khi kiểm dữ liệu. Backup Nutrition và main DB độc lập, không có snapshot nguyên tử xuyên hai DB. SQL 38 trên main DB cần backup riêng của main deployment.

Để lên lịch hàng ngày, chỉnh `/opt/caresitter` trong service thành thư mục checkout trên VM rồi cài hai unit:

```sh
sudo install -m 644 deploy/nutrition/caresitter-nutrition-backup.service /etc/systemd/system/
sudo install -m 644 deploy/nutrition/caresitter-nutrition-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now caresitter-nutrition-backup.timer
systemctl list-timers caresitter-nutrition-backup.timer
```

Timer 03:00 giờ Việt Nam, bù lần lỡ chạy. Sau cài đặt cần chạy service một lần và diễn tập restore. Bản mã hóa trên cùng VM chưa bảo vệ mất máy: chọn kho ngoài VM, thời gian giữ bản và cảnh báo dung lượng/lỗi job theo môi trường thực; chuyển ciphertext qua kênh quản lý đã có. Giữ recovery identity riêng và kiểm khả năng lấy lại. Không có kho off-host hoặc timer thực tế nào đã được thiết lập trong đợt local này.

## Gia hạn và rollback code

Leaf certificate có hạn 90 ngày, CA hai năm. Script gia hạn giữ CA, DB password, JWT, gateway/People key và backup recipient/identity:

```sh
sh deploy/nutrition/renew-certificates.sh
sh deploy/nutrition/preflight.sh
sh deploy/nutrition/compose.sh up -d --force-recreate nutrition api
sh deploy/nutrition/compose.sh --profile nutrition-smoke run --rm nutrition-smoke
```

Bind mount file cần recreate container để nhận bundle mới; restart riêng không bảo đảm remount inode. Gia hạn trước khi leaf hết hạn; CA còn dưới 90 ngày cần lập kế hoạch chuyển CA và trust tương ứng riêng. Không tự xoay CA đang được client tin.

Khi rollback code, dùng image/tag đã kiểm tương thích schema và các flag đã ghi nhận. Không `down -v`, drop schema hoặc chạy SQL đảo ngược để rollback ứng dụng. Feature flag chỉ kiểm hành vi nghiệp vụ; khóa gateway không thay thế kiểm owner/session.

## Kiểm thử local và giới hạn

Lệnh từ gốc repo trên Windows, cần PostgreSQL native, Git Bash và age Windows:

```powershell
./deploy/nutrition/test-compose.ps1
./deploy/nutrition/test-ops.ps1 -AgeBin 'DUONG_DAN_THU_MUC_CO_AGE_EXE'
dotnet test backend/tests/CareSitter.IntegrationTests --no-restore --filter 'FullyQualifiedName~NutritionGatewayTests|FullyQualifiedName~InternalCertificateTrustTests|FullyQualifiedName~DeploymentConfigurationTests'
```

Runner tạo cluster loopback/DB test riêng trong `backend/artifacts/`, bảo toàn env và dừng cluster khi kết thúc. Không trỏ vào DB local ứng dụng. Kiểm chuẩn bị secret lặp, migration/replay/checksum/LF-CRLF/rollback/đồng thời, backup mã hóa/restore/RLS và file bị hỏng. Kết quả chi tiết ở [báo cáo kiểm thử](../kiem-thu/NUTRITION_STAGING_2026-10-13.md).

Đã kiểm .NET 8.0.425, PostgreSQL native 18 và cấu hình Compose offline. Chưa build image, chạy PostgreSQL 16/Linux container, preflight quyền Linux, DNS/public TLS, smoke với customer/People/Identity thật trên staging hoặc timer/off-host backup. Các mục này cần Docker chạy và host đích; chưa được đánh dấu hoàn thành.
