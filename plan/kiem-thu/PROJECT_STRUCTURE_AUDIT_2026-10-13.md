# Rà soát cấu trúc toàn dự án CareSitter — 13/10/2026

> Báo cáo này giữ nhận định của lần audit trước khi sửa. Đợt khắc phục tiếp theo nằm tại [PROJECT_STRUCTURE_FIXES_2026-10-13.md](PROJECT_STRUCTURE_FIXES_2026-10-13.md); một số class/wrapper nêu dưới đây đã được thay thế. Liên kết đến file đã xóa dẫn qua báo cáo khắc phục để tra source thay thế.

## Kết luận

**Dự án chưa clean hoàn toàn.** Cấu trúc thư mục, chiều phụ thuộc và các ranh giới chính đã có nền tốt. Phần còn yếu là phân chia trách nhiệm: Flutter có nhiều lớp trung gian truyền hàm dựng UI; backend vẫn đặt một số luật nghiệp vụ và điều phối lớn trong Infrastructure; Nutrition và Admin chưa nhất quán theo từng use case/feature.

Đợt này chỉ kiểm tra và lập báo cáo, theo yêu cầu tạm dừng phần Lab 2. Không sửa source ứng dụng, không build APK, không commit/push. Báo cáo phản ánh **working tree local**, bao gồm thay đổi chưa commit của gRPC, AppHost và Admin; không xác nhận trạng thái production hay GitHub CI hiện tại.

## Phạm vi và bằng chứng

Đã quét danh sách source, các dependency/import, giới hạn widget, điểm tập trung trách nhiệm; đọc sâu các điểm đáng chú ý và đối chiếu quy ước hiện tại. Không coi việc quét toàn bộ danh sách file là đã review nghiệp vụ từng dòng.

| Khu vực | File được thống kê | Nhận định cấu trúc |
| --- | ---: | --- |
| Customer `lib/` | 704 Dart | Đúng tầng theo guard; nhiều widget tách theo layout và truyền callback qua nhiều lớp |
| Caregiver `lib/` | 368 Dart | Đúng tầng theo guard; Shift detail còn phụ thuộc nhiều hàm dựng widget từ screen |
| Admin `src/` | 55 TS/TSX/CSS | Catalog/Promotion đã có adapter; Booking/Payments/Disputes/KYC/Users/Support chưa đồng đều |
| Landing `src/` | 39 TS/TSX/CSS | Luồng consultation đã tách feature; trợ lý AI còn gộp xử lý request với component và thiếu validation runtime |
| Backend chính `caresitter-be/` | 885 C# | Module và shared contract rõ; Wallet/Booking jobs cần tách trách nhiệm |
| Nutrition `src/` | 56 C# | Service độc lập; command và persistence còn gom nhiều loại thao tác |
| AppHost `orchestration/` | 2 C# | Vai trò composition riêng phù hợp; thay đổi còn local |
| **Tổng trong các thư mục trên** | **2.209** | Bao gồm test đặt trong `src/` của web; không tính dependency, file sinh, backend test, SQL và script |

Đã xem thêm tổ chức `backend/init-db`, `deploy`, workflow CI, project references và test kiến trúc. Các thư mục build, cache, snapshot và tài liệu local không tự động bị coi là lỗi kiến trúc.

### Kết quả chạy trong đợt này

| Kiểm tra | Kết quả |
| --- | --- |
| `CareSitter.ArchitectureTests` | 30 pass, 0 fail, 0 skip |
| Nutrition `ServiceArchitectureTests` | 1 pass, 0 fail, 0 skip |
| Customer `frontend_boundaries_test.dart` | 3 pass |
| Caregiver `frontend_boundaries_test.dart` | 3 pass |
| Admin TypeScript: `tsc --noEmit -p tsconfig.app.json` | Exit 0 |
| Landing TypeScript: `tsc --noEmit --incremental false` | Exit 0 |
| Graph import/export TS/TSX, có resolve alias | Admin: 54 file, 149 cạnh, 0 vòng; Landing: 25 file, 32 cạnh, 0 vòng |
| Thử input lỗi của route AI bằng transpile + adapter giả, không gọi mạng | JSON `null` gây `TypeError`; `{}` và `[]` trả 400 |

Tổng **37 kiểm tra kiến trúc pass**. Không chạy lại toàn bộ functional test, PostgreSQL race suite, nghiệm thu ngân hàng hay build ứng dụng trong lần rà cấu trúc này. Test kiến trúc hiện tại không chứng minh rằng mọi class đã có trách nhiệm nhỏ và rõ.

Log, TRX, inventory và kết quả probe lưu tại [thư mục bằng chứng](../../backend/artifacts/structure-audit-20261013/).

