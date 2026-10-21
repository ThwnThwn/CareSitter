# Báo cáo tổng thể chức năng dự án CareSitter

**Ngày cập nhật:** 15/10/2026, múi giờ Asia/Saigon.
**Nguồn rà soát:** working tree `D:\EXE\CareSitter`, nhánh `develop`, gồm cả code
Kafka và cấu hình local chưa commit. Commit nền: `2fb0bcb`.

Kiến trúc tổng thể được trình bày trong [ARCHITECTURE.md](ARCHITECTURE.md).
Báo cáo này tổng hợp chức năng có trong source, mức độ kết nối giữa các lớp
và những phần còn thiếu. Đây là kết quả rà soát source/cấu hình, không phải
biên bản nghiệm thu toàn bộ chức năng trên thiết bị hoặc production.

Chat hỗ trợ trực tuyến đã có
[kế hoạch thực thi riêng](../backend/SUPPORT_CHAT_IMPLEMENTATION_PLAN.md);
hiện vẫn chưa có code chat.
Chat Customer ↔ Caregiver theo từng booking cũng đã có
[kế hoạch riêng](../backend/BOOKING_PARTY_CHAT_IMPLEMENTATION_PLAN.md), gồm tin
nhắn nhanh “Tôi sắp tới”, nhưng chưa được triển khai.
Khôi phục mật khẩu đã có API và giao diện trên hai app; xem
[phạm vi, cấu hình và kiểm thử](../backend/PASSWORD_RECOVERY.md).
Migration 35 đã áp dụng ở local; SMTP thật và thiết bị Android/iOS chưa
được nghiệm thu trong lượt triển khai này.

## 1. Cách đọc trạng thái

| Trạng thái | Ý nghĩa trong báo cáo |
| --- | --- |
| **Đã có** | Có mã xử lý nghiệp vụ/API và giao diện hoặc điểm gọi tương ứng được tìm thấy trong phạm vi mô tả |
| **Có một phần** | Đã có một số lớp, giao diện, adapter hoặc nghiệp vụ nhưng thiếu bước để hoàn thành toàn bộ luồng |
| **Chưa có** | Chưa tìm thấy triển khai tương ứng trong source hiện tại; có thể mới nằm trong kế hoạch |
| **Chưa xác nhận** | Có cấu hình/mã nguồn nhưng chưa có đủ bằng chứng về môi trường thực tế hoặc nghiệm thu đầu cuối |

Chức năng **đã có** có thể vẫn cần bật cấu hình, thông tin xác thực hoặc
kiểm thử trên môi trường chạy. Các trạng thái này không được quy đổi thành
một phần trăm hoàn thành vì chưa có danh sách yêu cầu và tiêu chí nghiệm
thu đầy đủ để tính tỷ lệ.

## 2. Quy mô và phạm vi hiện tại

| Thành phần | Phạm vi đã có |
| --- | --- |
| Customer app | Flutter: tài khoản, người thân, caregiver, dịch vụ, booking, thanh toán, theo dõi, đánh giá, tranh chấp và ví |
| Caregiver app | Flutter: hồ sơ/KYC, nhận ca, lịch ca, chăm sóc, tracking, thu nhập, yêu cầu rút tiền và hỗ trợ |
| Admin web | React: dashboard, tài khoản, KYC, booking, dịch vụ/checklist, thanh toán/payout, tranh chấp và ticket |
| Landing page | Next.js: giới thiệu, giao diện đặt nhanh và trợ lý gợi ý dịch vụ bằng AI |
| Backend | ASP.NET Core modular monolith với 7 module: Identity, People, Catalog, Booking, Payments, Support, Promotion |
| Messaging | Thư viện Kafka dùng chung và NotificationWorker chạy riêng đã có source |

Luồng cốt lõi đã có mã xử lý: chọn người thân và dịch vụ → tạo booking
→ thanh toán VNPAY/payOS → xác nhận/ghép caregiver → nhận ca → check-in
→ checklist/timeline → yêu cầu checkout → xác nhận hoàn tất
→ ghi nhận tài chính nội bộ → đánh giá hoặc mở tranh chấp.

Hoàn tiền về ngân hàng và chuyển tiền ra ngân hàng cần được đọc riêng ở
phần chức năng chưa hoàn chỉnh; số dư và ledger nội bộ chưa chứng minh
nhà cung cấp đã thực hiện giao dịch tiền thật.

## 3. Chức năng đã có theo module backend

