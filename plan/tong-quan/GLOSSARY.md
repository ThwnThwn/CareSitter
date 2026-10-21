# Thuật ngữ miền CareSitter

Tài liệu này định nghĩa ngôn ngữ nghiệp vụ dùng chung. Thuật ngữ mô tả khái
niệm của sản phẩm, không mô tả tên bảng, API hoặc framework triển khai.

**Chat theo lịch chăm sóc (Booking chat)**: Hội thoại 1:1 gắn với một lịch chăm
sóc, dành cho khách hàng sở hữu lịch và caregiver đang được phân công để phối
hợp trước, trong và một khoảng ngắn sau ca. Vòng đời và quyền gửi được suy từ
booking.  
_Avoid_: chat hỗ trợ, ticket chat, support chat.

**Chat hỗ trợ (Support chat)**: Hội thoại giữa khách hàng hoặc caregiver với
nhân viên CareSitter để xử lý một yêu cầu hỗ trợ. Hội thoại này gắn với ticket
và không cấp quyền cho hai bên của booking nhắn trực tiếp cho nhau.  
_Avoid_: booking chat, chat với caregiver.

**Caregiver đang được phân công (Assigned caregiver)**: Caregiver hiện có quyền
thực hiện một booking theo trạng thái phân công nguồn sự thật của hệ thống. Khi
phân công thay đổi, caregiver trước đó không còn quyền truy cập booking chat.  
_Avoid_: caregiver từng nhận lịch, caregiver được client truyền lên.

**Tin nhắn nhanh (Quick message)**: Câu soạn sẵn theo vai trò và trạng thái
booking, giúp người dùng gửi thông tin phối hợp thường gặp như “Tôi sắp tới”. Nó
được lưu như một tin nhắn thông thường và không tự thay đổi trạng thái booking.  
_Avoid_: lệnh trạng thái, check-in nhanh.

**Sự kiện hệ thống trong chat (System chat event)**: Mục lịch sử bất biến phản ánh
một thay đổi booking đã được ghi nhận thành công, ví dụ caregiver bắt đầu di
chuyển hoặc check-in. Nó không phải tin do người dùng nhập.  
_Avoid_: tin nhắn của CareSitter, quick message tự động.

**Khoảng nhắn sau ca (Post-shift grace)**: Khoảng thời gian tính từ lần yêu cầu
checkout đầu tiên, hoặc lần hoàn tất đầu tiên nếu không có checkout, mà hai bên
còn được nhắn để chốt nội dung sinh hoạt; xác nhận hoàn tất không khởi động lại
khoảng này. Hết hạn, hội thoại chỉ đọc.  
_Avoid_: mở chat vĩnh viễn, thời hạn khiếu nại.

**Lần phân công chat (Chat assignment epoch)**: Giai đoạn một caregiver đã nhận
và được phân công cho lịch chăm sóc, xác định phần hội thoại người đó được xem.
Cùng caregiver được phân công lại vẫn là lần mới, khác với một lời mời nhận ca.  
_Avoid_: offer, lịch sử mọi caregiver của booking.

