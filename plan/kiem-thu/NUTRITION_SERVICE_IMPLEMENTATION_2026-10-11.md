# Nutrition — triển khai service và kiểm thử local

Cập nhật 11/10/2026 (Asia/Saigon). Phạm vi: tạo microservice riêng theo yêu cầu customer, xử lý 9 tình huống Nutrition cho beneficiary bản thân/người thân. Không commit/push/deploy; không sửa DB ứng dụng đang chạy. Tài liệu local, không chứa secret.

## Kết quả triển khai

- `backend/services/nutrition/`: solution/host .NET 8 riêng, không project reference monolith; Domain/Application/Infrastructure/Controllers, ports, Npgsql store, JWT CUSTOMER, CORS/rate limit, health endpoints, worker lease, Docker/Compose và CI riêng.
- DB Nutrition riêng, runtime role hạn chế và FORCE RLS. Owner/beneficiary/revision/status/key/fingerprint quan hệ; snapshots/facts/món/rules JSONB có schemaVersion. Schema nguồn ở `backend/init-db/nutrition-service/`; không có FK hoặc SQL sang People.
- People: migration 38 tăng revision bằng trigger, allergy status/confirmation, sparse GET/PATCH và snapshot HTTP nội bộ có service credential. Các đường cập nhật legacy không âm thầm xác nhận lại dị ứng.
- Normalizer đọc dữ liệu cấu trúc và ghi chú, giữ legacy chưa hiểu là unresolved, không bắt textarea mới. Parser port chưa chọn provider; adapter thật chưa có, khi phải đọc ghi chú thì failed/ai_unavailable. Quote/code/alias/subject guard ngăn facts ngoài nguồn hoặc thuộc người khác; không tuyên bố đã kiểm chứng ngữ nghĩa model thật.
- Policy chặn thiếu/chưa rõ/xung đột/triệu chứng, nhóm thận/khó nuốt/ăn qua ống/hạn chế dịch/điện giải; nhiều bệnh áp đồng thời quy tắc hiện tại. Dị ứng, nguyên liệu cấm, daily maximums và nutrient thiếu kiểm cả 3 bữa, bao gồm đổi món/lưu.
- Generate/read/replacement-options/replace/save/history đều kiểm owner/revision/catalog. Idempotent retry cũng đánh dấu stale khi catalog đã đổi; không hồi sinh công thức bị retired.
- Customer có route từ hồ sơ, cập nhật phần thiếu, optional notes, summary/xác nhận, các trạng thái chặn, thực đơn 3 bữa/định lượng/cách nấu/nguồn, chọn món thay thế, lưu/lịch sử. Request/polling theo session + beneficiary, bỏ response muộn; lỗi giữ draft, sửa chưa lưu chặn dùng kết quả cũ.
- Hai client People/Nutrition dùng chung refresh theo session, giữ host gốc khi retry. Core auth serialize secure-storage writes và kiểm generation, chặn token refresh cũ ghi đè login/logout mới. Lỗi nghiệp vụ sau refresh không logout phiên hợp lệ.
- Nutrition validate user ID/sid/jti rồi kiểm durable session/account/token revocation qua API Identity `/api/v1/auth/session` trả 204 không có profile; phiên revoked bị chặn 401, dependency outage 503. Không giữ positive cache để bỏ qua thu hồi phiên.

Hai DB không có transaction nguyên tử chung. Đọc People trước và sau thao tác, resource gắn revision; mọi lần dùng tiếp tục revalidate. Race ngay sau HTTP check cuối chỉ được phát hiện ở lần đọc/sử dụng tiếp theo. Không giữ SQL lock qua AI/HTTP.

## Kiểm thử đã chạy

Môi trường: Windows/PowerShell, SDK .NET theo global.json 8.0.425, Flutter theo workspace; PostgreSQL 16/PostGIS 3.4 container test riêng tại loopback 55439, role test không superuser/BYPASSRLS. Không dùng credential ứng dụng thực.

