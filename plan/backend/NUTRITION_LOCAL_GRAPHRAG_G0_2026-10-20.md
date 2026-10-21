# G0 — khóa nguồn và môi trường cho GraphRAG Nutrition local (v4)

> Cập nhật 20/10/2026 (Asia/Saigon). Đây là runbook triển khai v4. Chỉ sàng lọc kỹ thuật bằng fixture tổng hợp; không cấp quyền dùng sách, không duyệt lâm sàng, không tạo endpoint Customer và không ghi PostgreSQL Nutrition.

## Trạng thái triển khai

| Hạng mục | Trạng thái |
| --- | --- |
| Module custom extractor/gate | Đã tạo tại `backend/services/nutrition/tools/nutrition_knowledge_g0/` |
| Fixture tổng hợp | Đã tạo 38 ca: dev 6, selection 20, holdout 12 |
| Ontology/schema/prompt/ngưỡng | Đã khóa bằng file cấu hình có hash khi freeze |
| Manifest quyền | 3 fixture `synthetic`; sách và draft catalog/evidence giữ `unverified` |
| Python | Đã cài 3.12.10 song song; venv nằm ngoài Git trên D: |
| Ollama | Đã cài 0.40.5 trên D:, loopback-only, `OLLAMA_NO_CLOUD=1` |
| Model | Đã khóa 4 extractor + `bge-m3` bằng tag, digest và quantization trong freeze `g0-v4` |
| Test source | 7/7 test đạt sau benchmark |
| Selection | Đã chạy 20 ca × 2 lượt cho cả 4 model; tất cả fail cổng |
| Offline/holdout | Không chạy vì selection NO-GO; holdout vẫn chưa bị tiêu thụ |
| Quyết định | Chuyển sang structured candidate graph + duyệt tay; xem `NUTRITION_KNOWLEDGE_NO_GO_IMPLEMENTATION_2026-10-20.md` |

## Hợp đồng đã đóng thành code

- Manifest fail-closed: chỉ `synthetic` hoặc `permitted` đúng `allowed_uses` mới được query/index. `unverified` và `denied` chỉ có metadata.
- Fixture có `span_id`; quote được chuẩn hóa NFC/NFD/NBSP nhưng vẫn ánh xạ về offset gốc. Quote lặp trong cùng span bị loại.
- Metric tách `extraction_f1`, `evidence_locatable_rate` và `admission_precision`.
- Selection chạy đúng 20 ca hai lượt; chấm từng lượt, bootstrap theo `case_id` giữ cặp run và chỉ dùng mô tả.
- Holdout 12 ca dùng marker tạo độc quyền trước lúc chạy nên mỗi freeze chỉ được tiêu thụ một lần.
- Freeze giữ hash fixture/config/source code/lock, đúng model tag, digest, quantization, capabilities, Python và Ollama.
- Benchmark từ chối model ngoài freeze, digest/quantization đổi, model khác còn load, artifact ghi ngoài thư mục ignore, context bị cắt hoặc `done_reason` khác `stop`.
- Gói dùng Python stdlib, không import driver DB, không đọc `.env`/`appsettings` và CLI không nhận connection string.
- Báo cáo tổng hợp không chứa raw fixture/prompt; prediction chi tiết chỉ nằm ở artifact local đã ignore.

## Fixture v4

| Nhóm chính | Dev | Selection | Holdout |
| --- | ---: | ---: | ---: |
| Phủ định | 1 | 4 | 2 |
| Số liệu + đơn vị | 2 | 6 | 3 |
| Bảng | 1 | 3 | 2 |
| Alias | 1 | 3 | 2 |
| Tham chiếu mơ hồ | 0 | 2 | 1 |
| Không có gì để trích xuất | 1 | 2 | 2 |

Selection có 4 ca dài, 3 ca kết hợp và 9 relation nhạy hướng. Holdout có 2 ca dài, 1 ca kết hợp và 5 relation nhạy hướng. Có fixture NFD và NBSP.

## Lệnh thực thi

```powershell
$artifacts = 'D:\EXE\CareSitter\backend\artifacts\nutrition-knowledge-local'
$python = "$artifacts\venv\Scripts\python.exe"

& $python -m nutrition_knowledge_g0 validate
& $python -m nutrition_knowledge_g0 preflight --output "$artifacts\preflight.json"
& $python -m nutrition_knowledge_g0 baseline --output "$artifacts\manual-baseline.json"
& $python -m nutrition_knowledge_g0 freeze --output "$artifacts\freezes\g0-v4.json"

& $python -m nutrition_knowledge_g0 benchmark-selection --freeze "$artifacts\freezes\g0-v4.json" --model 'qwen3:1.7b'
& $python -m nutrition_knowledge_g0 benchmark-selection --freeze "$artifacts\freezes\g0-v4.json" --model 'qwen3:4b'
& $python -m nutrition_knowledge_g0 benchmark-selection --freeze "$artifacts\freezes\g0-v4.json" --model 'gemma3:4b'
& $python -m nutrition_knowledge_g0 benchmark-selection --freeze "$artifacts\freezes\g0-v4.json" --model 'qwen3:8b'

# Code chỉ ghi nhận model đúng luật chọn v4 sau khi đủ kết quả bốn candidate.
& $python -m nutrition_knowledge_g0 record-selection --freeze "$artifacts\freezes\g0-v4.json" --model '<model-do-code-chon>'

# Phải có evidence offline hai lớp trước lệnh holdout.
& $python -m nutrition_knowledge_g0 benchmark-holdout --freeze "$artifacts\freezes\g0-v4.json"
& $python -m nutrition_knowledge_g0 embedding-smoke --freeze "$artifacts\freezes\g0-v4.json" --output "$artifacts\bge-m3-smoke.json"
& $python -m nutrition_knowledge_g0 report --freeze "$artifacts\freezes\g0-v4.json" --preflight "$artifacts\preflight.json" --output "$artifacts\g0-report.json"
```

## Cổng không được lách

- Không model nào đạt selection: không chạy holdout, chuyển keyword + duyệt tay.
- Không có offline evidence hai lớp: lệnh holdout bị từ chối.
- Holdout fail: không chọn model khác trên cùng holdout; tạo revision và holdout mới.
- Sách/draft còn `unverified`: luôn no-go cho index/query, kể cả fixture G0 đạt.
- Chỉ khi holdout và offline cùng pass, báo cáo mới ghi `go_g1_with_reviewed_fixture`; vẫn không có nghĩa là được dùng nguồn thật hoặc đưa ra Customer.

## Kết quả selection thực tế

| Model | Entity F1 | Relation/claim F1 | Semantic valid | Schema valid | P95 | Kết luận |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `qwen3:1.7b` | 0,594 | 0,360 | 10/20 | 20/20 | 5,17 s | Fail |
| `qwen3:4b` | 0,704 | 0,413 | 13/20 | 20/20 | 21,65 s | Fail |
| `gemma3:4b` | 0,575 | 0,302 | 9/20 | 20/20 | 14,56 s | Fail |
| `qwen3:8b` | 0,829 | 0,583 | 17/20 | 19/20 | 42,28 s | Fail |

Hai lượt của từng model cho cùng F1; 8B tốt nhất nhưng vẫn dưới ngưỡng relation/claim F1 0,75 và semantic-valid 19/20. Không model nào được ghi selection addendum.
