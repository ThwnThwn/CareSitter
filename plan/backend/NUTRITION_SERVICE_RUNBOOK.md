# Service Nutrition độc lập

Cập nhật 13/10/2026. Đã có code, kiểm thử PostgreSQL thật, áp dụng SQL 37–38 trên CareSitter local và smoke AppHost; chưa deploy production. Tài liệu local. Gói hạ tầng staging mới ở [runbook deploy Nutrition](../deploy/NUTRITION_STAGING.md); phân biệt kiểm thử local với môi trường chưa triển khai. Xem [kết quả ban đầu](../kiem-thu/NUTRITION_SERVICE_IMPLEMENTATION_2026-10-11.md), [gRPC/AppHost](../kiem-thu/NUTRITION_GRPC_APPHOST_2026-10-11.md) và [hồ sơ/DB local hiện tại](../kiem-thu/NUTRITION_HEALTH_DATABASE_2026-10-11.md).

## Ranh giới

Nutrition ở `backend/services/nutrition/`, có solution .NET 8, host, PostgreSQL, Docker image/Compose và job CI riêng. Không reference ApiHost/People/Shared; không SQL, FK hoặc transaction xuyên DB. API và worker hiện cùng process, nhiều instance được bảo vệ bằng lease token.

```text
Customer app
  ├─ BASE_URL → ApiHost → People → DB CareSitter
  │    GET/PATCH /api/v1/beneficiaries/{id}/health-profile
  └─ BASE_URL → ApiHost façade → gRPC/HTTP2 → Nutrition → DB Nutrition
       └─ HTTP nội bộ → ApiHost People snapshot + owner/revision/Identity session
```

People sở hữu hồ sơ hiện hành. Nutrition chỉ lưu snapshot lịch sử của assessment, không tạo hồ sơ nguồn thứ hai. Customer ID lấy từ JWT. `IPeopleHealthClient` gọi `/internal/v1/nutrition/owners/{owner}/beneficiaries/{id}/health-profile` với `X-Nutrition-Service-Key`. People kiểm credential riêng và owner/beneficiary chưa xóa; DTO ở hai bên khớp JSON contract.

Nutrition yêu cầu JWT có user ID/sid/jti hợp lệ và gọi GET `/api/v1/auth/session` trên ApiHost bằng bearer token đó. Endpoint trả 204, dùng pipeline Identity hiện hữu (durable session/account active + token blacklist), không trả profile. Phiên bị thu hồi/tài khoản khóa trả 401, Identity outage trả 503; không cache positive session để bỏ qua logout/reset. Đây là HTTP dependency, không reference hoặc đọc DB Identity. Worker có thể hoàn tất job đã được nhận; mỗi API đọc/dùng kết quả vẫn cần phiên hiện hành hợp lệ.

Hai DB không có transaction nguyên tử chung. Nutrition đọc People trước thao tác và sau commit; đổi revision trả 409, mất hồ sơ trả 404. Mọi GET/list/ứng viên/đổi/lưu tiếp tục đối chiếu People. Thay đổi ngay sau lần HTTP check cuối sẽ được phát hiện ở lần đọc/sử dụng tiếp theo. Transaction Nutrition chỉ giữ owner advisory lock và catalog epoch lock; không giữ lock qua HTTP/AI.

## Schema và migration

- DB CareSitter: `backend/init-db/38-nutrition-health-revision.sql`, theo [quy trình migration](docs/MIGRATIONS.md). Thêm revision, trạng thái/metadata xác nhận dị ứng và trigger cho mọi đường ghi sức khỏe. Legacy vẫn unknown, không suy none từ null/mảng rỗng. Đã áp vào DB local ngày 11/10; staging/production phải kiểm schema/ledger riêng.
- DB Nutrition riêng: `backend/init-db/nutrition-service/01-nutrition-workflow.sql`; runtime role ở `02-runtime-role.sql`. Không chạy các script này lên DB CareSitter. Compose development bootstrap volume mới. Gói deploy staging dùng runner riêng với lock/checksum/transaction và ledger; schema đã có trước phải đối chiếu/baseline, không chạy lại CREATE SCHEMA/ROLE hoặc reset.
- Không dùng EF migrations. Có FORCE RLS cho resource customer, predicate owner/beneficiary, runtime role không publish catalog. Cấp UPDATE(id) trên catalog_state để FOR SHARE; không cấp cập nhật revision.