| Phần | Kết quả cuối | Bằng chứng |
| --- | --- | --- |
| Nutrition solution | 40 pass, 0 fail, 0 skip | `backend/artifacts/nutrition-final-review/nutrition-final.trx` |
| Main integration | 271 pass, 0 fail, 0 skip | `backend/artifacts/nutrition-final-review/integration-final.trx` |
| Main architecture và unit modules | 275 pass, 0 fail, 0 skip | Các TRX trong `backend/artifacts/nutrition-main-review/`, không đổi source các module ngoài People |
| Messaging regression chạy lại | 22 pass, 0 fail, 0 skip | `backend/artifacts/nutrition-final-review/messaging-final.trx` |
| Customer Flutter toàn suite | 163 pass | `backend/artifacts/nutrition-flutter-final.log` |
| Flutter analyze | No issues found | `flutter analyze --no-pub` |
| Customer web build | Thành công, có NUTRITION_BASE_URL | `flutter build web --no-pub --dart-define=NUTRITION_BASE_URL=http://localhost:5035/api/v1` |
| Docker build riêng | Thành công với SDK image 8.0.425, đã build lại sau thay đổi session cuối | Build độc lập, không copy source monolith; `backend/artifacts/nutrition-compose-review.log` |
| Compose/bootstrap/readiness | Qua: /health/ready 200; API thiếu JWT 401; nutrition_app superuser=false, bypassrls=false | Project test `caresitter-nutrition-review-20261011`, credential sinh tạm, volume test riêng; đã down và dọn volume test |

Tổng backend kiểm chứng theo từng suite: 568 main và 40 Nutrition. **Không ghi là một lần chạy full solution sạch**: lần đầu full main có 7 fail (1 discovery nhãn PG thiếu; 3 EF test fixture tạo quá nhiều internal service providers; 2 timeout khi dọn test DB; 1 Kafka publish timeout). Đã thêm đúng Category=PostgreSQL, dùng chung datasource trong fixture HealthProfile và chạy lại toàn integration 271 cùng messaging 22 đều qua. Không sửa production EF/Kafka để bỏ qua warning hoặc tăng timeout nhằm che lỗi.

Nutrition PG tests: owner/RLS thật, 12 concurrent cùng key tạo một resource, same-key different payload, quota/retry không tính hai lần, assessment/confirm/no_content, AI unavailable, source revision race giữa commit/response, xóa/mất owner, expired worker fencing/recovery, published fixture/replacement cả ngày/allergen/nutrient, saved/retired/stale và retry không hồi sinh catalog cũ. Fixtures chỉ trong test.

HTTP tests: credential nội bộ thiếu/sai không gọi reader, đúng credential vẫn giữ exact owner scope/404; People client phân biệt outage/404 và reject snapshot sai beneficiary; host Nutrition kiểm JWT role/expiry/signature. Main PG tests bảo toàn legacy/notes, revision nguyên tử, confirmation không tự đổi bởi notes và PATCH concurrent không ghi đè.

Session tests bổ sung: host Nutrition reject revoked session và phân biệt Identity outage 503; HTTP client dùng đúng bearer/path, chỉ 204 là active; main endpoint dùng IAccessSessionValidator và không trả PII. Suite Nutrition và main integration đã chạy lại thành công sau bổ sung session probe.

Flutter tests mới: unknown dị ứng, không bắt mô tả mới, key retry transport/failed retry, AI failed giữ hồ sơ, 404 xóa dữ liệu, late response sau cancel/dispose/logout, conflict chuyển stale, widget 320/390px text scale 2 không overflow và draft giữ khi lỗi PATCH.

Thêm 5 test core auth: hai host cùng 401 chỉ refresh một lần/retry đúng host; late refresh không cập nhật/logout tài khoản mới; retry 409 giữ phiên; secure storage refresh cạnh tranh login/logout không ghi đè phiên mới. Chạy targeted 15 tests (5 core + 10 Nutrition) đều qua; full Flutter 163 tests, analyze và web build đã qua sau thay đổi cuối này.

## Chưa kiểm chứng/chưa triển khai

- Provider AI thật, bộ eval tiếng Việt/chủ thể/phủ định, consent và vận hành provider; adapter chưa cấu hình theo lựa chọn customer.
- Công thức/quy tắc từ sách có nguồn và review thực; không có demo runtime. Catalog rỗng trả no_content. Không có importer/admin review UI hoàn chỉnh.
- Preferences API/UI, khẩu phần biến đổi, schema clinical guidance chuyên biệt, corrections/questions nhiều lượt và Nutrition Kafka events.
- Migration/rollout staging/production, e2e app → hai host thật trên thiết bị, observability/retention purge/backups/pilot. Feature flags mặc định false.
- Không apply migration 38 lên DB CareSitter hiện hữu; không bật feature trên môi trường customer thực.

Hướng dẫn cấu hình và API: [runbook](../backend/NUTRITION_SERVICE_RUNBOOK.md). Backlog mở rộng: [plan các tình huống](../tong-quan/NUTRITION_EDGE_CASE_IMPLEMENTATION_PLAN.md).
