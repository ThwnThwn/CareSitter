# Kế hoạch triển khai các tình huống Nutrition

> Cập nhật: 11/10/2026. Trạng thái: **đã có code và kiểm thử local cho service Nutrition độc lập, People integration và UI customer; chưa bật môi trường thật**. Phạm vi: 9 tình huống ở mục 6 của [plan thực đơn](MEAL_RECOMMENDATION_PLAN.md), áp dụng cho cả hồ sơ bản thân và người thân. Tài liệu local, không commit/push.

Quyết định kiến trúc theo yêu cầu customer: Nutrition là **microservice .NET 8, database riêng**, tại `backend/services/nutrition/`. Provider AI chưa chọn: giữ `IHealthDescriptionParser` và adapter báo chưa cấu hình. Không seed nội dung demo. Xem [runbook service](../backend/NUTRITION_SERVICE_RUNBOOK.md) và [kết quả kiểm thử](../kiem-thu/NUTRITION_SERVICE_IMPLEMENTATION_2026-10-11.md) để phân biệt phần đã làm với thiết kế mở rộng bên dưới.

Tài liệu này là backlog và hợp đồng xử lý tình huống của plan chính, không thay thế [đặc tả phân tích](../backend/NUTRITION_ANALYSIS_SPEC.md). Không bổ sung ngưỡng dinh dưỡng hay quy tắc điều trị; nội dung đó thuộc bộ quy tắc có nguồn và được chuyên môn duyệt.

## 1. Mục tiêu và hiện trạng

Mục tiêu: chỉ đưa gợi ý cá nhân hóa khi dữ liệu, quyền truy cập và nội dung đáp ứng điều kiện; mọi trường hợp chưa đáp ứng có lý do và hành động tiếp theo. Customer chỉ bổ sung phần thiếu trong hồ sơ đang có.

Đã đối chiếu source ngày 11/10/2026:

| Thành phần | Đã có | Cần triển khai |
| --- | --- | --- |
| People/Beneficiary | Các trường hiện hữu, revision sức khỏe, xác nhận dị ứng, HTTP snapshot nội bộ và GET/PATCH sức khỏe | Áp migration 38 ở môi trường triển khai; dữ liệu chuyên biệt ngoài schema v1 tiếp tục cần làm rõ |
| Cập nhật hồ sơ | Handler merge trường không gửi với bản ghi hiện hành | Đảm bảo mọi đường ghi dữ liệu sức khỏe cùng tăng revision và làm mất hiệu lực xác nhận liên quan |
| Nutrition backend | Host/solution/Docker/DB/CI riêng, policy, parser port, durable worker, idempotency, RLS, API đánh giá/gợi ý/đổi/lưu/lịch sử | Chọn và kiểm thử provider thật; chưa phát integration event Nutrition qua Kafka |
| Customer app | Feature nutrition, CancelToken/polling theo phiên/hồ sơ, màn cập nhật, trạng thái chặn, đổi món, lưu/lịch sử | Nghiệm thu staging và thiết bị thật, cấu hình NUTRITION_BASE_URL |
| Nội dung | Có tài liệu thiết kế | Chưa có danh mục công thức/quy tắc Nutrition đã publish được xác minh trong source |

Mốc hoàn thành đợt đầu là chạy được toàn bộ luồng đánh giá và các trạng thái chặn bằng backend thật. Trạng thái `no_content` là kết quả hợp lệ khi chưa có nội dung duyệt; không coi nó là đã hoàn thành chức năng gợi ý món.

## 2. Quyết định triển khai

