# Báo cáo trạng thái FE Prototype — CareSitter Customer App

> Cập nhật: 27/06/2026  
> Phạm vi: Frontend prototype sử dụng Riverpod và dữ liệu local/mock. Chưa đánh giá là production-ready và chưa tính các tích hợp backend.

## 1. Tổng quan hiện tại

| Hạng mục | Trạng thái |
|---|---|
| Booking flow phía Customer | ✅ Demo được end-to-end bằng local state |
| Booking state machine | ✅ Đã có store dùng chung, không còn chỉ hiện Snackbar |
| Matching caregiver | ✅ Heuristic local theo dịch vụ, trạng thái rảnh, khu vực và rating |
| Thanh toán | ⚠️ Chỉ có booking demo và ví demo mô phỏng giữ tiền |
| Caregiver app/action | ⚠️ Được mô phỏng bằng các nút demo trong Customer app |
| GPS/check-in | ⚠️ Map và check-in mô phỏng |
| Doanh thu/thu nhập | ⚠️ Tính local 15%/85%, chưa phải ledger backend |
| Lưu dữ liệu | ⚠️ In-memory; khởi động lại app sẽ reset |
| `flutter analyze` | ✅ 0 error, 0 warning; còn 9 mức `info` |
| `flutter test` | ✅ 1/1 smoke test đạt |

## 2. Booking Flow 5.1 đối chiếu với code

| Bước | Nghiệp vụ | Trạng thái FE hiện tại | File chính |
|---:|---|---|---|
| 1 | Customer tạo hồ sơ người cần chăm sóc | ⚠️ Form và local store đã có; chưa nối store mới vào wizard/detail/edit | `beneficiary_create_screen.dart`, `beneficiary_store.dart` |
| 2 | Chọn dịch vụ, thời gian, địa chỉ | ✅ Wizard đúng thứ tự; kiểm tra lịch bắt đầu sau hiện tại tối thiểu 30 phút; có địa chỉ lưu sẵn/nhập tay | `booking_wizard_screen.dart` |
| 3 | Hệ thống lọc caregiver phù hợp | ✅ Heuristic local theo kỹ năng dịch vụ, `isAvailable`, khu vực và rating | `booking_wizard_screen.dart` |
| 4 | Customer chọn hoặc để hệ thống gợi ý caregiver | ✅ Có cả hai lựa chọn; hệ thống chọn người có điểm cao nhất | `booking_wizard_screen.dart` |
| 5 | Customer xác nhận consent form | ✅ Sáu mục điều khoản và checkbox bắt buộc | `booking_wizard_screen.dart` |
| 6 | Thanh toán hoặc xác nhận booking demo | ✅ FE có hai mode: booking demo và ví demo giữ tiền mô phỏng | `booking_wizard_screen.dart` |
| 7 | Caregiver nhận ca | ✅ Mô phỏng chuyển `pending → confirmed` | `booking_detail_screen.dart`, `booking_store.dart` |
| 8 | Caregiver di chuyển | ⚠️ Mới có giao diện theo dõi; chưa có trạng thái `en_route` riêng | `shift_tracking_screen.dart` |
| 9 | Caregiver check-in bằng GPS | ✅ Mô phỏng chuyển `confirmed → in_progress`; map vẫn là minh họa | `booking_detail_screen.dart`, `shift_tracking_screen.dart` |
| 10 | Checklist và timeline | ✅ Checklist theo loại dịch vụ, cập nhật local; timeline đọc cùng dữ liệu | `booking_store.dart`, `shift_tracking_screen.dart`, `care_timeline_screen.dart` |
| 11 | Caregiver yêu cầu checkout | ✅ Mô phỏng chuyển `in_progress → checkout_requested` và hoàn tất checklist | `booking_detail_screen.dart`, `shift_tracking_screen.dart` |
| 12 | Customer bấm “Đã hoàn thành” | ✅ Chỉ mở sau `checkout_requested`; có nhánh “Có vấn đề” | `booking_detail_screen.dart`, `shift_tracking_screen.dart` |
| 13 | Booking hoàn thành | ✅ Chuyển sang `completed`, ghi thời gian và số liệu tài chính mock | `booking_store.dart` |
| 14 | Customer đánh giá | ✅ Rating/tags/comment và cờ `isReviewed` lưu trong local state | `review_screen.dart`, `booking_store.dart` |
| 15 | Ghi nhận doanh thu/thu nhập | ✅ FE hiển thị doanh thu nền tảng 15% và thu nhập caregiver 85%; chưa có backend ledger | `booking_detail_screen.dart`, `booking_store.dart` |

