# Kế hoạch hoàn thiện và bàn giao CareSitter

> Cập nhật: 18/10/2026, Asia/Saigon.  
> Phạm vi: backend, Customer app, Caregiver app, Admin web, Landing page,
> dữ liệu/migration, CI, vận hành và hồ sơ bàn giao.  
> Trạng thái: kế hoạch đề xuất dựa trên source/working tree hiện tại; chưa phải
> xác nhận production-ready. Tài liệu lưu local, không commit/push khi chưa có
> yêu cầu riêng.

## 1. Mục tiêu bàn giao và giới hạn

Kế hoạch chia kết quả thành ba mức độc lập:

| Mức | Kết quả cần đạt | Không được suy diễn |
| --- | --- | --- |
| **H0 — Bàn giao kỹ thuật** | Source có mốc Git rõ, build/test tái lập, migration và cấu hình mẫu đầy đủ, không còn lỗi P0/P1 trong phạm vi bàn giao, tài liệu chạy/kiểm thử/known issues đủ cho người nhận tiếp tục | Không đồng nghĩa provider, store hoặc production đã nghiệm thu |
| **H1 — Pilot nội bộ** | H0 đạt; staging HTTPS, PostgreSQL thật, thiết bị thật và provider sandbox/acceptance đã chạy; backup/restore, rollback, alert và runbook được diễn tập | Không đồng nghĩa đủ điều kiện mở công khai |
| **H2 — Mở công khai** | H1 đạt; policy/pháp lý/store/credential production, capacity, support và go/no-go được owner ký duyệt | Store approve không tự chứng minh backend, tiền hoặc dữ liệu an toàn |

Mục tiêu khả thi trước mắt là **đóng H0 đầy đủ**, đồng thời chuẩn bị H1. H2 phụ
thuộc tài khoản Apple/Google, quyền merchant, môi trường production, pháp lý và
người vận hành; không đặt ngày hoàn tất khi các dependency này chưa có owner và
ngày cam kết.

## 2. Baseline ngày 18/10/2026

- Nhánh hiện tại: `develop`; mốc so sánh: `082b157`.
- Working tree có nhiều thay đổi chưa commit từ 17/10, gồm Booking Chat
  notification/deep link, report → Support ticket, Admin Booking Chat,
  pagination/race tests, Flutter test seams và Nutrition personalization gate.
- Không stage/commit/push Markdown. Không gom landing page, workflow iOS, ảnh local
  hoặc thay đổi ngoài phạm vi vào cùng commit source.
- Kiểm tra review gần nhất:
  - backend compile; Booking unit `17 pass`;
  - Booking PostgreSQL integration `25 skip` vì thiếu
    `CARESITTER_TEST_ADMIN_CONNECTION`, nên chưa phải bằng chứng đạt;
  - Customer targeted `24 pass`, Caregiver targeted `7 pass`;
  - Admin `72 pass` và production build đạt;
  - `flutter analyze` chưa sạch: Customer `13 issues`, Caregiver `15 issues`.

Các nhóm đã có code nhưng **chưa được đánh dấu hoàn thành**:

1. Booking Chat push/preference/deep link.
2. Report bền vững, ticket Support, legal hold và Admin cơ bản.
3. Seam/test controller Booking Chat cho hai app.
4. Pagination/race fixture PostgreSQL.
5. Cổng UI Nutrition yêu cầu xác nhận dữ liệu sức khỏe.

## 3. Gate 0 — Cố định phạm vi và bảo toàn working tree

### 3.1 Việc phải làm

1. Chụp inventory toàn bộ file modified/untracked và chia thành commit độc lập:
   Booking Chat backend, Booking Chat hai app, Admin, Nutrition, CI/iOS và landing.
2. Đối chiếu từng nhóm với plan/spec; file không rõ nguồn gốc không được đưa vào
   commit chỉ để làm sạch status.
