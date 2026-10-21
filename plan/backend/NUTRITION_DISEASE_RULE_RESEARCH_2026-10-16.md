# Nghiên cứu rule dinh dưỡng theo bệnh cho CareSitter

**Ngày chốt nghiên cứu:** 16/10/2026  
**Phạm vi:** rối loạn lipid máu, đái tháo đường type 2, béo phì, loãng xương, gout; đồng thời xác định các trường hợp phải chuyển chuyên gia.  
**Trạng thái:** tài liệu thiết kế và đăng ký nguồn nội bộ; không phải phác đồ điều trị, không tự làm cho rule có hiệu lực phát hành.

## 1. Kết luận phát hành

Catalog có thể seed thêm các `condition concept` để nhận diện hồ sơ người cao tuổi, nhưng **seed concept không đồng nghĩa bệnh đó đã được hỗ trợ sinh thực đơn**. Một bệnh chỉ được đưa vào `supported scope` khi đồng thời có nguồn còn hiệu lực, dữ liệu món đủ, hồ sơ đầu vào đủ, engine biểu diễn đúng rule, bộ ca kiểm thử và người chuyên môn duyệt.

| Thứ tự | Nhóm bệnh | Quyết định hiện tại | Điều kiện để tiến tới tự động hóa |
| --- | --- | --- | --- |
| 1 | Rối loạn lipid máu | Ứng viên phát hành kế tiếp | Bổ sung dữ liệu acid béo bão hòa, trans fat và cholesterol; hỗ trợ `% năng lượng`; phân biệt kiểu rối loạn lipid và nguy cơ tim mạch |
| 2 | Đái tháo đường type 2 | Engine v2 có thể biểu diễn khoảng năng lượng/carbohydrate theo ngày và theo bữa, nhưng chưa được phát hành | Phải có mục tiêu năng lượng và carbohydrate cá thể, lịch bữa, thuốc và nguy cơ hạ đường huyết từ hồ sơ hoặc chỉ định chuyên môn |
| 3 | Béo phì | Chưa được phát hành | Phải có chiều cao, cân nặng, diễn tiến cân nặng, mức hoạt động, mục tiêu do chuyên môn xác nhận và sàng lọc suy dinh dưỡng/thiểu cơ |
| 4 | Loãng xương | Chỉ nghiên cứu dữ liệu | Phải tính tổng từ thức ăn và bổ sung, có calcium/vitamin D đáng tin cậy, chức năng thận và nguy cơ sỏi/tăng calcium máu; không tự kê thực phẩm bổ sung |
| 5 | Gout | Chưa được phép dùng ngưỡng số tự động | Chưa có bảng purine Việt Nam đủ tin cậy và guideline hiện đại không cung cấp một ngưỡng purine số phổ quát; phải xét thận, tim, sỏi, thuốc và tình trạng cơn gout |
| Chuyển chuyên gia | Suy dinh dưỡng, thiểu cơ, bệnh thận, suy tim, ung thư, đột quỵ | `needs_professional_guidance` | Chỉ áp dụng đơn chuyên môn đã được nhập có cấu trúc; không tự suy ra mục tiêu điều trị |

Tài liệu này không đề xuất bật rule điều trị mới. Những con số được trích ở phần sau là **bằng chứng để chuyên gia duyệt**, không phải giá trị phát hành mặc định.

## 2. Khả năng hiện tại và khoảng trống kỹ thuật

Schema catalog v2 hiện biểu diễn được `NutrientConstraint` dạng `minimum`/`maximum`, theo phạm vi `daily` hoặc theo `mealType`. Vì vậy hệ thống đã có thể biểu diễn một khoảng năng lượng hay carbohydrate tuyệt đối cho từng bữa **nếu mục tiêu cá thể đã được cung cấp và duyệt**.

Những phép tính sau chưa có trong contract hiện tại:

- phần trăm năng lượng từ một chất (`percent_energy_daily`), cần cho chất béo bão hòa và trans fat;
- gram trên kg cân nặng mỗi ngày (`per_kg_daily`), cần cho protein và năng lượng trong nhiều nhóm bệnh;
- công thức dựa trên cân nặng mục tiêu, mức vận động, giai đoạn bệnh hoặc xét nghiệm;
- điều kiện theo thuốc, xét nghiệm và hiệu lực của chỉ định chuyên môn;
- tổng lượng nhận từ món ăn + sữa/ONS + thực phẩm bổ sung + thuốc;
- mức dịch, kết cấu thức ăn và độ đặc chất lỏng.

Hồ sơ hiện có đã đọc bệnh nền, dị ứng, thuốc và ghi chú; nutrition snapshot có trạng thái bệnh/thuốc, đường nuôi ăn, nuốt, hạn chế dịch và điện giải. Hồ sơ chưa đủ chiều cao, cân nặng, diễn tiến cân nặng, giới, mức hoạt động, xét nghiệm có ngày/đơn vị, giai đoạn bệnh, lịch dùng thuốc và mục tiêu do chuyên gia kê. Do đó một constraint có thể hợp lệ về cú pháp nhưng vẫn chưa đủ căn cứ lâm sàng để chạy.

## 3. Mở rộng dữ liệu chung trước khi thêm bệnh

### 3.1. Hồ sơ bắt buộc có nguồn gốc và thời điểm

