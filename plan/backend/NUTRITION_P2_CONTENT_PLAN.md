# Kế hoạch P2 — 12 bữa và rule bệnh lý cho Nutrition

> Cập nhật: 16/10/2026. Trạng thái: **P2.1–P2.3 đã có bản nháp kỹ thuật; chưa có món hoặc rule lâm sàng được duyệt/phát hành**. P0 catalog và P1 pipeline quản trị đã hoàn thành. P2 hiện có 12 bữa, evidence cấp nguyên liệu/dưỡng chất, rule tăng huyết áp nháp, kiểm đủ 64 tổ hợp và engine rule v2 cho khoảng tối thiểu/tối đa theo ngày hoặc từng bữa; cổng release vẫn chặn đúng vì nội dung còn `unresolvedItems` và chưa có reviewer chuyên môn. Tài liệu này lưu local, không commit/push nếu chưa có yêu cầu riêng.

## 0. Tiến độ triển khai thực tế

| Hạng mục | Kết quả ngày 16/10/2026 | Trạng thái |
| --- | --- | --- |
| P2.0 — nguồn | Đã đọc đúng trang sách Viện Dinh dưỡng; chụp 13 mục thực phẩm từ công cụ chính thức; ghi các lỗi/điểm không thể suy diễn trong [sổ nguồn](NUTRITION_P2_SOURCE_REGISTER.md) | Còn thiếu xác nhận hiệu lực hướng dẫn tăng huyết áp và reviewer cụ thể |
| P2.1 — provenance/release validator | Bundle v1 vẫn đọc được; schema v2 thêm `nutrientConstraints` và evidence sidecar tiếp tục gắn SHA-256 file, nguồn từng nguyên liệu, phép tính từng dưỡng chất, review và kiểm tổ hợp | Code/test đạt |
| P2.2 — 12 bữa | Đã tạo bundle `adult-hypertension-p2.bundle.json`: 4 sáng, 4 trưa, 4 tối; mỗi bữa đủ sáu chỉ số | `technical_draft`; chưa nhập/publish |
| P2.3 — rule | Đã soạn rule `HYPERTENSION`; engine đã hỗ trợ minimum/maximum theo ngày và theo `breakfast`/`lunch`/`dinner`, kiểm ở C#, release gate và PostgreSQL | Tăng huyết áp `blocked_by_evidence`; các bệnh kế tiếp vẫn chờ dữ liệu/profile/review |
| P2.4 — tổ hợp | Baseline 64/64; scope tăng huyết áp nháp 64/64; dị ứng đậu nành còn 8 tổ hợp, lạc 27 và vừng 27; mỗi slot còn ít nhất 2 lựa chọn trong từng kịch bản đơn dị ứng | Kiểm kỹ thuật và PostgreSQL tạm đạt; API staging thật chờ bundle được duyệt/publish |
| P2.5 — duyệt/phát hành | `release-check` trả exit code 2 với lý do cụ thể; không cho phát hành nháp | Đúng thiết kế; chờ chuyên môn |

Toàn bộ solution đạt **80/80 test, 0 skip** với PostgreSQL local. Bộ test gồm import bundle v1, import/reject constraint v2 ngay tại biên database, áp dụng khoảng theo ngày/từng bữa và luồng P2 nhập/publish bundle chỉ trong database dùng một lần. Database test được xóa sau test, không biến bản nháp thành nội dung runtime.

File kỹ thuật:

- `backend/services/nutrition/catalog/drafts/adult-hypertension-p2.bundle.json`
- `backend/services/nutrition/catalog/drafts/adult-hypertension-p2.evidence.json`
- `backend/services/nutrition/catalog/sources/nin-food-composition-2026-10-16.json`
- `backend/services/nutrition/tools/generate_p2_draft.py`

## 1. Kết quả P2 cần bàn giao

P2 đưa Nutrition từ catalog kỹ thuật trống tới một gói nội dung thật, có thể kiểm tra và thu hồi:

