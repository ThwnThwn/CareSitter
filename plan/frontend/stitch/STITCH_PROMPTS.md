# Prompt sắp xếp CareSitter và bổ sung Nutrition trên Stitch

> Cập nhật: 14/10/2026. Phạm vi: prompt theo luồng source hiện tại, Customer/Nutrition ưu tiên trước. Đã mở project và gửi yêu cầu sang Stitch. Người dùng yêu cầu mới “xài màu giống landing page”: palette thiết kế Customer/Nutrition đổi sang teal của Landing; code Customer còn olive. Lưu local, chưa commit/push. Dùng cùng [DESIGN.md](DESIGN.md).

> **Yêu cầu mới thay thế phần nội dung sức khỏe của các prompt cũ:** người dùng cho phép liệt kê **bệnh lý đã biết do gia đình cung cấp** trong Nutrition để tránh gợi ý món/nguyên liệu không phù hợp. Giữ dị ứng và ghi chú chuẩn bị món. Không dùng lại phần thuốc/liều, nuốt/đường nuôi ăn, nước/điện giải, chẩn đoán hoặc thực đơn trị bệnh của các prompt lịch sử bên dưới. Xem [bảng kiểm tra màn hình](KIEM_TRA_MAN_HINH_PHI_Y_TE.md), [hệ thống thiết kế](DESIGN.md) và [đối chiếu PRM323 Lab 2](PRM323_LAB2_DOI_CHIEU.md).

Project Stitch đã được người dùng cung cấp trong hội thoại: `https://stitch.withgoogle.com/projects/9685887642498274590`. Mở project đó và gửi ba prompt theo thứ tự. Không cần tạo project mới.

## 1. Prompt sắp xếp màn hình hiện có