## 3. State machine đang sử dụng

```text
pending
  ├─ caregiver nhận ca → confirmed
  └─ customer hủy     → cancelled

confirmed
  ├─ GPS check-in     → in_progress
  └─ customer hủy     → cancelled

in_progress
  ├─ caregiver yêu cầu kết thúc → checkout_requested
  └─ customer báo vấn đề        → disputed

checkout_requested
  ├─ customer bấm “Đã hoàn thành” → completed
  └─ customer báo vấn đề           → disputed

completed
  ├─ customer đánh giá → completed + isReviewed
  └─ khiếu nại         → disputed
```

Store từ chối các chuyển trạng thái không hợp lệ bằng `StateError`.

## 4. Các thay đổi chính đã có trong code

### Booking model và local state

- `MockBooking` có thêm ID liên kết beneficiary/caregiver/service, mode thanh toán, consent timestamp, checkout/completed timestamp, review, dispute, checklist và số liệu tài chính.
- `MockCareTask` biểu diễn checklist theo booking.
- `booking_store.dart` là nguồn dữ liệu dùng chung cho Home, danh sách booking, chi tiết, tracking, timeline, review và dispute.
- Tạo booking mới đã thêm booking thật vào local list thay vì chỉ hiện thông báo thành công.

### Booking wizard

- Thứ tự hiện tại: `Dịch vụ → Người thân → Lịch & địa chỉ → Caregiver → Đồng ý → Xác nhận`.
- Có kiểm tra thời gian, địa chỉ, matching caregiver, lựa chọn hệ thống gợi ý và mode booking demo.
- Khi đổi dịch vụ/lịch/địa chỉ, lựa chọn caregiver cũ được reset để tránh dùng kết quả matching sai.

### Tracking, checkout và tài chính

- Customer không thể hoàn thành ca khi booking mới ở `in_progress`.
- Nút “Đã hoàn thành” chỉ xuất hiện sau khi caregiver yêu cầu checkout.
- Nhánh “Có vấn đề” chuyển booking sang `disputed` và không ghi tài chính hoàn thành.
- Khi hoàn thành, FE ghi local `platformRevenue = 15%` và `caregiverEarning = 85%`.

### Hồ sơ người được chăm sóc

- Đã thêm `beneficiary_store.dart` và trường `address` vào model.
- Form tạo mới ghi dữ liệu vào local store; danh sách hồ sơ đọc từ store và cập nhật ngay.
- Phần này chưa hoàn tất tích hợp: wizard, detail và edit vẫn đang đọc `MockData.beneficiaries`.

## 5. Các giới hạn FE còn lại

| Mức độ | Vấn đề | Ảnh hưởng |
|---|---|---|
| Cao | Beneficiary store chưa nối vào wizard/detail/edit | Hồ sơ vừa tạo xuất hiện trong danh sách nhưng chưa chọn được khi tạo booking và chưa mở detail đúng |
| Trung bình | Chưa có trạng thái `en_route` | Không demo riêng được bước caregiver đang di chuyển |
| Trung bình | Local state không persist | Reload/restart app làm mất booking, review và dispute mới |
| Trung bình | Chỉ có một smoke test | Chưa tự động kiểm thử state transitions và matching |
| Thấp | Analyzer còn 5 info về dấu ngoặc và 4 info API `Radio` deprecated | Không chặn build nhưng nên dọn trước khi bàn giao |

## 6. Phần để backend triển khai sau

- OTP thật và quản lý phiên đăng nhập.
- Persist beneficiary/booking/review/dispute.
- Matching theo lịch rảnh thực tế, vùng phục vụ và chống double-booking.
- Push booking sang Caregiver app; accept/decline/timeout/rematch.
- GPS check-in theo bán kính và live tracking.
- Payment authorization/capture/refund.
- Tự động hoàn tất theo SLA nếu không có dispute.
- Ledger doanh thu/thu nhập idempotent và thời hạn giải ngân.
- Upload bằng chứng khiếu nại và thông báo realtime.

## 7. Kết quả kiểm tra

```text
flutter analyze
0 error, 0 warning, 9 info

flutter test
1 test passed
```

Kết luận: booking flow hiện đủ để trình diễn FE prototype theo happy path và các nhánh hủy/khiếu nại. Việc FE cần làm tiếp theo trước demo chính thức là nối hoàn chỉnh `beneficiaryStoreProvider` vào wizard/detail/edit và bổ sung test cho state machine.
