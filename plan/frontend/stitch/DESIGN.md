# Hệ thống thiết kế CareSitter dành cho Stitch

> Cập nhật: 14/10/2026. Phạm vi: đối chiếu màn hình với source và yêu cầu PRM323 Lab 2. Nutrition được ghi bệnh lý đã biết do gia đình cung cấp để loại trừ món/nguyên liệu không phù hợp; không tự chẩn đoán hay đưa ra chế độ ăn điều trị. Thiết kế dùng palette Landing teal; source Customer còn olive. Việc thay đổi thiết kế không đồng nghĩa đã sửa hợp đồng hoặc chức năng của app/backend. Dùng cùng [bộ prompt](STITCH_PROMPTS.md) và [bảng đối chiếu Lab 2](PRM323_LAB2_DOI_CHIEU.md).

## 1. Chủ đề và không khí thị giác

CareSitter là sản phẩm đồng hành và hỗ trợ sinh hoạt phi y tế tại nhà cho người lớn tuổi, gia đình và người chăm sóc tại Việt Nam. Chỉ thiết kế các việc trò chuyện, đọc báo, chuẩn bị bữa ăn gia đình, hỗ trợ sinh hoạt và dạo bộ phù hợp. Giao diện ấm, bình tĩnh, dễ đọc và tập trung vào thao tác tiếp theo. Customer có mật độ 4/10, độ biến thiên bố cục 3/10, chuyển động 2/10. Mỗi màn hình có một hành động chính; form dài được chia nhóm theo nhiệm vụ.

Giữ bố cục, logo, ảnh, icon và component tốt của project Stitch hiện có. Customer, Caregiver, Landing và Admin là bốn bề mặt riêng; theo yêu cầu mới, đồng bộ màu Customer/Nutrition với Landing nhưng không tự đổi cấu trúc hoặc font. Ưu tiên Customer/Nutrition trước.

## 2. Bảng màu và vai trò

### Customer và Nutrition

Palette đích lấy từ [thiết kế Landing](../landing-page/DESIGN.md), theo yêu cầu trực tiếp mới nhất của người dùng. Đây là thay đổi thiết kế trên Stitch, không phải xác nhận code Customer đã được đổi màu.

| Tên mô tả | Màu | Vai trò |
| --- | --- | --- |
| Teal chăm sóc | `#006B5B` | CTA chính, lựa chọn, link và focus |
| Teal đậm | `#004F43` | Chữ nhấn và trạng thái trên nền mint |
| Teal hover | `#00806D` | Biến thể cùng họ màu primary |
| Giấy kem | `#F5F3EE` | Canvas và nền màn hình |
| Bề mặt trắng | `#FFFFFF` | Card và input |
| Mint dịu | `#E6F4F1` | Nhóm thông tin, lựa chọn và success nhẹ |
| Mực xanh đen | `#0D1117` | Heading và nội dung chính |
| Slate | `#536471` | Mô tả và metadata |
| Viền giấy | `#E2DDD5` | Divider và viền input |
| Cảnh báo | `#A43F16` trên `#FFF0E8` | Thiếu thông tin, cần xem lại |
| Lỗi | `#B42318` trên `#FDE5E2` | Validation và lỗi xử lý |
| Trắng | `#FFFFFF` | Chữ trên primary và bề mặt input |

Teal là điểm nhấn hành động chính trong Customer/Nutrition. Màu cảnh báo/lỗi có vai trò ngữ nghĩa, luôn đi kèm chữ và icon. Không dùng mảng đỏ lớn cho trạng thái cần bổ sung thông tin. Mint sáng `#00C896` chỉ dùng tín hiệu nhỏ, không thay primary teal hoặc dùng cho chữ body.

### Landing và Caregiver

Giữ teal `#006B5B`, nền giấy `#F5F3EE`, mint `#E6F4F1`, chữ `#0D1117`, chữ phụ `#536471`, viền `#E2DDD5` theo source và [thiết kế Landing](../landing-page/DESIGN.md). Customer/Nutrition dùng cùng palette này theo yêu cầu mới. Admin giữ theme hiện có của Admin.

## 3. Quy tắc typography

- Customer/Nutrition giữ font sans-serif hiện có của app (`Inter` trong `AppTheme`), hỗ trợ tiếng Việt đầy đủ. Đây là yêu cầu giữ giao diện hiện hành; không tự đổi font khi dùng workflow thiết kế.
- Caregiver/Admin giữ sans-serif theo component hiện có. Không đưa serif của Landing vào form, bảng vận hành hoặc thực đơn.
- Landing giữ Instrument Serif cho display, DM Sans cho body/UI, IBM Plex Mono cho nhãn ngắn theo tài liệu Landing.
- Tiêu đề màn hình 22–24 px, semibold; tiêu đề nhóm 16–18 px; body 16 px, line-height 1.5–1.65; metadata tối thiểu 13–14 px khi dựng màn mới. Ưu tiên khả năng đọc và text scale.
- Không ép một dòng cho nhãn dài. Đơn vị định lượng công thức phải đọc được cùng con số; không thiết kế chỉ số hoặc mục tiêu y tế. Không cắt mất nguồn dữ kiện hoặc thông báo lỗi quan trọng.

