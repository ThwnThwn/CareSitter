  Bối Cảnh Chung

CARE4EVER / CareSitter là nền tảng kết nối gia đình có người cao tuổi cần hỗ trợ sinh hoạt tại nhà với caregiver (người chăm sóc - CSV) đã được xác minh.
Dịch vụ tập trung hoàn toàn vào chăm sóc phi y tế (hỗ trợ sinh hoạt hằng ngày ADL và IADL) như hỗ trợ ăn uống, vệ sinh cá nhân, nhắc uống thuốc (chỉ nhắc, không chia liều/chuẩn bị thuốc), đi lại nhẹ, trò chuyện, theo dõi lịch sinh hoạt. Nền tảng tuyệt đối không thực hiện thủ thuật y tế như tiêm truyền, kê đơn hoặc can thiệp điều trị.

Giá trị cốt lõi của hệ thống là tạo sự tin cậy (Trust), minh bạch (Transparency) và an toàn (Safety) giữa ba bên: gia đình, caregiver và nền tảng. Điều này được đảm bảo bằng KYC caregiver, thanh toán qua escrow nội bộ, GPS check-in/tracking, care timeline realtime, ảnh bằng chứng chụp live, xác nhận checkout từ người nhà, dispute window 48h và cơ chế xử lý SOS/Safety Alert.

1. Onboarding & KYC Caregiver

Ngữ cảnh: Một caregiver muốn tham gia nền tảng để nhận ca chăm sóc người cao tuổi tại nhà. Gia đình chỉ giao người thân khi caregiver đã được xác minh danh tính và năng lực.

Caregiver đăng ký tài khoản, nhập thông tin cá nhân, tải lên CCCD (được mã hóa), ảnh chân dung, giấy khám sức khỏe, lý lịch tư pháp và các chứng chỉ liên quan nếu có. Sau đó caregiver khai báo khu vực có thể nhận ca, kỹ năng chăm sóc và lịch rảnh.

Admin Operations kiểm tra hồ sơ. Nếu hợp lệ, caregiver được duyệt KYC (kyc_status = APPROVED) và có thể bắt đầu nhận booking. Nếu thiếu hoặc sai thông tin, hồ sơ bị từ chối kèm lý do để caregiver bổ sung. Caregiver chưa được duyệt KYC thì hệ thống sẽ không cho phép nhận bất kỳ ca nào.

2. Customer & Beneficiary Profile

Ngữ cảnh: Một người con muốn đặt dịch vụ chăm sóc cho cha/mẹ tại nhà.

Customer đăng ký hoặc đăng nhập bằng OTP, sau đó tạo hồ sơ người thụ hưởng (Beneficiary). Hồ sơ bao gồm thông tin hành chính, tình trạng sức khỏe, thuốc đang dùng, thói quen sinh hoạt, ghi chú chăm sóc, người liên hệ khẩn cấp và địa chỉ chăm sóc có tọa độ GPS.

Một customer có thể quản lý nhiều beneficiary. Dữ liệu sức khỏe là thông tin nhạy cảm (được mã hóa AES-256), chỉ caregiver được phân công ca mới được xem các thông tin cần thiết để thực hiện dịch vụ, không hiển thị đại trà.

3. Booking & Matching

Ngữ cảnh: Gia đình cần đặt một ca chăm sóc cụ thể cho người thân.

Customer chọn beneficiary, dịch vụ (theo giờ, nhắc vận động, trông ban đêm, định kỳ...), ngày giờ, thời lượng và địa chỉ chăm sóc. Hệ thống tính giá dựa trên gói dịch vụ, thời gian và phí nền tảng. Sau đó customer có thể tự chọn caregiver hoặc để hệ thống tự matching.

Nếu hệ thống matching, nền tảng sẽ ưu tiên caregiver gần vị trí chăm sóc (GPS), có kỹ năng phù hợp, còn lịch trống và có độ uy tín tốt.

Sau khi customer thanh toán thành công, booking được xác nhận và offer được gửi đến caregiver. Caregiver có thời gian giới hạn (vd 2 phút) để accept. Nếu từ chối hoặc hết hạn, hệ thống chuyển offer sang caregiver tiếp theo trong hàng đợi.

*Đặc biệt - Backup Dispatch:* Nếu caregiver đã nhận ca nhưng hủy sát giờ, no-show hoặc im lặng, hệ thống không hủy ca ngay mà gắn nhãn BACKUP_DISPATCH để tự động tìm caregiver thay thế (qua Sequential Offer hoặc Broadcast Pool) hoặc Admin can thiệp thủ công. Nếu không tìm được người thay hoặc khách không đồng ý, ca mới bị hủy và hoàn tiền.

4. Payment & Escrow

Ngữ cảnh: Gia đình cần thanh toán trước nhưng vẫn muốn được bảo vệ nếu ca chăm sóc không diễn ra đúng cam kết.

Customer thanh toán qua VNPAY, MOMO hoặc thẻ (trả trước online, không COD). Khi cổng thanh toán xác nhận thành công, tiền được ghi nhận vào Escrow (quỹ tạm giữ trên sổ cái nội bộ - ledger) của hệ thống. Booking chuyển sang trạng thái CONFIRMED.

Tiền chưa được giải ngân ngay cho caregiver. Nó được giữ lại trong Escrow cho đến khi ca hoàn tất và qua thời gian khiếu nại (Dispute Window). Mọi giao dịch đều được ghi nhận vào Ledger (sổ cái bất biến) và dùng idempotency_key để chống trừ tiền trùng.

