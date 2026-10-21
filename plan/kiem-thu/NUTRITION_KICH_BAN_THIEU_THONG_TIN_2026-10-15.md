# Kịch bản kiểm thử Nutrition khi hồ sơ thiếu thông tin

Cập nhật ngày 15/10/2026. Tài liệu này mô tả hành vi hiện tại của luồng đọc hồ sơ người thụ hưởng, phân tích điều kiện an toàn và yêu cầu người dùng bổ sung dữ liệu trước khi gợi ý thực đơn.

## Kết quả chạy test hiện tại

| Phạm vi | Kết quả |
| --- | --- |
| Nutrition service, gồm test PostgreSQL thật | 61 pass, 0 fail, 0 skip |
| Tích hợp People/Nutrition, gồm test PostgreSQL thật | 57 pass, 0 fail, 0 skip |
| Flutter Nutrition và làm mới phiên | 24 pass, 0 fail |

Các lệnh trên được chạy tại workspace local ngày 15/10/2026. Đây là targeted test của luồng Nutrition, không phải full regression toàn repository.

## Dữ liệu tối thiểu để đi tiếp

Người dùng phải xác nhận đủ các mục sau:

- Tình trạng dị ứng thực phẩm: có hoặc đã xác nhận không có.
- Tình trạng bệnh lý: có hoặc gia đình xác nhận chưa có.
- Việc dùng thuốc hiện tại: đang dùng hoặc đã xác nhận không dùng.
- Cách ăn uống hiện tại: qua miệng hoặc qua ống.
- Khả năng nuốt: bình thường hoặc có khó khăn.
- Hướng dẫn hạn chế nước: có hoặc đã xác nhận không có.
- Hướng dẫn về điện giải: có hoặc đã xác nhận không có.

Nếu khai báo có dị ứng, bệnh lý hoặc đang dùng thuốc thì phải nhập thêm danh sách tương ứng. Giá trị `Chưa rõ` được lưu trung thực và làm kết quả dừng ở `needs_information`; hệ thống không tự suy diễn thành “không có”.

## Kịch bản nhập thiếu thông tin

### 1. Người dùng chưa khai gì

**Dữ liệu:** dị ứng và bệnh lý vẫn là `Chưa rõ`; phần thuốc và nhu cầu ăn uống chưa chọn.

**Thao tác:** bấm phân tích hồ sơ.

**Mong đợi:** trạng thái `needs_information`, giao diện hiện “Cần bổ sung thông tin” và yêu cầu xác nhận:

- Dị ứng thực phẩm.
- Bệnh lý hiện có.
- Việc dùng thuốc.
- Cách ăn uống.
- Khả năng nuốt.
- Hạn chế nước.
- Hướng dẫn điện giải.

Không được hiện nút xác nhận kết quả hoặc gợi ý thực đơn.

### 2. Đã xác nhận không có bệnh và dị ứng, nhưng bỏ trống thuốc và khả năng ăn

**Dữ liệu:**

```json
{
  "foodAllergyStatus": "reported_none",
  "nutritionProfile": {
    "schemaVersion": 1,
    "conditionsStatus": "reported_none"
  }
}
```

**Mong đợi:** `needs_information`. Danh sách thiếu gồm `medicationsStatus`, `feedingRoute`, `swallowingStatus`, `fluidRestriction` và `electrolyteRestriction`. Ghi chú chung không được dùng để tự lấp các trường này.

### 3. Khai có bệnh nhưng không nhập tên bệnh

**Dữ liệu:** chọn “Có thông tin bệnh lý”, để trống “Bệnh đã được thông báo”; các mục khác hợp lệ.

**Mong đợi:** `needs_information`, yêu cầu “Bổ sung bệnh đã được thông báo” (`chronicConditions`). Không được coi một triệu chứng trong ghi chú là chẩn đoán bệnh.

### 4. Khai có dị ứng nhưng không nhập thực phẩm

**Dữ liệu:** chọn “Có dị ứng thực phẩm”, để trống danh sách thực phẩm gây dị ứng; các mục khác hợp lệ.

**Mong đợi:** `needs_information`, yêu cầu “Làm rõ thực phẩm gây dị ứng” (`allergies`). Không được suy diễn là không dị ứng.

