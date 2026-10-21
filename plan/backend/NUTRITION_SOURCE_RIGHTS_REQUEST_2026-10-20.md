# Mẫu xử lý quyền nguồn Nutrition Knowledge

> Trạng thái 20/10/2026: workspace owner đã xác nhận cho phép dùng nội bộ/local trong Codex thread. Xác nhận này đủ cho chunk/index/query nội bộ đối với revision đã gắn hash, nhưng không được hiểu là quyền tái phân phối công khai hoặc phê duyệt nội dung lâm sàng.

## Thông tin cần xin xác nhận

- Tên tài liệu/dataset, ấn bản/release, chủ sở hữu và người liên hệ.
- Cho phép trích xuất tự động hay chỉ đọc thủ công.
- Cho phép tạo chunk/embedding/knowledge graph chạy local hay không.
- Cho phép lưu citation/snippet nội bộ; giới hạn độ dài nếu có.
- Cho phép dùng trong sản phẩm thương mại và cung cấp kết quả cho người dùng cuối hay không.
- Cho phép lưu bản dẫn xuất và thời hạn lưu; yêu cầu xóa/cập nhật khi nguồn đổi.
- Yêu cầu attribution, audit, redistribution và bảo mật.

## Mẫu thư

Kính gửi đơn vị quản lý nguồn,

CareSitter đang xây dựng công cụ nội bộ hỗ trợ chuyên gia soạn và kiểm tra dữ liệu dinh dưỡng. Chúng tôi muốn xin phép sử dụng **[tên nguồn, ấn bản/release]** trong phạm vi: trích xuất có kiểm soát, tạo chỉ mục/embedding/đồ thị tri thức chạy nội bộ, lưu trích dẫn có locator và dùng kết quả đã được chuyên gia duyệt trong sản phẩm.

Vui lòng xác nhận rõ các phạm vi được phép, yêu cầu attribution, giới hạn trích dẫn/redistribution, điều kiện thương mại, thời hạn và quy trình thu hồi/cập nhật. Nếu chỉ một phần được phép, xin chỉ rõ phần và mục đích tương ứng.

Chúng tôi sẽ giữ nguồn ở trạng thái `unverified` và không index/query cho tới khi nhận được xác nhận bằng văn bản.

## Sổ theo dõi hiện tại

| Nguồn | Trạng thái | Việc tiếp theo |
| --- | --- | --- |
| Dinh dưỡng lâm sàng 2019 | `permitted` cho local/internal, revision đã gắn hash | Nếu đưa ra production/public phải bổ sung bằng chứng quyền tương ứng |
| Hai trang sách/sample còn lại | `unverified` | Xác định chủ sở hữu và phạm vi sample/product metadata |
| Snapshot thành phần thực phẩm Việt Nam | `permitted` cho local/internal, revision đã gắn hash | Vẫn cần reviewer/phép tính trước khi dùng sản phẩm |
| Draft P2 + evidence | `permitted` làm đầu vào kỹ thuật | Vẫn là bản nháp; release gate tiếp tục chặn unresolved/reviewer |
| Hướng dẫn MOH | `unverified` | Đã được cho phép về chủ trương nhưng chưa có file/revision/hash để admission |
| USDA FoodData Central | `unverified candidate` | Đã được cho phép về chủ trương nhưng chưa chọn release/file/hash |
