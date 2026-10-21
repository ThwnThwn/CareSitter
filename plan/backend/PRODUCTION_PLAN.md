# CareSitter — Kế hoạch hoàn thiện lên production

Ngày rà soát: 03/10/2026. Phạm vi: backend, hai ứng dụng Flutter, admin web, hạ tầng và vận hành dịch vụ.

Đây là kế hoạch dựa trên source và bằng chứng local hiện có, không phải chứng nhận production-ready. Trong lượt lập kế hoạch này không triển khai, không áp dụng migration vào database hiện hữu, không commit và không push. Các sửa đổi backend chưa commit từ lượt rà soát trước được giữ nguyên.

## 1. Kết luận và phạm vi phát hành

Dự án đã có nền tảng chức năng, regression backend và bộ khung deploy. Phần cần ưu tiên hiện nay là khép kín dòng tiền, an toàn dữ liệu/người sử dụng, tích hợp thật và khả năng vận hành/khôi phục. Chưa đủ bằng chứng để mở dịch vụ công khai nhận tiền thật.

Chia hai cổng phát hành, không hạ tiêu chuẩn bảo mật hoặc tiền tệ ở pilot:

- **Pilot có kiểm soát:** một khu vực, số người dùng/ca giới hạn, caregiver đã được xác minh, có người trực vận hành trong toàn bộ thời gian nhận ca. Chỉ thu tiền thật sau khi hoàn tiền, chi trả, đối soát, bảo vệ dữ liệu và ứng phó SOS đã đạt nghiệm thu.
- **Production công khai:** pilot đạt, hệ thống đã diễn tập lỗi/khôi phục, thủ tục pháp lý và phát hành ứng dụng hoàn tất, đội vận hành đủ năng lực theo tải dự kiến.

Luồng bắt buộc của bản đầu: đăng nhập → beneficiary/địa chỉ → dịch vụ/báo giá → booking/thanh toán → matching/nhận ca → di chuyển/check-in → checklist/evidence → checkout/xác nhận → quyết toán/chi trả → đánh giá. Đồng thời phải có hủy/hoàn tiền, no-show, thay đổi lịch, tranh chấp, SOS và hỗ trợ.

Tạm hoãn mở rộng tính năng không phục vụ các luồng trên: microservices, Kubernetes, gamification, chiến dịch promotion phức tạp, dashboard phân tích nâng cao. AI assistant không nằm trên critical path; nếu chưa nghiệm thu về dữ liệu, giới hạn tư vấn và fallback, tắt bằng feature flag trong bản đầu.

## 2. Giả định tiến độ và nhân sự

Chưa nhận được thông tin chốt về đội ngũ, deadline hoặc ngân sách. Các số dưới đây là ước lượng lập kế hoạch, cần xác nhận lại ở G0:

| Nội dung | Giả định |
| --- | --- |
| Nền tảng ưu tiên | Hai app Android + admin web; iOS chạy nhánh nghiệm thu song song nếu có Mac, thiết bị và tài khoản phát hành |
| Nhân sự | 1 backend, 1 frontend/mobile, QA khoảng 0,5–1 FTE, DevOps khoảng 0,25–0,5 FTE; Product/Ops có quyền chốt chính sách và tham gia UAT |
| Thời gian | Khoảng 8–10 tuần từ lúc đủ người, tài khoản tích hợp và quyết định nghiệp vụ; đã dành khoảng đệm sửa lỗi, chưa cam kết ngày go-live |
| Công sức | Khoảng 80–110 ngày công kỹ thuật/QA, cần breakdown lại sau baseline; không bao gồm thời gian chờ hợp đồng, phê duyệt pháp lý hoặc store review |
| Pilot | Đề xuất 20–50 customer, 5–10 caregiver, giới hạn ca theo khả năng trực; tối thiểu 2 tuần và đủ một chu kỳ đối soát/chi trả |
| Nếu chỉ có 1 developer | Không giữ lịch 8–10 tuần như cam kết; cần giảm nền tảng/phạm vi, thêm QA/Ops hoặc lập lại lịch theo công suất thực tế |

BE = backend; FE = frontend/mobile; QA = kiểm thử; DO = DevOps; PO = chủ sản phẩm; OPS = vận hành/CSKH/tài chính. Mỗi ticket có một owner chính, người khác hỗ trợ; quyết định tiền và an toàn dịch vụ do PO/OPS duyệt, không để developer tự đặt chính sách.

## 3. Baseline đã có và khoảng trống cần xác minh

| Hạng mục | Bằng chứng hiện tại | Phần chưa được coi là hoàn thành |
| --- | --- | --- |
| Backend | Modular monolith .NET 8; PostgreSQL/PostGIS, Redis, Hangfire, SignalR; đủ module Identity/People/Catalog/Booking/Payments/Support/Promotion | Nghiệm thu thực tế xuyên ba role, các nhánh tài chính bất thường và production operations |
| Regression backend | 6 file TRX ngày 03/10 cộng lại 214/214 pass, 0 skip, chạy PostgreSQL trên database thử nghiệm riêng | Không phải test thiết bị, payment live hoặc pentest; phải chạy lại trên release candidate sau các thay đổi mới |
| Sửa luồng chính local | Bổ sung kiểm tra KYC khi nhận ca, xử lý slot, reschedule, giá đã thanh toán, completion/review, job, replay payment và migration tọa độ | Code và migration 30 chưa commit; migration 30 chưa áp dụng vào database dev hiện hữu; cần đưa vào baseline và rehearsal nâng cấp |
| Admin web | Commit 2f52792 đã sửa session/queues/financial review, có Vitest và các test component/API | Audit admin cũ phải revalidate trên commit này; không mặc định các lỗi logout/timezone cũ vẫn còn; chưa có bằng chứng browser E2E production |
| Customer/caregiver | Có implementation và test Flutter được ghi trong roadmap cũ | Chưa có bằng chứng hiện tại cho E2E thiết bị thật; chạy lại analyze/test/build để lấy số liệu mới |
| Deploy | Có Compose, Caddy/HTTPS, healthcheck, môi trường riêng, API non-root, migration runner/checksum; DB/Redis không publish host port trong manifest production | Chưa chứng minh đã deploy staging, rollback, backup/restore, load test hoặc alert end-to-end |
| CI | Có file local .github/workflows/ci.yml | .github đang bị root .gitignore bỏ qua, chưa được Git theo dõi trong checkout; file này chưa chạy npm test của admin; chưa đủ bằng chứng CI/CD hoạt động trên remote |
| Roadmap cũ | Phase 7/8/10 ghi đạt gate local; 9/11/12 còn mở | Phải mở lại phần tài chính/bảo mật liên quan phát hiện mới; Phase 11 đã có scaffold nhưng chưa đóng gate |