| Bảng | Nội dung |
| --- | --- |
| assessments | Owner/beneficiary/revision/status/key/fingerprint/timestamps dạng quan hệ; snapshot/facts/decision/error/confirmation dạng JSONB schemaVersion |
| assessment_jobs | ID/scope/attempt/lease token/expiry; nguồn claim bền của worker |
| recommendations / meal_plans | Owner/revision/status/key; JSONB assessment ID/ngày/3 bữa/rule version/catalog epoch |
| recipe_versions / rule_versions | ID/version/status/reviewer/time và payload đã kiểm; runtime chỉ đọc published |
| concepts / catalog_state | Dictionary chuẩn hóa và epoch nội dung tăng khi catalog đổi |
| preferences | Bảng dự phòng; chưa có API/UI hoặc ảnh hưởng policy |

Cột lease dự phòng trên assessments chưa dùng; assessment_jobs là nguồn claim. Các trường dễ query có cột quan hệ; JSONB không thay thế kiểm owner/revision/status. Không seed món hay ngưỡng y khoa trong runtime.

## Cấu hình local

Từ gốc repo, tạo `backend/services/nutrition/.env` từ `.env.example`, điền secret local/kho secret; không đưa giá trị thật vào Git/tài liệu/Flutter.

| Compose env | Ý nghĩa |
| --- | --- |
| NUTRITION_DB_ADMIN_PASSWORD / NUTRITION_DB_APP_PASSWORD | Credential riêng cho bootstrap và runtime |
| NUTRITION_JWT_SECRET / NUTRITION_JWT_ISSUER / NUTRITION_JWT_AUDIENCE | Khớp token Identity, validate signature/issuer/audience/lifetime |
| NUTRITION_INTERNAL_SERVICE_KEY | Cùng giá trị NutritionIntegration__ServiceKey trên ApiHost; 32–256 ký tự |
| NUTRITION_PEOPLE_URL | Root ApiHost, local mặc định http://host.docker.internal:5033/; không thêm /api/v1 |
| NUTRITION_CUSTOMER_ORIGIN | Origin customer web cho CORS |
| NUTRITION_ENABLED / NUTRITION_ASSESSMENTS_ENABLED / NUTRITION_RECOMMENDATIONS_ENABLED | Mặc định false; chỉ bật sau cấu hình/nghiệm thu |

```powershell
docker compose --env-file backend/services/nutrition/.env -f backend/services/nutrition/compose.yml up -d --build
```

Compose bind REST local `127.0.0.1:5035` và gRPC `127.0.0.1:5036`, không public DB. Cổng gRPC riêng dùng HTTP2; REST dùng HTTP1. `NUTRITION_GATEWAY_SERVICE_KEY` phải khớp `NutritionGateway__ServiceKey` của ApiHost; bật `NutritionGateway__Enabled=true` và trỏ `NutritionGateway__GrpcUrl=http://localhost:5036/`. Mặc định Development để gọi People HTTP local. Production cần override environment, HTTPS People/gRPC, CORS đúng origin, secret/volume/backup riêng; không dùng nguyên Compose local cho production.

Chạy dotnet trực tiếp cần `ConnectionStrings__Nutrition`, `Jwt__SecretKey/Issuer/Audience`, `People__BaseUrl/ServiceKey`, `Nutrition__Enabled/AssessmentsEnabled/RecommendationsEnabled`, `Cors__AllowedOrigins__0`. Host không tự load .env bằng DotNetEnv.

Customer dùng `BASE_URL` của ApiHost cho hồ sơ và Nutrition; không còn đọc `NUTRITION_BASE_URL`. Mẫu `frontend/customer-app/nutrition.local.example.json`. Từ thư mục customer:

