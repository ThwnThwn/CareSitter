# Bàn giao thiết kế Stitch sang Flutter cho PRM323 Lab 2

Ngày đối chiếu lịch sử: 14/10/2026. **Rà soát bổ sung: 17/10/2026.** Tài liệu này mô tả **đích thiết kế** và chênh lệch với source local; chưa phải xác nhận các màn Stitch đã được đưa vào Flutter. Project hiện tại là [Stitch CareSitter](https://stitch.withgoogle.com/projects/16914427060621528532). Bộ màn và sáu phần spec cho từng màn nằm trong [bảng đối chiếu Lab 2](frontend/stitch/PRM323_LAB2_DOI_CHIEU.md).

## Bảng ánh xạ token

| Token thiết kế Stitch đích | Giá trị | Vị trí Flutter dự kiến | Trạng thái source hiện tại |
| --- | --- | --- | --- |
| Primary CareSitter | `#006B5B` | `AppColors.primary`, `ColorScheme.primary` | Customer local còn `#496534`; cần đồng bộ khi triển khai thiết kế |
| On primary | `#FFFFFF` | `AppColors.onPrimary`, `ColorScheme.onPrimary` | Đã có màu trắng tương ứng |
| Background giấy kem | `#F5F3EE` | `AppColors.background`, `ScaffoldTheme` | Customer local còn `#F8F9EF` |
| Surface card | `#FFFFFF` | `ColorScheme.surface` / token card | Customer local dùng nền gần background; cần xét từng component |
| Mint nhẹ | `#D3E8E1` | `AppColors.primaryContainer` / surface phụ | Customer local còn `#DDE7CE`; cần đồng bộ theo Stitch hiện tại |
| Ink | `#0D1117` | `AppColors.textPrimary` / text theme | Customer local còn `#273126` |
| Error | `#B42318` | `AppColors.error`, `ColorScheme.error` | Đã có token cùng giá trị |
| Font app theo Stitch | `Be Vietnam Pro` | `AppTheme` và `TextTheme` sau khi được duyệt | Customer local còn Inter; chưa tự đổi code, cần approval trước khi triển khai |

Không ghi rằng Figma Variables đã kết nối đến Flutter hoặc thay token sẽ tự cập nhật toàn bộ app; phải kiểm chứng sau khi áp dụng source và component instances.

## Bảng ánh xạ component

| Component trong thiết kế | Widget Flutter phù hợp | State/giới hạn cần bàn giao |
| --- | --- | --- |
| Nút chính/phụ | `FilledButton`, `OutlinedButton`, các wrapper theme hiện có | Default, loading/disabled, focus, lỗi gửi lại; vùng chạm tối thiểu 48 × 48 dp |
| Ô nhập có label | `TextFormField` và widget form của feature | Default, focus, validation, disabled; không dùng placeholder thay label |
| Card lịch/người chăm sóc/món | `Card` hoặc widget feature hiện có | Empty/loading/data/error; không lặp số liệu minh họa như dữ liệu thật |
| App bar và Back | `AppBar`, `BackButton`/router hiện có | Trở về đúng màn trước, không làm mất draft không chủ ý |
| Bottom navigation Customer | `ShellScaffold` và thanh điều hướng hiện có | Trang chủ, Lịch hẹn, Chăm sóc viên, Hồ sơ; action Đặt lịch giữa |
| Dialog/sheet | `AlertDialog`, `showModalBottomSheet`/widget hiện có | Đóng được, trả đúng trạng thái; sheet không tính thành màn final riêng trong Lab 2 |
| Loading, empty, error | Widget trạng thái riêng theo feature | Loading không dùng tiến độ giả; lỗi có retry an toàn; empty có lối ra |
| Bản đồ tracking | Abstraction bản đồ và realtime hiện có | Mất quyền/vị trí cũ/không kết nối; không tự tạo marker minh họa trong dữ liệu thật |

## Handoff cho từng màn

Theo file hướng dẫn Lab 2, mỗi màn phải có **layout, components, states, interactions, navigation, UI constraints**. Bảng spec đầu tiên cho các màn trình diễn nằm ở [PRM323_LAB2_DOI_CHIEU.md](frontend/stitch/PRM323_LAB2_DOI_CHIEU.md). Cần gắn mỗi spec với đúng frame Figma Final UI và instance trước khi ghi “Ready for Dev”. Hiện chưa có đối chiếu Figma này.

Không yêu cầu viết Flutter code mới để hoàn thành Lab 2. Khi triển khai thật, dùng route và controller/repository hiện có, kiểm DTO/state/permission theo source; không lấy HTML hoặc số liệu Stitch làm hợp đồng API.
