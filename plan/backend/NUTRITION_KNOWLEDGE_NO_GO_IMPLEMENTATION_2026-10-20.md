# Nutrition Knowledge — kế hoạch sau G0 NO-GO

> Cập nhật 20/10/2026 (Asia/Saigon). G0 v4 đã NO-GO cho tự động trích xuất: không model local nào đạt toàn bộ selection gate. Tài liệu này và các Markdown trong `plan/` chỉ lưu local theo rule repository.

## Quyết định

- Không chạy holdout sau khi selection fail; không dùng holdout để chọn lại model.
- Không cho LLM tự động đưa entity/relation/claim vào graph.
- Tiếp tục bằng graph dựng từ dữ liệu cấu trúc, mọi record ở trạng thái ứng viên và cần reviewer phù hợp.
- Không index/query sách, snapshot hay draft có `rights_status=unverified`.
- Tool graph không được giữ connection string và không tự ghi PostgreSQL Nutrition. Việc import/review/publish chỉ đi qua CatalogTool và cổng DB; chưa nối Customer app và chưa publish catalog thật ở pha này.

## Pha M1 — quyền nguồn và intake

1. Gửi yêu cầu xác nhận quyền cho từng sách, snapshot thực phẩm và phạm vi sử dụng: trích xuất, index local, citation nội bộ, redistribution/production.
2. Chỉ chuyển manifest sang `permitted` khi có bằng chứng, người kiểm tra, thời gian và hash revision cụ thể.
3. USDA FoodData Central chỉ là nguồn dự phòng `unverified` cho tới khi chọn dataset/release và kiểm điều khoản; không tự tải hay index.

**Cổng:** nguồn có hash, quyền và `allowed_uses` đầy đủ; thay đổi file làm hash mismatch và bị chặn.

## Pha M2 — candidate graph có cấu trúc

1. Parse catalog bundle theo trường đã định nghĩa, không dùng LLM để đoán quan hệ.
2. Sinh ID ổn định cho node/cạnh từ source revision + payload chuẩn hóa.
3. Mọi candidate bắt đầu `pending_review`; `automatic_admissions=0`.
4. Edge chỉ materialize khi cả hai node đầu mút đã được duyệt.

**Cổng:** deterministic rerun, không dangling edge, provenance tới revision nguồn, không nguồn unverified.

## Pha M3 — review và graph nội bộ

1. Data steward chỉ duyệt source/citation/concept.
2. Recipe, rule và cạnh có ý nghĩa dinh dưỡng phải do dietitian hoặc physician duyệt.
3. Quyết định reviewer khóa theo hash candidate và hash graph; sửa graph làm ledger cũ vô hiệu.
4. Graph materialized vẫn là local/internal, chưa phải catalog published.

**Cổng:** 100% record có quyết định hợp lệ; rule/bữa ăn có reviewer chuyên môn; quyền nguồn đã đủ.

## Pha M4 — retrieval eval trước tích hợp

1. Tạo ít nhất 30 câu hỏi độc lập và đáp án/citation chuẩn.
2. So sánh keyword/RAG thường với traversal graph trên cùng tập; không tune trên tập đánh giá.
3. Chỉ giữ GraphRAG nếu cải thiện rõ ở câu hỏi nhiều bước mà không làm giảm citation accuracy.
4. Sau đó mới thiết kế service read-only; publish catalog vẫn qua release-check, quyền dữ liệu và reviewer lâm sàng hiện có.

## Phần đã implement

- Module `backend/services/nutrition/tools/nutrition_knowledge_manual/`.
- Rights gate fail-closed cho `synthetic/permitted` và hash/size/path.
- Builder candidate graph deterministic từ catalog JSON.
- Decision ledger, policy reviewer và materializer chống stale/tamper/dangling edge.
- Fixture tổng hợp và test; draft P2 và USDA candidate vẫn `unverified`.
- `prepare-release` chỉ tạo evidence/authorization khi bundle và toàn bộ citation source đều `permitted`, graph được duyệt đủ, và reviewer lâm sàng trong ledger khớp evidence.
- CatalogTool buộc `import` thật nhận cả bundle lẫn evidence đã qua `release-check`; chỉ `--dry-run` được kiểm bundle riêng.
- Release evidence có `knowledgeReview` gắn hash candidate graph, decision ledger, reviewed graph, quyền nguồn và reviewer.
- PostgreSQL có trigger `require_catalog_knowledge_review` để chặn evidence thiếu/sai ngay tại biên DB; AppHost, Compose, local bootstrap và readiness đều mang migration/cổng này.
- Đã chạy 11 test pipeline thủ công, 106 unit test Nutrition và 18/18 PostgreSQL workflow test trên database dùng một lần; không seed/publish dữ liệu thật.

## Trạng thái hiện tại

- Chuỗi kỹ thuật M1–M3 đã có fail-closed gate và đã được kiểm chứng bằng fixture.
- Draft `adult-hypertension-p2` vẫn bị `release-check` chặn vì `technical_draft`, 12 recipe và rule còn unresolved, chưa có clinical review và chưa có knowledge review.
- `prepare-release` trên draft thật bị chặn ở `rights_status=unverified` và không sinh artifact đầu ra.
- Chưa đủ điều kiện M4 hay tích hợp Customer app: MOH/USDA chưa bind artifact cụ thể, chưa có reviewer chuyên môn và chưa có tập đánh giá retrieval độc lập.

## Cập nhật chunk PDF

- Workspace owner đã cho phép sử dụng local/internal cho các revision hiện có. Sách Dinh dưỡng lâm sàng 2019, snapshot thực phẩm và bundle P2 đã được gắn `permitted`; MOH/USDA chưa có artifact cụ thể nên vẫn fail-closed.
- Đã thêm `chunk-pdf` dùng `pdfplumber`, chuẩn hóa Unicode NFC, giữ source revision/hash, trang PDF/trang in, heading, loại nội dung và ID/hash ổn định.
- Sách 545 trang tạo 610 chunk; 545 chunk văn bản đủ điều kiện retrieval-eval, 63 chunk bảng và 2 chunk ngắn cần duyệt tay. Không có chunk nào vượt 700 lexical token.
- Hai lần chạy cho cùng source revision cho cùng SHA-256 output `becfbe2eea44d5dcba49a23f7407222e21a131a64ad3073f6f363e7448ebffd4`.
- Chunk hiện chỉ nằm trong artifacts local; chưa embedding, chưa đưa vào graph và chưa nối endpoint người dùng.
