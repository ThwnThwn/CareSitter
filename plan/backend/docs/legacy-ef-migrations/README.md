# EF migration archive — không chạy

Tài liệu này đã được chuyển vào `plan/`. File C# archive vẫn ở [thư mục source lịch sử](../../../../backend/docs/legacy-ef-migrations/identity/); không di chuyển chúng cùng Markdown.

Các file Identity trong thư mục source lịch sử chỉ lưu để đối chiếu, nằm ngoài mọi runtime project và không được compile. `AddAvatarUrlAndNotificationPrefsToUsers` thực tế tạo `users`, `audit_logs`, `user_devices`; `Down` xóa cả bảng. Không dùng chúng để nâng cấp hoặc rollback DB hiện tại.

Nguồn schema duy nhất là `backend/init-db/*.sql`, được áp dụng bằng `backend/scripts/update-db.ps1` và theo dõi checksum trong `public.schema_migrations`. Xem [quy trình migration](../MIGRATIONS.md). Không dùng `dotnet ef database update`, `Database.Migrate` hay `EnsureCreated` song song với SQL.
