# Theo dõi chăm sóc viên: CARTO mặc định, Google Maps tùy chọn

## Trạng thái hiện tại

Màn theo dõi ca mặc định dùng CARTO Voyager qua `flutter_map`. Google Maps là tùy chọn riêng, chỉ tải SDK khi chọn `MAP_PROVIDER=google`; có khóa Google nhưng chưa chọn chế độ này cũng không tải Google Maps. Khi thiếu khóa CARTO, app dùng OpenStreetMap. Hướng dẫn cấu hình hai app nằm tại [tài liệu CARTO](../../cartodb-map-integration/huong-dan-su-dung.md).

Đã kiểm tra bằng các bài kiểm tra Flutter và build Android/Web. iOS đã cấu hình nguồn nhưng cần máy Mac/Xcode để build và xác nhận trên thiết bị. Chưa thử bản đồ Google thật vì chưa có project/API key.

## Luồng vị trí

1. Mở booking đang ở trạng thái `caregiver_en_route`.
2. Đăng ký các stream từ `CareSignalRService` hiện có và lấy ngay snapshot tại `GET /api/v1/bookings/{id}/gps/latest`; việc lấy snapshot không chờ Hub kết nối xong.
3. Nhận `GpsUpdated` qua kết nối SignalR dùng JWT hiện có. GPS chỉ gửi vào group customer có quyền; không thay đổi backend thành phát GPS vào group booking chung.
4. Chỉ chấp nhận đúng booking, đúng chăm sóc viên hiện tại và phiên bản GPS mới hơn. Snapshot REST cũ không ghi đè tọa độ mới từ SignalR.
5. Marker di chuyển trong 450 ms, xoay theo hướng GPS nếu có. Camera bám theo khi bật nút theo dõi; thao tác trên bản đồ tạm dừng bám theo. Nút “Xem cả hai điểm” cho thấy chăm sóc viên và địa chỉ đích.
6. Khi SignalR sẵn sàng, kiểm tra REST mỗi 30 giây; khi mất kết nối, mỗi 10 giây. Polling dừng khi app customer vào nền hoặc ca kết thúc giai đoạn di chuyển.
7. Tọa độ hơn 60 giây được ghi rõ là vị trí cũ, marker mờ đi và camera không tự bám theo mẫu cũ. Khi đổi chăm sóc viên/kết thúc di chuyển, vị trí hiện tại bị xóa.

Không yêu cầu quyền GPS của khách hàng để xem vị trí chăm sóc viên. App chăm sóc viên hiện gửi GPS khi ở màn hình trước; vào nền sẽ tạm dừng. Theo dõi nền cần một phần triển khai riêng cho quyền, dịch vụ nền và chính sách pin.

Chưa gọi Google Routes API hoặc tính ETA theo đường bộ. Không vẽ đường thẳng rồi gọi đó là tuyến đi thực tế.

## Đăng ký và cấu hình Google Maps