1. People tiếp tục là nguồn hồ sơ hiện hành. Không tạo hồ sơ sức khỏe thứ hai trong Nutrition; mọi kết quả gắn đúng beneficiaryId.
2. Backend quyết định điều kiện gợi ý. UI trình bày kết quả; AI chỉ trích dữ kiện có nguồn và không được trả quyền bỏ qua ràng buộc.
3. Đọc đồng thời trường cấu trúc và ghi chú. Nếu cấu trúc đủ và không có văn bản cần phân tích, bỏ qua AI. Nếu có ghi chú sức khỏe liên quan chưa đọc được thì không bỏ qua để vẫn đưa gợi ý.
4. Mọi dữ liệu chưa rõ được giữ là chưa rõ. `null`, `[]`, lỗi parse hoặc AI trả facts rỗng không chứng minh không có bệnh/dị ứng.
5. Với nhóm cần hướng dẫn chuyên biệt, bản đầu chặn gợi ý theo bệnh lý cho đến khi có quy tắc được duyệt và đủ prerequisite. Customer tick “đã có hướng dẫn” không tự mở khóa; dữ liệu phải đúng hợp đồng và được policy kiểm tra.
6. Có thể đọc tài liệu chung qua entry riêng khi bị chặn, nhưng không dùng nó như fallback cá nhân hóa và không gắn nhãn phù hợp bệnh lý.
7. Chọn, đổi món, lưu và đọc lại thực đơn đều kiểm quyền và phiên bản. Không chỉ kiểm một lần lúc phân tích.
8. Service không reference ApiHost/module People hay SharedKernel. Hợp đồng snapshot qua HTTP; không SQL/FK/transaction xuyên DB. People giữ quyền sửa hồ sơ và kiểm owner ở endpoint nội bộ có credential riêng.

## 3. Ma trận 9 tình huống

| Tình huống | Quyết định backend | Nội dung và hành động UI | Điều kiện đi tiếp |
| --- | --- | --- | --- |
| 1. Thiếu thông tin | `needs_information` + danh sách missingFields theo prerequisite; xét cả cấu trúc và ghi chú | “Cần bổ sung thông tin”; chỉ hiện trường/câu hỏi thiếu, dữ liệu có sẵn được điền trước | Lưu đúng trường People, tăng revision, đánh giá lại; không bắt textarea |
| 2. Chưa rõ dị ứng | `needs_information`, reason `allergy_status_unknown` | Chọn “Có dị ứng thực phẩm” / “Đã xác nhận không có” / “Chưa rõ”; nếu có, nhập thực phẩm cụ thể | Có xác nhận lưu bền và không xung đột nguồn; “Chưa rõ” tiếp tục chặn cá nhân hóa |
| 3. Triệu chứng chưa biết bệnh | Giữ fact loại symptom; `needs_information` hoặc `needs_professional_guidance` nếu không có thông tin để làm rõ | “Chưa đủ thông tin để gợi ý theo bệnh lý”; xem lại dữ kiện/hướng dẫn hiện có | Có dữ kiện đủ cho phạm vi được hỗ trợ; không chuyển symptom thành diagnosis |
| 4. Thận/khó nuốt/ăn qua ống/hạn chế dịch, điện giải | `needs_professional_guidance` nếu ngoài phạm vi; nếu có rule hỗ trợ thì kiểm prerequisite và nguồn chỉ định | Nêu chính xác thông tin/hướng dẫn còn thiếu; CTA “Cập nhật hướng dẫn hiện có” | Policy và nội dung đã review cho tình trạng đó, đủ dữ kiện; không tự đặt mức dịch/điện giải hay kết cấu “ăn mềm” |
| 5. Nhiều bệnh | Tổng hợp mọi hard constraint tương thích; thiếu dữ liệu → `needs_information`; xung đột không giải quyết được → `needs_professional_guidance` | Hiển thị các yêu cầu cần làm rõ; không yêu cầu customer chọn bỏ một bệnh để tiếp tục | Toàn bộ ràng buộc bắt buộc có thể áp dụng cùng lúc |
| 6. Không có công thức đã duyệt | `no_content` nếu chưa có nội dung publish cho phạm vi; `no_match` nếu có nội dung nhưng không món nào đáp ứng | “Chưa có công thức đã duyệt cho nhu cầu này” hoặc “Chưa tìm được món đáp ứng các yêu cầu”; giữ hồ sơ/lựa chọn | Có phiên bản nội dung hợp lệ; không tự nới hạn chế hoặc dùng demo |
| 7. Lỗi AI | Assessment `failed`, mã lỗi và retryable; không tạo facts/confirmation thành công | “Chưa phân tích được thông tin. Dữ liệu đã nhập vẫn được giữ.”; thử lại khi được phép | Retry có kiểm quyền/revision/quota, hoặc phân tích bằng đường cấu trúc nếu đầu vào thật sự không cần AI |
| 8. Đổi hồ sơ/đăng xuất/hết phiên | Mọi request/job có scope owner + beneficiary; không dựa vào trạng thái UI để cấp quyền | Hủy HTTP/polling, bỏ response muộn, xóa kết quả cũ trước khi tải người mới; hết phiên chuyển đăng nhập | Phiên và đúng beneficiary được xác minh lại từ server |
| 9. Hồ sơ xóa/không thuộc customer | HTTP 404 thống nhất cho hồ sơ/child resource không khả dụng; không trả snapshot/AI/meal | “Hồ sơ không còn khả dụng”; về danh sách hồ sơ | Chọn một hồ sơ hợp lệ; không fallback sang người đầu danh sách |