| Module | Nhóm chức năng tìm thấy | Giới hạn cần biết |
| --- | --- | --- |
| Identity | Đăng ký, OTP email, mật khẩu, Google, access/refresh token, logout, khôi phục mật khẩu, xác minh/đổi email, profile/avatar, thiết bị FCM, tùy chọn thông báo, quản lý user/role và audit | OTP hiện gửi email; chưa có SMS gateway. Luồng Google trên UI caregiver chưa được tìm thấy; tài khoản có ADMIN/bị khóa/mất email cần quy trình riêng |
| People | CRUD người thân và liên hệ gia đình; tìm caregiver; hồ sơ, kỹ năng, khu vực, trạng thái online; nộp/duyệt/từ chối KYC | Quản lý liên hệ đầy đủ và lịch rảnh caregiver còn chưa đồng đều trên UI |
| Catalog | Dịch vụ, báo giá, quy tắc giá, địa chỉ, autocomplete/chi tiết địa điểm và media | Cần cấu hình provider bản đồ/media; không suy giá từ nội dung landing page |
| Booking | Tạo/xem/sync ca, hủy/dời lịch/chọn caregiver, matching/offer, nhận/từ chối, di chuyển, check-in/selfie, checklist/ảnh, timeline/GPS, checkout/hoàn tất và SOS | Hủy booking chưa nối tự hoàn tiền về VNPAY; GPS trực tiếp local đang tắt cờ |
| Payments | Intent VNPAY/payOS, chọn cổng trên app, IPN/return/webhook có chữ ký, chống tạo/ghi nhận lặp, đối soát tự động/thủ công, escrow/ledger, ví, yêu cầu và duyệt/từ chối payout, outbox MediatR, producer Kafka tùy chọn | Refund provider và chi hộ chưa hoàn thành luồng đầu cuối |
| Support | Inbox thông báo, đọc/đếm chưa đọc, review, ticket, phân công/trạng thái, tranh chấp và quyết định, endpoint claim/complete thông báo | Chat hỗ trợ trực tuyến chưa có; quyết định hoàn tiền nội bộ chưa đồng nghĩa refund provider |
| Promotion | Danh sách/chi tiết/preview, kiểm điều kiện, reserve/redeem/release theo booking; API và UI admin CRUD, bật/tắt, phạm vi dịch vụ, giới hạn lượt, thống kê sử dụng và audit | Đã hoàn thiện CRUD admin ngày 06/10/2026; chỉ xóa chiến dịch chưa có lịch sử, chiến dịch đã dùng được tắt để giữ dữ liệu |

## 4. Chức năng dành cho Customer

Nguồn chính: [router customer](../../frontend/customer-app/lib/core/router/app_router.dart),
[các feature customer](../../frontend/customer-app/lib/features),
[controller backend](../../backend/caresitter-be/Modules).

