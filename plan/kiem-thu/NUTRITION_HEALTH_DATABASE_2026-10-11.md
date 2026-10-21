# Hồ sơ sức khỏe và DB Nutrition

Cập nhật 11/10/2026. Phạm vi: People quản lý hồ sơ gốc, chuẩn hóa dữ liệu cho Nutrition, form customer và bootstrap/kiểm thử PostgreSQL riêng. Đã có code, chạy local; chưa triển khai production. Markdown chỉ lưu local.

## Đã hoàn thành

- `PATCH /api/v1/beneficiaries/{id}/health-profile` kiểm định JSON bệnh lý, dị ứng, thuốc, enum, độ dài và trường trùng. Thêm `nutritionProfile` để merge từng trường vào `healthHistory.nutrition`; không gửi đồng thời với `healthHistory` thay thế toàn bộ. Giữ các mục cũ ngoài phần đang sửa. Phiên bản không hỗ trợ hoặc lịch sử cũ không phải object trả lỗi, không ghi đè.
- People vẫn kiểm owner/role/hồ sơ chưa xóa, khóa hàng và so sánh `expectedHealthRevision`. Xung đột “không có bệnh/thuốc” với danh sách đang có bị từ chối; patch lỗi không lưu một phần. Sửa ghi chú không tự xác nhận lại dị ứng.
- Dữ liệu `healthHistory.nutrition` phiên bản 1 bổ sung `medicationsStatus`. Customer nhập thuốc theo thông tin hiện có, trạng thái đang dùng/đã ngừng/chưa rõ; giữ lịch dùng, hướng dẫn và ngày đã lưu khi chỉ sửa tên/liều. Các mục cách ăn, khả năng nuốt, hạn chế nước/điện giải có lựa chọn “Chưa rõ”. Lưu lỗi giữ draft, hủy request/xóa dữ liệu theo phiên như luồng hiện hữu.
- Nutrition yêu cầu làm rõ trạng thái thuốc và các mục ăn uống trước khi cá nhân hóa; dữ liệu cũ thiếu trường không được mặc định bình thường. Thuốc đang dùng hợp lệ đi tới `needs_professional_guidance` vì chưa có catalog tương tác thuốc–thực phẩm đã duyệt. Thuốc đã ngừng không bị coi là đang dùng. Dữ liệu thuốc thiếu trạng thái/sai cấu trúc giữ `needs_information`. Không bắt ghi chú văn bản khi dữ liệu cấu trúc đã đủ.
- Readiness kiểm đủ bảng/cột/kiểu dữ liệu được runtime sử dụng, catalog epoch, quyền schema/bảng/cột, runtime không superuser/BYPASSRLS/CREATEDB/CREATEROLE, RLS và policy owner tồn tại. Catalog không có quyền ghi từ runtime. `/health/ready` chỉ xác nhận DB, không xác nhận AI/provider/People hoạt động.
- Sửa AppHost đọc khóa `.env` lặp: giữ giá trị đầu tiên, khớp `NoClobber` của API và vẫn ưu tiên cấu hình đã inject. Bổ sung cờ HTTP cho launch profile Development ở localhost; dashboard vẫn yêu cầu token đăng nhập.

## DB local đã thực hiện

1. DB CareSitter `caresitter-db`, database `caresitter`, khớp endpoint backend local và bind mount source: áp dụng **37-beneficiary-self-profile.sql** và **38-nutrition-health-revision.sql** qua runner `update-db.ps1 -From 37 -SkipStart`. Đối chiếu checksum SQL trong container với source trước chạy. Sau chạy đủ `is_self`, `health_profile_revision`, `food_allergy_status`, `food_allergy_confirmed_at`, `food_allergy_confirmed_by`, trigger `trg_beneficiaries_health_revision`. Số hàng và fingerprint các trường hồ sơ đã có không đổi. Không áp dụng các migration nghiệp vụ khác trong tác vụ này.
2. PostgreSQL 18 native riêng ở `127.0.0.1:5437`, database `nutrition`, 9 bảng; dùng script `backend/services/nutrition/scripts/start-local-db.ps1`. Script sinh secret một lần trong `nutrition-db.local.json` bị ignore, khóa bootstrap, xác minh data directory, chỉ init schema khi DB rỗng. Chạy lại không reset dữ liệu. Thư mục data/log ở `backend/artifacts/nutrition-local`. Các file cấu hình local bị loại khỏi cả Git và Docker build context.
3. AppHost đã khởi chạy PostgreSQL 16 với volume riêng `caresitter-apphost-nutrition`, API và Nutrition. Runtime `nutrition_app`, không superuser/BYPASSRLS. API `/health/live` = 200; Nutrition `/health/ready` = 200; capabilities qua API và trực tiếp Nutrition khi chưa đăng nhập đều = 401. Catalog thực tế có 0 recipe và 0 rule; không seed demo. AppHost và process dịch vụ của lượt smoke được dừng sau kiểm tra; volume được giữ.