Nếu nhiều lý do cùng tồn tại, backend trả danh sách reasons đầy đủ cho đúng owner; chọn trạng thái hiển thị theo ưu tiên: quyền/phiên → stale → lỗi xử lý → cần hướng dẫn chuyên môn → thiếu thông tin → cần xác nhận → kiểm danh mục → gợi ý. UI chỉ hiện tối đa ba câu hỏi thiết yếu mỗi lượt. Hết hai lượt làm rõ vẫn thiếu thì giữ trạng thái chặn và nêu phần chưa giải quyết; không tự cho qua.

## 4. Dữ liệu và migration

### 4.1. People

- Thêm `health_profile_revision bigint NOT NULL DEFAULT 1`, tăng nguyên tử khi dữ liệu ảnh hưởng Nutrition đổi: ngày sinh, trường sức khỏe, lưu ý/ghi chú, mobility note, care level và các metadata liên quan. Đổi tên/ảnh/địa chỉ không tự tăng revision sức khỏe. Delete vẫn chặn đọc ngay bằng ownership/lifecycle check.
- Thêm `food_allergy_status` với `unknown | reported_present | reported_none`; mặc định `unknown` cho toàn bộ dữ liệu cũ. Không đổi JSON Allergies legacy để ép về schema mới và không tự backfill `reported_none` từ mảng rỗng.
- Thêm metadata xác nhận dị ứng: `food_allergy_confirmed_at`, `food_allergy_confirmed_by`; backend gán từ phiên/thời gian server. `reported_present` yêu cầu danh sách dị ứng thực phẩm rõ; `reported_none` mâu thuẫn dị ứng còn hiệu lực phải được xử lý tường minh.
- Nếu PUT cũ thay Allergies mà không có xác nhận mới, vô hiệu xác nhận dị ứng và đưa status về `unknown`. Ghi chú trái với status tạo conflict trong assessment, không im lặng ưu tiên một nguồn.
- Metadata hướng dẫn chuyên biệt lưu dưới phần có schema version trong HealthHistory hiện hữu (chỉ thêm khi đã xác nhận không đụng key legacy): loại hướng dẫn, giá trị/đơn vị nếu được cung cấp, nội dung gốc, nguồn báo cáo, thời điểm và tình trạng còn áp dụng. Giữ nguyên các key legacy khác. Không giả danh verified clinician instruction từ lời customer.
- PATCH riêng chỉ nhận whitelist trường sức khỏe, có expectedHealthRevision; không yêu cầu địa chỉ/họ tên chỉ để xác nhận dị ứng. Trường không gửi giữ nguyên, null tường minh xóa về trạng thái chưa rõ theo validation. Revision conflict không tự merge/ghi đè.
- Adapter đọc legacy không hợp schema phải trả unresolved kèm source pointer. Có dữ liệu cũ không đọc được thì hỏi làm rõ phần đó, không bỏ toàn bộ hồ sơ.

### 4.2. Nutrition

Dùng các bảng được mô tả ở mục 12 của plan chính; cột query/ownership/revision/status dùng kiểu quan hệ, nội dung snapshot/facts/questions dùng JSONB có `schemaVersion` và kiểm schema. Bổ sung hợp đồng tối thiểu cho tình huống:

