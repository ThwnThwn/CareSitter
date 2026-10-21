# CareSitter Caregiver App

## Mục đích tài liệu

Đây là context UI cho Stitch khi thiết kế app mobile dành cho người chăm sóc
(caregiver) của CareSitter. Sản phẩm giúp caregiver nhận ca, xem lịch, thực hiện
ca chăm sóc, gửi bằng chứng và theo dõi thu nhập.

Ảnh đính kèm trong yêu cầu chỉ là ví dụ về màn hình nhập DESIGN.md của Stitch;
không dùng màn hình đó làm màn hình sản phẩm. Hãy thiết kế giao diện CareSitter
theo đặc tả bên dưới.

## Người dùng và bối cảnh

- Người dùng chính: caregiver tại Việt Nam, thường thao tác nhanh trên điện thoại.
- Bối cảnh: ở nhà, trên đường đến địa điểm chăm sóc hoặc đang bận chăm sóc khách.
- Ưu tiên: biết ngay việc cần làm, thời gian và địa điểm; thao tác lớn, rõ ràng,
  dùng được bằng một tay; giảm lỗi khi check-in/check-out.
- Ngôn ngữ giao diện: tiếng Việt. Tiền tệ: VND, hiển thị hậu tố đ.
- Không thiết kế theo phong cách landing page hoặc dashboard marketing. Đây là
  một product UI thực dụng, tin cậy và giàu trạng thái.

## Định hướng hình ảnh

Thiết kế mobile-first, sạch, ấm và chuyên nghiệp trong lĩnh vực chăm sóc sức
khỏe tại nhà. Dùng nền xanh ngọc rất nhạt, bề mặt trắng và màu xanh lá cho
những hành động chính. Màu cam chỉ dùng cho cảnh báo nhẹ hoặc thông tin cần chú ý.

Tránh giao diện toàn màu xanh, gradient nặng, glassmorphism, card bo quá tròn,
shadow lớn, chữ viết hoa dày đặc và các hình minh họa trang trí không giúp người
dùng hoàn thành công việc.

## Design tokens

### Màu

| Vai trò | Giá trị | Cách dùng |
| --- | --- | --- |
| Primary | #00B14F | CTA chính, trạng thái đang chọn, switch bật |
| Primary dark | #008A3D | Chữ/biểu tượng trên nền primary nhạt |
| Primary container | #E5F7ED | Nền ca mới, success nhẹ |
| Secondary | #F5A623 | Rating, cảnh báo cần chú ý |
| Background | #EEF7F7 | Nền màn hình |
| Surface | #F7FBFB | Toolbar/panel phụ |
| Card | #FFFFFF | Bề mặt nội dung |
| Text primary | #1A2E2E | Heading, nội dung chính |
| Text secondary | #5A7272 | Mô tả và metadata |
| Text hint | #6E8989 | Placeholder hoặc trạng thái phụ; vẫn phải đủ tương phản |
| Border | #D5E8E8 | Viền input, card, divider |
| Error | #E84040 | Lỗi, ca khẩn cấp, tài liệu hết hạn |
| Warning | #F39C12 | Ca chờ phản hồi, cảnh báo |
| Success | #2ECC71 | Hoàn thành, sẵn sàng nhận việc |
| Info | #3498DB | Thông tin trung tính |

### Typography và layout

- Font duy nhất: Inter, không dùng display font.
- Cỡ chữ: title màn hình 22 px / 600, section title 16 px / 700, body 14–16 px,
  metadata 12–13 px, button 16 px / 600.
- Line-height body khoảng 1.4. Không dùng letter spacing âm.
- Spacing: 4, 8, 16, 24, 32, 48 px.
- Radius: input/button 12–14 px, card 16 px, chip/pill 20 px.
- Touch target tối thiểu 44 px. CTA chính cao khoảng 52 px và rộng toàn phần
  khi nằm trong form.
- Content padding mặc định 16 px; vùng an toàn theo notch và thanh điều hướng.
- Dùng icon nét bo đồng nhất, quen thuộc; ưu tiên Material Symbols hoặc Lucide.

## Điều hướng chính

App shell có bottom navigation cố định, 4 mục:

1. Trang chủ — icon home
2. Ca làm việc — icon work history
3. Lịch rảnh — icon calendar
4. Cài đặt — icon person/settings

Tab đang chọn dùng icon và label màu primary, indicator nhạt phía sau; tab chưa
chọn dùng text hint. Bottom bar nền trắng, có divider/shadow rất nhẹ, không che
nội dung khi bàn phím hoặc safe area xuất hiện.

## Luồng xác thực caregiver

### Màn hình nhập số điện thoại — /auth/phone