- 12 bữa hoàn chỉnh cho người trưởng thành: 4 sáng, 4 trưa, 4 tối.
- Mỗi bữa có một khẩu phần, công thức, toàn bộ nguyên liệu/gia vị, dị nguyên, giá trị dinh dưỡng và nguồn truy vết được.
- Ít nhất một rule bệnh lý nằm trong khả năng của engine hiện tại, được người có chuyên môn duyệt trước khi phát hành.
- API thật tạo được 3 bữa, đổi từng bữa sang phương án hợp lệ, lưu và đọc lại cho hồ sơ nằm trong phạm vi.
- Hồ sơ thiếu dữ liệu, có thuốc, dị ứng không phù hợp hoặc nhu cầu chuyên biệt vẫn bị chặn đúng; không hạ điều kiện chỉ để sinh được thực đơn.

P2 không bao gồm thực đơn 7 ngày, tự chỉnh khẩu phần theo cân nặng, AI sáng tác món, bệnh thận, khó nuốt, ăn qua ống, hạn chế nước/điện giải hoặc hồ sơ dưới 18 tuổi.

## 2. Quyết định phạm vi

### 2.1. Tách nội dung nền và rule bệnh lý

P2 được chia thành hai gói có cổng duyệt riêng:

| Gói | Nội dung | Điều kiện phát hành |
| --- | --- | --- |
| P2A — bữa nền | 12 bữa hoàn chỉnh, dữ liệu dinh dưỡng và dị nguyên đầy đủ | Dùng được cho hồ sơ người lớn không có bệnh cần rule riêng, đã khai không dùng thuốc và không có nhu cầu chuyên biệt |
| P2B — rule bệnh lý | Rule giới hạn/từ chối món dựa trên dữ liệu của 12 bữa | Chỉ phát hành khi điều kiện có thể biểu diễn đúng trong engine, nguồn còn hiệu lực và người duyệt chuyên môn ký duyệt |

Không lấy một bữa “lành mạnh chung” để mặc nhiên coi là phù hợp với mọi bệnh. Nếu hồ sơ có bệnh nhưng chưa có rule đã phát hành, API tiếp tục trả hướng dẫn cần chuyên gia thay vì dùng gói P2A.

### 2.2. Bệnh ưu tiên

| Bệnh/nhóm | Trạng thái đề xuất ở P2 | Lý do |
| --- | --- | --- |
| Tăng huyết áp | Ứng viên phát hành đầu tiên | Engine đã cộng tổng dưỡng chất của 3 bữa và áp dụng `DailyMaximums`; có thể biểu diễn giới hạn natri nếu ngưỡng, phạm vi và cách tính được nguồn hiện hành cùng người duyệt xác nhận |
| Rối loạn lipid máu | `blocked_by_data` | Engine v2 đã biểu diễn được khoảng theo ngày, nhưng catalog phải bổ sung chất béo bão hòa, trans fat và cholesterol; không dùng tổng chất béo thay thế các chỉ số này |
| Đái tháo đường type 2 | `engine_range_ready`, chưa phát hành | Engine v2 đã biểu diễn được khoảng năng lượng/carbohydrate theo từng bữa. Profile chưa có dữ liệu để tính mục tiêu năng lượng cá thể và chưa có rule/nguồn/reviewer được duyệt |
| Béo phì | `blocked_by_engine` | Cần mục tiêu năng lượng theo tuổi, giới, cân nặng, mức hoạt động và kế hoạch theo dõi; profile/engine hiện chưa đủ trường |
| Loãng xương | `blocked_by_data` | Cần ít nhất canxi, vitamin D, protein và bối cảnh tuổi/giới/thuốc; bộ sáu dưỡng chất P2 chưa đủ |
| Gút | `blocked_by_data` | Catalog chưa có purin, đồ uống có cồn và các điều kiện liên quan; không suy hàm lượng purin từ tên thực phẩm |
| Suy dinh dưỡng/nguy cơ suy dinh dưỡng, thiểu cơ | `professional_guidance` | Cần sàng lọc, cân nặng/giảm cân, khối cơ, khẩu phần thực tế, khả năng ăn và mục tiêu năng lượng-protein cá thể hóa |
| Bệnh thận, suy tim, tai biến/đột quỵ, ung thư | `professional_guidance` | Có thể liên quan thuốc, hạn chế nước/điện giải, khó nuốt hoặc nhu cầu điều trị riêng; giữ chặn và chuyển chuyên gia |