| Nơi lưu | Dữ liệu cần có |
| --- | --- |
| assessments | owner/beneficiary, health revision, status, input snapshot, extracted facts, unresolved/conflicts, decision, confirmation, parser/policy versions, error/retryable, idempotency fingerprint, attempts/lease token/lease expiry, timestamps |
| recipe_versions/rule_versions | review và publication status độc lập, nguồn + locator (chương/trang nếu từ sách), scope/prerequisites, version, người duyệt có vai trò phù hợp, thời điểm, trạng thái thu hồi |
| recommendations | assessment/profile/preferences/catalog/rule versions, decision/reasons, item IDs/version và serving; không tin client gửi nhãn eligible |
| meal_plans | snapshot bất biến tại lúc lưu, owner/beneficiary, source versions, revision, trạng thái stale và lý do; lịch sử không tự sửa theo recipe mới |

Idempotency unique theo owner + operation + key, kèm hash payload: cùng key/payload trả tài nguyên cũ; khác payload trả 409. Retry chủ động sau assessment failed tạo attempt/assessment mới liên kết bản cũ, key mới cho thao tác mới; retry do mất response dùng key cũ.

Migration People là `backend/init-db/38-nutrition-health-revision.sql`. Schema Nutrition riêng là `backend/init-db/nutrition-service/01-nutrition-workflow.sql`, role runtime ở `02-runtime-role.sql`. Không chạy SQL Nutrition lên DB CareSitter; không dùng EF migration. Worker lease/attempt đặt ở `assessment_jobs`; các cột lease legacy dự phòng trong assessments không được dùng để claim.

## 5. Hợp đồng backend và xử lý race

Các implementation hiện tại và điểm mở rộng:

- `IPeopleHealthClient` thuộc Nutrition gọi HTTP snapshot nội bộ. `IBeneficiaryHealthSnapshotReader` thuộc People thực thi truy vấn owner + beneficiary chưa xóa; chỉ People dùng shared contract nội bộ monolith. Nutrition giữ DTO riêng theo cùng JSON contract.
- `HealthSnapshotNormalizer`: xử lý JSON legacy và cấu trúc, giữ source pointer và phân biệt symptom/condition/food allergy/drug allergy/preference.
- `IHealthDescriptionParser`: chỉ phân tích văn bản còn cần đọc. Output schema đóng, quote phải có trong nguồn, concept có version. Không nhận flags eligibility từ model.
- `NutritionEligibilityPolicy`: hàm thuần trả decision, reasons, missingFields, conflicts, requiredGuidance và allowedActions từ snapshot/facts/confirmation/rules.
- `NutritionWorker`/`AssessmentProcessor`: claim job bền bằng lease token, giới hạn attempts, kiểm lại owner/lifecycle/revision trước đọc và trước ghi kết quả. Worker cũ hết lease không được ghi đè worker mới.
- `MealConstraintPolicy`: kiểm toàn bộ món/ngày khi generate, chọn ứng viên thay thế, replace và save; bao gồm allergen từ gia vị và dinh dưỡng thiếu. Không dùng số 0 thay dữ liệu chưa có.

Tách **trạng thái xử lý** assessment (`queued`, `processing`, `needs_information`, `awaiting_confirmation`, `confirmed`, `needs_professional_guidance`, `failed`, `stale`, `cancelled`) khỏi **kết quả kiểm điều kiện** (`needs_information`, `needs_professional_guidance`, `awaiting_confirmation`, `eligible`, `no_content`, `no_match`, `suggested`). `confirmed` chỉ có nghĩa customer xác nhận dữ kiện; không tự tương đương `eligible`.

Luồng chính:

```text
Kiểm phiên và ownership → đọc snapshot hiện hành
  → chuẩn hóa cấu trúc + phân tích văn bản khi cần
  → kiểm nguồn/xung đột/prerequisite
  → thiếu thông tin / cần hướng dẫn / chờ xác nhận
  → xác nhận đúng revision → kiểm eligibility + danh mục published
  → no_content / no_match / suggested
  → đổi/lưu: kiểm lại quyền + revision + toàn bộ ràng buộc
```