```text
Bạn đang làm việc trong project CareSitter hiện có. Hãy rà toàn bộ màn hình trên canvas, giữ các thiết kế đang có, đặt tên và sắp xếp theo hành trình sử dụng. Ưu tiên Customer và nhánh Nutrition; các nhóm Caregiver, Landing, Admin được đặt thành khu vực riêng.

Trước khi sinh màn hình, lập bảng đối chiếu gồm tên frame đang có → vai trò trong flow → số thứ tự mới → đủ / cần bổ sung / trùng. Chỉ kết luận thiếu sau khi kiểm tra canvas thực tế. Khi màn đã có đúng vai trò, dùng lại; biến thể trùng đưa vào Archive, không xóa. Giữ logo, ảnh, bố cục và component tốt của UI hiện có.

Quy ước tên: LP-xx cho Landing, C-AUTH-xx cho auth Customer, C-HOME-xx, C-BOOK-xx, C-CARE-xx, C-PROFILE-xx, C-NUT-xx cho Nutrition, CG-xx cho Caregiver, A-xx cho Admin. Nhánh trạng thái có hậu tố -LOADING, -EMPTY, -ERROR, -STALE. Mã chỉ là tên frame/chú thích thiết kế, không in mã kỹ thuật vào UI cho khách.

Đặt từng nhóm thành một hàng/khu vực có tiêu đề, màn chính từ trái sang phải, nhánh phụ nằm ngay dưới màn cha. Tạo trang Flow Map chỉ ra các entry point, CTA, back và các nhánh. Nếu môi trường hỗ trợ liên kết prototype, nối các hành động chính; nếu không, ghi rõ màn đích cạnh từng hành động.

Thứ tự cần đối chiếu:

1) Landing:
Landing desktop và mobile → Gửi yêu cầu tư vấn → Đã nhận yêu cầu; cạnh form có biến thể lỗi/gửi lại. Form tư vấn gồm họ tên, điện thoại, loại hỗ trợ, ngày dự kiến, thời lượng, ghi chú tùy chọn và đồng ý được liên hệ. Gửi tư vấn chưa phải đặt lịch thành công hay đã thanh toán.

2) Customer — xác thực và vào app:
Đăng nhập email/điện thoại và mật khẩu (có Ghi nhớ đăng nhập) → Đăng ký/xác thực email/OTP ở nhánh phù hợp → Giới thiệu thương hiệu → Trang chủ. Quên mật khẩu và khôi phục là nhánh riêng; không biến OTP đăng nhập thành OTP khôi phục.

3) Customer — đặt lịch:
Trang chủ / Danh mục dịch vụ → Chọn dịch vụ → Chọn người được chăm sóc (Bản thân hoặc Người thân) → Chọn ngày, giờ và địa chỉ → Chọn chăm sóc viên → Điều khoản và đồng ý → Kiểm tra/xác nhận đặt lịch → Chi tiết lịch chờ thanh toán → Chọn phương thức thanh toán → Trang thanh toán bên ngoài → Kết quả thanh toán → Chi tiết lịch.
Giữ đúng thứ tự sáu bước wizard này. Có nhánh thành công, đã hủy thanh toán, đang đối soát và thất bại. Sau hủy thanh toán người dùng trở về đúng lịch; không coi hủy thanh toán là hủy lịch. Nếu chỉ mất phản hồi, giữ trạng thái đang kiểm tra và không khuyến khích tạo lịch/giao dịch trùng. payOS/VNPAY chỉ được chọn khi khả dụng; không vẽ lại trang ngân hàng/provider như một màn CareSitter.

4) Customer — lịch và chăm sóc:
Danh sách lịch → Chi tiết lịch → Theo dõi vị trí / Timeline ca → Xác nhận kết thúc → Đánh giá; Khiếu nại là nhánh từ chi tiết lịch. Có trạng thái chờ thanh toán, sắp tới, đang diễn ra, hoàn thành, đã hủy. Bản đồ có nhánh vị trí chưa cập nhật hoặc mất quyền, không hiển thị tọa độ giả.

5) Customer — chăm sóc viên:
Danh sách/lọc chăm sóc viên → Chi tiết chăm sóc viên → Đặt lịch với người đã chọn.

6) Customer — hồ sơ và tài khoản:
Hồ sơ tài khoản → Danh sách người thụ hưởng → Tạo hồ sơ / Chi tiết hồ sơ / Chỉnh sửa hồ sơ → Gợi ý thực đơn (nhánh C-NUT).
Các nhánh tài khoản: sửa thông tin cá nhân, địa chỉ đã lưu, đổi mật khẩu, email khôi phục, ví/lịch sử giao dịch, thông báo/cài đặt thông báo, FAQ và hỗ trợ. Không tạo thêm bản sao hồ sơ sức khỏe riêng cho Nutrition.
Bottom navigation Customer giữ Trang chủ, Lịch hẹn, Chăm sóc viên, Hồ sơ, cùng action Đặt lịch mới ở giữa. Nutrition đi từ hồ sơ người thụ hưởng, không thêm tab Nutrition độc lập trong đợt này.

7) Caregiver, bố trí riêng:
Đăng nhập/OTP/Đăng ký → Thiết lập hồ sơ → Hồ sơ/giấy tờ xác minh → Trang chủ và trạng thái nhận việc → Danh sách ca → Chi tiết ca → Bản đồ đến địa điểm → Check-in → Ca đang diễn ra/checklist → Check-out → Tổng kết ca → Báo cáo cho khách.
Nhánh: lịch rảnh, thu nhập, yêu cầu rút tiền, thông báo, sửa hồ sơ, giấy tờ/upload, đánh giá, email khôi phục/quên mật khẩu, FAQ và hỗ trợ. Giữ hai vai trò Customer/Caregiver tách nhau.

8) Admin desktop, bố trí riêng:
Đăng nhập → Tổng quan → Lịch hẹn → KYC → Thanh toán → Hỗ trợ (gồm tab Yêu cầu tư vấn) → Tranh chấp → Dịch vụ → Khuyến mãi → Người dùng. Đây là nhóm điều hướng, không ép thành wizard tuần tự. Dùng lại các bảng và panel hiện có.

Theme theo source hiện tại:
- Customer/Nutrition theo yêu cầu mới: teal #006B5B, teal đậm #004F43, hover #00806D, nền giấy kem #F5F3EE, card/input #FFFFFF, mint #E6F4F1, chữ #0D1117, chữ phụ #536471, viền #E2DDD5, warning #A43F16 trên #FFF0E8, error #B42318 trên #FDE5E2. Giữ font sans-serif của app và hỗ trợ tiếng Việt. Đây là palette thiết kế đích, code Customer chưa đổi từ olive.
- Landing/Caregiver: giữ teal #006B5B, nền #F5F3EE, mint #E6F4F1, chữ #0D1117. Admin giữ theme Admin đang có. Không tự đổi toàn bộ project sang một theme mới.

Kết quả lần này: một canvas dễ đọc theo các khu vực trên, bảng frame đủ/thiếu và Flow Map. Sau bước sắp xếp, ưu tiên bổ sung Nutrition theo yêu cầu tiếp theo; không tạo hàng loạt trang mới chưa được đặc tả.
```

