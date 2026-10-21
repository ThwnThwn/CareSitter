# CareSitter release roadmap: Phase 7–12

Cập nhật: 2026-09-28.

Roadmap này thay thế cách theo dõi Phase 0–6. Các phase cũ đã hoàn thành phần triển khai chính nhưng chưa hoàn tất toàn bộ acceptance test, vì vậy những release gate còn mở được chuyển sang Phase 7–12.

## Cách xác định trạng thái

Một hạng mục chỉ được đánh dấu hoàn thành khi có đủ:

1. Code đã merge vào `main` và không còn thay đổi chưa commit.
2. Build, static analysis và automated test liên quan đều đạt.
3. Migration và smoke test đạt trên môi trường PostgreSQL/Redis sạch.
4. Tích hợp bên thứ ba được xác minh bằng sandbox hoặc thiết bị thật khi có liên quan.
5. Có bằng chứng nghiệm thu và không còn lỗi blocker/critical.

Các trạng thái được dùng trong roadmap:

- **Hoàn thành:** đạt toàn bộ tiêu chí thoát phase.
- **Đang thực hiện:** đã có đầu ra nhưng còn checklist bắt buộc.
- **Chưa bắt đầu:** chưa có bằng chứng nghiệm thu cho phase.
- **Bị chặn:** không thể tiếp tục nếu thiếu tài khoản, thiết bị hoặc quyết định bên ngoài.

## Baseline đã xác minh ngày 2026-09-21

- Điểm xuất phát là `main` tại commit `9a2da18`; baseline Phase 7–10 đã được gom vào `main` sau khi vượt các gate local.
- Backend build thành công: 161/161 test đạt, không còn test skip khi chạy với PostgreSQL thật.
- Customer app: `flutter analyze` sạch và 26 test đạt.
- Caregiver app: `flutter analyze` sạch và 15 test đạt.
- Admin web: TypeScript và production build đạt; chưa có automated test.
- PostgreSQL container đang chạy; migration bảo mật số 26 và trigger audit đã được xác minh trực tiếp trên database.
- KYC, hồ sơ, booking, matching, VNPay/escrow, thực hiện ca, wallet, admin, SignalR và Firebase đều đã có implementation.

## Tổng quan phase mới

| Phase | Mục tiêu | Trạng thái | Phụ thuộc |
| --- | --- | --- | --- |
| 7 | Tái lập baseline chạy được và có thể lặp lại | Hoàn thành (28/09/2026) | Docker, cấu hình local |
| 8 | Nghiệm thu luồng vàng và tính đúng đắn giao dịch | Hoàn thành (22/09/2026) | Phase 7 |
| 9 | Nghiệm thu tích hợp thật và thiết bị thật | Chưa bắt đầu | Phase 8, tài khoản sandbox, thiết bị |
| 10 | Bảo mật, phân quyền và kiểm soát vận hành | Hoàn thành | Thực hiện ưu tiên theo quyết định ngày 2026-09-21 |
| 11 | Triển khai, quan sát và khôi phục | Chưa bắt đầu | Phase 10 |
| 12 | Release candidate, pilot và quyết định phát hành | Chưa bắt đầu | Phase 9–11 |

## Phase 7 — Baseline có thể lặp lại

**Mục tiêu:** mọi thành viên có thể dựng hệ thống sạch và nhận cùng một kết quả kiểm tra.

- [x] Khởi động PostgreSQL và Redis bằng Docker Compose; health check đều healthy.
- [x] Chạy toàn bộ migration 00–28 trên database sạch.
- [x] Chạy migration nâng cấp từ baseline legacy 00–25 lên 26–28 và xác minh dữ liệu sau nâng cấp.
- [x] Chạy smoke test cho liveness, readiness, catalog, authentication boundary và login ba role seed.
- [x] Chạy đủ 161 backend test trên PostgreSQL thật, không skip.
- [x] Customer app analyze sạch và 26 test đạt.
- [x] Caregiver app analyze sạch và 15 test đạt.
- [x] Admin web production build đạt.
- [x] Chuẩn hoá seed data, tài khoản test theo role và hướng dẫn reset môi trường.
- [x] Lưu kết quả kiểm tra vào biên bản acceptance.

**Tiêu chí thoát:** một lệnh hoặc một checklist duy nhất dựng được môi trường sạch; migration, health, smoke và toàn bộ test đều đạt hai lần liên tiếp.