3. Chạy secret scan theo tên file/từ khóa và kiểm tra staged diff trước mỗi commit.
4. Chốt phạm vi bàn giao bắt buộc:
   - luồng đăng nhập/hồ sơ/booking/nhận ca/thực hiện ca/thanh toán;
   - Booking Chat và Support Chat;
   - Nutrition ở mức nào: demo kỹ thuật, pilot có catalog đã duyệt, hay public;
   - refund/payout/provider nào được bật;
   - Android, iOS, web/admin và landing có nằm trong cùng release hay không.
5. Ghi rõ các tính năng bị tắt bằng feature flag; tính năng chưa nghiệm thu không
   được hiện như đã hoạt động thật.

### 3.2 Điều kiện qua gate

- Có bảng phạm vi `in/out/deferred`, owner và dependency cho từng feature.
- Mọi thay đổi source thuộc một task/commit rõ; Markdown vẫn local theo rule.
- `git status --short`, staged list và SHA bàn giao được lưu trong evidence.

## 4. Gate 1 — Sửa các blocker từ review 17/10

### 4.1 Booking Chat — P0/P1

| Việc | Sửa bắt buộc | Nghiệm thu |
| --- | --- | --- |
| Cache và phiên | Khi `canRead=false`, 401/403/404, đổi user/session hoặc epoch thì xóa message/cursor/draft; provider phải scope theo session generation + booking | Test đổi tài khoản, caregiver cũ, revoke giữa refresh; không còn body cũ trên UI |
| Pagination Flutter | Lưu riêng forward cursor và backward cursor; `loadMore` dùng `previousCursor`, refresh/delta không ghi đè cursor lịch sử | Test thật với contract backend: 250/251 tin, tin mới đến khi đang tải cũ, epoch gap và cursor direction |
| SignalR lifecycle | Dùng service/kết nối `/hubs/care-tracking` dùng chung; màn hình chỉ join/leave group hoặc subscription của nó, không `stop()` kết nối chung | Test nhiều feature cùng dùng hub, background/resume, reconnect và đổi tài khoản |
| Report worker | Claim có fencing token; `LINKED`/`FAILED` chỉ update khi token + trạng thái còn đúng; stale worker update 0 row | PostgreSQL race: hai worker, lease hết hạn, worker cũ quay lại, Support timeout/crash |
| Push | `BookingChat:PushEnabled=false` mặc định; fallback cũng dedup theo `EventId`; retry không tạo inbox/push logic mới | Integration test commit → outbox → notification, crash trước MarkSent, preference off, sender/system/read/caregiver cũ |
| API contract | Chốt một contract report/Admin; đồng bộ route, method, DTO, client và test; thêm GET trạng thái report | Contract test và OpenAPI/client cùng một hình dạng; giữ tương thích nếu endpoint cũ đã phát hành |
| Admin authorization/audit | Mọi đọc body có reason hoặc ticket context; list/messages/activity có pagination; legal hold chỉ release khi policy/ticket cho phép | non-admin 403, IDOR, audit đọc nội dung, version conflict, dispute/deadline không bị unblock |

### 4.2 Admin Booking Chat

- Bổ sung filter `reported`, `blocked`, `dead-letter`, booking/user/time và cursor.
- Detail phải có booking context, report/ticket, timeline và audit gần nhất.
- Block/unblock/release hold dùng form có reason + confirm; giữ draft khi lỗi hoặc
  `409`; không dùng `window.prompt` làm luồng bàn giao cuối.
- DTO chuyển về `src/types.ts`; API tiếp tục qua `src/api.ts`.
- Có Vitest cho list/detail/pagination/filter/role/conflict/draft và responsive.

### 4.3 Nutrition

1. Backend vẫn là nguồn quyết định `needs_information`, conflict,
   `needs_professional_guidance`, `awaiting_confirmation` và `eligible`.
2. Không chặn thao tác assessment chỉ vì client thấy thiếu dữ liệu; assessment phải
   cho backend trả danh sách thiếu và hành động phù hợp. Chỉ chặn generate/replace/save
   recommendation khi backend chưa cho phép.
