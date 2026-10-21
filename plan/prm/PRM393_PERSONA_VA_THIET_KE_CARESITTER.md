# HỒ SƠ THIẾT KẾ UI/UX & BÁO CÁO PERSONA — DỰ ÁN CARESITTER
**Học phần:** PRM393 · Bước 2 / 5: User Persona & Brainstorming (Gate G2)  
**Tên dự án:** CareSitter — Nền tảng đồng hành và chăm sóc người cao tuổi phi y tế tại nhà  
**Quy mô nhóm:** 4 thành viên  
**Tham chiếu thiết kế:** Stitch Project `LAB2 - CareSitter` (Project ID: `16914427060621528532`)  
**Design System mục tiêu của hồ sơ:** `CareSitter Design System` (Màu chủ đạo `#0D6E57`, Màu phụ Teal `#00B4A0`, Nền `#F6F9F8`, Font `Be Vietnam Pro`, Vùng chạm $\ge 48\text{dp}$, Chữ $\ge 14\text{sp}$); còn phải đồng bộ với token Flutter hiện hành.  
**Tiêu chuẩn đánh giá:** Rubric 100 điểm & Hướng dẫn [PRM393 Persona Guideline](https://prm393-material.web.app/persona-guideline)  
**Minh chứng Chat Evidence:** [ChatGPT Rà soát & Phản biện Lab 2](https://chatgpt.com/s/cx_6ad371cf90308191ab53a511a2212c74)  
**Link Figma được khai báo (cần reviewer xác minh nội dung/6 page):** [Figma LAB02_CareSystem](https://www.figma.com/design/Ph22SZvtVFwWzohuaia1UC/LAB02_CareSystem?node-id=0-1&t=y8TBlIsxnOdSbWSD-1)  
**Link Canva được khai báo (cần chốt 12 slide chính hay kèm phụ lục):** [Canva Trình bày Lab 2](https://canva.link/55qt0sv9dsz7w3g)  
**Google Docs Hồ sơ rà soát:** [Tài liệu Google Docs](https://docs.google.com/document/d/1fBMiqKdpAtMjy8XKDpX7-WQMsufw5_SPwp1s8oMFH_8/edit?usp=sharing)  
**Hồ sơ minh chứng rà soát local:** [PRM393_MINH_CHUNG_RASOAT_HO_SO.md](PRM393_MINH_CHUNG_RASOAT_HO_SO.md)

---

## 0. ĐỐI CHIẾU TRẠNG THÁI VÀ PHẠM VI KẾT LUẬN

> **Ngày rà soát cập nhật:** 21/10/2026. Hồ sơ đã được đối chiếu về cấu trúc với [Persona Guideline v1.0](https://prm393-material.web.app/persona-guideline). Đây là **hồ sơ proto-persona đang chờ kiểm chứng**, chưa phải bằng chứng rằng nghiên cứu người dùng, accessibility audit, usability test hoặc Gate G2 đã được duyệt.

### 0.1. Kết luận tổng quan

- Bản báo cáo đã **phủ cấu trúc** của 10 tiêu chí rubric: phạm vi sản phẩm, User/Stakeholder Map, 4 proto-persona, 12 trường cốt lõi, kịch bản và ma trận ánh xạ sang giả thuyết UI. Tiêu chí về research evidence và affinity pattern mới đạt mức chuẩn bị, vì chưa có biên bản/phụ lục nghiên cứu gốc để xác minh.
- Design System mục tiêu dùng CareSitter Primary Green (`#0D6E57`), Secondary Teal (`#00B4A0`), Background Slate (`#F6F9F8`) và `Be Vietnam Pro`. Mức đồng bộ giữa Figma, Canva và Flutter phải được đo trên artefact thực tế; không suy ra “100%” từ mô tả trong tài liệu.

### 0.2. Vai trò của từng nguồn minh chứng

| Nguồn | Vai trò minh chứng | Tình trạng kiểm tra |
| :--- | :--- | :--- |
| [ChatGPT Chat Evidence](https://chatgpt.com/s/cx_6ad371cf90308191ab53a511a2212c74) | Nhật ký hỗ trợ AI và phản biện văn bản | Không thay thế research evidence hoặc reviewer approval |
| [Figma LAB02_CareSystem](https://www.figma.com/design/Ph22SZvtVFwWzohuaia1UC/LAB02_CareSystem?node-id=0-1&t=y8TBlIsxnOdSbWSD-1) | Artefact thiết kế được khai báo gồm 6 page | Có link; số page, nội dung, prototype và quyền xem còn cần reviewer xác nhận |
| [Canva 12 Slides](https://canva.link/55qt0sv9dsz7w3g) | Bộ slide trình bày | Có link; cần đối chiếu bản nộp cuối với nguồn evidence |
| [Google Docs](https://docs.google.com/document/d/1fBMiqKdpAtMjy8XKDpX7-WQMsufw5_SPwp1s8oMFH_8/edit?usp=sharing) | Bảng tổng hợp Persona, rà soát và checklist | Có link; chưa phải nguồn nghiên cứu độc lập |
| [Stitch Project](https://stitch.withgoogle.com/projects/16914427060621528532) | Dự án thiết kế UI và các vòng lặp AI | Có link; cần gắn frame/version vào từng claim UI |
| [Persona Guideline](https://prm393-material.web.app/persona-guideline) | Chuẩn 12 trường, nhãn evidence, workshop và rubric gợi ý | Đã đối chiếu cấu trúc; chưa đạt approval 10/10 |

### 0.3. Chuẩn hóa Design System và Thuật ngữ

1. **Design System đồng nhất:** Chọn `CareSitter Design System` với mã màu chính `#0D6E57`, màu phụ `#00B4A0`, nền `#F6F9F8`, typography `Be Vietnam Pro`.
2. **Accessibility là mục tiêu kiểm chứng:** Tương phản, touch target $\ge 48\times 48\text{dp}$ và chữ body $\ge 14\text{sp}$ phải được đo trên frame/build cuối; các con số hiện có chưa phải audit độc lập.
3. **Phân loại evidence fail-closed:** Chỉ dùng `Observed` hoặc `Reported` khi có artefact gốc tương ứng. Nội dung chưa truy được biên bản/ghi chú phải giữ nhãn `Assumed` hoặc `Inferred`.

---

## MỤC LỤC
1. [MILESTONE A — DISCOVERY](#phần-1-milestone-a--discovery)
   - 1.1. Problem Statement & Scope
   - 1.2. Stakeholder / User Map
   - 1.3. Brainstorming & Affinity Board
   - 1.4. Persona Coverage Matrix
   - 1.5. Proto-Personas & Assumption Backlog
2. [MILESTONE B — VALIDATION & DESIGN](#phần-2-milestone-b--validation--design)
   - 2.1. Anonymized Research Evidence (Bằng chứng nghiên cứu ẩn danh)
   - 2.2. Bộ hồ sơ 4 Persona hoàn chỉnh (12 trường cốt lõi)
   - 2.3. Persona Scenarios & Task Flows
   - 2.4. Ma trận ánh xạ: Persona $\rightarrow$ User Need $\rightarrow$ UI Decision $\rightarrow$ Test Metric
   - 2.5. Tiêu chuẩn Accessibility & UX Checklist
   - 2.6. Kết quả Usability Testing giả lập
3. [BẢNG MỨC SẴN SÀNG RUBRIC — CHƯA PHẢI GATE APPROVAL](#phần-3-bảng-mức-sẵn-sàng-rubric--chưa-phải-gate-approval)
4. [BỘ CÂU HỎI PHẢN BIỆN & HƯỚNG DẪN THUYẾT TRÌNH](#phần-4-bộ-câu-hỏi-phản-biện-khi-thuyết-trình-trước-giảng-viên)

---

# PHẦN 1: MILESTONE A — DISCOVERY

## 1.1. Problem Statement & Scope

### 1.1.1. Bối cảnh & Phát biểu vấn đề
- **Bối cảnh**: Xu hướng già hóa dân số tại các đô thị lớn ở Việt Nam (Hà Nội, TP.HCM) diễn ra nhanh chóng. Con cái trong độ tuổi 28–45 thường chịu áp lực công việc văn phòng nặng nề, không thể ở nhà 24/7 để chăm sóc cha mẹ già.
- **Thực trạng**: Khi người già ở nhà một mình, họ đối mặt với:
  1. *Nguy cơ thể chất*: Quên uống thuốc, ăn uống qua bữa, nguy cơ trượt ngã không ai biết.
  2. *Khủng hoảng tâm lý*: Cảm giác cô đơn, trầm cảm, tự ti vì nghĩ mình là gánh nặng.
  3. *Nỗi lo lắng của con cái*: Bất an triền miên khi đi làm xa, không có công cụ giám sát đáng tin cậy.
- **Problem Statement**:
  > *“Những người con bận rộn cần một giải pháp tin cậy, minh bạch để người thân cao tuổi được bầu bạn và hỗ trợ sinh hoạt hàng ngày an toàn tại nhà; trong khi các dịch vụ giúp việc hiện nay thiếu kỹ năng ứng xử với người già, còn các dịch vụ y tế tại nhà thì quá tốn kém và không đáp ứng nhu cầu đồng hành đời sống.”*

### 1.1.2. Phạm vi sản phẩm (Product Scope)
- **Trong phạm vi (In-Scope)**:
  - Dịch vụ **đồng hành & chăm sóc phi y tế (Non-medical companion)**: Trò chuyện, nhắc giờ uống thuốc theo đơn có sẵn, dạo bộ, hỗ trợ ăn uống, đọc sách/báo.
  - Quản lý hồ sơ người cao tuổi (`C-BEN`) & Gợi ý thực đơn dinh dưỡng theo bệnh nền (`C-NUT`).
  - Đặt lịch theo ca linh hoạt (ca lẻ hoặc định kỳ) với quy trình 6 bước rõ ràng (`C-BOOK-01..06`).
  - Thanh toán số tích hợp cổng PayOS với cơ chế đối soát (`C-PAY`).
  - Giám sát ca trực thời gian thực: Check-in định vị GPS, nhật ký hoạt động kèm ảnh minh chứng (`C-SHIFT-LIVE`, `C-SHIFT-TIMELINE`).
  - Cơ chế an toàn: Báo mất mạng ngoại tuyến (`C-SHIFT-OFFLINE`) và gửi khiếu nại (`C-SHIFT-DISPUTE`).
- **Ngoài phạm vi (Out-of-Scope)**:
  - *Tuyệt đối không thực hiện thủ thuật y tế xâm lấn*: Không tiêm truyền, không đặt ống sonde, không kê đơn/chẩn đoán bệnh, không sơ cứu chấn thương nặng.
  - Không thay thế dịch vụ cấp cứu 115.
  - Không làm công việc giúp việc dọn dẹp nhà cửa nặng (tổng vệ sinh công nghiệp).

---

## 1.2. Stakeholder & User Map

```
                          ┌──────────────────────────────────────┐
                          │         HỆ SINH THÁI CARESITTER      │
                          └──────────────────┬───────────────────┘
                                             │
      ┌──────────────────────┬───────────────┴──────────────┬──────────────────────┐
      │                      │                              │                      │
┌─────▼──────────────┐ ┌─────▼──────────────┐        ┌──────▼─────────────┐ ┌──────▼─────────────┐
│    PRIMARY USER    │ │ DIRECT BENEFICIARY │        │  SERVICE PROVIDER  │ │ INTERNAL / SUPPORT │
├────────────────────┤ ├────────────────────┤        ├────────────────────┤ ├────────────────────┤
│ Người con đặt lịch │ │ Người già tiếp nhận│        │ Chăm sóc viên      │ │ Đội ngũ vận hành   │
│ & trả tiền (P01)   │ │ chăm sóc (P02)     │        │ Caregiver (P03)    │ │ & CSKH (P04)       │
├────────────────────┤ ├────────────────────┤        ├────────────────────┤ ├────────────────────┤
│ • Hoàng Lan (36t)  │ │ • Bác Tuấn (68t)   │        │ • Hạnh (24t)       │ │ • Quang Minh (31t) │
│ • Ra quyết định    │ │ • Bệnh tiểu đường  │        │ • Nhận việc theo ca│ │ • Giải quyết tranh │
│ • Thanh toán số    │ │ • Cần tôn trọng,   │        │ • Cập nhật timeline│ │   chấp, đối soát   │
│ • Theo dõi từ xa   │ │   ăn đúng chế độ   │        │ • Di chuyển ngoài đ│ │   tiền nong        │
└────────────────────┘ └────────────────────┘        └────────────────────┘ └────────────────────┘
```

- **Nhóm người dùng dễ bị bỏ sót**: Người cao tuổi bị suy giảm nhận thức nhẹ hoặc thị lực kém $\rightarrow$ Được nhóm đưa vào vị trí **Persona 02 (Secondary)** để định hình trực tiếp chuẩn Accessibility (chữ $\ge 14\text{sp}$, nút $\ge 48\text{dp}$, tương phản $\ge 4.5:1$).

---

## 1.3. Brainstorming & Affinity Board

Quá trình Brainstorming theo mô hình Double Diamond (*Diverge $\rightarrow$ Cluster $\rightarrow$ Converge*) trong workshop 100 phút đã phân loại toàn bộ ý tưởng và dữ liệu khảo sát thành 4 cụm chủ đề cốt lõi (Affinity Clusters):

```
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│ CỤM 1: MINH BẠCH & AN TÂM TỪ XA │   │ CỤM 2: PHÁP LÝ & AN TOÀN PHI Y TẾ│
├─────────────────────────────────┤   ├─────────────────────────────────┤
│ • "Ở cơ quan không tập trung    │   │ • "Sợ người giúp việc tự ý cho  │
│   vì không biết mẹ đã ăn chưa"  │   │   uống thuốc linh tinh gây biến │
│ • Cần ảnh thật khay cơm sau ca  │   │   chứng"                        │
│ • Check-in GPS đúng giờ đến/về  │   │ • Phải cam kết rõ ràng không    │
│ • Thông báo đẩy khi có hoạt động│   │   tiêm truyền trước khi thanh   │
│ ➔ Màn: C-SHIFT-LIVE, TIMELINE   │   │   toán ➔ Màn: C-BOOK-05         │
└─────────────────────────────────┘   └─────────────────────────────────┘
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│ CỤM 3: RÀO CẢN SỨC KHỎE NGƯỜI GIÀ│  │ CỤM 4: RÀO CẢN KỸ THUẬT HIỆN TRƯỜNG│
├─────────────────────────────────┤   ├─────────────────────────────────┤
│ • "Người già mắt kém, tay run"  │   │ • "Chung cư vào thang máy là mất│
│ • "Ăn kiêng tiểu đường nhưng    │   │   4G, app bị văng dữ liệu"      │
│   thèm ăn vặt"                  │   │ • "Đang đỡ người già không thể  │
│ • Dừng gợi ý nếu có bệnh lý nặng│   │   gõ chữ dài dòng"              │
│ ➔ Màn: C-NUT-07, C-NUT-STATE-01 │   │ ➔ Màn: C-SHIFT-OFFLINE, Tag pill│
└─────────────────────────────────┘   └─────────────────────────────────┘
```

---

## 1.4. Persona Coverage Matrix

| Phân khúc | Tên / Vai trò | Mức ưu tiên | Ngữ cảnh sử dụng | Rào cản cốt lõi | Màn hình Stitch trực tiếp |
| :--- | :--- | :---: | :--- | :--- | :--- |
| **Gia đình** | **P01 · Hoàng Lan** (36t) | **Primary** | Văn phòng, vừa họp vừa lướt app | Thiếu thời gian, lo sợ rủi ro pháp lý/an toàn | `C-BOOK-01..06`, `C-PAY-METHOD`, `C-SHIFT-LIVE` |
| **Người già** | **P02 · Bác Tuấn** (68t) | **Secondary** | Ở nhà một mình, đọc tin chậm | Mắt mờ, tay run, tự trọng cao, bệnh nền tiểu đường | `C-BEN-DETAIL`, `C-NUT-07`, `C-NUT-STATE-01..03` |
| **Hiện trường** | **P03 · Nguyễn Hạnh** (24t) | **Secondary** | Nhà khách hàng, di chuyển liên tục | Mất sóng 4G, bận tay thể chất, sợ bị đổ lỗi oan | `C-SHIFT-TIMELINE`, `C-SHIFT-OFFLINE` |
| **Vận hành** | **P04 · Quang Minh** (31t) | **Supporting** | Bàn làm việc CSKH với 2 màn hình | Khách khiếu nại thiếu bằng chứng, giao dịch treo | `C-PAY-REVIEW`, `C-SHIFT-DISPUTE` |

---

## 1.5. Proto-Personas & Danh mục giả định (Assumption Backlog)

- **Proto-P01 (Lan)**:
  - *Assumed-01*: Giả định rằng người đặt lịch sẵn sàng đọc kỹ điều khoản phi y tế ở `C-BOOK-05` thay vì bấm lướt qua.
  - *Assumed-02*: Giả định rằng khách hàng chuộng thanh toán mã QR PayOS hơn tiền mặt để minh bạch tài chính.
- **Proto-P02 (Bác Tuấn)**:
  - *Assumed-03*: Giả định rằng người cao tuổi thích tự duyệt món ăn thay thế trên app (`C-NUT-09`) thay vì để người chăm sóc tự ý nấu.
- **Proto-P03 (Hạnh)**:
  - *Assumed-04*: Giả định rằng chăm sóc viên sẵn sàng chụp ảnh khay cơm và hoạt động sau mỗi công việc mà không thấy phiền toái.
- **Proto-P04 (Minh)**:
  - *Assumed-05*: Giả định rằng timeline lưu trên PostgreSQL đủ tính pháp lý để hòa giải mọi tranh chấp ca trực.

---

# PHẦN 2: MILESTONE B — VALIDATION & DESIGN

## 2.1. Candidate Evidence Register — chưa xác minh nguồn nghiên cứu gốc

Theo Persona Guideline, không được tự tạo quote, cuộc phỏng vấn, số liệu hoặc chi tiết cá nhân rồi trình bày như fact. Workspace hiện chưa có consent, ngày/phương thức phỏng vấn, ghi chú/transcript ẩn danh hoặc người thu thập tương ứng với `[EV-01]`–`[EV-04]`. Vì vậy bốn mục dưới đây là **giả thuyết nghiên cứu**, không phải “verbatim quote” và không được dùng để tuyên bố đã phỏng vấn thực địa.

| ID ứng viên | Nhóm cần kiểm chứng | Giả thuyết/pattern cần hỏi hoặc quan sát | Nhãn hiện tại | Điều kiện nâng nhãn |
| :--- | :--- | :--- | :---: | :--- |
| `[EV-01]` | Người con đặt lịch | Cần xác thực caregiver, ranh giới phi y tế và cập nhật ảnh ngắn để an tâm khi làm việc | `Assumed` | Có note/transcript ẩn danh, ngày, phương thức, consent và người thu thập |
| `[EV-02]` | Người cao tuổi | Ưu tiên được tôn trọng, giao tiếp phù hợp và bữa ăn dễ dùng theo hồ sơ đã xác nhận | `Assumed` | Có phỏng vấn/quan sát trực tiếp và không suy diễn chẩn đoán y khoa |
| `[EV-03]` | Caregiver | Mạng yếu và thao tác tại hiện trường có thể làm gián đoạn ghi nhận ca | `Assumed` | Có observation/task evidence hoặc interview note truy vết được |
| `[EV-04]` | Vận hành/CSKH | Cần tập hợp timeline, vị trí, ảnh và thanh toán để xử lý tranh chấp | `Inferred` | Có workflow/ticket ẩn danh hoặc interview note của nhân sự vận hành |

**Research backlog tối thiểu:** tuyển 6–12 người theo khuyến nghị lớp học, phủ các nhóm P01–P04; ghi consent và metadata; lưu note ẩn danh; mã hóa `Observed/Reported`; tạo affinity clusters từ evidence ID; cập nhật persona và giữ lại assumption nào chưa được xác nhận.

---

## 2.2. Hồ sơ chi tiết 4 Persona (Chuẩn 12 trường cốt lõi + Bắt buộc Lab 2)

### 🧑‍💼 PERSONA 01 (PRIMARY) — HOÀNG THỊ LAN
1. **Identity & Archetype**: Hoàng Thị Lan (36 tuổi) · *Người con bận rộn đặt lịch chăm sóc từ xa (Remote Family Caregiver)* · Trưởng phòng Tài chính.
2. **Persona Priority**: **Primary Persona (Ưu tiên số 1)** · Người ra quyết định chi trả và điều hướng luồng chính của app.
3. **Usage Context**: Mở app lúc 7h30 sáng hoặc 14h00 giữa các cuộc họp tại văn phòng; dùng iPhone 14/15; độ chú ý phân tán cao do công việc.
4. **Goals**: (1) Đặt được chăm sóc viên uy tín trong $< 5\text{ phút}$; (2) Nắm tiến độ thực tế của mẹ mà không phải gọi điện ngắt lời; (3) Minh bạch chi phí và an toàn pháp lý.
5. **Job to Be Done**: *“Khi tôi bận rộn họp hành ở công ty mà mẹ ở nhà một mình cần người trò chuyện, nhắc uống thuốc và nấu ăn, tôi muốn đặt một chăm sóc viên uy tín và theo dõi trực tiếp nhật ký ca trực trên điện thoại, để tôi có thể yên tâm tập trung công việc mà mẹ vẫn được chăm sóc chu đáo.”*
6. **Current Behaviors**: Đăng bài tìm người trên Facebook hoặc nhờ người quen; dùng camera quan sát gián đoạn giấc ngủ của mẹ; tần suất đặt 3 buổi/tuần.
7. **Pain Points**: (1) Lo sợ người lạ ngược đãi hoặc trộm cắp; (2) Camera không biết mẹ đã ăn cơm chưa; (3) Mập mờ ranh giới y tế gây biến chứng.
8. **Motivations**: Sự an tâm tuyệt đối (Peace of mind) và tính minh bạch tài chính/pháp lý.
9. **Constraints**: Cực kỳ ít thời gian; cần bản cam kết dịch vụ phi y tế trước khi trả tiền.
10. **Key Scenarios**: Đặt lịch khẩn cấp 4 tiếng cho mẹ vào chiều mai, chọn Caregiver 5 sao, đồng ý điều khoản phi y tế và thanh toán PayOS trong 3 phút.
11. **Success Criteria**: Hoàn thành flow `C-BOOK-01..06` $< 3.5\text{ phút}$; Tỷ lệ hiểu lầm điều khoản phi y tế = 0%; Điểm an tâm $\ge 4.5/5$.
12. **Evidence & Status**: *Proto-persona hypothesis (Assumed)* · Mã ứng viên `[EV-01]`; `[CS-INT-01]` chưa có artefact nguồn trong workspace.
* **Trường bắt buộc Lab 2 (Lab 2 Mandatory Requirements)**:
  - *Tuổi (Age)*: 36 tuổi.
  - *Vai trò (Role)*: Khách hàng chính (Primary Customer / Payer) — Đặt lịch và thanh toán.
  - *Thói quen dùng thiết bị (Device Habits)*: Sử dụng iPhone 14 Pro Max một tay khi đang di chuyển hoặc ngồi máy tính văn phòng; thao tác lướt nhanh, ưa chuộng thông báo đẩy (push notification) ngắn gọn.
  - *Nhu cầu Accessibility (Accessibility Needs)*: Bố cục nút bấm rõ ràng ở nửa dưới màn hình (thumb zone), thông báo trạng thái đơn hàng có màu sắc tương phản cao $\ge 4.5:1$ để nhận biết nhanh trong điều kiện ánh sáng văn phòng.
  - *Problem Statement riêng*: *“Chị Lan cần phương thức đặt dịch vụ chăm sóc người già tin cậy, xác thực danh tính và có cam kết phi y tế minh bạch trong vòng dưới 5 phút, để vừa chu toàn việc gia đình vừa không bị gián đoạn công việc tại công ty.”*
  - *Tiêu chí thành công đo được*: Thời gian hoàn tất đặt lịch và quét PayOS $< 3\text{ phút } 30\text{ giây}$; Tỷ lệ xác nhận cam kết phi y tế đạt $100\%$.
  - *Bản chất bằng chứng (Evidence Nature)*: **Assumed** cho đến khi có note/transcript ẩn danh và metadata phỏng vấn. Thiết bị, nghề nghiệp và bối cảnh cụ thể hiện là chi tiết dựng thiết kế.

---

### 👴 PERSONA 02 (SECONDARY) — BÁC TRẦN VĂN TUẤN
1. **Identity & Archetype**: Bác Trần Văn Tuấn (68 tuổi) · *Người cao tuổi có bệnh nền, tự trọng cao (Dignified Senior)* · Giáo viên nghỉ hưu, góa vợ.
2. **Persona Priority**: **Secondary Persona** · Người tiếp nhận dịch vụ trực tiếp; quyết định sự gắn bó lâu dài của khách hàng.
3. **Usage Context**: Ở nhà một mình cả ngày; dùng Samsung màn hình to, chữ phóng to; mắt viễn thị, tay run nhẹ.
4. **Goals**: (1) Có bạn cờ, bạn dạo bộ lễ phép; (2) Bữa ăn ngon miệng, đúng khẩu vị nhưng kiểm soát đường huyết; (3) Giữ gìn sự độc lập và tự tôn.
5. **Job to Be Done**: *“Khi tôi ở nhà một mình và thấy trống trải, buồn chán, tôi muốn có một người bạn đồng hành lịch sự, biết lắng nghe và nấu cho tôi bữa ăn thanh đạm phù hợp sức khỏe, để tôi cảm thấy vui vẻ, khỏe khoắn mà không làm phiền công việc của con cái.”*
6. **Current Behaviors**: Tự nấu mì hoặc ăn cơm nguội qua bữa; ngồi xem tivi cả ngày; thỉnh thoảng quên uống thuốc.
7. **Pain Points**: (1) Cảm giác bị theo dõi bởi camera; (2) Ăn uống sai chế độ làm đường huyết tăng vọt; (3) Chăm sóc viên cắm mặt bấm điện thoại.
8. **Motivations**: Sự lễ phép, tôn trọng và bữa ăn nóng sốt, vừa miệng.
9. **Constraints**: Giảm thị lực và phản xạ xúc giác; bệnh nền tiểu đường Type 2 $\rightarrow$ Không được gợi ý món nhiều đường bột.
10. **Key Scenarios**: Chăm sóc viên đến, mở màn `C-NUT-07` chọn canh cá nấu ngót ăn trưa; hệ thống ngắt gợi ý tự động (`C-NUT-STATE-01`) khi có chẩn đoán bệnh mới.
11. **Success Criteria**: Tỷ lệ đọc rõ màn hình không cần kính lúp $\ge 90\%$; Mức độ hài lòng nụ cười ở màn `C-SHIFT-REVIEW` đạt 5 sao.
12. **Evidence & Status**: *Proto-persona hypothesis (Assumed)* · Mã ứng viên `[EV-02]`; `[CS-INT-02]` chưa có artefact nguồn trong workspace.
* **Trường bắt buộc Lab 2 (Lab 2 Mandatory Requirements)**:
  - *Tuổi (Age)*: 68 tuổi.
  - *Vai trò (Role)*: Người thụ hưởng dịch vụ (Beneficiary / Senior User).
  - *Thói quen dùng thiết bị (Device Habits)*: Dùng smartphone Samsung Galaxy A-series cỡ 6.5 inch, đặt độ sáng cao và bật phóng to chữ 125%; thường dùng ngón trỏ để bấm, thao tác chậm rãi.
  - *Nhu cầu Accessibility (Accessibility Needs)*: Bắt buộc tuân thủ chuẩn WCAG 2.1 AA — Cỡ chữ nội dung $\ge 16\text{sp}$, độ tương phản $\ge 7:1$ (đạt $11.4:1$ trên CareSitter), kích thước vùng chạm tối thiểu $48\times 48\text{dp}$ (nút thực tế $54\text{px}$) để chống bấm nhầm do run tay.
  - *Problem Statement riêng*: *“Bác Tuấn cần người đồng hành thấu hiểu, lễ phép và hỗ trợ bữa ăn đúng chỉ số đường huyết mà không bị tước đi quyền tự chủ hay cảm giác bị giám sát xâm phạm đời tư.”*
  - *Tiêu chí thành công đo được*: Bác Tuấn đọc đúng tên món ăn và thành phần nguyên liệu tại `C-NUT-07` đạt $\ge 90\%$ không cần đeo kính lão; tỷ lệ bấm nhầm nút $< 2\%$.
  - *Bản chất bằng chứng (Evidence Nature)*: **Assumed & Inferred**; chưa có artefact phỏng vấn hoặc trích dẫn nguồn y khoa gắn trực tiếp với claim này. Không dùng persona để chẩn đoán hoặc quyết định dinh dưỡng lâm sàng.

---

### 👩‍⚕️ PERSONA 03 (SECONDARY) — NGUYỄN THỊ HẠNH
1. **Identity & Archetype**: Nguyễn Thị Hạnh (24 tuổi) · *Chăm sóc viên chuyên nghiệp, trẻ tuổi (Junior Companion)* · Tốt nghiệp Trung cấp Điều dưỡng.
2. **Persona Priority**: **Secondary Persona** · Người thao tác trực tiếp tại hiện trường.
3. **Usage Context**: Di chuyển bằng xe máy giữa các ca trực; dùng điện thoại Android tầm trung, 4G chập chờn; tay thường bận chăm sóc người già.
4. **Goals**: (1) Nhận ca trực gần nhà; (2) Cập nhật nhật ký ca trực nhanh bằng 1 tay; (3) Nhận thù lao minh bạch và không bị trừ tiền oan.
5. **Job to Be Done**: *“Khi tôi đang trong ca chăm sóc người già và hoàn thành các hoạt động như cho uống thuốc hay nấu ăn, tôi muốn ghi nhận nhanh nhật ký và hình ảnh bằng 1–2 chạm trên điện thoại, để con cái khách hàng nhìn thấy tiến độ tức thì mà tôi không bị phân tâm khỏi việc chăm sóc cụ.”*
6. **Current Behaviors**: Nhận việc qua trung tâm môi giới (mất phí 25%); nhắn tin Zalo riêng cho người nhà dễ bị hiểu nhầm.
7. **Pain Points**: (1) Khách đòi hỏi làm việc nặng ngoài hợp đồng; (2) Mất sóng 4G trong thang máy bị tính trễ giờ; (3) Bị đổ lỗi oan khi người già tự ngã.
8. **Motivations**: Thu nhập minh bạch và sự bảo vệ từ nền tảng bằng điều khoản rõ ràng.
9. **Constraints**: Mạng chập chờn $\rightarrow$ Cần chế độ lưu ngoại tuyến (`C-SHIFT-OFFLINE`); không thể gõ chữ dài.
10. **Key Scenarios**: Check-in định vị tại nhà khách; bấm chọn tag "Đã ăn trưa" và chụp ảnh khay cơm trong 10 giây; màn hình chuyển vàng báo lưu offline khi vào tầng hầm.
11. **Success Criteria**: Thời gian cập nhật 1 hành động $< 15\text{ giây}$; Tỷ lệ mất dữ liệu do rớt mạng = $0\%$; Tỷ lệ đồng thuận phạm vi việc làm $\ge 98\%$.
12. **Evidence & Status**: *Proto-persona hypothesis (Assumed)* · Mã ứng viên `[EV-03]`; `[CS-INT-03]` chưa có artefact nguồn trong workspace.
* **Trường bắt buộc Lab 2 (Lab 2 Mandatory Requirements)**:
  - *Tuổi (Age)*: 24 tuổi.
  - *Vai trò (Role)*: Người thực thi dịch vụ tại chỗ (Caregiver Provider).
  - *Thói quen dùng thiết bị (Device Habits)*: Dùng điện thoại Xiaomi/Oppo gắn giá đỡ xe máy; thao tác nhanh một tay (one-handed thumb gestures), quen dùng camera chụp ảnh tức thì thay vì soạn thảo văn bản.
  - *Nhu cầu Accessibility (Accessibility Needs)*: Giao diện tương phản ngoài trời nắng gắt (High outdoor contrast), các nút hành động dạng Chip/Tag to bản dễ bấm nhanh, chế độ Offline Banner màu vàng cảnh báo rõ rệt khi mất kết nối mạng.
  - *Problem Statement riêng*: *“Hạnh cần công cụ ghi nhận nhật ký ca trực siêu tốc bằng hình ảnh và tag lựa chọn sẵn có khả năng hoạt động ngoại tuyến, để bảo vệ công sức lao động mà không làm ảnh hưởng đến thời gian chăm sóc cụ.”*
  - *Tiêu chí thành công đo được*: Thời gian ghi nhận 1 hành động + chụp ảnh $< 15\text{ giây}$; Tỷ lệ dữ liệu báo cáo đồng bộ thành công sau khi có lại mạng = $100\%$.
  - *Bản chất bằng chứng (Evidence Nature)*: **Assumed**; chưa có observation log, ngày, bối cảnh, consent hoặc người ghi nhận để gọi là `Observed/Reported`.

---

### 👨‍💼 PERSONA 04 (SUPPORTING) — LÊ QUANG MINH
1. **Identity & Archetype**: Lê Quang Minh (31 tuổi) · *Chuyên viên điều phối & hòa giải tranh chấp (Operations & Dispute Specialist)* · Trưởng nhóm CSKH.
2. **Persona Priority**: **Supporting Persona** · Định hình các màn hình xử lý biên và tranh chấp.
3. **Usage Context**: Bàn làm việc CSKH với 2 màn hình lớn, tai nghe trực tổng đài từ 7h00 đến 21h00.
4. **Goals**: (1) Phân loại khiếu nại $< 15\text{ phút}$; (2) Đối soát mở khóa thanh toán treo PayOS; (3) 100% ca sự cố được xử lý công bằng.
5. **Job to Be Done**: *“Khi khách hàng và chăm sóc viên có bất đồng về chất lượng hoặc thời gian ca trực, tôi muốn truy xuất được toàn bộ bằng chứng lịch sử ca trực và hình ảnh báo cáo, để tôi đưa ra quyết định xử lý khiếu nại công bằng, giữ được uy tín của nền tảng.”*
6. **Current Behaviors**: Đọc tin nhắn Zalo hai bên rất mất thời gian; xuất file Excel đối soát ngân hàng thủ công.
7. **Pain Points**: (1) Khách khiếu nại không có bằng chứng; (2) Giao dịch treo làm khách giận dữ; (3) Thông tin rải rác.
8. **Motivations**: Tính khách quan dựa trên log hệ thống và tỷ lệ giải quyết khiếu nại lần đầu (First Contact Resolution).
9. **Constraints**: Tuân thủ bảo mật thông tin cá nhân (PII); chính sách hoàn hủy tiền của công ty.
10. **Key Scenarios**: Nhận ticket khiếu nại từ `C-SHIFT-DISPUTE`, đối chiếu log GPS check-out lúc 11h45 thay vì 12h00, duyệt hoàn tiền 15% giờ thừa tự động.
11. **Success Criteria**: Tỷ lệ khiếu nại có đủ bằng chứng xử lý ngay $\ge 95\%$; Thời gian xử lý khiếu nại $< 30\text{ phút}$; CSAT sau hòa giải $\ge 85\%$.
12. **Evidence & Status**: *Proto-persona hypothesis (Inferred)* · Mã ứng viên `[EV-04]`; `[CS-OPS-01]` chưa có workflow/ticket/interview nguồn trong workspace.
* **Trường bắt buộc Lab 2 (Lab 2 Mandatory Requirements)**:
  - *Tuổi (Age)*: 31 tuổi.
  - *Vai trò (Role)*: Vận hành nội bộ & Hòa giải sự cố (Operations & CSKH).
  - *Thói quen dùng thiết bị (Device Habits)*: Sử dụng máy tính bàn 2 màn hình (Desktop Web Admin), bàn phím cơ gõ nhanh, quen dùng các phím tắt và bộ lọc trạng thái đơn hàng.
  - *Nhu cầu Accessibility (Accessibility Needs)*: Bảng dữ liệu có kẻ sọc rõ ràng (striped rows), trạng thái đơn hàng phân biệt bằng cả màu sắc lẫn nhãn chữ (Badge + Text label) để tránh nhầm lẫn cho người mù màu.
  - *Problem Statement riêng*: *“Minh cần bảng điều phối hiển thị trọn vẹn lịch sử GPS, ảnh timeline và trạng thái thanh toán PayOS trên một giao diện thống nhất, để giải quyết khiếu nại khách quan trong dưới 30 phút.”*
  - *Tiêu chí thành công đo được*: Thời gian truy xuất đủ bằng chứng ca trực $< 2\text{ phút}$; Tỷ lệ khiếu nại hòa giải thành công lần đầu $\ge 85\%$.
  - *Bản chất bằng chứng (Evidence Nature)*: **Inferred** (Suy luận logic từ quy trình CSKH thực tế và nghiệp vụ cổng thanh toán PayOS).

---

## 2.3. Persona Scenarios & Task Flows

### 2.3.1. Happy Path Flow (Persona 01: Hoàng Lan)
```
[Màn chủ] ──> [C-BOOK-01: Chọn dịch vụ] ──> [C-BOOK-02: Chọn mẹ] ──> [C-BOOK-03: Ngày giờ, Địa chỉ]
  ──> [C-BOOK-04: Chọn Caregiver 5★] ──> [C-BOOK-05: Tích cam kết Phi y tế] ──> [C-BOOK-06: Tóm tắt chi phí]
  ──> [C-PAY-METHOD: Quét PayOS QR] ──> [C-PAY-RESULT: Thành công] ──> [C-SHIFT-LIVE: Giám sát thời gian thực]
```

### 2.3.2. Edge Case Flow (Persona 03: Caregiver Hạnh - Xử lý mất mạng)
```
[Caregiver chụp ảnh khay cơm] ──> [Mất kết nối Internet] ──> [Màn hình C-SHIFT-OFFLINE (Banner vàng)]
  ──> [Lưu ảnh & timestamp vào local device] ──> [Có lại kết nối 4G/Wifi] ──> [Tự động đồng bộ lên Server]
  ──> [Màn hình C-SHIFT-TIMELINE của khách hàng cập nhật tức thì]
```

---

## 2.4. Ma trận: Persona $\rightarrow$ User Need $\rightarrow$ UI Decision $\rightarrow$ Test Metric

| Persona | Nhu cầu thực tế (User Need) | Quyết định thiết kế trên Stitch | Mã màn hình Stitch tương ứng | Tiêu chuẩn đo lường (Test Metric) |
| :--- | :--- | :--- | :--- | :--- |
| **P01** (Lan) | Sợ tranh chấp pháp lý và người làm vượt thẩm quyền y khoa. | Tách riêng màn hình cam kết phi y tế bắt buộc tích chọn trước khi thanh toán. | `C-BOOK-05` (Điều khoản phi y tế) | 100% người dùng hiểu rõ dịch vụ không bao gồm tiêm truyền y tế. |
| **P01** (Lan) | Muốn nắm tiến độ ca trực khi đang ngồi họp cơ quan. | Thiết kế thanh tiến trình thời gian thực kèm card ảnh chụp từng hoạt động. | `C-SHIFT-LIVE`, `C-SHIFT-TIMELINE` | Điểm số an tâm Likert $\ge 4.5/5$. Thời gian kiểm tra tiến độ $< 10\text{s}$. |
| **P02** (Tuấn) | Mắt viễn thị kém, run tay, có bệnh nền tiểu đường nguy hiểm. | Dùng font Inter $\ge 14\text{sp}$, touch target $\ge 48\text{dp}$. Tự động ngắt gợi ý thực đơn khi bệnh án bất thường. | `C-NUT-07`, `C-NUT-STATE-01` | Người cao tuổi đọc đúng tên món ăn không cần trợ giúp $\ge 90\%$. Tỷ lệ bấm nhầm $< 2\%$. |
| **P03** (Hạnh) | Mất mạng 4G khi vào nhà kín hoặc tầng hầm chung cư. | Xây dựng màn hình thông báo lưu đệm ngoại tuyến (Offline cache) và tự đồng bộ khi có sóng. | `C-SHIFT-OFFLINE` | Tỷ lệ dữ liệu báo cáo bị mất khi ngắt kết nối mạng = $0\%$. Thời gian phục hồi $< 3\text{s}$. |
| **P04** (Minh) | Cần bằng chứng xác thực để giải quyết tranh chấp hoàn hủy tiền công bằng. | Tích hợp form đính kèm lý do khiếu nại đối soát trực tiếp với log GPS và ảnh timeline. | `C-SHIFT-DISPUTE`, `C-PAY-REVIEW` | Giảm thời gian xử lý khiếu nại trung bình xuống $< 30\text{ phút}$. CSAT sau hòa giải $\ge 85\%$. |

---

## 2.5. Tiêu chuẩn Accessibility & UX Checklist

> Các trạng thái dưới đây là kết quả tự kiểm tra được ghi trong bản MD, không phải approval của reviewer. Cần đối chiếu lại sau khi chốt design system và màn hình Stitch hiện hành.

| Hạng mục kiểm tra | Tiêu chuẩn PRM393 / WCAG 2.1 AA | Kết quả triển khai trên Stitch | Trạng thái |
| :--- | :--- | :--- | :---: |
| **Độ tương phản màu sắc** | $\ge 4.5:1$ (Văn bản thường) / $\ge 3:1$ (Đồ họa UI) | Chữ `#273126` trên nền `#F8F9EF` đạt tỉ lệ **11.4:1** (vượt chuẩn AAA). Nút xanh `#496534` trên nền trắng đạt **6.8:1**. | **Tự kiểm tra — cần xác minh lại sau khi chốt token** |
| **Kích thước vùng chạm** | Tối thiểu $48 \times 48\text{dp}$ | Nút bấm chính có chiều cao cố định **$54\text{px}$**, full-width; Checkbox và radio control nằm trong khung chạm tối thiểu **$48\text{dp}$**. | **Tự kiểm tra — cần kiểm tra trên màn hình thực tế** |
| **Cỡ chữ hiển thị** | Tối thiểu $14\text{sp}$ (body), $16\text{sp}$ (core instruction) | Body text mặc định **$14\text{px}$**, phụ đề dinh dưỡng **$16\text{px}$**, tiêu đề **$20 - 30\text{px}$**, font Inter chống nhòe. | **Tự kiểm tra — cần đối chiếu với Stitch hiện hành** |
| **Trạng thái giao diện** | 8 interaction states | Có đủ: Empty state (`C-BOOK-EMPTY`, `C-NUT-EMPTY`), Loading sync (`C-PAY-SYNC`), Error (`C-PAY-FAIL`), Offline (`C-SHIFT-OFFLINE`), Dispute (`C-SHIFT-DISPUTE`). | **Có trong hồ sơ — cần lập bảng đối chiếu màn hình** |

---

## 2.6. Số liệu Usability Testing giả lập — chưa phải kiểm chứng thực địa

> Các số liệu bên dưới chỉ được dùng làm mục tiêu/minh họa cho prototype. Chỉ gọi là kết quả test khi có evidence thực tế, người tham gia ẩn danh, task script, kết quả từng người và cách tính.
- **Quy mô**: 5 người tham gia (3 khách hàng văn phòng, 1 người cao tuổi, 1 sinh viên điều dưỡng).
- **Kết quả đo lường**:
  - **Tỷ lệ hoàn thành tác vụ (Task Completion Rate)**: $100\%$ (5/5 hoàn thành).
  - **Thời gian đặt lịch trung bình**: $2\text{ phút } 45\text{ giây}$ (mục tiêu $< 3.5\text{ phút}$).
  - **Thời gian cập nhật nhật ký Caregiver**: $12\text{ giây}$ (mục tiêu $< 15\text{ giây}$).
  - **Điểm System Usability Scale (SUS)**: **$88.5 / 100\text{ điểm}$** (Grade A — Xuất sắc).

---

# PHẦN 3: BẢNG MỨC SẴN SÀNG RUBRIC — CHƯA PHẢI GATE APPROVAL

> Guideline dùng rubric 10 tiêu chí như công cụ tự rà soát. Điểm số không thay cho evidence hoặc reviewer approval. Bảng dưới dùng ba trạng thái: `[x]` có artefact cấu trúc, `[~]` có bản nháp nhưng thiếu bằng chứng, `[ ]` chưa có.

```
PERSONA SELF-REVIEW
[x] 1. Đã xác định phạm vi sản phẩm, các tác vụ trọng tâm và nhóm người dùng liên quan.
[x] 2. Có User/Stakeholder Map và đã cân nhắc người dùng dễ bị bỏ sót.
[x] 3. Số Persona phù hợp phạm vi; nếu chỉ có 1 thì có lý giải dựa trên nghiên cứu.
[~] 4. Persona được phân biệt bằng goals, behaviors, contexts hoặc constraints; các khác biệt hiện vẫn là giả thuyết cần nghiên cứu xác nhận.
[x] 5. Mỗi Persona có đủ 12 trường cốt lõi, ngắn gọn và dễ sử dụng.
[x] 6. Nhu cầu được mô tả theo kết quả mong muốn, không ngụy trang một tính năng thành nhu cầu.
[~] 7. Đã hạ `[EV-01]`–`[EV-04]` về Assumed/Inferred; chưa có research evidence gốc để nâng lên Reported/Observed.
[~] 8. Có Affinity Board dạng bản nháp; chưa có evidence ID đã xác minh để chứng minh pattern và phân khúc.
[x] 9. Mỗi Primary Persona có scenario và success criteria cụ thể.
[x] 10. Có ít nhất một quyết định/giả thuyết UI và phương pháp kiểm chứng liên kết đến Persona.

KẾT LUẬN: PHỦ 10/10 MỤC VỀ CẤU TRÚC; 3 MỤC CÒN PARTIAL (4, 7, 8) · GATE G2: CHƯA APPROVED
```

---

# PHẦN 4: BỘ CÂU HỎI PHẢN BIỆN KHI THUYẾT TRÌNH TRƯỚC GIẢNG VIÊN

1. **Giảng viên hỏi:** *“Tại sao nhóm lại thiết kế màn hình mất mạng `C-SHIFT-OFFLINE`? Có cần thiết cho đồ án không?”*
   - **Trả lời:** *“Dạ thưa thầy/cô, đây là giả thuyết thiết kế gắn với **Persona 03 (Bạn Hạnh - Caregiver)** và mã ứng viên `[EV-03]`: kết nối yếu có thể làm gián đoạn ghi nhận ca. Nhóm đã thiết kế hướng offline để thử nghiệm, nhưng chưa gọi đây là kết quả phỏng vấn cho đến khi có research note truy vết được.”*

2. **Giảng viên hỏi:** *“Tại sao lại có màn hình `C-BOOK-05` về Điều khoản dịch vụ phi y tế trước khi thanh toán?”*
   - **Trả lời:** *“Dạ thưa thầy/cô, đây là giả thuyết an toàn của **Persona 01 (Chị Lan)**, mã ứng viên `[EV-01]`. Màn hình giúp truyền đạt phạm vi chăm sóc phi y tế trước thanh toán; nhóm cần usability test để xác nhận người dùng thực sự hiểu, thay vì chỉ đo việc họ tích checkbox.”*

3. **Giảng viên hỏi:** *“Nhóm đảm bảo tính tiếp cận (Accessibility) cho người cao tuổi như thế nào?”*
   - **Trả lời:** *“Dạ thưa thầy/cô, từ giả thuyết của **Persona 02 (Bác Tuấn)**, nhóm đặt mục tiêu chữ dễ đọc, vùng chạm tối thiểu $48\times48\text{dp}$ và tương phản đạt ngưỡng WCAG. Các giá trị phải được đo lại trên frame/build cuối và thử với người dùng; hiện chưa tuyên bố đã đạt audit.”*
