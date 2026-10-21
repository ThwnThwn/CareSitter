# Kế hoạch seed GraphRAG local cho kho tri thức Nutrition

> Cập nhật: 20/10/2026 (Asia/Saigon). Trạng thái: **kế hoạch, chưa triển khai pipeline hoặc index sách**. Phạm vi chỉ là công cụ nghiên cứu/soạn bản nháp nội bộ; không thay catalog đã duyệt, không mở chức năng hỏi đáp y tế cho Customer. Tài liệu lưu local, không commit/push nếu chưa có yêu cầu riêng.

## 1. Quyết định và ranh giới

- Chọn **Python 3.12 + Ollama chạy local + custom extractor JSON + NetworkX/Parquet + tìm kiếm vector in-memory** cho bản đầu. Không cần Neo4j, community report hay một DB mới khi mới có vài tài liệu. `bge-m3` là ứng viên embedding tiếng Việt; G0 sàng lọc `qwen3:1.7b`, `qwen3:4b` và `gemma3:4b` bằng fixture gold trước khi khóa model. Có thể dùng tìm kiếm từ khóa trước khi embedding sẵn sàng.
- Máy hiện tại: khoảng 31,4 GiB RAM, RTX 3050 Ti Laptop GPU hiển thị 4 GiB VRAM; `ollama` chưa được tìm thấy, Python hiện có là 3.14.5. Cần môi trường Python 3.12 riêng và đo tốc độ/VRAM thực tế trước khi khóa model hoặc `num_ctx`; không thay Python hệ thống. Context lớn tốn thêm bộ nhớ, không mặc định 16–32k.
- **Không dùng LightRAG/Microsoft GraphRAG làm lõi ngay.** Custom pipeline là lựa chọn đã chốt cho G0–G2. LightRAG chỉ là nhánh benchmark retrieval ở G3 trên cùng tập gold; Microsoft GraphRAG và community summaries chỉ xét khi corpus và câu hỏi tổng hợp thật sự cần. Không đưa cả hai framework vào luồng sản phẩm chỉ vì tên “GraphRAG”.
- Tài liệu sách và snapshot thực phẩm chưa được xác nhận quyền khai thác lại; gắn `rights_status=unverified`. Prototype dùng fixture tổng hợp/nguồn được phép trước. Không tự động gửi văn bản sách hoặc hồ sơ người dùng tới Gemini/OpenAI hay provider khác. Xử lý local không tự chứng minh quyền sử dụng cho sản phẩm.
- Graph nháp **không phải nguồn quyết định lâm sàng**. Nutrition runtime hiện dựng graph nhỏ từ concept/rule đã publish bằng `HealthKnowledgeGraphRetriever`; thực đơn đọc `recipe_versions` published. Không sửa các luồng đó ở giai đoạn này. Một claim/edge do LLM trích xuất luôn có trạng thái `candidate`; không thể tự biến thành rule, nutrient hay recipe published.

## 2. Nguồn và hợp đồng dữ liệu tối thiểu

Nguồn đầu vào được đăng ký bằng manifest local: `source_id`, tên, ấn bản/năm, đường dẫn, SHA-256, kiểu file, ngôn ngữ, `rights_status`, phạm vi cho phép, ngày kiểm tra và người kiểm tra. Một thay đổi byte hoặc ấn bản tạo revision mới; không ghi đè revision đã dùng để trích dẫn.

| Nguồn hiện có | Xử lý dự kiến |
| --- | --- |
| `book/Dinh_duong_lam_sang_Vien_Dinh_duong_2019.pdf` | Kiểm lớp text/page; OCR có chọn lọc nếu trang không đọc được; chưa bật làm corpus sản phẩm khi quyền chưa rõ. |
| Hai HTML trong `book/` | Phân biệt bản đọc thử chính thức với trang metadata; không gán nội dung toàn sách cho hai file này. |
| Snapshot 13 thực phẩm và bundle P2 trong `backend/services/nutrition/catalog/` | Nạp làm **dữ liệu có cấu trúc ở trạng thái nháp**; giữ mã, đơn vị, dạng sống/chín và locator; không suy nutrient bị thiếu thành 0. |

Đầu ra nội bộ gồm `documents`, `chunks`, `entities`, `relations`, `claims`, `embeddings`, `run_manifest` ở Parquet và graph NetworkX dựng từ các bảng đó. Mỗi chunk giữ `source_id`, revision/SHA, chương hoặc mục, trang in nếu xác định được, trang PDF, thứ tự và offset. Nếu không xác định được trang hoặc OCR kém, đánh dấu `location_unverified` và không dùng làm chứng cứ định lượng. Mỗi relation/claim phải trỏ tới ít nhất một chunk cụ thể và trạng thái review. ID ổn định theo nguồn + revision + vị trí, không theo tên tự do do LLM sinh.