## Những phần đã làm tốt

- Backend chính có bảy module nghiệp vụ, Domain/Application/Infrastructure/Controllers và shared contract. Guard hiện tại không báo phụ thuộc ngược, tham chiếu trực tiếp nội bộ module khác hoặc truy cập SQL xuyên schema module trong phạm vi kiểm tra.
- Hai app có feature-first, controller/repository và domain riêng; dependency graph không báo cycle hay đảo tầng. Toàn bộ widget nằm trong giới hạn file/build mà guard hiện tại kiểm tra.
- Formatter dùng chung đã tồn tại trong `core/utils`; spacing/radius/font/color đã được gom đáng kể. Quét literal `Color(0x...)` ngoài core chỉ còn 1 ở Customer, 0 ở Caregiver; đây là thống kê hẹp, không phải chứng nhận mọi token đã hoàn tất.
- Các sửa về session/lifecycle, form, booking và consultation ở đợt trước không được đánh dấu lại là chưa làm chỉ vì tài liệu cũ từng nêu vấn đề.
- Nutrition có solution, transport và database ownership độc lập. Test kiến trúc riêng xác nhận không project-reference monolith và không truy cập `people.beneficiaries`.
- SQL tập trung trong `backend/init-db`; runner deploy theo filename/checksum và bỏ seed demo. Các tiền tố SQL trùng số không được tự ý đổi tên vì filename là lịch sử migration.
- CI local có backend baseline, Flutter, Admin, Nutrition, Landing và job build AppHost mới. AppHost dùng SDK riêng cho orchestration không đồng nghĩa backend nghiệp vụ đã bị nâng lên SDK đó.

## Các vấn đề còn lại

### A1 — Customer: tách file nhưng chưa giảm phụ thuộc giữa các widget

**Ưu tiên refactor: cao.**

- [SettingsTopPaddingProfileLayout](PROJECT_STRUCTURE_FIXES_2026-10-13.md) truyền `WidgetRef`, 5 hàm dựng widget và các callback sang [SettingsTopPaddingProfileContent](PROJECT_STRUCTURE_FIXES_2026-10-13.md), rồi chuyển tiếp sang `SettingsProfileBookingsContent`.
- [ShiftTrackingContent](../../frontend/customer-app/lib/features/shift_tracking/presentation/widgets/shift_tracking_content.dart) nhận 9 trường `Widget Function`, thêm hàm dựng app bar, `WidgetRef`, model, state và các biến progress. Screen vẫn sở hữu phần lớn cách dựng UI, dù file đã nhỏ hơn.
- [ActivityRecentRowBookingIsCancelledInset](PROJECT_STRUCTURE_FIXES_2026-10-13.md) chủ yếu thêm Padding rồi chuyển nguyên dữ liệu/callback sang widget kế tiếp. Tên file phản ánh cấu trúc layout thay vì vai trò giao diện.

Thống kê Customer: **102 file có tên `callbackActionN`, 25 trường `WidgetRef`, 79 trường `Widget Function`**. Đây là chỉ dấu để chọn chỗ đọc sâu, không phải 206 lỗi độc lập hay yêu cầu cấm mọi builder.

Ảnh hưởng: muốn sửa một phần Settings/Tracking phải lần qua nhiều file và chữ ký hàm; khó xác định widget nào chịu trách nhiệm hiển thị/state; test khó dựng độc lập.

Hướng sửa: gom lại thành section/card có ý nghĩa; widget nhận dữ liệu cần thiết và callback tên hành động; container đọc provider ở ranh giới rõ. Ưu tiên Settings → Shift tracking → Activity. Không chỉ đổi tên callback hoặc tiếp tục cắt file để đạt số dòng.

### A2 — Caregiver: Shift detail vẫn là screen điều khiển cách dựng phần lớn UI

**Ưu tiên refactor: cao.**

[ShiftDetailBody](../../frontend/caregiver-app/lib/features/shifts/presentation/widgets/shift_detail_body.dart) chỉ 87 dòng nhưng nhận **12 hàm dựng widget** cùng `WidgetRef`, booking, beneficiary và nhiều cờ trạng thái. Nó gọi ngược các builder do [ShiftDetailScreen](../../frontend/caregiver-app/lib/features/shifts/presentation/screens/shift_detail_screen.dart) cung cấp.

Thống kê Caregiver: **65 file có tên `callbackActionN`, 14 trường `WidgetRef`, 29 trường `Widget Function`**.

Ảnh hưởng và hướng sửa tương tự Customer: section Status/Earnings/Schedule/Recipient/Checklist/Actions nên là widget cụ thể với đầu vào nhỏ, dùng state hiển thị thống nhất; sự kiện nhận/từ chối/bắt đầu ca đi qua controller. Sau Shift detail mới dọn nhóm profile/schedule có cùng dấu hiệu. Không kết luận phần shift active đã refactor trước đây là chưa làm.