| Chức năng | Trạng thái | Phạm vi thực tế |
| --- | --- | --- |
| Đăng ký và đăng nhập bằng mật khẩu | Đã có | Có màn hình, repository và handler backend |
| Đăng nhập bằng OTP email | Đã có | Backend gửi email, lưu OTP trong Redis; route phone cũ chuyển sang email |
| Đăng nhập Google | Đã có | Có gateway web/native và backend kiểm tra ID token |
| Logout và làm mới phiên | Đã có | Có access/refresh token và cơ chế xử lý phiên |
| Sửa hồ sơ, avatar và mật khẩu hiện tại | Đã có | Có màn hình và API tương ứng |
| Quản lý người được chăm sóc | Đã có | Tạo, xem, sửa, xóa; lưu ghi chú, lưu ý chăm sóc và các trường sức khỏe do người dùng cung cấp |
| Liên hệ gia đình/khẩn cấp | Có một phần | Backend có CRUD; app có lấy danh sách và lưu liên hệ khi tạo người thân, chưa thấy UI quản lý sửa/xóa đầy đủ |
| Quản lý địa chỉ đã lưu | Đã có | Lưu/sửa/xóa/chọn địa chỉ; tìm địa điểm qua provider bản đồ |
| Danh mục và báo giá dịch vụ | Đã có | Lấy dữ liệu từ Catalog và API quote |
| Tìm/xem caregiver | Đã có | Hồ sơ đã duyệt, bộ lọc và các thông tin kỹ năng/rating/khu vực |
| Đặt ca chăm sóc | Đã có | Wizard chọn người thân, địa chỉ, dịch vụ, thời gian và caregiver theo luồng đang có |
| Áp dụng mã ưu đãi | Đã có | Backend preview/reserve/redeem/release gắn với booking |
| Thanh toán booking qua VNPAY | Đã có | Tạo intent, mở URL thanh toán, xử lý kết quả và trạng thái đối soát |
| Thanh toán booking qua payOS | Đã có code; chưa bật tiền thật | Chọn cổng, VietQR/chuyển khoản, webhook có chữ ký, truy vấn trạng thái, ledger/booking và đối soát; còn thiếu kênh payOS, khóa và backend HTTPS |
| Chống bấm thanh toán lặp khi loading | Đã có | Khóa nút trên app, một intent đang mở trên mỗi booking dùng chung cho các cổng, tái sử dụng mã đơn và ghi ledger/webhook một lần; tiền chuyển thêm từ ngân hàng cần đối soát |
| Xem danh sách/chi tiết và đồng bộ booking | Đã có | REST, delta sync và tín hiệu SignalR |
| Hủy hoặc dời lịch | Đã có | Có API/UI theo quyền và trạng thái; không bao gồm hoàn tiền provider tự động |
| Chọn caregiver và xem gợi ý | Đã có | Backend kiểm lịch/phân công và có cơ chế matching |
| Theo dõi trạng thái, timeline và checklist | Đã có | Có giao diện, dữ liệu backend, ảnh minh chứng và cập nhật trực tiếp |
| Theo dõi vị trí caregiver đang di chuyển | Có một phần | Có mã API, app, SignalR và test; local đang `LiveTracking__Enabled=false`, chưa nghiệm thu thiết bị thật |
| Xác nhận hoàn tất sau yêu cầu checkout | Đã có | Customer/admin có quyền complete; caregiver yêu cầu checkout |
| Đánh giá caregiver | Đã có | Có API và màn hình gửi đánh giá sau ca theo điều kiện backend |
| Tạo/xem tranh chấp | Đã có | Có UI, API và luồng xử lý admin |
| Kích hoạt SOS | Có một phần | Có nghiệp vụ ghi nhận và tạo cảnh báo/ticket; chưa có quy trình điều phối ứng cứu đã nghiệm thu |
| Xem ví và lịch sử giao dịch | Đã có | App đọc số dư và giao dịch từ Payments |
| Nạp tiền/rút tiền customer hoặc thanh toán bằng số dư ví | Chưa có | Chưa thấy luồng API/UI đầu cuối tương ứng; ví customer hiện phục vụ xem số dư/giao dịch |
| Inbox thông báo và đánh dấu đã đọc | Đã có | Danh sách, số chưa đọc, đọc từng thông báo hoặc tất cả |
| Tùy chọn nhận thông báo và FAQ | Đã có | Có màn hình, API preferences và nội dung FAQ |
| Liên hệ hỗ trợ qua điện thoại/email | Đã có | UI mở ứng dụng gọi điện/email; đây không phải ticket đã lưu trong hệ thống |
| Tạo/quản lý ticket trực tiếp trên customer app | Có một phần | Backend có ticket API; màn hình hỗ trợ customer hiện chủ yếu mở các kênh liên hệ |
| Chat hỗ trợ trực tuyến | Chưa có | Nút chat hiện hiển thị thông báo tính năng đang phát triển |
| Chat Customer ↔ Caregiver theo booking | Chưa có | Nút Nhắn tin ở chi tiết lịch hiện là placeholder; đã có kế hoạch lifecycle, quick message, realtime và phục hồi riêng |
| Quên mật khẩu và tự khôi phục quyền đăng nhập | Đã có | Email đã xác minh → mã riêng → mật khẩu mới; thu hồi mọi phiên cũ, vô hiệu OTP cũ. Không tự mở khóa/khôi phục tài khoản bị xóa |
| Xác minh/đổi email khôi phục | Đã có | Mục Email khôi phục; đổi email cần mật khẩu hiện tại và mã email mới; tài khoản chỉ Google/OTP chưa có luồng tự đổi email |

## 5. Chức năng dành cho Caregiver

Nguồn chính: [router caregiver](../../frontend/caregiver-app/lib/core/router/app_router.dart),
[các feature caregiver](../../frontend/caregiver-app/lib/features),
[People](../../backend/caresitter-be/Modules/People),
[Booking](../../backend/caresitter-be/Modules/Booking).

