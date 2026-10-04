# Production progress

Cập nhật: 04/10/2026 (Asia/Saigon). Đã được người dùng cho phép commit local, sau đó yêu cầu merge code hiện tại vào main và đồng bộ với Git. Không deploy hoặc gọi giao dịch tiền thật.

## Quyết định đã được người dùng chốt

- D01/D02, phạm vi customer hủy booking đã thanh toán **trước khi ca bắt đầu**: tự động hoàn 100% số tiền thực thu về phương thức thanh toán gốc. Không coi credit ví nội bộ là hoàn tiền provider thành công. Chỉ hiển thị đã hoàn khi có xác nhận đáng tin cậy từ provider.
- D03: payout caregiver qua API **VNPAY**, theo lựa chọn người dùng. Chưa có hợp đồng/tài liệu API **chi hộ**, quyền sandbox và quy tắc callback/idempotency/đối soát; không dùng API refund để thay cho chi hộ và không thực hiện chuyển tiền thật.
- Chưa chốt: hủy sau khi ca bắt đầu, caregiver hủy, no-show, partial service/fee; phải tách khỏi policy pre-start, không tự suy rộng.
- Việc refund tự động vẫn cần xác nhận merchant đã được cấp quyền refund và môi trường được nhà cung cấp hỗ trợ. Adapter refund/querydr 2.1.0 đã được thêm nhưng mặc định tắt và **chưa nối vào CancelBooking**; chưa có giao dịch sandbox/provider thật trong đợt này.

## G0 — Baseline/CI

Baseline kỹ thuật local đạt; **chưa đóng toàn bộ G0/policy** (policy matrix, owner, phạm vi thiết bị, RPO/RTO còn cần chốt):

- Bỏ ignore .github/global.json; đưa workflow vào commit được người dùng cho phép. CI remote trên main/develop tại f8bed77: ba job frontend pass; backend crash trong StartProcessCommand.StdOutputHandler (closed TextWriter, exit 134), không phải migration/smoke fail.
- Pin SDK .NET 8.0.425/latestPatch, Flutter 3.44.4, Node 24.19.0 cho baseline CI. Đây là baseline hiện tại, không thay thế REL02 nâng .NET 10 trước public release.
- CI chạy backend hai vòng, không skip PostgreSQL, chạy test admin trước build và lưu TRX/summary/JUnit.
- Runner local dùng PostgreSQL/Redis tạm, không chạy Compose hoặc sử dụng Redis dev; cleanup chỉ tài nguyên do runner tạo.
- Schema gate kiểm tra promotion và các cột/function/trigger tọa độ của migration 30, replay legacy upgrade và fingerprint nội dung dirty worktree.
- Backend Release build: 0 warning/error trước adapter; hai vòng sạch liên tiếp, mỗi vòng **217/217**, 0 fail/skip. Migrations 00–30, legacy 00–25 → 26–30 và replay đạt; smoke health/readiness/catalog/anonymous boundary/login ba role đạt. Evidence: `backend/artifacts/g0-20261004/backend/summary.json` (fingerprint của baseline trước adapter).
- Customer Flutter: analyze sạch, **55 test pass**, web release build đạt. Caregiver Flutter: analyze sạch, **15 test pass**, web release build đạt. Không thay cho nghiệm thu Android/iOS/thiết bị thật.
- Admin: Node 24.19.0, `npm ci` đạt, **33/33 test**, TypeScript/Vite build đạt. JUnit: `backend/artifacts/g0-20261004/admin-tests.xml`.

### Sửa runner CI — 04/10/2026

- Chạy DLL Release trực tiếp, không để launcher `dotnet run` sinh API con bị bỏ lại. Dùng .NET Process/ArgumentList, hai task copy stdout/stderr; kill tree, chờ exit và drain log có timeout trước dispose. Không dùng callback redirect của PowerShell Start-Process.
- Startup fail tự dọn process. Regression native kiểm tra quoting/exit code, dừng lúc ghi stdout/stderr, cleanup lặp và lỗi startup/log pump. CI chạy regression này trước baseline; lưu log cùng TRX/summary để chẩn đoán.
- Tách TRX từng test project, kiểm đủ báo cáo và chặn sử dụng lại kết quả cũ. Fingerprint bổ sung vercel.json.
- Baseline local đầu sau sửa lifecycle: hai vòng **294/294**, 0 fail/skip, 6 TRX/vòng, schema 00–31, legacy upgrade/replay và smoke pass; runner đã ghi summary và exit 0. Evidence: `backend/artifacts/runner-fix-20261004/summary.json`. Sau bảo vệ TRX/log-failure, chạy lại một vòng **294/294**, 6 báo cáo riêng, summary/cleanup/exit 0: `backend/artifacts/runner-fix-trx-20261004/summary.json`; native process regression pass. Chỉ cập nhật dòng tiến độ này sau lượt test đó, không sửa runtime trước commit.
- Người dùng cho phép commit/push develop để chạy CI, chỉ merge main khi CI xanh. Chưa coi baseline remote đã đạt trước khi đọc kết quả run của commit mới.
- Hướng dẫn chuẩn bị tài liệu/provider: [VNPAY_READING_GUIDE.md](VNPAY_READING_GUIDE.md). Đợt này không bật refund, không nối CancelBooking, không tích hợp API chi hộ thiếu hợp đồng và không gọi giao dịch thật.

## Nhánh Git local