```powershell
flutter run -d chrome --dart-define-from-file=.env.local
```

Điện thoại dùng URL LAN/HTTPS, không localhost. Không đưa internal key, JWT signing key hay DB password vào dart-define. Entry cần URL, phiên customer và capabilities enabled.

## API thực tế

People public GET/PATCH `/api/v1/beneficiaries/{id}/health-profile`: PATCH `{expectedHealthRevision, changes}`, whitelist và merge sparse, không bắt tên/địa chỉ/textarea mới. reported_none không tự xóa danh sách dị ứng; customer xử lý dữ liệu còn hiệu lực tường minh.

Nutrition JWT CUSTOMER, route sau `/api/v1/beneficiaries/{id}`:

| Method/route | Hành vi |
| --- | --- |
| POST nutrition-assessments | Lưu resource/job bền; 202 + Location |
| GET nutrition-assessments/{assessment} | Poll, kiểm owner/revision |
| POST nutrition-assessments/{assessment}/confirm | Chỉ awaiting_confirmation, đúng revision/catalog |
| POST / GET meal-recommendations[/{recommendation}] | Tạo từ assessment confirmed đủ policy; đọc/kiểm stale |
| GET meal-recommendations/{recommendation}/replacement-options?mealType=lunch | Tối đa 20 ứng viên phù hợp toàn ngày |
| POST meal-recommendations/{recommendation}/replacements | Fork recommendation, kiểm lại toàn bộ ràng buộc |
| POST / GET meal-plans | Lưu server snapshot / tối đa 20 bản gần nhất |
| GET meal-plans/{plan} | Đọc bản lưu, kiểm stale |

Capabilities ở GET `/api/v1/nutrition/capabilities`. Request ghi cần expectedHealthRevision và UUID idempotencyKey; recommend thêm assessmentId, save thêm recommendationId, replace thêm recipeVersionId/mealType. Cùng owner/key/kind/payload trả lại resource; payload khác 409. Confirm là chuyển trạng thái lặp an toàn của cùng assessment, không nhận facts sửa qua body. Giới hạn 20 assessments/customer/24 giờ, 120 HTTP requests/phút; quota trả 429.

Response: id/beneficiaryId/healthRevision/status/data/createdAt. Decision: state/reasonCodes/missingFields/conflicts/requiredGuidance/allowedActions. 401 phiên, 403 role, 404 thống nhất không khả dụng, 409 revision/catalog/key, 503 chưa cấu hình/tạm lỗi. State chặn gồm needs_information, needs_professional_guidance, failed, stale/cancelled, no_content, no_match. Không demo/healthy fallback. Questions và sửa summary có cấu trúc nâng cao chưa có endpoint; customer sửa hồ sơ nguồn rồi phân tích lại.

UI có cập nhật sparse, tóm tắt/xác nhận, các trạng thái chặn, 3 bữa với định lượng/cách nấu/nguồn, đổi món, lưu và lịch sử. Chỉnh sửa chưa lưu chặn dùng kết quả cũ; lỗi giữ draft; đổi phiên/hồ sơ hủy request/polling, bỏ response muộn và đóng sheet chứa dữ liệu cũ.

People/Nutrition dùng chung một refresh interceptor theo session, refresh vẫn gọi Identity qua BASE_URL. Refresh token đồng thời chỉ có một request; retry giữ đúng host gốc. Response refresh cũ không cập nhật hoặc logout tài khoản mới; ghi secure storage được serialize và kiểm session generation khi login/logout/refresh cạnh tranh. Lỗi nghiệp vụ sau refresh không bị đổi thành logout.

## Normalizer, parser và nội dung