| Chức năng | Trạng thái | Phạm vi thực tế |
| --- | --- | --- |
| Đăng ký, đăng nhập mật khẩu/OTP và quản lý phiên | Đã có | Có màn hình, repository và backend; OTP gửi email |
| Quên mật khẩu và email khôi phục | Đã có | Nút Quên mật khẩu nối 3 bước; cài đặt xác minh/đổi email, API và thu hồi phiên dùng chung với customer |
| Đăng nhập Google trên caregiver app | Có một phần | Backend có `/api/v1/auth/google/caregiver`; chưa thấy nút/luồng Google tương ứng trong app đã rà soát |
| Tạo/sửa hồ sơ caregiver | Đã có | Thông tin cá nhân, kinh nghiệm, kỹ năng và khu vực phục vụ |
| Nộp CCCD/chứng chỉ và xem trạng thái KYC | Đã có | Upload media ID, submit và xem duyệt/từ chối |
| Bật/tắt trạng thái nhận việc | Đã có | Backend hỗ trợ ONLINE/OFFLINE/BUSY và kiểm tra điều kiện nhận ca |
| Xem ca mở, ca được mời và ca của mình | Đã có | App lấy danh sách từ Booking |
| Nhận hoặc từ chối ca | Đã có | Kiểm tra phân công, trạng thái, KYC và lịch; có cơ chế chống nhận trùng |
| Xem lịch ca | Đã có | Màn hình schedule hiển thị ca đang có |
| Đăng ký lịch rảnh lặp lại theo tuần | Chưa có | Chưa thấy luồng quản lý lịch rảnh định kỳ riêng; không đồng nghĩa màn hình lịch ca đã có chức năng này |
| Bắt đầu di chuyển và mở bản đồ | Đã có | Có trạng thái EN_ROUTE và màn hình bản đồ |
| Gửi vị trí trực tiếp khi đang mở app | Có một phần | Có phiên gửi, lease, kiểm thời gian/tần suất; luồng đang tắt ở local và chưa nghiệm thu thiết bị thực |
| Gửi vị trí khi khóa màn hình/chạy nền Android/iOS | Chưa có | Chưa triển khai theo tài liệu và mã luồng live tracking |
| Check-in GPS và selfie | Đã có | Backend kiểm geofence và lưu minh chứng theo luồng hiện tại |
| Làm checklist, đánh dấu xong/bỏ qua | Đã có | Có task mẫu, task phát sinh theo policy và kiểm tra thao tác |
| Gửi ảnh minh chứng công việc | Đã có | Upload và gắn ảnh vào care task |
| Ghi chú và timeline chăm sóc | Đã có | API ghi nhận sự kiện/ghi chú, app theo dõi ca |
| Báo cáo/tóm tắt sau ca | Có một phần | Có màn hình summary/customer report và dữ liệu ca; chưa có hệ thống báo cáo nghiệp vụ/export riêng đầy đủ |
| Yêu cầu checkout | Đã có | Caregiver gửi yêu cầu, chờ customer/admin hoặc tác vụ hệ thống xử lý |
| Xem thu nhập và số dư khả dụng | Đã có | App đọc dữ liệu ví/ca từ backend |
| Tạo yêu cầu rút tiền | Đã có | Gửi tài khoản ngân hàng, số tiền và idempotency key vào API payouts |
| Nhận tiền thực tế qua VNPAY chi hộ | Chưa có | Chưa có adapter/hợp đồng API chi hộ và vòng xác nhận chuyển tiền |
| Xem thông báo, đánh giá và chỉnh hồ sơ | Đã có | Có màn hình và điểm gọi API |
| Gửi ticket hỗ trợ | Đã có | App caregiver gửi yêu cầu vào backend và nhận mã ticket |

## 6. Chức năng dành cho Admin

Nguồn chính: [các trang admin](../../frontend/admin-web/src/pages),
[đăng nhập và điều hướng](../../frontend/admin-web/src/main.tsx).

| Chức năng | Trạng thái | Phạm vi thực tế |
| --- | --- | --- |
| Đăng nhập admin và kiểm quyền | Đã có | Mật khẩu, JWT, kiểm role ADMIN và xử lý lỗi phiên |
| Dashboard | Đã có | Có trang dashboard và API tổng hợp dữ liệu vận hành |
| Danh sách/chi tiết tài khoản | Đã có | Tìm/lọc, trạng thái tài khoản và vai trò |
| Thay đổi trạng thái và vai trò user | Đã có | Có API và UI quản lý tương ứng |
| Xem, duyệt hoặc từ chối KYC | Đã có | Có API/UI; đọc media riêng qua backend |
| Xem/lọc/tra cứu booking | Đã có | Trang danh sách và dữ liệu chi tiết phục vụ vận hành |
| Xác nhận hoàn tất ca | Đã có ở API | Endpoint complete cho CUSTOMER/ADMIN; cần phân biệt với quyền hủy/dời lịch của customer |
| Quản lý dịch vụ và quy tắc giá | Đã có | Tạo/sửa/bật tắt dịch vụ và pricing rule |
| Quản lý checklist mẫu và policy task | Đã có | Tạo/sửa/xóa/bật tắt template, điều chỉnh quyền thêm task phát sinh |
| Xem giao dịch, ledger và hàng đợi đối soát | Đã có | Có API và màn hình Payments |
| Quyết định đối soát thủ công | Đã có | Admin xác nhận/từ chối theo dữ liệu và lý do đối chiếu |
| Duyệt/từ chối yêu cầu rút tiền | Có một phần | Đã có workflow nội bộ; approve hiện chưa dựa trên kết quả chuyển tiền provider |
| Giải quyết tranh chấp | Đã có | Xem chi tiết, quyết định và xử lý tác động nghiệp vụ nội bộ |
| Quản lý ticket hỗ trợ | Đã có | Danh sách/chi tiết, cập nhật trạng thái và phân công |
| Quản lý chiến dịch ưu đãi | Đã có | Trang Ưu đãi và API admin: tìm kiếm/phân trang/lọc, tạo/xem/sửa/bật tắt/xóa; nội dung preview, điều khoản, thời gian, mức giảm, phạm vi dịch vụ, giới hạn lượt và thống kê sử dụng |
| Phân quyền admin chi tiết theo bộ phận | Có một phần | Có role ADMIN; chưa thấy mô hình quyền chi tiết theo thao tác/nhóm vận hành hoàn chỉnh |
| Xuất báo cáo CSV/PDF, BI chuyên sâu | Chưa có | Chưa thấy chức năng xuất và hệ thống phân tích tổng hợp tương ứng |