1. Mở [Google Cloud Console](https://console.cloud.google.com/), tạo project dành cho CareSitter.
2. Liên kết billing. Đây là thao tác bạn tự thực hiện trong tài khoản Google của mình.
3. Vào APIs & Services → Library và bật các API cần sử dụng:
   - Android: Maps SDK for Android.
   - iOS: Maps SDK for iOS.
   - Web: Maps JavaScript API.
4. Tạo khóa riêng cho từng nền tảng và giới hạn:
   - Android: package `vn.caresitter.customer` cùng SHA-1 của chứng chỉ debug/release tương ứng. Có thể đọc SHA-1 bằng `.\android\gradlew.bat -p android signingReport` khi đứng tại thư mục app.
   - iOS: bundle ID đang dùng trong Xcode; chỉ cho phép Maps SDK for iOS.
   - Web: HTTP referrers của localhost dùng để test và domain frontend thật; chỉ cho phép Maps JavaScript API.
5. Sao chép `maps.local.example.json` thành `maps.local.json`, rồi điền ba khóa phù hợp. File `maps.local.json` đã được Git bỏ qua. Không ghi khóa server/Routes/Geocoding vào file cấu hình phía khách hàng; không gửi khóa lên chat.
6. Đặt `MAP_PROVIDER=google` trong file cấu hình để bật tùy chọn này. Chạy lại app; hot reload không thay đổi khóa hoặc cấu hình native:

```powershell
flutter run -d chrome --dart-define-from-file=maps.local.json --dart-define=MAP_PROVIDER=google
```

Khi test trên điện thoại thật, `localhost` là điện thoại, nên cần URL HTTPS của backend cho cả REST và Hub. Ví dụ với tunnel hiện tại:

```powershell
flutter build apk --debug --dart-define-from-file=maps.local.json --dart-define=BASE_URL=https://uncrystallized-subtransversal-chantel.ngrok-free.dev/api/v1 --dart-define=HUB_BASE_URL=https://uncrystallized-subtransversal-chantel.ngrok-free.dev
```

Android đọc khóa từ `dart-defines` vào manifest; iOS đọc cùng cấu hình từ build setting và gọi `GMSServices.provideAPIKey`; Web tải SDK khi mở bản đồ. Nếu khóa sai/không được cấp quyền, cần sửa giới hạn/API/billing trong Google Cloud; không thể coi việc build thành công là đã xác minh khóa hợp lệ.

Google Maps không hỗ trợ SDK native cho Windows/Linux/macOS trong phần này; bản Web hoặc bản đồ dự phòng vẫn sử dụng được. Các giấy phép nguồn mở có thể xem tại Hồ sơ → Hỗ trợ → Giấy phép nguồn mở.

## Cách kiểm tra bằng hai app

1. Có booking đã được gán chăm sóc viên và địa chỉ có tọa độ thật.
2. Trong app chăm sóc viên, chọn “Bắt đầu di chuyển”, cấp quyền vị trí và giữ app ở màn hình trước.
3. Trong app khách hàng, mở booking → Theo dõi trực tiếp.
4. Di chuyển điện thoại chăm sóc viên: marker cập nhật, nhãn hiển thị tuổi của mẫu GPS. Kéo bản đồ rồi bấm nút theo dõi để kiểm tra camera.
5. Tắt mạng một thiết bị rồi bật lại để kiểm tra kết nối lại. Khi kết thúc di chuyển/check-in hoặc hủy ca, marker vị trí di chuyển phải biến mất.

## Chi phí

Theo bảng giá Google được kiểm tra ngày 08/10/2026, Maps SDK cho bản đồ Android/iOS có mức miễn phí không giới hạn; Web dùng Dynamic Maps có 10.000 lần tải miễn phí mỗi tháng, sau đó có phí. Routes API là dịch vụ riêng có mức phí/hạn mức riêng. Project vẫn cần billing và API key; nên giới hạn quota và theo dõi ngân sách trong Google Cloud. Giá có thể thay đổi.

Nguồn chính thức: [Cấu hình Flutter](https://developers.google.com/maps/flutter-package/config), [bảng giá Google Maps](https://developers.google.com/maps/billing-and-pricing/pricing), [billing của Maps JavaScript API](https://developers.google.com/maps/documentation/javascript/usage-and-billing).

## Kiểm tra kỹ thuật

```powershell
flutter test test/features/shift_tracking test/core/realtime/gps_update_test.dart test/core/realtime/care_signalr_service_test.dart
flutter analyze
flutter build apk --debug
flutter build web
```

Các bài kiểm tra Google Maps sử dụng adapter SDK giả để xác minh luồng marker/camera mà không gọi dịch vụ trả phí. Kiểm tra trên bản đồ Google thật vẫn cần khóa hợp lệ và thiết bị/trình duyệt.

Đã xác minh 15 bài kiểm tra liên quan GPS, SignalR và màn theo dõi. Giao diện đã kiểm tra ở chiều rộng 390 px và 320 px với cỡ chữ 140%; thanh tiêu đề không che nút bản đồ, thao tác xem hai điểm chừa chỗ cho nhãn GPS để marker vẫn nhìn thấy. Trạng thái của người chăm sóc đang di chuyển hiển thị “Đang đến”; đã bỏ thanh tiến độ hành trình cố định vì chưa có dữ liệu tuyến đi/ETA để tính tiến độ thật.