Ontology phiên bản đầu: `SourceDocument`, `Passage`, `Condition`, `Ingredient`, `Nutrient`, `Allergen`, `RecipeDraft`, `RuleCandidate`. Quan hệ cho phép: `CONTAINS`, `MENTIONS`, `CITES`, `HAS_NUTRIENT_CLAIM`, `HAS_ALLERGEN_CLAIM`, `PROPOSES_RULE_FOR`. `PROPOSES_RULE_FOR` không đồng nghĩa `approved` hoặc `safe_for`. Không đưa bệnh nhân, booking hoặc hồ sơ cá nhân vào graph tài liệu.

Đặt một **seam** ở công cụ nghiên cứu với interface nhỏ: `index(manifest) → run report` và `search(question, filters) → cited hits`. Module giấu chi tiết PDF/OCR, chunk, Ollama, embedding, graph và Parquet; caller chỉ biết trạng thái nguồn, trích dẫn, lỗi và giới hạn kết quả. Adapter local dùng file/Parquet; test dùng corpus tổng hợp có trang và quan hệ biết trước. Chưa tạo seam DB/Neo4j khi chưa có adapter thứ hai thực sự cần.

## 3. Các pha triển khai và cổng nghiệm thu

### G0 — khóa phạm vi nguồn và môi trường

Checklist thực thi và cổng kiểm tra chi tiết: [G0 — khóa nguồn và môi trường](NUTRITION_LOCAL_GRAPHRAG_G0_2026-10-20.md). Chưa triển khai G0.

- Lập manifest, phân loại `synthetic`, `permitted`, `unverified`, `denied`; chỉ hai loại đầu được vào index thử nghiệm mặc định. Dữ liệu `unverified` chỉ được kiểm tra thủ công trong máy, không tự động chuyển thành corpus để trả lời.
- Tạo venv Python 3.12, khóa dependency, cài Ollama local khi triển khai; bind cổng local, không bật cloud fallback hoặc public port. Lưu index/cache/log ngoài Git (ví dụ dưới `backend/artifacts/nutrition-knowledge-local/`); log không chứa nguyên văn tài liệu hay hồ sơ sức khỏe.
- Kiểm GPU/CPU thực tế với 20 ca fixture gold khó, đo strict F1 entity/relation/claim, lỗi JSON, độ trễ, VRAM/RAM và offload. Chọn model trích xuất theo ngưỡng cố định trong checklist G0; `bge-m3` cho embedding nếu chạy ổn. Nếu không đáp ứng ngưỡng, giữ pipeline keyword + duyệt tay, không giảm tiêu chí an toàn.

**Xong khi:** môi trường tái lập được, source manifest có SHA/quyền, fixture chạy hoàn toàn offline và không có lệnh nào ghi DB Nutrition đang dùng.

### G1 — trích xuất, chunk và provenance

- PDF/HTML/TXT: trích text theo trang/mục; giữ mapping trang in/PDF riêng; bảng và chú thích không trộn vào câu văn. OCR là nhánh riêng có báo cáo độ tin cậy và kiểm mẫu thủ công.
- Chunk theo đoạn/mục, đo bằng tokenizer của model đã chọn (khởi điểm 300–800 token, overlap 10–15% **chỉ là giả thuyết để benchmark**). Không cắt ngang bảng, đơn vị hay hàng thực phẩm. Từ bảng/CSV/JSON thì parse cột có cấu trúc, không đưa cả bảng qua LLM để “đoán” quan hệ.
- Hash đầu vào và từng chunk; rerun không đổi phải ra cùng ID và không nhân bản node. File bị sửa chỉ reindex revision chịu ảnh hưởng; có lệnh xóa một nguồn và mọi dẫn xuất của nó trong index nháp.

**Xong khi:** mọi hit quay lại đúng file + trang/mục; không có chunk không rõ nguồn lọt vào truy vấn mặc định; test idempotency và xóa nguồn đạt.

### G2 — graph candidate và tìm kiếm

- Seed trực tiếp các concept/mã/quan hệ từ bundle cấu trúc; LLM local chỉ trích entity/relation/claim **ứng viên** từ chunk văn bản theo JSON schema/ontology đóng. Validate JSON, source span, kiểu đơn vị, alias; lỗi thì cách ly, không tự sửa thành dữ kiện.
- Entity resolution theo ID/mã và alias có chủ đích; fuzzy/embedding chỉ tạo danh sách đề nghị gộp. Không auto-merge bệnh, dị nguyên hay nutrient chỉ vì tên gần giống.
- Lưu graph NetworkX + Parquet; tạo embedding chunk/entity bằng cùng một model cho index và query. Với corpus nhỏ, cosine exact search in-memory trước; chỉ thêm vector store khi benchmark chứng minh cần. Truy vấn local kết hợp keyword/vector, rồi mở 1–2 hop có giới hạn và trả `cited hits`; thiếu chứng cứ thì trả không đủ nguồn.
- Community detection/tóm tắt cộng đồng là G2b tùy chọn: chỉ làm sau khi graph đủ lớn và bộ câu hỏi “global” cho thấy local search thiếu. Summary là dữ liệu sinh tự động có links ngược về chunk, không là nguồn độc lập.

