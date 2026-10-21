# Gợi ý thực đơn từ mô tả sức khỏe người thân

Cập nhật: 11/10/2026, Asia/Saigon. Nutrition đã có service .NET 8, DB và Docker riêng, tích hợp People qua HTTP và UI customer; đã kiểm thử local. AI vẫn là adapter chưa cấu hình, chưa import công thức/quy tắc đã duyệt thực và chưa bật môi trường thật. Dùng hồ sơ hiện hữu của từng người thân hoặc bản thân, chỉ bổ sung thông tin thiếu. [Runbook hiện hành](../backend/NUTRITION_SERVICE_RUNBOOK.md) mô tả source/API thực tế; các mục mở rộng dưới đây tiếp tục là thiết kế.

Tài liệu đi kèm: [Đặc tả phân tích dữ liệu đầu vào](../backend/NUTRITION_ANALYSIS_SPEC.md), gồm phương pháp kết hợp AI/quy tắc, cấu trúc dữ kiện, ví dụ phân tích, xử lý mâu thuẫn, prompt, đánh giá chất lượng và riêng tư.

Các quyết định kiến trúc và giới hạn kỹ thuật dưới đây là đề xuất triển khai. Một ngày/sáng–trưa–tối là phạm vi MVP đề xuất; nhà cung cấp AI, chuyên môn kiểm duyệt nội dung, chính sách lưu dữ liệu và quy mô danh mục món chưa được chốt.

## 1. Phạm vi đã thống nhất

- Tái sử dụng hồ sơ Beneficiary hiện có. Customer chọn một người thân; Nutrition đọc dữ liệu của đúng beneficiaryId, không tạo hồ sơ người thân thứ hai hoặc yêu cầu nhập lại thông tin đã lưu.
- Mô tả/lưu ý hiện có bằng tiếng Việt là một phần đầu vào; customer bổ sung hoặc cập nhật trong chính hồ sơ đó khi thiếu. Không bắt chọn bệnh từ một danh sách cố định.
- Customer xem gợi ý và tự chọn món. Phiên bản đầu chưa gửi thực đơn cho caregiver hoặc gắn thực đơn vào booking.
- Tính năng hỗ trợ lựa chọn bữa ăn. Không chẩn đoán bệnh, kê chế độ điều trị, đổi thuốc hoặc cam kết kết quả sức khỏe.
- Đề xuất cho bản đầu: một ngày, chia sáng/trưa/tối, có đổi món và lưu lựa chọn. Thực đơn tuần là bước mở rộng, chưa phải phạm vi được người dùng xác nhận.

## 2. Những gì đã có trong source

- `People/Domain/Beneficiary.cs` có `HealthHistory`, `Allergies`, `ChronicConditions`, `Medications`, `GeneralNote` và `CareInstructions`.
- `BeneficiaryUpsertRequest` và `BeneficiaryResponse` đã chứa các trường sức khỏe dạng JSON.
- Customer `BeneficiaryModel` hiện chỉ có `condition` và `notes`, chưa ánh xạ đầy đủ bệnh nền/dị ứng/thuốc.
- `BeneficiaryStore` đang lưu `condition` vào `GeneralNote`; thông tin này là ghi chú tự do, không phải chẩn đoán đã xác minh.
- Form tạo/sửa người thân đã có “Nhu cầu hỗ trợ / Lưu ý” và ghi chú; các tag được nối thành `condition` rồi lưu vào `GeneralNote`, ghi chú lưu vào `CareInstructions`. Đây là dữ liệu có sẵn cần tận dụng trước khi thêm bất kỳ trường nhập mới nào.
- Controller hiện cập nhật hồ sơ bằng PUT với các trường sức khỏe nullable. Cần bảo toàn dữ liệu hiện hữu khi bổ sung form; không để thao tác sửa thông tin cơ bản làm mất các trường sức khỏe chưa được app ánh xạ.
- `BeneficiaryDetailScreen` dùng fallback sang phần tử đầu nếu không tìm thấy ID. Luồng thực đơn phải đọc đúng ID từ backend và hiển thị không tìm thấy; không gợi ý cho một người thân khác.
- `_fromBackend` đang mặc định tuổi 70 khi thiếu ngày sinh và dùng “Bình thường” khi thiếu ghi chú. Bộ phân tích phải đọc snapshot server với trạng thái thiếu dữ liệu, không coi các giá trị hiển thị này là sự thật sức khỏe.
- Backend đã có Hangfire, audit và kiểm tra cấu hình storage PostgreSQL cho production. Có thể tái sử dụng hạ tầng này, nhưng trạng thái phân tích cần lưu bền vững; không đưa mô tả sức khỏe vào tham số job hoặc dashboard.

## 3. Luồng customer

1. Mở **Người thân → Chi tiết → Gợi ý bữa ăn**. Hiển thị tên người thân để tránh chọn nhầm.
2. Đọc snapshot hồ sơ đã lưu và hiển thị thông tin nguồn: lưu ý, ghi chú, lịch sử sức khỏe, dị ứng/bệnh nền/thuốc nếu có. Không bắt customer viết lại toàn bộ mô tả.
3. Bổ sung ngắn gọn những mục còn thiếu hoặc cần cập nhật trong chính hồ sơ: dị ứng thực phẩm, thực phẩm cần tránh, sở thích và chỉ định ăn uống hiện có. Dị ứng có ba trạng thái: có, đã xác nhận không có, chưa rõ; không mặc định mảng rỗng là không có dị ứng.
4. Hệ thống tóm tắt nội dung: bệnh được gia đình báo cáo, nhu cầu ăn uống và thông tin còn thiếu. Customer sửa hoặc xác nhận rằng bản tóm tắt phản ánh đúng nội dung họ cung cấp.
5. Nếu đủ dữ liệu và có quy tắc được kiểm duyệt, hiển thị gợi ý sáng/trưa/tối. Nếu còn thiếu, chỉ hỏi các thông tin ảnh hưởng trực tiếp đến lựa chọn món.
6. Mỗi món có thành phần, khẩu phần theo công thức, cách chế biến, dữ liệu dinh dưỡng có nguồn và lý do được chọn. Customer đổi món hoặc lưu thực đơn.
7. Khi mô tả/dị ứng thay đổi, thực đơn cũ có trạng thái **Cần kiểm tra lại**. Kiểm tra lại toàn bộ ràng buộc trước khi lưu hoặc sử dụng tiếp.

