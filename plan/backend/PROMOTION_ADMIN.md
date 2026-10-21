# Quản trị chiến dịch ưu đãi

Cập nhật: 06/10/2026. Phần Promotion admin đã có API và giao diện
trong admin web. Tài liệu mô tả hành vi của mã nguồn hiện tại.

## Sử dụng trên admin web

Đăng nhập bằng tài khoản có role `ADMIN`, mở **Ưu đãi** trong menu hoặc
`#/promotions`. API local mặc định là `http://localhost:5033`; có thể đổi
bằng `VITE_API_BASE_URL`.

- Danh sách tìm kiếm theo mã/tên, lọc trạng thái và phân trang tại server.
- Tạo/sửa nội dung, nhãn, mô tả, điều khoản, mức giảm, thời gian, phạm vi
  dịch vụ, giới hạn tổng lượt/mỗi khách, độ ưu tiên và trạng thái nổi bật.
- Chiến dịch mới mặc định tắt trên giao diện; bật khi đã kiểm tra cấu hình.
- Xem trước nội dung khách hàng sẽ thấy, cùng lượt đã dùng/đang giữ/đã
  giải phóng. Đây là preview nội dung; tính giá thực tế dùng API preview
  khách hàng và luồng booking hiện có.
- Bật/tắt nhanh dùng cấu hình đã lưu, không lưu bản nháp đang nhập.
- Xóa yêu cầu xác nhận trong giao diện và chỉ áp dụng khi chưa có lịch sử.
- Lỗi mã trùng hoặc giới hạn lượt có thể sửa rồi gửi lại; dữ liệu cũ do
  người khác thay đổi cần tải bản mới trước khi tiếp tục.

Thời gian trên form theo múi giờ thiết bị; request gửi UTC. Edit token
`updatedAt` phải được gửi nguyên chuỗi từ response, tránh mất độ chính
xác microsecond của PostgreSQL.

## API

Tất cả endpoint dưới đây yêu cầu JWT có role `ADMIN`. Chưa đăng nhập
nhận HTTP 401; CUSTOMER/CAREGIVER nhận HTTP 403.

| Phương thức | Đường dẫn | Kết quả |
| --- | --- | --- |
| GET | `/api/v1/admin/promotions` | Danh sách có phân trang, kể cả chiến dịch tắt/chưa bắt đầu/hết hạn |
| GET | `/api/v1/admin/promotions/{id}` | Chi tiết cấu hình và thống kê sử dụng |
| POST | `/api/v1/admin/promotions` | Tạo chiến dịch, HTTP 201 và header Location |
| PUT | `/api/v1/admin/promotions/{id}` | Cập nhật đầy đủ cấu hình, HTTP 200 |
| PATCH | `/api/v1/admin/promotions/{id}/active` | Bật/tắt, HTTP 200 |
| DELETE | `/api/v1/admin/promotions/{id}` | Xóa chiến dịch chưa có lịch sử, HTTP 204 |

Tham số danh sách: `search` tối đa 160 ký tự, `status` là
`ACTIVE`/`SCHEDULED`/`EXPIRED`/`INACTIVE` hoặc bỏ trống;
`page` mặc định 1; `pageSize` mặc định 20, tối đa 100.
Response có `items`, `total`, `page`, `pageSize`.

Ví dụ body tạo chiến dịch:

```json
{
  "code": "CARE10",
  "title": "Ưu đãi chăm sóc",
  "summary": "Giảm 10% cho ca chăm sóc đủ điều kiện",
  "description": "Áp dụng trong thời gian chiến dịch",
  "badgeText": "Giảm 10%",
  "terms": ["Đơn từ 200.000 đ", "Mỗi khách tối đa 2 lượt"],
  "discountType": "percentage",
  "discountValue": 10,
  "maxDiscountAmount": 100000,
  "minOrderAmount": 200000,
  "startsAt": "2026-10-10T01:00:00Z",
  "endsAt": "2026-11-01T16:59:59Z",
  "isActive": false,
  "firstPaidBookingOnly": false,
  "totalUsageLimit": 100,
  "perCustomerUsageLimit": 2,
  "priority": 1,
  "isFeatured": true,
  "eligibleServiceIds": []
}
```

- `discountType`: `percentage` (1–100) hoặc `fixed_amount` (VND).
- Số tiền là số nguyên, không vượt `Number.MAX_SAFE_INTEGER` để UI và API
  dùng cùng giá trị. Mức giảm dương; đơn tối thiểu không âm.