Hai DB Nutrition native/AppHost là hai lựa chọn local tách biệt, không tự đồng bộ dữ liệu. Luồng AppHost mặc định dùng DB Docker do AppHost quản lý.

## Hợp đồng patch bổ sung

Ví dụ từ gốc API, body cho PATCH hồ sơ do customer sở hữu; giá trị là dữ liệu người dùng cung cấp, không phải mặc định tự điền:

```json
{
  "expectedHealthRevision": 7,
  "changes": {
    "nutritionProfile": {
      "medicationsStatus": "reported_present",
      "feedingRoute": "oral",
      "swallowingStatus": "unknown",
      "fluidRestriction": "unknown",
      "electrolyteRestriction": "unknown"
    },
    "medications": [
      { "name": "Tên thuốc theo hồ sơ", "is_active": true }
    ]
  }
}
```

`nutritionProfile`: `conditionsStatus`/`medicationsStatus` = unknown|reported_none|reported_present; feedingRoute = unknown|oral|tube; swallowingStatus = unknown|normal|difficulty; fluidRestriction/electrolyteRestriction = unknown|none|present; symptoms/guidance = văn bản tối đa 4.000 ký tự. Server ghi schemaVersion=1 khi merge. Mảng dị ứng/bệnh/thuốc tối đa 40 mục. Thuốc có name, dosage, schedule, instruction, start_date/end_date dạng yyyy-MM-dd và is_active boolean; dữ liệu cũ không có is_active được giữ nhưng cần làm rõ.

## Kiểm chứng

| Phạm vi | Kết quả cuối |
| --- | --- |
| People profile + gateway/session/internal auth | 53 pass, 0 fail, 0 skip; PostgreSQL 16/PostGIS container riêng, tự dọn |
| AppHost configuration regression | 3 pass, 0 fail, 0 skip |
| Nutrition độc lập | 51 pass, 0 fail, 0 skip trên PostgreSQL 18 local; cả 51 đã pass trên PostgreSQL 16 trước lần bổ sung assertion readiness cuối |
| Customer Nutrition + refresh/session | 19 pass, 0 fail |
| Flutter analyze phần Nutrition | Không có issue |
| AppHost runtime | API live 200, Nutrition ready 200; auth 401; 9 bảng và runtime role được xác minh trên PostgreSQL 16 |
| Giao diện | Widget 320/390px với text scale 2; kiểm ảnh form 390px dùng font/theme app |

Tổng 126 test khác nhau pass. Lần đầu có lỗi readiness và test fixture giao diện; đã sửa và chạy lại. Không tính test screenshot tạm hay lần chạy lặp vào tổng.

Evidence local: `backend/artifacts/nutrition-profile/people-postgres.trx`, `apphost-config.trx`, `nutrition-postgres-final.trx`, `nutrition-postgres16.trx`, `flutter-tests-final.log`, `apphost-smoke-result.json`, `profile-form.png`. Log AppHost chứa link đăng nhập dashboard: chỉ giữ local, không đưa lên Git hoặc báo cáo công khai.

## Khởi chạy

Từ gốc repository, dùng Docker Desktop cho cách chạy chính:

```powershell
./backend/scripts/run-apphost.ps1
```

Nếu chỉ cần DB Nutrition native (PostgreSQL 18 đã cài trên Windows):

```powershell
./backend/services/nutrition/scripts/start-local-db.ps1
```

Script native chỉ chạy DB. Connection string runtime lấy từ cấu hình local để inject vào `ConnectionStrings__Nutrition`; không gửi admin credential vào Nutrition. Không bật feature chỉ vì DB đã ready.

## Giới hạn còn lại

- Feature Nutrition mặc định vẫn tắt; catalog chuyên môn và AI provider thật chưa có theo quyết định đã chốt.
- Chưa nghiệm thu luồng customer đăng nhập thật → API → Nutrition → People → thực đơn thật; smoke chỉ xác minh khởi động, DB và cửa xác thực. Luồng nghiệp vụ dùng fixtures trong test.
- Legacy history dạng không hỗ trợ cần đối chiếu và chuyển đổi có chủ đích; không tự xóa hoặc suy diễn thành hồ sơ khỏe mạnh.
- Chưa làm importer/review/publish, quy tắc tương tác thuốc, backup/restore, retention hoặc production rollout. Phần này không commit/push trong lượt hiện tại; Markdown giữ local.