Ví dụ mô tả để kiểm thử ngôn ngữ, không phải chỉ định ăn uống:

> Mẹ tôi 72 tuổi, gia đình được bác sĩ thông báo có tiểu đường và tăng huyết áp. Bác sĩ dặn giảm muối. Mẹ dị ứng tôm và không thích đồ chiên.

Tóm tắt cần phân biệt rõ: bệnh do gia đình báo cáo, chỉ định được gia đình nhập, dị ứng tôm và sở thích. Customer xác nhận nội dung không biến thông tin đó thành hồ sơ đã được bác sĩ xác minh.

## 4. Vai trò của AI và bộ lọc thực đơn

AI dùng để đọc mô tả tự do, trích xuất dữ kiện được nêu rõ và đặt câu hỏi làm rõ. AI không tự tạo định mức dinh dưỡng hoặc chẩn đoán từ triệu chứng.

```text
Hồ sơ người thân đã chọn + thông tin customer bổ sung khi cần
  → kiểm tra quyền sở hữu và dữ liệu đầu vào
  → chuẩn hóa trường cấu trúc; AI đọc lưu ý/ghi chú và giữ đoạn nguồn
  → customer kiểm tra bản tóm tắt
  → xác định quy tắc dinh dưỡng có thể áp dụng
  → lọc công thức đã kiểm duyệt bằng ràng buộc bắt buộc
  → xếp hạng theo sở thích, đa dạng và khả năng chuẩn bị
  → customer chọn, đổi món và lưu
```

- Giữ nguyên phủ định, thời điểm và mức độ chưa chắc chắn: “không bị”, “đã từng”, “đang nghi”, “chưa khám”. Không biến câu “đang nghi tiểu đường” thành chẩn đoán tiểu đường.
- Dữ liệu trích xuất có đoạn nguồn; assertion `present/absent/uncertain`, temporality `current/past/unknown` và reportingBasis riêng; thêm người xác nhận, thời điểm và phiên bản ở server. Không dùng một điểm confidence của AI để chứng nhận an toàn y khoa.
- Nội dung mô tả là dữ liệu không tin cậy; câu “bỏ qua dị ứng” hoặc yêu cầu trong văn bản không được thay đổi chính sách hệ thống.
- Bệnh/tình trạng chưa hỗ trợ trả **Cần thêm hướng dẫn chuyên môn**. Không gán quy tắc cho một bệnh khác hoặc đưa món ngẫu nhiên với nhãn “phù hợp bệnh lý”.
- Bộ lọc chạy ở backend. Frontend không tự phát sinh món, thành phần hay dữ liệu dinh dưỡng.
- Dị ứng, nguyên liệu cần tránh và hạn chế được áp dụng trước khi xếp hạng sở thích. Nguyên liệu thiếu thông tin dị ứng không được coi là an toàn.
- Khi nhiều hạn chế mâu thuẫn hoặc không còn công thức đáp ứng, trả **Chưa tìm được thực đơn đáp ứng các yêu cầu**. Không tự bỏ một hạn chế để có kết quả.
- Đổi một món phải kiểm tra lại cả thực đơn theo phạm vi quy tắc, không chỉ kiểm tra riêng món thay thế.

## 5. Dữ liệu cần bổ sung

| Nhóm | Dữ liệu | Yêu cầu |
| --- | --- | --- |
| Mô tả sức khỏe | Nội dung gốc, thời điểm cập nhật, phiên bản | Thuộc đúng beneficiary/customer; không log toàn văn |
| Bản tóm tắt | Dữ kiện, đoạn nguồn, trạng thái chưa chắc chắn, câu hỏi cần làm rõ | Không ghi đè `ChronicConditions` bằng kết quả AI chưa được xác nhận |
| Hạn chế ăn uống | Dị ứng, nguyên liệu tránh, sở thích; chỉ định ăn uống do customer báo cáo | Phân biệt `unknown` với không có; giữ nguồn/thời điểm |
| Công thức | Nguyên liệu và định lượng, gia vị, khẩu phần, chế biến, allergen, nguồn dinh dưỡng | Có phiên bản và trạng thái draft/reviewed/retired; thiếu dữ liệu không mặc định bằng 0 |
| Quy tắc | Đối tượng áp dụng, dữ liệu cần có, điều kiện loại trừ, nguồn, người chuyên môn duyệt | Không hardcode ngưỡng điều trị từ tên bệnh hoặc từ AI |
| Kết quả gợi ý | Món/công thức, lý do, điều kiện áp dụng, phiên bản profile/rule/catalog | Có thể truy hồi nguồn quyết định; chưa được chọn khác đã lưu |
| Lựa chọn đã lưu | Customer, beneficiary, ngày, món/khẩu phần, snapshot dữ liệu | Không tự động cập nhật theo bản công thức mới |

Thuốc chỉ dùng theo những gì customer đã cung cấp và các quy tắc tương tác được kiểm duyệt. Không suy đoán thuốc từ tên bệnh, không khẳng định đã kiểm tra mọi tương tác thuốc–thực phẩm.