- Theo yêu cầu người dùng, đã tạo `develop` từ HEAD `2f52792` của nhánh feature hiện tại và chuyển checkout sang `develop`, kiểm tra status trước/sau giống nhau. Nhánh feature cũ vẫn giữ nguyên.
- Sau khi tạo nhánh, người dùng yêu cầu **merge code hiện tại vào main và đồng bộ với Git**, đồng thời tắt auto-deploy Vercel. Fetch cho thấy `origin/main` là `123b238`; merge phải giữ lịch sử remote này, không force-push và không merge hàng loạt các nhánh lịch sử cũ.
- Người dùng đã cho phép **commit local vào develop**. Commit chỉ chọn code BE/CI/test/migration/tài liệu và Vercel config của đợt này; không gom ảnh hoặc `.kombai` frontend ngoài phạm vi.
- Merge lần này là đồng bộ source theo yêu cầu, **không phải chứng nhận release**: FIN01/FIN02/SEC01 và các gate tiếp theo vẫn chưa hoàn thành. Từ các lượt phát triển sau, làm việc trên develop và chỉ đưa release đã nghiệm thu sang main khi được duyệt.
- CI chạy push/PR cho cả main/develop, chỉ kiểm tra, không có job deploy. Branch protection và pipeline deploy remote chưa được cấu hình; nhánh local không tự tạo các kiểm soát đó.

## Vercel — Auto-deploy đã dừng trước khi đồng bộ Git

- Xác minh đúng project `thuanvans-projects/landing-page`, repo `ThwnThwn/CareSitter`, Root Directory để trống.
- Đã Remove Git Connection trên Vercel theo yêu cầu tắt auto-deploy, và đọc lại trạng thái: **This Project is not connected to a Git repository**. Project/settings và các deployment hiện có được giữ lại; không xóa website, không redeploy.
- `vercel.json` ở repo root đặt `git.deploymentEnabled: false` cho **mọi nhánh**, thay cho rule chỉ chặn nhánh feature. Đây là lớp bảo vệ thêm nếu reconnect Git sau này. Muốn mở auto-deploy phải chủ động reconnect và xét lại cấu hình này; deploy thủ công/CLI là cơ chế khác.
- [Project Git settings](https://vercel.com/thuanvans-projects/landing-page/settings/git), [hợp đồng cấu hình Vercel](https://vercel.com/docs/project-configuration/git-configuration).

## FIN01 — Nền tích hợp refund (đang thực hiện, chưa đạt gate)

- Thêm adapter VNPAY full refund và querydr theo [tài liệu chính thức](https://sandbox.vnpayment.vn/apis/docs/truy-van-hoan-tien/querydr%26refund.html). Amount lấy từ PaymentIntent thực thu VND, không lấy escrow gồm trợ giá. Request ID/date/reference/IP là snapshot bất biến; không tự sinh ID/date mới mỗi lần gọi.
- Kiểm tra chữ ký HMAC SHA512 constant-time và binding command/merchant/order/amount/full-refund type. Query trả thành công cho payment gốc không thể trở thành refund thành công. `00` thiếu trạng thái hoặc thiếu bằng chứng refund vẫn không được coi là đã hoàn.
- Timeout/disconnect/HTTP lỗi/malformed response/hash sai/mismatch → `Unknown`, không retry POST tự động; processing/đã gửi ngân hàng không bị gán thất bại. Default disabled, endpoint HTTPS phải cấu hình riêng, không redirect.
- Lưu cố định `provider_create_date` cho PaymentIntent VNPAY mới trước Save/return URL; payment URL/query/refund dùng đúng ngày này. Migration 31 additive, không đoán/backfill ngày giao dịch cũ từ `created_at`/`vnp_PayDate`; giao dịch cũ thiếu ngày trả trạng thái unknown để đối soát. **Phải chạy migration 30/31 trước bản app mới**, chưa chạy trên DB dev/production. Ví dụ local: `./backend/scripts/update-db.ps1 -From 30 -SkipStart` (kiểm tra đúng container/môi trường trước khi chạy).
- Payments unit suite mới: **97/97 pass**, gồm 70 case adapter HTTP giả lập và 3 case ngày gốc mới. Full backend + migration 31/reload đã qua **hai vòng, mỗi vòng 292/292**, 0 fail/skip, Release build 0 warning/error, smoke và legacy replay đạt. Evidence: `backend/artifacts/g0-20261004/after-refund/summary.json`. Sau baseline chỉ sửa CI branch trigger, Vercel config, thêm test config và cập nhật tài liệu; chạy gate sau merge riêng. Đây **không phải evidence tích hợp sandbox**.
- Còn phải hoàn thiện: refund request/inbox-outbox bền vững trong transaction hủy, unique business key + worker lease/recovery sau crash, chặn cạnh tranh refund ví/dispute/settlement, ledger chỉ sau xác nhận, trạng thái app/admin, race/failure-injection và sandbox acceptance. Chưa mở rộng policy sang sát giờ/no-show/sau giờ bắt đầu.
- Không bật `Payments:VNPayRefund:Enabled` trong pilot/production chỉ vì adapter pass; worker chưa triển khai và CancelBooking hiện vẫn chưa tự hoàn về phương thức gốc.

## FIN02 — Nhà cung cấp đã chọn, hợp đồng tích hợp còn thiếu

Người dùng xác nhận **chưa có tài liệu chi hộ/sandbox**. Cần lấy từ VNPAY và xác minh create/query/callback/signature, external reference, retry/idempotency, xử lý unknown và final settlement. Không tự dựng endpoint chi hộ từ API thanh toán/refund. Bug approve ghi PAYOUT trước xác nhận chuyển tiền chưa được đánh dấu đã sửa.

## Thứ tự tiếp theo

G0/policy → FIN01 + FIN02 + SEC01 → FIN03/FIN04 + SAFE01 → E2E thiết bị/tích hợp → restore/rollback/security RC → pilot → go/no-go công khai.

Không đánh dấu gate hoàn thành chỉ vì unit test pass hoặc vì có adapter stub. Các nghiệm thu sandbox/device/public/restore/pentest cần evidence riêng.
