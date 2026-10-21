# HỒ SƠ MINH CHỨNG RÀ SOÁT PRM393 — CARESITTER

**Ngày lập:** 17/10/2026 · **Cập nhật đối chứng:** 21/10/2026  
**Phạm vi:** Rà soát hồ sơ Persona, prototype và mức truy vết sang source hiện có; không xác nhận code/prototype chỉ bằng tuyên bố trong tài liệu.  
**Dự án Stitch:** [LAB2 - CareSitter](https://stitch.withgoogle.com/projects/16914427060621528532)  
**Tài liệu Persona hiện có:** [PRM393_PERSONA_VA_THIET_KE_CARESITTER.md](PRM393_PERSONA_VA_THIET_KE_CARESITTER.md)  
**Link minh chứng cuộc trò chuyện (Chat Evidence):** [Mở cuộc trò chuyện ChatGPT rà soát](https://chatgpt.com/s/cx_6ad371cf90308191ab53a511a2212c74)  
**Link Figma chính thức:** [Figma LAB02_CareSystem](https://www.figma.com/design/Ph22SZvtVFwWzohuaia1UC/LAB02_CareSystem?node-id=0-1&t=y8TBlIsxnOdSbWSD-1)  
**Link Figma Make (Image Retrieval):** [Figma Make - Mobile app](https://www.figma.com/make/zYbuvraAFDQoVb6wEXhpnH/Mobile-app-image-retrieval?t=HrAK44qDKK2rzSvZ-1)  
**Link Canva Slide Presentation:** [Canva 12 Slides](https://canva.link/55qt0sv9dsz7w3g)  
**Link Google Docs:** [Tài liệu tổng hợp Google Docs](https://docs.google.com/document/d/1fBMiqKdpAtMjy8XKDpX7-WQMsufw5_SPwp1s8oMFH_8/edit?usp=sharing)  
**Báo cáo đối chứng guideline/repository:** [PRM393_DOI_CHIEU_PERSONA_GUIDELINE_2026-10-21.md](PRM393_DOI_CHIEU_PERSONA_GUIDELINE_2026-10-21.md)  

> File này là bản tổng hợp minh chứng từ các nguồn đã truy cập và tài liệu local. Link cuộc trò chuyện chỉ dùng để truy vết quá trình rà soát; không thay thế GitHub, Figma, evidence nghiên cứu hoặc reviewer approval chính thức.

## 1. Nguồn đã kiểm tra

| Nguồn | Vai trò | Kết quả ghi nhận |
| :--- | :--- | :--- |
| [Quality Gates](https://prm393-material.web.app/quality-gates.html) | Quy trình P0–P5 và điều kiện duyệt gate | P0 vẫn `Needs revision`; sau khi ghi evidence đã đánh dấu `3/6` điều kiện P0, tổng `3/36`, và chưa có gate được phê duyệt |
| [Persona Guideline](https://prm393-material.web.app/persona-guideline.html) | Yêu cầu Persona, evidence và deliverables | Yêu cầu 12 trường Persona, phân biệt Observed/Reported/Inferred/Assumed và có scenario cho Primary Persona |
| [UI Checklist](https://prm393-material.web.app/ui-checklist.html) | Rubric review giao diện | 20 tiêu chí, 5 nhóm, 100 điểm; từ 80 điểm là đạt theo rubric nội bộ |
| [Lab 2 — Slide & Demo](https://prm393-material.web.app/lab2-presentation.html) | Hồ sơ cần nộp và cách trình bày | Đề gốc yêu cầu GitHub repository và Figma link; slide/demo là hình thức trình bày bằng chứng |
| [Stitch Project](https://stitch.withgoogle.com/projects/16914427060621528532) | Prototype và các màn hình hiện có | Có flow đặt lịch, hồ sơ người được chăm sóc, thực đơn, thanh toán, theo dõi ca, offline và hoạt động ca |
| [Persona MD hiện tại](PRM393_PERSONA_VA_THIET_KE_CARESITTER.md) | Artefact do nhóm tổng hợp | Có scope, stakeholder map, affinity board, 4 Persona, assumption backlog, flow, ma trận UI và self-review |
| [Repository LAB2_PRM tham khảo](https://github.com/ThwnThwn/LAB2_PRM/tree/ed54edd4c61b020c4811e5ae3eebc44291276d6d) | Mẫu cấu trúc hồ sơ tại commit đã đối chiếu | Có báo cáo, handoff và preview slide; không có research note gốc nên không phải nguồn độc lập xác nhận `[EV-01..04]` |

## 2. Bản đồ đầy đủ Milestone, Phase và bối cảnh

### 2.1. Milestone A — Discovery

| Hạng mục | Bối cảnh/yêu cầu | Minh chứng hiện có | Đánh dấu |
| :--- | :--- | :--- | :---: |
| Problem Statement | Người con bận rộn cần giải pháp tin cậy để người thân cao tuổi được đồng hành và hỗ trợ sinh hoạt phi y tế tại nhà | Phần `1.1` trong [Persona MD](PRM393_PERSONA_VA_THIET_KE_CARESITTER.md) | [x] |
| Product Scope | Trong phạm vi: trò chuyện, hỗ trợ sinh hoạt, hồ sơ người cao tuổi, đặt lịch, thanh toán, theo dõi ca; ngoài phạm vi: chẩn đoán, kê đơn, thủ thuật y tế và cấp cứu | Phần `1.1.2` trong Persona MD | [x] |
| Stakeholder/User Map | Người đặt lịch, người cao tuổi, Caregiver và đội vận hành/CSKH | Phần `1.2` trong Persona MD | [x] |
| Brainstorming/Affinity | Gom các pain point về an toàn, cô đơn, mất mạng, bằng chứng tranh chấp và minh bạch thanh toán | Phần `1.3` trong Persona MD | [x] |
| Persona Coverage Matrix | 4 nhóm: Primary, Secondary và Supporting; mỗi nhóm có tác vụ và rào cản khác nhau | Phần `1.4` trong Persona MD | [x] |
| Assumption Backlog | Giả định về việc đọc điều khoản, thanh toán QR, chọn món, chụp ảnh và giá trị pháp lý của timeline | Phần `1.5` trong Persona MD | [x] |
| MVP/Impact × Feasibility | Cần chứng minh phạm vi MVP và lý do ưu tiên so với các ý tưởng khác | Có scope và assumption; chưa thấy bảng Impact × Feasibility riêng | [~] |

**Bối cảnh sản phẩm của Milestone A:**

- Dịch vụ là **đồng hành và chăm sóc đời sống phi y tế**, không thay thế bệnh viện, điều dưỡng y khoa hoặc cấp cứu 115.
- Người đặt lịch thường bị phân tán sự chú ý trong giờ làm việc và cần hoàn thành tác vụ nhanh.
- Người cao tuổi cần sự tôn trọng, giao diện dễ đọc và hỗ trợ sinh hoạt phù hợp thói quen.
- Caregiver làm việc ngoài hiện trường, có thể dùng điện thoại một tay và gặp mạng 4G không ổn định.
- Bộ phận vận hành cần bằng chứng đủ tin cậy để xử lý khiếu nại và đối soát.

### 2.2. Milestone B — Validation & Design

| Hạng mục | Bối cảnh/yêu cầu | Minh chứng hiện có | Đánh dấu |
| :--- | :--- | :--- | :---: |
| Research Evidence | Evidence phải được ẩn danh và có mã nguồn; cần phân biệt Reported, Observed, Inferred, Assumed | `[EV-01]`–`[EV-04]` đã được chuyển thành candidate register `Assumed/Inferred`; chưa có source artefact gốc | [~] |
| Persona 01 — Hoàng Thị Lan | Người con bận rộn, quyết định chi trả; dùng app giữa các cuộc họp; ưu tiên an tâm, minh bạch và đặt lịch nhanh | 12 trường Persona trong phần `2.2` | [x] |
| Persona 02 — Bác Trần Văn Tuấn | Người cao tuổi ở nhà một mình; cần giao tiếp lễ phép, chữ dễ đọc, món ăn mềm/nhạt và giữ tự tôn | 12 trường Persona trong phần `2.2` | [x] |
| Persona 03 — Nguyễn Thị Hạnh | Caregiver trẻ, Android tầm trung, mạng chập chờn, thao tác một tay và cần lưu offline | 12 trường Persona trong phần `2.2` | [x] |
| Persona 04 — Lê Quang Minh | Nhân sự vận hành/CSKH cần log GPS, ảnh timeline và dữ liệu đối soát để xử lý tranh chấp | 12 trường Persona trong phần `2.2` | [x] |
| Primary Scenario | Đặt lịch → chọn người thân → chọn thời gian/địa chỉ → chọn Caregiver → đọc cam kết phi y tế → thanh toán → theo dõi ca | Happy path trong phần `2.3.1` | [x] |
| Edge Case Scenario | Chụp ảnh khi mất mạng → lưu local kèm timestamp → tự đồng bộ khi có mạng → timeline cập nhật | Edge case trong phần `2.3.2` | [x] |
| Persona → Need → UI → Test | Mỗi quyết định UI phải truy ngược được về nhu cầu và metric | Ma trận trong phần `2.4` | [x] |
| Accessibility/UX | Contrast, touch target, font size, loading/empty/error/offline/dispute states | Bảng tự kiểm trong phần `2.5` | [~] |
| Usability Test | Có người tham gia, task script, kết quả từng người, cách tính và issue/retest | Hiện mới có số liệu giả lập | [~] |

### 2.3. Bốn bối cảnh sử dụng chính

| Mã | Người dùng/bối cảnh | Mục tiêu | Rào cản | Quyết định cần kiểm chứng |
| :--- | :--- | :--- | :--- | :--- |
| P01 | Người con ở văn phòng, dùng điện thoại trong lúc họp | Đặt ca cho cha/mẹ trong vài phút và theo dõi mà không cần gọi liên tục | Ít thời gian, lo người lạ và rủi ro y tế/pháp lý | Flow 6 bước ngắn, chi phí rõ, cam kết phi y tế trước thanh toán, timeline có ảnh |
| P02 | Người cao tuổi ở nhà, màn hình lớn, thị lực và thao tác hạn chế | Được trò chuyện, hỗ trợ sinh hoạt, ăn uống phù hợp và vẫn giữ tự chủ | Chữ nhỏ, tay run, không muốn bị đối xử như bệnh nhân | Font dễ đọc, vùng chạm lớn, ngôn ngữ tôn trọng, không biến gợi ý món thành chẩn đoán |
| P03 | Caregiver di chuyển giữa các ca, Android và 4G chập chờn | Ghi nhận hoạt động nhanh, không mất dữ liệu và không bị quy lỗi oan | Mất mạng, tay bận, không thể gõ dài | Tag một chạm, ảnh + timestamp local, banner offline, tự đồng bộ và trạng thái rõ |
| P04 | Nhân sự vận hành tại bàn CSKH | Phân loại và giải quyết tranh chấp công bằng | Dữ liệu nằm rải rác, giao dịch treo, thiếu bằng chứng | Ticket gắn GPS/timeline/ảnh, lịch sử đối soát, quyền truy cập và lý do quyết định |

### 2.4. Bản đồ 6 Phase và 6 Quality Gate

| Phase | Câu hỏi chính | Đầu ra cần có | Gate/điều kiện | Trạng thái phiên kiểm tra |
| :--- | :--- | :--- | :--- | :--- |
| **P0 — Ideas / Discovery** | Đang giải quyết vấn đề gì, cho ai, trong bối cảnh nào và vì sao đáng giải quyết? | Idea backlog, Problem Statement, Stakeholder Map, Assumption/Risk Log, MVP Scope | G0: 6 điều kiện; 3 mục Critical phải có minh chứng | **Needs revision**, `3/6`; `0/6` gate approved |
| **P1 — Research** | Người dùng thực sự làm gì, đau ở đâu và bằng chứng nào xác nhận? | Research plan, interview/observation notes ẩn danh, insight và evidence matrix | G1: evidence đủ tin cậy, không biến giả định thành fact | Chưa mở gate |
| **P2 — UX Design** | Người dùng hoàn thành tác vụ ra sao trước khi có màu/style? | Persona, JTBD, prioritized needs, IA, user flows, low-fi/wireframe | G2: Persona rubric và flow có scenario/nhánh lỗi | Chưa mở gate |
| **P3 — UI Concept** | Ứng dụng sẽ trông như thế nào và quy tắc nào giữ nhất quán? | Style guide, tokens, concept alternatives, AI generation/critique/refine log | G3: concept và quyết định UI có lý do, có accessibility baseline | Chưa mở gate |
| **P4 — UI Design** | Các màn hình ưu tiên đã đầy đủ state, responsive và nhất quán chưa? | Hi-fi screens, components, prototype, loading/empty/error/offline states | G4: review UI Checklist và prototype không dead-end | Chưa mở gate |
| **P5 — Validate/Handoff** | Người dùng có hoàn thành được việc và developer có triển khai đúng không? | Usability test, issue/retest, screen spec, Flutter handoff, mapping tables | G5: test evidence, bug resolution và handoff đủ thông số | Chưa mở gate |

**Quy tắc duyệt chung:** đạt tối thiểu 80% checklist, không fail Critical, có link evidence và tên reviewer; gate trước phải được Approved. Ngưỡng 80% là rubric nội bộ của môn học, không phải chứng nhận quốc tế.

### 2.5. Chuỗi truy vết cần đánh dấu

```text
Evidence ID
  → Insight / Pattern
  → Persona / JTBD / Need
  → User Story / Scenario
  → User Flow
  → Screen / Component
  → Test Case / Metric
  → Issue / Decision / Handoff
```

| Chuỗi cần có | Tình trạng hiện tại |
| :--- | :--- |
| Evidence → Persona | Có mã evidence và 4 Persona; cần xác minh nguồn thực tế của từng evidence |
| Persona → Need → UI | Có ma trận trong Persona MD |
| Need → Flow → Screen | Có 3 flow trong [user-flow.md](../ux/user-flow.md) và sitemap/mapping trong [sitemap.md](../ux/sitemap.md); prototype link vẫn cần kiểm |
| Screen → Test Case | Có metric mục tiêu; chưa có bảng test case và kết quả từng người |
| UI → Handoff | Có bản nháp trong [flutter-handoff.md](../flutter-handoff.md); chưa gắn đủ frame Figma |

## 3. Những gì tài liệu hiện tại đã có

- Problem statement và phạm vi dịch vụ chăm sóc phi y tế.
- Stakeholder/User Map và Persona Coverage Matrix.
- Affinity Board và assumption backlog cho 4 Persona.
- 4 Persona với 12 trường cốt lõi.
- Candidate evidence register `[EV-01]` đến `[EV-04]`, được giữ fail-closed ở `Assumed/Inferred` cho tới khi có research artefact gốc.
- Happy path đặt lịch và edge case mất kết nối mạng.
- Ma trận `Persona → User Need → UI Decision → Test Metric`.
- Tự kiểm accessibility, usability và bộ câu hỏi phản biện.
- Phần đối chiếu trạng thái đã được bổ sung trong file Persona MD.
- [Sitemap và mapping 12 màn hình ứng viên](../ux/sitemap.md).
- [Responsive/accessibility evidence matrix](PRM393_RESPONSIVE_ACCESSIBILITY_EVIDENCE.md).
- [Ma trận evidence P0/G0](PRM393_P0_G0_EVIDENCE_MATRIX.md).

## 4. Những artefact cần có ngoài slide

Theo [hướng dẫn Lab 2](https://prm393-material.web.app/lab2-presentation.html), hồ sơ cần tiếp tục đối chiếu các mục sau:

| Artefact | Yêu cầu | Hiện trạng rà soát |
| :--- | :--- | :--- |
| GitHub repository | Repository bài nộp theo quy ước của lớp | Repo `ThwnThwn/LAB2_PRM` chỉ là nguồn tham khảo do người dùng cung cấp; chưa được coi là repository bài nộp CareSitter trong lần rà soát này |
| Figma | Link xem được, có quyền truy cập | Đã gắn link khai báo ở đầu hồ sơ; reviewer vẫn cần mở, xác nhận quyền xem, số page, frame và prototype. Việc Stitch từng không export được không phủ định link, nhưng link một mình chưa chứng minh nội dung |
| Information Architecture | Sitemap và tối thiểu 8 màn hình | Đã tạo [sitemap.md](../ux/sitemap.md); Figma Final UI chưa được xác nhận |
| Three User Flows | 3 flow, có alternate path và ít nhất 1 lỗi/phục hồi | Đã có trong [user-flow.md](../ux/user-flow.md); prototype chạy liền mạch chưa xác minh |
| AI Design Log | Prompt nguyên văn, output, tối thiểu 3 vòng before/after | Đã có [ai-design-log.md](../ai/ai-design-log.md) và artefact local; còn thiếu đủ 3 cặp ảnh before/after cùng frame |
| AI Critique | Tối thiểu 5 vấn đề UX gắn màn hình cụ thể | Đã có 6 vấn đề trong AI log; cần gắn ảnh/frame cuối |
| Design Decisions | 3–5 quyết định Accept / Modify / Reject có lý do | Đã có 6 quyết định trong [design-decisions.md](../design-decisions.md); cần gắn screenshot/frame |
| Wireframe → Final UI | Đối chiếu hierarchy, consistency, empty/loading/error | Có mô tả một phần; cần bằng chứng Figma |
| Design System | Token màu/chữ/spacing/radius/elevation và component states | Đã chốt tạm token theo Stitch hiện tại trong [design-decisions.md](../design-decisions.md); Figma Variables chưa xác nhận |
| Accessibility/Responsive | Contrast, 48×48 dp, chữ ≥14 sp, kiểm tra 360/412 dp | Đã tạo [evidence matrix](PRM393_RESPONSIVE_ACCESSIBILITY_EVIDENCE.md) và tìm thấy snapshot 390 dp; vẫn thiếu đo 360/412 dp |
| Live Prototype | Demo 3 flow, Back, overlay/dialog, loading → result, không dead-end | Có sơ đồ và yêu cầu; chưa xác nhận chạy trực tiếp |
| Flutter Handoff | 6 mục mỗi màn hình và 2 bảng mapping token/component | Đã có bản nháp [flutter-handoff.md](../flutter-handoff.md); cần gắn frame và hoàn thiện từng màn |
| README/assets | README chỉ rõ artefact, link và assets không bị chặn | Chưa có bằng chứng trong lần rà soát này |

## 5. Các điểm cần tránh kết luận quá mức

1. Persona MD không còn dùng `100/100` làm kết luận; trạng thái hiện tại là **phủ cấu trúc 10/10 mục, 3 mục partial, Gate G2 chưa Approved**.
2. Các số liệu `100%`, `2 phút 45 giây`, `12 giây`, `SUS 88.5` đang được ghi là **usability testing giả lập** cho đến khi có evidence thực tế.
3. Các kết quả accessibility trong MD là **tự kiểm tra theo thiết kế**, chưa phải WCAG audit đầy đủ.
4. Dữ liệu tên, địa chỉ, số điện thoại, lịch hẹn và thông tin sức khỏe trong Stitch được coi là **dữ liệu mẫu prototype**, không phải bằng chứng nghiên cứu người dùng thật.
5. Design system đã **chốt tạm theo Stitch hiện tại** cho hồ sơ review:
   - Nguồn chuẩn tạm thời: `Serene Companion`, `#006B5B`, `#D88C6C`, `#D3E8E1`, `#F5F3EE`, `Be Vietnam Pro`.
   - Token cũ trong MD (`Warm Companion`, `#496534`, `#F8F9EF`, `Inter`) được giữ để truy vết lịch sử, chưa được coi là token triển khai mới.
6. Source Flutter hiện dùng `#006B5B`, `#00C896` và `Inter`, khác với bộ `#0D6E57`, `#00B4A0`, `Be Vietnam Pro` khai báo ở đầu Persona MD; cần chốt một nguồn chuẩn và version trước khi nói đã đồng bộ.
7. Repository tham khảo ghi 19 slide (12 slide chính + 7 phụ lục), trong khi hồ sơ local gọi “Canva 12 Slides”; phải xác nhận artefact nộp cuối rồi dùng một cách gọi thống nhất.

## 6. Việc tiếp theo — chỉ tài liệu/review

- [~] Xác nhận reviewer, link evidence và trạng thái P0/G0 trên Quality Gates; đã chuẩn bị [ma trận P0/G0](PRM393_P0_G0_EVIDENCE_MATRIX.md), còn thiếu reviewer.
- [x] Bổ sung sitemap và mapping tối thiểu 8 màn hình trong [sitemap.md](../ux/sitemap.md); còn cần xác nhận Figma Final UI.
- [x] Bổ sung flow thứ 3, alternate path và error/recovery path trong [user-flow.md](../ux/user-flow.md); còn cần chạy prototype.
- [~] Tạo AI design log trong [ai-design-log.md](../ai/ai-design-log.md); còn thiếu đủ 3 cặp ảnh before/after đã xác minh.
- [x] Tạo bảng 6 vấn đề UX và 6 quyết định Accept/Modify/Reject trong [AI log](../ai/ai-design-log.md) và [design-decisions.md](../design-decisions.md); còn cần gắn frame/screenshot.
- [x] Chốt tạm design system theo Stitch hiện tại; cần reviewer/Figma xác nhận trước triển khai.
- [~] Bổ sung [evidence responsive 360/412 dp](PRM393_RESPONSIVE_ACCESSIBILITY_EVIDENCE.md) và [Flutter handoff](../flutter-handoff.md); đã có ma trận/bản nháp, còn thiếu số đo và frame.
- [ ] Chỉ đổi trạng thái sang `Approved` sau khi reviewer xác nhận, không dựa riêng vào self-review.

### Các đầu vào đã được ghi nhận (cần reviewer mở và xác minh nội dung):

- **Link Figma được khai báo:** [Figma LAB02_CareSystem](https://www.figma.com/design/Ph22SZvtVFwWzohuaia1UC/LAB02_CareSystem?node-id=0-1&t=y8TBlIsxnOdSbWSD-1); reviewer cần xác minh quyền xem, số page và nội dung.
- **Figma Make / Image Retrieval:** [Figma Make](https://www.figma.com/make/zYbuvraAFDQoVb6wEXhpnH/Mobile-app-image-retrieval?t=HrAK44qDKK2rzSvZ-1)
- **Canva Slide Presentation:** [Canva 12 Slides](https://canva.link/55qt0sv9dsz7w3g)
- **ChatGPT Chat Evidence:** [Cuộc trò chuyện minh chứng](https://chatgpt.com/s/cx_6ad371cf90308191ab53a511a2212c74)
- **Tài liệu Google Docs:** [Google Docs Tổng Hợp](https://docs.google.com/document/d/1fBMiqKdpAtMjy8XKDpX7-WQMsufw5_SPwp1s8oMFH_8/edit?usp=sharing)

## 7. Kết luận

CareSitter hiện **đủ để trình bày bản nháp/Proto-Persona**: có tài liệu Persona & UX, link Stitch/Figma/Canva và ma trận truy vết thiết kế. Hồ sơ **chưa đủ để tuyên bố Persona đã validation hoặc Gate G2 đã Approved** cho tới khi có Evidence Registry trỏ tới note/transcript/observation thật, Affinity Board có provenance, reviewer xác minh artefact thiết kế và các token/số slide được đồng bộ.
