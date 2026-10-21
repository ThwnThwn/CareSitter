# Ma trận minh chứng P0/G0 — CareSitter

**Ngày rà soát:** 17/10/2026 · **Cập nhật:** 21/10/2026  
**Quality Gates:** [PRM393 Quality Gates](https://prm393-material.web.app/quality-gates.html)  
**Evidence tổng:** [Hồ sơ minh chứng rà soát](PRM393_MINH_CHUNG_RASOAT_HO_SO.md)  
**Link cuộc trò chuyện:** [Mở minh chứng trao đổi](https://chatgpt.com/s/cx_6ad371cf90308191ab53a511a2212c74)

> P0/G0 hiện chưa được đánh dấu Approved. Bảng dưới đây chuẩn bị evidence để reviewer kiểm tra; không tự thay thế tên reviewer hoặc quyết định duyệt.

| # | Điều kiện G0 | Evidence hiện có | Trạng thái | Việc còn thiếu |
| :---: | :--- | :--- | :---: | :--- |
| 1 | Problem statement xác định ai – vấn đề – bối cảnh – tác động | [Persona MD](PRM393_PERSONA_VA_THIET_KE_CARESITTER.md), mục `1.1` | [x] Đã đánh dấu trên Quality Gates | Reviewer xác nhận câu chữ và nguồn |
| 2 | Phân biệt fact, hypothesis và opinion | Assumption backlog; `[EV-01..04]` đã hạ về candidate `Assumed/Inferred` trong Persona MD | [~] Có khung fail-closed | Tạo Evidence Registry và chỉ nâng nhãn khi có source artefact/span thực tế; không dùng số liệu giả lập làm fact |
| 3 | Có tối thiểu 2 ý tưởng được cân nhắc | Brainstorming/Affinity Board trong Persona MD | [~] Có mô tả | Bổ sung bảng phương án và lý do chọn MVP |
| 4 | Có user target và stakeholder sơ bộ | Stakeholder/User Map và 4 Persona | [x] Đã đánh dấu trên Quality Gates | Reviewer xác nhận phạm vi |
| 5 | Có MVP, giới hạn, rủi ro và metric sơ bộ | Product Scope, assumption backlog, Persona → UI → Test | [x] Đã đánh dấu trên Quality Gates | Bổ sung Impact × Feasibility nếu reviewer yêu cầu |
| 6 | Có kế hoạch kiểm chứng assumption lớn ở P1 | Assumption backlog và các mục usability/evidence cần bổ sung | [~] Có khung | Thêm research plan, người tham gia, task và lịch kiểm chứng |

## Trạng thái gate

- Trạng thái hiện tại: **P0 — Needs revision**.
- Sau khi ghi evidence và đánh dấu các artefact đã có: `3/6` điều kiện P0, `0/6` gate approved. Tổng tiến độ Quality Gates hiển thị `3/36` điều kiện.
- Reviewer: **chưa xác nhận**.
- Link evidence đã chuẩn bị: file này, hồ sơ tổng hợp, Persona MD, sitemap, user flows và design log.

### Ghi nhận kiểm tra Figma — 17/10/2026 (lịch sử)

- Đã mở [Stitch CareSitter](https://stitch.withgoogle.com/projects/16914427060621528532) và kiểm tra `Export`.
- Stitch hiển thị giới hạn tối đa 16 màn hình; sau khi giảm lựa chọn xuống 15–16 màn hình, radio `Figma` vẫn ở trạng thái disabled.
- Kết luận tại thời điểm kiểm tra: chưa export được Figma từ Stitch. Từ lần cập nhật 21/10, hồ sơ đã khai báo một link Figma riêng; reviewer vẫn phải mở và xác minh quyền xem/nội dung, nên chưa đánh dấu mục Figma hoàn tất chỉ dựa vào link.
- Tham chiếu hỗ trợ: [Google AI Developers Forum — Exporting Stitch to Figma](https://discuss.ai.google.dev/t/exporting-stitch-to-figma/104903) ghi nhận Figma export chỉ hỗ trợ ở Standard mode; dự án hiện tại chưa chứng minh được đang ở mode đó.
- Không đánh dấu `Approved` cho đến khi reviewer kiểm tra evidence và ghi feedback/action items.
