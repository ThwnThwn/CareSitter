# Kế hoạch đưa Nutrition lên iPhone để kiểm thử

> Cập nhật: 16/10/2026  
> Phạm vi: customer-app iOS, ApiHost REST, gRPC Nutrition và PostgreSQL local/staging.  
> Mục tiêu: kiểm thử end-to-end trên iPhone thật; không phải phát hành production và không dùng dữ liệu sức khỏe thật.

## 1. Kết luận và đường triển khai

Máy phát triển hiện tại chạy Windows. Đường được Flutter và Apple hỗ trợ chính thức vẫn dùng macOS/Xcode, nhưng có thể thử một đường cộng đồng mới trước:

1. **POC `xcross` trên Windows** — công cụ hướng trực tiếp tới Flutter iOS, build/sign/install lên iPhone iOS 17+ và hỗ trợ hot reload. Đây là giải pháp thử nghiệm, không phải release gate.
2. **Mac + Xcode + iPhone cắm USB** — đường chính thức và ổn định nhất để debug nếu có Mac. Có thể dùng Apple ID/personal development team cho kiểm thử trên thiết bị của mình.
3. **Build trên macOS và phân phối qua TestFlight** — phù hợp khi tiếp tục code trên Windows và muốn cài app lên iPhone không cần cắm Mac. Cần Apple Developer/App Store Connect, signing và một runner macOS hoặc máy Mac.

Nếu chưa có Mac lẫn quyền Apple Developer, chỉ có thể triển khai Flutter web qua HTTPS và mở bằng Safari để test tạm giao diện/API. Cách này **không được tính là nghiệm thu ứng dụng iOS native**.

Luồng mạng cho cả hai đường native:

```text
Customer app trên iPhone
  -> HTTPS staging/ngrok /api/v1
  -> ApiHost REST :5033
  -> Nutrition gRPC :5036
  -> PostgreSQL Nutrition
```

iPhone không dùng được `adb reverse`; `localhost` trên iPhone là chính điện thoại. Vòng test local phải dùng HTTPS tunnel hoặc domain staging.

## 2. Trạng thái iOS hiện tại

| Hạng mục | Trạng thái 16/10/2026 | Việc cần làm |
| --- | --- | --- |
| Máy build | Windows, không có Xcode | Thử POC xcross; Mac/Xcode hoặc macOS CI là fallback chính thức |
| iOS project | Bundle ID `vn.caresitter.customer`, iOS target 14.0 | Xác nhận bundle ID thuộc Apple team dùng để ký |
| Plugin native | Flutter 3.44.4, project dùng Swift Package Manager | Resolve package và build thử trên Xcode hiện hành |
| Signing | Automatic signing nhưng chưa có `DEVELOPMENT_TEAM` | Chọn team/certificate/provisioning profile trên Mac hoặc CI |
| TestFlight | Chưa có workflow iOS/TestFlight | Tạo App Store Connect record và pipeline upload nếu chọn TestFlight |
| Backend URL | App nhận `BASE_URL`/`HUB_BASE_URL` qua dart-define | Dùng cùng một origin HTTPS truy cập được từ iPhone |
| Core DB/Redis | Docker Desktop đang tắt | Khởi động `db`, `redis`, và `ngrok` nếu test qua tunnel local |
| Nutrition | Gateway đã nối nhưng ba feature flag mặc định tắt | Bật chỉ ở môi trường test |
| Catalog | Runtime không tự seed draft | Publish fixture tổng hợp P4 trong database test |
| AI parser | Mặc định tắt | Giữ tắt; chỉ dùng dữ liệu test có cấu trúc |

Các quyền camera, vị trí, ảnh, push/APNs và background mode chưa phải điều kiện của màn Nutrition, nhưng phải được rà riêng trước khi dùng bản iOS để nghiệm thu toàn bộ customer-app.

## 3. Phân biệt xtool và xcross

- `xtool` tập trung vào ứng dụng iOS dạng SwiftPM. Hỗ trợ Flutter trực tiếp vẫn nằm trong roadmap của dự án.
- `xcross` là dự án riêng, lấy cảm hứng từ xtool và tái hiện pipeline Flutter iOS trên Windows/Linux. Đây mới là công cụ phù hợp để thử với customer-app.
- Customer-app hiện dùng Flutter 3.44.4 và SwiftPM cho plugin iOS, nên đáp ứng điều kiện kiến trúc thuận lợi nhất của xcross. Tuy vậy các plugin native như Firebase, Google Maps, camera, secure storage và image picker vẫn phải build thử thật; không suy ra tương thích chỉ từ việc project đã dùng SwiftPM.
- Không dùng Apple ID chính với đường đăng nhập không chuẩn của công cụ cộng đồng. Ưu tiên App Store Connect API key có quyền tối thiểu; nếu chỉ có free account thì dùng tài khoản development riêng và chấp nhận rủi ro khóa tài khoản mà chính tài liệu xcross cảnh báo.

