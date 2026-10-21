# CareSitter admin web

## Phát triển và kiểm tra

Chạy các lệnh sau trong thư mục source `frontend/admin-web`, không phải thư mục tài liệu `plan/frontend/admin-web`.

```powershell
npm ci
npm run dev
npm test
npm run build
```

Local mặc định gọi API tại `http://localhost:5033`; đổi bằng
`VITE_API_BASE_URL` khi cần. Bản production mặc định dùng cùng origin.
Xác thực và metadata vận hành lấy từ backend. Dữ liệu giả trong test
không được đưa vào ứng dụng.

## Quản lý ưu đãi — 06/10/2026

Trang **Ưu đãi** tại `#/promotions` đã nối API admin CRUD. Có tìm kiếm,
lọc trạng thái, phân trang tại server, tạo/xem/sửa/bật tắt/xóa, xem trước
nội dung, cấu hình mức giảm/thời gian/phạm vi/quota và thống kê sử dụng.

Chiến dịch mới mặc định tắt. Chiến dịch đã có lịch sử không được xóa hoặc
đổi điều kiện tính tiền. Form giữ edit token và thời điểm bắt đầu nguyên
chuỗi từ backend; dữ liệu cũ cần tải lại. Lỗi mã trùng và quota có thể sửa
rồi gửi lại mà không mất bản nháp. Tắt nhanh dùng cấu hình đã lưu.

Chi tiết API, quy tắc và cách chạy:
[Quản trị chiến dịch ưu đãi](../../backend/PROMOTION_ADMIN.md).

Kiểm tra trong lượt này:

- `npm test`: **56 test đạt**, 9 file.
- `npm run build`: đạt TypeScript và Vite production build.
- Backend: **25 unit Promotion, 32 integration được chọn, 30 architecture**
  đều đạt. Sáu integration test admin dùng database PostgreSQL tạm riêng,
  kiểm tra quyền HTTP, CRUD/audit, mã trùng, quota và xử lý đồng thời.
- Browser: 1440×1000, 900×1024, 390×844; đã xem danh sách/form/preview,
  rỗng và lỗi; kiểm tra tạo chiến dịch, Escape, không tràn trang và không
  có lỗi JavaScript. Đã sửa tràn ngang cột thao tác, điều hướng mobile
  bị dồn chữ, thêm mở chi tiết từ tên chiến dịch và tên truy cập cho icon.
- Browser dùng HTTP fixture chỉ cho QA. Đây chưa phải nghiệm thu trình
  duyệt với đăng nhập thật và dữ liệu production. API được kiểm tra riêng
  bằng TestServer và PostgreSQL thật. Chưa triển khai production.

## Hoàn thiện giao diện admin — 03/10/2026

Các thay đổi đã có trước phần Promotion:

- Đăng xuất thu hồi phiên backend trước khi xóa token trình duyệt. Lỗi
  mạng vẫn xóa token local và báo chưa xác nhận thu hồi remote. HTTP 403
  không làm hết phiên hợp lệ; 401 đến muộn từ token cũ không ảnh hưởng
  phiên đăng nhập mới.
- Sửa bảng giá giữ thời gian local và millisecond khi chuyển UTC. Giá
  hiện hành xét khoảng hiệu lực và quy tắc mới nhất đủ điều kiện.
- Hàng đợi phân trang bỏ phản hồi cũ, hủy request khi rời trang, đưa bộ lọc
  về trang 1 và phục hồi khi trang cuối mất dữ liệu. Lỗi tải có trạng thái
  lỗi riêng, không bị hiển thị thành hàng đợi rỗng thành công.
- Form checklist xóa bản nháp/định danh đang sửa khi đổi dịch vụ; có trạng
  thái rỗng/lỗi/thử lại, khóa thao tác xung đột và giữ policy đã lưu.
- Tranh chấp tải dữ liệu mới, yêu cầu phán quyết, kiểm số tiền hoàn một
  phần/chế tài và cho xem xác nhận phân bổ. Thắng toàn phần dùng phân bổ
  tự động của backend. Tính nguyên tử của settlement vẫn cần hoàn thiện.
- Hoàn tất booking yêu cầu tải được chi tiết, checklist và timeline.
  Xác nhận giải thích cửa sổ tranh chấp; người duyệt xem thời gian thực,
  công việc bắt buộc, lý do bỏ qua và bằng chứng.
- Đối soát thanh toán có xác nhận số tiền/booking. Duyệt payout mô tả duyệt
  hạch toán, chưa khẳng định ngân hàng đã chuyển tiền.
- KYC đếm tệp thực tế. Đổi role ADMIN yêu cầu xác nhận trong giao diện.
  Drawer giữ focus bàn phím và không đóng trong lúc lưu.
- Dashboard ưu tiên CRITICAL/HIGH khi gộp hàng đợi trước giới hạn 12 mục;
  hiển thị thời điểm dữ liệu và độ ưu tiên.

Bằng chứng lịch sử ngày 03/10, không thay thế bằng chứng Promotion mới:

- Vitest khi đó: **33 test đạt**, 6 file. HTTP response là fixture.
- Build TypeScript/Vite đạt; helper bảng giá đạt với
  `TZ=Asia/Ho_Chi_Minh` và `TZ=UTC`.
- `dotnet test backend/CareSitter.sln --configuration Release`:
  **199 test đạt, 0 bỏ qua**, gồm 14 test PostgreSQL trong database riêng.
  TRX: `backend/artifacts/admin-hardening-20261003/`.
- Login page đã được xem trên trình duyệt, không có lỗi console.
- Chưa triển khai. `vercel.json` ở root tắt Git deploy cho
  `feat/google-sign-in-account-chooser`; không tắt CLI deploy hay các nhánh khác.

## Phần còn cần hoàn thiện

1. Hủy tranh chấp và settlement: xác định việc rút tranh chấp hay kết quả
   tài chính; xử lý bền vững, phục hồi giữa Support/Payments/Booking và
   kiểm tra các quyết định đồng thời/lỗi giữa các bước. Hiện thao tác hủy
   chỉ đóng tranh chấp.
2. Payout: chọn chuyển thủ công có bằng chứng hoặc provider; tách duyệt
   khỏi xác nhận paid/failed; giữ nhất quán ledger, hoàn bút toán và retry.
3. Tìm kiếm/phân trang: booking vẫn tìm trên trang hiện tại; đối soát vẫn
   lọc trong tối đa 100 bản ghi đã tải. Promotion dùng tìm kiếm/phân trang
   server riêng và đã hoàn thiện trong lượt 06/10.
4. Quy trình vận hành: lịch sử/thông báo từ chối KYC; xử lý đồng thời,
   ghi chú/phân công ticket; liên kết dashboard đến bản ghi cụ thể; lịch
   ngày lễ và preview giá; bảo vệ admin cuối cùng và UI xem audit.
5. Nghiệm thu đầu cuối bằng tài khoản/dữ liệu đại diện trước khi triển khai.
   Test đạt xác nhận các trường hợp đã kiểm tra, chưa bao phủ mọi nghiệp vụ
   còn thiếu hoặc mọi giao dịch chuyển tiền thực tế.