Bằng chứng local: [backend review](D:/EXE/CareSitter/plan/docs/backend-main-flow-review-2026-10-03.md), [test artifacts](D:/EXE/CareSitter/backend/artifacts/main-flow-review-2026-10-03), [roadmap trước](D:/EXE/CareSitter/plan/docs/release-roadmap.md), [security operations](D:/EXE/CareSitter/plan/backend/SECURITY.md), [deploy README](D:/EXE/CareSitter/plan/deploy/README.md). Docs/artifacts hiện bị ignore; khi thực hiện cần chọn nơi lưu evidence/versioning phù hợp, không coi file local là evidence CI được lưu lâu dài.

## 4. Các quyết định phải chốt trong 2–3 ngày đầu

| ID | Quyết định | Người chốt | Đầu ra bắt buộc |
| --- | --- | --- | --- |
| D01 | Hủy trước/sau thanh toán, caregiver/customer hủy, no-show, hủy sát giờ, phần dịch vụ đã thực hiện | PO + OPS/tài chính | Bảng tình huống → phí → số tiền hoàn → bên chịu phí → deadline xử lý, có ví dụ VND cụ thể |
| D02 | Hoàn về phương thức gốc hay tín dụng nội bộ; nếu có ví customer thì sử dụng/rút/đóng tài khoản thế nào | PO + tài chính + pháp lý + nhà cung cấp | Cơ chế được hợp đồng hỗ trợ và người dùng chấp thuận; ghi rõ hoàn tiền thật khác cộng số dư nội bộ |
| D03 | Chi trả thủ công có chứng từ hay API ngân hàng/provider; ngưỡng hai người duyệt, người chịu trách nhiệm đối soát | OPS/tài chính | Quy trình duyệt → thực chi → xác nhận; cách xử lý trạng thái không rõ; không coi approve là đã chuyển tiền |
| D04 | Khi tranh chấp được hủy/đóng, booking trở lại trạng thái nào; ai được hoàn thành ca đang NeedsReview/Crisis | PO + OPS | State-transition matrix và quyền thao tác theo role, quyết định nhất quán giữa các module |
| D05 | Thời gian tự xác nhận checkout, checklist bắt buộc, thiếu bằng chứng, GPS sai số, đổi lịch khi đã tạo payment intent | PO + OPS | Policy version theo dịch vụ và bộ ví dụ boundary; snapshot vào booking khi cần |
| D06 | Khu vực phục vụ, giờ nhận ca, SLA SOS/no-show, caregiver dự phòng, quy trình người giám hộ và liên hệ khẩn cấp | PO + OPS | Lịch trực thực, cap số ca, escalation và người thay thế; không bán ca ngoài năng lực hỗ trợ |
| D07 | Android/iOS/web ra mắt đợt đầu; nhân sự, ngân sách, hạ tầng/data region, RPO/RTO | PO + tech lead + DO | Scope phát hành, tải dự kiến, budget cap, trách nhiệm tài khoản/domain/secrets và kế hoạch ngày công |

Nếu chưa chốt D01–D04, có thể tiếp tục baseline/staging/test, nhưng không hoàn thiện một chính sách tiền bằng giả định rồi mở thu tiền thật.

## 5. Backlog ưu tiên chặn phát hành

P0 ở bảng này nghĩa là **bắt buộc trước khi nhận tiền/dữ liệu thật trong pilot**, không phải khẳng định đã xảy ra sự cố. P1 là bắt buộc trước khi mở công khai hoặc trước nền tảng/tính năng tương ứng.