## 7. Landing page và trợ lý AI

Nguồn chính: [landing page](../../frontend/landing-page/src),
[QuickBookModal](../../frontend/landing-page/src/components/QuickBookModal.tsx),
[API care-assistant](../../frontend/landing-page/src/app/api/care-assistant/route.ts).

| Chức năng | Trạng thái | Phạm vi thực tế |
| --- | --- | --- |
| Giới thiệu CareSitter và dịch vụ | Đã có | Có trang, component và nội dung marketing |
| Hiển thị caregiver/nội dung giới thiệu | Đã có ở giao diện | Không mặc định dữ liệu marketing là danh sách caregiver đã đồng bộ backend |
| Giao diện đặt nhanh | Có một phần | Có chọn loại hỗ trợ, ngày, số giờ và trạng thái thành công trên UI |
| Tạo booking/lead thật từ form đặt nhanh | Chưa có | `handleSubmit` chỉ gọi `setBookingSuccess(true)`, không gọi API lưu booking hoặc lead |
| Báo giá thật tại form đặt nhanh | Có một phần | UI tính `hours * 120_000`; chưa dùng quote/pricing backend |
| Trợ lý AI gợi ý loại hỗ trợ và số giờ | Đã có mã tích hợp | Next.js gọi OpenAI Responses API, trả JSON có schema, cần `OPENAI_API_KEY` |
| AI tự xác nhận booking hoặc chọn caregiver thật | Chưa có | Trợ lý không được nối vào thao tác nghiệp vụ này |
| AI dinh dưỡng theo hồ sơ người thân | Chưa có | Trợ lý landing chỉ gợi ý loại hỗ trợ; Nutrition là tính năng riêng chưa triển khai |

## 8. Nền tảng kỹ thuật và cấu hình đang có

| Nhóm | Trạng thái | Bằng chứng/phạm vi |
| --- | --- | --- |
| PostgreSQL/PostGIS và schema theo module | Đã có | DbContext, mapping và SQL có đánh số |
| Migration SQL | Đã có | Có runner local/triển khai; hiện tới migration 35 |
| Redis cho OTP/phiên/cache | Đã có | Có adapter và Compose local |
| SignalR và delta sync | Đã có | Hub, sự kiện trạng thái/timeline/GPS và logic phục hồi client |
| Hangfire và các tác vụ nền | Đã có | Đối soát, checkout, matching, cảnh báo và cleanup |
| Kafka generic | Đã có | Contracts/Abstractions/transport/persistence, producer, consumer, outbox/inbox, retry, DLQ, health và retention |
| Broker Kafka local | Đã có và đang chạy | Container healthy, 6 topic, kết nối Windows và restart đã được kiểm tra |
| Luồng thông báo Kafka/NotificationWorker | Đã có mã, local chưa bật | Có API claim/complete và worker; cờ thông báo đang false |
| PaymentSucceeded qua Kafka | Đã có producer | Có outbox riêng và relay; cờ Payments local đang false, Booking vẫn dùng MediatR hiện có |
| MealPlanSelected qua Kafka | Có một phần | Có contract/topic; chưa có nghiệp vụ phát/nhận sự kiện Nutrition |
| JWT, role, ownership, rate limit và audit | Đã có | Có code và các test liên quan; quyền production cần nghiệm thu theo môi trường |
| Upload media và KYC riêng tư | Đã có mã | Có media ID, read ticket và proxy; provider/URL legacy còn hạng mục mở |
| Container hóa API, worker và admin | Đã có | Có Dockerfile và manifest Compose |
| CI backend/Flutter/admin | Đã có cấu hình | Workflow push/PR main/develop, kiểm tra và build; chưa xác nhận run remote của toàn bộ code local mới |
| Triển khai tự động và nghiệm thu production | Chưa xác nhận | Workflow CI hiện không có job deploy; cần nghiệm thu bản phát hành cụ thể |

## 9. Các chức năng mới có một phần

### 9.1 Hoàn tiền về phương thức thanh toán gốc

**Đã có:** adapter `VNPayRefundGateway`, contract/options cho refund/query
và kiểm tra kết quả nhà cung cấp.

**Còn thiếu:** yêu cầu refund bền vững trong transaction hủy, khóa nghiệp
vụ chống trùng, worker có lease/phục hồi, đối soát trạng thái không chắc
chắn, cập nhật ledger sau xác nhận và trạng thái tương ứng trên app/admin.
Handler `CancelBooking` hiện chuyển trạng thái, giải phóng slot/ưu đãi và
gửi cập nhật; chưa gọi workflow hoàn tiền về VNPAY.

Hoàn vào ví nội bộ cho một số ca không ghép được hoặc quyết định tranh
chấp là luồng khác với hoàn về phương thức thanh toán gốc.