| Nhóm dữ liệu | Trường tối thiểu đề xuất | Quy tắc chất lượng |
| --- | --- | --- |
| Nhân trắc | `height_cm`, `weight_kg`, `weight_measured_at`, `usual_weight_kg`, `weight_change_period_days`, `waist_cm` khi phù hợp | Không dùng cân nặng tự khai cũ để tính đơn vị `/kg` mà không hiển thị cảnh báo; lưu cân nặng thực, cân nặng khô hoặc cân nặng mục tiêu thành các trường riêng |
| Cá thể | `date_of_birth`, `sex_at_birth`, `activity_level`, mức vận động/chức năng | Giá trị mức hoạt động phải đến từ vocabulary đã khóa, không lấy trực tiếp từ ghi chú tự do |
| Bệnh | concept chuẩn hóa, trạng thái xác nhận, mức độ/giai đoạn, biến chứng, ngày chẩn đoán | `suspected` hoặc không rõ giai đoạn không được kích hoạt rule điều trị |
| Xét nghiệm | `test_code`, `value`, `unit`, `collected_at`, `source`, khoảng tham chiếu nếu có | Không so sánh số khi chưa chuẩn hóa đơn vị; dữ liệu hết hạn theo chính sách từng rule |
| Thuốc | hoạt chất, liều, lịch dùng, mục đích, trạng thái | Thuốc có liên hệ với bữa ăn phải có thời điểm dùng; tên thuốc tự do giữ hệ thống ở `needs_information` |
| Đơn dinh dưỡng | người duyệt, mục tiêu/giới hạn, đơn vị, ngày hiệu lực, ngày hết hạn, lý do | Rule cá thể chỉ chạy trong thời hạn và không được mở rộng ra ngoài mục tiêu đã kê |
| An toàn ăn uống | dị ứng, đường nuôi ăn, đánh giá nuốt, kết cấu/độ đặc được chỉ định, hạn chế dịch/điện giải | Thiếu đánh giá nuốt ở người có nguy cơ không được suy ra “ăn đường miệng bình thường” |

