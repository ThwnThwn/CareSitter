# Rà soát thay đổi RLS và Reviews

Ngày kiểm tra: 08/10/2026. Trạng thái: chưa hoàn tất; cần sửa RLS và nối đủ luồng đọc đánh giá.

## Phạm vi

Đối chiếu nội dung được gửi trong `Pasted text.txt` với source và diff hiện tại. Tập trung vào `ModuleDbContext`, `GetReviewByBooking`, `SupportReadStore`, `SupportErrors`, `ISupportReadStore`, `ReviewsController` và việc xóa import trong `AddTimelineNoteRequest`.

Đọc thêm các hợp đồng booking, registration MediatR, schema SQL, repository review phía customer và ba file được nhắc trong nội dung gửi: `BookingTrackingController`, `email_input_screen.dart`, `SwaggerExtensions`. Ba file này không có thay đổi so với HEAD. Báo cáo không phải rà soát toàn bộ các thay đổi Kafka, payOS, recovery, bản đồ hoặc UI khác đang có trong working tree.

## 1. P1 — Thay `set_config(..., true)` thành `false` chưa sửa được RLS

Vị trí: [ModuleDbContext.cs](../../backend/caresitter-be/Shared/CareSitter.Infrastructure/Persistence/ModuleDbContext.cs), dòng 27–31 và 80–87.

`ApplyRlsContextAsync` thực hiện hai lệnh SQL trước `base.SaveChangesAsync`. Khi caller không chủ động mở connection hoặc transaction, EF mở rồi đóng connection cho từng lệnh. Npgsql reset session khi tái sử dụng connection từ pool. Vì vậy, context vừa được set đã mất trước câu lệnh ghi; đổi sang session-level không giải quyết được vòng đời connection.

Đã tái hiện bằng chính implementation `ModuleDbContext` trong repository, EF/Npgsql theo dependency hiện tại và PostgreSQL 16 trong container test riêng. Tài khoản test không có quyền superuser/BYPASSRLS.

| Trường hợp | User tại thời điểm INSERT | Role tại thời điểm INSERT | Kết quả |
| --- | --- | --- | --- |
| `SaveChangesAsync()` với connection do EF quản lý | NULL | NULL | Context bị mất |
| Caller mở connection trước khi save | Đúng actor | CUSTOMER | Context được giữ |
| Caller có outer transaction | Đúng actor | CUSTOMER | Context được giữ |
| `SaveChangesAsync(false, ct)` dù đã mở connection | NULL | NULL | Bỏ qua override hiện tại |
| Bảng bật RLS, connection do EF quản lý | NULL | NULL | PostgreSQL từ chối ghi, SQLSTATE `42501` |
| Bảng bật RLS, có outer transaction | Đúng actor | CUSTOMER | Ghi thành công |

Bảng thật đang dùng RLS gồm `people.beneficiaries` và `people.family_contacts`. Audit booking trong `26-security-audit-hardening.sql` cũng đọc các GUC này; đường ghi mất context có thể ghi actor NULL/role SYSTEM. Những use case đã có outer transaction giữ context được, nên không kết luận mọi thao tác hiện tại đều lỗi.

Hướng sửa phù hợp: giữ `set_config` và thao tác ghi trong cùng transaction, dùng transaction-local; tận dụng transaction có sẵn và chỉ tự commit/dispose transaction do lớp này tạo. Với query cần RLS, thiết lập scope trước query tại store/use case; chỉ override save không bao phủ luồng đọc.

