# Nhật ký thiết kế AI CareSitter cho PRM323 Lab 2

Ngày đối chiếu lịch sử: 14/10/2026. **Rà soát hiện tại: 17/10/2026.** Project đang đối chiếu: [Stitch CareSitter](https://stitch.withgoogle.com/projects/16914427060621528532). Log này ghi phần quan sát được và chỗ thiếu bằng chứng; không xem mô tả tự sinh của Stitch là kết quả đã kiểm chứng. Project ID cũ `9685887642498274590` chỉ giữ để truy vết lịch sử, không dùng làm link nộp hiện tại.

| Vòng | Mục tiêu và prompt/nguồn | Kết quả quan sát | Phản biện và quyết định |
| --- | --- | --- | --- |
| 1 — cấu trúc | Prompt gốc và danh sách frame trong [STITCH_PROMPTS.md](../frontend/stitch/STITCH_PROMPTS.md) | Canvas có Customer, Caregiver, Nutrition và Flow Map; có bản trùng. | Nhóm theo flow/role. Không tính sheet, dialog và state của cùng màn thành màn final mới. |
| 2 — nhận diện | Yêu cầu người dùng: “xài màu giống landing page” | Một số frame Nutrition dùng teal Landing; ảnh kiểm tra local: `D:\EXE\.codex-output\stitch-20261014\nutrition-landing-theme.jpg`. | Cần kiểm từng frame, vì màn mới vẫn xuất hiện màu `#006a43`/nền `#e7fff1` khác token Landing `#006B5B`/`#F5F3EE`. |
| 3 — mobile | Yêu cầu người dùng: “UI fit y chang những phần cũ” | Ảnh vòng đầu local: `D:\EXE\.codex-output\stitch-20261014\mobile-fit-first-pass.jpg`. Có artboard Mobile thật, nhưng các frame khác vẫn bọc điện thoại trong artboard 1280 px. | Chỉ đưa frame 390 px đã kiểm kích thước vào nhóm final; làm lại/đối chiếu bản còn sai. |
| 4 — phạm vi | Yêu cầu bỏ nội dung y tế; sau đó người dùng xác nhận bệnh lý đã biết được liệt kê để tránh món ảnh hưởng. | Bản audit trước khi sửa lưu local: `D:\EXE\.codex-output\stitch-20261014\audit-before.json`; một số frame cũ đã được chỉnh. | Giữ dị ứng/bệnh lý gia đình khai/lưu ý món; bỏ lời hứa điều trị, thuốc, đo chỉ số và ngưỡng nước. Kiểm lại preview sau sửa. |

**Sáu vấn đề UX cụ thể cần chứng minh trong slide:** (1) frame Desktop bọc phone làm sai kích thước mobile; (2) màu và font giữa các frame lệch token Landing; (3) Flow Map cũ ghi thời lượng 2–5 giờ, source dùng 2–12 giờ; (4) Flow Map/preview cũ có hotline và cam kết 24/7 chưa xác thực; (5) Nutrition cũ có thuốc, khả năng nuốt, giới hạn nước và lời hứa kiểm soát bệnh; (6) payment result ở các biến thể có số tiền minh họa không nhất quán. Mỗi ảnh đem chấm phải gắn đúng frame, ngày và cặp trước/sau tương ứng.

**Tình trạng bằng chứng Lab 2:** Có dấu vết prompt và một số ảnh local, nhưng chưa đủ **ba cặp ảnh trước/sau đã xác minh**, chưa có AI critique theo từng frame với kết quả Figma, và chưa có log nguyên văn của mọi lần gửi Stitch. Không ghi các vòng này là hoàn tất rubric cho tới khi xuất đủ bằng chứng và đối chiếu bản lưu.

**Kiểm tra Figma ngày 17/10/2026:** Đã mở Export của Stitch project hiện tại và thử giảm lựa chọn xuống 15–16 màn hình; tùy chọn `Figma` vẫn bị disabled. Vì vậy chưa ghi nhận Figma link/export như một output đã hoàn tất. Nếu cần tiếp tục, dùng `Download Project`/`.zip` và chuyển qua công cụ import HTML sang Figma, hoặc tạo lại/tiếp tục trong Stitch Standard mode rồi export trực tiếp.

## Kho artefact local đã kiểm tra lại ngày 17/10/2026

| Artefact | Vai trò | Có thể dùng làm | Giới hạn |
| :--- | :--- | :--- | :--- |
| `D:\EXE\.codex-output\stitch-20261014\audit-before.json` | Snapshot text trước lượt audit | Evidence nội dung trước khi chỉnh | Không phải ảnh before/after và có nội dung prototype cũ cần lọc |
| `D:\EXE\.codex-output\stitch-20261014\palette-qa.json` | Kết quả kiểm màu/state Nutrition | Evidence token, background, button và `hasInventedDose` | Chưa thay thế đo contrast WCAG hoặc Figma proof |
| `D:\EXE\.codex-output\stitch-20261014\mobile-fit-first-pass.jpg` | Snapshot canvas mobile first pass | Evidence phát hiện viewport 390 px và frame desktop bọc phone | Chưa phải cặp before/after cùng một màn |
| `D:\EXE\.codex-output\stitch-20261014\nutrition-landing-theme.jpg` | Snapshot canvas Nutrition/theme | Evidence rà token và các state Nutrition | Chưa phải cặp before/after cùng một màn |
| `D:\EXE\.codex-output\stitch-20261014\prm323-lab2-flowmap.jpg` | Snapshot Flow Map | Evidence sitemap/flow map và vấn đề frame trùng | Không chứng minh prototype nối chạy |
| `D:\EXE\.codex-output\stitch-20261014\progress.jpg` | Snapshot tiến trình | Evidence lịch sử chỉnh sửa | Không đủ thông tin để xác định before/after của từng frame |

**Kết luận cập nhật:** đã có đủ artefact để lập danh sách vòng chỉnh sửa và vấn đề UX, nhưng chưa đủ bằng chứng để đánh dấu “3 vòng before/after hoàn tất”. Cần ảnh hoặc export của cùng một frame ở trạng thái trước và sau cho từng vòng.

**QA lượt 14/10 theo file Lab 2:** Stitch tạo thêm Flow Map tham chiếu Customer và báo đã sửa C-NUT-01/02/05/STATE-01. Đã xác nhận tài liệu mới có trên canvas, song Flow Map cũ còn ở đó và vẫn ghi 2–5 giờ/hotline/bảo hiểm. Bản mới tự thêm suy luận bệnh cụ thể → tránh gia vị/dầu mỡ; cần bỏ suy luận đó. Chưa quan sát đủ bốn preview Nutrition sau sửa hoặc đo được width của từng artboard, nên chưa đánh dấu hoàn tất vòng này.