## 2. Prompt bổ sung các màn Nutrition chính

```text
Tiếp tục trong project CareSitter vừa sắp xếp. Hãy bổ sung các frame còn thiếu cho Nutrition của Customer, dùng lại frame/component đã có nếu đủ vai trò. Thiết kế mobile 390 × 844, kiểm tra 320 và 430 px. Dùng palette Landing theo yêu cầu mới: teal #006B5B, nền kem #F5F3EE, mint #E6F4F1, card/input trắng, chữ #0D1117 và chữ phụ #536471; font sans-serif, body khoảng 16 px, target bấm tối thiểu 44 px. Đây là product UI chăm sóc tại nhà, ưu tiên rõ và dễ đọc.

Nutrition gắn vào hồ sơ người thụ hưởng đã có (Bản thân hoặc Người thân), entry từ Chi tiết hồ sơ → Gợi ý thực đơn. Mọi màn phải hiện đúng tên/ảnh người đang được chọn. Không tạo lại họ tên, ngày sinh, địa chỉ như onboarding Nutrition mới. Giữ các thông tin có sẵn và chỉ hỏi phần cần bổ sung.

Đặt nhánh chính trái sang phải theo thứ tự sau. Các frame là thiết kế bước/trạng thái/sheet của một flow; không cần giả định mỗi frame có một route độc lập:

C-NUT-01 — Tổng quan dinh dưỡng theo hồ sơ:
App bar, tên người đang chọn, tóm tắt tình trạng dị ứng/bệnh lý/thuốc và thông tin cần kiểm tra. CTA Kiểm tra thông tin; link Xem thực đơn đã lưu; action Cập nhật thông tin sức khỏe. Nếu trường nào chưa rõ, ghi Chưa rõ, không giả định là không có. Dùng nội dung gợi ý ăn uống, không đặt nhãn chẩn đoán/điều trị.

C-NUT-02 — Cập nhật phần sức khỏe liên quan:
Form có dữ liệu đã lưu, chia nhóm Dị ứng thực phẩm, Bệnh lý đã được thông báo, Thuốc và nhu cầu ăn uống, Lưu ý/hướng dẫn hiện có. Có thể tạo các state/section frame để xem form dài rõ hơn, thay vì ép toàn bộ vào màn 844 px.
Dị ứng: Chưa rõ / Có dị ứng thực phẩm / Đã xác nhận không có; khi có thì nhập thực phẩm cụ thể.
Bệnh lý: Chưa rõ / Có thông tin bệnh lý / Gia đình xác nhận chưa có bệnh lý; khi có thì nhập thông tin đã được thông báo, không yêu cầu tự chẩn đoán.
Thuốc: Chưa rõ / Đã xác nhận không dùng / Đang dùng thuốc. Mỗi thuốc có tên, liều đã được hướng dẫn (nếu có), trạng thái Đang dùng / Đã ngừng / Chưa rõ; có Thêm thuốc và Bỏ mục thuốc.
Cách ăn uống: Chưa rõ / Qua miệng / Qua ống. Khả năng nuốt: Chưa rõ / Không có khó khăn đã biết / Có khó khăn. Hạn chế nước và hướng dẫn điện giải: Chưa rõ / Đã xác nhận không có / Có hướng dẫn riêng.
Lưu ý sức khỏe và hướng dẫn chăm sóc/ăn uống là ghi chú tùy chọn, không bắt nhập lại. CTA Lưu thông tin cập nhật; khi có sửa chưa lưu, chặn phân tích/xác nhận/gợi ý dựa vào dữ liệu cũ và chỉ rõ cần lưu trước.

C-NUT-03 — Đang kiểm tra/phân tích:
Biến thể Đang chờ phân tích và Đang phân tích thông tin; có tên người đang chọn, trạng thái bằng chữ và skeleton. Không hiển thị phần trăm hoàn thành giả, không vẽ kết quả AI trước khi có dữ liệu. Cho quay lại trong khi thông tin vẫn được giữ.

C-NUT-04 — Cần bổ sung thông tin:
Nêu phần còn thiếu bằng câu hỏi cụ thể, tối đa ba câu hỏi thiết yếu trong một nhóm. CTA Cập nhật phần còn thiếu dẫn vào các trường liên quan của C-NUT-02. Giữ dữ liệu đã rõ, không bắt điền lại toàn bộ. Chưa rõ dị ứng vẫn chặn gợi ý cá nhân hóa.

C-NUT-05 — Kiểm tra bản tóm tắt:
Danh sách dữ kiện đã lấy từ hồ sơ/ghi chú. Mỗi dòng có nội dung, nguồn do gia đình/hồ sơ cung cấp, mức Đã báo cáo / Báo cáo không có / Chưa chắc chắn và Hiện tại / Trước đây / Chưa rõ thời điểm khi có dữ liệu. CTA Thông tin đúng, tiếp tục; action Chỉnh sửa thông tin. Không gắn nhãn Đã được bác sĩ xác minh cho dữ liệu khách tự nhập.

C-NUT-06 — Đã xác nhận thông tin:
Trạng thái Thông tin đã được xác nhận và CTA Xem gợi ý thực đơn khi hệ thống cho phép. Phải phân biệt xác nhận dữ kiện với đã có thực đơn phù hợp; không tự đưa menu lên màn này chỉ vì người dùng bấm xác nhận.

C-NUT-07 — Thực đơn gợi ý trong ngày:
Ba bữa Sáng, Trưa, Tối theo chiều dọc; mỗi bữa hiển thị tên món, khẩu phần và action Xem chi tiết/Chọn món thay thế. CTA Lưu thực đơn. Luồng hiện tại là ba bữa trong một ngày; không tự mở rộng thành planner 7 ngày, nhật ký calories hoặc theo dõi ăn uống.

C-NUT-08 — Chi tiết món, có thể là sheet:
Tên món và bữa, khẩu phần, nguyên liệu + định lượng + đơn vị + trước/sau chế biến, các bước chế biến, dinh dưỡng mỗi phần khi có dữ liệu, nguồn công thức, lý do gợi ý và lưu ý dùng đúng khẩu phần. Các trường dinh dưỡng có thể có kcal, đạm, carbohydrate, chất béo, chất xơ, natri, kali, phospho, dịch. Trường thiếu ghi Chưa có dữ liệu, không ghi 0 hoặc tự tính. Không tự đặt giới hạn chuyên môn.

C-NUT-09 — Chọn món thay thế, dạng sheet:
Hiện bữa đang thay, danh sách ứng viên phù hợp trả về, tên món/khẩu phần, chọn một món rồi xác nhận thay. Chỉ cho chọn các ứng viên được hệ thống cho phép; thay xong cập nhật thực đơn trước khi lưu. Không cho bỏ qua dị ứng hoặc hạn chế để tăng số lựa chọn. Có loading, đang thay và trạng thái không có ứng viên.

C-NUT-10 — Đã lưu thực đơn / xem bản đã lưu:
Thông báo lưu thành công, tên người, ngày của thực đơn và ba bữa. CTA Xem thực đơn đã lưu / Về hồ sơ. Bản đã lưu là bản xem lại, không có nút sửa tùy ý làm mất lịch sử. Nếu muốn thực đơn mới thì quay về luồng kiểm tra hiện hành.

C-NUT-11 — Danh sách thực đơn đã lưu:
Danh sách theo ngày của đúng người đang chọn, nhãn Đã lưu hoặc Cần kiểm tra lại; nhấn để xem bản đã lưu. Có empty state Chưa có thực đơn đã lưu và CTA quay về kiểm tra thông tin. Không tạo lịch sử của một người khác khi đổi hồ sơ.

C-NUT-12 — Thực đơn cần kiểm tra lại:
Nêu Thông tin đã thay đổi — cần kiểm tra lại, do hồ sơ hoặc nội dung đã thay đổi. CTA Kiểm tra lại hồ sơ; giữ bối cảnh lịch sử nhưng không quảng bá món cũ là vẫn phù hợp hiện tại. Tạm khóa thay/lưu/dùng kết quả cũ cho đến khi được kiểm tra lại.

Nối flow:
Chi tiết hồ sơ → 01 → 02 (nếu cần cập nhật) → 03 → 04 hoặc 05 → 06 → 07.
07 → 08 để xem món; 07 → 09 để đổi món → 07; 07 → 10 để lưu; 01/10 → 11 → 10 hoặc 12.
Các nhánh cần hướng dẫn chuyên biệt/lỗi/không có nội dung sẽ được bổ sung ở lượt tiếp theo dưới màn cha tương ứng.

Chỉ dùng tên, ảnh và số liệu minh họa có ghi chú Dữ liệu minh họa bên ngoài UI khi dựng prototype. Không bịa nguồn chuyên môn, chỉ định, danh mục đã duyệt hay tuyên bố AI đã hoạt động thật. Không hiển thị JSON, revision, token, gRPC/REST, mã lỗi nội bộ hoặc cấu hình backend lên UI cho khách.

Kết quả: các frame mới được đánh số, tái sử dụng component, có notes về hành động/đích đến và một happy path dễ trình diễn. Giữ các màn cũ; khi đủ tương đương thì cải thiện frame cũ thay vì tạo bản sao.
```