Tạo/confirm/generate/replace/save kiểm expected revision. Transaction ngắn chỉ trong DB Nutrition: owner advisory lock bảo vệ idempotency/quota; catalog epoch lock bảo vệ phiên bản nội dung. Đọc People trước thao tác và sau commit; đổi revision trả 409, mất hồ sơ trả 404. Mỗi GET/list/ứng viên và lần sử dụng lại đều đối chiếu People hiện hành. Không có transaction nguyên tử xuyên service: thay đổi ngay sau lần kiểm tra HTTP cuối sẽ được phát hiện ở lần đọc/sử dụng tiếp theo. Không giữ DB lock qua HTTP/AI; test mô phỏng nguồn đổi giữa commit và response, đồng thời test PATCH race trên PostgreSQL thật.

Event làm stale/cancel hỗ trợ cập nhật chủ động; tính đúng không phụ thuộc event đã tới. Mọi lần đọc dữ liệu nhạy cảm và dùng recommendation đều đối chiếu People hiện hành. Publish/retire nội dung cũng kiểm lại khi dùng, không chỉ lúc tạo assessment.

## 6. API và mã lỗi

Giữ các route đã phác thảo ở mục 7 plan chính. Khóa DTO trước code; mỗi type một file. Không nhận owner từ client.

| API | Hành vi phải có |
| --- | --- |
| GET/PATCH health-profile | GET trả cấu trúc hiện hữu + revision + trạng thái chưa rõ; PATCH cập nhật phần thiếu có revision, không làm mất trường khác |
| POST nutrition-assessments | Lưu job rồi trả 202 + Location; cùng idempotency key không tạo nhiều job; input lấy từ People |
| GET assessment | Trả processing status, decision, reasons và hành động; kiểm child ID thuộc đúng beneficiary và owner |
| POST assessment/confirm | Chỉ xác nhận facts của revision hiện hành; sửa cách AI đọc có provenance; thêm/sửa thông tin sức khỏe phải lưu People và tạo assessment mới |
| POST meal-recommendations | Chỉ thực thi khi assessment hợp lệ; trả suggested/no_content/no_match hoặc các trạng thái chặn, không bịa item để response có dữ liệu |
| GET recommendation; POST replacements | Kiểm quyền/revision/content versions; thay món phải kiểm cả thực đơn |
| POST/GET meal-plans; GET plan | Lưu có idempotency và expected revision; lịch sử stale có nhãn và không cho dùng lại như gợi ý hiện hành |

Response decision gồm `state`, `reasonCodes[]`, `missingFields[]`, `questions[]`, `conflicts[]`, `requiredGuidance[]`, `allowedActions[]`, `healthRevision`, `assessmentId` khi đã có. Mỗi question có ID ổn định, sourceField, inputType, options, required và purpose. UI ánh xạ mã sang tiếng Việt; không render HTML hay CTA do AI tự tạo.

Phân biệt lỗi giao thức và kết quả nghiệp vụ:

- HTTP 401: phiên không hợp lệ; 403: role không được phép; 404: hồ sơ/child ID không tồn tại, đã xóa hoặc không thuộc owner (không lộ tên hay nội dung).
- HTTP 409 + `nutrition.profile_changed`, `nutrition.assessment_stale`, `nutrition.content_changed` hoặc `nutrition.idempotency_conflict`: client nạp lại đúng phần, không tự ghi đè.
- HTTP 400: payload sai; 429: quá quota với hướng dẫn thời điểm thử lại. Provider không cấu hình/tính năng chưa mở trả lỗi dịch vụ rõ ràng, không giả lập success.
- Kết quả nghiệp vụ thiếu thông tin/cần hướng dẫn/no_content/no_match trả body có decision (HTTP 200 cho kết quả đã xử lý); job được nhận vẫn là 202.
- Worker phân tích thất bại: GET assessment trả HTTP 200 với `status=failed`, `errorCode`, `retryable`; mã đề xuất `nutrition.ai_timeout`, `nutrition.ai_unavailable`, `nutrition.ai_refused`, `nutrition.ai_invalid_output`. Đây không phải facts rỗng hay hồ sơ không bệnh.

Các mã lowercase có namespace trong tài liệu này thay ký hiệu minh họa `PROFILE_CHANGED` ở plan chính khi khóa API mới.