3. PATCH phải lưu được phần người dùng vừa biết dù mục khác còn `unknown`; không bắt
   hoàn tất toàn bộ hồ sơ mới cho lưu sparse update.
4. Nếu giữ preflight client, kiểm đủ bảy nhóm: dị ứng, bệnh lý, thuốc, cách ăn,
   khả năng nuốt, hạn chế nước và điện giải; phát hiện `reported_none` mâu thuẫn
   với danh sách hiện có.
5. Mỗi lượt chỉ hiện tối đa ba câu hỏi thiết yếu; giữ dữ liệu đã rõ và chỉ mở đúng
   trường cần bổ sung.
6. Readiness/validation nằm trong controller/state/domain; widget chỉ render và gửi
   callback. Tách public type theo rule frontend.
7. Test thêm partial save, đủ bảy prerequisite, conflict, giới hạn ba câu hỏi,
   backend authority, đổi beneficiary/session và stale response.

### 4.4 Điều kiện qua Gate 1

- Không còn finding P0/P1 ở trên sau review lại.
- `flutter analyze` hai app sạch.
- Booking Chat unit/contract/PostgreSQL race **0 fail, 0 skip**.
- Customer/Caregiver targeted và full suite đạt; Admin test/build đạt.
- Không bật push/report/purge công khai từ kết quả unit test.

## 5. Gate 2 — Khép kín các luồng nghiệp vụ chặn bàn giao

| Mã | Phạm vi còn lại | Điều kiện hoàn tất H0 | Điều kiện bổ sung cho H1/H2 |
| --- | --- | --- | --- |
| FIN01 | Refund request/worker/ledger đã có code | Race/crash/replay, trạng thái Customer/Admin, runbook và feature flag đạt | VNPAY refund sandbox/merchant acceptance, đối soát chứng từ |
| FIN02 | Payout create/query đã có code, mặc định tắt | State machine, unknown/retry/ledger/recovery và test DB đạt | Credential/activation VNPAY chi hộ và giao dịch nhỏ thật |
| FIN03 | Dispute recovery | Một quyết định idempotent, crash từng bước tiếp tục được, booking không kẹt | UAT Admin + đối soát tiền trên staging |
| FIN04 | Payment mismatch/late callback | Amount/currency/reference/snapshot đúng; tiền đến muộn vào review/refund có owner | Sandbox/provider burst và callback HTTPS |
| SAFE01 | SOS vận hành | Incident/ticket bền vững, ack/escalation/audit, không auto-settle ca Crisis | Diễn tập push lỗi/người trực không ack trên thiết bị |
| SEC01 | KYC private media | Quyền server, media ID, TTL/proxy, migration inventory và cleanup test | Cloudinary sandbox, revoke URL legacy và kiểm anonymous thực |
| SEC02 | Admin tiền/dữ liệu | Quyền thao tác chi tiết, audit và thu hồi session | MFA/IdP và least-privilege vận hành thật |
| ID/STORE | Xóa tài khoản và login iOS | Endpoint/use case, policy retention, xóa token/media phù hợp, UI hoạt động | Apple/Google declarations, signing và review |

Policy phải được chốt trước khi đóng gate: hủy sau khi ca bắt đầu, caregiver hủy,
no-show, dịch vụ một phần/phí, dispute window, retention chat/KYC/GPS và người có
quyền release legal hold.

## 6. Gate 3 — CI, migration và regression tái lập

### 6.1 Backend

```powershell
dotnet test backend/CareSitter.sln --nologo
./backend/scripts/test-races.ps1 -Repeat 3
./backend/scripts/test-phase7.ps1 -Repeat 2 -SkipFrontend
```

- Dùng PostgreSQL test thật; skip là fail gate.
- Bootstrap sạch và upgrade từ schema hiện hành qua migration mới nhất.
- Kiểm checksum/schema; một migration runner tại một thời điểm.
- Failure injection cho worker tiền, notification/report, outbox/inbox và restore.

### 6.2 Frontend/Admin/Landing