## 3. Prompt các nhánh trạng thái còn thiếu

```text
Bổ sung các biến thể trạng thái cho flow Nutrition CareSitter vừa dựng, đặt ngay dưới màn cha, dùng cùng component và palette Customer. Không tạo tính năng backend mới hoặc thêm dữ liệu sức khỏe chưa được cung cấp.

1. Thiếu/chưa rõ dị ứng: Cần xác nhận tình trạng dị ứng; chọn Chưa rõ vẫn giữ trạng thái cần bổ sung, không tự đổi thành Không có.
2. Triệu chứng chưa rõ hoặc nguồn mâu thuẫn: nêu thông tin cần làm rõ, CTA Kiểm tra lại hồ sơ. Không biến triệu chứng thành tên bệnh hoặc âm thầm bỏ ràng buộc đã báo cáo.
3. Cần hướng dẫn chuyên biệt: dành cho tình trạng ngoài phạm vi hỗ trợ như khó nuốt, ăn qua ống, hạn chế dịch/điện giải. Nêu Cần hướng dẫn phù hợp trước khi gợi ý; CTA Cập nhật hướng dẫn hiện có và Về hồ sơ. Không tự gợi ý ăn mềm hoặc tự đặt mức nước/điện giải, không có checkbox tự mở khóa.
4. Nhiều bệnh/ràng buộc chưa giải quyết được: giữ tất cả thông tin hiện có và nêu phần cần làm rõ; không yêu cầu bỏ một bệnh để tiếp tục.
5. Không có nội dung đã duyệt: Chưa có công thức đã duyệt cho nhu cầu này; giữ hồ sơ, quay về hoặc kiểm tra lại khi có nội dung. Đây là state riêng với không có món phù hợp.
6. Không có món phù hợp: Chưa tìm được món đáp ứng các yêu cầu; không nới hạn chế. Biến thể không có món thay thế nằm trong sheet C-NUT-09.
7. Phân tích chưa khả dụng/lỗi: Chưa phân tích được thông tin. Dữ liệu đã nhập vẫn được giữ. Chỉ có Thử phân tích lại khi được phép; nếu chưa khả dụng thì cho quay lại, không hiển thị thực đơn giả.
8. Lưu/cập nhật lỗi mạng: giữ draft và món đã chọn; báo lỗi inline, cho thử lại đúng thao tác, tránh nút gửi liên tục. Khi chưa biết kết quả lưu, dùng Đang kiểm tra kết quả thay cho thông báo chắc chắn thành công/thất bại.
9. Hồ sơ/nội dung thay đổi: nối C-NUT-12, khóa thao tác dựa trên kết quả cũ, kiểm tra lại hồ sơ; tránh ghi đè thông tin mới.
10. Hồ sơ xóa/không còn khả dụng: xóa dữ liệu người cũ khỏi màn, CTA Về danh sách hồ sơ; không tự chuyển sang hồ sơ khác.
11. Hết phiên/đổi tài khoản: về đăng nhập hoặc tải lại đúng hồ sơ sau xác thực; không để kết quả người cũ tồn tại trên màn.
12. Tính năng chưa khả dụng: trong biến thể chi tiết hồ sơ, entry Nutrition chỉ xuất hiện khi khả dụng. Nếu mở link cũ thì hiện chưa khả dụng và Về hồ sơ; không hiện CTA hoạt động giả.

Rà lại keyboard, focus, nhãn tiếng Việt, loading, disabled, empty, error, back và text scale 200%. Không chỉ dựa vào màu để phân biệt trạng thái. Không thêm chatbot bác sĩ, liều thuốc, mục tiêu calories, shopping list, reminder hay thực đơn 7 ngày trong đợt này.

Xuất bảng cuối: mã frame → tên → mục đích → màn trước/sau → state → đã tái dùng hay bổ sung. Nêu rõ phần không thể nối prototype hoặc không thể di chuyển trên canvas để người dùng biết bước còn lại.
```