Nguồn: [VNPayRefundGateway](../../backend/caresitter-be/Modules/Payments/Infrastructure/VNPayRefundGateway.cs),
[CancelBookingCommandHandler](../../backend/caresitter-be/Modules/Booking/Application/Commands/Bookings/CancelBooking/CancelBookingCommandHandler.cs),
[tiến độ FIN01](../backend/PRODUCTION_PROGRESS.md).

### 9.2 Chi tiền thật cho caregiver

**Đã có:** caregiver tạo yêu cầu; backend quản lý số dư, idempotency,
trạng thái; admin duyệt/từ chối; có API và màn hình payout.

**Còn thiếu:** tích hợp VNPAY chi hộ, mã giao dịch provider, query/callback,
xác thực, đối soát và xử lý trạng thái chưa rõ kết quả.
Trong `PayoutStore.ApproveAsync`, thao tác duyệt hiện tạo ledger `PAYOUT`,
đánh dấu posted và giảm pending balance trong transaction nội bộ,
không có lời gọi chuyển tiền provider. Vì vậy, trạng thái duyệt nội bộ
chưa chứng minh tiền đã tới tài khoản ngân hàng.

Nguồn: [PayoutStore](../../backend/caresitter-be/Modules/Payments/Infrastructure/PayoutStore.cs),
[tiến độ FIN02](../backend/PRODUCTION_PROGRESS.md).

### 9.3 Kafka đã có nền tảng, chưa bật các luồng trên local

**Đã có:** thư viện generic, outbox/inbox, relay, retry, DLQ, broker local,
luồng NotificationRequested, producer PaymentSucceeded và worker riêng.

**Còn thiếu ở cấu hình local hiện tại:** chạy NotificationWorker và bật
cờ của luồng cần dùng. FCM/SMTP thật cần thông tin xác thực và kiểm tra
gửi thực tế; các test provider đã lưu dùng bộ gửi giả lập.

| Biến local đã kiểm tra | Giá trị |
| --- | --- |
| `KAFKA_ENABLED` | `true` |
| `KAFKA_BOOTSTRAP_SERVERS` | `localhost:9092` |
| `KAFKA_FLOW_NOTIFICATIONS_ENABLED` | `false` |
| `KAFKA_FLOW_PAYMENTS_ENABLED` | `false` |
| `KAFKA_FLOW_NUTRITION_ENABLED` | `false` |

Nguồn: [Kafka local](../backend/KAFKA_LOCAL.md),
[kiến trúc messaging](../docs/architecture/adr-kafka-messaging.md).

### 9.4 Theo dõi vị trí trực tiếp

**Đã có:** vị trí gần nhất cho mỗi ca, session/lease một thiết bị gửi,
kiểm thời gian/tần suất, phân quyền, cập nhật SignalR, REST phục hồi và cleanup.

**Còn thiếu:** bật cờ trên môi trường cần dùng và nghiệm thu GPS ngoài
đường, quyền thiết bị, pin, độ trễ đầu cuối. Android/iOS chạy nền chưa
triển khai. Local hiện có `LiveTracking__Enabled=false`.

Nguồn: [LIVE_TRACKING.md](../backend/docs/LIVE_TRACKING.md).

### 9.5 KYC riêng tư và dữ liệu legacy

**Đã có:** luồng mới dùng media ID, upload có quyền, đọc qua ticket có
thời hạn và proxy backend, kiểm quyền khi submit/approve.

**Còn thiếu:** kiểm chứng provider thực tế, kiểm kê/chuyển đổi/thu hồi URL
công khai cũ, vòng đời dữ liệu và quyền trên môi trường triển khai.
Các ảnh nhạy cảm ngoài KYC còn cần được rà soát riêng.

Nguồn: [SEC01_PLAN.md](../backend/SEC01_PLAN.md),
[tiến độ SEC01](../backend/PRODUCTION_PROGRESS.md).

### 9.6 Landing page và các giao diện chưa nối đủ nghiệp vụ

- Form đặt nhanh có giao diện nhưng chưa lưu booking/lead và chưa lấy báo
  giá từ backend.
- Customer có liên hệ gia đình ở backend và thao tác lưu/tái sử dụng trong
  form người thân; cần UI sửa/xóa đầy đủ để quản lý toàn bộ danh bạ.
- Customer có màn hình hỗ trợ nhưng chưa có luồng tạo/theo dõi ticket
  tương đương màn hình caregiver.
- API Google cho caregiver đã có; UI caregiver chưa có luồng tương ứng
  trong phạm vi đã rà soát.
- Promotion đã có màn hình admin quản lý chiến dịch ngày 06/10/2026.
  Quyền ADMIN được kiểm tra ở API. Các điều kiện tính tiền được khóa khi
  đã có lịch sử giữ/sử dụng; việc tắt vẫn cho phép xử lý lượt giữ hiện có.

## 10. Danh mục chức năng chưa có

