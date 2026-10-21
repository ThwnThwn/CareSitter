# Sổ nguồn P2 — Nutrition CareSitter

> Cập nhật: 16/10/2026. Phạm vi: nguồn dùng để soạn gói kỹ thuật 12 bữa và rule tăng huyết áp. Tài liệu lưu local; không thay thế phê duyệt của bác sĩ/chuyên gia dinh dưỡng.

## 1. Nguồn đã chụp và vai trò

| Mã nguồn | Nguồn | Phạm vi dùng | Trạng thái |
| --- | --- | --- | --- |
| `VIEN_DINH_DUONG_2019` | *Dinh dưỡng lâm sàng*, Viện Dinh dưỡng, 2019; file `book/Dinh_duong_lam_sang_Vien_Dinh_duong_2019.pdf`; SHA-256 `abea34b8a6a63e9eabd25f57141c18ba6ac31012c1d4a8dcc15f9ba68dc7f737` | Nguyên tắc xây dựng khẩu phần ở trang in 64–75; tăng huyết áp ở 131–143; đái tháo đường ở 235–245; người cao tuổi ở 349–359 | Đã đọc đúng trang. Dùng cho nguyên tắc và đối chiếu cấu trúc bữa; không lấy tổng ngày trong sách để suy ra từng món khi công thức thiếu thể tích/gia vị |
| `HOW_NOT_TO_DIE_VI_2022` | Michael Greger & Gene Stone, *Ăn gì không chết: Sức mạnh chữa lành của thực phẩm*, Hoàng Nữ Minh Nguyệt và Công Huyền Tôn Nữ Thùy Trang dịch, NXB Trẻ, in lần 8, 2022, ISBN `978-604-1-20442-3`; [trang sách NXB Trẻ](https://www.nxbtre.com.vn/sach/an-gi-khong-chet-suc-manh-chua-lanh-cua-thuc-pham-146415.html); bản đọc thử chính thức lưu tại `book/An_gi_khong_chet_NXB_Tre_2022_official_sample.html`, SHA-256 `993dd986d9ea7e4df78d9b9a80a1a16e38c045d8676191678316f6bbd8d899c9` | Nguồn nền để tìm chủ đề chế độ ăn giàu thực vật và lần về nghiên cứu gốc liên quan bệnh mạn tính | Chỉ là nguồn thứ cấp, bối cảnh gốc Hoa Kỳ. Không đặt ngưỡng, chống chỉ định hoặc rule phát hành trực tiếp từ sách; từng luận điểm dùng cho sản phẩm phải đối chiếu nghiên cứu gốc, hướng dẫn hiện hành của Việt Nam và reviewer lâm sàng. NXB Trẻ cũng nêu tranh luận về thiên lệch chọn bằng chứng và không nhận chủ trương loại bỏ toàn bộ thực phẩm động vật là quan điểm của nhà xuất bản |
| `LONGEVITY_DIET_VI_2021` | Valter Longo, *Chế độ ăn trường thọ: Tối ưu cân nặng, đẩy lùi bệnh tật, kéo dài tuổi thọ*, Nguyễn Khánh Chi dịch, NXB Dân Trí, 2021, ISBN `9786043140545`; [biểu ghi Thư viện KHTH TP.HCM](https://phucvu.thuvientphcm.gov.vn/Item/ItemDetail/748047); [trang phát hành Medinsights](https://shop.alphabooks.vn/che-do-an-truong-tho-toi-uu-can-nang-day-lui-benh-tat-keo-dai-tuoi-tho-p28835578.html); snapshot metadata lưu tại `book/Che_do_an_truong_tho_Medinsights_product_page_2026-10-16.html`, SHA-256 `54b849bce2d2767730b7cf5c556d03997ae5a840abe010545f6eac5d17dfae25` | Nguồn thứ cấp để lập danh sách nghiên cứu về chế độ ăn trường thọ, hạn chế thời gian ăn và fasting-mimicking diet (FMD) | Không đưa FMD/nhịn ăn/hạn chế năng lượng vào rule tự động. [NIA](https://www.nia.nih.gov/news/calorie-restriction-and-fasting-diets-what-do-we-know) cho biết chưa đủ bằng chứng khuyến nghị rộng rãi và còn thiếu dữ liệu an toàn ở người cao tuổi. Các thử nghiệm mới chỉ áp dụng nhóm chọn lọc; phải kiểm tra tiêu chí tuyển, thuốc, BMI, nguy cơ suy dinh dưỡng/thiểu cơ và xung đột lợi ích trước khi dùng. Chuyển `needs_professional_guidance` nếu beneficiary yêu cầu nhịn ăn/FMD |
| `VIETNAM_FOOD_COMPOSITION_2017` | [Công cụ giá trị dinh dưỡng thực phẩm của Viện Dinh dưỡng](https://viendinhduong.vn/vi/cong-cu-va-tien-ich/gia-tri-dinh-duong-thuc-pham); metadata được [FAO ghi nhận là Bảng thành phần thực phẩm Việt Nam 2017 của Bộ Y tế](https://www.fao.org/food-composition/tables-and-databases/detail/%28viet-nam--2017%29-vietnamese-food-composition-table/en) | Sáu chỉ số trên 100 g: năng lượng, đạm, carbohydrate, béo, xơ và natri cho 13 mục thực phẩm đã chọn | Đã chụp giá trị và mã thực phẩm vào `catalog/sources/nin-food-composition-2026-10-16.json`. Không gọi mạng trong runtime |
| `MOH_HTN_GUIDE_2010` | [Hướng dẫn chẩn đoán và điều trị tăng huyết áp, Quyết định 3192/QĐ-BYT](https://kcb.vn/phac-do/huong-dan-chan-doan-va-dieu-tri-tang-huyet-ap.html) | Đối chiếu nguyên tắc giảm muối của rule tăng huyết áp | Có nguồn chính thức nhưng văn bản năm 2010; chưa xác nhận tình trạng thay thế/cập nhật, nên rule còn `blocked_by_evidence` |
| `MOH_DIABETES_GUIDES` | [Trang tổng hợp hướng dẫn đái tháo đường của Cục Quản lý Khám, chữa bệnh](https://daithaoduong.kcb.vn/huong-dan-chan-doan-va-dieu-tri-dai-thao-duong-tip-2%26p%3D18), gồm Quyết định 5481/QĐ-BYT năm 2020 và 1353/QĐ-BYT năm 2021 | Xác định yêu cầu nghiên cứu cho rule đái tháo đường type 2 | Chưa đưa vào bundle P2. Engine v2 biểu diễn được khoảng năng lượng/carbohydrate theo ngày và theo bữa, nhưng profile chưa cung cấp mục tiêu cá thể, lịch bữa/thuốc và nguy cơ hạ đường huyết; giữ ngoài `supportedScopes` |
| `NIN_ELDERLY_GUIDANCE` | [Khuyến nghị dinh dưỡng cho người cao tuổi](https://viendinhduong.vn/vi/lookup/de-tai-nghien-cuu-khoa-hoc/khuyen-nghi-dinh-duong-cho-nguoi-cao-tuoi-68035d40359ef722321fcef3), Viện Dinh dưỡng | Chọn nhóm condition cần nhận diện ở hồ sơ người cao tuổi | Nguồn liệt kê suy dinh dưỡng, béo phì, rối loạn lipid máu, tăng huyết áp, đái tháo đường, tai biến mạch máu não, ung thư và bệnh mạn tính khác; chỉ dùng để seed dictionary/phân luồng |
| `NIN_ELDERLY_PYRAMID_2026` | [Hướng dẫn sử dụng tháp dinh dưỡng cho người cao tuổi](https://viendinhduong.vn/vi/proper-nutrition-and-health/nguoi-cao-tuoi/68baa5e00ca85001dd026ee2), Viện Dinh dưỡng | Nền cho bữa ăn người cao tuổi khỏe mạnh và danh sách dữ liệu cần có | Nêu khẩu phần theo nhóm thực phẩm và giới hạn muối/đường/dầu mỡ; không dùng các mức cộng đồng làm rule điều trị bệnh |
| `NIN_RNI_2026` | [Nhu cầu dinh dưỡng khuyến nghị cho người Việt Nam 2026](https://viendinhduong.vn/vi/article/tin-tuc/6a70094d06fb0c475f0ac123) | Xác định gap profile/engine cho người cao tuổi | Nhu cầu thay đổi theo tuổi, giới, hoạt động và tình trạng; nguồn nói rõ người mắc bệnh cần được cán bộ y tế/bác sĩ/chuyên gia dinh dưỡng đánh giá và cá thể hóa |
| `MOH_CKD_2024` | [Quyết định 2388/QĐ-BYT năm 2024 về bệnh thận mạn và một số bệnh lý thận](https://kcb.vn/phac-do/quyet-dinh-so-2388-qd-byt-ngay-12-8-2024-ve-viec-ban-hanh-tai-lieu-chuyen-mon-huong-dan-chan-doan-va-dieu-tri-benh-than-.html) | Xác nhận bệnh thận cần nhánh chuyên môn riêng | Dùng để giữ `KIDNEY_DISEASE` ngoài scope gợi ý tự động; không rút một ngưỡng chung vào `DailyMaximums` |
| `WHO_OLDER_UNDERNUTRITION_2023` | [WHO: Supplemental nutrition with dietary advice for older people affected by undernutrition](https://www.who.int/tools/elena/interventions/nutrition-older-people) | Xác nhận suy dinh dưỡng/thiểu cơ ở người cao tuổi cần đánh giá nhu cầu cá thể | WHO mô tả bổ sung protein, năng lượng, vitamin và khoáng chất theo nhu cầu do nhân viên y tế được đào tạo đánh giá; CareSitter chỉ nhận diện và chuyển chuyên gia |

## 2. Điều đã kiểm tra trong sách

- Phần xây dựng chế độ ăn yêu cầu tính năng lượng/dưỡng chất theo nhu cầu và chia theo bữa; không có một khẩu phần cố định phù hợp mọi người.
- Thực đơn tăng huyết áp ở trang in 142–143 có tổng ngày nhưng phần phở thiếu thể tích nước dùng và nhiều món không định lượng đầy đủ gia vị. Không thể tái tạo chính xác natri của từng bữa.
- Thực đơn đái tháo đường ở trang in 245 có tổng ngày nhưng cũng thiếu thể tích nước dùng và gia vị của món kho/rim. Không dùng con số natri tổng để gán ngược cho recipe.
- Phần người cao tuổi nhấn mạnh sàng lọc suy dinh dưỡng, ảnh hưởng của thuốc và chuyển chuyên gia khi khó nuốt. Các chặn hiện có của CareSitter được giữ nguyên.

## 3. Các bất thường không được tự sửa

- Phần tăng huyết áp có chỗ ghi đơn vị kali `4000–5000 g/ngày`, có khả năng là lỗi đơn vị. Không chuyển thành rule.
- Một số đoạn dùng “natri” và “muối” không nhất quán về đơn vị. Không quy đổi bằng suy đoán.
- Nhiều mục thực phẩm trên công cụ trực tuyến để trống một dưỡng chất thay vì ghi số 0. Generator P2 chỉ chọn 13 mục có đủ cả sáu chỉ số; không coi ô trống là 0.
- Bảng trong sách là thực đơn ví dụ toàn ngày, không phải phép duyệt cho 12 công thức CareSitter mới phối hợp.

## 4. Snapshot số liệu

Snapshot kỹ thuật nằm tại `backend/services/nutrition/catalog/sources/nin-food-composition-2026-10-16.json`. Mỗi mục giữ:

- mã thực phẩm Viện Dinh dưỡng và tên Việt/Anh;
- trạng thái cân `raw` hoặc `cooked`;
- sáu giá trị trên 100 g cùng đơn vị và khóa gốc;
- locator quay lại công cụ chính thức.

Generator dừng ngay nếu một mã thực phẩm không còn duy nhất hoặc thiếu một trong sáu dưỡng chất. Bundle dùng tổng `khối lượng × giá trị/100`, làm tròn hai chữ số; evidence lưu từng phép cộng.

## 5. Quyết định phát hành

| Nội dung | Trạng thái ngày 16/10/2026 | Lý do |
| --- | --- | --- |
| 12 bữa P2 | `technical_draft` | Đủ 4 sáng, 4 trưa, 4 tối; đủ sáu chỉ số, nguồn và phép tính. Công thức phối hợp, khẩu phần và giả định hệ số hao hụt chưa được chuyên gia dinh dưỡng duyệt |
| Rule tăng huyết áp | `blocked_by_evidence` | Engine biểu diễn được giới hạn natri và 64/64 tổ hợp kỹ thuật đang qua ngưỡng nháp; ngưỡng/phạm vi còn cần nguồn hiện hành và reviewer xác nhận |
| Rule đái tháo đường type 2 | `blocked_by_engine` | Chưa có mục tiêu năng lượng cá nhân và khoảng carbohydrate theo bữa |
| Publish catalog | `blocked` | Chưa có tên, bằng cấp, thời điểm và quyết định `approved` của reviewer gắn với SHA-256 chính xác của bundle |

Không đổi `contentStatus` thành `review_ready`, không xóa `unresolvedItems` và không điền reviewer giả để vượt cổng release.

## 6. Condition dictionary cho người cao tuổi

| Code | Vai trò hiện tại | Hành vi bắt buộc |
| --- | --- | --- |
| `HYPERTENSION` | Có rule nháp | Chỉ có thể mở sau review nguồn/ngưỡng |
| `TYPE_2_DIABETES`, `OBESITY` | Nhận diện; thiếu mô hình năng lượng/carbohydrate cá thể hóa | `needs_professional_guidance` |
| `DYSLIPIDEMIA` | Ứng viên nghiên cứu tiếp theo | Chặn đến khi có saturated/trans fat và cholesterol đầy đủ |
| `OSTEOPOROSIS`, `GOUT` | Nhận diện; thiếu dưỡng chất/chỉ số chuyên biệt | `needs_professional_guidance` |
| `MALNUTRITION`, `SARCOPENIA` | Nhận diện nguy cơ | Chuyển đánh giá chuyên môn, không tự tăng khẩu phần hoặc protein |
| `KIDNEY_DISEASE`, `HEART_FAILURE`, `STROKE`, `CANCER` | Nhóm phức tạp hoặc có thể kèm hạn chế/thuốc/khó nuốt | `needs_professional_guidance`; các hard block hiện có tiếp tục ưu tiên |

Các code trên được seed vào dictionary của bundle nháp nhưng chỉ `HYPERTENSION` xuất hiện trong `supportedScopes`. Sự tồn tại của concept không cấp quyền sinh thực đơn bệnh lý.