```powershell
# Chạy trong từng Flutter app
flutter analyze
flutter test

# Chạy trong frontend/admin-web
npm test -- --run
npm run build
```

- Build Android release cho hai app; iOS build/TestFlight khi có Mac/signing.
- Kiểm route/deep link/login gate, text scale, màn nhỏ, loading/error/empty/offline.
- Landing: hoặc nối QuickBook với lead/quote backend thật, hoặc đổi nội dung để không
  báo đặt thành công giả. AI key chỉ ở server.
- CI remote phải chạy trên commit chứa đúng source bàn giao và lưu report/artifact.

### 6.3 Điều kiện qua Gate 3

- Full regression 0 fail/0 skip theo phạm vi đã chốt.
- CI remote xanh từ SHA bàn giao; không dùng artifact của commit cũ.
- Migration clean/upgrade/replay đạt; rollback code tương thích schema đã diễn tập.

## 7. Gate 4 — Staging, thiết bị và vận hành

1. Deploy staging HTTPS từ image/digest cố định; không build lại tùy ý trên server.
2. E2E ba vai trò Customer/Caregiver/Admin:
   đăng nhập → hồ sơ/KYC → quote/booking → thanh toán → nhận ca → chat/tracking →
   check-in/checklist/checkout → review/settlement; thêm cancel/refund, dispute, SOS,
   payout, session revoke và caregiver đổi.
3. Thiết bị thật Android và iOS: FCM/APNs, camera/KYC, GPS, deep link, app kill,
   mất mạng, reconnect, nhiều thiết bị và timezone.
4. Backup mã hóa ngoài máy chủ; restore sang DB/host mới; đo RPO/RTO và đối soát
   ledger/provider/outbox sau restore.
5. Diễn tập deploy/rollback, worker crash, dead-letter replay, provider timeout,
   hết credential và alert không được ack.
6. Load/soak có profile rõ: RPS, mix endpoint, số phiên, dữ liệu, duration và ngưỡng
   chấp nhận; theo dõi DB lock/pool, job lag, SignalR và queue.

Điều kiện qua gate: có evidence theo build/device/environment, không có lỗi sai tiền,
sai quyền hoặc lộ dữ liệu; known issue còn lại có owner, deadline và chấp thuận.

## 8. Gate 5 — Gói bàn giao H0

### 8.1 Source và release manifest

- Repository/branch/SHA/tag; danh sách commit và trạng thái working tree sạch.
- Phiên bản API, Admin, Customer, Caregiver, Landing; migration cuối và checksum.
- Image/artifact digest; Android APK/AAB và iOS IPA/TestFlight nếu thuộc phạm vi.
- Danh sách feature flag theo môi trường và trạng thái mặc định.

### 8.2 Cấu hình và secret

- Chỉ bàn giao tên biến, owner và nơi lấy secret; không ghi giá trị thật vào Git/chat.
- Ma trận dev/staging/production; domain/callback/CORS; provider, FCM/APNs, SMTP,
  storage, DB/Redis/Kafka và signing.
- Quy trình rotate/revoke, khôi phục key và thu hồi tài khoản người bàn giao.

### 8.3 Tài liệu bắt buộc

- Kiến trúc/module/data flow và contract API/OpenAPI.
- Runbook deploy, migration, rollback, backup/restore, incident và đối soát tiền.
- Hướng dẫn chạy local/test; tài khoản/fixture demo không chứa dữ liệu thật.
- Test report từ đúng SHA, danh sách known issues và tính năng đang tắt.
- Policy đã duyệt: tiền, tranh chấp, SOS, KYC/GPS/chat retention và xóa tài khoản.
- Danh sách dependency ngoài code, owner, ticket/liên hệ và trạng thái acceptance.

Vì `plan/` đang ignore và Markdown chưa được phép commit, trước ngày bàn giao phải
chốt cách chuyển bộ tài liệu local: archive riêng có checksum, kho tài liệu nội bộ,
hoặc cho phép commit một bộ tài liệu đã rà secret. Không để tài liệu duy nhất nằm trên
máy người bàn giao.

