# CareSitter

CareSitter là nền tảng đặt lịch chăm sóc tại nhà gồm API .NET 8, ứng dụng Customer và Caregiver viết bằng Flutter, cùng trang quản trị React.

## Thành phần

- `backend/caresitter-be`: API, SignalR, Hangfire và các module nghiệp vụ.
- `frontend/customer-app`: ứng dụng dành cho khách hàng/người thân.
- `frontend/caregiver-app`: ứng dụng dành cho caregiver.
- `frontend/admin-web`: giao diện vận hành và quản trị.
- `backend/init-db`: schema, seed data và migration nâng cấp PostgreSQL.

## Yêu cầu

- Docker Desktop.
- .NET SDK 8.
- Flutter 3.x.
- Node.js 22 và npm.

## Khởi chạy local

1. Tạo cấu hình local và điền các giá trị bắt buộc:

   ```powershell
   Copy-Item backend/.env.example backend/.env
   ```

2. Khởi động PostgreSQL, Redis và RedisInsight:

   ```powershell
   docker compose -f backend/docker-compose.yml up -d db redis redisinsight
   ```

3. Nâng cấp database đang tồn tại. Hai migration dọn dữ liệu legacy cần cờ xác nhận rõ ràng:

   ```powershell
   powershell -ExecutionPolicy Bypass -File backend/scripts/update-db.ps1 -AllowDestructive
   ```

4. Chạy API:

   ```powershell
   dotnet run --project backend/caresitter-be/ApiHost/CareSitter.ApiHost.csproj
   ```

5. Xác minh API và dependency:

   ```powershell
   powershell -ExecutionPolicy Bypass -File backend/scripts/smoke-test.ps1
   ```

6. Chạy các client trong terminal riêng:

   ```powershell
   cd frontend/customer-app
   flutter run --dart-define=BASE_URL=http://localhost:5033/api/v1

   cd ../caregiver-app
   flutter run --dart-define=BASE_URL=http://localhost:5033/api/v1

   cd ../admin-web
   npm ci
   npm run dev
   ```

Android Emulator phải dùng `http://10.0.2.2:5033/api/v1` thay cho `localhost`.

## Dữ liệu và tài khoản local

Database sạch được tạo từ toàn bộ migration trong `backend/init-db`. Các tài khoản seed chuẩn dùng cho local/acceptance:

| Role | Email | Điện thoại |
| --- | --- | --- |
| Admin | `admin@caresitter.vn` | `0900000001` |
| Customer | `nguoithan@example.com` | `0911111111` |
| Caregiver | `nguoicham@example.com` | `0922222222` |

Lệnh reset dưới đây **xóa database và RedisInsight volume local của riêng Docker Compose CareSitter**, dựng lại toàn bộ migration hiện hành, rồi đặt mật khẩu các tài khoản seed thành `CareSitter123!`:

```powershell
powershell -ExecutionPolicy Bypass -File backend/scripts/reset-local.ps1 -Force
```

Có thể truyền mật khẩu local khác bằng `-TestPassword`. Không dùng các tài khoản hoặc mật khẩu seed này ở staging/production.

## Kiểm tra chất lượng

```powershell
dotnet test backend/CareSitter.sln --nologo

# Chạy riêng race test trên PostgreSQL Docker Compose đang hoạt động
powershell -ExecutionPolicy Bypass -File backend/scripts/test-races.ps1

# Nghiệm thu Phase 8 ba vòng liên tiếp trên PostgreSQL tạm
powershell -ExecutionPolicy Bypass -File backend/scripts/test-phase8.ps1

cd frontend/customer-app
flutter analyze
flutter test

cd ../caregiver-app
flutter analyze
flutter test

cd ../admin-web
npm run build
```

Để đóng hoặc tái xác minh Phase 7 bằng một lệnh, chạy:

```powershell
powershell -ExecutionPolicy Bypass -File backend/scripts/test-phase7.ps1
```

Runner này không xóa database local hiện có. Nó kiểm tra health của PostgreSQL/Redis Compose, dựng database tạm sạch, diễn tập nâng cấp từ migration 25 lên bản hiện tại, chạy API smoke test và đăng nhập ba role seed, chạy toàn bộ backend test với yêu cầu không có test skip, rồi analyze/test/build các frontend. Mặc định toàn bộ chuỗi được chạy **hai lần liên tiếp** và log nằm trong `backend/artifacts/phase7`.

CI chạy lại toàn bộ các bước trên cho mỗi pull request vào `main`.

## Health endpoints

- `/health` và `/health/live`: process API đang hoạt động.
- `/health/ready`: PostgreSQL và Redis đều sẵn sàng phục vụ request.
- `/swagger`: OpenAPI UI trong môi trường Development.

Trạng thái triển khai và các release gate hiện hành được cập nhật tại [docs/release-roadmap.md](docs/release-roadmap.md).
