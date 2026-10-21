# Đối chiếu hồ sơ PRM393 CareSitter với Persona Guideline

> **Ngày đối chiếu:** 21/10/2026 (Asia/Saigon)  
> **Phạm vi:** `plan/prm/`, Persona Guideline v1.0 và repository `ThwnThwn/LAB2_PRM`  
> **Trạng thái:** rà soát tài liệu local; chưa phải phê duyệt của giảng viên/reviewer  
> **Nguyên tắc:** phân biệt “có artefact” với “artefact đã được kiểm chứng”.

## 1. Nguồn và mốc đối chiếu

1. [PRM393 Persona Guideline v1.0](https://prm393-material.web.app/persona-guideline.html) là nguồn yêu cầu chính cho Persona, workshop, research evidence, rubric và deliverables.
2. Repository [ThwnThwn/LAB2_PRM](https://github.com/ThwnThwn/LAB2_PRM/tree/ed54edd4c61b020c4811e5ae3eebc44291276d6d) được kiểm tra tại commit `ed54edd4c61b020c4811e5ae3eebc44291276d6d`, ngày 21/10/2026. Đây là bộ artefact tham khảo/đối chiếu, **không phải nguồn độc lập xác nhận nghiên cứu người dùng**.
3. Hồ sơ local được kiểm tra:
   - [PRM393_PERSONA_VA_THIET_KE_CARESITTER.md](PRM393_PERSONA_VA_THIET_KE_CARESITTER.md)
   - [PRM393_MINH_CHUNG_RASOAT_HO_SO.md](PRM393_MINH_CHUNG_RASOAT_HO_SO.md)
   - [PRM393_P0_G0_EVIDENCE_MATRIX.md](PRM393_P0_G0_EVIDENCE_MATRIX.md)
   - [PRM393_RESPONSIVE_ACCESSIBILITY_EVIDENCE.md](PRM393_RESPONSIVE_ACCESSIBILITY_EVIDENCE.md)

## 2. Kết luận ngắn

Hồ sơ CareSitter **đạt tốt về cấu trúc Persona**: có scope, Stakeholder Map, bốn Persona khác biệt, 12 trường cốt lõi, JTBD, scenario, success criteria và ma trận `Persona → Need → UI decision → Test`. Các phần này bám sát [12 trường bắt buộc](https://prm393-material.web.app/persona-guideline.html#fields) và [rubric 10 tiêu chí](https://prm393-material.web.app/persona-guideline.html#checklist).

Hồ sơ **chưa đủ cơ sở để kết luận “đã đối chiếu toàn diện”, “liên kết đầy đủ bằng chứng nghiên cứu” hoặc “đạt 100/100”**. Điểm nghẽn nằm ở research evidence và Affinity Board:

- Có bảng `[EV-01]`–`[EV-04]`, nhưng không tìm thấy research plan, ngày/phương pháp thu thập, transcript/observation note ẩn danh, consent status hoặc đường dẫn artefact gốc để kiểm tra.
- Affinity Board hiện là bản tổng hợp chữ; từng note chưa có source ID nên chưa chứng minh được quá trình từ dữ liệu → pattern → segment.
- Repository tham khảo cũng chỉ chứa các báo cáo tổng hợp và ảnh slide; không có research artefact gốc. Việc repo lặp lại một claim không biến claim đó thành bằng chứng độc lập.

Theo quy tắc của guideline, điểm tự chấm cao không thay thế evidence hoặc usability testing. Vì vậy, trạng thái phù hợp hiện tại là **“đạt cấu trúc Proto-Persona; validation evidence còn bị chặn”**. Guideline cũng nói rõ AI-generated Persona không tự động trở thành persona đã xác thực tại phần [Nguyên tắc](https://prm393-material.web.app/persona-guideline.html#principles).

## 3. Ma trận đối chiếu rubric Persona 100 điểm

| # | Tiêu chí từ guideline | Minh chứng local | Đánh giá | Việc cần bổ sung |
| ---: | --- | --- | --- | --- |
| 1 | Xác định scope, tác vụ trọng tâm, nhóm người dùng | Persona MD §1.1 có Problem Statement, In-Scope và Out-of-Scope | **Đạt về cấu trúc** | Gắn nguồn cho các phát biểu bối cảnh/xu hướng; tách fact khỏi giả định |
| 2 | Có User/Stakeholder Map và nhóm dễ bị bỏ sót | Persona MD §1.2 có bốn nhóm và ghi nhận người cao tuổi có rào cản thị lực/nhận thức | **Đạt về cấu trúc** | Nêu tiêu chí chọn/bỏ stakeholder và source ID hỗ trợ |
| 3 | Số Persona phù hợp phạm vi | Có 1 Primary, 2 Secondary, 1 Supporting | **Đạt** | Giữ giải thích “khác nhau vì hành vi/goal/context”, không dùng số lượng như bằng chứng chất lượng |
| 4 | Persona khác biệt bằng goals, behaviors, contexts hoặc constraints | Coverage Matrix §1.4 phân biệt gia đình, người cao tuổi, caregiver và vận hành | **Đạt về cấu trúc** | Dẫn source ID cho từng khác biệt trước khi gọi là qualitative finding |
| 5 | Mỗi Persona có đủ 12 trường lõi; Lab 2 có tuổi, vai trò, thiết bị, accessibility | Persona MD §2.2 có đủ các trường cho bốn Persona | **Đạt về nội dung** | Thêm ngày/revision và Evidence Status nhất quán cho từng Persona |
| 6 | Nhu cầu là outcome, không phải tính năng trá hình | Goals và JTBD chủ yếu mô tả sự an tâm, liên tục công việc, quyền tự chủ, xử lý công bằng | **Đạt, cần rà câu chữ** | Chuyển các câu gắn sẵn tên màn hình/tính năng sang phần UI hypothesis |
| 7 | Có research evidence hoặc ghi rõ assumption | Có ID và quote trong §2.1, nhưng thiếu artefact gốc và metadata; `[CS-INT-*]`/`[CS-OPS-*]` không trỏ tới file kiểm chứng | **Chưa chứng minh** | Tạo Evidence Registry, research plan, note ẩn danh và mapping claim → source span; nếu không có, hạ nhãn về `Assumed` |
| 8 | Có Affinity Board/tổng hợp pattern chứng minh cách hình thành segment | Persona MD §1.3 có bốn cluster, nhưng từng note không có source ID và không có ảnh/bản xuất board | **Đạt một phần** | Gắn source ID cho từng note, lưu snapshot board và decision log gộp/tách segment |
| 9 | Primary Persona có scenario và success criteria | P01 có scenario, task flow và các metric mục tiêu | **Đạt về thiết kế** | Ghi rõ metric là target cho test, không phải kết quả đã đo |
| 10 | Có UI hypothesis và phương pháp kiểm chứng liên kết Persona | Persona MD §2.4 có ma trận Need → UI → Test Metric | **Đạt về cấu trúc** | Thêm test owner, trạng thái `Not run/Run`, ngày và evidence kết quả |

**Tóm tắt rubric:** 8 tiêu chí có artefact cấu trúc tương ứng; tiêu chí 7 chưa kiểm chứng và tiêu chí 8 mới đạt một phần. Không nên chuyển kết quả này thành tuyên bố reviewer đã chấm 80/90/100 điểm. Rubric trên website là self-review và chính guideline yêu cầu evidence/assumption matrix trước khi duyệt UI tại phần [Checklist](https://prm393-material.web.app/persona-guideline.html#checklist).

## 4. Đối chiếu deliverables bắt buộc

Guideline tách hồ sơ thành [Milestone A và Milestone B](https://prm393-material.web.app/persona-guideline.html#deliverables).

### 4.1. Milestone A — Discovery

| Deliverable | Local hiện có | Trạng thái |
| --- | --- | --- |
| Problem Statement & Scope | Persona MD §1.1 | Có |
| Stakeholder/User Map | Persona MD §1.2 | Có |
| Ảnh/chụp Brainstorming và Affinity Map | Chỉ có sơ đồ chữ tổng hợp §1.3 | **Thiếu artefact gốc/snapshot** |
| Persona Coverage Matrix | Persona MD §1.4 | Có |
| Bộ Proto-Persona có nhãn trạng thái | §1.5 có Assumption Backlog; sau đối chứng, §2.1–2.2 đã hạ các evidence chưa có nguồn về `Assumed/Inferred` | **Đã sửa nhãn; còn chờ evidence thật** |

### 4.2. Milestone B — Validation & Design

| Deliverable | Local hiện có | Trạng thái |
| --- | --- | --- |
| Research plan + interview/observation notes ẩn danh | Chưa tìm thấy file/đường dẫn artefact | **Thiếu** |
| Persona cập nhật có evidence IDs | Có ID, chưa có target artefact/source span | **Đạt một phần** |
| Scenario/Journey hoặc task flow của Primary Persona | Persona MD §2.3 | Có |
| Persona → Need → UI decision → Test | Persona MD §2.4 | Có |
| Checklist và kết quả test | Có self-review; usability figures được ghi đúng là giả lập | **Có self-review, chưa có test thực địa** |

## 5. Đối chiếu với repository `LAB2_PRM`

Tại commit đã kiểm tra, repository có `README.md`, `PERSONA_GUIDELINE_REPORT.md`, `BANG_DOI_CHIEU_TIEU_CHI.md`, `DANH_GIA_LAB2_PRM323.md`, `FLUTTER_HANDOFF_SPEC.md`, `AI_UI_CHAT_EVIDENCE.md` và 12 ảnh preview slide. Xem [cây file tại commit](https://github.com/ThwnThwn/LAB2_PRM/tree/ed54edd4c61b020c4811e5ae3eebc44291276d6d).

### 5.1. Nội dung có thể học và đồng bộ

- Cấu trúc báo cáo rõ: Discovery → Persona → UI decision → handoff.
- Bảng 10 tiêu chí dễ theo dõi và có đường dẫn sang artefact liên quan tại [BANG_DOI_CHIEU_TIEU_CHI.md](https://github.com/ThwnThwn/LAB2_PRM/blob/ed54edd4c61b020c4811e5ae3eebc44291276d6d/BANG_DOI_CHIEU_TIEU_CHI.md).
- `FLUTTER_HANDOFF_SPEC.md` dùng mẫu 6 mục/màn hình, hữu ích để nối thiết kế với implementation tại [bản commit đã kiểm tra](https://github.com/ThwnThwn/LAB2_PRM/blob/ed54edd4c61b020c4811e5ae3eebc44291276d6d/FLUTTER_HANDOFF_SPEC.md).

### 5.2. Nội dung không nên sao chép như fact

- Repo tự tuyên bố `100/100` cho Persona và `99/100` cho Lab 2 trong [README](https://github.com/ThwnThwn/LAB2_PRM/blob/ed54edd4c61b020c4811e5ae3eebc44291276d6d/README.md#L27-L31), nhưng đây là tự đánh giá, không có reviewer approval kèm theo.
- Repo gọi `[EV-01..04]` là phỏng vấn thực tế trong [bảng tiêu chí](https://github.com/ThwnThwn/LAB2_PRM/blob/ed54edd4c61b020c4811e5ae3eebc44291276d6d/BANG_DOI_CHIEU_TIEU_CHI.md#L38), nhưng cây file không có raw/anonymized research notes để kiểm tra nguồn.
- Repo và local chia sẻ cùng Persona, quote, evidence ID và kết luận; vì vậy repo là bản sao/artefact song hành, không phải corroboration độc lập.

## 6. Các mâu thuẫn phải sửa trước khi nộp

### 6.1. Trạng thái evidence và Gate

- Trước lần sửa 21/10, Persona MD §0 ghi “liên kết đầy đủ bằng chứng nghiên cứu” và “đáp ứng trọn vẹn 10 tiêu chí”; hai claim này đã được thay bằng trạng thái proto-persona/provisional.
- Hồ sơ rà soát §2.2 lại đánh dấu Research Evidence `[~]`, G1 chưa mở và Gate chưa approved.

**Cách sửa:** thay tuyên bố tuyệt đối bằng: “Hồ sơ đạt cấu trúc self-review; research evidence còn chờ đối chiếu artefact gốc và reviewer approval.”

### 6.2. Nhãn `[EV-04]`

`[EV-04]` xuất hiện dưới dạng một verbatim quote của người quản lý dịch vụ, nhưng Persona P04 lại ghi `Inferred`. Hai trạng thái không thể đồng thời đúng:

- nếu có phỏng vấn/note gốc: ghi `Reported`, kèm ngày, phương pháp và source span;
- nếu chỉ suy luận từ quy trình: bỏ quote giả lập, ghi `Inferred/Assumed` và nêu căn cứ suy luận.

### 6.3. Nhãn `Observed` của `[EV-03]`

Một quote phỏng vấn chỉ chứng minh `Reported`. Muốn ghi `Observed` phải có observation note nêu bối cảnh, hành vi nhìn thấy, ngày và người ghi nhận. Nếu chưa có, hạ nhãn `[EV-03]` xuống `Reported`.

### 6.4. Design System không khớp source hiện tại

Persona MD §0 ghi `#0D6E57`, `#00B4A0` và `Be Vietnam Pro`, nhưng source Flutter hiện dùng:

- `primary = #006B5B`, `accent = #00C896` trong `frontend/customer-app/lib/core/theme/app_colors.dart`;
- `fontFamily: 'Inter'` trong `frontend/customer-app/lib/core/theme/app_theme.dart` và bundle Inter trong `pubspec.yaml`.

Chính Persona MD §2.5 cũng ghi font Inter, tạo mâu thuẫn nội bộ. Cần chọn source hiện hành làm chuẩn rồi cập nhật Figma/Canva/tài liệu, hoặc ghi rõ snapshot/version nếu tài liệu mô tả thiết kế cũ.

### 6.5. Số slide không thống nhất

Persona MD §0 ghi Canva 12 slide, trong khi repository tại commit hiện tại ghi 19 slide và giải thích 12 slide chính + 7 slide phụ lục trong [README](https://github.com/ThwnThwn/LAB2_PRM/blob/ed54edd4c61b020c4811e5ae3eebc44291276d6d/README.md#L37-L60). Cần chốt một con số theo artefact Canva đang nộp.

### 6.6. Accessibility chưa có measurement evidence hoàn chỉnh

Persona MD có các tỷ lệ `11.4:1`, `6.8:1` và tuyên bố tương thích đầy đủ, nhưng `PRM393_RESPONSIVE_ACCESSIBILITY_EVIDENCE.md` ghi rõ token cũ và cần đo lại, đồng thời còn thiếu snapshot 360/412 dp. Do đó chỉ nên ghi “mục tiêu/tự kiểm tra”, chưa ghi “đạt WCAG audit”.

## 7. Phần cần bổ sung vào hồ sơ

### 7.1. Evidence Registry tối thiểu

Thêm một bảng riêng, không chứa PII thừa:

| Evidence ID | Method | Ngày | Participant pseudonym/segment | Context | Artefact local | Consent/anonymization | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EV-01 | Interview | `YYYY-MM-DD` | Payer/customer | Remote/in-person | `research/EV-01-notes.md#...` | Confirmed/Pending | Reported |
| EV-02 | Interview | `YYYY-MM-DD` | Older beneficiary | ... | ... | ... | Reported |
| EV-03 | Interview/Observation | `YYYY-MM-DD` | Caregiver | ... | ... | ... | Reported hoặc Observed |
| EV-04 | Interview hoặc desk research | `YYYY-MM-DD` | Operations | ... | ... | ... | Reported/Inferred |

Nếu không có artefact thật, không tạo file giả để lấp chỗ trống; chuyển Evidence Status thành `Assumed` và đưa vào Research Backlog.

### 7.2. Evidence → Claim matrix

| Claim ID | Persona/field | Claim | Evidence ID + source span | Nature | Confidence | Open question |
| --- | --- | --- | --- | --- | --- | --- |
| CL-01 | P01/Pain | ... | EV-01 §... | Reported | Medium | ... |

Mỗi quote, pain point, behavior và constraint quan trọng phải quay về một source span hoặc được gắn `Assumed`.

### 7.3. Affinity Board có provenance

- Mỗi sticky note có `EV-xx` hoặc `ASSUMPTION-xx`.
- Có snapshot/export của board.
- Có decision log giải thích vì sao gộp/tách cluster thành P01–P04.
- Không đổi màu/nhãn thành “evidence” nếu note chỉ do AI/nhóm tạo.

### 7.4. Research plan

Tối thiểu gồm: research questions, participant criteria, recruitment, method, interview/observation guide, consent/anonymization, lịch thực hiện, owner và điều kiện dừng/bão hòa. Mốc 6–12 người trong guideline chỉ là đề xuất tổ chức lớp học, không phải bằng chứng đại diện thống kê; xem phần [Từ Proto-Persona đến Persona có căn cứ](https://prm393-material.web.app/persona-guideline.html#evidence).

### 7.5. Test result registry

Tách rõ:

- `Target`: ngưỡng muốn đạt;
- `Not run`: chưa thử;
- `Observed result`: số đo thật kèm participant/task/evidence;
- `Decision`: giữ/sửa/bỏ UI hypothesis.

Không chuyển các số liệu usability giả lập ở Persona MD §2.6 thành kết quả thực tế.

## 8. Câu chữ đề xuất thay ngay

### Thay phần kết luận ở đầu Persona MD

> Hồ sơ đã được đối chiếu về cấu trúc với Persona Guideline v1.0. Hiện có đầy đủ khung scope, stakeholder map, bốn Proto-Persona, 12 trường cốt lõi, scenario và ma trận UI hypothesis. Research evidence `[EV-01..04]`, Affinity provenance, accessibility measurement và reviewer approval vẫn cần artefact gốc trước khi kết luận Persona đã được validated hoặc Gate G2 đã đạt.

### Thay nhãn điểm

> **Self-review:** có artefact cho 8/10 tiêu chí; tiêu chí evidence chưa kiểm chứng và Affinity provenance mới đạt một phần. Không phải điểm chính thức hoặc Gate approval.

### Thay cách trình bày Persona

Đã đổi `Qualitative Finding` thành `Proto-persona hypothesis (Assumed/Inferred)` ở P01–P04. Chỉ nâng từng field lên `Observed` hoặc `Reported` sau khi field đó trỏ được về artefact nguồn.

## 9. Checklist trước khi nộp

- [ ] Mọi Persona đủ 12 trường và các trường Lab 2 bắt buộc.
- [ ] Mọi claim quan trọng có source span hoặc nhãn `Assumed`.
- [ ] `Observed` có observation note; `Reported` có interview/note; `Inferred` có lý do suy luận.
- [ ] Affinity Board có snapshot và source IDs trên từng note.
- [ ] Primary Persona có scenario và success criteria ở trạng thái Target/Observed rõ ràng.
- [ ] Ma trận UI hypothesis ghi test owner, trạng thái và evidence kết quả.
- [ ] Token, font, số slide và số page thống nhất với artefact đang nộp.
- [ ] Các tỷ lệ contrast/responsive có phép đo hoặc được ghi là chưa kiểm chứng.
- [ ] `100/100`, `99/100`, “đạt chuẩn” chỉ ghi là self-review nếu chưa có reviewer.
- [ ] Không đưa transcript có PII hoặc dữ liệu sức khỏe nhận dạng được vào repository công khai.

## 10. Quyết định go/no-go tài liệu

- **Go để trình bày bản nháp/Proto-Persona:** Có.
- **Go để tuyên bố Persona đã được validation:** Chưa.
- **Go để tuyên bố Gate G2/reviewer approval:** Chưa.
- **Điều kiện mở:** hoàn thiện Evidence Registry + source artefacts, Affinity provenance, sửa nhãn evidence và đồng bộ Design System/slide count.