## 4. Đợt A — Dựng backend Nutrition test qua HTTPS

1. Khởi động Docker Desktop và chỉ bật core dependency cần thiết:

```powershell
cd backend
docker compose up -d db redis ngrok
```

2. Chạy PostgreSQL Nutrition local hoặc database Nutrition staging riêng.
3. Nạp đủ migration Nutrition và publish `catalog/fixtures/p4-api-smoke.bundle.json` bằng các role catalog. Fixture phải hiển thị rõ đây là dữ liệu tổng hợp kiểm thử.
4. Khởi động Nutrition ở `5035/5036` với:
   - `Nutrition__Enabled=true`
   - `Nutrition__AssessmentsEnabled=true`
   - `Nutrition__RecommendationsEnabled=true`
   - `HealthParser__Enabled=false`
5. Khởi động ApiHost lắng nghe `0.0.0.0:5033`, bật Nutrition gateway và trỏ gRPC tới `5036`.
6. Kiểm tra local `/health/ready`, sau đó lấy URL HTTPS hiện tại của ngrok tại `http://localhost:4040`.
7. Kiểm tra URL HTTPS từ mạng ngoài trả health/capability đúng. Không ghi token hoặc secret vào log/tài liệu.

Tiêu chí đạt: capability đã đăng nhập trả `enabled=true`, `assessmentsEnabled=true`, `recommendationsEnabled=true`, `freeTextParserReady=false`; URL HTTPS gọi được từ iPhone bằng 4G/5G hoặc Wi-Fi khác.

## 5. Đợt B0 — POC xcross trên Windows

Chỉ thực hiện sau khi người dùng xác nhận chấp nhận dùng công cụ cộng đồng và đã có iPhone iOS 17+:

1. Review release, checksum, license AGPL-3.0 và script cài đặt của xcross trước khi chạy; không pipe script mạng thẳng vào PowerShell.
2. Cài Swift toolchain 6.4+, LLVM, Python 3 và `pymobiledevice3` theo preflight của xcross.
3. Tải `Xcode.xip` từ nguồn Apple được công cụ yêu cầu và dùng `xcross sdk install`; không commit hoặc chia sẻ SDK đã trích xuất.
4. Xác thực bằng App Store Connect API key có quyền tối thiểu hoặc Apple ID development riêng, không dùng Apple ID chính.
5. Cắm iPhone, Trust máy Windows, bật Developer Mode và dựng RSD tunnel.
6. Chạy kiểm tra không thay đổi project:

```powershell
cd frontend/customer-app
xcross flutter doctor
```

7. Chỉ khi doctor đạt mới build/run với HTTPS test backend:

```powershell
xcross flutter run `
  -D BASE_URL=https://<TEST_DOMAIN>/api/v1 `
  -D HUB_BASE_URL=https://<TEST_DOMAIN>
```

8. POC đạt khi app build, ký, cài, mở được; plugin registration không lỗi; đăng nhập và mở Nutrition; hot reload hoạt động.
9. Dừng POC và chuyển Mac/TestFlight nếu gặp plugin không tương thích, signing không ổn định, yêu cầu patch sâu vào generated iOS project hoặc phải giảm bảo mật tài khoản.

Kết quả xcross chỉ dùng cho vòng debug thiết bị. Build phát hành vẫn phải được tái xác nhận qua pipeline macOS/Xcode chính thức.

## 6. Đợt B1 — Cài trực tiếp bằng Mac/Xcode

Áp dụng khi có Mac:

1. Cài Flutter, Xcode và iOS platform support; chấp nhận license Xcode.
2. Pull đúng commit đang test, chạy `flutter pub get` và resolve Swift packages.
3. Mở `ios/Runner.xcworkspace` hoặc project theo cấu hình Flutter hiện tại.
4. Chọn Apple team, bật automatic signing và kiểm tra bundle ID. Nếu bundle ID đã thuộc team khác, dùng bundle ID development riêng có hậu tố rõ ràng.
5. Cắm iPhone, bấm Trust và bật Developer Mode.
6. Chạy:

```bash
flutter run -d <IPHONE_DEVICE_ID> \
  --dart-define=BASE_URL=https://<TEST_DOMAIN>/api/v1 \
  --dart-define=HUB_BASE_URL=https://<TEST_DOMAIN>
