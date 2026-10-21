# Roadmap 14 ngày đưa CareSitter lên production

Ngày lập: **07/10/2026**, múi giờ Asia/Saigon. Mốc đánh giá: **21/10/2026**.
Ngày 0 là 07/10; ngày 14 là 21/10, sau 14 ngày tính từ kickoff.

## 1. Mục tiêu và điều kiện thực tế

Người dùng đã chốt: **một người phát triển, muốn mở công khai Android và iOS**.
Người dùng xác nhận chưa có tài khoản Google Play production, Apple Developer
và máy Mac. Trạng thái server/domain, merchant thật, refund và chi hộ VNPAY
chưa được xác nhận trong lượt lập roadmap này.

Mục tiêu public hai store được giữ làm đích phát hành. **Chưa thể cam kết đạt
đích đó vào 21/10/2026**: cần hoàn thiện sản phẩm, tài khoản, quyền nhà cung
cấp và quy trình review độc lập. Lịch dưới đây là lịch ưu tiên có cổng nghiệm
thu, không phải ước lượng chắc chắn rằng toàn bộ backlog sẽ xong trong 14 ngày.

Đầu ra có thể kiểm soát trong 14 ngày: bản release được version hóa, backend
HTTPS đã diễn tập deploy/restore, build Android/iOS ký hợp lệ khi đủ tài
khoản/môi trường, kiểm thử trên thiết bị và hồ sơ store đủ để bắt đầu testing
hoặc gửi review theo quyền thực có. Public chỉ được bật khi các gate đạt.

Repo có customer app và caregiver app. Nếu phát hành cả hai trên cả Android
và iOS, cần quản lý **bốn artifact và bốn hồ sơ phát hành**. Lịch này giả định
cả hai app; nếu chỉ phát hành customer app ở một store, phải ghi lại scope.

## 2. Những dependency phải bắt đầu ngay

### Google Play

Tài khoản cá nhân tạo sau 13/11/2023 phải có closed test với ít nhất **12
tester opt-in liên tục 14 ngày** trước khi xin quyền production. Đủ số ngày
không tự đồng nghĩa đã được cấp quyền hoặc app đã được duyệt.
[Yêu cầu chính thức của Google](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).

Đồng hồ tính từ thời điểm đáp ứng điều kiện tester, không từ ngày lập
roadmap, tạo tài khoản hoặc upload APK. Hai app phải kiểm tra điều kiện cho
từng app. Không dùng internal test thay cho closed test bắt buộc.

Nếu closed test đủ tester bắt đầu ngày 09/10, 14 ngày hoàn tất khoảng 23/10;
thời điểm xin quyền và review còn ở phía sau. Vì vậy không hứa public Play
ngày 21/10 trong kịch bản đó. Loại tài khoản phải phản ánh chủ thể thực tế;
không chọn loại tổ chức chỉ để tránh điều kiện của tài khoản cá nhân.

### Apple và môi trường iOS