- App bar tối giản với logo/chữ CareSitter và nhãn Dành cho Caregiver.
- Heading: Chào mừng bạn trở lại.
- Supporting text: Đăng nhập để quản lý ca chăm sóc của bạn.
- Input số điện thoại với prefix +84, label Số điện thoại.
- CTA: Tiếp tục.
- Link phụ: Đăng nhập bằng mật khẩu nếu flow mật khẩu được bật.
- Có trạng thái loading trong CTA, validation số điện thoại và lỗi mạng.
- Không hiển thị hoặc cho phép chuyển sang tài khoản customer từ màn hình này.

### Màn hình OTP — /auth/otp

- Heading: Nhập mã xác thực.
- Copy: Mã xác thực đã được gửi đến {phone}, với số điện thoại được che một phần.
- 6 ô OTP cố định, tự chuyển focus, hỗ trợ paste mã.
- CTA: Xác nhận.
- Timer và action: Gửi lại mã.
- Error role-specific: Tài khoản này không có quyền đăng nhập ứng dụng Caregiver.
- Khi lỗi role, giữ người dùng ở auth flow, không lưu token, không chuyển vào app.

### Quy tắc phân quyền bắt buộc

- Mọi request login từ caregiver app phải gửi requiredRole: CAREGIVER.
- Response cần có danh sách role; app chỉ lưu session nếu có role CAREGIVER.
- Customer hoặc admin account phải nhận lỗi rõ ràng, không được vào Home.
- Khi mở app với session cũ không có role CAREGIVER, xóa session và đưa về
  /auth/phone.

## Màn hình Trang chủ — /home

Header cố định khi scroll:

- Nền xanh teal đậm, cao khoảng 148 px cộng safe area.
- Avatar initials, greeting Xin chào Caregiver, tên caregiver.
- Notification bell với badge số chưa đọc.
- Rating nhỏ: 4.9/5.0 Đánh giá.

Nội dung theo thứ tự:

1. Banner cảnh báo tài liệu: icon warning, Giấy khám sức khoẻ sắp hết hạn,
   Vui lòng cập nhật trong vòng 7 ngày tới., action Cập nhật.
2. Availability control: icon trạng thái, Sẵn sàng nhận việc hoặc Đang bận,
   mô tả ngắn và switch. Khi bật: Hệ thống sẽ gợi ý ca phù hợp.
3. New shift alert khi có ca phù hợp: chip Ca mới phù hợp, thời điểm, tên dịch
   vụ, khoảng cách, quận, ngày giờ, thời lượng. Actions Bỏ qua và Xem chi tiết.
4. Earnings summary: Thu nhập tháng này, số tiền lớn, số ca đã hoàn thành,
   phần trăm so với tháng trước, chevron để mở Thu nhập.
5. Upcoming shift: heading Ca làm việc sắp tới, action Tất cả, một shift card
   hoặc empty state Không có ca làm việc sắp tới và hướng dẫn bật nhận ca.

## Màn hình Ca làm việc — /shifts

- App bar: Ca làm việc, action lọc nếu cần.
- Có thể dùng segmented control hoặc tabs: Tất cả, Chờ phản hồi, Sắp tới,
  Đang diễn ra, Hoàn thành.
- Mỗi shift item hiển thị: tên người được chăm sóc, loại dịch vụ, ngày/giờ,
  thời lượng, địa chỉ rút gọn, thu nhập dự kiến và status badge.
- Status colors:
  - Chờ phản hồi = warning
  - Sắp tới = green
  - Đang diễn ra = primary
  - Hoàn thành = success
  - Đã huỷ = neutral gray
  - Khẩn cấp = error
- Loading dùng skeleton list. Empty state phải thay đổi theo filter và giải thích
  bước tiếp theo. Error state có Thử lại.

## Chi tiết ca và ca đang diễn ra

### Chi tiết ca — /shifts/:id

- App bar có back và title Chi tiết ca.
- Status badge nổi bật phía trên.
- Summary: người được chăm sóc, dịch vụ, ngày, giờ bắt đầu/kết thúc, thời lượng,
  địa chỉ đầy đủ, ghi chú của khách hàng, thu nhập caregiver.
- Map preview hoặc location row với action Xem bản đồ.
- Actions theo trạng thái:
  - Ca chờ: Nhận ca và Từ chối.
  - Ca đã nhận: Bắt đầu di chuyển.
  - Ca đang diễn ra: Mở ca đang diễn ra.
- Các action nguy hiểm cần confirmation bottom sheet rõ ràng.

### Bản đồ đường đi — /shifts/:id/map

- Map chiếm phần lớn viewport, marker caregiver và marker địa điểm.
- Bottom information panel có khoảng cách, ETA, địa chỉ và CTA
  Mở Google Maps chỉ đường.
- Không đặt text trực tiếp lên vùng bản đồ nếu khó đọc.