```

7. Dùng đăng nhập email/mật khẩu hoặc OTP trong vòng đầu; chưa trộn lỗi Google Sign-In/APNs vào bài test Nutrition.

Tiêu chí đạt: app được ký/cài thành công, đăng nhập được và màn chi tiết beneficiary hiển thị lối vào **Gợi ý thực đơn**.

## 7. Đợt B2 — Phân phối qua TestFlight

Áp dụng khi không có Mac tại chỗ nhưng có Apple Developer/App Store Connect:

1. Xác nhận team sở hữu bundle ID `vn.caresitter.customer` hoặc chốt bundle ID staging.
2. Tạo app record trong App Store Connect trước khi upload build.
3. Chuẩn bị certificate/provisioning profile hoặc App Store Connect API key; chỉ lưu trong secret store của CI.
4. Bổ sung workflow macOS chỉ build customer-app iOS:
   - checkout đúng commit;
   - cài đúng Flutter version;
   - `flutter pub get`;
   - resolve Swift packages;
   - đưa signing material vào keychain tạm;
   - build IPA release với build number duy nhất;
   - upload App Store Connect;
   - xóa keychain tạm và file signing khi job kết thúc.
5. Build dùng HTTPS test domain:

```bash
flutter build ipa --release \
  --build-name <SEMVER> \
  --build-number <UNIQUE_BUILD_NUMBER> \
  --dart-define=BASE_URL=https://<TEST_DOMAIN>/api/v1 \
  --dart-define=HUB_BASE_URL=https://<TEST_DOMAIN>
```

6. Thêm tài khoản thử nghiệm vào nhóm TestFlight nội bộ, cài TestFlight trên iPhone và cài build.
7. Không dùng external testers ở vòng đầu; external testing có thể phát sinh beta review.

Tiêu chí đạt: build xuất hiện trong TestFlight, cài được trên iPhone, mở app không crash và gọi đúng HTTPS test backend.

## 8. Đợt C — Happy path Nutrition trên iPhone

Dùng customer và beneficiary test; không nhập thông tin sức khỏe thật. Beneficiary người lớn phải không có ghi chú tự do và không thuộc nhóm bị fixture chặn.

1. Đăng nhập và mở chi tiết beneficiary.
2. Vào **Gợi ý thực đơn**; xác nhận đúng beneficiary.
3. Điền trường sức khỏe có cấu trúc, chọn trạng thái thuốc `reported_none`, rồi lưu.
4. Bấm **Kiểm tra thông tin** và quan sát `queued -> processing -> terminal`.
5. Trả lời câu hỏi làm rõ nếu có và chạy lại theo revision mới.
6. Xác nhận assessment đủ điều kiện và tạo thực đơn ba bữa.
7. Mở metadata nguồn món; phải thấy nguồn tổng hợp P4 và cảnh báo không phải hướng dẫn dinh dưỡng thật.
8. Đổi món bữa trưa, lưu plan và mở lại từ lịch sử.

Tiêu chí đạt: không crash/loading vô hạn, trạng thái và lỗi rõ ràng bằng tiếng Việt, dữ liệu giữ đúng owner/beneficiary/revision sau khi mở lại app.

## 9. Đợt D — Ca lỗi và hành vi iOS bắt buộc

| Ca | Kỳ vọng |
| --- | --- |
| Chuyển Wi-Fi sang 4G/5G khi đang tải | Báo lỗi/retry có kiểm soát, không tạo request trùng |
| Đưa app xuống nền rồi mở lại khi assessment đang xử lý | Polling tiếp tục đúng session |
| iOS đóng app do thiếu tài nguyên rồi mở lại | Không khôi phục nhầm dữ liệu phiên cũ |
| Tăng Dynamic Type | Không tràn chữ, vùng chạm chính vẫn dùng được |
| Xoay màn hình | Form và kết quả không mất dữ liệu chưa gửi ngoài dự kiến |
| Sửa form nhưng chưa lưu | Khóa thao tác kiểm tra và hướng dẫn lưu |
| Bấm nhanh nhiều lần | Idempotency ngăn ghi trùng |
| Hồ sơ đổi revision | Hiện stale/profile changed và buộc tải lại |
| Logout/đổi tài khoản khi request đang chạy | Không hiển thị dữ liệu tài khoản cũ |
| Nhập free-text khi parser tắt | Lỗi `nutrition.ai_unavailable` có kiểm soát; không gửi ra ngoài |
| HTTPS tunnel đổi domain hoặc hết phiên | App báo không kết nối; không fallback sang URL/fixture giả |

## 10. Bằng chứng và Definition of Done

Lưu local, không commit token hoặc dữ liệu sức khỏe:

- video/ảnh capability, assessment, recommendation, source, replace và saved plan;
- model iPhone, phiên bản iOS, build number và commit;
- Flutter/Xcode device logs đã lọc thông tin nhạy cảm;
- log ApiHost/Nutrition, health check và correlation ID liên quan;
- bảng pass/fail cho happy path, lifecycle, session và network transitions.

Vòng iPhone hoàn tất khi build native cài được, happy path đạt, các ca session/network không rò dữ liệu hoặc ghi trùng, và không còn lỗi P0/P1. Fixture tổng hợp chỉ chứng minh đường truyền kỹ thuật, không chứng nhận chất lượng dinh dưỡng.

## 11. Ngoài phạm vi vòng đầu

- Bật AI parser hoặc gửi dữ liệu sức khỏe thật.
- Phát hành catalog Nutrition production.
- Public App Store release.
- Google Sign-In, APNs/push, payment, Maps, camera và background location.
- Android device acceptance.

