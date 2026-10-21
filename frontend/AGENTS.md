# Rule frontend bắt buộc

Trước khi viết hoặc sửa code/test Flutter trong `customer-app/` hoặc `caregiver-app/`:

1. Đọc toàn bộ [quy ước chung](../plan/QUY_UOC_CODE_VA_SECRET.md) trong tác vụ hiện tại.
2. Đọc toàn bộ [rule.frontend](../plan/frontend/RULE_FRONTEND.md) trong tác vụ hiện tại. Đọc lại khi tài liệu được cập nhật.
3. Kiểm tra ranh giới tầng, quyền sở hữu state, lifecycle phiên đăng nhập và test chịu tác động trước khi sửa.

Không bỏ qua rule vì source cũ chưa tuân thủ. Thay đổi mới phải tuân thủ; ghi rõ phần cũ còn lại trong báo cáo, không đánh dấu toàn app hoàn thành từ một đợt refactor.

Yêu cầu của người dùng được ưu tiên. Giữ thay đổi local đang có; Markdown chỉ lưu local, không stage/commit/push nếu chưa có yêu cầu riêng. Admin web và landing page tiếp tục theo quy ước chung và rule riêng trong thư mục của chúng.
