# Sửa luồng cập nhật hồ sơ người thân

> Cập nhật: 11/10/2026. Phạm vi: module People và app customer. Đã có code và kiểm thử local; chưa triển khai, chưa kiểm chứng với PostgreSQL đang chạy.

## Hợp đồng cập nhật

`PUT /api/v1/beneficiaries/{id}` vẫn yêu cầu `FullName` và `DefaultAddressId` thuộc người dùng, đã xác minh. Quyền sở hữu hồ sơ được kiểm tra như trước.

- Trường tùy chọn không xuất hiện trong JSON: giữ giá trị hiện tại tại server.
- Trường tùy chọn có giá trị `null`: xóa trường đó.
- Trường JSONB có giá trị mới: thay toàn bộ giá trị của trường, không merge sâu.
- Phân biệt hai trường hợp bằng DTO nhận biết property có mặt, hỗ trợ camelCase/PascalCase. Client không điều khiển được metadata `ProvidedFields`.
- Response tiếp tục là hồ sơ sau khi lưu. Không thay schema SQL hoặc chạy migration.

App chỉ gửi các trường tùy chọn đã thay đổi trên form. Các trường sức khỏe, điện thoại và ghi chú vận động được đọc vào model nhưng không gửi lại từ form thông tin cơ bản. Điều này tránh việc sửa tên ghi đè dữ liệu sức khỏe cũ từ app.

## Hành vi app

- Tạo/sửa bằng ngày sinh `DD/MM/YYYY`, cho phép để trống; gửi API theo `YYYY-MM-DD`. Tuổi được tính từ ngày sinh và xét ngày sinh nhật.
- Giới tính được nạp từ hồ sơ, gửi đúng mã `MALE`, `FEMALE`, `OTHER`, `UNSPECIFIED`; hồ sơ thiếu dữ liệu không tự nhận giới tính mặc định.
- Không tự gán 70 tuổi, “Bình thường” hoặc mức chăm sóc trung bình khi API thiếu dữ liệu. Ghi chú vận động không còn bị chuyển thành ghi chú chung.
- Dùng response đã lưu để cập nhật state; lỗi ghi dữ liệu khôi phục state trước thao tác.
- ID không tồn tại không mở hồ sơ của người khác. Màn hình sửa nạp đúng hồ sơ khi dữ liệu đến sau.

## Kiểm chứng ngày 11/10/2026

Môi trường: Windows, .NET 8 theo `global.json`, Flutter/Dart đang cài tại `C:\src\flutter`. Các test backend dùng repository giả lập; các test app dùng dữ liệu thử nghiệm, không gọi dịch vụ thật.

| Lệnh | Thư mục chạy | Kết quả |
| --- | --- | --- |
| `dotnet test backend/tests/CareSitter.Modules.People.UnitTests --nologo --verbosity quiet` | Gốc repository | 14 pass, 0 fail, 0 skip |
| `dotnet test backend/tests/CareSitter.ArchitectureTests --nologo --verbosity quiet` | Gốc repository | 30 pass, 0 fail, 0 skip |
| `flutter analyze --no-pub` | `frontend/customer-app` | Không có issue |
| `flutter test --no-pub test/features/beneficiary test/features/booking --reporter expanded` | `frontend/customer-app` | 39 pass, 0 fail, 0 skip |
| `flutter build web --no-pub` | `frontend/customer-app` | Thành công, gồm Wasm dry run |

Các ca quan trọng: request cũ thiếu trường; null tường minh; thay JSONB; quyền owner; ngày sinh/giới tính sai; tuổi trước/sau sinh nhật; lưu từ form; API lỗi; ID không tồn tại; hồ sơ tải chậm; tạo hồ sơ nhận ID đã lưu.

## Việc còn lại khi triển khai

Triển khai backend trước app vì app mới dựa vào quy tắc giữ trường bị bỏ qua. Kiểm tra lưu/đọc lại trên DB và thiết bị thật. Dữ liệu đã bị xóa hoặc ngày sinh đã bị đổi trong các lần lưu trước không tự khôi phục từ thay đổi này.

Module Nutrition, cấu trúc y khoa trong JSONB và `health_profile_revision` chưa được triển khai trong đợt sửa luồng này.
