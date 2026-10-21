# Kiểm thử gói hạ tầng Nutrition staging

Cập nhật: 13/10/2026. Phạm vi: DB riêng, migration, secret, HTTPS/gRPC, kiểm kết nối và backup/restore của Nutrition. Đã viết source và kiểm thử local; chưa triển khai trên server. Không stage/commit/push, không build APK. Tài liệu local.

## Thay đổi

- `deploy/nutrition/compose.yml` là overlay cho deployment VM hiện có: PostgreSQL/volume riêng, network nội bộ, API gọi Nutrition bằng gRPC TLS/HTTP2; Nutrition gọi People/Identity bằng HTTPS nội bộ. Chỉ proxy public cổng 80/443.
- Handler CA nội bộ ở hai host giữ kiểm hostname, thời hạn, EKU và chain. Thiếu CA dùng trust hệ thống; CA sai/không đọc được hoặc certificate sai bị từ chối.
- Secret nằm ngoài image/repo. Chuẩn bị lặp không thay credential; CA private key không mount runtime; recovery identity chỉ cấp cho restore job. Chứng chỉ dùng config OpenSSL riêng để không phụ thuộc extension mặc định của máy.
- Runner migration khóa toàn phiên, checksum chuẩn hóa LF/CRLF, commit SQL và ledger cùng transaction. Không sửa SQL đã áp dụng, không EF migration hoặc reset volume.
- Backup pg_dump custom được mã hóa bằng age, kèm SHA256 ciphertext. Restore kiểm trên DB tạm, giữ ACL/RLS và dọn đúng DB đã tạo. Có script smoke chỉ đọc, script gia hạn leaf certificate và systemd timer mẫu; chưa cài lên host thực.
- Giữ ba feature flag false; không cấu hình AI thật hoặc tự publish công thức/quy tắc. Không xoay JWT Identity.

## Bằng chứng kiểm thử

Môi trường: Windows, .NET SDK 8.0.425, PostgreSQL native 18.1, Git Bash/OpenSSL 1.1.1p, age Windows 1.3.2 từ release chính chủ và đã đối chiếu SHA256. Cluster/DB test riêng, chỉ bind loopback; không tác động DB ứng dụng local. Cluster test đã dừng sau mỗi lần chạy, mật khẩu bootstrap tạm được xóa.

| Kiểm tra | Kết quả cuối |
| --- | --- |
| Toàn bộ Nutrition suite trên PostgreSQL thật | **61 pass, 0 fail, 0 skip** |
| Gateway + CA/HTTPS + cấu hình deploy | **39 pass, 0 fail, 0 skip** |
| Cú pháp các shell script | Pass |
| Compose offline | Pass: merge, cổng DB/gRPC riêng tư, endpoint HTTPS, dependencies/readiness, flag false và mount secret đúng job |
| Chuẩn bị secret hai lần | Bảo toàn hash credential, CA và bundle đã có |
| Gia hạn leaf certificate | Bundle mới hợp lệ; CA, mật khẩu và key nội bộ không đổi |
| Migration lần đầu/chạy lại | Hai bản ghi ledger; không tạo schema/role lặp |
| Checkout LF/CRLF | Cùng checksum; thay nội dung thật vẫn bị từ chối |
| Migration lỗi giữa file | Table probe và ledger insertion rollback cùng transaction |
| Hai runner đồng thời | Cả hai thành công; migration chỉ được áp dụng một lần |
| Backup/restore | Ciphertext và checksum được tạo; restore schema/ACL/FORCE RLS/ledger vào DB tạm rồi dọn |
| Kiểm dữ liệu độc lập sau restore | Giữ đúng payload fixture; runtime role đọc được hồ sơ của owner, không đọc được owner khác |
| Checksum backup sai | Bị từ chối trước restore; DB nguồn không đổi |
| Whitespace/index | `git diff --check` pass; index trống |

Các lỗi fixture ban đầu đã được sửa trước kết quả cuối. Không bỏ test hoặc nới kiểm chain/RLS để qua kiểm tra.

Kết quả Nutrition cuối: [TRX](../../backend/artifacts/nutrition-staging-20261013/ops-6d9b3315e3ac452eb7fcb61f6fcf9ced/results/nutrition-postgres.trx). Gateway: [TRX](../../backend/artifacts/nutrition-staging-20261013/results/gateway-deployment.trx). Artifacts chỉ local và bị ignore.

Lệnh từ gốc repo:

```powershell
./deploy/nutrition/test-compose.ps1
./deploy/nutrition/test-ops.ps1 -AgeBin 'DUONG_DAN_THU_MUC_CO_AGE_EXE'
dotnet test backend/tests/CareSitter.IntegrationTests/CareSitter.IntegrationTests.csproj --no-restore --filter 'FullyQualifiedName~NutritionGatewayTests|FullyQualifiedName~InternalCertificateTrustTests|FullyQualifiedName~DeploymentConfigurationTests'
```

## Giới hạn còn lại

- Docker daemon local chưa chạy. Chưa build image hoặc chạy stack Linux/PostgreSQL 16; kiểm Compose offline không thay các bước này.
- Chưa có VPS/domain/SSH đích, chưa chạy preflight quyền file Linux, public HTTPS/DNS hoặc smoke dùng customer/profile/Identity thật trên staging. Test transport dùng fixture, không chứng minh phiên của môi trường thật.
- Timer mẫu chưa được cài; chưa có kho backup ngoài VM, retention hoặc cảnh báo job/dung lượng. Backup main DB và diễn tập main DB thuộc deployment chính, chưa được triển khai trong gói Nutrition local này.
- SQL 37–38 đã áp DB ứng dụng local trong đợt trước; staging/production cần kiểm và nâng schema riêng. Không áp lại migration lên DB ứng dụng trong đợt này.
- Provider AI thật, catalog chuyên môn đã duyệt và pilot/thiết bị thật chưa hoàn thành. Không đánh dấu chức năng gợi ý món hoặc production hoàn tất từ các test hạ tầng.

Thực hiện trên host theo [runbook Nutrition staging](../deploy/NUTRITION_STAGING.md).