## 7. Giao diện customer và lifecycle

Phạm vi thiết kế đợt này là luồng chức năng và các trạng thái, chưa dựng mockup hình ảnh. Người đặt dịch vụ kiểm tra hồ sơ gia đình trên điện thoại tại nhà; dùng theme sáng, màu teal và components hiện có. Giữ entry trong chi tiết hồ sơ: “Gợi ý thực đơn”; cùng luồng cho bản thân và người thân, không thêm tab chính.

1. Đầu màn hình luôn có tên người đang chọn. Trong lúc tải hồ sơ mới, xóa nội dung cũ và hiện skeleton; không để món của người trước trên màn hình.
2. “Kiểm tra thông tin”: hiện các dữ kiện đã lưu, nguồn do gia đình báo cáo và phần chưa rõ. Chỉ mở các câu hỏi cần bổ sung; không bắt nhập lại bệnh trong textarea khi đã có cấu trúc đủ.
3. “Kiểm tra bản tóm tắt”: cho sửa cách diễn giải và xác nhận. Nút xác nhận không được ghi “Đã được bác sĩ xác minh”.
4. “Cần bổ sung”/“Cần hướng dẫn phù hợp”: tiêu đề + lý do cụ thể + trường cần sửa + CTA chính; giữ các dữ kiện đã nhập. Không chỉ hiển thị nút bị vô hiệu mà không giải thích.
5. Kết quả theo sáng/trưa/tối có khẩu phần, lý do, lưu ý và nguồn/version; mở chi tiết công thức khi cần. Có “Đổi món”/“Lưu thực đơn” khi backend cho phép.
6. `no_content` và `no_match` là hai empty state riêng; không hiển thị hình/món demo. `stale` có “Thông tin đã thay đổi — kiểm tra lại”; chặn đổi/lưu tới khi có kết quả hiện hành.

Provider dự kiến: `nutritionFlowProvider` autoDispose theo session generation + userId + beneficiaryId. Repository nhận Dio CancelToken; controller sở hữu request generation và polling timer. Đổi hồ sơ, logout, token refresh thất bại hoặc dispose: cancel token, dừng polling, invalidate state và bỏ mọi response muộn kể cả cancellation không có hiệu lực. Đăng nhập lại cùng userId vẫn tạo session generation mới.

Draft được giữ trong bộ nhớ đúng phiên/hồ sơ khi lỗi mạng/AI; phần đã lưu có thể đọc lại từ People. Logout/hết phiên xóa draft nhạy cảm và kết quả trong bộ nhớ. Không đưa draft vào SharedPreferences. Đổi hồ sơ chỉ có thể giữ draft trong scope hồ sơ cũ của cùng phiên, không hiện/merge sang hồ sơ mới. App quay lại từ background phải revalidate trước khi cho thao tác.

Hủy HTTP/polling không bảo đảm nhà cung cấp AI dừng hoặc job bền đã bị hủy. Job vẫn kiểm quyền xử lý/ownership/revision; profile bị xóa hoặc quyền xử lý bị rút thì cancelled, không publish output. Kết quả job hoàn tất chỉ đọc được qua phiên được xác thực và quyền hiện hành.

Kiểm UI tại 320/390/430 px, text scale 1.3/2.0, bàn phím mở; touch target từ 44 px, thông báo có chữ/icon, contrast theo theme, focus tới câu hỏi lỗi đầu tiên. Không dùng nhiều dialog nối tiếp hoặc card lồng card.

## 8. Backlog theo thứ tự thực hiện