Bundle P2 seed dictionary cho 11 condition code mới: `TYPE_2_DIABETES`, `DYSLIPIDEMIA`, `OBESITY`, `OSTEOPOROSIS`, `MALNUTRITION`, `SARCOPENIA`, `GOUT`, `KIDNEY_DISEASE`, `HEART_FAILURE`, `STROKE`, `CANCER`. Seed chỉ giúp chuẩn hóa dữ liệu hồ sơ và trả `needs_professional_guidance` đúng thay vì để bệnh rơi vào ghi chú chưa hiểu. Các code này không nằm trong `supportedScopes` và không có rule phát hành.

Viện Dinh dưỡng liệt kê suy dinh dưỡng, béo phì, rối loạn lipid máu, tăng huyết áp, đái tháo đường, tai biến mạch máu não, ung thư và các bệnh mạn tính khác trong nhóm vấn đề dinh dưỡng thường gặp ở người cao tuổi. Danh sách seed bổ sung loãng xương theo dịch vụ tư vấn người lớn/người cao tuổi của Viện, cùng gút, bệnh thận và suy tim theo các chương bệnh lý trong sách. Đây là danh sách nhận diện và phân luồng, không phải tuyên bố CareSitter điều trị các bệnh này.

Các yếu tố `DYSPHAGIA`, `POOR_DENTITION`, `CONSTIPATION`, `FLUID_RESTRICTION`, sụt cân nhanh và giảm khả năng tự ăn cần được mô hình hóa như triệu chứng/modifier hoặc nhu cầu chăm sóc, không gộp thành disease rule. Schema concept v1 chưa có kind phù hợp cho toàn bộ nhóm này; các hard block nuốt/đường nuôi ăn/nước-điện giải hiện có vẫn giữ nguyên.

### 2.3. Thứ tự mở rộng sau tăng huyết áp

Thứ tự dưới đây là thứ tự làm năng lực và dữ liệu. Một bệnh chỉ được thêm vào `supportedScopes` sau khi qua cổng nguồn, dữ liệu, tổ hợp, review chuyên môn và API; việc condition code đã được seed không đồng nghĩa rule đã được phát hành.

| Thứ tự | Nhóm bệnh | Phần cần thêm trước khi soạn rule phát hành | Tiêu chí kỹ thuật đầu tiên |
| ---: | --- | --- | --- |
| 1 | Rối loạn lipid máu | Bổ sung `saturated_fat_g`, `trans_fat_g`, `cholesterol_mg` cho toàn bộ recipe và evidence tương ứng | Mọi recipe có số liệu không null; release validator bắt buộc tính lại mọi dưỡng chất dùng trong rule |
| 2 | Đái tháo đường type 2 | Khóa nguồn cho mục tiêu năng lượng/carbohydrate, xác định dữ liệu hồ sơ cần dùng để cá thể hóa và soạn khoảng theo từng bữa | Test biên minimum/maximum cho từng meal type; thiếu mục tiêu hoặc thiếu dưỡng chất phải chặn |
| 3 | Béo phì | Dùng chung nền tính năng lượng với đái tháo đường; bổ sung cân nặng, chiều cao, mức hoạt động và thời điểm đo có kiểm soát độ mới | Không phát hành khi không tính được mục tiêu cá thể hoặc dữ liệu đo đã quá hạn |
| 4 | Loãng xương | Bổ sung `calcium_mg`, `vitamin_d_ug` và dữ liệu khẩu phần tương ứng; xác định vai trò của protein, tuổi, giới và thuốc | Không suy vitamin D từ tên món; mọi giá trị có nguồn và phép tính |
| 5 | Gút | Có nguồn purine đáng tin, dữ liệu đồ uống có cồn và chính sách khi đồng mắc bệnh thận/tim | Bệnh kèm thuộc diện chuyên gia phải thắng rule gút tự động |
| 6 | Suy dinh dưỡng, thiểu cơ, bệnh thận, suy tim, ung thư, đột quỵ | Giữ `professional_guidance`; chỉ nghiên cứu schema sàng lọc, modifier và thông tin chuyển tuyến | Không sinh thực đơn tự động từ condition code của các nhóm này |

