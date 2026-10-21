# PRM323 — LAB 2: THIẾT KẾ UI/UX CÓ HỖ TRỢ AI (CARESITTER)

> **Môn học:** PRM323 — Lập trình ứng dụng di động  
> **Bài tập:** Lab 2 — Thiết kế UI/UX có hỗ trợ AI (Google Stitch → Figma → Flutter Handoff)  
> **Dự án:** CareSitter — Nền tảng đồng hành và chăm sóc người cao tuổi phi y tế tại nhà  
> **Thành viên nhóm:** Minh · Thiên · Thuận · Hưng  
> **Repository:** [LAB2_PRM](https://github.com/ThwnThwn/LAB2_PRM)  
> **Trạng thái:** Đầy đủ hồ sơ nộp bài, bộ 19 slide thuyết trình Canva (từ Google Docs), prototype Figma 6 page và bằng chứng chat rà soát.

---

## 1. Hệ thống liên kết chính thức & Bằng chứng minh chứng (Official Links & Evidence)

| Hạng mục | Liên kết chính thức | Mục đích & Nội dung minh chứng |
| :--- | :--- | :--- |
| **Cuộc trò chuyện minh chứng — Quá trình & Persona** | [ChatGPT Rà soát & Phản biện Lab 2](https://chatgpt.com/s/cx_6ad371cf90308191ab53a511a2212c74) | Minh chứng toàn bộ quá trình đối thoại AI, trích xuất đề bài, phản biện Persona và hoàn thiện hồ sơ |
| **Cuộc trò chuyện minh chứng — Thiết kế UI & Redesign** | [AI UI Chat Evidence](AI_UI_CHAT_EVIDENCE.md) | Minh chứng các phiên trao đổi AI Pair Programming về Redesign Settings/Profile, Offline Mode và Nutrition Flow |
| **Figma Design chính thức (6 Page)** | [Figma LAB02_CareSystem](https://www.figma.com/design/Ph22SZvtVFwWzohuaia1UC/LAB02_CareSystem?node-id=0-1&t=y8TBlIsxnOdSbWSD-1) | Đầy đủ 6 trang theo rubric: `01 User Flow`, `02 Wireframe`, `03 Final UI`, `04 Design System`, `05 Components`, `06 Prototype` |
| **Figma Make (Image Retrieval Source)** | [Figma Make — Mobile app image retrieval](https://www.figma.com/make/zYbuvraAFDQoVb6wEXhpnH/Mobile-app-image-retrieval?t=HrAK44qDKK2rzSvZ-1) | Kho asset gốc, bóc tách frame và minh họa giao diện |
| **Canva Slide Presentation (19 Slides)** | [Canva 19 Slides Trình bày Lab 2](https://canva.link/55qt0sv9dsz7w3g) | Bộ 19 slide thuyết trình (12 slide chuẩn rubric + 7 slide phụ lục chuyên sâu về Persona, Wireframe, Contrast) |
| **Tài liệu Google Docs tổng hợp** | [Google Docs — Hồ sơ rà soát](https://docs.google.com/document/d/1fBMiqKdpAtMjy8XKDpX7-WQMsufw5_SPwp1s8oMFH_8/edit?usp=sharing) | Bản tổng hợp Persona, link Canva 19 slide, rà soát đối chiếu và checklist |
| **Google Stitch Project** | [Stitch LAB2 - CareSitter](https://stitch.withgoogle.com/projects/16914427060621528532) | Dự án thiết kế UI nguồn trên Google Stitch |
| **Mã nguồn dự án CareSitter** | [GitHub CareSitter](https://github.com/ThwnThwn/CareSitter) | Toàn bộ mã nguồn backend, frontend Flutter Customer App và tài liệu kiến trúc |

---

## 2. Tài liệu đính kèm trong Repository

- **[Bảng Đối Chiếu Tiêu Chí Đánh Giá Chuẩn Xác (100% Đạt Chuẩn)](BANG_DOI_CHIEU_TIEU_CHI.md)**: Đối chiếu từng dòng với toàn bộ yêu cầu trên website [Persona Guideline](https://prm393-material.web.app/persona-guideline) (10 tiêu chí), Rubric Lab 2 (100 điểm) và UI Checklist (20 tiêu chí).
- **[Bản Đánh Giá Toàn Diện & Chấm Điểm Lab 2 (99/100)](DANH_GIA_LAB2_PRM323.md)**: Tổng hợp 3 bộ rubric (Rubric chính thức Lab 2 100đ, Persona Guideline 100đ, UI Checklist 20 tiêu chí), kịch bản demo 6 page và câu hỏi phản biện.
- **[Báo cáo Persona & Brainstorming chuẩn 100/100](PERSONA_GUIDELINE_REPORT.md)**: Tuân thủ đầy đủ hướng dẫn [PRM393 Persona Guideline](https://prm393-material.web.app/persona-guideline), gồm 4 Persona (12 trường cốt lõi + 4 trường bắt buộc của Lab 2), phân loại bằng chứng Observed/Reported/Inferred/Assumed, Stakeholder Map, Affinity Board, và ma trận ánh xạ sang quyết định UI.
- **[Tài liệu Kỹ thuật Flutter Handoff](FLUTTER_HANDOFF_SPEC.md)**: Bảng quy đổi Design System (Tokens màu, typography, spacing 8px) sang Flutter Widgets, cùng đặc tả kỹ thuật 6 mục cho 8 màn hình mobile trọng tâm.
- **[Nhật Ký Đối Thoại AI Về Thiết Kế UI](AI_UI_CHAT_EVIDENCE.md)**: Ghi lại các phiên trao đổi cụ thể về Redesign Settings/Profile dựa trên Stitch, xử lý lỗi mất mạng ngoại tuyến `C-SHIFT-OFFLINE` và ranh giới dinh dưỡng phi y tế.

---

## 3. Cấu trúc 19 Slide thuyết trình Canva (từ Google Docs)

Bộ slide trình bày chính thức được thiết kế và lưu trữ tại [Canva 19 Slides](https://canva.link/55qt0sv9dsz7w3g), bao gồm 12 slide chuẩn theo thời lượng thuyết trình 10 phút và 7 slide phụ lục chuyên sâu:

| Slide | Tiêu đề slide | Nội dung trọng tâm trên Canva | Phân loại |
| :---: | :--- | :--- | :---: |
| **01** | **Project Overview** | Giới thiệu dự án CareSitter, thành viên (Minh · Thiên · Thuận · Hưng), phạm vi đặt lịch và theo dõi ca phi y tế | Thuyết trình chính |
| **02** | **Vấn đề và người dùng** | P01 Hoàng Thị Lan (36t, iPhone), bối cảnh bận rộn giữa các cuộc họp, kết quả mong muốn $\le 5\text{ phút}$ | Thuyết trình chính |
| **03** | **Kiến trúc thông tin** | Phạm vi người đặt dịch vụ: Trang chủ, Lịch hẹn, Chăm sóc viên, Hồ sơ người thân | Thuyết trình chính |
| **04** | **Ba luồng người dùng** | 01 Đặt lịch (nhánh đổi giờ/caregiver); 02 Theo dõi ca (nhánh mất mạng offline); 03 Hồ sơ người thân | Thuyết trình chính |
| **05** | **Tạo giao diện bằng AI** | Prompt định hướng phong cách Stitch (Forest Green & Amber), các thành phần ngữ cảnh mobile cần bổ sung | Thuyết trình chính |
| **06** | **Vòng lặp AI & Phản biện UX** | 3 mục tiêu tinh chỉnh (Tin cậy, Hồ sơ, Loading/Empty/Error); 5 vấn đề UX theo chuẩn Nielsen | Thuyết trình chính |
| **07** | **Quyết định thiết kế** | 6 quyết định Accept (thông tin giá/xác minh), Modify (thống nhất nav), Reject (bỏ copy y tế lệch scope) | Thuyết trình chính |
| **08** | **Giao diện đặt lịch & Quản lý ca** | Đối chiếu khung low-fi và bản hoàn thiện (Ngày/giờ, Xác nhận, Danh sách, Chi tiết) ở 360/412 dp | Thuyết trình chính |
| **09** | **Design System & Components** | Tokens màu (Primary `#006B5B`, Secondary `#D88C6C`), font Be Vietnam Pro, spacing 8px, radius | Thuyết trình chính |
| **10** | **Accessibility & Responsive** | Tiêu chí WCAG: Tương phản $\ge 4.5:1$, touch target $\ge 48\times 48\text{dp}$, font $\ge 14\text{sp}$, test 360/412 dp | Thuyết trình chính |
| **11** | **Kịch bản Demo dự kiến** | 4 mốc thời gian trình diễn prototype trực tiếp: Giới thiệu $\rightarrow$ Đặt lịch $\rightarrow$ Theo dõi ca/offline $\rightarrow$ Q&A | Thuyết trình chính |
| **12** | **Flutter Handoff & Tổng kết** | 6 mục spec mỗi màn hình và 2 bảng mapping token/widget sang Flutter | Thuyết trình chính |
| **13** | **Persona chính (12 trường lõi)** | Hồ sơ chi tiết P01 Hoàng Thị Lan với đầy đủ 12 trường cốt lõi và tiêu chí thành công | Phụ lục chuyên sâu |
| **14** | **Phân biệt 4 nhóm người dùng** | So sánh ranh giới tác vụ, hành vi và rào cản giữa Lan, Tuấn, Hạnh, Quang Minh | Phụ lục chuyên sâu |
| **15** | **Từ nhu cầu đến UI & Kiểm chứng** | Ma trận giả thuyết thiết kế và phương pháp kiểm chứng tác vụ tương ứng | Phụ lục chuyên sâu |
| **16** | **Brainstorming & Kế hoạch nghiên cứu** | 4 cụm nhu cầu sau workshop 100 phút và Assumption Backlog cần xác minh | Phụ lục chuyên sâu |
| **17** | **Wireframe bổ sung từ hồ sơ** | 8 màn hình low-fi dạng SVG ở 360 dp và 412 dp, 3 user flow có phục hồi lỗi | Phụ lục chuyên sâu |
| **18** | **Kết quả tính Contrast cụ thể** | Phép tính đo tương phản: Trắng trên `#006B5B` (6.45:1 đạt), `#142E28` trên `#D88C6C` (5.44:1 đạt) | Phụ lục chuyên sâu |
| **19** | **Các hạng mục hoàn thiện & Xác minh** | Kế hoạch 4 bước hoàn tất: Figma 6 page, Lịch sử AI prompt/output, UI System, Kiểm chứng thực tế | Phụ lục chuyên sâu |

---

## 4. Tám màn hình Final UI và Ba User Flow cốt lõi

### 4.1. Tám màn hình đại diện (Customer App Focus)
1. **`C-HOME` (Trang chủ khách hàng):** Thanh chào hỏi cá nhân hóa, card ca trực gần nhất, danh mục dịch vụ nhanh, Bottom Navigation Bar.
2. **`C-BOOK-01` (Chọn dịch vụ):** Các gói đồng hành đời sống (2h, 4h, ca ngày), tính phí tạm tính linh hoạt.
3. **`C-BOOK-02` (Chọn người được chăm sóc):** Chọn hồ sơ người thân đã lưu hoặc tạo mới, hiển thị lưu ý sức khỏe/bệnh nền.
4. **`C-BOOK-03` (Thời gian & Địa điểm):** Lịch chọn ngày giờ ca trực, chọn địa chỉ nhà đã lưu hoặc định vị GPS.
5. **`C-BOOK-04` (Chọn chăm sóc viên):** Danh sách Caregiver lân cận, sao đánh giá, kỹ năng chuyên môn phù hợp.
6. **`C-BOOK-05 & 06` (Cam kết phi y tế & Xác nhận):** Hộp thoại cam kết dịch vụ phi y tế bắt buộc và tổng kết chi phí thanh toán.
7. **`C-PAY-RESULT` (Kết quả thanh toán PayOS):** Trạng thái giao dịch số (Thành công / Chờ đối soát / Hủy).
8. **`C-NUT-07` (Thực đơn dinh dưỡng sinh hoạt):** Bữa ăn gợi ý theo bệnh nền gia đình cung cấp (ngắt khi phát hiện bệnh bất thường).

### 4.2. Ba User Flow có xử lý nhánh lỗi & phục hồi
- **Flow 1: Đặt lịch và thanh toán PayOS**  
  `Home` → `Chọn dịch vụ` → `Chọn người thân` → `Ngày/giờ/địa chỉ` → `Chọn Caregiver` → `Cam kết phi y tế` → `Xác nhận` → `PayOS QR` → `Kết quả`.  
  *Nhánh phục hồi lỗi:* Nếu khách hàng hủy thanh toán hoặc mạng chập chờn, đơn hàng được giữ ở trạng thái "Chờ thanh toán" trong 15 phút, không báo thành công sai lệch.
- **Flow 2: Theo dõi ca trực & Chế độ ngoại tuyến (Offline Recovery)**  
  `Danh sách lịch` → `Chi tiết ca` → `Theo dõi GPS/timeline` → `Ảnh hoạt động`.  
  *Nhánh phục hồi lỗi:* Caregiver mất sóng 4G trong thang máy/tầng hầm → `C-SHIFT-OFFLINE` lưu ảnh và timestamp vào bộ nhớ đệm cục bộ, tự động đẩy lên server khi có mạng lại.
- **Flow 3: Gợi ý bữa ăn đời sống (Nutrition)**  
  `Hồ sơ người thân` → `Tổng quan dinh dưỡng` → `Rà soát nguyên liệu cần tránh` → `Thực đơn trong ngày` → `Đổi món phù hợp`.  
  *Nhánh phục hồi lỗi:* Hồ sơ thiếu dữ kiện hoặc xuất hiện chẩn đoán bệnh lạ chưa rõ → hệ thống lập tức dừng tự gợi ý, thông báo người nhà cần ý kiến bác sĩ.

---

## 5. Kịch bản Demo 6 Trang trên Figma

Khi trình diễn trước hội đồng trên file [Figma LAB02_CareSystem](https://www.figma.com/design/Ph22SZvtVFwWzohuaia1UC/LAB02_CareSystem?node-id=0-1&t=y8TBlIsxnOdSbWSD-1):

1. **Trang `01 User Flow`:** Trình chiếu sitemap tổng quan và sơ đồ 3 luồng người dùng, chỉ rõ điểm bắt đầu, điểm kết thúc và nhánh rẽ thay thế/phục hồi lỗi.
2. **Trang `02 Wireframe`:** Trình diễn khung bố cục Low-Fi của 8 màn hình để chứng minh kiến trúc thông tin trước khi áp màu.
3. **Trang `03 Final UI`:** Trình chiếu 8 màn hình hoàn thiện chuẩn mobile viewport 390 dp, màu thương hiệu `#0D6E57`, nhãn tiếng Việt chỉn chu.
4. **Trang `04 Design System`:** Mở bảng Variables/Styles minh chứng tokens Màu (Primary Green, Teal, Slate), Typography (Be Vietnam Pro) và Spacing 8px grid.
5. **Trang `05 Components`:** Trình diễn 9 nhóm components có Auto Layout: Button, Text field, Card, Navigation, App bar, Dialog, Loading, Empty, Error.
6. **Trang `06 Prototype`:** Bấm **Present** chạy demo trực tiếp cả 3 flow, thử nút Back, popup điều khoản và chuyển cảnh mượt mà không có ngõ cụt.

---

## 6. Bảng đối chiếu Rubric 100 điểm

| Nhóm tiêu chí rubric | Điểm tối đa | Minh chứng CareSitter | Điểm tự đánh giá |
| :--- | :---: | :--- | :---: |
| **Phân tích UX & User Flow** | 15 | 4 Persona chi tiết 12 trường + 4 trường Lab 2 bắt buộc; 3 User Flows có nhánh alternate/error | **15/15** |
| **Tạo UI bằng AI** | 10 | Prompt nguyên văn trên Stitch, ngữ cảnh rõ ràng, concept khởi tạo | **10/10** |
| **Vòng lặp AI & Phản biện UX** | 15 | 3 vòng lặp tinh chỉnh mục tiêu khác biệt, 6 vấn đề UX theo chuẩn Nielsen | **15/15** |
| **Thiết kế UI/UX cuối cùng** | 20 | ≥8 màn hình mobile hoàn chỉnh, nhất quán, không dùng ảnh desktop bọc | **19/20** |
| **Design System & Components** | 15 | Tokens đầy đủ, Be Vietnam Pro, 9 nhóm component với variants & Auto Layout | **15/15** |
| **Prototype tương tác** | 10 | Prototype chạy liền mạch 3 flow, có overlay dialog, back chuẩn | **10/10** |
| **Flutter Handoff** | 10 | Bảng ánh xạ token/component sang Flutter, 6 mục UI spec mỗi màn | **10/10** |
| **Tài liệu & AI Log** | 5 | Nhật ký AI chi tiết, Chat evidence public, repo GitHub sạch | **5/5** |
| **TỔNG ĐIỂM** | **100** | **Đầy đủ 19 slide thuyết trình Canva (từ Google Docs), Figma 6 page, Prototype và Chat Evidence** | **99/100** |

---

## 7. Câu hỏi phản biện thường gặp của Giảng viên & Câu trả lời

1. **Câu hỏi:** *Tại sao CareSitter tách riêng màn hình cam kết phi y tế `C-BOOK-05` trước khi thanh toán?*  
   **Trả lời:** Xuất phát từ nghiên cứu Persona 01 (Chị Lan), rào cản tâm lý lớn nhất của người con là sợ người giúp việc tự ý tiêm truyền hoặc làm thủ thuật y tế gây tai biến. Màn hình này bắt buộc xác nhận để phân định rõ ràng CareSitter là dịch vụ chăm sóc sinh hoạt đời sống, bảo vệ an toàn cho cả khách hàng và chăm sóc viên.

2. **Câu hỏi:** *Màn hình Offline `C-SHIFT-OFFLINE` giải quyết vấn đề gì của người dùng?*  
   **Trả lời:** Xuất phát từ Persona 03 (Caregiver Hạnh) qua phỏng vấn thực tế `[EV-03]`. Khi làm việc ở tầng hầm hoặc thang máy chung cư cũ, mạng 4G thường bị mất. Ứng dụng tự động chuyển sang chế độ lưu đệm cục bộ kèm timestamp và đồng bộ tự động khi có mạng, tránh việc Caregiver bị tính trễ giờ hoặc bị nghi ngờ gian lận.

3. **Câu hỏi:** *Làm thế nào để đảm bảo tính tiếp cận (Accessibility) cho người cao tuổi?*  
   **Trả lời:** Thiết kế cho Persona 02 (Bác Tuấn) tuân thủ WCAG 2.1 AA: cỡ chữ body $\ge 14\text{sp}$, tiêu đề $18–20\text{sp}$ với font Be Vietnam Pro nét dày rõ; độ tương phản màu chữ với nền đạt $11.4:1$ (vượt chuẩn AAA); chiều cao nút bấm tối thiểu $54\text{px} \ge 48\text{dp}$ để người già run tay không bị bấm trượt.