| Đợt | Công việc và vị trí | Bàn giao / điều kiện hoàn tất |
| --- | --- | --- |
| N0. Khóa contract | Shared Contracts, JSON schema/fixtures và mapping source; thống nhất DTO với app | 9 tình huống đều ánh xạ được state/reason/action; chưa cần provider AI |
| N1. People và revision | Domain/mapping/handlers, health-profile GET/PATCH, migration additive; cập nhật mọi write path cũ | Không mất dữ liệu legacy; unknown dị ứng đúng nghĩa; ownership và concurrency PostgreSQL qua |
| N2. Nền Nutrition | Tạo Domain/Application/Infrastructure/Controllers, DI/solution/architecture tests, schema/RLS, assessment/idempotency/worker | POST→poll hoạt động bền, duplicate/crash/retry/lease và quyền được test; feature flags mặc định tắt |
| N3. Phân tích và policy | Normalizer, parser port/adapter, provenance/schema validator, conflicts, missingFields, confirm, eligibility | Bộ mẫu tiếng Việt và 9 tình huống chặn đạt; parser lỗi không cho success; nhóm chưa hỗ trợ luôn chặn đúng |
| N4. UI đánh giá | features/nutrition data/state/screens/widgets, route hồ sơ, PATCH bổ sung, summary và lifecycle | End-to-end backend thật cho đủ/thiếu/AI lỗi/đổi hồ sơ/đăng xuất/404; không cần công thức để nghiệm thu trạng thái |
| N5. Nội dung và món | Import/review/publish recipe/rule; generate/replace/save/read với version guards | Chỉ trả item published có nguồn, không vượt constraint; danh mục rỗng ra no_content, không phù hợp ra no_match |
| N6. Nghiệm thu và bật | Security/concurrency/e2e, metrics/quota, migration staging, thiết bị thật và pilot | Bật từng phạm vi đã có nội dung review; rollback tắt entry/worker/gợi ý mà giữ dữ liệu |

Thứ tự: N0 → N1 → N2 → N3 → N4 → N5 → N6. Công việc thu thập/duyệt nội dung của N5 có thể tiến hành từ sau N0; API gợi ý chỉ nghiệm thu khi nội dung tương ứng có thật. UI có thể viết bằng fixtures test sau N0 nhưng production không fallback vào fixtures.

Test People nằm trong `backend/tests/CareSitter.IntegrationTests/`; test Nutrition riêng trong `backend/services/nutrition/tests/`; app trong `frontend/customer-app/test/features/nutrition/`. N0–N4 đã có code và kiểm thử local; N5 có API/runtime nhưng chưa có danh mục chuyên môn thực; N6 staging/provider/thiết bị/pilot còn lại. Ma trận nghiệm thu dưới đây là tiêu chí, không phải mọi ca đều đã nghiệm thu end-to-end.

## 9. Ma trận kiểm thử bắt buộc

| ID | Ca test | Kết quả bắt buộc |
| --- | --- | --- |
| E01 | Cấu trúc đủ, không có ghi chú cần đọc | Không bắt textarea; không gọi AI; vẫn cần confirmation/eligibility |
| E02 | Chỉ thiếu một prerequisite; ghi chú có dữ liệu tương ứng | Hỏi đúng phần còn thiếu sau đối chiếu; không hỏi lại dữ liệu đã rõ |
| E03 | Allergies null, [], JSON legacy lỗi, hoặc chỉ dị ứng thuốc | Không suy ra reported_none cho dị ứng thực phẩm |
| E04 | Customer xác nhận không dị ứng nhưng ghi chú còn dị ứng tôm | Conflict; không âm thầm bỏ allergen constraint |
| E05 | “Nghi…”, “từng…”, triệu chứng, bệnh của người khác, phủ định | Giữ assertion/temporality/subject; không tạo chẩn đoán cho beneficiary |
| E06 | Từng nhóm thận/khó nuốt/ăn qua ống/dịch/điện giải thiếu hướng dẫn hoặc ngoài scope | Chặn đúng reason; không tự đề xuất ăn mềm, giới hạn hay khẩu phần điều trị |
| E07 | Hai bệnh có rules tương thích, thiếu prerequisite, hoặc xung đột | Áp dụng đồng thời hoặc chặn; không chọn bỏ một rule |
| E08 | Catalog rỗng/draft/reviewed chưa publish; published nhưng không match; thiếu allergen/nutrient cần thiết | no_content hoặc no_match đúng nghĩa; không coi thiếu là 0; không có demo |
| E09 | AI timeout/429/refusal/JSON sai/quote bịa/prompt injection/facts rỗng | failed/unresolved đúng mã; không tự confirmed; giữ draft đúng phiên |
| E10 | A→B khi request A chậm; logout→login cùng user; refresh thất bại | Response A không xuất hiện; timer/token được hủy; state đúng session generation |
| E11 | Owner khác, child ID khác beneficiary, profile xóa trong lúc AI chạy | Không lộ snapshot/facts/món; job không publish dữ liệu truy cập được |
| E12 | Sửa health qua PATCH/PUT cũ trong lúc confirm/generate/replace/save | Revision tăng; stale/409 đúng; không commit kết quả được coi là hiện hành từ revision cũ |
| E13 | Duplicate request, payload khác cùng key, worker chết/lease hết/worker cũ quay lại | Không tạo lặp; không ghi đè kết quả mới; retry và recovery có giới hạn |
| E14 | Rule/recipe thu hồi trong lúc lưu; đổi một món làm vi phạm tổng ngày | Kiểm lại toàn bộ, chặn content_changed/constraint; không âm thầm nới rule |
| E15 | Upgrade DB có health JSONB cũ; sửa tên/địa chỉ và sparse PATCH | Dữ liệu sức khỏe nguyên vẹn, metadata unknown đúng, revision tăng đúng phạm vi |
| E16 | UI màn hình nhỏ, text lớn, bàn phím, back/resume, retry | Không overflow, không mất draft do lỗi tạm thời, hành động và thông báo rõ ràng |