### A3 — Backend: luật chia tiền và nhiều workflow còn nằm trong Infrastructure

**Ưu tiên refactor: cao vì liên quan nghiệp vụ nhạy cảm; chưa có kết luận sai số tiền trong audit này.**

- [WalletService](PROJECT_STRUCTURE_FIXES_2026-10-13.md), 559 dòng: lock escrow, promotion subsidy, settlement, release, refund và dispute. Từ `ResolveDisputeAsync` dòng 307, class vừa chuẩn hóa phán quyết, tính refund/fee/penalty/earning, vừa truy vấn danh tính, ghi ledger, cập nhật ví và điều khiển transaction.
- Cùng file có nhánh relational và non-relational cho settlement/dispute. Hai đường ghi dữ liệu làm tăng phần phải giữ đồng nhất khi sửa luật.
- [BookingJobsService](PROJECT_STRUCTURE_FIXES_2026-10-13.md), 449 dòng: late check-in, checkout hết giờ, auto-confirm, mở rộng offer, hoàn booking không ghép được, giải ngân đến hạn. Ngoài chạy job, class lấy dependency qua service scope, chọn booking, quyết định luồng, ghi DB và phát realtime/notification.

Hướng sửa: đưa phép phân bổ tiền thuần vào policy Domain; Application điều phối use case qua port; adapter Infrastructure giữ transaction/lock/SQL. Tách job theo use case và dùng lại chính sách/trạng thái chung. **Giữ nguyên tính nguyên tử của ledger/ví, idempotency, transaction và điều kiện dispute khi tách**; cần test PostgreSQL/concurrency khi thực sự sửa.

Không coi 574 dòng của [ApiHost/Program.cs](../../backend/caresitter-be/ApiHost/Program.cs) tự nó là vi phạm: chủ yếu là composition, health, rate limit, middleware và đăng ký job. Có thể gom extension theo nhóm sau khi xử lý hai class trên.

### A4 — Nutrition: một command chứa nhiều use case và nhiều field tùy chọn

**Ưu tiên refactor: vừa–cao.**

[NutritionCommand](PROJECT_STRUCTURE_FIXES_2026-10-13.md) dùng chuỗi `Operation` và các field nullable để biểu diễn assess/confirm/recommend/replace/save. [NutritionCommandHandler](PROJECT_STRUCTURE_FIXES_2026-10-13.md) xử lý cả quyền, revision, quota, fingerprint, idempotency, xác nhận assessment, chọn/đổi món và lưu plan.

File handler chỉ 135 dòng nhưng khoảng 10,6 nghìn ký tự, có nhiều câu lệnh/nhánh dài trên một dòng. Số dòng không phản ánh độ phức tạp thực tế. [NutritionStore](../../backend/services/nutrition/src/CareSitter.Nutrition/Infrastructure/NutritionStore.cs) đồng thời quản lý owner transaction, claim job và nested session cho nhiều loại resource/catalog.

Hướng sửa: command có kiểu riêng cho từng thao tác và field bắt buộc phù hợp; tách phần access/revision/idempotency dùng chung có chủ đích; tách persistence theo trách nhiệm trong cùng session/transaction khi cần. Không nhân bản kiểm tra health/catalog revision giữa các handler, không giữ lock khi gọi mạng.

Guard Nutrition hiện bảo vệ sự độc lập với monolith, chưa kiểm tra đầy đủ hướng import Domain/Application/Infrastructure bên trong service. Nên bổ sung khi chuẩn hóa các use case.

### A5 — Admin: mô hình feature/API/hook chưa áp dụng đồng đều

**Ưu tiên refactor: vừa.**

Catalog đã có [catalogApi.ts](../../frontend/admin-web/src/features/catalog/catalogApi.ts). Tuy vậy các file sau vẫn đặt URL/payload mutation, trạng thái busy/error, xử lý xác nhận và UI trong cùng component/file:

- [BookingsPage.tsx](../../frontend/admin-web/src/pages/BookingsPage.tsx): `BookingDrawer.complete`, dòng 63.
- [PaymentsPage.tsx](../../frontend/admin-web/src/pages/PaymentsPage.tsx): đối soát và duyệt payout.
- [DisputesPage.tsx](../../frontend/admin-web/src/pages/DisputesPage.tsx): `resolve`/`cancel`, dòng 49/61.
- [KycPage.tsx](../../frontend/admin-web/src/pages/KycPage.tsx), [UsersPage.tsx](../../frontend/admin-web/src/pages/UsersPage.tsx), [SupportTickets.tsx](../../frontend/admin-web/src/features/support/SupportTickets.tsx): mutation vẫn nằm trong UI.

