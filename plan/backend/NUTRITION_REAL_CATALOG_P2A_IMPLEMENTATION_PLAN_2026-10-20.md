# Nutrition Catalog P2A — kế hoạch tạo, duyệt và phát hành thực đơn thật

> Cập nhật 20/10/2026 (Asia/Saigon). Plan này chỉ mô tả triển khai; chưa tự động publish dữ liệu. Markdown trong `plan/` giữ local theo rule repository.

## 1. Mục tiêu và quyết định phạm vi

Mục tiêu đầu tiên là phát hành **P2A baseline** cho người lớn có đường ăn miệng, nuốt bình thường, không khai báo bệnh lý/dị ứng/thuốc hoặc nhu cầu hạn chế đặc biệt. P2A tạo được 3 bữa và hỗ trợ đổi/lưu món, nhưng không được trình bày là điều trị bệnh.

P2B tăng huyết áp là release riêng, chỉ thực hiện sau khi có nguồn hướng dẫn điều trị được gắn file/revision/hash và reviewer chuyên môn. Không để rule tăng huyết áp đi kèm P2A nhằm “vượt cổng”.

Current baseline:

- Draft có 12 món: đúng 4 sáng, 4 trưa, 4 tối; dùng 13 mã nguyên liệu và snapshot hiện có đủ 13/13 mã.
- Sáu chỉ số đã có: năng lượng, protein, carbohydrate, lipid, chất xơ, natri.
- 64 tổ hợp hiện cho khoảng 960,60–1.250,65 kcal, 38,63–51,69 g protein và 105,52–293,97 mg natri từ ba bữa. Đây là số đo kỹ thuật, chưa phải kết luận đủ dinh dưỡng.
- Cả 12 món còn hai unresolved item: khẩu phần/cách chế biến chưa được chuyên gia duyệt và chưa chốt cách áp dụng hệ số hao hụt/retention khi nấu.
- Chưa có reviewer dietitian/physician; đây là blocker của production release, không phải blocker của việc hoàn thiện authoring tool và review packet.

## 2. Kiến trúc module và seam

Tạo một module sâu `catalog_authoring` bên trong `nutrition_knowledge_manual`. Interface ngoài chỉ có hai thao tác:

1. `prepare-catalog-candidate`: nhận profile, draft recipe, snapshot thực phẩm và corpus chunk; trả về candidate bundle, candidate evidence, review packet và manifest hash.
2. `finalize-catalog-candidate`: nhận candidate manifest cùng decision ledger/clinical review; chỉ trả release bundle/evidence khi mọi gate đạt.

Implementation ẩn toàn bộ mapping, tính chất dinh dưỡng, provenance, coverage report và sinh artifact. Callers không được tự tính nutrient hoặc sửa evidence rải rác.

Python authoring module không có connection string và không ghi PostgreSQL. `CareSitter.Nutrition.CatalogTool` tiếp tục là DB adapter duy nhất qua chuỗi `release-check → import → review → publish`. Runtime Customer app chỉ đọc catalog đã published.

## 3. Pha A0 — khóa nghĩa sản phẩm và input

### Việc làm

- Khóa profile `adult_baseline_v1`: population, điều kiện được phép, điều kiện bị chặn và ý nghĩa của ba bữa.
- Quyết định rõ một trong hai nghĩa:
  - **Full-day menu:** phải có target/range được reviewer phê duyệt cho năng lượng, protein và các chỉ số bắt buộc; hoặc
  - **Meal suggestions:** UI/evidence phải ghi rõ đây không phải khẩu phần đầy đủ cả ngày.
- Khóa revision/hash của PDF, chunk JSONL, snapshot 13 thực phẩm và draft bundle.
- Tạo package key mới `adult-baseline-p2a-v1`; không sửa package technical draft tại chỗ.
- Candidate baseline phải bỏ rule `HYPERTENSION`, condition scope và citation MOH chưa bind artifact.

### Cổng A0

- Profile JSON có schema/version/hash.
- Không còn ambiguity “thực đơn đầy đủ” hay “gợi ý ba bữa”.
- Mọi input có path, byte size, SHA-256 và rights `permitted`.

## 4. Pha A1 — authoring deterministic

### Việc làm