Nghiệm thu backend: unit policy/parser + contract/architecture + integration PostgreSQL thật cho RLS, revision, transaction, idempotency, lease. Nghiệm thu frontend: analyze/test/build, widget state/lifecycle và đi hết luồng trên backend staging với thiết bị thật. Bộ đánh giá AI tách fixture deterministic và đánh giá provider thực; mọi ca bỏ sót ràng buộc quan trọng phải được phân tích trước khi bật phạm vi đó.

## 10. Điều kiện phát hành và phụ thuộc

- Feature flags tách entry point, assessments và recommendations; mặc định tắt. Backend vẫn kiểm flags, không chỉ ẩn UI.
- Danh mục/rule phải có nguồn, version, người duyệt đúng phạm vi; chưa có người duyệt thì không tự đánh dấu published bởi tài khoản kỹ thuật.
- Provider AI, mục đích xử lý, tối thiểu hóa dữ liệu và retention cần cấu hình trước gọi dịch vụ thật. Không gửi tên/địa chỉ/điện thoại khi không cần cho phân tích.
- Metrics chỉ chứa mã trạng thái/lỗi, thời gian, attempts và phiên bản; không log mô tả/quote/dữ liệu y tế. Có chỉ số needs_information/professional/no_content/no_match, không lấy tỷ lệ luôn tạo món làm mục tiêu.
- Deploy theo migration → backend → app; verify schema và race tests trước bật. Tắt tính năng phải chặn job/gợi ý mới nhưng không xóa dữ liệu đã lưu.
- Plan hoàn thành khi các task/hợp đồng trên được duyệt để code; chức năng chỉ hoàn thành sau từng tiêu chí nghiệm thu, không dùng kết quả test self-booking làm bằng chứng Nutrition.

## 11. Source và tài liệu đã đối chiếu

- [Beneficiary domain](../../backend/caresitter-be/Modules/People/Domain/Beneficiary.cs).
- [UpdateBeneficiary handler](../../backend/caresitter-be/Modules/People/Application/Commands/Beneficiaries/UpdateBeneficiary/UpdateBeneficiaryCommandHandler.cs).
- [Beneficiary model phía customer](../../frontend/customer-app/lib/features/beneficiary/data/models/beneficiary_model.dart).
- [Theme customer](../../frontend/customer-app/lib/core/theme/app_theme.dart).
- [Plan thực đơn](MEAL_RECOMMENDATION_PLAN.md), [đặc tả phân tích](../backend/NUTRITION_ANALYSIS_SPEC.md), [plan hồ sơ bản thân](SELF_BOOKING_PLAN.md).
- [Quy ước](../QUY_UOC_CODE_VA_SECRET.md), [migration](../backend/docs/MIGRATIONS.md), [test PostgreSQL](../backend/tests/POSTGRESQL_TESTS.md).
