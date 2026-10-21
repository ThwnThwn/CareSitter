# Bản đồ CareSitter: CARTO Voyager làm mặc định

## Cấu hình đang dùng

Cả customer-app và caregiver-app đã dùng cùng cấu hình CARTO Voyager. App khách hàng chỉ tải Google Maps khi chọn rõ `MAP_PROVIDER=google`. App chăm sóc viên giữ nút mở ứng dụng Google Maps bên ngoài để chỉ đường theo yêu cầu người dùng; nút này không gọi Maps SDK hoặc Routes API trong CareSitter.

Token đã nhận được lưu riêng trong `.env.local` của từng app, được Git bỏ qua. Kiểm tra trực tiếp cho thấy token hiện tại trả ảnh `API KEY REQUIRED` trên cả domain chính và subdomain CARTO, dù HTTP là 200. Vì vậy local đang đặt `MAP_PROVIDER=osm` để tiếp tục test được. Chưa xác minh CARTO hiển thị bản đồ thật với key hợp lệ.

## Lấy key và chạy app

1. Lấy key dành cho **CARTO Basemaps** tại [trang đăng ký chính thức](https://carto.com/basemaps/apikey/). Key phải được dịch vụ Basemaps chấp nhận; token từ dịch vụ khác không thể coi là đã được xác minh.
2. Trong `.env.local` của từng app, thay `CARTO_API_KEY` và đặt lại chế độ mặc định:

```dotenv
MAP_PROVIDER=carto
CARTO_API_KEY=KEY_BASEMAPS_CUA_BAN
```

3. Đứng tại thư mục app tương ứng, chạy:

```powershell
flutter run -d chrome --dart-define-from-file=.env.local
```

Flutter hỗ trợ cả JSON và `.env` qua `--dart-define-from-file`. Customer-app còn đọc cấu hình public từ `.env` đã bundle khi khởi động, nhưng `.env` hiện được Git theo dõi: không lưu token mới vào đó. Caregiver-app nhận file env qua bước build, không cần bundle file này thành asset. Giá trị `--dart-define` có ưu tiên cao hơn file cấu hình.

Nếu muốn dùng JSON, sao chép `maps.local.example.json` thành `maps.local.json`, điền key rồi chạy `flutter run --dart-define-from-file=maps.local.json`. Cả hai app đã bỏ qua file local trong Git. File mẫu luôn để key trống.

Muốn test trên điện thoại thật, thêm `BASE_URL` và `HUB_BASE_URL` là URL backend mà điện thoại truy cập được; `localhost` trên điện thoại không trỏ về máy tính. Khởi động lại app sau khi đổi cấu hình build.

## Chọn nguồn bản đồ

| Cấu hình | App khách hàng | App chăm sóc viên |
| --- | --- | --- |
| Không đặt hoặc `MAP_PROVIDER=carto` | CARTO Voyager nếu có key; thiếu key dùng OpenStreetMap | Tương tự |
| `MAP_PROVIDER=osm` | Chỉ OpenStreetMap, kể cả có key CARTO/Google | Chỉ OpenStreetMap |
| `MAP_PROVIDER=google` | Google Maps khi có key phù hợp; không tải được thì dùng CARTO/OSM | Bản đồ nhúng vẫn dùng CARTO/OSM; chỉ đường Google là nút mở app bên ngoài |

Ví dụ bật Google Maps trên customer-app khi đã cấu hình khóa:

```powershell
flutter run -d chrome --dart-define-from-file=maps.local.json --dart-define=MAP_PROVIDER=google
```

## Cấu hình kỹ thuật

- URL raster đúng là `https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=...`, tham số `key` theo tài liệu hiện tại, không phải `api_key` trong plan ban đầu.
- Key được trim và mã hóa query; dùng các subdomain `a`, `b`, `c`, `d`, hỗ trợ tile retina và zoom gốc tối đa 20. OpenStreetMap dùng URL riêng, không nhận token CARTO.
- Nguồn `© OpenStreetMap contributors` và `© CARTO` luôn hiển thị khi dùng CARTO. Ghi nguồn nằm ngoài phần nhấn để mở preview và ngoài thẻ thông tin ở bản đồ chăm sóc viên.
- Đổi nguồn tile không đổi GPS, booking, phân quyền, group SignalR hay cơ sở dữ liệu. GPS vẫn cần app chăm sóc viên ở màn hình trước; không thêm theo dõi nền.
- Không có key thì tự dùng OpenStreetMap. Với key sai, máy chủ có thể trả ảnh thông báo HTTP 200: cần sửa key, không thể chỉ kiểm tra HTTP để kết luận hợp lệ. Lỗi mạng/quota/giới hạn key vẫn cần xử lý ở cấu hình dịch vụ.

Key được gửi từ ứng dụng khách tới CDN nên có thể đọc được trong app/trình duyệt; file ignore giúp tránh commit lên Git. Key dành cho web có thể giới hạn website. Key native không dùng giới hạn website; nếu bật giới hạn app native, cần gửi các header nhận diện ứng dụng theo hướng dẫn CARTO, phần header này chưa được thêm trong phạm vi tích hợp tile hiện tại.

## Hạn mức

Theo [CARTO Basemaps FAQ](https://docs.carto.com/faqs/carto-basemaps), kiểm tra ngày 08/10/2026: ứng dụng thương mại được miễn phí tới **1 triệu lượt yêu cầu tile mỗi tháng**, cộng gộp các key raster/vector trong tài khoản. Dự án phi thương mại có mức miễn phí 5 triệu. Một lượt mở/kéo/zoom bản đồ có thể tạo nhiều yêu cầu tile. Vượt hạn mức thương mại cần gói trả phí; theo dõi dashboard trước khi đưa app lên production.

Nguồn URL/attribution: [CARTO Basemaps](https://carto.com/basemaps/), [mẫu raster chính thức](https://github.com/CartoDB/basemap-styles).
