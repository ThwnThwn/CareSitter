# Evidence responsive và accessibility — CareSitter

**Ngày lập:** 17/10/2026  
**Nguồn UI hiện tại:** [Stitch Project 16914427060621528532](https://stitch.withgoogle.com/projects/16914427060621528532)  
**Rubric:** [UI Checklist PRM393](https://prm393-material.web.app/ui-checklist.html)

> File này chuẩn bị bảng kiểm và vị trí evidence. Chưa đánh dấu đạt nếu chưa có screenshot/đo trực tiếp trên frame Figma hoặc thiết bị.

## 1. Chuẩn cần kiểm

| Hạng mục | Ngưỡng | Cách lấy evidence |
| :--- | :--- | :--- |
| Contrast chữ thường | ≥4.5:1 | Screenshot frame + công cụ đo contrast, ghi cặp màu |
| Contrast chữ lớn/điều khiển | ≥3:1 | Screenshot frame + công cụ đo contrast |
| Touch target | ≥48×48 dp | Đo nút/checkbox/radio trong Figma hoặc thiết bị |
| Body text | ≥14 sp | Ghi token/text style và kiểm frame |
| Responsive | 360 dp và 412 dp | Hai screenshot cùng màn, ghi overflow/line wrap |
| Không phụ thuộc màu | Trạng thái có icon/label | Screenshot error/success/offline/selected |
| Interaction states | loading, empty, success, error, offline | Link frame hoặc prototype cho từng state |

## 2. Ma trận màn hình cần kiểm ở 360/412 dp

| Màn | 360 dp | 412 dp | Touch | Contrast | State | Evidence |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| `C-HOME` | [ ] | [ ] | [ ] | [ ] | [ ] | Chưa có screenshot Figma |
| `C-BOOK-01` | [ ] | [ ] | [ ] | [ ] | [ ] | Chưa có screenshot Figma |
| `C-BOOK-03` | [ ] | [ ] | [ ] | [ ] | [ ] | Chưa có screenshot Figma |
| `C-BOOK-04` | [ ] | [ ] | [ ] | [ ] | [ ] | Chưa có screenshot Figma |
| `C-BOOK-06` | [ ] | [ ] | [ ] | [ ] | [ ] | Chưa có screenshot Figma |
| `C-PAY-RESULT` | [ ] | [ ] | [ ] | [ ] | [ ] | Chưa có screenshot Figma |
| `C-TRACKING` | [ ] | [ ] | [ ] | [ ] | [ ] | Chưa có screenshot Figma |
| `C-NUT-07` | [ ] | [ ] | [ ] | [ ] | [ ] | Chưa có screenshot Figma |

## 3. Kết quả rà soát hiện tại

- Design system tham chiếu tạm thời theo Stitch hiện tại: `#006B5B`, `#D88C6C`, `#D3E8E1`, `#F5F3EE`, `Be Vietnam Pro`.
- Các con số contrast `11.4:1` và `6.8:1` trong Persona MD là tự khai báo theo token cũ; cần đo lại sau khi chốt token hiện tại.
- Chưa có bằng chứng đủ để đánh dấu các cột 360/412, touch, contrast và state là đạt.
- Đây là phần cần người có Figma/device hoặc reviewer xác nhận; không thể suy ra chỉ từ ảnh canvas Stitch thu nhỏ.

## 4. Artefact local có thể làm evidence một phần

| Artefact | Quan sát | Mức dùng được |
| :--- | :--- | :---: |
| `D:\EXE\.codex-output\stitch-20261014\mobile-fit-first-pass.jpg` | Có ghi nhận viewport mobile khoảng 390 px và phát hiện frame desktop bọc điện thoại | [~] Bằng chứng phát hiện lỗi; chưa phải kiểm 360/412 |
| `D:\EXE\.codex-output\stitch-20261014\palette-qa.json` | Có background/button của các màn Nutrition và cờ `hasInventedDose` | [~] Bằng chứng token/state; chưa phải contrast audit |
| `D:\EXE\.codex-output\stitch-20261014\nutrition-landing-theme.jpg` | Có snapshot theme và các màn Nutrition | [~] Chưa có số đo kích thước |

Để đánh dấu hoàn tất cần thêm screenshot hoặc export cùng một màn ở đúng 360 dp và 412 dp, kèm kết quả đo không overflow, touch target và contrast.
