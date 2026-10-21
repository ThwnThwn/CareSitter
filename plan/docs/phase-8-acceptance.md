# Biên bản nghiệm thu Phase 8

Ngày nghiệm thu: 22/09/2026  
Phạm vi: luồng booking → thanh toán → nhận ca → checkout → giải ngân và các nhánh dispute/refund.

## Kết quả

Phase 8 đạt tiêu chí nghiệm thu tự động trên môi trường local với PostgreSQL thật:

- Luồng vàng domain đi xuyên suốt `DRAFT` → `PENDING_PAYMENT` → `CONFIRMED` → `CAREGIVER_ACCEPTED` → `CAREGIVER_EN_ROUTE` → `IN_PROGRESS` → `CHECKOUT_PENDING_REVIEW` → `COMPLETED`.
- Booking trùng lịch của cùng beneficiary bị chặn ở application layer và transaction-level guard PostgreSQL; database sạch còn có exclusion constraint.
- Payment callback, nhận ca, refund, payout, dispute và settlement có test retry/race; mỗi dòng tiền chỉ được ghi nhận một lần.
- Sau checkout, escrow chờ hết cửa sổ dispute 48 giờ mới được giải ngân. Dispute đang mở chặn settlement.
- `CUSTOMER_WINS`, `CAREGIVER_WINS` và `PARTIAL_REFUND` phân phối escrow có giới hạn, không tạo tiền ngoài escrow và không làm âm wallet.
- Customer chỉ được mở dispute cho booking thuộc sở hữu trong thời hạn và chỉ được review booking đã hoàn thành.

## Bằng chứng chạy test

| Gate | Kết quả |
| --- | --- |
| `backend/scripts/test-phase8.ps1` | 3/3 vòng đạt; mỗi vòng 18 passed, 0 failed, 0 skipped |
| Toàn bộ backend solution | 151 passed, 0 failed |
| Customer Flutter | analyze sạch; 26 passed |
| Caregiver Flutter | analyze sạch; 15 passed |
| Admin web | TypeScript và Vite production build đạt |
| API smoke sau migration local | health/live, health/ready, catalog và auth guard đều đạt |

Lệnh tái lập:

```powershell
powershell -ExecutionPolicy Bypass -File backend/scripts/test-phase8.ps1
```

Script tạo database PostgreSQL tạm cho từng vòng, chạy các contract/race test Phase 8 rồi tự xoá database. Migration `27-phase8-transaction-integrity.sql` được áp dụng trong fixture như khi dựng database mới.

Migration 27 cũng đã được áp dụng thành công vào database local. Database này có hai cặp booking legacy đang trùng lịch nên migration giữ nguyên dữ liệu, kích hoạt trigger/advisory-lock guard và bỏ qua riêng native exclusion constraint; mọi booking mới vẫn được bảo vệ khỏi xung đột đồng thời.

## Thay đổi kiểm soát chính

- Thêm `dispute_window_hours` và `settlement_released_at` cho booking.
- Thêm job giải ngân booking đủ hạn, chạy lặp an toàn mỗi 5 phút.
- Thêm workflow liên module cho mở/giải quyết dispute và chuyển trạng thái booking.
- Thêm transaction-level guard/constraint chống booking beneficiary trùng lịch cùng chỉ mục ledger phục vụ idempotency.
- Thêm kiểm tra ownership, role, thời hạn dispute và state transition.

Các kiểm thử VNPay sandbox, Cloudinary, SignalR, push notification và thiết bị thật thuộc Phase 9, không phải ngoại lệ của biên bản Phase 8 này.