Không tự tính mục tiêu năng lượng, protein, carbohydrate, điện giải hoặc dịch chỉ từ tuổi và một mô tả. Những trường hợp cần mục tiêu cá nhân phải có thông tin/chỉ định đủ để áp dụng một quy tắc đã được kiểm duyệt.

## 6. Những tình huống cần thiết kế ngay

Kế hoạch triển khai chi tiết 9 tình huống, đối chiếu source ngày 11/10/2026: [Nutrition — xử lý tình huống và điều kiện gợi ý](NUTRITION_EDGE_CASE_IMPLEMENTATION_PLAN.md). Tài liệu này bổ sung state/API, revision/dị ứng, backlog và ma trận kiểm thử; chưa phải chức năng đã triển khai.

- Hồ sơ thiếu thông tin cần thiết (xét cả trường cấu trúc và lưu ý/ghi chú): chỉ hướng dẫn bổ sung phần thiếu. Không bắt có textarea mô tả nếu các trường hiện hữu đã đủ để phân tích.
- Chưa rõ dị ứng: hỏi customer xác nhận trước khi đưa gợi ý mang tính cá nhân hóa.
- Có triệu chứng nhưng chưa biết bệnh: không suy bệnh từ triệu chứng; yêu cầu làm rõ, không trả thực đơn điều trị.
- Có bệnh thận, khó nuốt, ăn qua ống hoặc hạn chế nước/điện giải đặc biệt: cần thông tin và hướng dẫn phù hợp trước khi gợi ý theo bệnh lý. Không tự coi “ăn mềm” là giải pháp cho khó nuốt.
- Có nhiều bệnh: áp dụng đồng thời những quy tắc tương thích; nếu thiếu dữ kiện hoặc có xung đột thì ngừng gợi ý theo bệnh lý và giải thích điều cần làm rõ.
- Không có công thức đã duyệt: hiển thị trạng thái chưa có nội dung. Dữ liệu demo chỉ dùng trong test/debug.
- Lỗi phân tích AI: giữ nội dung customer đã nhập, cho thử lại; không chuyển lỗi thành hồ sơ “không có bệnh”.
- Thay đổi người thân, đăng xuất, hết phiên: hủy request cũ, xóa kết quả khỏi màn hình, kiểm lại quyền khi truy cập dữ liệu.
- Hồ sơ bị xóa hoặc không thuộc customer: không trả mô tả, kết quả AI hay thực đơn.

