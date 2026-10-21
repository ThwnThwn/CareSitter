# BẢN ĐÁNH GIÁ TOÀN DIỆN VÀ HỒ SƠ CHẤM ĐIỂM — PRM323 LAB 2

> **Học phần:** PRM323 — Lập trình ứng dụng di động  
> **Đồ án:** Lab 2 — Thiết kế UI/UX có hỗ trợ AI (Google Stitch → Figma → Flutter Handoff)  
> **Dự án:** CareSitter — Nền tảng đồng hành và chăm sóc người cao tuổi phi y tế tại nhà  
> **Repository:** [https://github.com/ThwnThwn/LAB2_PRM](https://github.com/ThwnThwn/LAB2_PRM)  
> **Ngày lập:** 21/10/2026  
> **Kết quả tự đánh giá:** **99 / 100 Điểm (Xếp loại: Xuất sắc / Đạt Gate G2)**

---

## I. HỆ THỐNG LIÊN KẾT MINH CHỨNG (EVIDENCE LINKS)

Để giảng viên và hội đồng kiểm chứng trực tiếp, tất cả các sản phẩm đã được kết nối và công khai:

| TT | Hạng mục minh chứng | Liên kết trực tiếp | Nội dung kiểm chứng |
| :-: | :--- | :--- | :--- |
| 1 | **Cuộc trò chuyện AI minh chứng (Chat Evidence)** | [ChatGPT Rà soát & Phản biện Lab 2](https://chatgpt.com/s/cx_6ad371cf90308191ab53a511a2212c74) | Toàn bộ prompt, nhật ký rà soát rubric, phản biện Persona và bóc tách tài liệu |
| 2 | **Figma Design chính thức (6 Page)** | [Figma LAB02_CareSystem](https://www.figma.com/design/Ph22SZvtVFwWzohuaia1UC/LAB02_CareSystem?node-id=0-1&t=y8TBlIsxnOdSbWSD-1) | 6 trang chuẩn rubric: User Flow, Wireframe, Final UI, Design System, Components, Prototype |
| 3 | **Figma Make (Image Retrieval)** | [Figma Make Mobile App Source](https://www.figma.com/make/zYbuvraAFDQoVb6wEXhpnH/Mobile-app-image-retrieval?t=HrAK44qDKK2rzSvZ-1) | Kho asset đồ họa, bóc tách frame và minh họa giao diện |
| 4 | **Canva Slide Presentation (19 Slides)** | [Canva 19 Slides Trình bày Lab 2](https://canva.link/55qt0sv9dsz7w3g) | Bộ 19 slide thuyết trình từ Google Docs (12 slide thuyết trình chính + 7 slide phụ lục chuyên sâu) |
| 5 | **Tài liệu Google Docs tổng hợp** | [Google Docs Hồ sơ rà soát](https://docs.google.com/document/d/1fBMiqKdpAtMjy8XKDpX7-WQMsufw5_SPwp1s8oMFH_8/edit?usp=sharing) | Bảng tổng hợp Persona, rà soát đối chiếu và checklist |
| 6 | **Google Stitch Project** | [Stitch LAB2 - CareSitter](https://stitch.withgoogle.com/projects/16914427060621528532) | Dự án thiết kế UI gốc với AI prompts & iterations |
| 7 | **Mã nguồn dự án CareSitter** | [GitHub CareSitter](https://github.com/ThwnThwn/CareSitter) | Toàn bộ mã nguồn backend, frontend Flutter Customer App và handoff specs |

---

## II. BẢNG TỰ ĐÁNH GIÁ THEO RUBRIC LAB 2 PRM323 (THANG ĐIỂM 100)

### 1. PHẦN QUÁ TRÌNH (45 ĐIỂM)

| Tiêu chí | Điểm tối đa | Mức độ đạt được trong dự án CareSitter | Bằng chứng kiểm tra | Điểm tự chấm |
| :--- | :---: | :--- | :--- | :---: |
| **1.1. Phân tích UX & User Flow** | **15** | • Xây dựng **4 Persona** chi tiết theo mẫu 12 trường cốt lõi kèm 4 trường bắt buộc của Lab 2 (tuổi, vai trò, thói quen thiết bị, accessibility).<br>• Thiết lập **3 User Flows** hoàn chỉnh: Đặt lịch & PayOS, Giám sát ca trực thời gian thực (có phục hồi ngoại tuyến khi mất sóng), Gợi ý thực đơn dinh dưỡng theo bệnh nền (ngắt khi có bệnh bất thường).<br>• Có sơ đồ nhánh rẽ thay thế và phục hồi lỗi (error recovery). | • [PERSONA_GUIDELINE_REPORT.md](PERSONA_GUIDELINE_REPORT.md) (Mục 2 & 3)<br>• Slide 02, 03, 04<br>• Figma Page `01 User Flow` | **15 / 15** |
| **1.2. Tạo UI bằng AI (AI UI Generation)** | **10** | • Sử dụng prompt nguyên văn trên Google Stitch có đầy đủ 4 thành phần: Persona, Nhiệm vụ người dùng, Ràng buộc kỹ thuật & phong cách thiết kế.<br>• Khởi tạo giao diện gốc phản ánh đúng ngữ cảnh đồng hành người cao tuổi phi y tế. | • Slide 05<br>• [Stitch Project Lab 2](https://stitch.withgoogle.com/projects/16914427060621528532)<br>• Chat evidence link | **10 / 10** |
| **1.3. Vòng lặp AI & Phản biện UX** | **15** | • Thực hiện **3 vòng lặp tinh chỉnh** với mục tiêu kỹ thuật khác biệt (Tăng tương phản cho người già, bổ sung cam kết phi y tế, cơ chế lưu ngoại tuyến).<br>• Phân tích **5 vấn đề UX** theo 10 nguyên lý Nielsen Heuristics và WCAG 2.1 AA.<br>• Đưa ra **6 quyết định thiết kế** (Accept / Modify / Reject) có lập luận chặt chẽ. | • Slide 06, 07<br>• Bảng quyết định thiết kế trong [PERSONA_GUIDELINE_REPORT.md](PERSONA_GUIDELINE_REPORT.md) | **15 / 15** |
| **1.4. Tài liệu & AI Log** | **5** | • Nhật ký AI chi tiết ghi lại toàn bộ prompt, phản hồi và tinh chỉnh.<br>• Minh chứng cuộc trò chuyện công khai, repository GitHub sạch sẽ có file `.gitignore`. | • Chat Evidence ChatGPT<br>• [README.md](README.md) | **5 / 5** |
| **TỔNG ĐIỂM QUÁ TRÌNH** | **45** | **Đầy đủ 4 Persona, 3 Flows, AI Prompts & Phản biện UX** | **45 / 45** |

---

### 2. PHẦN SẢN PHẨM (55 ĐIỂM)

| Tiêu chí | Điểm tối đa | Mức độ đạt được trong dự án CareSitter | Bằng chứng kiểm tra | Điểm tự chấm |
| :--- | :---: | :--- | :--- | :---: |
| **2.1. Thiết kế UI/UX cuối cùng** | **20** | • Hoàn thiện **≥8 màn hình mobile** (`C-HOME`, `C-BOOK-01..06`, `C-PAY-RESULT`, `C-NUT-07`, `C-SHIFT-OFFLINE`).<br>• Chuẩn mobile viewport 390 dp, tương thích 360–412 dp, không dùng ảnh desktop đóng khung di động.<br>• Thiết kế nhất quán, màu sắc trang nhã, ngôn ngữ tiếng Việt tự nhiên và chuẩn mực. | • Figma Page `03 Final UI`<br>• Slide 08<br>• Bộ 12 ảnh preview trong `previews/` | **19 / 20** |
| **2.2. Design System & Components** | **15** | • **Tokens đầy đủ:** Màu chính `#0D6E57`, màu phụ Teal `#00B4A0`, nền `#F6F9F8`; Font `Be Vietnam Pro`; 8px Spacing Grid.<br>• **9 nhóm Components:** Buttons, Text fields, Cards, Navigation, Selection controls, Dialogs, Loading shimmer, Empty state, Error/Offline banner.<br>• 100% components có Auto Layout, Padding và Variants (Default, Hover, Active, Disabled). | • Figma Page `04 Design System`<br>• Figma Page `05 Components`<br>• Slide 09, 10 | **15 / 15** |
| **2.3. Prototype tương tác** | **10** | • Kết nối liền mạch cả **3 User Flows** không có ngõ cụt (dead-end).<br>• Có overlay popup cam kết phi y tế, chuyển cảnh loading sang kết quả thanh toán PayOS.<br>• Nút Back hoạt động chuẩn xác theo ngăn xếp điều hướng (Navigation Stack). | • Figma Page `06 Prototype` (Chế độ Present)<br>• Slide 11 | **10 / 10** |
| **2.4. Flutter Handoff** | **10** | • Bảng ánh xạ Design System sang Flutter Widgets và mã màu `Color(0xFF...)`.<br>• Đặc tả kỹ thuật **6 mục (6-point UI specs)** cho toàn bộ 8 màn hình: Cấu trúc component, dữ liệu & state, bố cục spacing, màu sắc & chữ, tương tác, accessibility. | • [FLUTTER_HANDOFF_SPEC.md](FLUTTER_HANDOFF_SPEC.md)<br>• Slide 12 | **10 / 10** |
| **TỔNG ĐIỂM SẢN PHẨM** | **55** | **8 Màn hình Mobile, Design System hoàn chỉnh, Prototype & Spec Flutter** | **54 / 55** |

---

### **TỔNG KẾT ĐIỂM RUBRIC LAB 2:** **99 / 100 ĐIỂM**

---

## III. BẢNG ĐỐI CHIẾU THEO PERSONA GUIDELINE (10 TIÊU CHÍ — 100 ĐIỂM)

Theo chuẩn đánh giá tại [PRM393 Persona Guideline](https://prm393-material.web.app/persona-guideline):

| STT | Tiêu chí đánh giá Persona | Minh chứng thực tế của CareSitter | Tự chấm |
| :-: | :--- | :--- | :---: |
| 1 | Xác định phạm vi sản phẩm, tác vụ trọng tâm & người dùng liên quan | Problem Statement rõ ràng, phân định rành mạch In-Scope và Out-of-Scope (phi y tế) | 10 / 10 |
| 2 | Có User/Stakeholder Map & cân nhắc người dễ bị bỏ sót | Bản đồ 4 nhóm: Người đặt lịch, người cao tuổi, chăm sóc viên hiện trường và CSKH | 10 / 10 |
| 3 | Số Persona phù hợp phạm vi, có phân hóa hành vi thực tế | 4 Persona: 1 Primary (Hoàng Lan), 2 Secondary (Bác Tuấn, Hạnh), 1 Supporting (Minh) | 10 / 10 |
| 4 | Persona phân biệt bằng goals, behaviors, contexts, constraints | Ranh giới mục tiêu và rào cản khác biệt rõ rệt (Văn phòng vs Ở nhà một mình vs Hiện trường) | 10 / 10 |
| 5 | Mỗi Persona đủ 12 trường cốt lõi + 4 trường bắt buộc của Lab 2 | Đủ 12 trường chuẩn kèm Tuổi, Vai trò, Thói quen thiết bị, Nhu cầu Accessibility | 10 / 10 |
| 6 | Nhu cầu mô tả theo kết quả mong muốn, không ngụy trang tính năng | Mục tiêu là "Sự an tâm", "Bữa ăn thanh đạm an toàn", "Bảo vệ thù lao minh bạch" | 10 / 10 |
| 7 | Có bằng chứng nghiên cứu & phân loại Observed/Reported/Inferred/Assumed | 4 mã phỏng vấn thực tế `[EV-01..04]` và nhãn phân loại bằng chứng khoa học | 10 / 10 |
| 8 | Có Affinity Board chứng minh cách hình thành phân khúc | 4 cụm sau workshop 100 phút (Pháp lý, Giám sát, Sức khỏe người già, Hạ tầng 4G) | 10 / 10 |
| 9 | Mỗi Primary Persona có scenario & success criteria cụ thể | Kịch bản đặt lịch chi tiết với tiêu chí đo lường thời gian $< 3.5\text{ phút}$ và độ an tâm $\ge 4.5/5$ | 10 / 10 |
| 10 | Có ma trận quyết định UI và cách kiểm chứng liên kết Persona | Ma trận 5 quyết định: Cam kết phi y tế, Offline mode, Ngắt gợi ý dinh dưỡng, Đổi slot giờ | 10 / 10 |
| **TỔNG** | **BÁO CÁO PERSONA GUIDELINE** | **ĐẠT XUẤT SẮC 10/10 TIÊU CHÍ** | **100 / 100** |

---

## IV. BẢNG KIỂM TRA THEO UI CHECKLIST (20 TIÊU CHÍ)

Dựa trên chuẩn kiểm tra [UI Checklist](https://prm393-material.web.app/ui-checklist.html):

1. **Bố cục & Viewport:** 100% màn hình thiết kế trên kích thước chuẩn mobile 390×844 dp (Auto Layout co giãn tốt trên 360 dp và 412 dp).
2. **Kích thước vùng chạm (Touch Target):** Tất cả các nút bấm, icon button, radio button và checkbox đều có vùng chạm $\ge 48\times 48\text{dp}$ (nút bấm chính cao $54\text{px}$).
3. **Typography & Độ tương phản:**
   - Font chữ Be Vietnam Pro rõ nét, hỗ trợ tiếng Việt hoàn hảo không lỗi dấu.
   - Chữ nội dung $\ge 14\text{sp}$, phụ đề $\ge 12\text{sp}$, tiêu đề $18–28\text{sp}$.
   - Độ tương phản chữ chính `#182724` trên nền `#F6F9F8` đạt **11.4:1** (vượt chuẩn WCAG AAA $7:1$).
4. **8 Interaction States:** Đầy đủ Default, Hover, Focused, Active, Disabled, Loading, Empty (`C-BOOK-EMPTY`), Error/Offline (`C-SHIFT-OFFLINE`).
5. **Khả năng tiếp cận người cao tuổi (Senior Accessibility):** Nút to bản, nhãn chữ rõ ràng, không dùng màu sắc đơn lẻ để biểu thị trạng thái (kết hợp cả Icon + Badge + Text).

---

## V. KỊCH BẢN THUYẾT TRÌNH & DEMO FIGMA TRƯỚC GIẢNG VIÊN

Khi trình diễn trước hội đồng, người thuyết trình thao tác theo 6 bước tương ứng với 6 page trên [Figma LAB02_CareSystem](https://www.figma.com/design/Ph22SZvtVFwWzohuaia1UC/LAB02_CareSystem?node-id=0-1&t=y8TBlIsxnOdSbWSD-1):

- **Bước 1 (Page `01 User Flow`):** Mở sitemap tổng quan và trình bày 3 luồng người dùng chính. Nhấn mạnh vào điểm khác biệt: Flow đặt lịch có bước cam kết phi y tế bắt buộc, flow ca trực có nhánh xử lý mất mạng ngoại tuyến, và flow dinh dưỡng có nhánh ngắt tự động khi có bệnh bất thường.
- **Bước 2 (Page `02 Wireframe`):** Cho xem khung xương bố cục Low-Fi của 8 màn hình để chứng minh kiến trúc thông tin vững chắc trước khi áp màu.
- **Bước 3 (Page `03 Final UI`):** Trình diễn 8 màn hình hoàn thiện với màu thương hiệu CareSitter Primary Green `#0D6E57`, nhãn tiếng Việt chỉn chu.
- **Bước 4 (Page `04 Design System`):** Mở bảng Variables / Styles để giảng viên thấy hệ thống Tokens: Màu sắc, Typography (Be Vietnam Pro) và Grid 8px.
- **Bước 5 (Page `05 Components`):** Trình diễn 9 nhóm components có Auto Layout, tương thích với Flutter Widgets.
- **Bước 6 (Page `06 Prototype`):** Bấm nút **Present** chạy demo trực tiếp:
  - Bấm từ Home $\rightarrow$ Đặt lịch 6 bước $\rightarrow$ Popup cam kết phi y tế $\rightarrow$ PayOS QR $\rightarrow$ Thành công.
  - Bấm thử nút Back quay lại màn hình trước mượt mà, không gặp bất kỳ ngõ cụt nào.

---

## VI. BỘ CÂU HỎI PHẢN BIỆN CHUẨN BỊ TRƯỚC VÀ CÂU TRẢ LỜI

1. **Giảng viên hỏi:** *Tại sao CareSitter tách riêng màn hình cam kết phi y tế `C-BOOK-05` trước khi thanh toán?*  
   **Trả lời:** Xuất phát từ nghiên cứu Persona 01 (Chị Lan), rào cản tâm lý lớn nhất của người con là sợ người giúp việc tự ý tiêm truyền hoặc làm thủ thuật y tế gây tai biến. Màn hình này bắt buộc xác nhận để phân định rõ ràng CareSitter là dịch vụ chăm sóc sinh hoạt đời sống, bảo vệ an toàn cho cả khách hàng và chăm sóc viên.

2. **Giảng viên hỏi:** *Màn hình Offline `C-SHIFT-OFFLINE` giải quyết vấn đề gì của người dùng?*  
   **Trả lời:** Xuất phát từ Persona 03 (Caregiver Hạnh) qua phỏng vấn thực tế `[EV-03]`. Khi làm việc ở tầng hầm hoặc thang máy chung cư cũ, mạng 4G thường bị mất. Ứng dụng tự động chuyển sang chế độ lưu đệm cục bộ kèm timestamp và đồng bộ tự động khi có mạng, tránh việc Caregiver bị tính trễ giờ hoặc bị nghi ngờ gian lận.

3. **Giảng viên hỏi:** *Làm thế nào để đảm bảo tính tiếp cận (Accessibility) cho người cao tuổi?*  
   **Trả lời:** Thiết kế cho Persona 02 (Bác Tuấn) tuân thủ WCAG 2.1 AA: cỡ chữ body $\ge 14\text{sp}$, tiêu đề $18–20\text{sp}$ với font Be Vietnam Pro nét dày rõ; độ tương phản màu chữ với nền đạt $11.4:1$ (vượt chuẩn AAA); chiều cao nút bấm tối thiểu $54\text{px} \ge 48\text{dp}$ để người già run tay không bị bấm trượt.

---

> **Kết luận:** Hồ sơ Lab 2 CareSitter hoàn chỉnh, nhất quán từ Persona $\rightarrow$ AI Stitch $\rightarrow$ Figma 6 Page $\rightarrow$ Canva 19 Slide (từ Google Docs) $\rightarrow$ Flutter Handoff. Đầy đủ minh chứng và tự tin đạt điểm xuất sắc khi bảo vệ đồ án!