- `maxDiscountAmount` và `totalUsageLimit` nhận `null` nếu không giới hạn.
- `eligibleServiceIds: []` áp dụng mọi dịch vụ. Dịch vụ được thêm vào
  phạm vi phải tồn tại và đang hoạt động.
- Mã chuẩn hóa thành chữ hoa, dài 1–50 ký tự gồm chữ/số/`_`/`-`.
  Mã đã tồn tại nhận HTTP 409, kể cả khi tạo đồng thời.
- Điều khoản tối đa 20 mục, mỗi mục tối đa 500 ký tự. Tên tối đa 160,
  tóm tắt 300, nhãn 50 và mô tả 10.000 ký tự.

PUT dùng cùng body và thêm `expectedUpdatedAt` từ response mới nhất.
PATCH có body `{"isActive":false,"expectedUpdatedAt":"..."}`;
DELETE có body `{"expectedUpdatedAt":"..."}`. Thiếu token nhận HTTP 400,
token cũ nhận HTTP 409 với mã `promotion.stale`.

## Giữ nhất quán với booking

1. Reserve và các thao tác admin dùng cùng khóa hàng chiến dịch
   `SELECT ... FOR UPDATE`; lượt mới không chen vào lúc giảm quota hoặc xóa.
2. Quota tính redeemed và reserved còn hạn. Không giảm tổng giới hạn dưới
   số lượt này; không giảm giới hạn mỗi khách dưới số lượt của bất kỳ khách.
3. Khi đã có bất kỳ lịch sử redemption nào, không đổi mã, loại/mức giảm,
   mức giảm tối đa, đơn tối thiểu, thời điểm bắt đầu, điều kiện booking
   thanh toán đầu tiên hoặc danh sách dịch vụ. Tạo chiến dịch mới nếu cần
   đổi các điều kiện đó. Nội dung, kết thúc, quota, ưu tiên và trạng thái
   vẫn được cập nhật theo các kiểm tra trên.
4. Lượt đã release hoặc reserved hết hạn cũng được giữ làm lịch sử; vì
   vậy một chiến dịch có thể hiện 0 lượt đang giữ nhưng vẫn không được xóa.
5. Tắt chiến dịch chặn reserve mới; lượt giữ hiện có vẫn redeem/release
   bình thường. Giá đã snapshot trong booking không bị sửa bởi admin.
6. Các thao tác thành công ghi audit `ADMIN_PROMOTION_CREATED`,
   `ADMIN_PROMOTION_UPDATED`, `ADMIN_PROMOTION_ACTIVE_CHANGED` và
   `ADMIN_PROMOTION_DELETED`, kèm dữ liệu trước/sau.

Luồng thanh toán hiện chưa hỗ trợ ưu đãi khiến số tiền thanh toán bằng 0.
Quy tắc này tiếp tục được kiểm tra trong preview/reserve.

## Cấu trúc triển khai

HTTP DTO nằm trong `Promotion/Controllers/Contracts`; mapper và controller
chuyển sang command/query. Application dùng `IPromotionAdminStore`,
validation behavior và MediatR. Domain giữ `PromotionConfiguration`
và quy tắc cấu hình; Infrastructure giữ truy vấn, transaction và khóa.
Catalog được gọi qua Contracts, không tham chiếu module trực tiếp.

Sử dụng ba bảng migration 29: `promotion.promotions`,
`promotion.promotion_service_scopes`, `promotion.promotion_redemptions`.
Không có migration mới. Cần chạy lại API để nạp controller/metadata mới,
và tải lại hoặc build lại admin web.

## Kiểm tra đã chạy

- Unit Promotion: **25/25**.
- Integration theo phạm vi: **32/32**, gồm **6 test Promotion admin** trên
  PostgreSQL thật trong database tạm riêng và test hồi quy liên quan.
- Architecture: **30/30**.
- Admin web: Vitest và build TypeScript/Vite đạt; kết quả mới nhất ghi trong
  [README admin web](../frontend/admin-web/README.md).
- Browser: desktop 1440×1000, tablet 900×1024, mobile 390×844; đã xem
  danh sách/form/preview/rỗng/lỗi, kiểm tra không tràn trang, tạo chiến
  dịch, đóng bằng Escape và không có lỗi JavaScript.

Browser dùng HTTP fixture chỉ trong kiểm thử; ứng dụng không chứa dữ liệu
giả. Quyền HTTP, CRUD, audit và xử lý đồng thời được kiểm tra riêng bằng
TestServer cùng PostgreSQL. Chưa triển khai production trong lượt này.