**Xong khi:** mọi claim/edge đều có chunk nguồn, 0 edge không thuộc ontology, 0 auto-merge nhóm nhạy cảm và không có câu trả lời định lượng không trích dẫn.

### G3 — đánh giá và cổng tích hợp

- Tạo tối thiểu 30 câu hỏi tiếng Việt có đáp án/trang chuẩn: tìm trang, phân biệt ấn bản, thực phẩm sống/chín, đơn vị natri/muối, dị nguyên ẩn, nguồn mâu thuẫn và “không đủ bằng chứng”. Đánh giá retrieval trước generation; mục tiêu thử nghiệm: `recall@5 ≥ 0,90` trên tập gold, 100% citation trỏ về chunk tồn tại, 0 claim số liệu/rule không có nguồn. Các ngưỡng cần khóa trước khi tune trên tập kiểm tra.
- Rà thủ công ít nhất mẫu 50 node/edge ứng viên hoặc toàn bộ nếu ít hơn; phân loại sai nguồn, sai loại quan hệ, gộp nhầm, OCR/đơn vị và suy diễn y khoa. So sánh keyword-only với keyword+embedding và LightRAG thử nghiệm trên cùng tập gold; chỉ chọn giải pháp thêm nếu cải thiện có ý nghĩa.
- Kết quả đạt vẫn chỉ dùng **soạn bundle/evidence nháp**. Chuyển sang catalog phải qua quyền dữ liệu, kiểm phép tính/dị nguyên, `release-check`, reviewer lâm sàng và cổng DB hiện có. Không nối endpoint này vào Customer app trong pha này.

**Xong khi:** có báo cáo số đo tái lập, ví dụ truy vấn với citation đúng, danh sách lỗi còn lại và quyết định go/no-go cho việc dùng công cụ nội bộ.

## 4. Điều chưa được làm ở plan này

- Không seed hoặc publish 12 bữa/rule nháp; DB `nutrition` đang có 0 package/0 món published ở lần kiểm tra trước.
- Không dùng Gemini free tier như fallback âm thầm: đó không còn là pipeline local và cần quyết định riêng về quyền dữ liệu, riêng tư, quota.
- Không mua/cài Neo4j, bật LightRAG WebUI ra LAN, hoặc thay `HealthKnowledgeGraphRetriever` hiện tại trước khi nghiệm thu nội bộ.
- Không hứa model 7–8B, chunk 300–800 hay context 16–32k là “chuẩn”; lựa chọn cuối phụ thuộc benchmark trên GPU 4 GiB/CPU và tập gold tiếng Việt.

## 5. Tham chiếu kỹ thuật đã đối chiếu

- [Ollama structured outputs](https://docs.ollama.com/capabilities/structured-outputs): API local nhận JSON schema; kết quả vẫn cần validate ứng dụng.
- [Ollama embeddings](https://docs.ollama.com/capabilities/embeddings) và [bge-m3 trên Ollama](https://ollama.com/library/bge-m3): `/api/embed`, dùng cùng embedding model khi index/query.
- [Ollama context length](https://docs.ollama.com/context-length): tăng context tăng nhu cầu bộ nhớ; kiểm cấu hình thực tế thay vì giả định giá trị mặc định.
- [LightRAG README](https://github.com/HKUDS/LightRAG/blob/main/README.md): có local/graph/vector và citation, nhưng storage mặc định phù hợp thử nghiệm nhỏ; server phải bind loopback hoặc bật xác thực.
- [Microsoft GraphRAG indexing](https://microsoft.github.io/graphrag/index/overview/) và [query modes](https://microsoft.github.io/graphrag/query/overview/): community reports/global search là một pipeline khác, nặng hơn và không bắt buộc cho thử nghiệm đầu.

Tài liệu dự án liên quan: [sổ nguồn P2](NUTRITION_P2_SOURCE_REGISTER.md), [đối chiếu seed và release](NUTRITION_GRAPHRAG_SEED_SOURCE_CHECK_2026-10-20.md), [kế hoạch nội dung P2](NUTRITION_P2_CONTENT_PLAN.md).