Không áp quy tắc tên thư mục Riverpod một cách máy móc cho React. Vấn đề là trách nhiệm và tính nhất quán giữa các feature. Nên có API adapter theo feature, hook quản lý thao tác/state và component nhận dữ liệu/sự kiện. Giữ hàm tính phân bổ thuần đang có trong `operations.ts`, tránh đưa trở lại JSX.

`types.ts` dùng chung 312 dòng và `styles.css` khoảng 27,5 nghìn ký tự là hạng mục tổ chức tiếp theo, chưa cần tách hàng loạt trước các mutation nghiệp vụ.

### A6 — Landing: biên dữ liệu của trợ lý AI chưa đủ chặt; có lỗi input tái hiện được

**Ưu tiên sửa lỗi input: sớm; ưu tiên refactor toàn feature: vừa.**

- [Route AI](../../frontend/landing-page/src/app/api/care-assistant/route.ts) dòng 42–49 ép kiểu kết quả `request.json()` rồi đọc `body.message`. Với body JSON `null` và AI đã cấu hình, hàm ném `TypeError` trước khối catch gọi AI. Probe local đã tái hiện, không gọi Gemini.
- Route định nghĩa schema gửi provider, nhưng tại dòng 73 chỉ `JSON.parse` output rồi trả về. [CareAssistant.tsx](../../frontend/landing-page/src/components/CareAssistant.tsx) lại tự khai báo interface và ép kiểu response; chưa có validator runtime dùng chung tại biên dữ liệu.
- Component đồng thời chứa `fetch`, loading/error và JSX; nên tách feature client/hook/contract theo cách đã làm cho consultation.
- [CustomCursor.tsx](PROJECT_STRUCTURE_FIXES_2026-10-13.md) không có import tới trong graph source hiện tại; là ứng viên xóa nếu không còn dùng. Entry của Next/test cũng có thể không có incoming import, nên không đánh dấu toàn bộ danh sách này là dead code.
- Script `npm test` hiện chỉ chạy test consultation; lỗi input AI trên chưa nằm trong test command này.

Hướng sửa: parse input từ `unknown`, reject null/array/sai kiểu bằng 400; kiểm tra output thực tế; dùng contract chung; thêm test input sai/output sai và trạng thái request của feature AI. Không cần đổi thiết kế landing để xử lý việc này.

## Thứ tự triển khai đề xuất

1. Chặn lỗi JSON `null` của route AI bằng bản sửa nhỏ và test riêng khi quay lại sửa code.
2. Customer: Settings → Shift tracking → Activity. Hoàn thành từng feature cả cấu trúc và regression test.
3. Caregiver: Shift detail → các wrapper profile/schedule tương tự; bảo toàn controller và lifecycle hiện có.
4. Backend: Wallet allocation policy/use case → Booking background use case, kèm PostgreSQL/race regression.
5. Nutrition: command theo từng thao tác → chia persistence có kiểm soát → guard kiến trúc nội bộ.
6. Admin: Payments/Disputes → Bookings/KYC/Users/Support, theo adapter/hook/component nhất quán.
7. Landing AI feature và phần tổ chức chung còn lại: router/composition extension, CSS/types, code không dùng. Formatter/tokens Flutter ở mức ưu tiên thấp hơn các mục trên.

Tiêu chí hoàn tất: trách nhiệm đọc được qua tên class/file; dữ liệu đi qua biên rõ; widget không phải lớp chuyển tiếp dài; pure policy test được độc lập; guard/test giữ được behavior và quyền sở hữu dữ liệu. Không dùng số file nhỏ hơn 300 dòng làm tiêu chí duy nhất.

## Lệnh kiểm chứng

Tại repository:

```powershell
dotnet test backend/tests/CareSitter.ArchitectureTests/CareSitter.ArchitectureTests.csproj --no-restore --nologo
dotnet test backend/services/nutrition/tests/CareSitter.Nutrition.Tests/CareSitter.Nutrition.Tests.csproj --no-restore --nologo --filter FullyQualifiedName~ServiceArchitectureTests
```

Trong từng app Flutter:

```powershell
flutter test --no-pub test/architecture/frontend_boundaries_test.dart --reporter expanded
```

Trong Admin và Landing tương ứng:

```powershell
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.app.json
node node_modules/typescript/bin/tsc --noEmit --incremental false
```

Không dùng báo cáo này để đánh dấu toàn bộ feature đã nghiệm thu. Các nhánh tiền, lifecycle và triển khai cần bộ kiểm chứng tương ứng khi sửa thực tế.