Cần đăng ký Apple Developer, xác minh chủ thể, quyền App Store Connect,
bundle ID, signing/provisioning và môi trường macOS/Xcode. Có thể dùng máy
Mac được phép truy cập hoặc macOS CI phù hợp; cần thiết bị iPhone để nghiệm
thu. Flutter yêu cầu Xcode/macOS cho đường build iOS này.
[Hướng dẫn Flutter](https://docs.flutter.dev/deployment/ios),
[đăng ký Apple Developer](https://developer.apple.com/programs/enroll/).

TestFlight là một bước testing, chưa phải public App Store. Review và yêu
cầu bổ sung có thể kéo dài; chừa thời gian sửa và nộp lại. Không lấy thời
gian review trung bình làm SLA.
[Apple: trạng thái review](https://developer.apple.com/help/app-review/after-submitting-for-review/review-status/).

### VNPAY và vận hành dịch vụ

Giữ quyết định hiện có: hủy trước ca hoàn 100% thực thu về phương thức gốc;
chi hộ caregiver qua VNPAY. Cần quyền merchant/refund/chi hộ, tài liệu,
sandbox và bằng chứng đối soát đúng sản phẩm. Chưa có tài liệu/quyền thì
không tự giả định API chuyển tiền hoặc đánh dấu đã chuyển.

Hạ tầng và integration test có thể tiếp tục khi chờ provider. **Không mở
thu tiền thật khi hoàn tiền, chi trả và đối soát chưa đạt.** Nếu dependency
chưa có, mốc 14 ngày là bản thử nghiệm với dữ liệu/giao dịch thử, không phải
bản public kinh doanh đã hoàn tất.

## 3. Các khoảng trống hiện tại quyết định phạm vi công việc

| Hạng mục | Bằng chứng hiện tại | Việc phải đạt trước public tương ứng |
| --- | --- | --- |
| CRUD ưu đãi admin | Đã push commit `25269e9` lên develop; kiểm thử bản tách riêng đạt | Đưa vào release qua PR/CI, nghiệm thu trên môi trường deploy |
| Khôi phục mật khẩu | Đã triển khai local, migration 35; SMTP thật/native chưa nghiệm thu | Source/config/schema trong cùng release; email và thu hồi phiên chạy thực tế |
| Idempotency | Có payout/ledger/promotion/Kafka từng phần; booking và retry payout app chưa khép kín | Triển khai theo [plan riêng](IDEMPOTENCY_PLAN.md), không trùng booking/tiền khi retry |
| Refund | Có adapter, chưa nối workflow bền vững vào hủy booking | Request/worker/query/ledger/UI/recovery và provider acceptance |
| Payout | Approve hiện ghi ledger và giảm pending nội bộ, chưa chuyển tiền provider | Approved/Processing/Paid/Failed/Unknown phản ánh bằng chứng thực chi |
| Android release | Hai `build.gradle.kts` đang dùng debug signing | Upload/release key riêng, cấu hình signing, OAuth/FCM đúng certificate |
| Apple login | Customer có nút `onPressed: () {}`; chưa thấy backend Apple login | Hoàn thiện flow phù hợp guideline 4.8 hoặc chốt bỏ social login khỏi bản iOS; không để nút giả |
| Xóa tài khoản | Chưa thấy endpoint/use case và UI thực hiện | Đường xóa trong app, xử lý dữ liệu/phiên/media và web entry cho Google Play |
| KYC/media | Có luồng private/proxy; legacy và provider cần nghiệm thu | Anonymous không đọc được CCCD; xử lý URL cũ và quyền/TTL trên provider thật |
| SOS/support | Có trạng thái/timeline/notification; quy trình người trực chưa nghiệm thu | Incident bền vững, người tiếp nhận/ack/escalation và diễn tập khi push lỗi |
| Deploy/data | Có Compose/Caddy/health/migration scaffold | Staging thật, secrets, bootstrap, khóa migration, backup/restore/rollback và alert |
| Thiết bị | Bằng chứng hiện tại chủ yếu local/backend/web | Android và iPhone thật: auth, tiền, GPS, camera, push, network và vòng đời app |

Account deletion là yêu cầu store đối với app có tạo tài khoản: Apple cần
cho khởi tạo xóa trong app; Google yêu cầu đường trong app và web link phù
hợp. Chỉ khóa/deactivate không thay thế xóa dữ liệu. Những dữ liệu phải giữ
theo nghĩa vụ được xử lý theo chính sách retention đúng chủ thể/mô hình.
[Apple](https://developer.apple.com/support/offering-account-deletion-in-your-app/),
[Google Play](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).

Apple guideline 4.8 cần được đối chiếu cho bản có Google/social login.
Sign in with Apple là một hướng đáp ứng; thêm một nút không hoạt động không
đáp ứng yêu cầu. Nếu cắt social login khỏi iOS, phải bảo đảm tài khoản hiện
có vẫn có đường đăng nhập/khôi phục phù hợp và thông tin review đúng flow.
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

## 4. Phạm vi đóng băng trong hai tuần

Giữ luồng: tài khoản → người thân/địa chỉ → dịch vụ/báo giá → đặt lịch/thanh
toán → caregiver nhận/thực hiện ca → checkout/xác nhận → tiền/đánh giá;
gồm các nhánh hủy, hoàn tiền, tranh chấp, hỗ trợ và an toàn liên quan.

Hoãn chat realtime, Nutrition/AI, GPS chạy nền mới, phân tích nâng cao,
microservices, Kubernetes và đổi giao diện diện rộng. Không đưa triển khai
Kafka thành một dự án mới trên đường găng; dùng đường thông báo hiện có nếu
đã nghiệm thu, chỉ bật worker/flow cần thiết khi bằng chứng đáp ứng.

App có thể public trên store nhưng khu vực, giờ phục vụ và số ca phải
giới hạn theo năng lực caregiver/người trực thực tế. Một developer không
tự đồng nghĩa có đội vận hành dịch vụ; phải bố trí người tiếp nhận sự cố
và caregiver đã xác minh trước khi bán ca.

## 5. Roadmap theo ngày

| Ngày | Ngày lịch | Ưu tiên và đầu ra |
| --- | --- | --- |
| 0 | 07/10 | Đăng ký/khởi tạo xác minh store; tìm môi trường Mac/iPhone; xác nhận server/domain và VNPAY; chốt phạm vi. Mở danh sách gate và tester ngay. |
| 1–2 | 08–09/10 | Thiết lập staging HTTPS, secrets, bootstrap admin/catalog/pricing sạch và CI cho release. Cấu hình release signing; tạo build thử cho hai nền tảng. Hoàn thiện setup/listing để bắt đầu closed test/TestFlight sớm khi account/build được phép. |
| 3–6 | 10–13/10 | Làm các P0 theo thứ tự: dòng tiền refund/payout và đối soát → idempotency → xóa tài khoản/login iOS → dữ liệu KYC/SOS. Mỗi ngày đóng một kết quả có test; theo dõi tester và dependency provider. Nếu một đầu việc lớn chưa xong, dồn sang gate ngày 7 thay vì đánh dấu đạt. |
| 7 | 14/10 | Gate kỹ thuật: kiểm tra toàn bộ P0, tình trạng store/Mac/provider. P0 hoặc dependency còn mở thì cập nhật ngày public; tiếp tục test nhưng không xếp go-live ngày 14 như cam kết. |
| 8–10 | 15–17/10 | Kiểm thử xuyên hai app + admin trên thiết bị thật/HTTPS/provider sandbox. Diễn tập retry/crash, thu hồi phiên, hủy/refund, payout unknown, SOS và backup/restore. Hoàn thiện privacy/data safety, quyền, screenshots, tài khoản reviewer. |
| 11–12 | 18–19/10 | Đóng băng release candidate nếu gate đạt. Nộp review khi đủ quyền/điều kiện; cấu hình manual release. Chuẩn bị production cùng build đã kiểm, runbook rollback và cảnh báo có người nhận. Chưa đủ điều kiện Play thì duy trì closed test, không gọi đã public. |
| 13–14 | 20–21/10 | Sửa lỗi/rejection, xác minh lại RC sau sửa; quyết định public từng nền tảng theo trạng thái thực. Chỉ mở nghiệp vụ thật khi gate tiền/dữ liệu/vận hành và store cùng đạt. Nếu chưa đạt, bàn giao bản tested và danh sách việc/ngày external còn chờ. |

Ngày 3–6 là **cửa sổ ưu tiên có giới hạn**, không phải tuyên bố bốn ngày đủ
cho mọi workflow tiền và bảo mật còn thiếu. Hiện trạng source cho thấy có
khả năng phần này vượt ngân sách của một người. Gate ngày 7 là nơi điều
chỉnh mốc hoặc bổ sung nguồn lực, không dồn phần chưa xong vào ngày release.

Một người chỉ giữ một đầu việc lập trình chính cùng lúc. Việc theo dõi
store/tester/provider được làm hằng ngày trong thời gian chờ, không để tới
cuối tuần thứ hai. Duyệt code và test của Codex hỗ trợ năng suất, nhưng
không thay xác minh tài khoản, nhà cung cấp, tester hay vận hành thực tế.

## 6. Các cổng nghiệm thu

### Ngày 2 — Có đường build và testing

- [ ] Đã gửi đăng ký/xác minh store, biết chính xác loại tài khoản/quyền hiện có.
- [ ] Có Mac/macOS CI được truy cập hợp lệ, signing iOS và kế hoạch thiết bị.
- [ ] Android ký upload key riêng; build không dùng debug key.
- [ ] Staging HTTPS hoạt động, không lẫn dữ liệu/credential production.
- [ ] Build thử thực sự cài/mở được; tester có hướng dẫn, opt-in được khi track sẵn sàng.

### Ngày 7 — Đủ cơ sở chốt release candidate

- [ ] Release chứa đúng source/config/migration đã kiểm; recovery/Kafka local chưa tự coi là đã ship.
- [ ] Không còn lỗi sai tiền, sai ownership, session hoặc media nhạy cảm trong phạm vi phát hành.
- [ ] Refund/payout có vòng đời bền vững và bằng chứng provider theo sản phẩm được cấp quyền.
- [ ] Booking/payout retry an toàn; kết quả sau mất phản hồi phục hồi được.
- [ ] Account deletion và flow login iOS hoạt động; bỏ/hoàn thiện nút placeholder.
- [ ] Người trực/SOS, caregiver, giờ/khu vực và policy đã chốt để vận hành thực.

### Ngày 10 — E2E và vận hành thực tế

- [ ] Đăng ký/login/OTP/reset/password revoke trên Android và iPhone thật.
- [ ] Booking/payment/matching/check-in/evidence/checkout/review chạy xuyên các role.
- [ ] Hủy/refund, no-show, dispute, payout failed/unknown và race có bằng chứng.
- [ ] Camera/GPS/FCM/APNs, từ chối quyền, offline/resume và token refresh được kiểm.
- [ ] Kiểm thử xóa tài khoản, private KYC/legacy URL và least privilege admin.
- [ ] Backup ngoài máy chủ; restore vào DB/máy mới; kiểm tiền và không phát lại chi/hoàn đã thực hiện.
- [ ] Log/alert có người nhận; admin đủ MFA hoặc lớp xác thực tương đương phù hợp.

### Ngày 14 — Quyết định public

- [ ] Store đã cấp quyền và duyệt từng app/nền tảng cần phát hành.
- [ ] CI/test/device/migration trên chính commit/artifact cuối đạt, test DB không bị skip.
- [ ] Privacy, terms, consent, data safety và account deletion phản ánh đúng hoạt động.
- [ ] Release không trỏ localhost, sandbox hoặc bật mock/demo cho người dùng thật.
- [ ] Production deploy, live/readiness, secrets, backup, rollback và payment kill switch đã kiểm.
- [ ] Người vận hành và cap ca phù hợp; tiền/data/SOS không còn gate chặn.

Public store và public nghiệp vụ là hai trạng thái được quản lý riêng;
store approve không tự đóng các gate backend/provider. Với một gate chưa
đạt, ghi rõ kết quả: testing, submitted/waiting review hoặc chưa đủ release;
không gắn nhãn đã production-ready chỉ vì ngày lịch đã tới.

## 7. Hạ tầng tối thiểu và lifecycle

Giữ kiến trúc deploy hiện có: API/admin phía sau HTTPS proxy; PostgreSQL và
Redis trong mạng riêng; source/image được pin; secrets ngoài Git; production
bootstrap không chạy demo seed. Không mua/đổi nhà cung cấp hạ tầng trong
lượt lập kế hoạch này.

Migration runner cần một-runner lock và xử lý ghi SQL/checksum an toàn khi
crash. Rehearse DB sạch và nâng cấp đến migration tương ứng RC; đã có
migration 35 ở local không chứng minh production đã có schema đó. Deploy
đợt đầu phải có backup, lệnh kiểm tra và phương án rollback tương thích DB.

.NET 8 hiện còn hỗ trợ đến **10/11/2026**, rất gần sau mốc 21/10. Đưa spike
.NET 10 vào đầu giai đoạn nếu ngân sách cho phép; public roadmap cũ đặt
REL02 trước launch. Nếu muốn phát hành bản dùng .NET 8 trong thời hạn còn
hỗ trợ, đó là thay đổi tiêu chí release cần quyết định rõ, có bản vá được
kiểm và lịch nâng cấp trước EOL; không tự coi .NET 8 đã hết hỗ trợ hôm nay.
[Chính sách hỗ trợ Microsoft](https://dotnet.microsoft.com/en-us/platform/support/policy).

Không tăng nhiều API replica khi các counter/lock/rate limit chưa được
kiểm tra tương ứng; cũng không dùng single VM thay cho backup/restore.

## 8. Việc thực hiện ngay ngày 0

1. Bắt đầu tài khoản store và xác minh, đồng thời chuẩn bị 12 tester thật
   nếu dùng Google Play cá nhân thuộc diện yêu cầu.
2. Có đường Mac/Xcode và iPhone: mượn/thuê/CI phù hợp quyền truy cập và ngân
   sách; giữ ownership signing và bảo vệ certificate/key.
3. Lấy câu trả lời bằng chứng về merchant/refund/payout VNPAY và server/domain.
4. Chốt chủ thể phát hành và phạm vi hai app; khóa các tính năng mới ngoài MVP.
5. Đưa P0 đang mở vào danh sách làm việc; bắt đầu môi trường staging và build
   native trước khi viết thêm tính năng.

Tài liệu này được lưu local bằng tiếng Việt; không commit/push `.md` theo
yêu cầu đã có. Đây là roadmap và đánh giá, chưa đăng ký/mua tài khoản, chưa
deploy hay gọi giao dịch thật.

## 9. Tài liệu dự án liên quan

- [Kế hoạch production chi tiết](PRODUCTION_PLAN.md)
- [Tiến độ và các quyết định tài chính đã chốt](PRODUCTION_PROGRESS.md)
- [Idempotency booking/payout](IDEMPOTENCY_PLAN.md)
- [Khôi phục mật khẩu](PASSWORD_RECOVERY.md)
- [KYC private media](SEC01_PLAN.md)
- [Hướng dẫn deploy](../deploy/README.md)
- [Báo cáo chức năng tổng thể](../tong-quan/BAOCAO_CHUC_NANG.md)