- Thêm `catalog_authoring.py` và hai CLI command tại module hiện có.
- Map nguyên liệu bằng `conceptCode`, không fuzzy auto-merge. Mã thiếu/trùng/basis lệch làm cả candidate fail.
- Recompute sáu nutrient từ snapshot theo Decimal và làm tròn hai chữ số; bundle không được cung cấp kết quả tính sẵn làm nguồn sự thật.
- Mỗi ingredient evidence giữ mã NIN, raw/cooked basis, lượng, edible portion, retention/yield decision và source locator.
- Chốt semantics hệ số:
  - Nếu lượng và bảng đều cùng basis, hệ số identity phải được ghi rõ lý do;
  - Nếu chuyển raw↔cooked hoặc áp dụng hao hụt, cần nguồn/reviewer cho factor;
  - Không xóa unresolved chỉ vì đặt factor bằng `1`.
- Dị nguyên lấy từ ontology đóng; đậu tương/lạc/vừng phải đồng bộ giữa ingredients, concepts và recipe allergens.
- Chunk sách chỉ dùng để lấy nguyên tắc/locator và hỗ trợ review; không để LLM tự sinh lượng nguyên liệu hoặc nutrient.
- Sinh review packet JSON gồm 12 recipe cards, phép tính từng nutrient, citation trang/chunk, allergen, preparation steps, daily-combination coverage và flags.

### Artifact

- `adult-baseline-p2a-v1.candidate.bundle.json`
- `adult-baseline-p2a-v1.candidate.evidence.json`
- `adult-baseline-p2a-v1.review-packet.json`
- `adult-baseline-p2a-v1.candidate-manifest.json`

Tất cả đặt dưới `backend/artifacts/nutrition-knowledge-local/catalog-authoring/<run-id>/`, ngoài Git.

### Cổng A1

- Rerun cùng input cho cùng SHA-256 output.
- 13/13 ingredient codes map duy nhất; 0 fuzzy merge.
- 12/12 recipe có đủ sáu nutrient và phép tính khớp chính xác validator.
- 0 unknown allergen/citation/basis.
- Coverage report liệt kê toàn bộ 64 tổ hợp và flag mọi tổ hợp ngoài profile target.

## 5. Pha A2 — review có trách nhiệm

### Vai trò

- `data_steward`: duyệt mapping mã, revision nguồn, basis, phép tính và provenance.
- `dietitian` hoặc `physician`: duyệt khẩu phần, phối hợp món, cách chế biến, dị nguyên, ý nghĩa ba bữa và range dinh dưỡng.

Engineering không tự nhận vai reviewer lâm sàng. LLM chỉ được gợi ý candidate/flag và không được ghi quyết định approve.

### Quy trình

- Mỗi recipe card có approve/reject riêng, reviewer ID/role/time/comment và candidate SHA-256.
- Thay đổi lượng, nutrient, allergen, preparation hoặc source làm quyết định cũ stale.
- Reviewer phải quyết định rõ factor/retention; unresolved item chỉ được đóng bằng decision có lý do.
- Clinical review cuối phải tham chiếu chính candidate manifest hash và khớp reviewer trong knowledge ledger.

### Cổng A2

- 100% candidate có quyết định hợp lệ; 0 pending/rejected/stale/dangling edge.
- 12/12 món có data review và clinical review.
- Daily coverage phù hợp product semantics A0; nếu chưa có target được duyệt thì no-go production.

## 6. Pha A3 — tạo release artifact và release-check

### Việc làm

- `finalize-catalog-candidate` tạo immutable bundle/evidence mới; không sửa candidate đã duyệt.
- Bundle baseline có `rules=[]`, supported scope không chứa condition code và chỉ giữ citation thật sự được dùng.
- Evidence đặt `contentStatus=review_ready`, `releaseProfile=adult_baseline_v1`, `calculationBasis` rõ ràng và `unresolvedItems=[]`.
- `knowledgeReview` gắn candidate graph, decision ledger, reviewed graph, rights revisions và clinical reviewer.
- Chạy CatalogTool `release-check` trên đúng hai file final.

### Cổng A3

- `bundleValid=true`, `releaseReady=true`, issues rỗng.
- Đúng 4 recipe cho mỗi meal type; đúng 12 recipe.
- Baseline và từng dị nguyên còn ít nhất 2 lựa chọn mỗi bữa, `validCombinations > 0`.
- Digest của bundle/evidence/authorization được ghi trong release manifest.

