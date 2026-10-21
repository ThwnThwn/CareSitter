# Ba luồng người dùng CareSitter cho PRM323 Lab 2

Ngày lập: 14/10/2026. **Rà soát bổ sung: 17/10/2026.** Các mã là tên frame dự kiến để sắp Stitch/Figma; kiểm frame thực tế trước khi nối prototype. Xem [đối chiếu Lab 2](../frontend/stitch/PRM323_LAB2_DOI_CHIEU.md). Cả ba luồng chọn Customer app và persona [người con đặt chăm sóc](persona.md). Prototype hiện đối chiếu với [Stitch Project 16914427060621528532](https://stitch.withgoogle.com/projects/16914427060621528532).

## Cấu trúc điều hướng

Customer có bốn mục chính: **Trang chủ**, **Lịch hẹn**, **Chăm sóc viên**, **Hồ sơ**; action **Đặt lịch** mở booking wizard. Hồ sơ dẫn tới danh sách/chi tiết người thụ hưởng và Nutrition. Lịch hẹn dẫn tới chi tiết, thanh toán, tracking, timeline và đánh giá. Không tạo tab Nutrition hoặc Tin nhắn nếu source chưa có.

## Luồng 1 — đặt lịch và thanh toán

**Start:** Trang chủ hoặc Danh mục. **Goal:** tạo lịch đúng người, giờ, chi phí và biết trạng thái thanh toán. **End:** chi tiết lịch hiển thị trạng thái do backend xác nhận.

Happy path: `C-HOME → C-BOOK-01 Dịch vụ → C-BOOK-02 Người nhận → C-BOOK-03 Ngày giờ/địa chỉ → C-BOOK-04 Người chăm sóc → C-BOOK-05 Điều khoản → C-BOOK-06 Xác nhận → C-BOOK-DETAIL chờ thanh toán → C-PAY-METHOD → C-PAY-RESULT success → C-BOOK-DETAIL`.

Alternate path: chọn Bản thân hoặc hồ sơ Người thân ở bước 2; người chưa có hồ sơ mở tạo hồ sơ rồi quay về bước 2. Hủy thao tác ở cổng thanh toán dẫn `C-PAY-CANCEL → C-BOOK-DETAIL` với lịch vẫn chờ thanh toán.

Error/recovery: mất response hoặc provider chưa đồng bộ dẫn `C-PAY-SYNC/REVIEW`; màn giải thích đang đối soát, cho xem chi tiết lịch và thử lại chỉ khi trạng thái server cho phép. Không tạo giao dịch thứ hai từ URL quay về.

## Luồng 2 — theo dõi và đánh giá ca

**Start:** Lịch hẹn. **Goal:** biết ca đang diễn ra thế nào và xem bản ghi sinh hoạt. **End:** xem tổng kết, đánh giá hoặc quay lại danh sách lịch.

Happy path: `C-BOOK-LIST → C-BOOK-DETAIL → C-TRACKING → C-TIMELINE → C-REVIEW → C-BOOK-DETAIL`.

Alternate path: từ chi tiết lịch mở khiếu nại theo điều kiện trạng thái, gửi nội dung rồi trở lại chi tiết. Nút Back của từng màn về đúng ngữ cảnh lịch đã chọn.

Error/recovery: chưa cấp quyền vị trí, thiết bị caregiver mất kết nối hoặc vị trí cũ: `C-TRACKING-UNAVAILABLE`; nêu mốc cập nhật gần nhất nếu có, không đặt marker giả; cho xem timeline đã lưu hoặc quay về chi tiết lịch.

## Luồng 3 — gợi ý bữa ăn sinh hoạt

**Start:** Hồ sơ → Người được chăm sóc. **Goal:** kiểm lại dữ liệu gia đình cung cấp và xem bữa ăn không chứa nguyên liệu đã loại trừ. **End:** lưu/xem lại thực đơn hoặc quay về hồ sơ khi không thể gợi ý.

Happy path: `C-BEN-LIST → C-BEN-DETAIL → C-NUT-01 Tổng quan → C-NUT-02 Cập nhật → C-NUT-05 Kiểm tra → C-NUT-07 Bữa ăn trong ngày → C-NUT-08 Chi tiết món / C-NUT-09 Thay món → C-NUT-10 Lưu → C-NUT-11 Lịch sử`.

Alternate path: dữ liệu đã đủ có thể đi từ tổng quan tới kiểm tra/xác nhận mà không nhập lại. Người dùng giữ món cũ nếu không có món thay thế phù hợp; không nới lỏng dị ứng/bệnh lý đã khai.

Error/recovery: `C-NUT-04` cần bổ sung dữ kiện hoặc `C-NUT-STATE-01` cần hướng dẫn chuyên biệt thì dừng gợi ý và dẫn về hồ sơ; lỗi tải/lưu giữ lựa chọn đã nhập và retry an toàn. Bệnh lý chỉ là thông tin **đã biết do gia đình cung cấp** để tránh món/nguyên liệu không phù hợp, không phải chẩn đoán hay thực đơn điều trị.

## Kiểm prototype

Trong Figma 01 vẽ ba flow và các nhánh trên; trong Figma 06 đặt ba starting point và nối Back, dialog overlay và một chuyển cảnh loading → result. Tài liệu này chỉ xác định sơ đồ, **chưa chứng minh các link prototype đã được tạo hoặc chạy thử**.