[Nhu cầu năng lượng trong Khuyến nghị dinh dưỡng cho người Việt Nam 2026 phụ thuộc cân nặng tham chiếu và mức hoạt động](https://viendinhduong.vn/vi/article/tin-tuc/6a70094d06fb0c475f0ac123), còn người có bệnh, rối loạn chuyển hóa, suy dinh dưỡng, béo phì hoặc nhu cầu điều trị đặc biệt phải được đánh giá và cá thể hóa bởi nhân viên y tế/chuyên gia dinh dưỡng. Đây là căn cứ cho việc bắt buộc nhân trắc, mức hoạt động và đơn chuyên môn thay vì tự suy mục tiêu từ tên bệnh.

### 3.2. Nutrient keys và đơn vị chuẩn

Mọi giá trị catalog là **trên một khẩu phần đã chuẩn hóa**; rule ghi rõ phạm vi ngày/bữa và loại công thức. Không dùng tên món để suy dưỡng chất.

| Key | Đơn vị catalog | Loại constraint dự kiến | Nhóm bệnh sử dụng |
| --- | --- | --- | --- |
| `energy_kcal` | kcal/serving | daily/meal range; về sau `per_kg_daily` hoặc clinician order | T2D, béo phì, suy dinh dưỡng, thận, ung thư |
| `carbohydrate_g` | g/serving | daily range, meal range | T2D |
| `protein_g` | g/serving | daily range; về sau `per_kg_daily` | béo phì ở người cao tuổi, thận, suy dinh dưỡng, thiểu cơ, ung thư |
| `fat_g` | g/serving | daily range | rối loạn lipid |
| `saturated_fat_g` | g/serving | `percent_energy_daily` hoặc derived daily max | rối loạn lipid |
| `trans_fat_g` | g/serving | `percent_energy_daily` hoặc derived daily max | rối loạn lipid |
| `cholesterol_mg` | mg/serving | daily max | rối loạn lipid |
| `fiber_g` | g/serving | daily min/range | rối loạn lipid, T2D, béo phì |
| `free_sugar_g` | g/serving | `percent_energy_daily` hoặc derived daily max | T2D, rối loạn lipid, gout |
| `sodium_mg` | mg/serving | daily max hoặc clinician order | tim mạch, thận, suy tim |
| `calcium_mg` | mg/serving | daily range trên **tổng nguồn** | loãng xương |
| `vitamin_d_ug` | µg/serving | daily range trên **tổng nguồn** | loãng xương |
| `potassium_mg` | mg/serving | clinician order có điều kiện xét nghiệm | thận, suy tim |
| `phosphorus_mg` | mg/serving | clinician order có điều kiện xét nghiệm | thận |
| `fluid_ml` | mL/serving | clinician order | thận, suy tim |
| `alcohol_g` | g/serving | daily max/ingredient block | gout, rối loạn lipid, T2D |
| `purine_mg` | mg/serving | chưa cho phép phát hành | gout |

Các trường `texture_level`, `liquid_thickness` và `feeding_route` là thuộc tính an toàn/khẩu phần, không phải nutrient key.

## 4. Rối loạn lipid máu

### 4.1. Bằng chứng và cách diễn giải

[Viện Dinh dưỡng Quốc gia](https://viendinhduong.vn/vi/article/tin-tuc/giai-phap-an-uong-khoa-hoc-cho-nguoi-bi-roi-loan-lipid-mau-688356d770185b05a6022336) nêu rối loạn lipid có thể là bất thường cholesterol toàn phần, LDL-C, triglyceride hoặc HDL-C; vì vậy không được gom mọi hồ sơ vào một rule duy nhất. Bài hướng dẫn nêu các ứng viên để chuyên gia thẩm định: acid béo bão hòa dưới 7–10% tổng năng lượng, giảm tối đa trans fat, chất xơ tối thiểu 20–30 g/ngày, cholesterol khẩu phần dưới 200–300 mg/ngày, muối dưới 5 g/ngày và cá thể hóa theo tuổi, mức độ bệnh, bệnh kèm và tình trạng dinh dưỡng.

[Khuyến nghị dinh dưỡng cho người Việt Nam 2026](https://viendinhduong.vn/vi/article/tin-tuc/6a70094d06fb0c475f0ac123) cũng nêu lipid ở người trưởng thành, EPA/DHA, cholesterol, trans fat, carbohydrate, chất xơ và đường tự do theo nhóm dân số. Đây là giá trị tham chiếu dân số; chính tài liệu yêu cầu người có bệnh phải được cá thể hóa.

Bài của Viện Dinh dưỡng dẫn “Quyết định 3762/QĐ-BYT năm 2020”, nhưng nghiên cứu này chưa xác minh được bản gốc tương ứng trên cổng Bộ Y tế/Cục KCB. Không đưa mã quyết định đó vào source registry phát hành cho đến khi người quản trị nguồn đối chiếu được văn bản gốc.

### 4.2. Profile bắt buộc

- chẩn đoán và kiểu bất thường: LDL-C, triglyceride, hỗn hợp hoặc kiểu khác;
- lipid panel gần nhất gồm TC, LDL-C, HDL-C, TG, đơn vị và ngày lấy mẫu;
- tiền sử bệnh tim mạch xơ vữa/nguy cơ tim mạch đã được bác sĩ đánh giá;
- tuổi, giới, chiều cao, cân nặng, diễn tiến cân nặng và mức hoạt động;
- T2D, tăng huyết áp, bệnh thận, gan, tuyến giáp và tình trạng dinh dưỡng;
- thuốc đang dùng, dị ứng, đường nuôi ăn và tình trạng nuốt.

### 4.3. Constraint và giới hạn tự động hóa

| Mục | Thiết kế |
| --- | --- |
| Keys | `energy_kcal`, `fat_g`, `saturated_fat_g`, `trans_fat_g`, `cholesterol_mg`, `fiber_g`, `free_sugar_g`, `sodium_mg` |
| Loại | daily range/min/max; riêng saturated/trans/free sugar cần `% năng lượng` hoặc giá trị tuyệt đối dẫn xuất từ mục tiêu năng lượng đã duyệt |
| Hard block | kiểu bệnh không rõ; tăng TG nặng hoặc có nguy cơ viêm tụy; rối loạn lipid gia đình; CKD; sụt cân/suy dinh dưỡng; thuốc chưa phân tích; thiếu mục tiêu năng lượng khi rule dùng `% năng lượng` |
| Được phép sau gate | xếp hạng/loại món theo constraint đã duyệt cho đúng kiểu bệnh |
| Chưa được phép | tự đặt mục tiêu LDL/TG, thay thuốc, hoặc dùng một bộ rule chung cho mọi rối loạn lipid |

Đây là bệnh gần engine hiện tại nhất, nhưng catalog đang thiếu ba dữ liệu quyết định: `saturated_fat_g`, `trans_fat_g`, `cholesterol_mg`. Không phát hành bằng cách dùng tổng `fat_g` thay thế ba trường này.

## 5. Đái tháo đường type 2

### 5.1. Bằng chứng và cách diễn giải

[Cục Quản lý Khám, chữa bệnh](https://daithaoduong.kcb.vn/huong-dan-chan-doan-va-dieu-tri-dai-thao-duong-tip-2) đăng Hướng dẫn chẩn đoán và điều trị đái tháo đường type 2 theo Quyết định 5481/QĐ-BYT ngày 30/12/2020 và bản sửa đổi theo Quyết định 1353/QĐ-BYT ngày 23/02/2021. Đây phải là nguồn lâm sàng gốc mà người duyệt dùng khi khóa rule.

[Hướng dẫn Bộ Y tế năm 2017](https://daithaoduong.kcb.vn/upload/files/HD-chan-doan-dieu-tri-DTD-2017_07_19-Approved%20%281%29.pdf) mô tả chế độ ăn cần linh hoạt theo tập quán, thực phẩm địa phương, mức hoạt động, bệnh kèm và biến chứng; tư vấn tốt nhất bởi chuyên gia dinh dưỡng. Tài liệu cũ này chỉ dùng để xác định dữ liệu cần thu thập, không dùng để thay thế bản 2020/2021 khi phát hành.

[Cục KCB về hạ đường huyết](https://daithaoduong.kcb.vn/ha-duong-huyet-tren-benh-nhan-dai-thao-duong-cap-nhat-dinh-nghia-phan-loai-theo-hoi-dai-thao-duong-hoa-ky-2022) ghi nhận insulin, sulfonylurea và glinide làm tăng nguy cơ; bỏ bữa/ăn ít carbohydrate, rượu, suy thận hoặc gan, vận động và sụt cân đều có thể làm thay đổi nguy cơ. Do đó khoảng carbohydrate theo bữa không được tạo mà thiếu thuốc và lịch bữa.

### 5.2. Profile bắt buộc

- chẩn đoán T2D, mục tiêu do bác sĩ kê và giai đoạn điều trị;
- chiều cao, cân nặng, BMI, diễn tiến cân nặng, tuổi, giới và mức hoạt động;
- mục tiêu năng lượng/ngày và carbohydrate/ngày hoặc theo bữa đã được duyệt;
- lịch bữa, khả năng ăn hết suất, thời điểm vận động;
- hoạt chất, liều và lịch dùng insulin/sulfonylurea/glinide và các thuốc liên quan;
- HbA1c, glucose đói/sau ăn khi được dùng trong policy, kèm đơn vị và ngày;
- tiền sử hạ đường huyết, hạ đường huyết nặng hoặc không nhận biết;
- eGFR/bệnh thận, bệnh gan, tình trạng nuốt và đường nuôi ăn.

### 5.3. Constraint và giới hạn tự động hóa

| Mục | Thiết kế |
| --- | --- |
| Keys | `energy_kcal`, `carbohydrate_g`, `fiber_g`, `free_sugar_g`, `protein_g` |
| Loại | daily energy range; daily carbohydrate range; meal carbohydrate range theo `mealType`; daily fiber min; protein `/kg` chỉ khi thận đã được đánh giá |
| Hard block | insulin/SU/glinide chưa có lịch; hạ đường huyết nặng/tái diễn; CKD; thai kỳ; bệnh cấp; đường nuôi ăn; rối loạn nuốt; không có mục tiêu năng lượng/carbohydrate cá thể |
| Được phép sau gate | chọn và đổi bữa trong khoảng tuyệt đối do chuyên gia đã nhập |
| Chưa được phép | tự tính liều insulin, tự giảm carbohydrate khi có hạ đường huyết, tự đặt số gram carbohydrate/bữa hoặc mục tiêu đường huyết |

Schema v2 đã biểu diễn được range năng lượng/carbohydrate theo ngày và từng bữa. Phần còn thiếu là **nguồn tạo mục tiêu cá thể**, không phải cú pháp constraint. Nghiên cứu chưa tìm được trong nguồn Việt Nam hiện hành một số gram carbohydrate/bữa áp dụng an toàn cho mọi người; vì vậy không seed một ngưỡng chung.

## 6. Béo phì ở người cao tuổi

### 6.1. Bằng chứng và cách diễn giải

[Cục KCB công bố Hướng dẫn chẩn đoán và điều trị bệnh béo phì](https://daithaoduong.kcb.vn/huong-dan-chan-doan-va-dieu-tri-benh-beo-phi%26p%3D8) theo Quyết định 2892/QĐ-BYT ngày 22/10/2022, áp dụng trên toàn quốc. Rule phát hành phải được chuyên gia đối chiếu trực tiếp với tài liệu này.

[ESPEN practical guideline về dinh dưỡng và bù dịch trong lão khoa](https://2022.espen.org/files/ESPEN-Guidelines/ESPEN_practical_guideline_Clinical_nutrition_and_hydration_in_geriatrics.pdf) nhấn mạnh nhu cầu năng lượng và protein phải cá thể hóa; giảm cân ở người cao tuổi béo phì phải đi cùng bảo vệ khối cơ, bổ sung đủ vi chất và vận động, đồng thời tránh giảm cân ở người suy dinh dưỡng hoặc nguy cơ suy dinh dưỡng. Nguồn này giải thích vì sao không thể lấy BMI rồi tự giảm năng lượng.

### 6.2. Profile bắt buộc

- chiều cao đo được, cân nặng hiện tại, vòng eo, diễn tiến cân nặng và cân nặng mục tiêu/đơn chuyên môn;
- tuổi, giới, mức hoạt động, khả năng vận động và chương trình vận động;
- sàng lọc suy dinh dưỡng, khẩu phần hiện tại, sụt cân ngoài ý muốn;
- sức cơ, khối cơ/đánh giá thiểu cơ và frailty khi chính sách yêu cầu;
- T2D, bệnh tim mạch, CKD, suy tim, ung thư và thuốc ảnh hưởng cân nặng/khẩu vị;
- khả năng nhai nuốt và mức hỗ trợ ăn uống.

### 6.3. Constraint và giới hạn tự động hóa

| Mục | Thiết kế |
| --- | --- |
| Keys | `energy_kcal`, `protein_g`, `fiber_g` và bộ vi chất đầy đủ của thực đơn |
| Loại | energy daily range theo đơn; protein `per_kg_daily` minimum/range; không dùng “BMI → calories” như rule duy nhất |
| Hard block | sụt cân ngoài ý muốn; suy dinh dưỡng/nguy cơ; thiểu cơ/frailty; CKD; suy tim; ung thư; bệnh cấp; không có cân nặng và mục tiêu còn hiệu lực |
| Được phép sau gate | lập thực đơn trong khoảng năng lượng/protein đã được chuyên gia duyệt và theo dõi cân nặng định kỳ |
| Chưa được phép | tự kê mức thâm hụt năng lượng, tự đặt tốc độ giảm cân hoặc tạo thực đơn giảm cân cho người cao tuổi chưa sàng lọc cơ và dinh dưỡng |

## 7. Loãng xương

### 7.1. Bằng chứng và cách diễn giải

[Hướng dẫn chẩn đoán và điều trị các bệnh cơ xương khớp của Bộ Y tế](https://kcb.vn/upload/2005611/20210723//HD%C4%90T-C%C6%A1-X%C6%B0%C6%A1ng-Kh%E1%BB%9Bp.pdf) (Quyết định 361/QĐ-BYT năm 2014) nêu tổng calcium từ thức ăn, sữa và thuốc, cùng vitamin D, trong điều trị loãng xương. Vì tài liệu đã cũ và gộp thức ăn với chế phẩm/thuốc, các con số trong đó chỉ là ứng viên để bác sĩ/chuyên gia cập nhật, không seed thẳng vào catalog món.

[NIH Office of Dietary Supplements về calcium](https://ods.od.nih.gov/factsheets/Calcium-HealthProfessional/) mô tả nguy cơ khi bổ sung quá mức, tương tác và giới hạn tổng lượng nhận; [tài liệu vitamin D](https://ods.od.nih.gov/factsheets/VitaminD-HealthProfessional/) mô tả nguy cơ độc tính, tăng calcium máu và tổn thương thận. Đây là căn cứ tách “gợi ý món ăn” khỏi “kê thực phẩm bổ sung”.

### 7.2. Profile bắt buộc

- chẩn đoán loãng xương, DXA/gãy xương nếu được dùng để phân tầng, tuổi, giới và mãn kinh;
- ước lượng calcium và vitamin D hiện nhận từ thức ăn, sữa/ONS, supplement và thuốc;
- đơn bổ sung hiện tại, 25-OH vitamin D/calcium máu nếu chuyên gia dùng trong mục tiêu;
- eGFR/bệnh thận, tiền sử sỏi thận, tăng calcium máu hoặc bệnh cận giáp;
- glucocorticoid, bisphosphonate và thuốc liên quan; khả năng nuốt và tư thế dùng thuốc;
- năng lượng/protein và tình trạng suy dinh dưỡng.

### 7.3. Constraint và giới hạn tự động hóa

| Mục | Thiết kế |
| --- | --- |
| Keys | `calcium_mg`, `vitamin_d_ug`, `protein_g`, `energy_kcal` |
| Loại | daily range trên tổng nguồn; clinician order; cần phép cộng thức ăn + supplement/ONS/thuốc |
| Hard block | CKD; sỏi thận; tăng calcium máu; liều bổ sung/thuốc không rõ; không tính được tổng nguồn; rối loạn nuốt ảnh hưởng dùng thuốc |
| Được phép sau gate | chọn món giàu calcium/vitamin D trong phần còn lại của mục tiêu tổng đã được duyệt |
| Chưa được phép | tự kê liều vitamin D/calcium, thay đổi thuốc loãng xương, hoặc cộng mục tiêu thức ăn lên trên supplement hiện có |

## 8. Gout

### 8.1. Bằng chứng và cách diễn giải

[Hướng dẫn cơ xương khớp của Bộ Y tế năm 2014](https://kcb.vn/upload/2005611/20210723//HD%C4%90T-C%C6%A1-X%C6%B0%C6%A1ng-Kh%E1%BB%9Bp.pdf) khuyên tránh nhóm thực phẩm nhiều purine, hạn chế rượu và có hướng dẫn về thịt/nước. Không tự động hóa các con số này vì tài liệu đã cũ và mức nước có thể không an toàn khi người bệnh đồng thời suy tim, CKD hoặc có chỉ định hạn chế dịch.

[American College of Rheumatology 2020 guideline for gout](https://rheumatology.org/Portals/0/Files/Gout-Guideline-Final-2020.pdf) chỉ đưa các khuyến nghị có điều kiện về hạn chế rượu, purine, high-fructose corn syrup và giảm cân khi phù hợp; chất lượng bằng chứng cho thay đổi khẩu phần thấp hoặc rất thấp, và tác động của chế độ ăn lên urate thường nhỏ. Nguồn này không tạo ra một ngưỡng `purine_mg/day` phổ quát cho engine.

### 8.2. Profile bắt buộc

- chẩn đoán gout đã xác nhận hay chỉ tăng acid uric máu; đang trong cơn hay ổn định; tophi;
- urate huyết thanh có đơn vị/ngày và mục tiêu điều trị do bác sĩ đặt;
- eGFR/CKD, sỏi tiết niệu, suy tim và chỉ định dịch;
- thuốc hạ urate, thuốc điều trị cơn, lợi tiểu và các thuốc liên quan;
- rượu, đồ uống có đường/fructose, nguồn đạm, cân nặng và diễn tiến cân nặng;
- dị ứng, đường nuôi ăn và khả năng nuốt.

### 8.3. Constraint và giới hạn tự động hóa

| Mục | Thiết kế |
| --- | --- |
| Keys | tương lai: `purine_mg`; hiện tại: `alcohol_g`, `free_sugar_g` và tag nguồn đạm/nguyên liệu |
| Loại | ingredient/category block hoặc clinician order; chưa có numeric purine max |
| Hard block | cơn gout cấp; CKD; sỏi; suy tim/hạn chế dịch; thuốc chưa đủ; catalog không có dữ liệu purine có provenance |
| Được phép sau gate | lọc nhóm nguyên liệu theo policy đã duyệt, không tuyên bố thay thế điều trị urate |
| Chưa được phép | đặt mục tiêu urate, thay thuốc, ép uống một lượng nước cố định, hoặc dùng ngưỡng purine số không có nguồn dữ liệu được duyệt |

## 9. Các nhóm phải chuyển chuyên gia

### 9.1. Suy dinh dưỡng

[WHO về oral supplemental nutrition ở người cao tuổi](https://www.who.int/tools/elena/interventions/nutrition-older-people) yêu cầu sản phẩm bổ sung năng lượng/protein/vi chất được điều chỉnh theo nhu cầu cá thể do nhân viên được đào tạo đánh giá. [WHO ICOPE](https://www.ncbi.nlm.nih.gov/books/NBK488257/) yêu cầu chuyển khám khi có suy mòn rõ, sụt cân nhanh, tắc nghẽn/khó nuốt, nôn, tiêu chảy kéo dài hoặc triệu chứng bụng đáng kể.

Hồ sơ cần sàng lọc dinh dưỡng đã chuẩn hóa, tỷ lệ và thời gian sụt cân, lượng ăn so với nhu cầu, khẩu vị, triệu chứng tiêu hóa, viêm/bệnh cấp, nguy cơ refeeding, nuốt/đường nuôi ăn và chức năng thận. Constraint có thể là `energy_kcal` `/kg`, `protein_g` `/kg`, vi chất và route, nhưng phải do chuyên gia kê. Sụt cân nhanh, cachexia, khó nuốt hoặc nguy cơ refeeding là hard block.

### 9.2. Thiểu cơ

[EWGSOP2 consensus](https://academic.oup.com/ageing/article/48/4/601/5488778) dùng sức cơ, số lượng/chất lượng cơ và hoạt động thể lực để xác định/đánh giá mức độ sarcopenia; không thể suy ra chỉ từ tuổi hoặc BMI. Vì can thiệp dinh dưỡng cần phối hợp vận động và protein còn phụ thuộc chức năng thận, CareSitter chỉ nhận mục tiêu `protein_g` `/kg` từ chuyên gia sau đánh giá sức cơ, khối cơ, hiệu năng, khẩu phần và eGFR.

### 9.3. Bệnh thận mạn

[Hướng dẫn chẩn đoán và điều trị bệnh thận mạn và một số bệnh lý thận năm 2024 của Bộ Y tế](https://kcb.vn/upload/2005611/20240826/QD_ban_hanh_HD_chan_doan__dieu_tri_benh_than_man_va_mot_so_benh_ly_than__2024_08_12_f0584.pdf) quy định năng lượng và protein khác nhau theo giai đoạn, lọc máu, tuổi, giới, hoạt động, thành phần cơ thể, cân nặng mục tiêu, bệnh kèm và viêm; thay đổi phải thận trọng khi có suy dinh dưỡng. Potassium, phosphorus, sodium và dịch còn phụ thuộc xét nghiệm, triệu chứng, nước tiểu, điện tim và chỉ định điều trị.

Profile tối thiểu gồm stage/eGFR và ngày, lọc máu/phương thức, cân nặng khô, nước tiểu, potassium/phosphorus/calcium/bicarbonate, albumin và tình trạng protein-energy wasting, phù/hạn chế dịch, thuốc. Keys là `energy_kcal` `/kg`, `protein_g` `/kg`, `sodium_mg`, `potassium_mg`, `phosphorus_mg`, `fluid_ml`; tất cả phải là clinician order có thời hạn. Đây là hard block cấp bệnh, không chỉ là một daily maximum.

### 9.4. Suy tim

[Hướng dẫn chẩn đoán và điều trị suy tim mạn tính của Bộ Y tế](https://kcb.vn/upload/2005611/20210723/QD-1762-Ban-h%C3%A0nh-H%C6%B0%E1%BB%9Bng-d%E1%BA%ABn-ch%E1%BA%A9n-%C4%91o%C3%A1n-v%C3%A0-%C4%91i%E1%BB%81u-tr%E1%BB%8B-suy-tim-m%E1%BA%A1n-t%C3%ADnh.pdf) và [Hướng dẫn thực hành dược lâm sàng của Bộ Y tế](https://kcb.vn/upload/2005611/20210723/H%C6%B0%E1%BB%9Bng-d%E1%BA%ABn-th%E1%BB%B1c-h%C3%A0nh-d%C6%B0%E1%BB%A3c-l%C3%A2m-s%C3%A0ng-cho-D%C6%B0%E1%BB%A3c-s%C4%A9-trong-m%E1%BB%99t-s%E1%BB%91-b%E1%BB%87nh-kh%C3%B4ng-l%C3%A2y-nhi%E1%BB%85m.pdf) cho thấy xử trí dịch và sodium thay đổi theo mức độ, triệu chứng và điều trị; không phải mọi người bệnh đều dùng cùng một giới hạn dịch.

Profile cần loại/giai đoạn suy tim, NYHA, phù/ứ dịch, diễn tiến cân nặng hằng ngày, đơn sodium/dịch, huyết áp, chức năng thận, điện giải, thuốc lợi tiểu và lượng ăn. `sodium_mg` và `fluid_ml` chỉ chạy theo đơn bác sĩ; mất bù, tăng/giảm potassium, CKD hoặc thay đổi lợi tiểu là hard block.

### 9.5. Ung thư

[ESPEN practical guideline: Clinical Nutrition in Cancer](https://www.espen.org/files/ESPEN-Guidelines/ESPEN-practical-guideline-clinical-nutrition-in-cancer.pdf) yêu cầu đánh giá định kỳ lượng ăn, cân nặng và BMI; khi bất thường phải đánh giá triệu chứng ảnh hưởng dinh dưỡng, khối cơ, hoạt động và viêm. Can thiệp phụ thuộc vị trí/giai đoạn ung thư, điều trị, triệu chứng, mục tiêu chăm sóc và có nguy cơ refeeding; khó nuốt cần được đánh giá/chăm sóc chuyên môn.

Profile cần ung thư/vị trí/giai đoạn, pha điều trị và độc tính, tiên lượng/mục tiêu chăm sóc, diễn tiến cân nặng và lượng ăn, khối cơ/chức năng/viêm, triệu chứng, nuốt/đường nuôi, điện giải, thận/gan và thuốc. Năng lượng/protein `/kg`, ONS, enteral hoặc parenteral là đơn chuyên môn. Cachexia, nguy cơ refeeding, tắc nghẽn, nôn/tiêu chảy nặng và dysphagia là hard block.

### 9.6. Đột quỵ

[Quy trình kỹ thuật chuyên ngành Thần kinh của Bộ Y tế](https://kcb.vn/upload/2005611/20210723/ae09fc64a8f38b3fbf8e3228fa57da12Huong-dan-QTKT-Than-Kinh.pdf) yêu cầu sàng lọc nuốt ở người bệnh đột quỵ trước khi cho thức ăn, nước hoặc thuốc đường miệng nhằm giảm hít sặc, viêm phổi và suy dinh dưỡng. [AHA/ASA 2026 Guideline for Early Management of Acute Ischemic Stroke](https://www.ahajournals.org/doi/10.1161/STR.0000000000000513) tiếp tục đặt sàng lọc dysphagia trước oral intake và dùng kết quả để hướng dẫn quản lý dinh dưỡng.

Profile cần pha cấp hay phục hồi, đánh giá nuốt có ngày/kết quả, texture và liquid thickness được kê, đường nuôi ăn, tiền sử hít sặc, khả năng tự ăn, tình trạng dinh dưỡng/dịch, bệnh kèm và thuốc. Nếu chưa có đánh giá nuốt hợp lệ thì hard block toàn bộ thực đơn đường miệng. Engine còn cần hỗ trợ texture/độ đặc; tổng dưỡng chất đúng không đồng nghĩa món an toàn để nuốt.

## 10. Trình tự triển khai đề xuất

1. **Khóa nền dữ liệu:** thêm nhân trắc, xét nghiệm có đơn vị/ngày, medication schedule, clinician order có hiệu lực và nguồn dữ liệu. Thêm các nutrient keys ở mục 3.2 nhưng chưa gán rule phát hành.
2. **Mở rộng engine:** giữ daily/meal min-max v2; bổ sung `% energy`, `/kg/day`, clinician-order reference, rule theo điều kiện và tổng nguồn thức ăn + supplement/ONS. Mọi phép quy đổi phải trả về explanation và provenance.
3. **Rối loạn lipid máu:** thu thập saturated/trans/cholesterol cho 12 món và các món kế tiếp; khóa subtype; duyệt nguồn/ngưỡng; test thiếu lipid panel, CKD, thuốc và suy dinh dưỡng trước khi phát hành.
4. **T2D:** chỉ sau khi profile có mục tiêu năng lượng/carbohydrate cá thể và lịch thuốc/bữa. Dùng range theo bữa mà schema v2 đã hỗ trợ; không tạo ngưỡng chung.
5. **Béo phì:** dùng chung nền energy target với T2D, thêm nhân trắc và sàng lọc cơ/suy dinh dưỡng; người cao tuổi chỉ đủ điều kiện khi có mục tiêu đã duyệt.
6. **Loãng xương:** thêm calcium/vitamin D với provenance và tổng nguồn; chỉ hỗ trợ lựa chọn món, không kê supplement.
7. **Gout:** xây nguồn purine được thẩm định và policy bệnh kèm trước; nếu chưa có, giữ `needs_professional_guidance`.
8. **Sáu nhóm phức tạp:** giữ hard block. Có thể cho hệ thống thực thi đơn chuyên môn có cấu trúc, nhưng không tự sinh mục tiêu điều trị.

## 11. Gate bắt buộc trước khi đổi trạng thái sang supported

- nguồn gốc là văn bản còn hiệu lực hoặc guideline chuyên ngành chính thức; URL, phiên bản, ngày truy cập và phạm vi được đăng ký;
- mỗi claim/ngưỡng được bác sĩ hoặc chuyên gia dinh dưỡng được chỉ định duyệt;
- nutrient catalog có đơn vị, serving size, phương pháp/nguồn và kiểm tra thiếu dữ liệu;
- profile prerequisite đầy đủ và có chính sách thời hạn cho cân nặng, xét nghiệm, đơn chuyên môn;
- engine biểu diễn đúng loại constraint, không quy đổi im lặng;
- test có ca thiếu thông tin, xung đột bệnh, thuốc, CKD, suy dinh dưỡng, dị ứng và nuốt;
- API trả `needs_information` hoặc `needs_professional_guidance` khi thiếu gate, không trả thực đơn “gần đúng”;
- audit log lưu rule version, nguồn, người duyệt, dữ liệu đầu vào và lý do chọn/loại từng món.

## 12. Đăng ký nguồn chính

| Nguồn | Cơ quan/năm | Dùng cho | Giới hạn sử dụng |
| --- | --- | --- | --- |
| [Khuyến nghị dinh dưỡng cho người Việt Nam 2026](https://viendinhduong.vn/vi/article/tin-tuc/6a70094d06fb0c475f0ac123) | Viện Dinh dưỡng Quốc gia, 2026 | nền nhu cầu, keys, yêu cầu cá thể hóa | tham chiếu dân số; không thay đơn điều trị |
| [Giải pháp ăn uống cho người rối loạn lipid máu](https://viendinhduong.vn/vi/article/tin-tuc/giai-phap-an-uong-khoa-hoc-cho-nguoi-bi-roi-loan-lipid-mau-688356d770185b05a6022336) | Viện Dinh dưỡng Quốc gia, 2025 | lipid keys và ứng viên constraint | mã QĐ được bài dẫn chưa xác minh bản gốc; cần clinical review |
| [Hướng dẫn T2D](https://daithaoduong.kcb.vn/huong-dan-chan-doan-va-dieu-tri-dai-thao-duong-tip-2) | Bộ Y tế/Cục KCB, 2020–2021 | nguồn lâm sàng T2D | phải đối chiếu file gốc khi khóa rule |
| [Hạ đường huyết ở người bệnh đái tháo đường](https://daithaoduong.kcb.vn/ha-duong-huyet-tren-benh-nhan-dai-thao-duong-cap-nhat-dinh-nghia-phan-loai-theo-hoi-dai-thao-duong-hoa-ky-2022) | Cục KCB | medication/meal hard block | không cung cấp mục tiêu carb cá thể |
| [Hướng dẫn béo phì](https://daithaoduong.kcb.vn/huong-dan-chan-doan-va-dieu-tri-benh-beo-phi%26p%3D8) | Bộ Y tế/Cục KCB, 2022 | nguồn lâm sàng béo phì | cần reviewer trích chính xác rule phát hành |
| [ESPEN geriatrics](https://2022.espen.org/files/ESPEN-Guidelines/ESPEN_practical_guideline_Clinical_nutrition_and_hydration_in_geriatrics.pdf) | ESPEN, 2022 | an toàn giảm cân, protein/năng lượng người cao tuổi | guideline quốc tế; dùng khi nguồn Việt Nam chưa đủ chi tiết |
| [Hướng dẫn cơ xương khớp](https://kcb.vn/upload/2005611/20210723//HD%C4%90T-C%C6%A1-X%C6%B0%C6%A1ng-Kh%E1%BB%9Bp.pdf) | Bộ Y tế, 2014 | osteoporosis và gout | cũ; không dùng ngưỡng số tự động nếu chưa cập nhật/duyệt |
| [ACR Gout Guideline](https://rheumatology.org/Portals/0/Files/Gout-Guideline-Final-2020.pdf) | ACR, 2020 | mức bằng chứng cho diet ở gout | không có universal numeric purine limit |
| [Hướng dẫn bệnh thận](https://kcb.vn/upload/2005611/20240826/QD_ban_hanh_HD_chan_doan__dieu_tri_benh_than_man_va_mot_so_benh_ly_than__2024_08_12_f0584.pdf) | Bộ Y tế, 2024 | lý do chuyển chuyên gia, CKD keys | mục tiêu thay đổi theo stage/dialysis/lab |
| [Hướng dẫn suy tim mạn](https://kcb.vn/upload/2005611/20210723/QD-1762-Ban-h%C3%A0nh-H%C6%B0%E1%BB%9Bng-d%E1%BA%ABn-ch%E1%BA%A9n-%C4%91o%C3%A1n-v%C3%A0-%C4%91i%E1%BB%81u-tr%E1%BB%8B-suy-tim-m%E1%BA%A1n-t%C3%ADnh.pdf) | Bộ Y tế, 2020 | fluid/sodium cần theo mức độ | không seed một fluid limit chung |
| [ESPEN Cancer](https://www.espen.org/files/ESPEN-Guidelines/ESPEN-practical-guideline-clinical-nutrition-in-cancer.pdf) | ESPEN, 2021 | screening, cachexia/refeeding/route | cần phối hợp nhóm ung thư |
| [WHO Nutrition for older people](https://www.who.int/tools/elena/interventions/nutrition-older-people) | WHO | ONS và đánh giá cá thể | không phải đơn điều trị cá nhân |
| [EWGSOP2](https://academic.oup.com/ageing/article/48/4/601/5488778) | European Working Group, 2019 | tiêu chí đánh giá sarcopenia | cần công cụ/nhân sự đánh giá cơ và chức năng |
| [Quy trình kỹ thuật Thần kinh](https://kcb.vn/upload/2005611/20210723/ae09fc64a8f38b3fbf8e3228fa57da12Huong-dan-QTKT-Than-Kinh.pdf) | Bộ Y tế | swallow screen sau đột quỵ | cần kết quả đánh giá và prescription texture |

## 13. Quyết định an toàn cần giữ trong code và nội dung

- Không suy bệnh hoặc mức độ bệnh chỉ từ ghi chú tự do.
- Không coi xét nghiệm không có đơn vị/ngày là prerequisite hợp lệ.
- Không thay thế nutrient thiếu bằng nutrient gần giống, ví dụ tổng fat thay saturated fat hoặc đường tổng thay free sugar.
- Không áp rule `/kg` nếu không biết loại cân nặng và thời điểm đo.
- Không cộng món ăn mà bỏ qua ONS, supplement hoặc thuốc khi constraint yêu cầu tổng nguồn.
- Không đưa lời khuyên uống nước cố định cho gout khi chưa loại trừ CKD/suy tim/hạn chế dịch.
- Không sinh món đường miệng cho người sau đột quỵ khi chưa có đánh giá nuốt hợp lệ.
- Không tự kê mục tiêu điều trị, liều bổ sung hoặc thay đổi thuốc.

Với các giới hạn trên, hướng mở rộng an toàn là: **rối loạn lipid máu trước; T2D và béo phì sau khi có mục tiêu cá thể; loãng xương sau khi tính tổng nguồn; gout sau khi có dữ liệu purine/policy; các nhóm phức tạp tiếp tục chuyển chuyên gia**.