## 4. Phân biệt những gì đã có và đề xuất thiết kế

| Nội dung | Bằng chứng hiện tại | Ý nghĩa đối với Stitch |
| --- | --- | --- |
| Entry Nutrition theo hồ sơ | Router `/beneficiaries/:id/nutrition`, tile ở chi tiết beneficiary | Dùng entry sẵn, không thêm hồ sơ hoặc tab mới |
| Health form, thuốc, nhu cầu ăn uống | `NutritionHealthForm`, `NutritionHealthFields`, `NutritionNotesFields` | Chia nhóm/frame để giảm mật độ; không bắt onboarding sức khỏe lại |
| Assessment, confirm, recommend, replacement, save/history | Repository và actions của Nutrition | Thiết kế tương ứng đúng hành động đã có; nhiều frame vẫn thuộc một route/sheet |
| Trạng thái thiếu/hướng dẫn chuyên biệt/no_content/no_match/failed/stale | `NutritionResult`, `NutritionFacts`, response rules | Dựng đủ state, không chỉ happy path |
| Parser AI thực | Program đăng ký `UnconfiguredHealthParser` | Không mô tả provider thật đã chạy; có state chưa khả dụng |
| CATALOG chuyên môn đã nghiệm thu | Không xác minh trong đợt rà source này | Không dựng demo rồi gọi là danh mục production |
| Nutrition trong Caregiver/Admin | Chưa có màn/route Nutrition trong hai frontend được rà | Không gộp vào luồng hiện hành; nếu phát triển sau, tách board “Đề xuất” |
| Sở thích/budget, 7 ngày, tracking ăn uống, reminder, mua nguyên liệu, xuất PDF | Chưa có UI/contract tương ứng trong phần source đã rà | Không sinh như tính năng đã có; lập yêu cầu riêng nếu cần |
| Thiết kế tách Nutrition thành route mới | Chưa triển khai ở Flutter | Frame thiết kế mới không đồng nghĩa route/source đã được sửa |