Danh sách dưới đây là các khoảng trống được nhận diện từ mã nguồn và
kế hoạch đang có. Không phải mọi mục đều bắt buộc nằm trong một phiên bản MVP.

| Chức năng/luồng | Phần hiện có liên quan | Phần chưa có |
| --- | --- | --- |
| Nutrition thực tế | Kế hoạch, hồ sơ người thân, DTO MealPlanSelected, topic | Dịch vụ/module, DbContext, dữ liệu công thức/quy tắc, phân tích, gợi ý, chọn và lưu thực đơn |
| gRPC cho Nutrition | Có trong đề xuất kiến trúc | File `.proto`, server/client và tích hợp runtime |
| Refund tự động khi customer hủy trước ca | Adapter provider và thao tác hủy | Workflow bền vững, worker, đối soát, trạng thái đầu cuối |
| Chi hộ caregiver qua VNPAY | Yêu cầu payout và duyệt nội bộ | Adapter chuyển tiền, callback/query và xác nhận kết quả |
| Form landing lưu booking/lead | Modal và trạng thái UI | Endpoint tích hợp và lưu dữ liệu thực tế |
| Chat hỗ trợ trực tuyến | Nút chat/placeholder customer | Hội thoại Customer/Caregiver ↔ Admin, gửi/nhận tin, lịch sử và giao diện nhân viên hỗ trợ |
| Chat Customer ↔ Caregiver theo booking | Nút Nhắn tin ở chi tiết booking, booking realtime và preference `chatMessage` | Hội thoại gắn booking, quick message, lịch sử, unread, phân quyền theo caregiver hiện tại và UI hai app |
| SMS OTP | OTP email | Nhà cung cấp SMS và adapter gửi/xác nhận |
| Khôi phục ngoài phạm vi email đã xác minh | Đã có reset mật khẩu cho CUSTOMER/CAREGIVER ACTIVE, có mật khẩu | Mất email/nghi bị chiếm, self-service ADMIN/MFA, mở khóa/khôi phục tài khoản đã xóa và tự đổi email cho user chỉ Google/OTP |
| Đặt ca lặp lại/gói định kỳ | Booking theo từng khoảng thời gian | Mô hình lịch lặp và điều phối chuỗi booking |
| Lịch rảnh định kỳ của caregiver | Trạng thái online và lịch ca đã có | Quản lý khung giờ rảnh lặp lại riêng |
| GPS nền Android/iOS | Sender khi app đang mở | Dịch vụ nền và xử lý vòng đời thiết bị tương ứng |
| Ví customer dùng để nạp/rút/thanh toán | Xem số dư/lịch sử, credit nội bộ | Luồng giao dịch đầu cuối và UI thao tác tương ứng |
| Xuất báo cáo CSV/PDF và BI | Dashboard/danh sách/summary | Export và mô hình phân tích chuyên sâu |
| Quy trình xóa tài khoản và dữ liệu liên quan | Cập nhật/khóa tài khoản, một số xóa mềm dữ liệu nghiệp vụ | Luồng yêu cầu, kiểm tra, xử lý dữ liệu/media/token và kết quả đầu cuối |
| SignalR nhiều API instance | Hub và cache Redis | Backplane/fanout và nghiệm thu phân tán |

## 11. Các nội dung chưa đủ bằng chứng nghiệm thu

Đây là các nội dung cần xác minh theo môi trường chạy, tách khỏi việc
có hay chưa có code:

| Nội dung | Điều cần xác minh |
| --- | --- |
| VNPAY thanh toán/refund/chi hộ thực tế | Quyền merchant, sandbox, callback/query và đối soát đúng luồng |
| FCM và SMTP thật | Thông tin xác thực, việc gửi/nhận thực tế và xử lý lỗi provider |
| Cloudinary KYC | Truy cập bản gốc/biến thể, hết hạn, quyền đọc và thu hồi legacy |
| App trên thiết bị thật | Đăng nhập, thanh toán, quyền GPS/camera, reconnect và vòng đời ứng dụng |
| Hiệu năng đầu cuối | API, mạng, SignalR, DB và tải đồng thời đúng phạm vi sử dụng |
| Backup/restore và rollback | Bản sao lưu, phục hồi thử, dung lượng, kịch bản rollback và RPO/RTO |
| Giám sát vận hành | Thu thập chỉ số/log, cảnh báo và quy trình xử lý lỗi |
| CI của code local mới | Run tương ứng với commit chứa đúng các thay đổi; chưa xác nhận trong đợt tài liệu này |
| Bản production/pilot | Cấu hình, quyền dữ liệu, policy tài chính, quy trình SOS và bằng chứng nghiệm thu cụ thể |

## 12. Bằng chứng kỹ thuật đã được đối chiếu

- Có 11 project test backend; có bộ test Flutter cho hai app và Vitest cho admin.
- Báo cáo `messaging.trx` được lưu ngày 05/10/2026 ghi nhận 22/22 test
  messaging pass, gồm Kafka/PostgreSQL thật; provider gửi thông báo dùng giả lập.