| ID | Mức | Công việc và căn cứ | Owner | Phụ thuộc | Tiêu chí nghiệm thu |
| --- | --- | --- | --- | --- | --- |
| FIN01 | P0 | Khép kín paid cancellation/refund: nhánh customer hủy đã thanh toán hiện chưa thấy workflow hoàn tiền đầy đủ | BE | D01–D02 | Có refund request, trạng thái và bằng chứng đối soát; retry/concurrency không hoàn hai lần; tiền không bị mất sau crash; app/admin hiển thị đúng đang xử lý/thành công/thất bại |
| FIN02 | P0 | Sửa payout: PayoutStore.ApproveAsync hiện post ledger PAYOUT và giảm pending ngay khi duyệt, chưa gắn xác nhận chuyển tiền thực | BE + OPS | D03 | Approved khác Paid; reserve → processing → paid/failed/unknown; Paid có external reference/chứng từ duy nhất; unknown không tự gửi tiền lại; reject/fail có đường phục hồi đúng |
| FIN03 | P0 | Làm dispute recoverable: resolve đang thực hiện tiền → booking → support; cancel mới hủy dispute, chưa khép kín trạng thái booking | BE | D04 | Một quyết định bất biến có idempotency, recovery/outbox; crash từng bước đều tiếp tục được; hai admin chọn ngược nhau chỉ một quyết định hợp lệ; cancel không để booking kẹt DISPUTED |
| FIN04 | P0 | Payment mismatch, callback đến sau cancel/expiry, payment intent cũ sau đổi lịch/giá | BE | D01, D05 | Đúng checksum/reference/amount/currency/status; billable snapshot không thay dưới payment link còn hiệu lực; tiền đến muộn vào review/refund có owner; không retry vô hạn hoặc tự confirm booking sai |
| SAFE01 | P0 | Đưa SOS vào vận hành: đường notification hiện thấy gửi customer/caregiver, chưa thấy inbox/escalation admin tự động | BE + OPS | D06 | SOS tạo incident/ticket bền vững, báo người trực, ack/escalation, audit đóng sự cố; replay không tạo nhiều incident; không auto-settle ca đang Crisis; diễn tập khi push lỗi và người trực không ack |
| SEC01 | P0 | Bảo vệ KYC/CCCD/evidence: upload chưa ép delivery private/authenticated trong source; CreateSignedUrlAsync còn trả rỗng | BE + FE | Chính sách dữ liệu | Lưu media ID + owner, kiểm tra quyền server, không nhận URL tùy ý làm bằng chứng; original và derivatives không đọc anonymous; link tạm hết hạn thật; migration/revoke URL cũ được diễn tập |
| SEC02 | P0 | Tài khoản admin vận hành tiền/dữ liệu: least privilege, MFA và audit không lộ dữ liệu | BE + DO + OPS | D03–D04 | Tách quyền KYC/CSKH/tài chính/cấu hình; hành động tiền không vượt quyền; quyền duyệt theo policy; MFA cho admin hoặc kiểm soát IdP tương đương; thu hồi session hoạt động |
| OPS01 | P0 | Bootstrap production sạch: migration runner cố ý bỏ seed 09 nên không có admin/catalog/pricing | BE + OPS | Baseline sạch | Provision một lần có kiểm soát, không public admin registration, không credential demo; mật khẩu/secret không vào log; catalog, giá, checklist và giờ phục vụ được PO duyệt |
| OPS02 | P0 | Backup/restore và đối soát sau restore | DO + BE + OPS | D07, FIN01–04 | Backup ngoài VM, restore sang máy/DB mới đo được RPO/RTO; pause payment mutations/jobs khi phục hồi; kiểm tra giao dịch provider trong khoảng mất dữ liệu; không phát lại chi trả/hoàn tiền đã thực hiện |
| LEG01 | P0 | Phê duyệt mô hình dịch vụ, hợp đồng thanh toán/chi trả, quyền xử lý dữ liệu beneficiary/KYC và giấy tờ caregiver | PO + pháp lý + OPS | D01–D07 | Checklist applicability được người có chuyên môn xác nhận; terms/privacy/consent/retention phù hợp mô hình thực; không chỉ copy policy mẫu |
| REL01 | P0 | CI có thể tái lập và không bỏ qua test DB/admin | BE + FE + DO | Baseline | Workflow được theo dõi trong Git khi được phép commit; CI chạy PostgreSQL tests 0 skip, Flutter analyze/test, admin Vitest/build, lưu report; không coi CI local là CI remote |
| REL02 | P1 | Nâng runtime .NET 8 lên .NET 10 LTS và package tương thích | BE + DO | Baseline | Đồng bộ TargetFramework/SDK/Docker/CI/test; EF/Npgsql/Hangfire được kiểm tra; migration/race/API contract/regression đạt; hoàn tất trước public launch và trước khi runtime hết hỗ trợ |
| QA01 | P0 | Tích hợp thật xuyên customer/caregiver/admin trên HTTPS và thiết bị | QA + FE + BE | FIN/SAFE/SEC | Đủ ma trận mục 8, có report môi trường/build/device; không chỉ dùng mock payment, widget test hoặc thao tác API rời rạc |
| REL03 | P1 | Account deletion, signing, store declarations và production build cho nền tảng phát hành | FE + BE + PO | LEG01, SEC01 | Request deletion dùng được, xử lý media/token/retention; ký release bằng khóa riêng; cấu hình không trỏ local/sandbox; Play/App Store checklist được duyệt |

