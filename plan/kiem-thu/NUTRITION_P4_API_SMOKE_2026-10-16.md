# Kết quả P4 Nutrition qua ApiHost thật

Thời gian chạy: 16/10/2026, múi giờ Asia/Saigon. Đây là nghiệm thu kỹ thuật M1 bằng dữ liệu tổng hợp; không phát hành bundle tăng huyết áp P2 và không thay thế duyệt chuyên môn.

## Phạm vi chạy

- Chạy process `CareSitter.ApiHost` thật tại `http://localhost:5033`, không dùng mock hay `TestServer`.
- ApiHost gọi process Nutrition thật qua gRPC HTTP/2 tại cổng nội bộ; Nutrition đọc PostgreSQL 18 thật.
- Tạo database dùng một lần, áp đủ năm migration, publish bundle `p4-api-smoke` bằng ba actor importer/reviewer/publisher tách biệt.
- Health parser/provider giữ tắt. Bundle chỉ chứa món và citation tổng hợp QA, ghi rõ không phải công thức hoặc hướng dẫn dinh dưỡng thực tế.

Aspire orchestration project không được dùng trong lần chạy này vì máy hiện có .NET SDK 8/9 nhưng project pin SDK `10.0.401`. Điều này không thay đổi đường request được kiểm: REST vẫn đi qua executable ApiHost thật, gRPC Nutrition và PostgreSQL; build/chạy orchestration Aspire còn là kiểm tra hạ tầng riêng ở P5.

## Kết quả

| Kiểm tra | Kết quả |
| --- | --- |
| Capabilities không JWT | `401` |
| Đăng nhập customer và capabilities | `200`; ba feature flag bật, `freeTextParserReady=false` |
| Hồ sơ thiếu dữ liệu | `needs_information`; đúng 3 câu hỏi có ID ổn định: dị ứng, bệnh lý, thuốc |
| Hồ sơ cấu trúc đầy đủ | `awaiting_confirmation` |
| Xác nhận | resource `confirmed`, decision `eligible` |
| Gợi ý | `suggested`, đúng 3 bữa |
| Lựa chọn thay bữa trưa | đúng 1 lựa chọn hợp lệ |
| Đổi món | recommendation mới `suggested` |
| Lưu thực đơn | `saved`, 3 bữa |
| Metadata nguồn | có ID, tên, cơ quan, năm, ngày đối chiếu trên món/option/plan; không có `fileSha256` |

Artifact JSON đã che credential/token: [result.json](../../backend/artifacts/nutrition-p4-smoke/2a3c1f6c42d445b6b1ebf1d6813d858e/result.json).

## Dọn dữ liệu

- Beneficiary tổng hợp: xóa qua API, HTTP `204`.
- Phiên đăng nhập: revoke qua API, HTTP `204`.
- Catalog tổng hợp: chuyển `retired` bằng publisher actor.
- Database dùng một lần: drop thành công; không còn database tên `caresitter_nutrition_smoke_*`.
- Process ApiHost/Nutrition đã dừng; các cổng `5033`, `5035`, `5036` đã trống.
- PostgreSQL bootstrap local dùng cho test đã dừng sạch sau lượt regression; dữ liệu local không bị xóa/reset.

## Regression cùng lát cắt

| Bộ kiểm tra | Kết quả |
| --- | --- |
| Nutrition + PostgreSQL thật | 112 pass, 0 fail, 0 skip |
| `NutritionGatewayTests` | 28 pass, 0 fail, 0 skip |
| Flutter Nutrition | 23 pass; `flutter analyze` không có issue |
| Compose offline + cú pháp script deploy | pass |

Test ops đầy đủ gồm backup/restore chưa chạy lại vì máy không có executable `age`; không ghi nhận mục đó là pass. P5 vẫn còn ma trận HTTP/staging T04–T14, TLS staging, thiết bị thật, latency/cost, rollback và các gate M2/provider.