## 7. Pha A4 — import, review, publish và rollback

### Trình tự bắt buộc

1. Backup/ghi nhận state catalog trước release.
2. `catalog-tool import <bundle> <evidence>` bằng importer role.
3. Đọc package ID và digest trả về; đối chiếu release manifest.
4. `catalog-tool review <id> <digest> <bundle> <evidence>` bằng reviewer role.
5. `catalog-tool publish <id> <digest>` bằng publisher role.
6. Kiểm DB: 1 package published, 12 recipe published, 0 disease rule cho P2A, citation đầy đủ.
7. Rollback rehearsal bằng `retire <id> <reason>` trên database test trước production/local shared DB.

Không seed trực tiếp bằng `INSERT`, không dùng tài khoản admin để bỏ qua role/function/trigger.

### Cổng A4

- Trigger knowledge review hoạt động; runtime role không thể publish hay sửa citation.
- Publish idempotent theo package/digest; digest mismatch/stale evidence bị chặn.
- Retire làm recommendation/plan liên quan stale đúng policy.

## 8. Pha A5 — E2E thật và UI

Chạy smoke trên package P2A đã publish, không dùng fixture tổng hợp:

- Hồ sơ thiếu dữ liệu → `needs_information`, 1–3 câu hỏi xác định.
- Hồ sơ baseline hợp lệ → assessment `confirmed`, recommendation `suggested`, đúng 3 bữa.
- Mỗi bữa có citation public-safe; không lộ file hash/path nội bộ.
- Dị ứng SOY/PEANUT/SESAME loại đúng món và vẫn còn phương án.
- Có ít nhất một replacement hợp lệ; replace và save thành công.
- Package retire → recommendation/meal plan cũ thành stale.
- UI phân biệt rõ “gợi ý ba bữa” và “khẩu phần đầy đủ” theo quyết định A0.

### Cổng A5

- Toàn bộ Nutrition tests và PostgreSQL workflow xanh, không skip.
- Smoke REST → gRPC → PostgreSQL pass và cleanup hoàn chỉnh.
- DB sau rollback rehearsal không còn package test/dữ liệu rác.

## 9. Pha P2B — tăng huyết áp, làm sau P2A

- Thu thập guideline hiện hành thành file/revision/hash; không dựa duy nhất vào locator web cũ.
- Duyệt giới hạn natri, prerequisites, thuốc và nhóm cần loại trừ với chuyên gia.
- Tạo package/release profile condition riêng; không mutate P2A đã publish.
- Chạy coverage cho condition × từng allergen và E2E hồ sơ tăng huyết áp.

## 10. Test matrix bắt buộc

- Authoring unit: mapping/basis/Decimal math/rounding/allergen/locator.
- Golden determinism: cùng inputs → cùng artifact hashes.
- Negative: missing code, duplicate code, changed source hash, wrong basis, factor thiếu, calculation mismatch, unresolved item, stale review.
- Contract: final artifacts chạy qua chính `CatalogReleaseValidator`.
- PostgreSQL: role separation, knowledge trigger, digest mismatch, publish/retire.
- Runtime: healthy baseline, từng allergen, missing information, replace/save/stale.

## 11. Điều kiện dừng/no-go

- Chưa chốt semantics full-day hay suggestions.
- Không có reviewer chuyên môn thực hoặc reviewer không duyệt đủ 12 món.
- Bất kỳ unresolved item, nguồn không permitted/hash mismatch hoặc phép tính không tái lập.
- Daily combination coverage chưa được đánh giá theo profile đã duyệt.
- `release-check` còn một issue, hoặc smoke chỉ pass với fixture mà không pass package final.

## 12. Thứ tự triển khai đề xuất

1. A0 và authoring interface/schema.
2. A1 implementation + unit/golden tests.
3. Sinh review packet từ 12 món hiện tại và sửa mọi lỗi kỹ thuật.
4. Chờ/tiến hành A2 clinical review; trong lúc chờ hoàn thiện negative/DB tests.
5. A3 release-check sạch.
6. A4 trên disposable DB, sau đó local Nutrition DB.
7. A5 E2E và UI copy.
8. P2B sau khi P2A ổn định.

Ước lượng kỹ thuật: 4–6 ngày làm việc cho A0–A5 không tính thời gian chờ reviewer. Production publish không có ETA hợp lệ khi chưa có reviewer chuyên môn.