Chi tiết media: Cloudinary phân biệt private với authenticated; cần kiểm tra cả bản gốc và biến thể. Chữ ký URL thông thường không tự tạo TTL; phải dùng cơ chế hết hạn được hỗ trợ hoặc proxy kiểm tra quyền/thời hạn. Thiết kế SEC01 cần xác minh bằng truy cập anonymous, URL cũ và hết hạn, không chỉ nhìn thấy URL có chữ ký. [Tài liệu Cloudinary](https://cloudinary.com/documentation/control_access_to_media).

REL02 cần đưa vào giai đoạn sớm: .NET 8 kết thúc hỗ trợ ngày 10/11/2026, .NET 10 LTS được hỗ trợ đến 14/11/2028. Không chọn .NET 9 làm bước đích vì cũng hết hỗ trợ 10/11/2026. Đây là quyết định lifecycle, vẫn phải spike package compatibility trước khi đổi. [Chính sách .NET](https://dotnet.microsoft.com/en-us/platform/support/policy).

## 6. Lộ trình thực hiện và cổng nghiệm thu

Các tuần tính từ kickoff đã đủ điều kiện, không phải deadline lịch cố định. Hạ tầng, pháp lý và chuẩn bị tài khoản làm song song; QA tham gia từ tuần đầu. Tách giai đoạn để quản lý rủi ro, không tạo sáu lần viết lại hệ thống.

| Giai đoạn | Cửa sổ dự kiến | Trọng tâm | Đầu ra/cổng thoát |
| --- | --- | --- | --- |
| G0 — Chốt baseline/scope | Tuần 1 | D01–D07, kiểm kê thay đổi local, REL01, test/build tất cả app, tài khoản tích hợp | Baseline tái lập, backlog có owner/estimate, policy matrix được ký duyệt, không mất thay đổi chưa merge |
| G1 — Nghiệp vụ an toàn | Tuần 2–4 | FIN01–04, SAFE01, SEC01–02; spike/nâng runtime | Tiền và booking recoverable/idempotent; SOS có người tiếp nhận; media nhạy cảm không public; regression/race đạt |
| G2 — Hoàn thiện luồng xuyên app | Tuần 3–5 | UI theo policy mới, tích hợp sandbox public HTTPS, thiết bị thật, LEG01 và deletion | Customer/caregiver/admin xử lý cả đường thành công và lỗi; ma trận thiết bị/tích hợp đạt |
| G3 — Hạ tầng/vận hành production | Tuần 2–6, đóng gate tuần 6 | Staging, CD, migrations/bootstrap, metrics/alerts, backup/restore/rollback, load test | Diễn tập deploy/rollback/restore và cảnh báo đạt; có runbook và người trực |
| G4 — Release candidate | Tuần 7–8 | Freeze scope, full regression, kiểm thử bảo mật độc lập, release signing/store, UAT | RC cố định có release manifest; không còn P0/P1 chặn scope; đủ chữ ký kỹ thuật/sản phẩm/vận hành |
| G5 — Pilot và mở công khai | Tuần 8–10 | Pilot tối thiểu 2 tuần, đối soát/chi trả thực, sửa lỗi, go/no-go | Bằng chứng pilot + quyết toán + support; mở dần theo năng lực, không mở ngay toàn bộ vùng/ca |

### G0 — Baseline và tổ chức thay đổi

1. Chốt scope và policy ở mục 4; ghi các trường hợp đã hỗ trợ, chưa hỗ trợ và điều kiện từ chối rõ ràng.
2. Kiểm kê diff hiện tại; giữ nguyên công việc chưa merge. Khi được giao triển khai và cho phép quản lý Git, chia thay đổi nhỏ theo dòng việc: baseline/CI, booking correctness, refund/payment, payout, dispute, media/security, deploy/observability. Không tách bằng cách bỏ mất hunk hoặc reset worktree.
3. Chạy lại clean install/build/test cho BE, hai Flutter app và admin. Lưu commit + diff snapshot/checksum + runtime/version + cấu hình test không chứa secret để xác định chính xác baseline chưa commit.
4. Nâng bài test migration gồm 00–30 sạch và nâng cấp từ schema legacy/hiện hữu phù hợp; xác minh migration 29/30, dữ liệu, tọa độ, indexes/triggers, checksum và seed production riêng.
5. Xác minh CI thật sau khi workflow được đưa vào Git với sự cho phép phù hợp; thêm admin npm test, reports, secrets/dependency scan. Pin SDK/Flutter/Node và lockfiles; không để stable tự đổi toolchain giữa hai release.
6. Chuẩn bị domain, staging HTTPS, VNPay sandbox/live onboarding, Firebase, Cloudinary access control, map/routing quotas, store accounts/signing và Mac nếu có iOS. Dùng tài khoản môi trường riêng.

Gate G0: dựng hệ thống sạch lặp lại được; test không skip; policy và owner đã rõ. Chỉ kết quả local được ghi là local, không gắn nhãn CI/public acceptance.

### G1 — Dòng tiền, trạng thái và an toàn dịch vụ

1. Thiết kế state machine/version policy cho cancel/refund/payout/dispute/payment review/SOS. Dùng ledger append-only và reversal; không sửa/xóa bản ghi lịch sử để làm số dư khớp.
2. Giữ invariant: tiền provider thu được phân bổ rõ vào escrow/refund/fee/thu nhập/trợ giá; số dư không âm; số tiền dùng đơn vị VND nguyên, kiểm tra chuyển đơn vị ở biên provider; promo subsidy có nguồn và đối soát riêng.
3. FIN01–04 dùng unique business key, transaction ở từng module và outbox/inbox hoặc cơ chế recovery có checkpoint cho bước liên module. Response retry phải phản ánh quyết định đã ghi, không chạy nghiệp vụ lần hai.
4. Bổ sung finance review queue: lỗi amount, tiền đến sau hủy, provider timeout/unknown, payout chưa xác minh, refund quá hạn. Có owner, tuổi ticket, reason, audit và thao tác retry/reconcile được phân quyền.
5. SOS có incident bền vững, người trực/backup, ack và escalation. Push/SignalR chỉ là kênh báo, không là nguồn dữ liệu duy nhất; REST/admin inbox khôi phục được trạng thái.
6. Hoàn thiện private media, admin scopes/MFA và audit trước khi dùng CCCD hoặc tiền thật. Re-encode/strip EXIF khi cần, giới hạn file và quyền xem; không ghi URL ký tạm/CCCD/tài khoản ngân hàng vào log.
7. Nâng runtime trong thay đổi riêng, chạy compatibility spike sớm để không dồn cuối RC. Tối ưu session validation sau đo tải, không đổi sang cache làm mất revoke fail-closed.

Gate G1: test deterministic, PostgreSQL race, replay và crash recovery đạt; business UAT xác nhận số tiền/state từng trường hợp; không tồn tại đường thao tác tiền ngoài audit/quyền.

### G2 — Hoàn thiện customer, caregiver và admin

1. Đồng bộ API contract/error codes/status với UI. App hiển thị phân biệt đang thanh toán, payment cần review, đang hoàn, đã hoàn, payout đã duyệt và đã trả; không thông báo thành công chỉ theo redirect.
2. Customer: đăng nhập/refresh/logout, beneficiary/địa chỉ, báo giá, thanh toán/deep link, đổi lịch/hủy, theo dõi ca, xác nhận hoặc tranh chấp, review, hỗ trợ và yêu cầu xóa tài khoản.
3. Caregiver: KYC/reject/resubmit, availability, offer hết hạn/nhận ca race, GPS/check-in, required checklist/evidence, checkout, SOS, wallet/payout với lý do thất bại và lịch sử.
4. Admin: queue KYC/payment/dispute/SOS theo ưu tiên/tuổi; server pagination/search khi dữ liệu lớn; khóa tài khoản, xử lý ticket và tiền có confirm/rationale/audit, refresh lại dữ liệu sau lỗi/conflict. Revalidate các sửa session/timezone/queues đã có thay vì làm lại theo audit cũ.
5. Mạng yếu/offline/resume: thao tác submit lặp có idempotency; app phục hồi bằng REST/resync sequence; permission denied có hướng dẫn; push trễ/deep link hết hạn không kích hoạt action sai.
6. Kiểm tra VNPay HTTPS IPN + return thực, Google sign-in signing fingerprints, push foreground/background/killed, camera/location và routing/geofence bằng thiết bị. Test địa chỉ ngoài vùng, sai số GPS và không cấp quyền.
7. QA lập UAT script theo role; mỗi lần chạy ghi build, môi trường, device, thời gian UTC, IDs đã khử nhạy cảm, kết quả và ticket lỗi. Không dùng dữ liệu định danh thật ở staging nếu chưa được phép.

VNPay IPN là callback server-to-server, cần HTTPS và xác minh dữ liệu trước cập nhật. Nghiệm thu phải bao gồm checksum, amount và trạng thái; không dùng return page làm bằng chứng duy nhất đã nhận tiền. [Tài liệu VNPay](https://sandbox.vnpayment.vn/apis/docs/thanh-toan-pay/pay.html).

### G3 — Triển khai, quan sát và khôi phục

1. Giữ modular monolith; không cần chuyển kiến trúc để phát hành. Compose hiện tại có thể dùng staging/pilot nhỏ nếu đáp ứng diễn tập; single VM vẫn là single point of failure. Với public paid traffic, ưu tiên PostgreSQL/PostGIS managed hoặc DB tách host có off-host backup; chọn cấu hình theo SLO/ngân sách được duyệt.
2. CD build image một lần từ SHA, scan và đẩy registry khi được phép; promote cùng image digest staging → production. Không build mới trên VM rồi giả định giống artifact đã test. Release manifest ghi API/admin/mobile versions, migrations, config keys, feature flags và artifact digests.
3. Migrations chỉ có một runner; dùng lock ở deployment/database, checksum và transaction từng migration nếu tương thích. Kiểm thử crash sau SQL trước checksum, re-run và legacy upgrade. Dùng expand/contract khi app cũ/mới cùng chạy; không tự bật destructive migration 19/21.
4. Provision admin/catalog/pricing/checklist qua OPS01; xác minh fresh production không có demo users/known credentials. Không đổi seed dev thành seed production để tiện login.
5. Secrets tách dev/staging/prod; secret manager hoặc file quyền hạn chặt được quản lý; khóa signing/service account không nằm trong source/image/artifacts/log. Thử rotate/revoke. DB/Redis chỉ private; Hangfire chỉ qua mạng nội bộ/VPN/allowlist và auth phù hợp; sao lưu encryption keys theo quy trình riêng.
6. Log tập trung có correlation ID và structured error; metrics API/DB/Redis/outbox/Hangfire/SignalR/provider; error tracking mobile/admin có redaction. Phân biệt health liveness/readiness, không coi lỗi push đơn lẻ là lý do restart API liên tục.
7. Backup mã hóa ngoài VM, retention được duyệt, PITR phù hợp RPO. Restore gồm roles/extensions/PostGIS/config/key recovery và kiểm tra ledger. Diễn tập khôi phục sang host mới với bằng chứng thời gian, không chỉ tạo file backup.
8. Rollback ứng dụng dùng image trước với schema backward-compatible. Không mặc định chạy down migration/xóa cột. Nếu phải restore DB, cần incident plan và đối soát giao dịch ngoài DB trước khi bật payout/refund/jobs.
9. Load/soak test trên dữ liệu và cấu hình gần production: login, search/PostGIS, booking, nhận ca cạnh tranh, IPN burst, REST resync và admin queues. Đo locks, connection pools, retry và job lag; không tự tăng replicas khi OTP counter vẫn read-modify-write không nguyên tử.
10. Runbook tối thiểu: API down, DB/Redis lỗi, payment mismatch/unknown, refund/payout pending, outbox backlog, SOS không ack, push lỗi, secret leak, restore và rollback. Mỗi runbook có dấu hiệu, owner, cách cô lập, bước kiểm tra và điều kiện mở lại.

PITR PostgreSQL cần base backup và lưu WAL liên tục; pg_dump hằng ngày không tự đáp ứng RPO 15 phút. Chọn managed PITR hoặc thiết kế backup/WAL phù hợp, rồi đo bằng rehearsal. [Tài liệu PostgreSQL 16](https://www.postgresql.org/docs/16/continuous-archiving.html).

### G4 — Pháp lý, bảo mật độc lập và release candidate

1. Kiểm kê dữ liệu: CCCD/KYC, ảnh, vị trí, sức khỏe/beneficiary, thanh toán, push identifiers và audit. Chốt cơ sở xử lý, consent theo version, quyền người giám hộ, retention, deletion, vendor/data region và trách nhiệm khi có sự cố với người có chuyên môn pháp lý.
2. Rà soát quy định hiện hành theo mô hình thực: kinh doanh dịch vụ chăm sóc, xác minh caregiver/chứng chỉ, bảo hiểm/trách nhiệm, thuế/hóa đơn, thương mại điện tử, hợp đồng tiền/chi trả. Không mặc định tên “wallet/escrow” trong code đồng nghĩa được phép vận hành dịch vụ tài chính đó.
3. Implement và nghiệm thu xóa tài khoản/dữ liệu: revoke sessions/tokens, media deletion, dữ liệu ở vendor, anonymization/retention cho chứng từ phải giữ, job retry/backup lifecycle, thông báo phạm vi và thời gian cho người dùng.
4. Android release: production signing, target SDK/permissions, push/deep link, Data safety, privacy/deletion link, nội dung store và tài khoản reviewer. iOS nếu trong scope: signing/APNs, privacy declarations/permission text, login/deletion và kiểm tra yêu cầu store hiện hành. Không release bằng debug key.
5. Đặt kiểm thử bảo mật độc lập từ sớm: ownership/IDOR, admin privilege, payment tampering/replay, OTP abuse, session revocation, upload/media exposure, dependency/secret scan và public deployment config. Sửa lỗi và retest trước nhận tiền/dữ liệu thật; scan tự động không thay thế pentest.
6. Freeze scope; build RC cố định, regression/UAT đủ role trên staging tương đương production, load + restore/rollback đạt, chốt known issues không chặn an toàn/tiền/quyền, release notes và phiên bản app tương thích.

Cổng pháp lý phải được đánh giá theo văn bản hiện hành; Nghị định 356/2025/NĐ-CP hướng dẫn Luật Bảo vệ dữ liệu cá nhân có hiệu lực từ 01/01/2026. Kế hoạch này là backlog kiểm tra, không phải kết luận tuân thủ pháp luật. [Nguồn Chính phủ](https://vanban.chinhphu.vn/?classid=1&docid=216387&pageid=27160).

Ứng dụng cho phép tạo tài khoản cần đường yêu cầu xóa phù hợp store: Google Play yêu cầu đường trong app và tài nguyên web để gửi yêu cầu; Apple yêu cầu khởi tạo xóa trong app cho app thuộc phạm vi chính sách. Xử lý retention hợp pháp rõ ràng, không chỉ deactivate. [Google Play account deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en), [Apple account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/).

Theo yêu cầu Google Play tại ngày rà soát, app Android mới và cập nhật phải target Android 16/API 36 từ 31/08/2026; kiểm tra giá trị thực trong release artifact và lại đối chiếu policy ở ngày submit. [Google Play target API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en).

### G5 — Pilot và tăng phạm vi

1. Chỉ mở pilot sau checklist mục 10; feature flags kiểm soát khu vực/dịch vụ/số ca và thao tác tiền có kill switch an toàn. Không đưa người thật vào hệ thống chưa đạt bảo vệ dữ liệu.
2. OPS onboarding caregiver, xác minh hồ sơ/tài khoản nhận tiền và diễn tập dịch vụ/SOS/no-show trước ca đầu. Chốt ca trực, số hotline, người dự phòng và giới hạn khả năng nhận ca.
3. Theo dõi ít nhất 2 tuần và đủ một chu kỳ checkout, dispute window, refund, settlement và payout. Ca pilot đề xuất khoảng 30–50 nếu đủ năng lực, nhưng số lượng không thay thế nghiệm thu các nhánh hiếm bằng simulation/UAT.
4. Mỗi ngày đối soát provider/bank/ledger/wallet, xem booking bị kẹt và ticket SLA; daily triage có PO/BE/QA/OPS. Mọi lệch tiền phải có case/owner và không đóng bằng sửa DB trực tiếp.
5. Sự cố sai tiền, sai quyền, ảnh KYC bị đọc trái phép hoặc SOS không có người xử lý: dừng mở thêm/thu tiền theo runbook, cô lập, điều tra và retest trước tiếp tục. Không đợi đủ hai tuần mới xử lý.
6. Go/no-go có PO, kỹ thuật và OPS ký. Tăng cap theo từng bước sau review số liệu; không coi một lần chạy happy path thành công là đủ mở toàn quốc/24 giờ.

## 7. Mười ngày làm việc đầu tiên

| Ngày | BE/DO | FE/QA | PO/OPS | Đầu ra |
| --- | --- | --- | --- | --- |
| 1–2 | Kiểm kê diff, clean DB/test, kiểm tra migration/CI/toolchain | Chạy analyze/test/build ba frontend, lập test matrix | Chốt D01–D07, thuê/tài khoản/thiết bị cần thiết | Baseline report + quyết định nghiệp vụ + blocker có owner |
| 3–4 | Thiết kế refund/payout/dispute recovery, spike .NET 10, dựng staging HTTPS | Map status/error mới vào UI, tạo E2E skeleton và fixture | Duyệt state/tiền ví dụ, quy trình SOS và payout | API/state contract + backlog sprint có estimate |
| 5–6 | Bắt đầu FIN01/FIN02 và SEC01; CI DB/admin gates | Test KYC/media và paid cancel; UI pending/refund/payout | Duyệt bootstrap/catalog/checklist/pricing | Vertical slice đầu có integration tests |
| 7–8 | FIN03/FIN04, SOS inbox/escalation; backup/observability skeleton | Crash/replay/race UAT, sandbox IPN, push/deep link devices | Diễn tập tài chính/SOS trên staging, đặt pentest | Evidence các nhánh khó + ticket lỗi cụ thể |
| 9–10 | Hoàn thiện lát cắt ưu tiên, chạy regression và rehearsal migration | E2E ba role + nghiệm thu policy mới, thống kê lỗi | Sprint review, xác nhận scope/công suất/schedule | Quyết định G0 đạt/chưa đạt và kế hoạch G1 cập nhật |

Đây là phân bổ khởi động, không kỳ vọng tất cả FIN/SEC hoàn thành trong 10 ngày. Owner điều chỉnh theo estimate và phụ thuộc thực; dữ liệu/test/infra phải sẵn sàng trước khi “đóng ticket”.

## 8. Ma trận nghiệm thu tối thiểu

| Nhóm | Tình huống bắt buộc | Bằng chứng |
| --- | --- | --- |
| Identity | Customer/caregiver/admin đúng role; refresh rotate/reuse; logout/revoke/lock; OTP brute force; Google account chooser | API negative tests + browser/device + audit metadata |
| KYC/media | Submit/reject/resubmit/approve; người khác không xem; URL cũ, original/derivatives, URL hết hạn; caregiver chưa duyệt không nhận ca | Test ownership + truy cập storage thật + UAT admin |
| Quote/booking | Giá/khuyến mãi snapshot; địa chỉ/vùng; timezone UTC+7; quote hết hạn; submit lặp; lịch trùng | Contract/domain/PostgreSQL tests + UI |
| Payment | Success/fail/cancel/timeout; Return trước/sau IPN; IPN mất/lặp/đồng thời/sai hash/sai tiền; tiền đến sau hủy/expiry | Sandbox public HTTPS + DB/ledger + finance queue |
| Matching/slots | Hai caregiver nhận một ca; một caregiver nhận hai ca trùng; offer hết hạn; đổi lịch race; cancel giải phóng HELD/COMMITTED | PostgreSQL concurrency tests + UI offer refresh |
| Thực hiện ca | Di chuyển/GPS sai số; thiếu location/camera permission; check-in boundary; checklist required skipped; evidence; checkout; NeedsReview | Thiết bị thật + job tests + policy UAT |
| Hoàn thành | Confirm tay và auto-job; auto không vượt review/Crisis/dispute; event/notification retry | Crash/replay tests + timeline/sync/ledger |
| Refund | Trước/sau thanh toán, một phần/toàn phần theo policy; provider fail/unknown; replay; subsidy/fee | Số tiền kỳ vọng + chứng từ/đối soát + recovery tests |
| Payout | Reserve/approve/reject/processing/paid/fail/unknown; thiếu/chứng từ trùng; hai admin; provider timeout sau thực chi | Ledger invariants + bank/provider proof + role tests |
| Dispute | Hai admin quyết định ngược nhau; kill process sau từng bước; hủy dispute; support save fail; retry | Immutable decision + recovery/outbox + audit |
| SOS/no-show | Push không tới; người trực không ack; incident trùng; backup caregiver; ca đang Crisis không settle | Diễn tập OPS với đồng hồ, ticket và escalation |
| Realtime/mobile | SignalR reconnect/out-of-order; REST resync; app killed/resume; push denied/late; stale deep link | Thiết bị thật, mạng yếu và restart app |
| Admin/support | Session revoke, queue/data refresh, timezone, pagination, quyền từng thao tác, reply/close/SLA | Vitest + browser E2E + UAT OPS |
| Migration/deploy | DB sạch/nâng cấp; bootstrap không demo; checksum/re-run/concurrent runner/crash; app cũ với schema mới | Logs đã redaction + database assertions + deploy manifest |
| Khôi phục | Mất VM/DB; restore host mới; replay outbox; giao dịch provider nằm ngoài snapshot | RPO/RTO đo thực + đối soát + không duplicate money |
| Privacy/release | Consent, deletion/session/media/vendor/retention; signed release; không endpoint dev/secret/debug | UAT + artifact inspection + checklist legal/store |

Ma trận thiết bị: ít nhất hai hãng Android, một thiết bị cấu hình thấp, phiên bản OS thấp nhất cam kết và phiên bản hiện hành; iOS gồm mức tối thiểu hỗ trợ và hiện hành nếu phát hành. Admin kiểm thử Chrome/Edge được đội OPS sử dụng. Lưu phiên bản chính xác khi kickoff; không ghi “hỗ trợ mọi thiết bị”.

## 9. Mục tiêu chất lượng và vận hành đề xuất

Các mục tiêu sau là baseline thương lượng, chưa phải SLA đã đo hoặc lời hứa cho khách hàng. G0 phải chốt tải, giờ vận hành và ngân sách; G3 phải chứng minh đạt.

| Chỉ tiêu | Mục tiêu ban đầu | Cách đo/điều kiện |
| --- | --- | --- |
| Tiền và quyền | 0 duplicate charge/refund/settlement/payout; 0 sai ownership | Assertion DB/ledger + external reconciliation; không chấp nhận “tỷ lệ lỗi nhỏ” |
| API availability | SLO đề xuất 99,9%/tháng cho public | Đo synthetic/API từ ngoài; single VM không bảo đảm HA; thay cấu hình hoặc SLO nếu không đủ ngân sách |
| Latency | p95 đọc ≤500 ms, ghi nội bộ ≤1 giây dưới tải đã chốt | Nêu endpoint/payload/data size; tách thời gian provider; không áp mục tiêu này cho toàn bộ matching workflow |
| Tải | 2 lần peak dự kiến; nếu chưa có forecast, dùng profile thăm dò 100 phiên đồng thời và burst booking/IPN phù hợp | Không đánh đồng concurrent session với requests/second; kịch bản phải nêu RPS, mix, số bản ghi, duration và chấp nhận tải lại sau pilot |
| Lỗi kỹ thuật | <1% 5xx/timeout trong profile chuẩn, không mất dữ liệu/tiền | Tách lỗi validation hợp lệ và outage provider; soak test tối thiểu 2 giờ trước RC |
| Outbox/jobs | p95 outbox lag ≤60 giây; cảnh báo khi item quá 5 phút hoặc failure/retry tăng | DLQ/manual review có owner; job restart/backlog recovery được diễn tập |
| Mobile | Crash-free sessions mục tiêu ≥99,5%; luồng chính không bị chặn ở mạng yếu | Ghi sample size; pilot ít dữ liệu không đủ chứng minh tỷ lệ dài hạn |
| Khôi phục | RPO ≤15 phút, RTO ≤2 giờ là đề xuất cho paid public | PITR/off-host backup, restore đo thực; nếu không đạt phải chọn kiến trúc khác hoặc duyệt mục tiêu khác trước launch |
| SOS/support | Đề xuất SOS ack ≤2 phút trong giờ có ca; escalation khi quá hạn | OPS phê duyệt SLA và đủ người trực/backup; không coi đây là cam kết cứu hộ y tế của ứng dụng |
| Tài chính | Đối soát hằng ngày, không còn chênh chưa giải thích khi đóng kỳ chi trả | Kết nối sổ provider/bank/ledger; mismatch mới vào review ngay, không chờ cuối ngày |

Dashboard tối thiểu: auth errors/rate limit, booking conversion/state age, IPN success/mismatch, refund/payout pending age, ledger reconciliation, DB pool/locks/space, Redis, outbox lag, Hangfire failures, SOS unacknowledged và mobile errors. Alert phải gửi đến người có thể xử lý và được thử bằng lỗi giả lập.

Chi phí cần chốt theo nhóm: compute, PostgreSQL/PostGIS + backup/PITR, Redis, storage/Cloudinary, logging/monitoring, map/routing, email/SMS/OTP, payment fees, domain, store accounts, pentest và vận hành. Lấy báo giá theo usage dự kiến, đặt budget alert và dự phòng 20–30%; không tự chọn gói cloud hoặc mua tài khoản trong bước lập plan.

## 10. Checklist go/no-go

### Trước pilot có tiền/dữ liệu thật

- [ ] D01–D07, mô hình dịch vụ và điều kiện pháp lý đã được người có trách nhiệm duyệt.
- [ ] FIN01–04, SAFE01, SEC01–02 đạt nghiệm thu; không có known issue sai tiền, sai quyền hoặc lộ dữ liệu.
- [ ] Baseline/CI đầy đủ, DB tests không skip; migration sạch/nâng cấp và bootstrap không demo đạt.
- [ ] HTTPS staging/production, callback/provider config được nghiệm thu; sandbox không bị dùng nhầm ở production.
- [ ] Đối soát với provider/bank, hoàn tiền và chi trả có evidence; policy + UI phản ánh đúng trạng thái.
- [ ] Bộ test ba role, thiết bị/tích hợp đúng scope đạt; kiểm thử bảo mật độc lập phù hợp scope đã retest lỗi chặn.
- [ ] Backup/restore/rollback, alert và runbook được diễn tập; có quyền tạm dừng giao dịch an toàn.
- [ ] Terms/privacy/consent/deletion phù hợp scope; dữ liệu KYC được bảo vệ trước onboarding.
- [ ] Người trực/backup, caregiver được xác minh, cap khu vực/ca và kênh hỗ trợ sẵn sàng.
- [ ] RC/artifact/config được ghi cố định; PO, tech lead và OPS ký cho phép pilot.

### Trước mở production công khai

- [ ] Pilot ít nhất 2 tuần và đủ chu kỳ tiền/dispute/chi trả; case bất thường có bằng chứng xử lý.
- [ ] Không còn P0/P1 chặn scope; known issues khác có owner, deadline và chấp thuận bằng văn bản.
- [ ] .NET/runtime còn được hỗ trợ; toolchain/package/image đã scan và regression đạt trên RC cuối.
- [ ] Signing/store approvals và declarations hoàn tất cho từng nền tảng thực sự phát hành.
- [ ] SLO/load/RPO/RTO được đo và đáp ứng mức đã duyệt; capacity/support đủ cho cap mở mới.
- [ ] Đối soát không có chênh lệch chưa giải thích; payout/refund quá hạn đã được xử lý.
- [ ] Go/no-go lần cuối có evidence links, rollback image, người quyết định rollback và lịch trực hậu phát hành.

Một lỗi mới về tiền, quyền, dữ liệu nhạy cảm hoặc an toàn dịch vụ có thể mở lại gate đã đóng. Không ngoại lệ hóa các lỗi đó chỉ để đạt ngày ra mắt.

## 11. Sau go-live: 30 ngày đầu

- **72 giờ đầu:** theo dõi sát booking/payment/SOS, trực theo giờ phục vụ, đối soát hằng ngày, triage ít nhất một lần/ngày; tăng cap chỉ khi đủ năng lực.
- **Tuần 1–2:** kiểm tra funnel, ca bị kẹt, refund/payout aging, lỗi thiết bị, provider quotas và support backlog; hotfix nhỏ, có regression và rollback.
- **Tuần 3–4:** diễn tập restore/rotation lại nếu cần, tổng kết incident, review SLO/cost, điều chỉnh staffing và dịch vụ; lên backlog cải tiến theo số liệu thật.
- Mở rộng vùng, promotion/AI và tối ưu lớn chỉ sau review vận hành. Không dùng production làm môi trường thử chính sách dòng tiền.

## 12. Cách quản lý tiến độ và Definition of Done

Board đề xuất: Backlog → Ready → In progress → Review → QA/UAT → Accepted; Blocked phải ghi dependency, người tháo gỡ và ngày kiểm tra lại. WIP một đầu việc chính mỗi developer để tránh nhiều luồng tiền cùng dở dang.

Mỗi ticket bắt buộc có: ID mục 5 hoặc ID con, owner, priority, policy/contract, estimate, dependency, test cases, migration/rollback impact, evidence links và người nghiệm thu. Estimate lại sau mỗi gate bằng ngày công, không chỉ tỷ lệ phần trăm tính năng.

Definition of Done:

1. Code được review và versioned khi người dùng cho phép Git workflow; không tự commit/push trong nhiệm vụ hiện tại.
2. Build/static analysis và tests liên quan đạt; có regression cho lỗi đã sửa; không skip DB/race vì thiếu cấu hình.
3. API/domain/DB/UI và nghiệp vụ tài chính dùng cùng quyết định/policy; migration đã rehearse nếu có.
4. Security/ownership/idempotency/recovery được kiểm tra theo rủi ro; evidence không chứa secret/dữ liệu thật không cần thiết.
5. UAT trên môi trường/tài khoản/thiết bị phù hợp đạt; có audit/metrics/runbook cho thao tác vận hành.
6. Người chịu trách nhiệm ký nghiệm thu; việc mới chỉ chạy local được ghi rõ local, không đóng gate production.

**Thứ tự nên bắt đầu:** G0/policy → FIN01 + FIN02 + SEC01 → FIN03/FIN04 + SAFE01 → E2E thiết bị/tích hợp → restore/rollback/security RC → pilot → go/no-go công khai. Hạ tầng, runtime upgrade, pháp lý và tài khoản store được chuẩn bị song song ngay từ đầu để không thành blocker cuối kỳ.
