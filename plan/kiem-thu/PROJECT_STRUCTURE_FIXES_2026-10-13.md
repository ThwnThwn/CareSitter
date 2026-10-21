# Khắc phục cấu trúc CareSitter — 13/10/2026

## Kết quả và phạm vi

Đã sửa các nhóm ưu tiên A1–A6 trong [báo cáo rà soát](PROJECT_STRUCTURE_AUDIT_2026-10-13.md), bổ sung regression và kiểm chứng local. Đây là kết quả của đợt refactor, **chưa chứng nhận toàn bộ dự án clean hoặc nghiệm thu production**. Phần Lab 2 tiếp tục tạm dừng; chưa build APK, stage, commit, push hay deploy.

Giữ các thay đổi gRPC, AppHost, People và Admin có sẵn trước đợt này. Riêng `vercel.json` đã đặt `git.deploymentEnabled=false` theo lựa chọn mới của người dùng; test cấu hình Vercel đã qua.

## Những phần đã sửa

| Nhóm | Thay đổi và trách nhiệm mới | Bằng chứng source |
| --- | --- | --- |
| Landing AI | Input đọc từ `unknown`, JSON null/array/sai kiểu trả 400; validate output thật; contract dùng chung; tách provider server, client, hook; đóng modal/unmount hủy request; xóa CustomCursor không dùng | [route](../../frontend/landing-page/src/app/api/care-assistant/route.ts), [feature](../../frontend/landing-page/src/features/care-assistant/server.ts), [contract](../../frontend/landing-page/src/features/care-assistant/contract.ts) |
| Customer Settings | Bỏ ba wrapper chuyển tiếp; section Tài khoản/Bảo mật/Hỗ trợ cụ thể; profile nhận callback tên hành động; logout tự đọc provider | [screen](../../frontend/customer-app/lib/features/settings/presentation/screens/settings_screen.dart), [account section](../../frontend/customer-app/lib/features/settings/presentation/widgets/settings_account_section.dart) |
| Customer Tracking | Screen giữ lifecycle/điều hướng; content/care progress/task list/photo tự dựng widget; bỏ builder và WidgetRef chuyển tiếp ở luồng chính; mapping icon nằm trong presentation model | [screen](../../frontend/customer-app/lib/features/shift_tracking/presentation/screens/shift_tracking_screen.dart), [content](../../frontend/customer-app/lib/features/shift_tracking/presentation/widgets/shift_tracking_content.dart) |
| Customer Activity | Status có kiểu, format tiền dùng hàm chung; card/row sở hữu layout; bỏ wrapper Padding/Row/Column trung gian và đổi tên phần summary/amount theo ý nghĩa | [Activity](../../frontend/customer-app/lib/features/home/presentation/screens/activity_screen.dart), [summary](../../frontend/customer-app/lib/features/home/presentation/widgets/activity_recent_booking_summary.dart) |
| Caregiver | Shift detail bỏ 12 builder cùng WidgetRef truyền từ screen; section/card và action đọc provider ở nơi sở hữu; tách beneficiary presentation và safety expansion; bỏ nút more không có hành động | [screen](../../frontend/caregiver-app/lib/features/shifts/presentation/screens/shift_detail_screen.dart), [body](../../frontend/caregiver-app/lib/features/shifts/presentation/widgets/shift_detail_body.dart) |
| Caregiver Schedule/Profile/Settings/Summary | Calendar/timeline dùng widget cụ thể; theo dõi ca thật qua selector; dọn nhánh availability đã mất API và các hàm thêm/xóa no-op; section hồ sơ/hỗ trợ và summary dùng component trực tiếp; callback giới tính/logout có tên rõ | [Schedule](../../frontend/caregiver-app/lib/features/schedule/presentation/screens/schedule_screen.dart), [profile links](../../frontend/caregiver-app/lib/features/settings/presentation/widgets/settings_profile_links.dart), [summary](../../frontend/caregiver-app/lib/features/shifts/presentation/widgets/shift_summary_details.dart) |
| Payments | Phân bổ tranh chấp trong Domain; WalletService điều phối qua port; Infrastructure chia escrow/settlement/dispute và ledger writer; giữ các khóa, transaction và marker idempotency hiện hữu | [allocation](../../backend/caresitter-be/Modules/Payments/Domain/DisputeAllocation.cs), [use case](../../backend/caresitter-be/Modules/Payments/Application/Services/WalletService.cs), [store](../../backend/caresitter-be/Modules/Payments/Infrastructure/WalletLedgerStore.cs) |
| Booking jobs | Application điều phối checkout/refund/settlement; Store truy vấn và transaction; Notifier giữ SignalR/notification; Domain giữ thời hạn lifecycle; từng checkout lưu xong được thông báo trước khi xử lý candidate tiếp | [jobs](../../backend/caresitter-be/Modules/Booking/Application/Jobs/BookingJobsService.cs), [checkout](../../backend/caresitter-be/Modules/Booking/Application/Jobs/BookingCheckoutJobs.cs), [policy](../../backend/caresitter-be/Modules/Booking/Domain/BookingLifecyclePolicy.cs) |
| Nutrition | Năm command/handler riêng: assess, confirm, recommend, replace, save; scope chung giữ quyền/revision/idempotency; chuẩn bị meal và kiểm tra catalog tách riêng; Store/Session/CatalogReader tách trách nhiệm | [commands](../../backend/services/nutrition/src/CareSitter.Nutrition/Application/Commands/AssessNutritionCommandHandler.cs), [scope](../../backend/services/nutrition/src/CareSitter.Nutrition/Application/Commands/NutritionWriteScope.cs), [store](../../backend/services/nutrition/src/CareSitter.Nutrition/Infrastructure/NutritionStore.cs) |
| Admin | Payments/Disputes/Bookings/KYC/Users/Support có API adapter, hook và drawer riêng; page giữ hàng đợi/bộ lọc; mutation khóa đồng bộ trước render, hủy request khi unmount, bỏ response thuộc phiên cũ và giữ lỗi/draft | [mutation](../../frontend/admin-web/src/hooks/useAdminMutation.ts), [dispute hook](../../frontend/admin-web/src/features/disputes/useDisputeReview.ts), [booking hook](../../frontend/admin-web/src/features/bookings/useBookingReview.ts) |

