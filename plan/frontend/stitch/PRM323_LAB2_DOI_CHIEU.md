# Đối chiếu CareSitter với yêu cầu PRM323 Lab 2

Ngày đối chiếu lịch sử: 14/10/2026. **Rà soát bổ sung: 17/10/2026.** Nguồn yêu cầu là `C:\Users\ADMIN\Downloads\PRM323_Lab2_HuongDan_Slide_Presentation_Demo (1).docx`; nguồn sản phẩm hiện tại là [Stitch CareSitter](https://stitch.withgoogle.com/projects/16914427060621528532), [repository CareSitter](https://github.com/ThwnThwn/CareSitter) và tài liệu local. Project Stitch cũ `9685887642498274590` chỉ giữ trong log lịch sử. Đây là hướng dẫn để **trình bày và chấm Lab 2**, không phải kế hoạch xây toàn bộ sản phẩm hoặc bằng chứng một tính năng đã chạy.

## Kết luận cần dùng khi làm slide

Stitch đã có nhiều bản thiết kế Customer, Caregiver và Nutrition, đủ làm nguồn chọn màn. **Chưa thể tuyên bố hoàn thành Lab 2** vì chưa có Figma 6 page đã kiểm, prototype ba luồng chạy được, ba cặp ảnh AI trước/sau, component instances/variables và kiểm accessibility. Màn trùng, sheet, dialog hoặc state của cùng màn không được cộng vào mốc tám màn cuối. Không đưa artboard Desktop 1280 px bọc điện thoại vào nhóm Final UI mobile.

Sau lượt chỉnh 14/10, Stitch đã lưu tài liệu **“CareSitter Customer App — Flow Map Tham Chiếu (PRM323 Lab 2)”** và phản hồi đã cập nhật bốn frame Nutrition. Kiểm nội dung canvas xác nhận tài liệu mới tồn tại, nhưng tài liệu Flow Map toàn hệ thống cũ vẫn còn với thời lượng 2–5 giờ, hotline và bảo hiểm tự sinh. Bản mới cũng còn câu gán bệnh cụ thể với nhóm gia vị/dầu mỡ mà không có nguồn; phải thay bằng “dùng thông tin gia đình khai để rà nguyên liệu cần tránh” trước khi coi là final. Phản hồi của Stitch **chưa xác nhận** kích thước thực của bốn artboard Nutrition hay việc các màn đã được kéo theo thứ tự trên canvas.

Tài liệu hướng dẫn **đề xuất** 10 phút trình bày, 10–12 slide, 5 phút demo, 5 phút hỏi đáp. Đây không phải yêu cầu cứng của đề gốc. Đề gốc áp dụng hình thức cá nhân nếu giảng viên chưa đổi; không mặc định báo cáo theo nhóm. Slide hỗ trợ trình bày, còn nộp chính là **một repo GitHub và một link Figma có quyền xem**.

Rubric gốc phân bổ: phân tích UX/flow **15**, tạo UI bằng AI **10**, ba vòng AI và phản biện **15**, UI cuối **20**, design system/component **15**, prototype **10**, Flutter handoff **10**, tài liệu/AI log **5**. Do đó ảnh màn hình nhiều chỉ hỗ trợ một phần; điểm còn phụ thuộc quá trình, Figma và demo thực sự.

## Thứ tự gọn cho bài Lab 2

Chọn **Customer app** làm phạm vi đánh giá để ba flow liên kết cùng persona. Caregiver/Admin/Landing là bối cảnh sản phẩm hoặc phụ lục, không cần ép toàn bộ hơn 80 frame lên một trang Figma Final UI. Màn chính đi trái sang phải; nhánh lỗi/hủy nằm dưới màn phát sinh. Flow Map là tài liệu điều hướng; chỉ có vị trí artboard và prototype link thật mới chứng minh đã sắp canvas và nối tương tác.

| Luồng | Thứ tự màn chính trong Final UI/Prototype | Nhánh cần demo |
| --- | --- | --- |
| 1. Đặt lịch và thanh toán | Home → Danh mục/chọn dịch vụ → Người được chăm sóc → Ngày/giờ/địa chỉ → Người chăm sóc → Điều khoản → Xác nhận → Chi tiết lịch chờ tiền → Chọn cổng → Kết quả → Chi tiết lịch | Hủy thanh toán quay lại lịch chưa trả; kết quả chưa rõ chờ backend đối soát, không báo thành công theo URL |
| 2. Theo dõi ca | Danh sách lịch → Chi tiết lịch → Theo dõi ca → Nhật ký/timeline → Đánh giá | Mất quyền hoặc vị trí cũ có thông báo và lối quay lại; Back không gây ngõ cụt |
| 3. Bữa ăn sinh hoạt Nutrition | Danh sách người thụ hưởng → Chi tiết hồ sơ → Tổng quan Nutrition → Cập nhật thông tin → Kiểm tra/xác nhận → Bữa ăn trong ngày → Chi tiết/thay món → Lưu/lịch sử | Thiếu thông tin, không có món phù hợp hoặc cần hướng dẫn chuyên biệt: dừng gợi ý, quay về hồ sơ |

Nutrition giữ **bệnh lý đã biết do gia đình cung cấp**, dị ứng, nguyên liệu cần tránh và ghi chú chuẩn bị món để loại trừ món không phù hợp. Không viết AI chẩn đoán, món điều trị bệnh, kê thuốc, liều, khả năng nuốt, đường nuôi ăn hoặc mức nước. Nếu dữ kiện chưa đủ, trạng thái “Chưa rõ” không được đổi thành “Không có”.

## Tám màn đại diện và sáu mục handoff

Các màn dưới đây là **danh sách ứng viên** để chốt Final UI trong Figma, không phải xác nhận frame đã đạt chất lượng hay có component instances. Mỗi dòng ghi đủ sáu mục mà file Lab 2 yêu cầu. Khi bàn giao, gắn thêm link frame Figma và ảnh/đo kích thước cụ thể.

| Màn | Layout | Components | States | Interactions | Navigation | UI constraints |
| --- | --- | --- | --- | --- | --- | --- |
| C-HOME | Header, lịch gần nhất, dịch vụ, action Đặt lịch | App bar, card, bottom nav | Loading, empty, data, error | Chọn dịch vụ/đặt lịch | Sang danh mục/booking/lịch | Mobile 360/390/412; chữ ≥14 sp |
| C-BOOK-01 Dịch vụ | Danh sách dịch vụ một cột | Card chọn, stepper, CTA | Chưa chọn, đã chọn, lỗi tải | Chọn dịch vụ và thời lượng | Bước 2; Back về entry | 48 dp touch; tổng tiền chưa chốt ở client |
| C-BOOK-02 Người nhận | Bản thân/người thân, entry tạo hồ sơ | Recipient card, CTA | Rỗng, chọn, loading, lỗi | Chọn hồ sơ | Bước 3; Back bước 1 | Tên đọc được; không lộ hồ sơ khác |
| C-BOOK-03 Ngày giờ | Lịch, khung giờ, địa chỉ | Date picker, time slots, address card | Chưa đủ, khả dụng, lỗi | Chọn giờ/địa chỉ | Bước 4; Back bước 2 | Thời lượng theo source 2–12 giờ; 360/412 dp |
| C-BOOK-04 Người chăm sóc | Danh sách và tóm tắt lựa chọn | Card, filter, CTA | Loading, empty, selected | Chọn người phù hợp | Bước 5; Back bước 3 | Không hiện xác minh/chứng chỉ tự sinh |
| C-BOOK-06 Xác nhận | Tóm tắt người, dịch vụ, giờ, chi phí | Summary rows, consent, CTA | Chưa đồng ý, đang gửi, lỗi | Xác nhận một lần | Chi tiết lịch chờ tiền; Back bước 5 | Chống bấm lặp; chi phí do backend quyết định |
| C-PAY-RESULT | Trạng thái, mã lịch, action phù hợp | Status icon, notice, CTA | Success, pending, fail, cancel | Xem lịch, thử lại khi an toàn | Chi tiết lịch; Back có đích | Không kết luận trả tiền từ return URL |
| C-NUT-OVERVIEW | Hồ sơ, nguồn dữ kiện, action thực đơn | Info rows, warning, CTA | Chưa rõ, đủ, needs_info, guidance | Kiểm tra dữ kiện hoặc xem món | Chi tiết hồ sơ → Nutrition → form | Bệnh lý gia đình khai chỉ dùng đối chiếu món; không trị bệnh |

Các màn còn lại trong ba flow (tracking, timeline, Nutrition result/replace/history) cũng cần spec sáu mục trước khi coi handoff hoàn tất. Sheet chi tiết/thay món và biến thể payment không nâng số “màn khác nhau” nếu chỉ là overlay hoặc state của một màn.

## Bảng kiểm theo file hướng dẫn

| Yêu cầu | Bằng chứng hiện có | Tình trạng và bước chốt |
| --- | --- | --- |
| Phân tích persona, vấn đề, chỉ số | [Persona giả định](../../ux/persona.md) | Có giả thuyết; chưa có khảo sát và số đo. Trình bày mục tiêu kiểm thử, không trình bày thành kết quả. |
| Information Architecture, ≥8 màn cuối | Canvas Stitch có nhiều frame; bảng tám ứng viên ở trên | Cần chọn đúng tám artboard Mobile final khác nhau trong Figma 03; đánh dấu frame trùng/state. |
| Ba flow, alternate/error | Sơ đồ ba flow ở trên và Flow Map Stitch | Cần vẽ Figma 01, nối prototype Figma 06, chạy từ start đến end và kiểm Back. |
| AI prompt nguyên văn, ≥3 vòng tinh chỉnh, ≥5 vấn đề UX | [Prompt local](STITCH_PROMPTS.md), [AI log](../../ai/ai-design-log.md), một số ảnh local | Chưa đủ ba cặp ảnh trước/sau và nhật ký prompt nguyên văn đã xác minh. Xuất từng vòng cụ thể; ghi cả lỗi AI mới ở Flow Map, không chỉ lời tự nhận “đã sửa”. |
| Quyết định Accept/Modify/Reject | [Sáu quyết định hiện tại](../../design-decisions.md) | Có lý do; cần gắn screenshot AI và frame cuối vào từng quyết định. |
| Wireframe → Final UI | Một số màn Stitch final và bản cũ | Chưa có Figma 02 Wireframe và Figma 03 Final UI được kiểm cùng cặp màn. |
| Design system, 9 nhóm component | [DESIGN.md](DESIGN.md) mô tả token và component | Chưa xác minh Figma Variables/styles, Auto Layout, variants/instances cho Button, Text field, Card, Navigation, App bar, Dialog, Loading, Empty, Error. |
| Accessibility/responsive | Quy tắc mục tiêu trong DESIGN.md | Chưa đo contrast 4.5:1/3:1, cỡ ≥14 sp, target ≥48 dp và hai khung 360/412 dp. |
| Flutter handoff 6 mục/màn và 2 bảng | [Bảng mapping](../../flutter-handoff.md); tám spec ứng viên ở trên | Có bản nháp; cần hoàn thiện mọi màn trong ba flow và gắn frame Figma. Flutter code không phải phần bắt buộc của Lab 2. |
| Link nộp | [GitHub](https://github.com/ThwnThwn/CareSitter), [Stitch hiện tại](https://stitch.withgoogle.com/projects/16914427060621528532), [Figma LAB02_CareSystem](https://www.figma.com/design/Ph22SZvtVFwWzohuaia1UC/LAB02_CareSystem?node-id=0-1&t=y8TBlIsxnOdSbWSD-1), [Canva Slides](https://canva.link/55qt0sv9dsz7w3g), [Chat Evidence](https://chatgpt.com/s/cx_6ad371cf90308191ab53a511a2212c74) | Đã bổ sung đầy đủ link Figma, Canva và Chat Evidence minh chứng. |

## Sáu page Figma phải theo thứ tự

1. `01 User Flow` — sitemap và ba flow, màn bắt đầu/đích/nhánh lỗi.
2. `02 Wireframe` — ít nhất tám bố cục low-fi ứng với màn đã chọn.
3. `03 Final UI` — ít nhất tám màn cuối khác nhau, tên và thứ tự theo ba flow.
4. `04 Design System` — color/type/spacing/radius/elevation variables/styles.
5. `05 Components` — chín nhóm component, Auto Layout, variants và instances.
6. `06 Prototype` — ba starting point, Back, dialog overlay, loading → result, không dead-end.

**Chưa có bằng chứng sáu page này đã tồn tại.** Stitch là nguồn tạo UI, không thay thế file Figma mà Lab 2 yêu cầu.

## Cấu trúc 12 slide đề xuất

1. Project Overview và hai link; 2. Problem & Persona; 3. Information Architecture; 4. Three User Flows; 5. Prompt gốc và màn Stitch ban đầu; 6. Ba vòng AI và ít nhất năm vấn đề UX; 7. Accept/Modify/Reject; 8. Wireframe → Final UI; 9. Design System; 10. Accessibility/responsive; 11. Demo prototype ba flow; 12. Flutter handoff, giới hạn và link nộp.

Không đưa ảnh Stitch hoặc ảnh minh họa chưa kiểm vào slide như bằng chứng Figma/prototype. Khi trình bày, nói rõ bản nào là thiết kế, bản nào đã nối được trong Figma và bản nào đã hiện thực trong Flutter.
