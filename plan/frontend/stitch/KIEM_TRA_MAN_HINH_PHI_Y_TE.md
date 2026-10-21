# Kiểm tra màn hình CareSitter và phạm vi phi y tế

Ngày kiểm tra: 14/10/2026. Project: [CareSitter trên Stitch](https://stitch.withgoogle.com/projects/9685887642498274590). Phạm vi màn dùng trình bày PRM323 Lab 2 và bằng chứng còn thiếu ở [bảng đối chiếu](PRM323_LAB2_DOI_CHIEU.md).

Yêu cầu bổ sung trong lúc làm: UI mới phải fit giống khung mobile cũ trong ảnh người dùng. Đã xác định các nhóm màn sinh mới dùng artboard rộng 1280 px với phone 390 px nằm giữa; cần đổi sang viewport Mobile thật, không chỉ đổi CSS của phone bên trong. Nhóm Admin/Landing Desktop vẫn theo loại bề mặt của dự án.

## Yêu cầu và phạm vi

Người dùng yêu cầu đối chiếu màn hình với dự án, thêm phần còn thiếu và bỏ nội dung y tế vì CareSitter là dịch vụ phi y tế. Palette thiết kế theo Landing: teal `#006B5B`, giấy kem `#F5F3EE`, mint `#E6F4F1`.

Tác vụ này chỉnh thiết kế Stitch và tài liệu local. Không tự thay đổi hợp đồng People/Nutrition, xóa dữ liệu sức khỏe, sửa source Flutter/backend, chạy APK hoặc push. Một frame là thiết kế bước/trạng thái, không mặc nhiên là route độc lập hoặc chứng cứ tính năng đã chạy.

## Kết quả kiểm tra ban đầu

Canvas có các màn Customer chính, ba màn Caregiver chính và nhóm Nutrition đã bổ sung. Chưa đủ để bao phủ các route Customer/Caregiver, Admin hoặc yêu cầu tư vấn Landing. Flow Map đã có tên màn dự kiến nhưng tên trong sơ đồ không chứng minh artboard tương ứng đã được tạo.

Đã phát hiện nội dung vượt phạm vi trong preview thực tế:

- Home/danh mục: điều dưỡng, hộ lý, hỗ trợ y tế, phục hồi, vật lý trị liệu, chứng chỉ sơ cứu và gói sau viện.
- Theo dõi/ca đang làm/chi tiết lịch: đo huyết áp, nhịp tim, nhắc thuốc, liều hoặc tên thuốc; một số tuyên bố giám sát sức khỏe và cấp cứu.
- Nutrition bản cũ: thuốc, đường nuôi ăn, đánh giá nuốt, giới hạn dịch/điện giải; lượng nước 500 ml tự sinh, kiểm soát đường huyết và tuyên bố món ăn hỗ trợ bệnh hoặc nuốt. Bệnh lý đã biết do gia đình cung cấp được **giữ lại** theo yêu cầu mới để tránh món/nguyên liệu không phù hợp.
- Mẫu cũ còn cam kết không được kiểm chứng: bảo hiểm, hotline giả, 24/7, 100% xác minh, nhận diện khuôn mặt, lưu thẻ Visa/2FA SMS, gói định kỳ và mức giảm giá tự đặt.

## Ranh giới thiết kế mới

Giữ đồng hành, trò chuyện/đọc báo, chuẩn bị bữa ăn gia đình, hỗ trợ sinh hoạt thông thường, dạo bộ khi phù hợp, lịch hẹn, thanh toán, check-in/check-out, nhật ký, đánh giá và hỗ trợ vận hành.

Nutrition đổi định hướng thành **Gợi ý bữa ăn sinh hoạt**. Giữ dị ứng thực phẩm, **bệnh lý đã biết do gia đình cung cấp**, nguyên liệu cần tránh và ghi chú chuẩn bị món. Bệnh lý chỉ dùng để đối chiếu món/nguyên liệu cần tránh; màn hình nêu rõ nguồn là gia đình và không tự chẩn đoán, điều trị hay bảo đảm an toàn lâm sàng. Phân biệt chưa rõ với xác nhận không có; không nới lỏng dị ứng hoặc bệnh lý đã khai để tạo kết quả. Bỏ thuốc/nhắc thuốc/liều, dấu hiệu sinh tồn, nuôi ăn, đánh giá nuốt, định lượng dịch/điện giải và chế độ ăn trị bệnh. Nhu cầu chuyên biệt ngoài phạm vi thì dừng gợi ý và dẫn về hồ sơ.

Thông tin về vận động trong hồ sơ chỉ là hỗ trợ sinh hoạt do gia đình mô tả, không phân loại bệnh hoặc phục hồi chức năng. Giữ người liên hệ và báo sự cố; không biến thành dịch vụ cấp cứu hoặc giám sát y tế. Không dùng danh xưng chuyên môn y tế để giới thiệu người chăm sóc.

## Danh mục cần bao phủ

Mã dưới đây dùng để đối chiếu thiết kế; không khẳng định nhãn artboard đã được đổi. Các màn dùng chung có thể dùng một thiết kế với chú thích rõ vai trò/route; mỗi state quan trọng phải có thiết kế hiển thị cụ thể.

### Customer

| Route / bước | Thiết kế yêu cầu |
| --- | --- |
| `/brand-intro` | Giới thiệu thương hiệu phi y tế |
| `/auth/login` | Đăng nhập mật khẩu, ghi nhớ; entry OTP Email |
| `/auth/register` | Đăng ký; thành công quay về đăng nhập |
| `/auth/email` | Nhập Email nhận OTP |
| `/auth/phone` | Alias chuyển tới `/auth/email`, không tạo luồng SMS mới |
| `/auth/otp` | Xác minh OTP Email; sai/hết hạn/gửi lại |
| `/auth/forgot-password` | Email → mã → mật khẩu mới → thành công |
| `/settings/recovery-email` | Email khôi phục và xác minh mã |
| `/home` | Home, dịch vụ phi y tế, lịch sắp tới |
| `/bookings` | Danh sách lịch, trạng thái thanh toán/ca |
| `/caregivers` | Danh sách người chăm sóc sinh hoạt |
| `/beneficiaries` | Danh sách Bản thân/Người thân |
| `/tracking` | Danh sách hoạt động, chọn lịch để xem |
| `/settings` | Hồ sơ và cài đặt Customer |
| `/beneficiaries/create` | Tạo hồ sơ với thông tin sinh hoạt và liên hệ |
| `/beneficiaries/:id` | Chi tiết, sửa, đặt lịch, entry bữa ăn |
| `/beneficiaries/:id/edit` | Biến thể chỉnh sửa form, giữ các field không sửa |
| `/catalog` | Danh mục dịch vụ có thật, không tự gói định kỳ |
| `/notifications` | Thông báo lịch/thanh toán/hệ thống |
| `/booking/new`: 1 | Dịch vụ |
| `/booking/new`: 2 | Bản thân/Người thân |
| `/booking/new`: 3 | Ngày/giờ/địa chỉ, thời lượng 2–12 giờ |
| `/booking/new`: 4 | Chọn người chăm sóc |
| `/booking/new`: 5 | Điều khoản và đồng ý |
| `/booking/new`: 6 | Kiểm tra và xác nhận, thanh toán sau khi có lịch |
| Chọn thanh toán | Sheet payOS/VNPAY theo khả dụng; không lưu thẻ |
| `/payment-result` | Thành công, đang đồng bộ, chưa hoàn tất, cần đối soát; nhánh hủy thanh toán giữ lịch |
| `/bookings/:id` | Chi tiết lịch, hủy lịch là thao tác riêng |
| `/bookings/:id/tracking` | Theo dõi tiến trình và nhật ký sinh hoạt |
| `/bookings/:id/timeline` | Timeline sinh hoạt theo giờ |
| `/bookings/:id/review` | Đánh giá ca đã hoàn tất |
| `/bookings/:id/dispute` | Lý do/mô tả khiếu nại, trạng thái gửi |
| `/caregivers/:id` | Hồ sơ/kỹ năng sinh hoạt, lịch và đặt lịch |
| `/settings/profile/edit` | Sửa thông tin tài khoản |
| `/wallet` | Số dư và lịch sử hoàn tiền; không tự thêm nạp/rút |
| `/settings/addresses` | Danh sách/thêm/sửa/chọn địa chỉ đã xác thực |
| `/settings/password` | Mật khẩu hiện tại/mới/xác nhận |
| `/settings/notifications` | Thiết lập thông báo theo source |
| `/settings/faq` | Câu hỏi thường gặp phi y tế |
| `/settings/support` | Gửi yêu cầu hỗ trợ vận hành |
| `/beneficiaries/:id/nutrition` | 12 bước/state/sheet chính, ba state chặn và bảng ngoại lệ; nội dung phi y tế |

### Caregiver

| Route / bước | Thiết kế yêu cầu |
| --- | --- |
| `/auth/phone` | Đăng nhập Email/SĐT + mật khẩu hoặc OTP Email; tên route không phải SMS OTP |
| `/auth/otp`, `/auth/register`, `/auth/forgot-password` | OTP/đăng ký/khôi phục; có thể dùng mẫu chung ghi rõ vai trò |
| `/settings/recovery-email` | Dùng mẫu khôi phục đã xác minh |
| `/home` | Tổng quan và offer ca hỗ trợ người lớn tuổi |
| `/shifts` | Danh sách ca và trạng thái |
| `/schedule` | Lịch công việc |
| `/settings` | Hồ sơ/cài đặt/entry thu nhập và tài liệu |
| `/notifications` | Thông báo ca và tài khoản |
| `/profile/setup`, `/settings/profile/edit` | Form thông tin/kỹ năng sinh hoạt; dùng cùng thiết kế |
| `/profile/documents`, `/settings/documents` | Trạng thái tài liệu/xác minh danh tính; dùng cùng thiết kế |
| `/settings/documents/upload` | Upload tài liệu, không yêu cầu bằng/chứng chỉ y khoa |
| `/shifts/:id` | Chi tiết offer/ca, nhận/từ chối nếu phù hợp trạng thái |
| `/shifts/:id/active` | Check-in/checklist/nhật ký/check-out phi y tế |
| `/shifts/:id/map` | Bản đồ tới điểm hẹn; trạng thái thiếu quyền/vị trí |
| `/shifts/:id/summary` | Kết quả ca, công việc, ghi chú, thu nhập |
| `/shifts/:id/customer-report` | Bản tổng kết sinh hoạt gửi/xem cho gia đình; không biểu đồ sức khỏe |
| `/earnings` | Thu nhập/số dư/lịch sử |
| `/earnings/withdraw` | Form yêu cầu rút; đã nhận yêu cầu không đồng nghĩa chuyển tiền thành công |
| `/settings/reviews`, `/settings/faq`, `/settings/support` | Đánh giá/FAQ/hỗ trợ theo vai trò |

### Admin và Landing

| Mục | Thiết kế yêu cầu |
| --- | --- |
| Admin Login | Form đăng nhập vận hành |
| Dashboard | Tổng quan lịch/offer/payment/support, không số liệu y tế |
| Bookings | Danh sách và drawer chi tiết/duyệt kết thúc ca |
| KYC | Xác minh danh tính/tài liệu, không cấp chứng chỉ y khoa |
| Payments | Thanh toán/đối soát/hoàn tiền/payout theo trạng thái, không báo đã trả khi chỉ duyệt yêu cầu |
| Support | Ticket và tab yêu cầu tư vấn Landing |
| Disputes | Danh sách và drawer xử lý khiếu nại dịch vụ |
| Services | Danh mục/bảng giá và checklist sinh hoạt |
| Promotions | Chiến dịch có thật, form và trạng thái |
| Users | Vai trò/trạng thái tài khoản |
| Landing desktop/mobile | Nội dung phi y tế, giữ nhận diện hiện có |
| Form tư vấn | Tên/SĐT/dịch vụ/ngày/2-4-8-12 giờ/ưu tiên/ghi chú/đồng ý |
| Kết quả tư vấn | Biên nhận đã tiếp nhận, lỗi giữ dữ liệu; không gọi là đã đặt lịch/đã trả tiền |

## Giới hạn của source cần xử lý riêng

Source People/Nutrition vẫn có trường và trạng thái sức khỏe; backend Nutrition đang đăng ký `UnconfiguredHealthParser`. Thiết kế mới không chứng minh backend đã thành hệ gợi ý phi y tế hoàn chỉnh. Nếu triển khai UI mới, cần rà hợp đồng/field/domain cùng chủ dự án; giữ đúng bệnh lý và dị ứng đã khai, không ngầm đổi giá trị chưa rõ thành không có.

Phần đính kèm khiếu nại và chia sẻ báo cáo có UI trong source nhưng không được coi là hoàn tất chỉ từ sự xuất hiện của widget. Thiết kế phải ghi trạng thái chưa khả dụng hoặc bỏ CTA nếu chưa được chứng minh có kết nối thật.

## Xác minh và tiến độ

Đang thực hiện: sửa artboard theo các nhóm, bổ sung màn thiếu và kiểm lại text hiển thị. Kết quả cuối được cập nhật sau khi quan sát bản lưu, không dựa riêng vào phản hồi của agent Stitch.

Nguồn đối chiếu: Router Customer/Caregiver, `BookingWizardBody`, `ScheduleRules`, mô hình người thụ hưởng, form đăng ký, trạng thái payment, ví/rút tiền, route Admin và contract form tư vấn Landing. Tất cả đọc từ source local ngày 14/10/2026.