## 4. Component và các trạng thái

- Nút chính cao 48–52 px, teal/chữ trắng ở Customer; khóa thao tác khi đang gửi. Nút phụ outline hoặc text, có focus và phản hồi khi nhấn.
- Input có label rõ, helper text khi cần, lỗi ngay dưới field. Không dùng placeholder thay label. Trường đã có dữ liệu được điền trước.
- Spacing theo token app: 4, 8, 12, 16, 20, 24, 32, 48 px. Padding nội dung 16–20 px.
- Input/button radius 14 px; card 16–18 px; bottom sheet 24 px ở góc trên. Dùng divider cho các dòng dữ kiện thay vì card lồng card.
- Thông tin bữa ăn gồm dị ứng thực phẩm, bệnh lý đã biết do gia đình cung cấp, nguyên liệu cần tránh và ghi chú chuẩn bị món; ghi rõ nguồn/thời điểm nếu có. Bệnh lý là bối cảnh để rà món/nguyên liệu và dừng gợi ý khi chưa đủ cơ sở, không phải đầu vào để AI chẩn đoán hay kê thực đơn điều trị. Không thiết kế thuốc/liều, đường nuôi ăn, thang đánh giá nuốt, giới hạn dịch/điện giải hoặc phân tích chỉ số sức khỏe.
- Bữa ăn dùng ba khối dọc Sáng, Trưa, Tối; tên món, khẩu phần, các mục chi tiết và thao tác thay món. Chưa có dữ liệu dinh dưỡng được ghi đúng là chưa có dữ liệu.
- Loading dùng skeleton theo nội dung; processing có nhãn trạng thái không dùng phần trăm giả. Empty/error có hành động tiếp theo đúng luồng.
- Nhóm thiếu thông tin ưu tiên tối đa ba câu hỏi sinh hoạt cần thiết mỗi lượt; không bắt nhập lại cả hồ sơ. “Chưa rõ” khác với “Gia đình xác nhận không có”. Yêu cầu chế độ ăn chuyên biệt ngoài phạm vi thì dừng gợi ý, không mở khóa chỉ bằng cách tải lên hoặc chép chỉ định.
- Lịch sử thực đơn có ngày và trạng thái. Thực đơn lưu là bản xem lại; thay món thực hiện trước bước lưu. Khi hồ sơ/nội dung đổi, kết quả cũ cần kiểm tra lại.

## 5. Bố cục và điều hướng

- Theo yêu cầu mới “fit y chang những phần cũ”, Customer/Caregiver phải là artboard **MOBILE thật** rộng khoảng 390 px hoặc bằng đúng frame mẫu cũ. Nội dung chiếm toàn bộ bề rộng artboard; chiều cao theo nội dung như mẫu cũ, form có cuộn và safe area. Không dùng artboard Desktop 1280 px rồi đặt một khung điện thoại 390 px ở giữa; không bezel, nền showcase, khoảng trắng ngang hoặc chú thích làm phình viewport.
- App bar, card, padding, font và CTA của màn mới theo bộ màn mobile cũ C-NUT-04/C-NUT-12, giữ màu Landing theo yêu cầu trước. Kiểm tra 320/430 px và text scale 200% khi triển khai. Landing/Admin dùng artboard Desktop thật khoảng 1440 px; Landing có bản Mobile riêng. Các bảng state/Flow Map là tài liệu thiết kế riêng, không thay thế màn ứng dụng.
- Customer giữ bottom navigation: Trang chủ, Lịch hẹn, Chăm sóc viên, Hồ sơ; action Đặt lịch mới ở giữa. Không thêm tab Nutrition trong đợt này.
- Nutrition đi từ Hồ sơ người thụ hưởng → Chi tiết hồ sơ → Gợi ý thực đơn. Mọi màn luôn thể hiện đúng tên người đang chọn; hồ sơ Bản thân và Người thân dùng cùng flow.
- Route Nutrition hiện tại là `/beneficiaries/:id/nutrition`. Các frame bổ sung biểu diễn bước, trạng thái và sheet của flow này; việc thiết kế frame không chứng minh đã có route độc lập.
- Màn chính đặt từ trái sang phải theo thứ tự hành trình; các nhánh lỗi/state đặt ngay dưới màn cha; nhánh thay món và lịch sử nằm dưới nhánh thực đơn. Có sơ đồ luồng và quy ước tên frame.
- Giữ khoảng cách không gian rõ giữa text/ảnh/nút. Không chồng nội dung lên nhau hoặc dùng three-column equal cards cho màn mobile.
- Touch target tối thiểu 44 × 44 px; CTA không che nội dung khi bàn phím mở; dùng safe area.