## 5. Source đã đối chiếu

Đường dẫn dưới đây tính từ gốc repository `CareSitter`:

- `frontend/customer-app/lib/app/router/app_router.dart`, `shell_scaffold.dart`: route và bottom navigation.
- `frontend/customer-app/lib/features/booking/presentation/widgets/wizard/booking_wizard_body.dart`: thứ tự sáu bước.
- `frontend/customer-app/lib/features/nutrition/presentation/screens/nutrition_screen.dart`: form, history/replacement sheets.
- `frontend/customer-app/lib/features/nutrition/presentation/widgets/nutrition_result.dart`, `nutrition_facts.dart`, `nutrition_meal_card.dart`: nhãn state và dữ liệu món.
- `frontend/customer-app/lib/features/nutrition/presentation/widgets/nutrition_health_form.dart`, `nutrition_health_fields.dart`, `nutrition_notes_fields.dart`: trường cập nhật.
- `frontend/customer-app/lib/features/nutrition/data/repositories/nutrition_repository.dart`, `presentation/controllers/nutrition_actions_controller.dart`: thao tác hiện có.
- `frontend/customer-app/lib/core/theme/app_colors.dart`, `app_theme.dart`, `app_spacing.dart`, `app_radius.dart`: palette olive hiện tại trong code, font và tokens; palette thiết kế đích đã đổi sang Landing theo yêu cầu mới của người dùng.
- `frontend/caregiver-app/lib/app/router/app_router.dart`, `lib/core/theme/app_colors.dart`: nhóm Caregiver và palette teal.
- `frontend/admin-web/src/routes.tsx`, `pages/SupportPage.tsx`: chín nhóm Admin và tab tư vấn.
- `frontend/landing-page/src/features/consultation/ConsultationForm.tsx`: form yêu cầu tư vấn.
- `backend/services/nutrition/src/CareSitter.Nutrition/Program.cs`: parser hiện chưa cấu hình.