**Kết quả:** runner `backend/scripts/test-phase7.ps1` đạt hai vòng liên tiếp ngày 26/09/2026. Ngày 28/09/2026, backend build, migration, smoke test và 161/161 test tiếp tục đạt; customer app analyze sạch và 26/26 test đạt sau khi sửa responsive login; caregiver app và admin web cũng đạt lại gate tương ứng. Baseline đã được đưa vào `main`. Xem [Phase 7 acceptance](phase-7-acceptance.md).

## Phase 8 — Luồng vàng và tính đúng đắn giao dịch

**Mục tiêu:** chứng minh nghiệp vụ cốt lõi chạy xuyên suốt và không tạo trạng thái hoặc dòng tiền sai.

- [x] Customer đăng ký/đăng nhập đúng role, tạo beneficiary và địa chỉ hợp lệ.
- [x] Customer lấy báo giá, tạo booking và không thể tạo booking trùng/xung đột.
- [x] Payment callback finalize booking đúng một lần khi retry hoặc chạy đồng thời.
- [x] Matching tạo offer đúng caregiver; caregiver nhận ca và không thể giữ hai ca trùng lịch.
- [x] Caregiver di chuyển, gửi GPS và check-in đúng điều kiện thời gian/vị trí.
- [x] Checklist bắt buộc, tác vụ phát sinh và evidence tuân thủ policy dịch vụ.
- [x] Caregiver checkout; Customer hoặc Admin xác nhận kết quả đúng state transition.
- [x] Escrow giải ngân đúng một lần; wallet và ledger hai phía cân bằng.
- [x] Refund, dispute, payout và retry không làm âm hoặc ghi nhận tiền hai lần.
- [x] Customer gửi review đúng booking đã hoàn thành.
- [x] Thêm integration test PostgreSQL cho ownership và các state transition quan trọng còn thiếu.
- [x] Sửa toàn bộ lỗi blocker/critical phát hiện trong luồng vàng.

**Tiêu chí thoát:** luồng vàng đạt tối thiểu ba lần liên tiếp; test idempotency/race đạt; database không có bản ghi mồ côi và ledger cân bằng.

**Biên bản:** [Phase 8 acceptance](phase-8-acceptance.md).

## Phase 9 — Tích hợp thật và thiết bị thật

**Mục tiêu:** xác minh các hành vi không thể chứng minh chỉ bằng unit/widget test.

- [ ] VNPay Sandbox chạy đủ Return URL và IPN qua HTTPS public.
- [ ] Xác minh giao dịch thành công, thất bại, hủy, timeout, duplicate callback và reconciliation.
- [ ] Cloudinary upload/đọc/xoá avatar, KYC, selfie và evidence đúng quyền truy cập.
- [ ] Routing và geofence chạy bằng địa chỉ, GPS và sai số vị trí thật.
- [ ] SignalR reconnect, mất mạng, resume app và REST resync không làm mất trạng thái.
- [ ] Firebase push, quyền thông báo và deep link đạt trên Android thật.
- [ ] Firebase push, quyền thông báo và deep link đạt trên iOS thật.
- [ ] Kiểm tra camera, location, background/resume và mạng yếu trên thiết bị thật.
- [ ] Sửa toàn bộ lỗi blocker/critical phát hiện trong acceptance test.

**Tiêu chí thoát:** ma trận tích hợp và thiết bị đạt; các tình huống lỗi có thông báo an toàn và có đường phục hồi cho người dùng.

## Phase 10 — Bảo mật và kiểm soát vận hành

**Mục tiêu:** khoá các đường truy cập sai quyền và bảo đảm thao tác nhạy cảm có thể truy vết.

- [x] Rà soát JWT, refresh-token rotation/reuse, logout và session revocation.
- [x] Rà soát OTP expiry/rate limit, brute-force protection và account enumeration.
- [x] Kiểm thử ownership và role boundary cho Customer, Caregiver, Admin và anonymous.
- [x] Rà soát CORS, security headers, upload validation, secret handling và log redaction.
- [x] Thêm automated test cho admin login, KYC, payout, dispute và quản lý user/service.
- [x] Tăng test caregiver cho nhận ca, check-in, checklist, evidence và checkout.
- [x] Ghi audit log đầy đủ cho thao tác admin và các thay đổi tài chính.
- [x] Có quy trình khoá tài khoản, thu hồi session và xử lý sự cố quyền truy cập.
- [x] Không còn lỗ hổng critical/high đã biết chưa có phương án xử lý.

