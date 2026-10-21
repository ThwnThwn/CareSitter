# Session Progress — CareSitter

> Cập nhật bổ sung: 20/10/2026 (Asia/Saigon).

## Nutrition knowledge corpus — 20/10/2026

- Đã bổ sung chunker HTML fail-closed bên cạnh chunker PDF; bỏ `script`, `nav`,
  `header`, `footer`, giữ locator theo trang PDF hoặc dải block HTML.
- Đã chunk toàn bộ 3 artifact hiện có trong `book/`: một PDF đầy đủ và hai trang
  HTML mẫu/metadata. Corpus local có 615 chunk với 615 ID duy nhất; 549 chunk đủ
  điều kiện retrieval, 66 chunk cần duyệt tay.
- `Dinh dưỡng lâm sàng` tạo 610 chunk (545 retrieval, 65 manual review); output
  PDF chạy lại cho cùng SHA-256 nên idempotent.
- `Chế độ ăn trường thọ` product page tạo 4 chunk retrieval. `Ăn gì không chết`
  official sample chỉ có 20 token title/metadata nên tạo 1 chunk manual review và
  không được tự đưa vào index trả lời.
- Artifact corpus nằm dưới `backend/artifacts/nutrition-knowledge-local/corpus/`,
  bị ignore và không ghi PostgreSQL/catalog. Python manual pipeline: 34 pass.

## Nutrition catalog authoring — 20/10/2026

### Đã có code local, chưa commit/push

- Module `nutrition_knowledge_manual.catalog_authoring` sinh candidate bundle,
  evidence, review packet, coverage và manifest deterministic từ profile + draft
  + food snapshot. Module không nhận connection string và không ghi PostgreSQL.
- CLI có `prepare-catalog-candidate`, `finalize-catalog-candidate`,
  `init-catalog-review`, `review-catalog-recipe` và
  `review-catalog-release`.
- Review ledger khóa theo candidate manifest hash; data review và clinical review
  tách riêng; resolution gắn reviewer/role; sửa candidate/profile/ledger làm review
  stale hoặc tampered.
- Profile thật `adult-baseline-p2a-v1` đã bật authoring với semantics
  `meal_suggestions`, nhưng vẫn giữ `release_enabled=false`. Pipeline chiếu draft
  schema v1 sang candidate schema v2, bỏ rule tăng huyết áp khỏi baseline thay vì
  thêm rule giả.
- Đã sinh local candidate 12 món (4 sáng, 4 trưa, 4 tối), 64 tổ hợp baseline,
  bundle/evidence/review packet/manifest và review ledger. Artifact nằm dưới
  `backend/artifacts/nutrition-knowledge-local/catalog-authoring/` và không vào Git.
- Dị nguyên được ánh xạ đóng cho 13 mã nguyên liệu; candidate có 3 phạm vi lọc
  PEANUT/SESAME/SOY. Mọi món vẫn mang unresolved item về khẩu phần, cách chế biến
  và factor nên chưa thể release.
- Evidence nguyên liệu hỗ trợ `sourceReferenceCode` để giữ mã NIN cùng locator.

### Kiểm chứng

- Python manual knowledge/catalog: **33 pass, 0 fail**.
- Nutrition .NET + PostgreSQL thật: **124 pass, 0 fail, 0 skip** ở lần kiểm tra
  sau khi thêm hạ tầng authoring.
- CatalogTool `validate`: bundle candidate hợp lệ, 0 issue.
- CatalogTool `release-check`: phép tính nutrient đã khớp validator .NET; chỉ còn
  các cổng dự kiến (`technical_draft`, unresolved, clinical review và knowledge
  review). Không import/publish và không ghi PostgreSQL.

### Việc tiếp theo để phát hành bữa ăn

- Data steward đối chiếu 12 recipe card với snapshot và nguồn.
- Reviewer dinh dưỡng/bác sĩ duyệt khẩu phần, cách chế biến, factor và phạm vi
  người dùng; ghi resolution vào ledger, không dùng reviewer giả.
- Sau khi review đạt mới bật `release_enabled`, finalize, knowledge review rồi đi
  qua CatalogTool release-check/import/review/publish.

> Cập nhật: 18/10/2026 (Asia/Saigon).
> **Đọc file này ngay khi bắt đầu session mới.** Cập nhật lại cuối mỗi session làm việc.