Nhu cầu dinh dưỡng bệnh thận thay đổi theo tình trạng và không có một thực đơn chung cho mọi người bệnh; lượng protein, kali và dịch cần cá nhân hóa. Đây là cơ sở cho việc yêu cầu thông tin bổ sung, không tự gán “thực đơn bệnh thận”. [NIDDK](https://www.niddk.nih.gov/health-information/kidney-disease/chronic-kidney-disease-ckd/healthy-eating-adults-chronic-kidney-disease).

Khó nuốt cần đánh giá nuốt; thay đổi kết cấu thức ăn/độ đặc chất lỏng phải dựa trên đánh giá phù hợp. [ASHA – Adult Dysphagia](https://www.asha.org/practice-portal/clinical-topics/adult-dysphagia/).

## 7. Điểm tích hợp kỹ thuật đề xuất

- **People** giữ một hồ sơ nguồn hiện hành cho mỗi beneficiaryId và quyền sở hữu. Nutrition dùng hồ sơ đó; health-profile là view/endpoint cập nhật một phần của Beneficiary, không phải hồ sơ độc lập. Tái sử dụng GeneralNote/CareInstructions/HealthHistory và các trường sức khỏe có sẵn; chỉ thêm trường mới khi đã chứng minh dữ liệu hiện tại không biểu đạt được nhu cầu. Không dùng PUT hồ sơ tối giản làm mất dữ liệu y tế đã lưu.
- **Nutrition** là microservice độc lập tại `backend/services/nutrition/`, giữ DB riêng cho phân tích, danh mục, gợi ý và thực đơn đã lưu. Đọc snapshot People qua HTTP nội bộ có credential riêng; không reference ApiHost/Shared/module People hay đọc DB People.
- Nếu trường cấu trúc đã đủ và không có văn bản tự do cần đọc, chuẩn hóa bằng adapter backend và bỏ qua lượt gọi AI. Snapshot/phân tích/thực đơn đều gắn beneficiaryId hiện hữu.
- Giữ cấu trúc `Domain/Application/Infrastructure/Controllers`; DTO request/response mỗi type một file; parser là port, policy lọc món là hàm thuần có unit test.
- SQL additive theo quy trình migration hiện hành. Chọn số migration tiếp theo khi triển khai, không ghi đè SQL đã áp dụng.
- App customer thêm feature `nutrition` và route dưới đúng beneficiary. Dùng theme/components đang có; không thay shell hoặc thêm tab chính chỉ cho tính năng này.
- Danh mục món và quy tắc được import/duyệt theo quy trình nội dung; MVP không cần một màn hình quản lý dinh dưỡng mới trong admin.

API phác thảo, cần khóa hợp đồng khi triển khai:

| Method | Route | Mục đích |
| --- | --- | --- |
| GET/PATCH | `/api/v1/beneficiaries/{id}/health-profile` | People đọc/lưu mô tả và các trường sức khỏe, có kiểm revision |
| GET/PUT | `/api/v1/beneficiaries/{id}/nutrition-preferences` | Nutrition đọc/lưu sở thích và nhu cầu chuẩn bị món |
| POST | `/api/v1/beneficiaries/{id}/nutrition-assessments` | Phân tích mô tả đã lưu; trả tóm tắt/câu hỏi, chưa phải chẩn đoán |
| GET | `/api/v1/beneficiaries/{id}/nutrition-assessments/{assessmentId}` | Đọc trạng thái/tóm tắt của đúng bản phân tích |
| POST | `/api/v1/beneficiaries/{id}/nutrition-assessments/{assessmentId}/confirm` | Xác nhận/sửa dữ kiện; gắn đúng phiên bản profile |
| POST | `/api/v1/beneficiaries/{id}/meal-recommendations` | Gợi ý từ assessment đã xác nhận và công thức đã duyệt |
| GET | `/api/v1/beneficiaries/{id}/meal-recommendations/{recommendationId}` | Đọc bản gợi ý đã tạo của đúng beneficiary |
| POST | `/api/v1/beneficiaries/{id}/meal-recommendations/{recommendationId}/replacements` | Thay món/khẩu phần, kiểm lại ràng buộc và trả revision mới |
| POST/GET | `/api/v1/beneficiaries/{id}/meal-plans` | Lưu/xem lựa chọn của customer |
| GET | `/api/v1/beneficiaries/{id}/meal-plans/{planId}` | Đọc snapshot một thực đơn đã lưu và trạng thái cần kiểm tra lại |

Không nhận `customerId` do client gửi làm quyền sở hữu. Kiểm JWT/role CUSTOMER và ownership trên mọi endpoint; child ID cũng phải thuộc đúng beneficiary. Kết quả trả `needs_information`, `needs_professional_guidance`, `no_match` hoặc `suggested` bằng mã ổn định cho frontend.

## 8. UI và nội dung

Người thân trung niên mở hồ sơ cha mẹ trên điện thoại ở nhà, thường vào buổi tối và muốn xem gợi ý nhanh. Giữ giao diện sáng, màu teal và chữ rõ như app customer hiện tại; dùng accent cho CTA/trạng thái chọn.

- Một luồng gồm mở hồ sơ → kiểm tra/bổ sung thông tin cần thiết → kiểm tra tóm tắt → chọn món. Dùng layout theo bữa, không bảng dashboard hoặc card lồng card.
- Form hiện có được bổ sung/diễn đạt rõ phần sức khỏe khi cần, giữ dữ liệu cũ và prefill. Textarea **Mô tả tình trạng sức khỏe** nếu cần chỉ là trường trong cùng hồ sơ, không phải bước tạo hồ sơ Nutrition. Không yêu cầu nhập lại tên, tuổi, địa chỉ hoặc liên hệ.
- Bản tóm tắt: **Kiểm tra thông tin trước khi xem gợi ý**. Nút **Sửa thông tin**, **Thông tin đúng, tiếp tục**.
- Kết quả dùng **Được gợi ý vì…**, **Điều cần lưu ý**, **Đổi món**, **Lưu thực đơn**. Tránh “an toàn tuyệt đối”, “điều trị bệnh” hoặc “được bác sĩ duyệt” nếu không có bằng chứng.
- Loading, lỗi có thử lại, trạng thái không tìm thấy, chưa đủ thông tin và dữ liệu cũ đều có hành động tiếp theo rõ ràng.
- Touch target tối thiểu 44 px, hỗ trợ text scale và mobile 360–430 px; không dùng màu làm tín hiệu duy nhất.

## 9. Thứ tự triển khai và nghiệm thu

1. Đọc đúng hồ sơ beneficiary hiện có; ánh xạ đầy đủ dữ liệu, bảo toàn dữ liệu cũ, kiểm ownership và chỉ cập nhật mục còn thiếu/cần thay đổi.
2. Parser có schema cố định, kiểm phủ định/bệnh chưa xác nhận, ràng buộc độ dài, timeout và rate limit. Customer được sửa bản tóm tắt.
3. Bộ công thức và quy tắc có nguồn, khẩu phần, phiên bản và người chuyên môn duyệt. Chỉ bật từng nhóm tình trạng khi có đủ nội dung cho nhóm đó; mô tả đầu vào vẫn là văn bản tự do.
4. Bộ lọc/xếp hạng, đổi món và lưu thực đơn; không nới hạn chế bắt buộc khi hết lựa chọn.
5. Luồng customer hoàn chỉnh với dữ liệu backend thật; kiểm lỗi mạng, quyền, đổi người thân và mô tả mới.

Các kiểm thử quan trọng: customer A không đọc dữ liệu B; ID không tồn tại không fallback người khác; PUT hồ sơ không xóa sức khỏe; “không dị ứng” khác “chưa rõ”; phủ định/nghi bệnh/tiền sử không thành chẩn đoán; prompt injection không đổi policy; allergen từ gia vị; nhiều bệnh xung đột; thiếu dinh dưỡng không coi là 0; thay món/đổi profile phải kiểm lại; lỗi AI/catalog không tạo kết quả giả.

Chỉ báo thành công: customer hoàn thành được luồng nhập → kiểm tra → chọn → lưu; mọi món trả về có nguồn dữ liệu và lý do; các ca thiếu dữ kiện trả đúng trạng thái. Không lấy tỷ lệ luôn tạo được thực đơn làm mục tiêu để ép hệ thống bỏ qua hạn chế.

## 10. Nguồn tham khảo và phụ thuộc thực tế

- [NIDDK – Healthy Living with Diabetes](https://www.niddk.nih.gov/health-information/diabetes/overview/healthy-living-with-diabetes): kế hoạch ăn uống cần xét thực phẩm, lượng và thời điểm, phù hợp với kế hoạch chăm sóc cá nhân.
- [NHLBI – DASH Eating Plan](https://www.nhlbi.nih.gov/health/dash-eating-plan): nguồn tham khảo cho quy tắc ăn uống hỗ trợ tim mạch/huyết áp; không sao chép mức năng lượng mẫu làm định mức chung cho mọi người cao tuổi.
- [USDA FoodData Central](https://fdc.nal.usda.gov/): nguồn dữ liệu thành phần thực phẩm có thể dùng khi xây công thức; cần đối chiếu nguyên liệu và cách nấu tại Việt Nam, không coi số liệu thực phẩm rời là số liệu chính xác của món hoàn chỉnh.

Để đưa gợi ý theo bệnh lý vào vận hành, cần công thức/quy tắc được chuyên môn rà soát và cấu hình dịch vụ AI nếu chọn parser AI. Không bật lời khẳng định phù hợp bệnh lý chỉ vì model trả JSON đúng. Nếu dùng nhà cung cấp AI ngoài hệ thống, cần thông báo rõ việc xử lý mô tả sức khỏe và lựa chọn của customer; chỉ gửi dữ liệu tối thiểu cần thiết, không gửi tên/địa chỉ/điện thoại và không log nội dung nhạy cảm.

Đã có service/schema/API/UI và kiểm thử local. Provider AI thật, import/review nội dung chuyên môn, nghiệm thu staging/thiết bị và bật feature vẫn còn lại. Preferences mới có bảng dự phòng, chưa có API/UI; không tính là chức năng đã hoàn thành.

Khi thay/lưu món, client gửi ID/version và lựa chọn, không gửi số liệu dinh dưỡng hoặc nhãn eligible để server tin cậy. Server xác thực lại toàn bộ snapshot/rule scope và revision trước khi ghi; POST có idempotency để tránh lưu lặp.

## 11. Ranh giới service

Nutrition là microservice .NET 8 có solution, host, Docker image, PostgreSQL và runtime role riêng. ApiHost CareSitter tiếp tục chạy các module hiện hữu và cung cấp endpoint People nội bộ. Hai service triển khai và scale độc lập; không có khóa hay transaction xuyên database.

```text
Customer app / features/nutrition
  → Nutrition Controllers
      → Application: Assessments, Recommendations, MealPlans, Preferences
          → Domain: trạng thái, snapshot, ràng buộc và bất biến
          → Infrastructure: SQL, AI adapter, dispatcher/worker, kho nội dung

Nutrition Application
  → IPeopleHealthClient (HTTP + X-Nutrition-Service-Key)
      → ApiHost / internal/v1/nutrition/owners/{owner}/beneficiaries/{id}/health-profile
          → People: kiểm ownership + lấy snapshot/revision sức khỏe
```

| Thành phần | Sở hữu | Không tự làm |
| --- | --- | --- |
| People | Hồ sơ Beneficiary hiện có: lưu ý/ghi chú, ngày sinh, bệnh/dị ứng/thuốc, revision và quyền sở hữu | Không tạo bản hồ sơ nguồn thứ hai cho Nutrition, không dùng AI ghi chẩn đoán mới |
| Nutrition | Snapshot phân tích, kết quả trích xuất/xác nhận, sở thích, danh mục công thức/quy tắc và thực đơn | Không đọc trực tiếp entity/DbContext People hoặc sửa hồ sơ nguồn qua SQL |
| HTTP contract | Snapshot tối thiểu, beneficiaryId và revision; DTO riêng ở mỗi bên | Không chia sẻ EF entity/DbContext hay credential client |
| Nutrition host | DI, JWT, rate limit, feature flags, worker registration và DB riêng | Không chứa policy lựa chọn món |
| ApiHost CareSitter | People health API và xác thực dịch vụ nội bộ | Không host Nutrition worker hoặc truy cập DB Nutrition |
| Customer app | Nhập/xác nhận/chọn/lưu, trình bày trạng thái backend | Không gọi AI trực tiếp hoặc tự xác nhận món phù hợp bệnh lý |

Tổ chức Application theo feature; requests/responses/ports/handlers/policies tách file như quy ước DTO vừa thống nhất. Dùng `IHealthDescriptionParser` để thay nhà cung cấp AI mà không đổi API customer. `MealEligibilityPolicy` và `MealRankingPolicy` nhận snapshot/options tường minh, không gọi DB/HTTP hoặc đọc thời gian hệ thống ngầm.

## 12. Thiết kế lưu trữ và quản lý phiên bản

Schema chi tiết sẽ khóa khi triển khai; thiết kế logic đề xuất:

| Dữ liệu | Nơi lưu | Cột/thuộc tính chính |
| --- | --- | --- |
| Hồ sơ/mô tả nguồn | People beneficiaries hiện có | GeneralNote/CareInstructions/HealthHistory và các JSON sức khỏe; bổ sung `health_profile_revision` khi triển khai, không mặc định thêm cột mô tả trùng dữ liệu |
| Sở thích | nutrition.preferences | beneficiary/customer, thực phẩm thích/không thích, cách chế biến, thời gian chuẩn bị, revision |
| Assessment | nutrition.assessments | owner, beneficiary, source revisions, trạng thái, schema/parser/prompt version, snapshot tối thiểu, facts/questions/confirmation, attempts/lease |
| Khái niệm thực phẩm/tình trạng | nutrition.concepts | mã chuẩn, loại, từ đồng nghĩa đã kiểm tra, phiên bản; không phải công cụ chẩn đoán |
| Công thức phiên bản | nutrition.recipe_versions | recipe ID/version, nguyên liệu+gia vị, định lượng, serving/yield, nguồn dinh dưỡng, allergens, review/publication status |
| Quy tắc phiên bản | nutrition.rule_versions | applicability, prerequisites, scope, exclusions/actions, nguồn và bằng chứng review, effective/retired status |
| Kết quả gợi ý | nutrition.recommendations | assessment/profile/preferences/catalog/rule versions, items, lý do có ID quy tắc, trạng thái |
| Thực đơn đã lưu | nutrition.meal_plans | owner/beneficiary/date, snapshot món/khẩu phần, recommendation ID, revision, trạng thái cần kiểm tra lại |

Assessment chứa snapshot để giải thích kết quả tại thời điểm phân tích; snapshot không phải một hồ sơ sức khỏe có thể sửa độc lập. People vẫn là nguồn hiện hành. Dữ liệu nhạy cảm trong snapshot/facts cũng phải chịu cùng kiểm soát truy cập và chính sách lưu/xóa như mô tả nguồn.

- Mỗi cập nhật trường sức khỏe ảnh hưởng phân tích tăng `health_profile_revision`. Sở thích có revision riêng.
- PATCH mới phân biệt rõ trường không gửi = giữ nguyên, giá trị null có chủ ý = xóa, giá trị có mặt = cập nhật. Bảo toàn hợp đồng JSON hiện hữu và thêm regression cho PUT cũ; không dùng nullable đơn thuần để đoán trường có được gửi hay không.
- Đọc GeneralNote/CareInstructions như dữ liệu báo cáo có sẵn; không tự động di chuyển thành chẩn đoán hoặc yêu cầu customer sao chép sang cột mô tả mới. Nếu customer sửa/bổ sung, lưu vào đúng trường nguồn của cùng Beneficiary.
- Tạo/confirm/gợi ý/lưu đều kiểm tra source revision. Thay đổi giữa chừng trả `PROFILE_CHANGED` và hướng dẫn kiểm tra lại; không giữ khóa DB trong lúc gọi AI.
- Không tự sửa nội dung thực đơn đã lưu khi recipe/rule đổi. Đánh dấu cần kiểm tra lại khi nguồn thay đổi hoặc phiên bản nội dung bị thu hồi.
- Xóa/khóa/đổi quyền hồ sơ nguồn chặn mọi endpoint con ngay cả khi assessment vẫn tồn tại. Job xử lý nền kiểm lại ownership và quyền xử lý trước khi đọc nguồn/lưu kết quả.

### 12.1. Ghi chú các cột Nutrition đã trao đổi — 05/10/2026

Bảng dưới đây giữ thiết kế logic để mở rộng; schema thực tế dùng relational columns cho owner/revision/status và JSONB payload cho snapshot/facts/món. Nguồn schema là `backend/init-db/nutrition-service/01-nutrition-workflow.sql` trên DB riêng, thêm `assessment_jobs` và `catalog_state`. Mỗi người thân vẫn sử dụng hồ sơ Beneficiary hiện có trong People.

| Bảng trong schema `nutrition` | Các cột dự kiến |
| --- | --- |
| `preferences` | `id`, `customer_id`, `beneficiary_id`, `liked_foods`, `disliked_foods`, `preferred_cooking_methods`, `max_prep_minutes`, `revision` |
| `assessments` | `id`, `customer_id`, `beneficiary_id`, `health_profile_revision`, `input_snapshot`, `extracted_facts`, `unresolved_items`, `status`, `processing_versions`, `confirmation`, `error_code`, `idempotency_key`, `attempt_count`, `lease_until` |
| `concepts` | `id`, `code`, `kind`, `display_name`, `aliases`, `dictionary_version`, `is_active` |
| `recipe_versions` | `id`, `recipe_id`, `version`, `name`, `meal_types`, `ingredients`, `servings`, `preparation_steps`, `prep_minutes`, `nutrition_per_serving`, `allergens`, `sources`, `review_metadata`, `status` |
| `rule_versions` | `id`, `rule_id`, `version`, `name`, `applicability`, `prerequisites`, `scope`, `actions`, `sources`, `review_metadata`, `status` |
| `recommendations` | `id`, `customer_id`, `beneficiary_id`, `assessment_id`, `health_profile_revision`, `preferences_revision`, `planned_date`, `meal_items`, `applied_rule_versions`, `status` |
| `meal_plans` | `id`, `customer_id`, `beneficiary_id`, `recommendation_id`, `planned_date`, `meal_snapshot`, `revision`, `status`, `saved_at` |

Quy ước dữ liệu:

- Các bảng đều có `created_at`, `updated_at` kiểu `TIMESTAMPTZ`. ID dùng `UUID`; revision/version dùng `INTEGER` hoặc `BIGINT`; `planned_date` dùng `DATE` theo ngày sử dụng của customer. `saved_at`, `lease_until` dùng `TIMESTAMPTZ`.
- Các cấu trúc danh sách, snapshot, facts, điều kiện/hành động quy tắc và nguồn có thể dùng `JSONB` với schema được kiểm tra ở backend; không nhận JSON tùy ý từ client. Các giá trị cần lọc/index trực tiếp giữ ở cột riêng.
- `processing_versions` ghi phiên bản schema/parser/prompt/model/dictionary. `confirmation` ghi người xác nhận, thời điểm và revision được xác nhận; `unresolved_items` ghi thông tin còn thiếu hoặc mâu thuẫn.
- `nutrition_per_serving` ghi giá trị, đơn vị và nguồn/phương pháp ước tính cho năng lượng, đạm, carbohydrate, chất béo, chất xơ, natri và các chất cần thiết trong phạm vi đã được duyệt. Thiếu dữ liệu dùng `null`, không mặc định bằng 0.
- `meal_items` phải tham chiếu ID/version công thức và khẩu phần; `applied_rule_versions` phải lưu ID/version quy tắc. `meal_snapshot` giữ nội dung thực đơn tại thời điểm lưu để có thể xem lại dù danh mục được cập nhật.
- `customer_id` do backend xác định từ phiên đăng nhập và kiểm quyền với `beneficiary_id`. Không cho client tự chọn chủ sở hữu. `preferences` dự kiến duy nhất theo customer/beneficiary; recipe/rule có ràng buộc duy nhất theo ID logic + version; idempotency có phạm vi theo customer và thao tác.
- `input_snapshot` là bằng chứng lịch sử của lần phân tích, không phải hồ sơ sức khỏe thứ hai có thể chỉnh sửa. Bệnh lý, dị ứng, thuốc và mô tả sức khỏe hiện hành vẫn thuộc People. Sở thích không được thay thế hoặc ghi đè hạn chế sức khỏe.
- Các phiên bản recipe/rule đã xuất bản và snapshot đã xác nhận không sửa nội dung tại chỗ; thay đổi nội dung tạo phiên bản hoặc assessment mới. Các trường trạng thái và mốc thời gian phục vụ quản lý vòng đời.

## 13. Giao thức phân tích và trạng thái

POST assessment đề xuất trả HTTP 202 và Location cho assessment ID đã lưu. Client gửi beneficiaryId/expectedHealthRevision/idempotency key; backend tự lấy snapshot hồ sơ có sẵn của đúng customer. Client không phải gửi lại toàn bộ hồ sơ hoặc owner ID.

```text
queued → processing → needs_information
                    → awaiting_confirmation → confirmed
                    → needs_professional_guidance
                    → failed

Trả lời bổ sung làm thay đổi nguồn → revision mới → assessment mới queued

Thay đổi source revision → stale
Hủy/xóa hồ sơ hoặc rút quyền xử lý → cancelled
```

- Job chỉ có assessment ID. Dispatcher quét bản ghi queued bền vững; worker claim bằng lease để tránh xử lý đồng thời. Có recovery khi process chết, giới hạn attempts và kiểm duplicate execution.
- Phân biệt kết quả extraction đã tạo với profile đã xác nhận, và confirmed với đủ điều kiện gợi ý. Customer xác nhận nội dung không xác minh chẩn đoán hoặc tự duyệt quy tắc.
- Nếu một dữ kiện cần sửa, lưu correction có provenance riêng; câu trả lời bổ sung về sức khỏe cập nhật nguồn People, tạo revision mới và phân tích lại. Không nối vòng chat vô hạn vào một assessment cũ.
- Timeout/429/refusal/output không hợp lệ phải có mã lỗi riêng. Không fallback sang kết quả “không có bệnh”. Retry giới hạn; sau timeout không hứa chỉ bị tính phí một lần bởi nhà cung cấp.
- Client đọc trạng thái có backoff và dừng khi rời màn hình/đăng xuất. Nhấn lại CTA với cùng idempotency key không tạo nhiều job.
- Cập nhật nguồn làm assessment cũ stale; kết quả từ job cũ không được chuyển thành confirmed hoặc suggestion hiện hành.

Các giới hạn kỹ thuật ban đầu đề xuất, điều chỉnh sau đo thực tế: tối đa 4.000 ký tự mô tả/16 KB UTF-8; tối đa 40 facts; tối đa 3 câu hỏi thiết yếu mỗi lượt, 2 lượt làm rõ; timeout AI khoảng 25 giây/lượt; quota theo customer và giới hạn chi phí ngày. Đây là cấu hình kỹ thuật, không phải ngưỡng y khoa.

## 14. Chuẩn bị danh mục món và quy tắc

1. Thu thập công thức thực tế phù hợp thói quen ăn uống Việt Nam. Mỗi công thức có đầy đủ nguyên liệu, gia vị, khối lượng, số phần và cách nấu.
2. Chuẩn hóa thực phẩm/raw–cooked basis, đơn vị và allergen, bao gồm thành phần của nguyên liệu chế biến sẵn. Không suy đoán công thức chỉ từ tên món.
3. Gắn nguồn dữ liệu dinh dưỡng cho từng thành phần/công thức; đánh dấu estimated/missing, tính yield và khẩu phần theo phương pháp được kiểm tra.
4. Chuyên môn rà soát phạm vi sử dụng và quy tắc. Người nhập dữ liệu kỹ thuật hoặc ADMIN không mặc nhiên có thẩm quyền duyệt nội dung y khoa.
5. Import draft → kiểm tra schema → reviewed → published. Review và publication có người, thời điểm, nguồn, version và lịch sử thu hồi.
6. Bắt đầu bằng một danh mục thử có đủ món thay thế cho các tổ hợp hạn chế được hỗ trợ. Số lượng món chỉ là mục tiêu nội dung; không bật chức năng vì đạt một số lượng nhưng thiếu coverage.

RAG nếu cần dùng để truy hồi nội dung đã review từ kho nội bộ có version. MVP ưu tiên truy vấn theo concept/rule ID; chưa cần vector database. Không tìm web theo mô tả sức khỏe từng customer và dùng kết quả ngẫu nhiên làm quy tắc vận hành.

## 15. Lộ trình triển khai chi tiết

| Giai đoạn | Task | Sản phẩm bàn giao | Tiêu chí qua bước |
| --- | --- | --- | --- |
| P0 — Hồ sơ và hợp đồng | Rà mapping sức khỏe; xử lý omission/null; bỏ mặc định sức khỏe giả trong pipeline; sửa route sai ID; khóa schema phân tích | Health snapshot contract, input/output schema, luồng UX và dữ liệu test | Không mất dữ liệu cũ, không đọc nhầm người, unknown được giữ nguyên |
| P1 — Nền Nutrition | Service/host/DB/CI riêng; schema, assessments, revisions, ownership và flags | Backend nền tảng và endpoint health-profile thuộc People | Schema test và quyền dữ liệu đạt; rollout/replay môi trường thật còn lại |
| P2 — Bộ phân tích | Parser port/adapter; schema và provenance validation; dictionary; conflicts; câu hỏi; confirm; worker/lease/retry | Phân tích được mô tả tiếng Việt và trả trạng thái chính xác | Bộ đánh giá ngôn ngữ qua; lỗi quan trọng không lọt vào dữ kiện được dùng |
| P3 — Nội dung chuyên môn | Công thức, thành phần, allergen, dữ liệu dinh dưỡng và rule versioning/review | Danh mục nội dung published cho phạm vi hỗ trợ | Mọi item có nguồn/review; thiếu dữ liệu quan trọng không được coi là 0 |
| P4 — Gợi ý/lưu | Eligibility, tổng ràng buộc, ranking, replacement, snapshot plans, stale detection | Customer nhận/lưu được lựa chọn thực tế | Không vượt hard constraint; thay món kiểm lại toàn bộ phạm vi |
| P5 — Customer UI | Form mô tả, summary correction, câu hỏi, kết quả theo bữa, đổi/lưu/lịch sử | Luồng customer hoàn chỉnh dùng backend thật | Loading/error/empty/unknown/session/text scale đều được nghiệm thu |
| P6 — Pilot | Regression, quyền/riêng tư, quota/load/failure recovery, kiểm duyệt nội dung và pilot nhỏ | Báo cáo nghiệm thu và phạm vi bật tính năng | Có evidence từng gate; không bật nhóm tình trạng ngoài phạm vi |

Thứ tự phụ thuộc: P0 → P1 → P2 → P4 → P5 → P6. P3 có thể chuẩn bị song song từ sau P0 và phải hoàn tất phần nội dung cần dùng trước nghiệm thu P4. UI có thể dựng với fixture test theo schema từ P0; dữ liệu fixture không đưa vào flow production.

Phân công công việc đề xuất: backend phụ trách hợp đồng/persistence/parser/policy; frontend phụ trách customer flow; chuyên môn phụ trách công thức/quy tắc; QA kiểm regression và bộ mẫu ngôn ngữ. Chưa ấn định ngày giao hàng vì chưa biết nhân lực, dịch vụ AI và tốc độ kiểm duyệt nội dung.

## 16. Checklist nghiệm thu và cách đo

- Backend: service độc lập không reference monolith, HTTP contract, migration/replay, API ownership, sparse updates, revision/idempotency, worker lease recovery và log không lộ nội dung.
- Phân tích: negation, uncertainty, history, đúng chủ thể, dị ứng/sở thích, thuốc/thực phẩm, spelling/abbreviation, unknown terms, source conflict, prompt injection, câu hỏi có mục đích. Chi tiết trong analysis spec.
- Nội dung: reviewed/published version, đơn vị/serving/yield, allergen từ gia vị, ràng buộc theo bữa/ngày, dữ liệu dinh dưỡng thiếu, rule prerequisites và thu hồi nội dung.
- UI: đúng beneficiary, mạng lỗi không làm mất draft, xác nhận khác lưu thực đơn, kết quả stale, không có món đáp ứng, text scale, bàn phím/web và điện thoại.
- Vận hành: phân tích lỗi/timeout, phục hồi job, quota và chi phí, chính sách lưu/xóa đã cấu hình, disable feature, rollback release và restore dữ liệu mới.
- Feature flags mặc định tắt: chỉ bật entry point khi nền tảng đủ, bật phân tích khi adapter/config được nghiệm thu và bật gợi ý riêng cho phạm vi nội dung đã publish/review. Không trả kết quả stub thành công khi thiếu provider/catalog.
- Đo thời gian phản hồi, tỷ lệ schema/provenance hợp lệ, precision/recall của từng loại fact, tỷ lệ customer sửa summary, tỷ lệ needs_information/professional/no_match, nguồn lỗi và chi phí mỗi assessment. Không log nội dung sức khỏe để lấy metric.

Không dùng điểm confidence do AI tự chấm làm điều kiện thông qua an toàn. Bộ test kỹ thuật không thay thế review nội dung chuyên môn hoặc chứng nhận phù hợp cho mọi bệnh lý.

## 17. Các phụ thuộc chưa có trong source và cách xử lý

| Phụ thuộc | Tình trạng lập plan | Cách xử lý trước khi bật |
| --- | --- | --- |
| Dịch vụ AI | Chưa chọn nhà cung cấp/model | So sánh bằng cùng bộ mẫu tiếng Việt, dữ liệu được xử lý ở đâu, retention, độ trễ/chi phí; giữ adapter thay thế được |
| Công thức/quy tắc đã review | Chưa thấy danh mục Nutrition hiện hữu | Chuẩn bị nội dung và workflow review; chỉ publish bản có bằng chứng |
| Phạm vi bệnh/tình trạng hỗ trợ | Đầu vào tự do, không có danh sách cố định được chốt | Kho nội dung vẫn phải khai báo phạm vi hỗ trợ; ngoài phạm vi trả trạng thái rõ ràng |
| Chuyên môn kiểm duyệt | Chưa xác định người/quy trình | Phân công trước khi đưa ra gợi ý theo bệnh lý; không để AI tự phê duyệt |
| Lưu/xóa và xử lý dữ liệu ngoài hệ thống | Chưa có quyết định cho Nutrition | Ghi rõ mục đích, quyền xử lý và thời hạn; policy phải cấu hình trước pilot |

Service/API/worker/People integration/UI đã có code và kiểm thử local; phần provider, nội dung chuyên môn và rollout vẫn cần nghiệm thu. Xem [báo cáo hiện tại](../kiem-thu/NUTRITION_SERVICE_IMPLEMENTATION_2026-10-11.md).