Nhận định trong nội dung gửi rằng EF không tự tạo transaction cần chỉnh lại: EF có thể tạo transaction cho `SaveChanges`; vấn đề là các lệnh `set_config` chạy trước transaction đó. Tham khảo [transaction của EF Core](https://learn.microsoft.com/en-us/ef/core/saving/transactions) và [reset connection của Npgsql](https://www.npgsql.org/doc/performance.html).

## 2. P2 — Đọc review theo booking mới có một phần

Vị trí: [GetReviewByBookingQuery.cs](../../backend/caresitter-be/Modules/Support/Application/Queries/Reviews/GetReviewByBooking/GetReviewByBookingQuery.cs), dòng 6; [ReviewsController.cs](../../backend/caresitter-be/Modules/Support/Controllers/ReviewsController.cs).

Đã có method ở read store/interface, mã lỗi not-found và query record. Chưa có `GetReviewByBookingQueryHandler`, chưa có route `GET /api/v1/reviews/booking/{bookingId}`. Kiểm tra registration của `SupportModule` cho query mới trả về **0 handler**; controller chỉ có GET `caregiver/{caregiverId:guid}`. Build vẫn qua vì compiler không yêu cầu mỗi MediatR request phải có handler.

Chưa có method/handler/route lấy review theo ID. POST hiện trả Location `/api/v1/reviews/{id}` nhưng URL này chưa có GET; đây là thiếu sót đã có trước đợt sửa. Nếu muốn Location này có thể truy cập, cần triển khai route tương ứng.

Khi hoàn thiện luồng theo booking, handler phải kiểm tra actor và quyền đối với booking trước khi trả dữ liệu, cùng quy ước 401/403/404. `[Authorize]` ở controller chỉ xác nhận đăng nhập. Read store hiện truy vấn theo `BookingId` và không tự kiểm tra quyền; chưa có route nên chưa thể kết luận đang có lỗ hổng truy cập từ endpoint mới.

Nếu cho caregiver đọc, lưu ý `Review.CaregiverId` là ID của `people.caregiver_profiles`, không phải `ICurrentUser.UserId`. Xác thực qua contract công khai của module sở hữu dữ liệu, không so sánh trực tiếp hai ID khác loại.

Customer `ReviewRepository` hiện chưa gọi API review theo booking. Nếu mục tiêu là người dùng xem lại đánh giá đã gửi, cần nối repository và màn hình tương ứng; chỉ bổ sung backend chưa hoàn tất trải nghiệm đó.

## 3. Khoảng trống hardening — Overload async còn bỏ qua context

`ModuleDbContext` chỉ override `SaveChangesAsync(CancellationToken)`; overload `SaveChangesAsync(bool, CancellationToken)` kế thừa từ EF bỏ qua `UpdateTimestamps` và `ApplyRlsContextAsync`. Đã tái hiện dù connection được mở sẵn.

Không tìm thấy caller hiện tại dùng overload bool trong source/test đang rà; đây là khoảng trống đã tồn tại, không phải regression mới do thay true thành false. Khi chuẩn hóa mọi đường save, nên gom implementation vào overload đầy đủ và cho overload ngắn gọi nó. Hai overload sync hiện đã bị chặn bằng exception; thuộc tính `Obsolete(error: true)` tạo hai warning CS0809 khi build.

## Những thay đổi hợp lý

- Xóa hai import thừa trong `AddTimelineNoteRequest` là thay đổi nhỏ, phù hợp.
- `AsNoTracking`, `CancellationToken`, DTO mapper và `SingleOrDefaultAsync` ở read store phù hợp: SQL đã có UNIQUE trên `reviews.booking_id`.
- Thêm mã lỗi `support.review.not_found` giữ đúng nhóm lỗi hiện tại; hiện chưa được dùng vì thiếu handler.
- Thư mục DTO/Handlers trống không tự chứng minh chức năng thiếu. `BookingTrackingController` đã có route `gps-tracks`; không cần thêm route chỉ từ suy đoán trong nội dung gửi.
- Việc bổ sung GET review nên bám nhu cầu nghiệp vụ/API; không thể suy ra bắt buộc chỉ vì đang mở một controller.

## Kiểm chứng và giới hạn

- `dotnet build backend/caresitter-be/Modules/Support/CareSitter.Modules.Support.csproj --nologo --no-restore -v minimal`: thành công, 0 lỗi, 2 warning CS0809.
- `dotnet test backend/tests/CareSitter.Modules.Support.UnitTests/CareSitter.Modules.Support.UnitTests.csproj --nologo --no-restore -v minimal`: 5 pass, 0 fail, 0 skip.
- Integration filter `FullyQualifiedName~BookingFlowTests|FullyQualifiedName~ModuleMediatRRegistrationTests|FullyQualifiedName~ModuleResultExtensionsTests`: 17 pass, 0 fail, 15 skip. Filter cũng khớp `MainBookingFlowTests`; 15 ca PostgreSQL bị skip vì chưa cấu hình `CARESITTER_TEST_ADMIN_CONNECTION` cho runner đó. Không tính các ca skip là pass.
- Probe PostgreSQL riêng: 6 trường hợp về context/RLS như bảng trên; kiểm tra thêm registration handler và route qua reflection. Probe sử dụng lớp base thật và bảng tối thiểu, không thay thế nghiệm thu toàn bộ schema/use case của dự án.
- Container test riêng đã dừng và tự xóa. Không thao tác DB ứng dụng. Không sửa source, không stage/commit/push.

Thứ tự nên hoàn thiện: sửa vòng đời RLS và bao phủ overload async, bổ sung regression tương ứng, sau đó hoàn thiện handler/route/quyền truy cập review theo phạm vi nghiệp vụ thực sự cần.