**Bằng chứng xác minh:** 26 ca kiểm thử bảo mật Phase 10 đạt, gồm test âm tính cho anonymous, sai role, sai ownership và Google self-registration không thể yêu cầu ADMIN; toàn bộ 125 test backend thường đạt; 7/7 race test PostgreSQL đạt; 15 test caregiver đạt; quét NuGet và `npm audit --omit=dev` không còn cảnh báo critical/high. Migration audit số 26 đã áp dụng và trigger lưu actor từ request đã được kiểm tra trực tiếp. Checklist vận hành, rủi ro còn lại và quy trình xử lý sự cố nằm tại `plan/backend/SECURITY.md`. Pentest độc lập và nghiệm thu trên môi trường public vẫn là đầu việc của Phase 12, không phải bằng chứng đã hoàn thành trong phase này.

**Tiêu chí thoát:** security checklist đạt, test quyền truy cập âm tính đạt và mọi thao tác nhạy cảm truy được actor, thời gian, đối tượng và kết quả.

## Phase 11 — Triển khai, quan sát và khôi phục

**Mục tiêu:** có thể triển khai an toàn, phát hiện lỗi và quay lui khi cần.

- [ ] Tạo container/deployment manifest cho API và admin web.
- [ ] Tách cấu hình theo môi trường; secrets không nằm trong source hoặc image.
- [ ] Thiết lập pipeline build, migration, deploy và rollback có phê duyệt.
- [ ] Thiết lập log tập trung, error tracking, metrics, dashboard và cảnh báo.
- [ ] Định nghĩa SLI/SLO tối thiểu cho API availability, latency, payment và job failure.
- [ ] Tạo backup PostgreSQL tự động; diễn tập restore và ghi nhận RPO/RTO thực tế.
- [ ] Xác minh migration forward/rollback cho release candidate.
- [ ] Viết runbook cho downtime, payment mismatch, queue/job lỗi và lỗi push notification.
- [ ] Chạy kiểm tra tải tối thiểu cho login, catalog, booking, matching và payment callback.

**Tiêu chí thoát:** deploy và rollback rehearsal đạt; cảnh báo phát hiện được lỗi giả lập; restore tạo ra database sử dụng được và đáp ứng RPO/RTO đã chọn.


## Phase 12 — Release candidate và pilot

**Mục tiêu:** đóng gói bản phát hành, chạy pilot có kiểm soát và đưa ra quyết định go/no-go.

- [ ] Hoàn tất Android signing, iOS signing và cấu hình production.
- [ ] Tạo release candidate cố định từ commit/tag đã qua Phase 7–11.
- [ ] Hoàn tất Privacy Policy, Terms of Service, consent và quy trình xoá tài khoản/dữ liệu.
- [ ] Chạy regression trên ma trận Android/iOS mục tiêu và trình duyệt admin được hỗ trợ.
- [ ] Kiểm tra accessibility, responsive, timezone, định dạng tiền/ngày và lỗi tiếng Việt.
- [ ] Chạy pilot với tập user nhỏ; theo dõi funnel, lỗi, payment mismatch và support ticket.
- [ ] Triage toàn bộ lỗi pilot; không còn blocker/critical và có quyết định rõ cho lỗi còn lại.
- [ ] Chốt owner trực vận hành, kênh hỗ trợ và kế hoạch phản ứng sau phát hành.
- [ ] Lập biên bản go/no-go có đại diện sản phẩm, kỹ thuật và vận hành xác nhận.

**Tiêu chí thoát:** release candidate vượt regression và pilot; có thể hỗ trợ, quan sát, khôi phục và rollback; biên bản go-live được phê duyệt.

## Thứ tự thực hiện bắt buộc

1. Hoàn thành Phase 7 trước khi chạy nghiệm thu nghiệp vụ.
2. Hoàn thành Phase 8 trước khi coi bất kỳ tích hợp thanh toán hoặc realtime nào là sẵn sàng phát hành.
3. Phase 9 và Phase 10 có thể chạy song song sau Phase 8.
4. Phase 11 có thể bắt đầu phần hạ tầng sớm, nhưng chỉ được đóng sau Phase 10.
5. Chỉ tạo release candidate ở Phase 12 khi Phase 9–11 đều hoàn thành.

## Điều kiện dừng phát hành

Không phát hành nếu còn một trong các điều kiện sau:

- Có lỗi làm sai ownership, state booking, escrow, wallet hoặc ledger.
- Payment callback/retry có thể finalize hoặc hoàn tiền nhiều lần.
- Có thể truy cập dữ liệu hoặc hành động ngoài role/ownership.
- Migration, backup/restore hoặc rollback chưa được diễn tập thành công.
- Push/realtime hỏng mà ứng dụng không thể đồng bộ lại bằng REST.
- Còn blocker/critical chưa sửa hoặc chưa có quyết định chấp nhận rủi ro bằng văn bản.