---

## Triển khai blocker review 17/10 — 18/10/2026

### Đã có code

- Booking Chat xóa cache/cursor/draft khi mất quyền, mọi lỗi refresh, đổi
  conversation/epoch/scope; pagination Flutter dùng đúng `previousCursor` và bỏ
  response `loadMore` cũ nếu quyền hoặc phiên đã thay đổi.
- Hai app dùng chung `CareSignalRService`; feature chỉ join/leave booking group
  mình sở hữu, xử lý cả join hoàn tất muộn và không dừng hub chung. Port,
  repository và model mới đã tách mỗi public type một file.
- Report worker có claim token/fencing; push mặc định tắt và fallback dedup theo
  `EventId`; deep link Customer/Caregiver đã được allowlist và chuẩn hóa.
- Contract report dùng message ID trên route, có GET trạng thái; Admin mutation
  dùng PUT. Admin backend/web có cursor pagination, filter reported/blocked/
  dead-letter/booking/user/time, reason hoặc ticket context khi đọc body, report
  context và form mutation giữ draft khi lỗi/conflict.
- Retention có policy, dry-run service, worker mặc định tắt và purge loại trừ
  dispute/legal/timed hold cùng report/outbox chưa giải quyết.
- Nutrition cho phép assessment khi hồ sơ thiếu, lưu PATCH từng phần, kiểm đủ bảy
  prerequisite, phát hiện khai báo mâu thuẫn và giới hạn tối đa ba câu hỏi. Quyết
  định readiness nằm ở domain/controller thay vì widget.
- Bootstrap DB đã import migration 41/44/45 đúng thứ tự. Màn Booking Chat được
  tách actions/widgets để qua guard 300 dòng/80 dòng build.

### Kết quả kiểm chứng local

| Suite | Kết quả |
| --- | --- |
| Backend Architecture | 31 pass, 0 fail, 0 skip |
| Booking unit (full project) | 94 pass, 0 fail, 0 skip |
| Backend unit còn lại trong lần full solution | Booking 94, Payments 147, People 14, Promotion 25, Identity 15, Support 7, Catalog 5, Routing 4; 0 fail |
| Backend Integration | 246 pass, 0 fail, **133 skip** do thiếu PostgreSQL test connection |
| Messaging | **22 pass**, 0 fail, 0 skip sau khi Docker phục hồi |
| Customer Flutter | analyze sạch; full test **302 pass**, 0 fail |
| Caregiver Flutter | analyze sạch; full test **110 pass**, 0 fail |
| Admin web | **75 pass**, 0 fail; production build thành công |
| Diff | `git diff --check` không có lỗi whitespace; chỉ có cảnh báo LF/CRLF |

### Gate còn mở trước bàn giao

- Booking Chat PostgreSQL chạy trên database disposable: test fencing đơn 1/1 và
  toàn bộ nhóm Booking Chat **46/46, 0 skip trong cả 3 vòng race**. Lỗi 45 pass/1 fail
  ban đầu là fixture fake trả `support_ticket_id` chưa tồn tại nên vi phạm FK; fixture
  đã được sửa để persist ticket trước khi trả ID.
- Chạy migration clean/upgrade/replay, retention dry-run và restore rehearsal trên
  môi trường tạm; không bật `PushEnabled` hoặc `PurgeEnabled` công khai.
- E2E staging/thiết bị thật cho FCM/APNs, app kill/reconnect, đổi caregiver và
  Admin UAT vẫn chưa thực hiện. Không coi code/unit test local là nghiệm thu pilot.
- Working tree đã bẩn từ trước, gồm nhiều xóa Markdown và thay đổi Landing/iOS
  ngoài phạm vi; chưa stage/commit/push và không được gom các file đó vào commit.

---

## Rà soát và kế hoạch bàn giao — 18/10/2026

- Đã rà working tree từ 15:00 ngày 17/10 so với `082b157`; không sửa source.
- Booking Chat còn blocker: cache sau mất quyền/đổi phiên, Flutter dùng sai chiều
  cursor, SignalR chưa dùng kết nối chung, report worker thiếu fencing, push mặc
  định bật/fallback chưa dedup, Admin/API/test chưa đủ contract và acceptance.
