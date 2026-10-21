# Quyết định thiết kế CareSitter cho PRM323 Lab 2

Các quyết định dưới đây đối chiếu yêu cầu người dùng, source local và thiết kế Stitch ngày 14/10/2026. **Rà soát lại với project hiện tại ngày 17/10/2026:** [Stitch CareSitter](https://stitch.withgoogle.com/projects/16914427060621528532). Chúng là lý do để chỉnh bản thiết kế; chưa chứng minh Figma prototype hay Flutter đã áp dụng.

**Quyết định chốt tạm cho hồ sơ:** dùng token đang hiển thị trên Stitch hiện tại làm nguồn tham chiếu UI: `Serene Companion`, primary `#006B5B`, secondary `#D88C6C`, tertiary `#D3E8E1`, neutral `#F5F3EE`, font `Be Vietnam Pro`. `Warm Companion`, `#496534`, `#F8F9EF` và `Inter` trong tài liệu cũ được giữ dưới dạng token lịch sử cho đến khi có Figma/Flutter approval.

1. **Modify — màu thương hiệu:** Dùng token đang hiển thị trên Stitch hiện tại: primary teal `#006B5B`, secondary coral `#D88C6C`, tertiary mint `#D3E8E1` và nền giấy `#F5F3EE`. Không dùng xanh `#2D9E6B` trong tài liệu Lab 2 cũ. Flutter Customer local vẫn có primary `#496534`; phần handoff phải ghi chênh lệch này thay vì nói token đã đồng bộ.
2. **Accept — thông tin chọn người chăm sóc:** Giữ card có tên, kỹ năng sinh hoạt, lịch khả dụng và thông tin xác minh khi nguồn dữ liệu có thật. Bỏ huy hiệu “100% xác minh” hoặc chứng chỉ y tế tự sinh. Điều này giúp persona so sánh mà không tạo bảo đảm sai.
3. **Reject — tab và tính năng giả:** Điều hướng Customer theo source gồm Trang chủ, Lịch hẹn, Chăm sóc viên, Hồ sơ và action Đặt lịch. Không thêm tab Tin nhắn, SMS OTP hay ví nạp/rút chỉ vì AI vẽ ra.
4. **Modify — kết quả thanh toán:** Sau khi trở về từ payOS/VNPAY, hiển thị trạng thái từ backend: thành công, đang kiểm tra, thất bại hoặc hủy. Hủy thanh toán giữ lịch chờ trả tiền. Không đổi URL quay về thành bằng chứng đã thu tiền.
5. **Modify — Nutrition:** Giữ dị ứng, bệnh lý đã biết do gia đình cung cấp, nguyên liệu cần tránh và lưu ý chuẩn bị món để loại trừ món không phù hợp. Nếu điều kiện không rõ hoặc cần chế độ ăn chuyên biệt, dừng gợi ý và dẫn về hồ sơ. Bỏ kê đơn, liều thuốc, ngưỡng nước và lời hứa điều trị.
6. **Modify — kích thước frame:** Màn app cuối phải là artboard Mobile thật rộng khoảng 390 px, một cột và nút chạm tối thiểu 48 × 48 dp. Frame Desktop rộng 1280 px bọc điện thoại không được tính là bản final mobile trong Lab 2.

**Cần kiểm chứng trong Figma:** contrast chữ thường `≥4.5:1`, điều khiển/chữ lớn `≥3:1`, cỡ chữ nội dung `≥14 sp`, khung 360 và 412 dp. Hiện chưa có kết quả đo hoặc screenshot Figma cho các tiêu chí này.