## 6. Chuyển động và tương tác

- App dùng chuyển màn và phản hồi nhấn nhẹ, khoảng 160–240 ms. Spring tham khảo stiffness 100, damping 20 nếu cần prototype.
- Chỉ animate transform và opacity; không dùng chuyển động liên tục cho thông tin sức khỏe hoặc tất cả card. Micro-loop giới hạn ở skeleton/loading hoặc tín hiệu đang cập nhật và dừng khi trạng thái kết thúc.
- Không animation làm chậm đọc form. Prototype có thể không thể hiện animation; lưu mô tả tương tác cạnh frame.
- Tôn trọng giảm chuyển động cho các màn mới. Landing giữ hành vi hiện có; tác vụ này không thay hiệu ứng Landing.

## 7. Mẫu cần tránh và giới hạn nội dung

- Không đổi hàng loạt UI cũ; không nhân bản màn đã đủ nội dung; biến thể cũ chuyển vào khu Archive thay vì xóa.
- Không font lỗi tiếng Việt, emoji dùng thay icon, pure black `#000000`, neon, gradient tím/xanh hoặc glow cho CTA.
- Không bố cục card giống nhau ở mọi nơi, không giả số liệu, đánh giá, bác sĩ đã xác minh hoặc tỷ lệ thành công.
- Bỏ khỏi thiết kế chẩn đoán AI, thu thập triệu chứng để suy bệnh, thuốc/nhắc thuốc/liều, đo dấu hiệu sinh tồn, phục hồi/vật lý trị liệu, chỉ định ăn/nuốt, mức dịch/điện giải, mục tiêu dinh dưỡng trị bệnh, danh xưng điều dưỡng/hộ lý/chuyên gia y tế và chứng chỉ y khoa. Có thể liệt kê bệnh lý đã biết do gia đình khai để tránh gợi ý món không phù hợp; không tuyên bố món chữa hoặc kiểm soát bệnh. Chỉ dùng một câu phạm vi ngắn; không lặp danh sách thủ thuật trong disclaimer.
- Không chuyển “Chưa rõ” thành “Không có”; không cho bỏ dị ứng để mở khóa gợi ý; không dùng thực đơn chung như kết quả cá nhân hóa. Giữ dị ứng thực phẩm như thông tin an toàn cho chuẩn bị bữa ăn, không tự suy diễn chẩn đoán.
- Bỏ cam kết không được source/chính sách xác nhận: bảo hiểm, 24/7, hotline giả, nhận diện khuôn mặt, độ chính xác GPS tuyệt đối, 100% xác minh, ưu đãi và số liệu thành công tự sinh.
- Không thêm theo dõi ăn uống, reminder, shopping list, xuất PDF, kế hoạch 7 ngày, sở thích/budget hay màn duyệt công thức Admin vào flow hiện hành khi chưa có hợp đồng hỗ trợ. Nếu cần ý tưởng tương lai, đặt board riêng ghi “Đề xuất”.
- Dữ liệu dựng prototype phải được ghi “Dữ liệu minh họa” trong chú thích thiết kế; không dùng dữ liệu cá nhân thật.

## Cơ sở đối chiếu và cách kiểm chứng

Đã đọc source Router Customer/Caregiver, `BookingWizardBody`, feature Nutrition (screen, form, result, repository/actions), theme Customer/Caregiver, routes Admin và form tư vấn Landing ngày 14/10/2026. Source Nutrition hiện đăng ký `UnconfiguredHealthParser`; thiết kế trạng thái gợi ý không chứng minh provider AI hoặc danh mục chuyên môn đã được nghiệm thu.

Đã mở project Stitch được người dùng cung cấp, gửi các lượt yêu cầu, tải lại và kiểm tra bản đã lưu. Đã kiểm màu hiển thị thực tế ở C-NUT-01–08: primary teal `#006B5B`, nền chính `#F5F3EE` (chi tiết món có lớp nền tối của sheet); kiểm tra tóm tắt không còn liều thuốc/ngưỡng nước tự sinh được phát hiện trong QA. C-NUT-09–12 và các state có palette Landing trong preview. Flow Map đã ghim trên canvas.

Giới hạn: Stitch không tự di chuyển tọa độ artboard; tài liệu Flow Map chỉ ra thứ tự để sắp workspace. Chưa kiểm toàn bộ prototype, breakpoint, font hoặc nghiệm thu UI trên thiết bị. Frame thiết kế và dữ liệu minh họa không chứng minh app/backend đã được thay đổi hoặc gợi ý dinh dưỡng đã chạy thực tế.