Schema v2 là nền chung cho bước 1–2: `NutrientConstraint` có `nutrientKey`, `scope`, `mealType`, `minimum`, `maximum`. `scope=daily` cộng ba bữa; `scope=meal` chỉ kiểm bữa đã chỉ định. Dữ liệu thiếu/null, ngưỡng âm, minimum lớn hơn maximum và constraint trùng đều bị từ chối. Schema này chưa tự tính mục tiêu cá thể; bước 2–3 vẫn cần contract hồ sơ riêng trước khi phát hành rule.

Ma trận profile, nutrient keys, hard block và 36 liên kết nguồn được lưu riêng tại [NUTRITION_DISEASE_RULE_RESEARCH_2026-10-16.md](NUTRITION_DISEASE_RULE_RESEARCH_2026-10-16.md).

Trang chính thức của Cục Quản lý Khám, chữa bệnh đang tìm thấy cho tăng huyết áp dẫn tới Quyết định 3192/QĐ-BYT năm 2010; trang quy trình đái tháo đường dẫn tới Quyết định 3798/QĐ-BYT năm 2017. Đây là đầu mối để đối chiếu, không phải bằng chứng rằng chưa có văn bản thay thế. P2.0 phải kiểm tra tình trạng còn hiệu lực trước khi rút ngưỡng hoặc phát hành rule:

- [Hướng dẫn chẩn đoán và điều trị tăng huyết áp — Cục Quản lý Khám, chữa bệnh](https://kcb.vn/phac-do/huong-dan-chan-doan-va-dieu-tri-tang-huyet-ap.html)
- [Quy trình lâm sàng điều trị đái tháo đường — Cục Quản lý Khám, chữa bệnh](https://daithaoduong.kcb.vn/quy-trinh-lam-sang-dieu-tri-dai-thao-duong)

## 3. Cấu trúc bộ 12 bữa

Mỗi `Recipe` là một bữa hoàn chỉnh, không phải một món lẻ. Một bữa có thể gồm phần tinh bột, món đạm, rau/canh và phần kèm; engine xem toàn bộ đó là một đơn vị để gợi ý hoặc đổi bữa.

| Mã làm việc | Loại bữa | Số lượng | Yêu cầu |
| --- | --- | ---: | --- |
| `BF-01` … `BF-04` | Sáng | 4 | Bốn lựa chọn độc lập, một khẩu phần hoàn chỉnh |
| `LN-01` … `LN-04` | Trưa | 4 | Bốn lựa chọn độc lập, khai đủ cả gia vị/dầu/nước chấm |
| `DN-01` … `DN-04` | Tối | 4 | Bốn lựa chọn độc lập, khai đủ cả gia vị/dầu/nước chấm |

Tên và thành phần món chỉ được chốt sau khi hoàn thành đối chiếu nguồn ở P2.0. Không điền tên món từ trí nhớ rồi bổ sung citation về sau.

### 3.1. Dữ liệu bắt buộc cho mỗi bữa

- `servings = 1`.
- Mỗi nguyên liệu có mã chuẩn, tên hiển thị tiếng Việt, lượng, đơn vị `g` hoặc `ml`, và trạng thái cân sống/chín.
- Liệt kê cả dầu, muối, nước mắm, nước tương, đường, sốt, nước dùng và thành phần đóng gói có ảnh hưởng tới dưỡng chất hoặc dị nguyên.
- Dị nguyên được khai theo thành phần thực tế, gồm dị nguyên ẩn trong gia vị/sốt.
- Ít nhất có `energy_kcal`, `carbohydrate_g`, `protein_g`, `fat_g`, `fiber_g`, `sodium_mg` trên một khẩu phần. Dưỡng chất dùng trong rule không được thiếu.
- Hướng dẫn chuẩn bị đủ để tái tạo đúng khẩu phần đã tính, nhưng không sao chép dài từ sách.
- Citation chỉ rõ tài liệu, phiên bản/năm, trang hoặc bảng, và vai trò của nguồn.

Validator P0 hiện chỉ yêu cầu có ít nhất một dưỡng chất. P2 phải bổ sung profile kiểm tra nội dung phát hành để bắt buộc bộ sáu chỉ số trên; không thay đổi im lặng ý nghĩa bundle v1 đã khóa.

### 3.2. Truy vết số liệu

Mỗi bữa cần bốn lớp bằng chứng:

1. Nguồn nguyên tắc lâm sàng: *Dinh dưỡng lâm sàng* của Viện Dinh dưỡng và hướng dẫn chuyên môn còn hiệu lực.
2. Nguồn thành phần nguyên liệu: ưu tiên *Bảng thành phần thực phẩm Việt Nam* đúng ấn bản, có quy ước phần ăn được và đơn vị.
3. Bảng tính: lượng nguyên liệu, hệ số phần ăn được/hao hụt nếu dùng, phép cộng và quy tắc làm tròn tạo ra giá trị trên một khẩu phần.
4. Bằng chứng duyệt: người nhập, người duyệt chuyên môn, ngày duyệt, digest bundle và ghi chú phạm vi.

Bundle v1 hiện có citation ở cấp recipe nhưng chưa truy vết từng nguyên liệu và từng phép tính dưỡng chất. Trước khi nhập nội dung thật, P2 phải chọn một trong hai cách và ghi quyết định:

- thêm hồ sơ bằng chứng đi kèm bundle, được ràng buộc bằng cùng digest; hoặc
- tạo schema bundle v2 có provenance ở cấp nguyên liệu/dưỡng chất và giữ importer v1 tương thích ngược.

Không sửa ý nghĩa của schema v1 tại chỗ sau khi đã khóa.

## 4. Các gói công việc

### P2.0 — Khóa nguồn và phạm vi chuyên môn

1. Đọc theo trang các phần lập khẩu phần, tăng huyết áp, đái tháo đường và người cao tuổi trong bản *Dinh dưỡng lâm sàng* đã lưu tại `book/`.
2. Kiểm tra văn bản Bộ Y tế/Cục Quản lý Khám, chữa bệnh có bị thay thế hoặc cập nhật không.
3. Có bản *Bảng thành phần thực phẩm Việt Nam* được phép sử dụng; đọc quy ước đơn vị, phần ăn được, số liệu thiếu và cách làm tròn.
4. Chỉ định người duyệt chuyên môn và ghi rõ vai trò; người nhập không được tự duyệt/phát hành.
5. Chốt nhóm người dùng: người lớn, ăn đường miệng bình thường, không hạn chế nước/điện giải, đã khai không dùng thuốc.

**Đầu ra:** sổ nguồn có phiên bản, trang/bảng, trạng thái hiệu lực, phạm vi sử dụng và người chịu trách nhiệm duyệt.

### P2.1 — Chuẩn hóa mẫu nhập và provenance

1. Khóa dictionary mã nguyên liệu, dưỡng chất, dị nguyên và đơn vị.
2. Tạo mẫu bảng tính một khẩu phần và quy tắc làm tròn.
3. Bổ sung profile validator dành cho release P2.
4. Bổ sung định dạng bằng chứng cấp nguyên liệu/dưỡng chất theo quyết định ở mục 3.2.
5. Tạo lệnh kiểm tra để một giá trị dinh dưỡng dùng trong rule luôn có nguồn và phép tính.

**Đầu ra:** một recipe mẫu vượt validator nhưng vẫn ở trạng thái `draft`.

### P2.2 — Soạn 12 bữa

1. Soạn lần lượt 4 bữa sáng, 4 bữa trưa và 4 bữa tối từ nguồn đã khóa.
2. Tính giá trị trên đúng một khẩu phần, lưu bảng tính trung gian và assumptions.
3. Khai đầy đủ dị nguyên và các thành phần phụ.
4. Chạy `validate` và `import --dry-run` sau từng nhóm bốn bữa.
5. Rà thủ công những giá trị bất thường, số liệu thiếu và nguyên liệu phải thay thế.

**Đầu ra:** bundle 12 bữa ở trạng thái `draft`, có digest và báo cáo kiểm tra kỹ thuật.

### P2.3 — Soạn rule bệnh lý

#### Rule ứng viên tăng huyết áp

- Prerequisite phải chỉ rõ hồ sơ báo cáo có tăng huyết áp, người lớn, không dùng thuốc, ăn đường miệng bình thường và không có nhóm chuyên biệt đang bị chặn.
- Dùng `DailyMaximums` chỉ sau khi chốt dưỡng chất, đơn vị và ngưỡng từ nguồn còn hiệu lực.
- Tổng của ba bữa chỉ mô tả ba bữa do CareSitter gợi ý; không tuyên bố là toàn bộ lượng ăn trong ngày nếu chưa quản lý đồ uống, bữa phụ và thực phẩm ngoài kế hoạch.
- Rule phải có test biên tại ngưỡng, vượt ngưỡng, thiếu dưỡng chất và kết hợp dị ứng.

#### Rule ứng viên đái tháo đường type 2

- Lập bảng yêu cầu dữ liệu và predicate cần có: tổng năng lượng mục tiêu, khoảng carbohydrate theo bữa, phân bố bữa và các yếu tố cá nhân nếu nguồn yêu cầu.
- Nếu thiếu field hồ sơ hoặc engine chưa biểu diễn được, giữ rule ở tài liệu nghiên cứu/`draft`; không review và publish.
- Chỉ mở phạm vi sau một thay đổi contract/engine riêng được kiểm thử và người duyệt chuyên môn xác nhận.

**Đầu ra:** ít nhất một rule có quyết định rõ `publishable`, `blocked_by_engine` hoặc `blocked_by_evidence`; không có trạng thái mơ hồ “tạm dùng được”.

### P2.4 — Kiểm tra tổ hợp và API thật

Với 4 lựa chọn cho mỗi bữa có tối đa `4 × 4 × 4 = 64` tổ hợp. Công cụ kiểm tra phải duyệt toàn bộ 64 tổ hợp thay vì chỉ tin vào tổ hợp đầu tiên engine chọn.

Kiểm tra bắt buộc:

- Mỗi recipe xuất hiện trong ít nhất một tổ hợp hợp lệ thuộc phạm vi của nó.
- Mỗi vị trí sáng/trưa/tối có ít nhất một lựa chọn thay thế khác với bữa hiện tại; mục tiêu là còn ít nhất hai phương án hợp lệ sau khi áp dụng rule thông thường.
- Dị ứng loại đúng mọi recipe chứa dị nguyên, kể cả qua sốt/gia vị.
- Thiếu dưỡng chất mà rule yêu cầu phải chặn, không mặc định bằng 0.
- Tổng dưỡng chất của mọi tổ hợp được chấp nhận không vượt ngưỡng rule.
- Hai bệnh đồng thời chỉ được chạy nếu tổ hợp rule đã được duyệt; nếu chưa, chuyển chuyên gia.
- Publish, retire và catalog thay đổi giữa lúc tạo/lưu được xử lý theo revision hiện có.

Kịch bản API nghiệm thu:

| Hồ sơ | Kết quả mong đợi |
| --- | --- |
| Người lớn, không bệnh cần rule, khai không dùng thuốc, đủ dữ liệu | `suggested` với đủ sáng/trưa/tối; đổi từng bữa, lưu và đọc lại thành công |
| Người lớn tăng huyết áp, đúng prerequisite, rule đã duyệt | Chỉ nhận tổ hợp đáp ứng rule đã phát hành; response chỉ rõ rule/citation |
| Đái tháo đường type 2 khi rule còn `draft` | Chuyển hướng dẫn chuyên gia; không dùng bữa nền để lách rule |
| Có dị ứng | Không trả recipe chứa dị nguyên; nếu hết lựa chọn thì trả không có tổ hợp phù hợp |
| Đang dùng thuốc | Chuyển hướng dẫn chuyên biệt theo policy hiện tại |
| Thiếu ngày sinh, bệnh, dị ứng, thuốc hoặc nhu cầu ăn đặc biệt | `needs_information` với đúng trường thiếu |
| Khó nuốt, ăn qua ống, bệnh thận hoặc hạn chế nước/điện giải | Chuyển chuyên gia |
| Bundle bị retire | Không dùng bản đã retire cho recommendation mới |

### P2.5 — Duyệt, phát hành và theo dõi

1. Importer nhập bundle `draft` và xuất digest/báo cáo.
2. Người duyệt chuyên môn đối chiếu nguồn, bảng tính, dị nguyên, phạm vi và lời mô tả.
3. Reviewer duyệt đúng digest; publisher là tài khoản khác và chỉ phát hành bản đã duyệt.
4. Phát hành vào môi trường staging, chạy trọn bộ kịch bản API P2.4 và kiểm response/citation.
5. Chỉ phát hành production sau khi staging đạt; chuẩn bị sẵn thao tác `retire` và version thay thế.

## 5. Cổng nghiệm thu

| Cổng | Điều kiện đạt |
| --- | --- |
| Nguồn | Mọi nguyên tắc, thành phần và ngưỡng có tài liệu, phiên bản, trang/bảng; đã kiểm tra văn bản thay thế |
| Dữ liệu | 12/12 bữa đủ thành phần, dị nguyên, sáu chỉ số dinh dưỡng, khẩu phần và phép tính truy vết được |
| An toàn | Profile ngoài phạm vi vẫn bị chặn; không suy ngưỡng từ tên bệnh; dữ liệu thiếu không được tính là 0 |
| Tổ hợp | Duyệt đủ 64 tổ hợp; mỗi bữa có đường sử dụng và mỗi slot có lựa chọn đổi hợp lệ trong phạm vi công bố |
| Duyệt | Người nhập, reviewer chuyên môn và publisher tách vai trò; approval gắn digest |
| API | Luồng `assessment → confirmation → recommendation → replace → save → read` chạy trên API thật và lưu bằng chứng response |

P2 chỉ được đánh dấu hoàn thành khi 12 bữa và ít nhất một rule bệnh lý đã vượt toàn bộ cổng trên. Nếu chưa có rule bệnh lý đủ điều kiện phát hành, có thể hoàn thành P2A nhưng trạng thái tổng vẫn là **P2 đang làm**.

## 6. Thứ tự thực hiện và ước lượng

| Thứ tự | Công việc | Ước lượng kỹ thuật |
| ---: | --- | ---: |
| 1 | P2.0 khóa nguồn, phạm vi và reviewer | 0,5–1 ngày, chưa gồm thời gian chờ chuyên môn |
| 2 | P2.1 mẫu nhập, provenance và validator release | 0,5–1 ngày |
| 3 | P2.2 soạn/tính 12 bữa | 2–3 ngày |
| 4 | P2.3 rule tăng huyết áp và phân tích gap đái tháo đường | 1–2 ngày |
| 5 | P2.4–P2.5 kiểm 64 tổ hợp, API staging, duyệt/phát hành | 1–2 ngày |

Tổng thực tế: khoảng **5–9 ngày kỹ thuật cộng thời gian review chuyên môn**. Có thể làm bảng thành phần, recipe và công cụ duyệt tổ hợp song song sau khi P2.0 khóa nguồn, nhưng không thể bỏ cổng review để rút ngắn lịch.

## 7. Điểm chặn phải giải quyết trước khi nhập nội dung thật

1. Có bản đầy đủ, hợp lệ của *Bảng thành phần thực phẩm Việt Nam* và hiểu quy ước số liệu.
2. Xác nhận hướng dẫn tăng huyết áp/đái tháo đường đang dùng chưa bị thay thế.
3. Chỉ định reviewer chuyên môn cụ thể.
4. Chốt cách lưu provenance cấp nguyên liệu/dưỡng chất mà không phá bundle v1.
5. Chấp nhận rằng rule đái tháo đường có thể nằm ngoài P2 phát hành nếu engine và hồ sơ chưa đủ dữ liệu.

Sau khi năm điểm này được giải quyết, thứ tự triển khai nên là: **một recipe mẫu → validator/provenance → đủ 12 bữa → rule tăng huyết áp → 64 tổ hợp → API staging → review/publish**.
