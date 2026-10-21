# Sitemap và mapping màn hình CareSitter — PRM323 Lab 2

**Rà soát:** 17/10/2026  
**Phạm vi:** Customer app; Caregiver/Admin là bối cảnh phụ, không trộn vào sitemap đánh giá chính.  
**Nguồn prototype:** [Stitch Project 16914427060621528532](https://stitch.withgoogle.com/projects/16914427060621528532)  
**Nguồn flow:** [user-flow.md](user-flow.md) và [đối chiếu Lab 2](../frontend/stitch/PRM323_LAB2_DOI_CHIEU.md)

> Đây là sitemap và mapping hồ sơ dùng để chuẩn bị Figma. Nó chưa chứng minh các frame đã được sắp đúng 6 page Figma hoặc prototype đã nối chạy.

## 1. Cấu trúc điều hướng

```text
Customer App
├── Trang chủ (C-HOME)
│   ├── Đặt lịch
│   ├── Ca sắp diễn ra
│   └── Lịch hẹn gần đây
├── Lịch hẹn (C-BOOK-LIST)
│   ├── Chi tiết lịch (C-BOOK-DETAIL)
│   ├── Thanh toán (C-PAY-METHOD)
│   ├── Kết quả thanh toán (C-PAY-RESULT)
│   ├── Theo dõi ca (C-TRACKING)
│   ├── Nhật ký/timeline (C-TIMELINE)
│   └── Đánh giá/khiếu nại (C-REVIEW / C-DISPUTE)
├── Chăm sóc viên (C-CAREGIVER-LIST)
│   └── Chi tiết người chăm sóc (C-CAREGIVER-DETAIL)
└── Hồ sơ (C-PROFILE)
    └── Người được chăm sóc (C-BEN-LIST)
        ├── Chi tiết hồ sơ (C-BEN-DETAIL)
        └── Nutrition
            ├── Tổng quan (C-NUT-OVERVIEW)
            ├── Cập nhật dữ liệu (C-NUT-UPDATE)
            ├── Kiểm tra (C-NUT-CHECK)
            ├── Bữa ăn trong ngày (C-NUT-07)
            ├── Đổi món (C-NUT-09)
            └── Lịch sử đã lưu (C-NUT-11)
```

## 2. Mapping tối thiểu 8 màn hình đại diện

| # | Mã màn hình | Tên | Flow | Vai trò trong tác vụ | Trạng thái cần có |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `C-HOME` | Trang chủ | F1/F2 | Điểm bắt đầu đặt lịch và xem ca | loading, empty, data, error |
| 2 | `C-BOOK-01` | Chọn dịch vụ | F1 | Chọn loại hỗ trợ và thời lượng | chưa chọn, đã chọn, lỗi tải |
| 3 | `C-BOOK-02` | Người được chăm sóc | F1 | Chọn bản thân/người thân | rỗng, chọn, tạo mới, lỗi |
| 4 | `C-BOOK-03` | Ngày giờ/địa chỉ | F1 | Chọn ngày, giờ, địa điểm | thiếu dữ liệu, khả dụng, lỗi |
| 5 | `C-BOOK-04` | Người chăm sóc | F1 | Chọn Caregiver phù hợp | loading, empty, selected |
| 6 | `C-BOOK-06` | Xác nhận đặt lịch | F1 | Kiểm tra thông tin trước khi gửi | chưa đồng ý, gửi, lỗi |
| 7 | `C-PAY-RESULT` | Kết quả thanh toán | F1 | Hiển thị success/pending/fail/cancel | 4 trạng thái thanh toán |
| 8 | `C-TRACKING` | Theo dõi ca | F2 | Theo dõi check-in và kết nối | live, offline, vị trí cũ, lỗi |
| 9 | `C-TIMELINE` | Nhật ký ca | F2 | Xem hoạt động và ảnh minh chứng | loading, có dữ liệu, empty, lỗi |
| 10 | `C-BEN-DETAIL` | Chi tiết người được chăm sóc | F3 | Kiểm tra dữ liệu gia đình | đủ dữ liệu, thiếu dữ liệu, cần hướng dẫn |
| 11 | `C-NUT-07` | Bữa ăn trong ngày | F3 | Xem thực đơn sinh hoạt | có món, không có món, thay món |
| 12 | `C-NUT-09` | Đổi món | F3 | Chọn thay thế không vi phạm dị ứng | có lựa chọn, không có lựa chọn, retry |

## 3. Quy tắc đếm màn hình

- Chỉ tính artboard Final UI khác nhau; không tính riêng dialog, sheet, loading/error variant hoặc bản copy.
- Mỗi màn phải có link tới frame Figma và được gắn vào ít nhất một flow.
- Mỗi flow phải có start, goal, end, alternate path và error/recovery path.
- `C-PAY-RESULT` không được tự báo thành công từ return URL; trạng thái phải đến từ backend/provider.
- Nutrition chỉ dùng thông tin do gia đình cung cấp để tránh món/nguyên liệu không phù hợp; không biến thành chẩn đoán hay thực đơn điều trị.

## 4. Tình trạng minh chứng

| Minh chứng | Tình trạng |
| :--- | :--- |
| Sitemap và mapping ≥8 mã màn | Có trong file này |
| Frame Final UI trong Figma | Chưa có link Figma để xác nhận |
| Prototype nối đủ 3 flow | Chưa xác minh trực tiếp |
| Back, overlay và loading → result | Có yêu cầu và mã trạng thái; cần kiểm trên prototype |
| Responsive 360/412 dp | Theo dõi trong [responsive/accessibility evidence](../prm/PRM393_RESPONSIVE_ACCESSIBILITY_EVIDENCE.md) |