Arrays bệnh/dị ứng chuẩn hóa qua dictionary, giữ source pointer. Legacy/giá trị lạ được giữ unresolved. `healthHistory.nutrition` schemaVersion=1; conditionsStatus/medicationsStatus=reported_none|reported_present; feedingRoute=oral|tube; swallowingStatus=normal|difficulty; fluidRestriction/electrolyteRestriction=none|present; guidance/symptoms là văn bản. Có thể lưu unknown để bổ sung sau; thiếu hoặc unknown ở các mục này phải được làm rõ trước cá nhân hóa. Thuốc hợp lệ đang dùng cần hướng dẫn chuyên biệt khi catalog tương tác chưa có; thuốc đã ngừng không tự bị coi là đang dùng. PATCH hỗ trợ nutritionProfile để merge từng trường, giữ lịch sử khác. Schema thiếu/enum lạ không được tự phê duyệt.

Thận/khó nuốt/ăn qua ống/hạn chế dịch/điện giải đặc biệt hiện luôn chặn để cần hướng dẫn chuyên biệt. Không có checkbox tự mở khóa. Policy áp đồng thời daily maximums/excluded ingredients của các rule bệnh chắc chắn hiện tại và dị ứng hard constraint. Thiếu nutrient dùng null, chặn nếu rule cần. Đúng 3 bữa, servings=1; chưa chỉnh hệ số khẩu phần.

Recipe: versionId/name/mealType/servings/ingredients(code,name,amount,unit g|ml,basis raw|cooked)/allergens/nutrients/preparationSteps/sources/allergenDataComplete. Rule: versionId/conditionCode/prerequisites/excludedIngredients/dailyMaximums/sources. Nutrient key có đơn vị như sodium_mg/protein_g/energy_kcal. Row published cần reviewer không rỗng và thời gian review/publication. Sources hiện là chuỗi citation; nội dung từ sách cần ghi tên/edition/chương/trang và review trước publish. Loader bỏ payload sai schema; runtime role không import/publish.

Provider chưa chọn theo yêu cầu customer. `IHealthDescriptionParser` có adapter báo nutrition.ai_unavailable khi phải đọc ghi chú; không tạo facts giả. Cấu trúc đủ, không còn văn bản phải đọc thì bỏ qua AI. Timeout 25s; quote phải có duy nhất trong nguồn và chứa code/alias khái niệm đã duyệt; kind/code/assertion/temporality hợp lệ, subject phải là beneficiary (thiếu/other/unknown bị từ chối). Không nhận condition chỉ từ quote triệu chứng không nêu khái niệm đó. Các kiểm cơ học này chưa chứng minh model hiểu đúng phủ định/chủ thể; adapter thật cần schema đóng, eval tiếng Việt và quy trình xử lý dữ liệu trước bật.

Worker lease 60s, tối đa 3 attempts lỗi hạ tầng; parser lỗi lưu failed/retryable. Retry transport giữ key, retry failed tường minh tạo assessment mới và tính quota. Log error type/trace, không notes/secret. Fixtures chỉ trong test, catalog rỗng ra no_content.

GET /health/live xác nhận process; /health/ready xác nhận DB/schema, không xác nhận provider/People. Còn lại: provider thật, nội dung chuyên môn/import workflow, preferences, Kafka integration nếu cần, quan sát backlog, retention/purge snapshots, backup/restore, staging và thiết bị/pilot. Chưa bật môi trường thực.

## Kiểm thử

CARESITTER_TEST_ADMIN_CONNECTION chỉ trỏ PostgreSQL test được phép tạo DB/role tạm. Thiếu env thì PG tests skip, không tính pass. Từ gốc repo:

```powershell
dotnet test backend/services/nutrition/CareSitter.Nutrition.sln --nologo
dotnet test backend/tests/CareSitter.IntegrationTests --filter 'FullyQualifiedName~HealthProfileTests|FullyQualifiedName~NutritionInternalAuthenticationTests|FullyQualifiedName~NutritionSessionProbeTests|FullyQualifiedName~PostgresTestDiscoveryTests'
```

Service tests tạo DB/role UUID riêng và dọn, test RLS/revision/idempotency/worker fencing trên PG thật. CI có job riêng cho solution Nutrition và Docker build. Flutter analyze/test/build web, widget 320/390px text scale 2 và lifecycle. Báo cáo local phân biệt test qua với provider/device e2e chưa kiểm chứng.