### 5. Khai đang dùng thuốc nhưng không có danh sách thuốc

**Dữ liệu:** chọn “Đang dùng thuốc”, không thêm thuốc; các mục khác hợp lệ.

**Mong đợi:** `needs_information`, yêu cầu bổ sung `medications`.

Nếu có thuốc nhưng thiếu `is_active`, tên trống hoặc sai cấu trúc, kết quả vẫn là `needs_information` và chỉ ra phần tử thuốc cần làm rõ.

### 6. Một mục chuyên biệt vẫn là “Chưa rõ”

**Dữ liệu:** mọi mục hợp lệ, riêng `swallowingStatus = unknown`.

**Mong đợi:** `needs_information`, yêu cầu “Khả năng nuốt”. Áp dụng tương tự cho cách ăn, hạn chế nước và điện giải.

### 7. Hồ sơ tự mâu thuẫn

**Dữ liệu:** người dùng xác nhận không dị ứng nhưng danh sách dị ứng vẫn có “Tôm”.

**Mong đợi:** `needs_information` với xung đột nguồn dữ liệu. Giao diện báo các nguồn thông tin đang khác nhau; hệ thống giữ hạn chế đã ghi nhận và yêu cầu người dùng sửa hồ sơ.

Áp dụng tương tự khi xác nhận không có bệnh nhưng vẫn có bệnh hiện tại, hoặc xác nhận không dùng thuốc nhưng danh sách có thuốc đang hoạt động.

### 8. Chỉ ghi triệu chứng hoặc thông tin chưa chắc chắn

**Dữ liệu ví dụ:** “Beni hay khát nước, gia đình nghi tiểu đường” trong ghi chú, nhưng chưa có chẩn đoán được khai trong `chronicConditions`.

**Mong đợi theo policy:** triệu chứng hoặc bệnh chưa chắc chắn không được chuyển thành chẩn đoán để tạo chế độ ăn; kết quả phải yêu cầu làm rõ `unresolvedHealthFacts`.

**Giới hạn runtime hiện tại:** parser văn bản chưa được cấu hình, nên hồ sơ có ghi chú tự do hiện kết thúc ở `failed` với mã `nutrition.ai_unavailable`, đồng thời giữ nguyên dữ liệu đã nhập. Kịch bản `unresolvedHealthFacts` đã có unit test cho đầu ra parser hợp lệ, nhưng chưa thể chạy end-to-end bằng AI thật.

## Trường hợp không phải thiếu thông tin

- Ăn qua ống, khó nuốt, có hạn chế nước hoặc điện giải: `needs_professional_guidance`.
- Có thuốc đang dùng với cấu trúc hợp lệ: `needs_professional_guidance` vì chưa có danh mục tương tác thuốc–thực phẩm được duyệt.
- Bệnh đã xác nhận nhưng chưa có rule dinh dưỡng được duyệt: `needs_professional_guidance`.
- Dữ liệu đầy đủ: `awaiting_confirmation`; chỉ sau khi người dùng xác nhận mới thành `eligible`.
- Hồ sơ thay đổi sau lần phân tích: kết quả cũ thành `stale` và phải phân tích lại.

## Tiêu chí đạt khi test tay

1. Không trường `unknown` hoặc dữ liệu rỗng nào bị hiểu thành “không có”.
2. Màn hình liệt kê đúng mục cần bổ sung bằng nhãn tiếng Việt.
3. Không cho xác nhận hoặc xem thực đơn khi trạng thái là `needs_information`.
4. Dữ liệu đã nhập vẫn còn sau lỗi lưu hoặc lỗi phân tích.
5. Sau khi bổ sung đủ và phân tích lại, kết quả chuyển sang `awaiting_confirmation` nếu hồ sơ không cần chuyên gia.
6. Việc xác nhận chuyển kết quả sang `eligible`; gợi ý món chỉ chạy sau bước này.

## Giới hạn của kết luận test

Bộ test xác nhận cơ chế bảo toàn dữ liệu, phát hiện thiếu/mâu thuẫn, phân quyền, idempotency, revision và ràng buộc PostgreSQL. Nó chưa chứng minh chất lượng y khoa của thực đơn thực tế vì parser AI chưa cấu hình và catalog runtime hiện chưa có bộ công thức/rule bệnh lý đã duyệt.