Gia hạn ca Customer trước đây chỉ hiện “đã gửi” mà không lưu qua API. Đã thay bằng ước tính và điều hướng thật sang hỗ trợ; test kiểm tra giới hạn giờ, mở hỗ trợ và không có thông báo thành công giả. Phần giấy tờ Caregiver cũng bỏ subtitle cố định “Đã duyệt • Còn hạn” khi chưa đọc tình trạng KYC.

Nutrition giữ REST/protobuf/error contract. Fingerprint mới giữ đúng thứ tự, null và trường không dùng của request cũ, kể cả ResourceId thừa trong gRPC, để retry đã lưu không bị xung đột chỉ do refactor. Confirm tiếp tục dùng trạng thái assessment làm thao tác lặp an toàn. Không có SQL/migration mới.

## Chỉ dấu cấu trúc sau đợt A1–A6

Các số đếm và kết quả Flutter bên dưới thuộc lượt A1–A6. Mục 2 đã được dọn tiếp sau đó: [kết quả wrapper/frontend](FRONTEND_WRAPPER_FIXES_2026-10-13.md) ghi số đếm mới và kiểm chứng cuối Customer 267 / Caregiver 96 test pass.

| Chỉ dấu | Customer trước → sau | Caregiver trước → sau |
| --- | ---: | ---: |
| File Dart trong lib | 704 → 701 | 368 → 366 |
| File chứa callbackActionN | 102 → 84 | 65 → 56 |
| Trường WidgetRef chuyển tiếp | 25 → 19 | 14 → 8 |
| Trường Widget Function | 79 → 45 | 29 → 0 |
| Color(0x...) ngoài core | 1 → 1 | 0 → 0 |

Số đếm dựa trên source hiện có trong working tree, gồm file untracked và loại file đã xóa. Builder/callback không tự động là lỗi; các số này là chỉ dấu đọc sâu, không thay thế review trách nhiệm. Guard hai app xác nhận không cycle/đảo tầng và các widget nằm trong giới hạn file/build.

Các screen trọng tâm hiện lần lượt 60 dòng (Settings), 92 (Tracking), 75 (Activity), 48 (Shift detail), 147 (Schedule). WalletService 71 dòng và BookingJobsService 63 dòng; logic đã chuyển sang thành phần có trách nhiệm rõ, không chỉ chia file theo số dòng.

## Kiểm chứng local