5. Care Shift Execution

Ngữ cảnh: Caregiver đã nhận ca và bắt đầu thực hiện chăm sóc tại nhà.

Trước giờ làm, caregiver bấm bắt đầu di chuyển (bật tracking GPS). Khi đến nơi, caregiver check-in bằng GPS. Hệ thống chỉ cho phép bắt đầu ca nếu caregiver ở trong bán kính hợp lệ (geo-fencing 50m) từ địa chỉ chăm sóc.

Trong ca làm, caregiver thực hiện checklist công việc (ADL/IADL). Mỗi hoạt động được tick hoàn thành kèm timestamp, GPS và ghi chú lên care timeline để người nhà theo dõi real-time. Các task cần bằng chứng bắt buộc phải chụp ảnh live qua camera (không cho chọn từ thư viện) kèm metadata.

Khi kết thúc ca, caregiver gửi yêu cầu checkout. Hệ thống gửi thông báo cho Customer xác nhận (OTP không còn là luồng chính). Nếu Customer xác nhận, ca chuyển sang COMPLETED. Nếu Customer không phản hồi sau thời gian quy định (timeout) hoặc có bất thường (checkout quá sớm, rời geofence - Safety Alert), ca sẽ được chuyển sang CHECKOUT_PENDING_REVIEW để Admin xét duyệt.

6. Settlement & Payout

Ngữ cảnh: Ca chăm sóc đã hoàn tất, caregiver cần được ghi nhận thu nhập.

Sau khi booking COMPLETED, hệ thống tính phần doanh thu của caregiver (tổng tiền trừ phí nền tảng). Khoản này được ghi nhận vào pending balance (số dư chờ) trong ví caregiver.

Trong vòng 48 giờ (Dispute Window), nếu customer không khiếu nại và không có sự cố an toàn nào, tiền sẽ được tự động chuyển sang available balance (số dư khả dụng). Lúc này caregiver có thể tạo yêu cầu rút tiền (Payout) về tài khoản ngân hàng.

Kế toán duyệt yêu cầu payout. Nếu chuyển khoản thành công, trạng thái là PAID. Nếu lỗi ngân hàng, yêu cầu FAILED và tiền được hoàn lại ví để xử lý lại.

7. Cancellation & Refund

Ngữ cảnh: Một bên muốn hủy ca trước khi ca diễn ra hoặc trong quá trình điều phối.

Chính sách hủy được chia tier rõ ràng:
- Customer hủy sớm (trước 24h): hoàn 100%.
- Customer hủy sát giờ: hoàn một phần và có tính phí phạt.
- Caregiver hủy/no-show: hệ thống tìm Backup Dispatch. Nếu thất bại, Customer được hoàn 100%, và Caregiver bị ghi nhận giảm uy tín/phạt.

Refund được ghi nhận qua Ledger, booking chuyển sang CANCELLED hoặc REFUNDED. Không thể hủy ca theo luồng thông thường nếu ca đã IN_PROGRESS.

8. Dispute

Ngữ cảnh: Sau ca làm, customer không hài lòng hoặc cho rằng caregiver không thực hiện đúng cam kết.

Customer có thể mở khiếu nại trong vòng 48 giờ sau khi ca COMPLETED. Khi dispute được mở, tiền doanh thu của caregiver trong pending balance bị đóng băng. 
Hai bên cung cấp bằng chứng (care timeline, ảnh live, GPS, lịch sử chat). Admin điều tra và đưa ra phán quyết: Hoàn toàn cho khách (Customer Wins), Trả cho Caregiver (Caregiver Wins) hoặc Hoàn một phần (Partial Refund). Sổ cái sẽ được ghi nhận lại dựa trên phán quyết này.

9. SOS / Crisis & Vận hành CRM

Ngữ cảnh: Trong ca xảy ra tình huống khẩn cấp (người cao tuổi té ngã, khó thở, sự cố an toàn).

Caregiver hoặc người nhà bấm nút SOS. Booking lập tức chuyển sang trạng thái CRISIS, hệ thống tạo support ticket ưu tiên CRITICAL. Admin/CSKH tiếp nhận ngay lập tức, liên hệ người thân khẩn cấp và hướng dẫn gọi 115 nếu cần. CareSitter chỉ báo động và điều phối, không trực tiếp can thiệp y khoa.

Về phía nền tảng, có một hệ thống CRM Admin Operations Panel dành riêng cho Admin, CSKH, và Kế toán để giám sát toàn bộ hoạt động:
- Dashboard KPI: Giám sát real-time các ca, đặc biệt là CRISIS.
- Customer 360: Quản lý hồ sơ khách hàng.
- KYC: Xét duyệt hồ sơ Caregiver.
- Live Dispatch: Điều phối ca theo bản đồ trực tiếp, xử lý Backup Dispatch.
- Dispute Center & Sổ cái: Xử lý khiếu nại và quản lý dòng tiền/payout.

Happy Path Tổng Quát

Customer tạo hồ sơ người thân → đặt lịch chăm sóc → thanh toán vào escrow → hệ thống matching caregiver → caregiver accept → caregiver bắt đầu di chuyển → đến nơi và GPS check-in (bán kính 50m) → thực hiện checklist chăm sóc & cập nhật timeline bằng ảnh live → CSV yêu cầu checkout → Customer xác nhận → booking COMPLETED → chờ 48h dispute window → tiền chuyển sang available balance → giải ngân cho caregiver → caregiver rút tiền (Kế toán duyệt).
