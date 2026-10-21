# Quy trình migration SQL duy nhất

## Nguồn chuẩn

- Schema, index, constraint, trigger, seed chuẩn nằm trong `backend/init-db/*.sql`; EF chỉ map/query, không quản lý schema.
- Áp dụng bằng `backend/scripts/update-db.ps1`; script lưu tên/checksum trong `public.schema_migrations`. Không sửa nội dung migration đã áp dụng; thêm file số kế tiếp.
- Không chạy `dotnet ef migrations add/database update`, `Database.Migrate[Async]` hoặc `EnsureCreated[Async]` cho các DB này. EF Identity cũ đã được lưu ngoài project tại `docs/legacy-ef-migrations`; không có migration runtime để chạy nhầm.
- Script init của Docker dành cho DB mới. DB đã tồn tại phải đi qua update script, không giả định restart Docker sẽ cập nhật schema.
- `update-db.ps1` hiện làm việc qua Docker container, mặc định `-From 10`, `-ContainerName caresitter-db`. Khi vận hành phải truyền tên container/điểm bắt đầu rõ ràng; `-SkipStart` tránh khởi động compose ngoài ý muốn. Không chạy `-From 0` lên DB đã có bảng; 00–09 là bootstrap cho DB mới. Runner test legacy hiện kiểm tra 00–25 → 26–32, không khẳng định hỗ trợ mọi phiên bản lịch sử.
- `-AllowDestructive` chỉ dùng sau review riêng cho 19/21; mặc định script bỏ qua hai migration phá hủy này. Không hiểu “script chạy thành công” là toàn bộ file đã áp dụng; kiểm kê schema/checksum thực tế.
- DB cũ có `__EFMigrationsHistory` không cần xóa để chuyển quy trình. Không tái thực thi các file archive; đối chiếu schema trước khi chọn mốc SQL.

## Một thay đổi schema

1. Chốt module/schema sở hữu dữ liệu. Thêm SQL mới theo thứ tự hiện có; tránh query runtime chéo schema, giao tiếp qua Contracts.
2. Dùng expand/contract: thêm cột nullable/default an toàn, triển khai code tương thích cũ/mới, backfill có kiểm soát, chỉ xóa cột ở bản sau. Kiểm tra lock, thời gian chạy, dữ liệu nhạy cảm, volume và index trước khi duyệt.
3. Đồng bộ EF mapping, domain/contracts và regression tests. Script phải áp dụng được trên DB mới và DB ở phiên bản được hỗ trợ.
4. Chạy `backend/scripts/test-phase7.ps1 -Repeat 2 -SkipFrontend` với Docker: build, fresh SQL, legacy upgrade, replay checksum, smoke/API và tất cả test projects. Không chạy thử trên DB thật.
5. Staging: xác nhận phiên bản/checksum, backup, restore drill, dung lượng và cửa sổ deploy; chạy update script với đích DB rõ ràng theo tham số của script. Chỉ một migration runner hoạt động tại một thời điểm.
6. Production: người vận hành xác nhận đúng DB/backup trước khi chạy. Lưu bằng chứng log/checksum và kiểm tra health, readiness, luồng chính sau deploy.

## Rollback

Ưu tiên rollback application về bản vẫn tương thích schema mở rộng hoặc thêm migration SQL sửa tiến về phía trước. Không dùng EF `Down`; không xóa bảng để “undo”. Thay đổi phá hủy dữ liệu cần runbook riêng, backup đã restore thử và phê duyệt. Restore DB toàn phần cần đánh giá dữ liệu phát sinh từ thời điểm backup và reconciliation thanh toán; không thực hiện tự động.

## Giới hạn của guard

Architecture tests chặn source EF migration/snapshot và lời gọi tạo/migrate schema ở runtime, cùng compile liên kết archive. Đây là hàng rào source regression, không thay thế quyền DB, review SQL, kiểm tra catalog thực tế hay restore drill. Archive còn trong Git để đối chiếu lịch sử, không phải cơ chế migration thứ hai.

## Hạn chế runner cần xử lý trước production

- Docker bootstrap thực thi SQL nhưng không tự ghi checksum toàn bộ bootstrap vào `public.schema_migrations`; bảng này hiện ghi các file chạy qua update script. Không giả định DB bootstrap có đủ lịch sử checksum.
- Update script chưa có khóa phân tán bảo đảm một runner duy nhất; bước ghi checksum tách khỏi bước áp dụng file SQL. Một số file tự có BEGIN/COMMIT, một số không. Nếu crash giữa hai bước có thể phải đối chiếu schema trước khi chạy lại, không retry mù.
- Vì vậy việc bỏ EF migrations đã giải quyết hai cơ chế cạnh tranh, nhưng chưa biến runner dev/baseline thành deployment orchestrator production. Cần migration-runner hardening + failure-injection, DB role tối thiểu, backup/restore và runbook vận hành được nghiệm thu riêng; không sửa lại SQL lịch sử để chữa những hạn chế này.
