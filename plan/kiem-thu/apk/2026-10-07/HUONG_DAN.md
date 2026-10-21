# Cài APK CareSitter để test trên Android

Hai APK được build từ mã nguồn hiện tại ngày **07/10/2026**, có các màn hình khôi phục mật khẩu mới. Các file và script trong thư mục này nằm ngoài repository; không commit hoặc push tài liệu Markdown.

## Tải và cài

1. Kết nối điện thoại Android với cùng Wi-Fi của máy tính đang build.
2. Mở `http://192.168.1.134:8765/` trên trình duyệt điện thoại để tải app khách hàng hoặc app người chăm sóc. Nếu trang tải đã dừng, chạy lệnh dưới đây trong PowerShell trên máy tính:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\EXE\apk-test\2026-10-07\Mo-Trang-Tai-APK.ps1'
   ```

3. Mở file `.apk` vừa tải và cho phép trình duyệt cài ứng dụng khi Android yêu cầu. Hai app có ID khác nhau nên có thể cài cùng trên một điện thoại.
4. Có thể chuyển APK bằng cáp USB nếu điện thoại không truy cập được trang tải.

Trang tải hiện chạy trên máy tính. Khi tải xong, có thể dừng bằng:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\EXE\apk-test\2026-10-07\Dung-Trang-Tai-APK.ps1'
```

## Bật API để test đăng nhập và nghiệp vụ

APK dùng **`http://192.168.1.134:5033/api/v1`**. Đây là IP Wi-Fi hiện tại của máy tính, không phải server production. Máy tính phải bật và API phải chạy trong suốt quá trình test.

Docker/API đang tắt lúc bắt đầu build. Để chạy API:

1. Mở Docker Desktop và đợi Docker sẵn sàng.
2. Mở PowerShell, chạy:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\EXE\apk-test\2026-10-07\Mo-API-Test.ps1'
   ```

   Script khởi động PostgreSQL, Redis, Kafka và dùng cấu hình local hiện có trong `backend/.env`, rồi chạy API trên cổng 5033. Giữ cửa sổ PowerShell này mở.

3. Trên điện thoại, mở `http://192.168.1.134:5033/health/ready`. Khi API và dịch vụ sẵn sàng, trang trả trạng thái khỏe. Sau đó mở app và dùng tài khoản test hiện có.
4. Nếu Windows hỏi quyền truy cập mạng, cho phép trên mạng riêng đang dùng. Nếu chưa truy cập được, kiểm tra máy tính và điện thoại có cùng Wi-Fi, mạng có chặn thiết bị giao tiếp với nhau không, và firewall có chặn cổng 5033/8765 không.

## Khi IP hoặc URL API thay đổi

URL API được nhúng lúc build. Nếu IP Wi-Fi đổi, hoặc muốn dùng API HTTPS để test từ mạng khác, build lại:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\EXE\apk-test\2026-10-07\Build-Lai-APK.ps1' -ApiBaseUrl 'https://API-CUA-BAN/api/v1'
```

Thay URL ví dụ bằng URL API thật. Cập nhật thông tin URL trong trang tải và tài liệu này, rồi cài APK mới.

## Phạm vi bản test

- Bản **debug**, phiên bản `1.0.0+1`, được ký bằng khóa debug trên máy build. Đây là bản để cài trực tiếp và test.
- APK chứa mã native cho `arm64-v8a`, `armeabi-v7a` và `x86_64`.
- Cho phép kết nối HTTP ở manifest debug để truy cập API trong Wi-Fi; manifest release không thay đổi.
- Đăng nhập, đặt lịch, khôi phục mật khẩu và các chức năng dùng dữ liệu cần API tương ứng đang chạy. Gửi mã email cần SMTP local được cấu hình hợp lệ.
- Đăng nhập Google, thông báo đẩy, camera, vị trí và luồng thanh toán cần kiểm tra tiếp trên thiết bị thật với cấu hình dịch vụ tương ứng.
- Lần build này kiểm tra đóng gói APK và chữ ký. Chưa có điện thoại Android kết nối để kiểm tra cài đặt và chạy thực tế.

Tài liệu chính thức: [Build và cài APK Flutter](https://docs.flutter.dev/deployment/android).