Môi trường: Windows, Flutter 3.44.4/Dart 3.12.2, .NET SDK 8.0.425, Node 26.1.0; Nutrition chạy PostgreSQL 18.1 test riêng, chỉ bind localhost. Các cluster test đã dừng và file mật khẩu bootstrap đã xóa. Log nằm tại [artifacts](../../backend/artifacts/structure-fixes-20261013/).

| Phạm vi | Kết quả cuối |
| --- | --- |
| Customer flutter analyze + toàn bộ test | Không lỗi; **255 pass**, không fail/skip |
| Caregiver flutter analyze + toàn bộ test | Không lỗi; **89 pass**, không fail/skip |
| Backend architecture | **30 pass** |
| Booking unit | **60 pass**, gồm 8 ca mới về maturity/timeout và thứ tự thông báo sau lưu |
| Payments unit | **134 pass**, gồm 9 ca phân bổ hợp lệ/sai và bảo toàn escrow |
| Các unit backend còn lại | **68 pass**: People, Support, Identity, Catalog, Promotion, Routing |
| Integration backend | **237 pass, 93 skip** vì thiếu DB PostGIS test; không tính skip là pass |
| Messaging trong lần chạy solution | **8 pass, 14 fail do DockerUnavailableException**; chưa kiểm chứng Kafka/container |
| Baseline/Vercel contract sau lựa chọn tắt deploy | **6 pass**; test Vercel trước đó fail đã được khắc phục |
| Nutrition toàn suite với PostgreSQL thật | **58 pass, 0 skip** trong **3 lần chạy liên tiếp**, gồm guard nội bộ và tương thích fingerprint |
| Admin | **70 pass**, TypeScript/build thành công; 4 ca mới về double click, unmount, đổi phiên và request lỗi |
| Landing | **15 pass**, lint, TypeScript và production build thành công; không gọi Gemini thật |
| Whitespace | git diff --check thành công; không có staged file |

Lệnh đã dùng từ root repo, trừ Flutter/Admin/Landing chạy trong app tương ứng:

```powershell
dotnet test backend/CareSitter.sln --no-restore --verbosity quiet
dotnet test backend/tests/CareSitter.Modules.Booking.UnitTests/CareSitter.Modules.Booking.UnitTests.csproj --no-restore
dotnet test backend/tests/CareSitter.Modules.Payments.UnitTests/CareSitter.Modules.Payments.UnitTests.csproj --no-restore
dotnet test backend/tests/CareSitter.IntegrationTests/CareSitter.IntegrationTests.csproj --no-build
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
npm test
npm run build
```

Lần chạy toàn solution không xanh do Docker không khởi động được và xung đột Vercel có sẵn. Vercel đã sửa theo người dùng và Integration đã chạy lại thành công với 93 skip. Docker Desktop vẫn báo lỗi socket inference; không reset Docker hay volume. PostgreSQL native có đủ cho Nutrition nhưng thiếu PostGIS cho fixture backend chính, nên **chưa chạy được race Payments/Booking ba lần**. Không thay schema, mock lock hay bỏ test để che giới hạn này.

## Phần còn lại

1. Khi Docker sẵn sàng, chạy lại race Payments/Booking và Messaging/Kafka trước khi coi đợt backend được xác nhận đầy đủ. Runner hiện có: `backend/scripts/test-races.ps1 -Repeat 3` và `backend/scripts/test-phase7.ps1 -Repeat 2 -SkipFrontend`.
2. Đã xử lý wrapper/builder của Customer Profile edit, Change password, Saved addresses, Auth và Live map, cùng ref chuyển tiếp ở Caregiver Auth/Home/route map/list. Xem [kết quả dọn frontend](FRONTEND_WRAPPER_FIXES_2026-10-13.md); các nhóm Customer Home/Catalog/Caregiver list còn được ghi riêng để xử lý tiếp.
3. Nhiều callbackActionN còn ở các feature khác. Không đổi hàng loạt tên để tuyên bố clean; cần đọc chain dữ liệu và gom widget có ý nghĩa.
4. Router/composition, CSS/types và token còn lại có thể tổ chức tiếp theo phạm vi sử dụng. File route/type dài không tự động là một lỗi nghiệp vụ.
5. Chưa test trên thiết bị thật, chưa build APK, chưa nghiệm thu payOS/Gemini thật và chưa xác nhận CI/deployment từ những thay đổi local này.