Tham khảo [kế hoạch các tình huống Nutrition](../../tong-quan/NUTRITION_EDGE_CASE_IMPLEMENTATION_PLAN.md) và [kết quả triển khai lịch sử](../../kiem-thu/NUTRITION_SERVICE_IMPLEMENTATION_2026-10-11.md); không coi tài liệu lịch sử là xác nhận runtime hiện tại.

Kiểm chứng ban đầu: đọc source và kiểm đường dẫn tài liệu; kết quả thao tác Stitch ghi ở mục 6. Không chạy suite ứng dụng vì không sửa source/test. Phần còn lại: rà prototype, breakpoint và duyệt frame bổ sung trước khi triển khai UI tương ứng vào app.

## 6. Kết quả thực hiện trực tiếp trên Stitch

Theo yêu cầu “lên Stitch bảo nó làm luôn”, đã mở đúng project và gửi yêu cầu qua trình duyệt. Theo steering tiếp theo “xài màu giống landing page”, đã sửa yêu cầu olive thành Landing teal và yêu cầu edit các frame đã tạo.

- Đã tạo/hoàn thiện C-NUT-01–12; C-NUT-07 được chuẩn hóa từ màn thực đơn đã có. Nutrition có form/summary/confirmation, ba bữa, chi tiết/đổi món, lưu/lịch sử và stale.
- Đã tạo C-NUT-STATE-01 (cần hướng dẫn), STATE-02 (chưa có nội dung duyệt), STATE-03 (không có món đáp ứng), cùng C-NUT-STATES là bảng chín biến thể hỗ trợ.
- Đã ghim tài liệu **CareSitter — Thứ tự màn hình & Flow Map**, gồm Booking đúng sáu bước, nhánh Payment và Nutrition.
- Đã tải lại project, kiểm các preview đã lưu và màu hiển thị thực tế trên tám frame ban đầu. Đã yêu cầu bỏ các liều thuốc/ngưỡng nước mẫu tự sinh, kiểm bản tóm tắt không còn giá trị bị phát hiện trong QA.
- Tác vụ này chỉ thay thiết kế Stitch và tài liệu local. Chưa đổi theme source Customer hoặc triển khai các route/frame mới trong Flutter.

Giới hạn còn lại: không tự di chuyển tọa độ artboard bằng agent Stitch; dùng Flow Map đã ghim để sắp workspace. Chưa kiểm toàn bộ breakpoint/prototype/tất cả nội dung minh họa. Không có chứng nhận chuyên môn cho dữ liệu prototype.