### 8.4 Phiên bàn giao

1. Người nhận dựng local từ máy sạch theo README.
2. Người nhận tự chạy migration/test và deploy staging bằng runbook.
3. Walkthrough một happy path và ba failure path: payment/refund unknown, worker
   crash/retry, mất quyền/session.
4. Thử restore/rollback hoặc xem lại evidence mới nhất.
5. Hai bên ký bảng: đã nhận, chưa nhận, external dependency và known issue.

## 9. Thứ tự thực hiện đề xuất

| Đợt | Ưu tiên | Phạm vi | Ước lượng kỹ thuật |
| --- | --- | --- | --- |
| A | P0 | Gate 0 + Booking Chat/Nutrition blocker + analyze sạch | 3–5 ngày làm việc |
| B | P0 | Integration/race/Admin tests, API contract, CI remote | 3–5 ngày |
| C | P0 | FIN03/FIN04, SAFE01, SEC01/SEC02 và policy còn mở | 5–10 ngày |
| D | P0/P1 | Staging, provider sandbox, thiết bị thật, restore/rollback/load | 5–10 ngày, phụ thuộc môi trường |
| E | Handoff | Release manifest, archive tài liệu, dry-run và ký nhận | 2–3 ngày |

Ước lượng trên là effort một người sau khi dependency sẵn sàng, không phải cam kết
ngày lịch. FIN01/FIN02 provider, Apple/Google, pháp lý và thiết bị có thể chạy song
song nhưng phải có owner ngay từ Đợt A.

## 10. Tiêu chí dừng và go/no-go

Không bàn giao H0 như “đã hoàn thành” nếu còn một trong các điều sau:

- lỗi P0/P1 chưa có quyết định phạm vi;
- Flutter analyze/test hoặc backend/admin gate đỏ;
- PostgreSQL test bị skip;
- migration/README không tái lập trên máy sạch;
- source/doc/artifact không gắn với cùng SHA;
- có secret hoặc dữ liệu thật trong source, tài liệu, log hay fixture;
- tính năng UI báo thành công nhưng backend chưa ghi nhận;
- người nhận chưa tự dựng/chạy được hoặc chưa biết known issues.

Không mở pilot/production nếu còn lỗi sai tiền, sai quyền, lộ dữ liệu, provider chưa
acceptance, backup chưa restore thử, không có người trực hoặc chưa chốt policy pháp lý.

## 11. Bằng chứng cần tạo trong quá trình thực hiện

Mỗi gate ghi: ngày/giờ, SHA, lệnh, môi trường, số pass/fail/skip, artifact/log,
người thực hiện và người duyệt. Bằng chứng đề xuất:

- `handoff/source-inventory.txt`
- `handoff/release-manifest.json`
- `handoff/test-summary.json`
- `handoff/migration-report.json`
- `handoff/device-matrix.md`
- `handoff/known-issues.md`
- `handoff/external-dependencies.md`
- `handoff/acceptance-signoff.md`

Các tên trên là cấu trúc bàn giao đề xuất; chỉ tạo khi bắt đầu thực hiện gate và phải
đặt ở nơi bàn giao đã thống nhất, không tự đưa Markdown/secret vào Git.

## 12. Tài liệu nguồn

- [Production progress](../backend/PRODUCTION_PROGRESS.md)
- [Kế hoạch production](../backend/PRODUCTION_PLAN.md)
- [Roadmap 14 ngày](../backend/ROADMAP_PRODUCTION_14_NGAY.md)
- [Kế hoạch Booking Chat còn lại](../backend/BOOKING_CHAT_REMAINING_IMPLEMENTATION_PLAN.md)
- [Kế hoạch Nutrition edge cases](../tong-quan/NUTRITION_EDGE_CASE_IMPLEMENTATION_PLAN.md)
- [Quy ước code, tài liệu và secret](../QUY_UOC_CODE_VA_SECRET.md)
- [Session progress](SESSION_PROGRESS.md)