- Nutrition còn blocker: UI chặn assessment, không lưu sparse khi hồ sơ còn thiếu,
  readiness chỉ kiểm 2/7 prerequisite, chưa phát hiện conflict và chưa giới hạn ba
  câu hỏi.
- Kiểm tra gần nhất: Backend Booking unit 17 pass; PostgreSQL Booking 25 skip do
  thiếu `CARESITTER_TEST_ADMIN_CONNECTION`; Customer targeted 24 pass; Caregiver
  targeted 7 pass; Admin 72 pass + build; Flutter analyze còn 13/15 issue.
- Đã thêm [kế hoạch hoàn thiện và bàn giao](KE_HOACH_HOAN_THIEN_VA_BAN_GIAO_2026-10-18.md),
  chia H0 bàn giao kỹ thuật, H1 pilot và H2 public; ưu tiên Gate 0/1 trước khi tiếp
  tục FIN/SEC/E2E. Tài liệu chỉ lưu local, không stage/commit/push.

---

## Trạng thái nhánh Git

- Nhánh: `develop`
- Commit HEAD: `082b157` — `feat(caregiver-app): add booking party chat Flutter feature (BCHAT-07)`
- Remote: `origin/develop` — đã push.

---

## Việc vừa hoàn thành (session 17/10/2026)

### ✅ Booking Party Chat (BCHAT) — đã commit, chưa verify CI
| Commit | Nội dung |
|--------|---------|
| `27466b6` | Backend BCHAT-01..06, 08: migration, domain, commands, SignalR hub, idempotency |
| `2663672` | Customer-app BCHAT-Flutter: màn chat, widget, provider, repository |
| `082b157` | Caregiver-app BCHAT-07: màn chat, quick message, provider, repository |

**Backlog còn lại cho BCHAT (chưa làm):**
- [ ] CI backend + Flutter 2 app chạy xanh với bộ test BCHAT
- [ ] Nghiệm thu Admin panel xem/block chat
- [ ] E2E thiết bị thật: gửi tin, mất mạng, caregiver cũ/mới, deep link
- [ ] Notification push khi có tin mới (APNs/FCM chưa test)

### ✅ iOS TestFlight workflow — chưa commit
File: `.github/workflows/ios-testflight.yml` (**untracked**, chưa commit)
- workflow_dispatch: chọn app, environment, api_base_url, hub_base_url, distribution
- Build IPA, ký manual với certificate/profile từ secrets
- Upload TestFlight tùy chọn qua altool
- Dọn keychain/profile/key sau mỗi run

**Việc còn lại:**
- [ ] Commit file workflow (khi được yêu cầu)
- [ ] Bổ sung secrets vào GitHub (IOS_TEAM_ID, IOS_DISTRIBUTION_CERTIFICATE_BASE64, v.v.)
- [ ] Chạy thử `build-only` trước khi dùng `testflight`

### ⏳ Landing page — thay đổi chưa commit
Files modified (so với HEAD):
- `frontend/landing-page/AGENTS.md`
- `frontend/landing-page/src/app/layout.tsx` — thêm font `IBM_Plex_Mono`, cập nhật metadata/OpenGraph
- `frontend/landing-page/src/styles/foundation.css` — token màu, font vars
- `frontend/landing-page/src/styles/header.css`
- `frontend/landing-page/src/styles/responsive.css`

**Chưa rõ:** landing-page đang sửa gì cụ thể — cần người dùng xác nhận trước khi commit.

---

## Thứ tự ưu tiên tiếp theo (theo PRODUCTION_PROGRESS.md)

```
G0/policy → FIN01 + FIN02 + SEC01 → FIN03/FIN04 + SAFE01 → E2E thiết bị → RC → pilot → go/no-go
```

### P0 — Gate còn mở (theo ROADMAP ngày 10: 17/10)
- **FIN01**: Refund request bền vững → worker/outbox → ledger sau xác nhận → sandbox VNPAY
- **FIN02**: Payout activation → credential VNPAY chi hộ → giao dịch giá trị nhỏ thật
- **SEC01**: KYC media private → Cloudinary sandbox → inventory/migration legacy URLs
- **BCHAT**: CI xanh → Admin panel → thiết bị thật

### P1 — iOS build
- Bổ sung secrets GitHub cho `ios-testflight.yml`
- Commit workflow → trigger `build-only` → kiểm IPA

---

## Cấu hình môi trường hiện tại