### Ca đang diễn ra — /shifts/:id/active

- Luôn hiển thị status, tên người được chăm sóc và đồng hồ/thời lượng ca.
- CTA check-in rõ ràng: Bắt đầu Check-in.
- Check-in yêu cầu vị trí; hiển thị GPS state Đang xác nhận vị trí, thành công
  hoặc lỗi với action thử lại.
- Checklist công việc dạng checkbox với progress, không dùng card lồng card.
- Evidence section: Chụp ảnh minh chứng, Thư viện, số ảnh đã thêm.
- Note field cho caregiver.
- CTA cuối: Hoàn thành ca & Check-out.
- Action khẩn cấp: Gửi báo cáo khẩn cấp dùng màu error và confirmation.

### Tổng kết ca — /shifts/:id/summary

- Confirmation state sau checkout.
- Tóm tắt: khách hàng, thời gian chăm sóc, checklist hoàn thành, thu nhập nhận
  được, ảnh minh chứng và ghi chú.
- CTA Xem báo cáo khách hàng, secondary Trở về Trang chủ.

## Lịch rảnh — /schedule

- Calendar theo tuần/tháng với ngày đang chọn nổi bật bằng primary.
- Cho phép bật/tắt các khung giờ có thể nhận ca.
- Hiển thị rõ unavailable, booked và available bằng label + màu, không chỉ dựa
  vào màu sắc.
- Save action có loading, success feedback và lỗi lưu.

## Thu nhập — /earnings

- Tổng thu nhập hiện tại và tháng này ở đầu màn hình.
- Danh sách payout/ca đã hoàn thành có ngày, dịch vụ, trạng thái và số tiền.
- CTA Rút tiền; form rút tiền có số dư khả dụng, phương thức nhận tiền,
  validation và confirmation.

## Cài đặt và hồ sơ

Màn hình Cài đặt gồm các row rõ ràng, icon + label + chevron:

- Hồ sơ cá nhân
- Hồ sơ và giấy tờ
- Đánh giá của tôi
- Thu nhập và thanh toán
- Câu hỏi thường gặp
- Trung tâm trợ giúp
- Đăng xuất

Hồ sơ/giấy tờ cần có progress hoặc status: Đã xác minh, Đang chờ duyệt,
Cần cập nhật. Upload document hỗ trợ camera và thư viện, preview, retry và
confirmation trước khi gửi duyệt.

## Component states bắt buộc

Mọi component tương tác phải có default, pressed/active, focus, disabled,
loading và error. Tối thiểu cần thể hiện:

- Button: primary, secondary/outlined, destructive, loading, disabled.
- Input: empty, focused, valid, invalid, disabled.
- Switch: on/off/disabled/loading.
- Shift card: pending/confirmed/in-progress/completed/cancelled/empty.
- Network: skeleton, retry error, offline hint.
- Permission: location denied, camera denied, notification denied.
- Session: unauthorized, wrong role, expired token, logout confirmation.

## Responsive và accessibility

- Tối ưu viewport điện thoại rộng 360–430 px; không để heading, label hoặc button
  tràn ngang.
- Với màn hình lớn hơn, giữ content max-width khoảng 480 px và căn giữa, không
  kéo các form thành dòng quá dài.
- Hỗ trợ dynamic text size; mọi label vẫn đọc được khi tăng cỡ chữ.
- Contrast đạt WCAG AA; không dùng màu làm tín hiệu duy nhất.
- Icon button có tooltip/semantic label; vùng chạm ít nhất 44 px.
- Dùng safe area cho notch, bàn phím và bottom navigation.
- Tôn trọng prefers-reduced-motion; animation chỉ 150–250 ms để phản hồi trạng thái.

## Ưu tiên prototype trong Stitch

Nếu chỉ dựng một flow hoàn chỉnh đầu tiên, hãy tạo theo thứ tự:

1. Phone login → OTP → wrong-role error → Home.
2. Home với warning tài liệu, availability switch, new shift alert và upcoming shift.
3. Shift list → Shift detail → Map → Active shift → Summary.
4. Bottom navigation với Schedule và Settings ở trạng thái có thể truy cập.

Prototype cần có dữ liệu mẫu thực tế:

- Caregiver: Nguyễn Minh Anh, rating 4.9/5.0.
- Dịch vụ: Chăm sóc người cao tuổi tại nhà.
- Ca mẫu: 08:00–12:00, Q. Bình Thạnh, 2.5 km, thu nhập 290.000 đ.
- Tài liệu cảnh báo: Giấy khám sức khoẻ sắp hết hạn.

Mục tiêu cuối: caregiver mở app là biết trạng thái sẵn sàng, ca tiếp theo, số
tiền có thể nhận và hành động kế tiếp; customer account không bao giờ được vào
giao diện caregiver.