- Lượt cấu hình local ngày 06/10/2026 đã kiểm tra broker healthy, 6 topic,
  kết nối Confluent từ Windows và giữ nguyên topic sau restart.
- Migration 34 đã áp dụng vào DB local; DB và Redis đang healthy ở thời
  điểm kiểm tra.
- Lượt hoàn thiện Promotion admin ngày 06/10/2026: 25 test unit Promotion,
  32 test integration được chọn (gồm 6 test CRUD/quyền/đồng thời mới và
  các kiểm tra hồi quy), 30 test kiến trúc đều đạt; không có test bị bỏ qua.
- Admin web đã đạt kiểm tra Vitest và build TypeScript/Vite; số test cập
  nhật được ghi tại [hướng dẫn Promotion admin](../backend/PROMOTION_ADMIN.md).
  Giao diện đã được xem ở 1440×1000, 900×1024 và 390×844, gồm trạng thái
  danh sách, sửa, rỗng và lỗi. Browser dùng dữ liệu kiểm thử được chặn tại
  HTTP; API CRUD và quyền được kiểm tra riêng với PostgreSQL thật.
- Đợt viết báo cáo này không chạy lại toàn bộ test, không gọi giao dịch
  tiền thật và không nghiệm thu provider/thiết bị production.

Bằng chứng các lượt test có phạm vi khác nhau; không cộng gộp các số test
trong nhiều lượt để coi là một lần nghiệm thu toàn bộ hệ thống.

## 13. Tổng hợp phần đã có và phần còn thiếu

**Đã có nền tảng nghiệp vụ chính:** quản lý tài khoản/người thân/caregiver,
KYC, dịch vụ/giá/ưu đãi, booking, thanh toán VNPAY, nhận và thực hiện ca,
checklist, tracking/timeline, checkout, ví/ledger, đánh giá, tranh chấp,
ticket, thông báo, admin và hạ tầng messaging.

**Những luồng chưa hoàn chỉnh cần được theo dõi riêng:** refund về phương
thức gốc, chi hộ caregiver, kích hoạt Kafka notification trên môi trường
thực, nghiệm thu GPS/KYC và các UI còn thiếu điểm nối backend.

**Những chức năng chưa triển khai:** Nutrition/gRPC, chat hỗ trợ trực tuyến,
chat Customer ↔ Caregiver theo booking, SMS OTP, booking/lịch rảnh định kỳ, GPS chạy nền,
giao dịch ví customer đầy đủ và export/BI.

## 14. Nguồn kiểm tra và tài liệu liên quan

- [Kiến trúc tổng thể cập nhật](ARCHITECTURE.md)
- [Bản đồ module](../backend/module.md)
- [Application và Controllers của backend](../../backend/caresitter-be/Modules)
- [Customer app](../../frontend/customer-app/lib)
- [Caregiver app](../../frontend/caregiver-app/lib)
- [Admin web](../../frontend/admin-web/src)
- [Kế hoạch Nutrition](MEAL_RECOMMENDATION_PLAN.md)
- [Tiến độ production](../backend/PRODUCTION_PROGRESS.md)
- [Kế hoạch production](../backend/PRODUCTION_PLAN.md)
- [Roadmap 14 ngày — một developer, Android và iOS](../backend/ROADMAP_PRODUCTION_14_NGAY.md)
- [Hướng dẫn GPS trực tiếp](../backend/docs/LIVE_TRACKING.md)
- [Hướng dẫn Kafka local](../backend/KAFKA_LOCAL.md)
- [Khôi phục mật khẩu trong app](../backend/PASSWORD_RECOVERY.md)
- [Kế hoạch idempotency cho booking và rút tiền](../backend/IDEMPOTENCY_PLAN.md)
- [Hướng dẫn vận hành Kafka](../docs/architecture/kafka-messaging-runbook.md)
- [Báo cáo test messaging đã lưu](../../backend/tests/CareSitter.Messaging.Tests/TestResults/messaging.trx)


## Cập nhật payOS ngày 07/10/2026

Đã bổ sung payOS bên cạnh VNPAY cho app khách hàng và backend. Khi chưa có kênh/khóa/HTTPS, app hiển thị payOS chưa khả dụng. Kết quả thanh toán chỉ xác nhận theo dữ liệu backend. Chuyển thiếu/thừa, chuyển thêm và nhận tiền sau khi booking đóng có biên nhận để admin đối soát; không tự ghi có thêm hoặc mở lại booking đã đóng.

Migration `36-payos-payments.sql` đã áp dụng vào database local. Cấu hình payOS local và mẫu triển khai mặc định tắt. Chưa kiểm tra giao dịch tiền thật và chưa bổ sung tự động hoàn tiền/chi hộ qua payOS.

Hướng dẫn cấu hình và vận hành: [Thanh toán payOS](../backend/PAYOS.md). Các tài liệu Markdown chỉ lưu local, không push.