| Hạng mục | Trạng thái |
|---------|----------|
| .NET SDK | 8.0.425/latestPatch (pin global.json) |
| Flutter | 3.44.4 |
| Node | 24.19.0 |
| PostgreSQL | Docker local, migration 42 đã áp dụng |
| payOS | Acceptance thật 2.000 VND ✅ |
| VNPAY refund | Adapter có, worker chưa nối, mặc định tắt |
| VNPAY payout | Credential chưa có, mặc định tắt |
| Nutrition | P4 smoke thật qua ApiHost ✅, thiết bị chưa test |
| Vercel | Git connection đã ngắt, deploymentEnabled: false |

---

## Tài liệu tham chiếu nhanh

| Tài liệu | Đường dẫn |
|---------|---------|
| Quy ước code | `plan/QUY_UOC_CODE_VA_SECRET.md` |
| Tiến độ production | `plan/backend/PRODUCTION_PROGRESS.md` |
| Roadmap 14 ngày | `plan/backend/ROADMAP_PRODUCTION_14_NGAY.md` |
| Booking chat plan | `plan/backend/BOOKING_PARTY_CHAT_IMPLEMENTATION_PLAN.md` |
| Nutrition iPhone test | `plan/frontend/customer-app/NUTRITION_IPHONE_DEVICE_TEST_PLAN.md` |
| iOS workflow | `.github/workflows/ios-testflight.yml` |
| Rule frontend | `plan/frontend/RULE_FRONTEND.md` |

---

## Cập nhật Nutrition knowledge seed — 20/10/2026

- Đã bind artifact + SHA-256 và chunk hai nguồn mở CC BY-NC-SA 3.0 IGO:
  `WHO/FAO What are healthy diets? (2024)` và
  `WHO Europe Healthy ageing diets (2023)`.
- Đã bind/chunk trang chính thức tiếng Anh của Viện Dinh dưỡng cho
  `Mười lời khuyên dinh dưỡng hợp lý đến năm 2030` theo QĐ 3594/QĐ-BYT.
- Đã sửa HTML extractor để ưu tiên vùng nội dung bài, loại menu và related news;
  bổ sung regression test. Manual pipeline hiện 35/35 test pass.
- WHO `Keep fit for life` (2002) và ESPEN geriatrics (2022) đã bind đúng artifact
  nhưng giữ `unverified`/metadata-only vì PDF ghi `All rights reserved`; test xác nhận
  fail-closed, không sinh chunk.
- RDA Việt Nam, 07 tháp dinh dưỡng 2025, Hướng dẫn điều trị dinh dưỡng 2015 và
  trang FAO Việt Nam được đăng ký metadata-only, chờ exact official artifact/quyền
  hoặc bị đánh dấu cũ hơn QĐ 3594/2024.
- Corpus local hiện có 6 nguồn, 709 chunks: 636 eligible, 73 manual review,
  0 duplicate chunk ID, max 700 tokens; rerun không đổi hash.

## Cập nhật Nutrition local demo catalog — 21/10/2026

- Bundle `adult-baseline-p2a-v1.candidate.bundle.json` đã có trong đúng database
  `nutrition` trên PostgreSQL dùng chung của AppHost dưới package
  `adult-baseline-p2a-v1-local-demo`, revision 2.
- Catalog có 24 món `[DEMO]`: 8 breakfast, 8 lunch và 8 dinner; không có rule bệnh
  lý và không được phép publish production.
- Runtime role `nutrition_app` đọc được package; `NutritionCatalog__LocalDemoEnabled`
  và `NutritionCatalog__LocalDemoPackageKey` đang trỏ đúng package local demo.
- Docker/PostgreSQL và AppHost đã được khởi động; Nutrition readiness trả HTTP 200.
- Integration test `Local_demo_catalog_is_visible_only_when_explicitly_enabled` pass,
  bao phủ luồng đọc catalog demo, assess, confirm và recommend 3 bữa.
- 709 knowledge chunks vẫn là corpus/evidence local, không được nhập trực tiếp thành
  món ăn. Thực đơn chỉ đọc 24 recipe có cấu trúc từ bundle candidate. G0 vẫn no-go
  cho auto-admit entity/relation từ LLM, nên candidate GraphRAG không được giả làm
  công thức hoặc nguồn đã đối chiếu trong app.
