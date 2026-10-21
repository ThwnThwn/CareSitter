# Kết quả smoke test Nutrition qua API thật

Thời gian chạy: 15/10/2026, múi giờ Asia/Saigon. Luồng được gọi qua REST façade của ApiHost tại `http://localhost:5033`; ApiHost gọi Nutrition bằng gRPC và Nutrition dùng PostgreSQL do AppHost quản lý. Ba feature flag Nutrition chỉ được bật trong tiến trình smoke test.

## Hạ tầng và xác thực

| Request | Kết quả |
| --- | --- |
| `GET /health/live` | `200`, `{"status":"ok"}` |
| `GET /health/ready` | `200`, PostgreSQL/Redis/Kafka đều `Healthy` |
| `GET /api/v1/nutrition/capabilities` không token | `401` |
| `POST /api/v1/auth/login/password` với customer seed | `200`, role `CUSTOMER`; token không ghi vào báo cáo |
| `GET /api/v1/nutrition/capabilities` có token | `200`, cả `enabled`, `assessmentsEnabled`, `recommendationsEnabled` là `true` |

## Kịch bản 1: hồ sơ hoàn toàn thiếu dữ liệu dinh dưỡng

Tạo beneficiary thử nghiệm qua API trả `201`. `GET health-profile` trả revision `1`, dị ứng `unknown`, chưa có `healthHistory`, bệnh hoặc thuốc.

`POST /nutrition-assessments` trả `202` và resource `queued`. Lần poll đầu trả `200`:

```json
{
  "status": "needs_information",
  "data": {
    "decision": {
      "state": "needs_information",
      "reasonCodes": ["missing_information"],
      "missingFields": [
        "foodAllergyStatus",
        "conditionsStatus",
        "healthHistory/nutrition/medicationsStatus",
        "healthHistory/nutrition/feedingRoute",
        "healthHistory/nutrition/swallowingStatus",
        "healthHistory/nutrition/fluidRestriction",
        "healthHistory/nutrition/electrolyteRestriction"
      ],
      "allowedActions": ["edit_health"]
    }
  }
}
```

Response đầy đủ: [nutrition-api-missing-info-20261015.json](../../backend/artifacts/nutrition-api-missing-info-20261015.json).

## Kịch bản 2: đã xác nhận không bệnh và không dị ứng

`PATCH health-profile` trả `200`, revision tăng từ `1` lên `2`, đồng thời server ghi `allergyConfirmedAt` và `schemaVersion: 1`.

Assessment đi qua `queued` rồi trả:

```json
{
  "status": "needs_information",
  "data": {
    "decision": {
      "state": "needs_information",
      "reasonCodes": ["missing_information"],
      "missingFields": [
        "healthHistory/nutrition/medicationsStatus",
        "healthHistory/nutrition/feedingRoute",
        "healthHistory/nutrition/swallowingStatus",
        "healthHistory/nutrition/fluidRestriction",
        "healthHistory/nutrition/electrolyteRestriction"
      ],
      "allowedActions": ["edit_health"]
    }
  }
}
```

Response đầy đủ: [nutrition-api-partial-info-20261015.json](../../backend/artifacts/nutrition-api-partial-info-20261015.json).

## Kịch bản 3: hồ sơ cấu trúc đầy đủ

Hồ sơ khai không dị ứng, không bệnh, không dùng thuốc, ăn qua miệng, nuốt bình thường, không hạn chế nước hoặc điện giải.

| Bước | HTTP | Trạng thái nghiệp vụ |
| --- | --- | --- |
| Tạo beneficiary | `201` | Đã tạo |
| PATCH health-profile | `200` | Revision `2` |
| Tạo assessment | `202` | `queued` |
| Poll assessment | `200` | `awaiting_confirmation` |
| Xác nhận assessment | `200` | Resource `confirmed`, decision `eligible` |
| Yêu cầu thực đơn | `200` | `no_content` |

Response cuối khi yêu cầu thực đơn:

```json
{
  "status": "no_content",
  "data": {
    "plannedDate": "2026-10-15",
    "meals": [],
    "appliedRules": [],
    "decision": {
      "state": "no_content",
      "reasonCodes": ["catalog_unavailable"],
      "allowedActions": ["edit_health"]
    },
    "catalogRevision": 1
  }
}
```

Response đầy đủ: [nutrition-api-complete-flow-20261015.json](../../backend/artifacts/nutrition-api-complete-flow-20261015.json).

## Kịch bản 4: hồ sơ đầy đủ nhưng có ghi chú tự do

Ghi chú dùng để test: `Beni hay khát nước, gia đình nghi tiểu đường.` Các trường cấu trúc còn lại đều đầy đủ.

Assessment được nhận với HTTP `202`, sau đó poll trả HTTP `200`:

```json
{
  "status": "failed",
  "data": {
    "decision": {
      "state": "failed",
      "reasonCodes": ["nutrition.ai_unavailable"],
      "allowedActions": ["retry"]
    },
    "errorCode": "nutrition.ai_unavailable",
    "retryable": false
  }
}
```

Response đầy đủ: [nutrition-api-free-text-20261015.json](../../backend/artifacts/nutrition-api-free-text-20261015.json).

## Kết luận

Façade REST, JWT customer, People health-profile, gRPC Nutrition, worker assessment và PostgreSQL hoạt động cùng nhau trong runtime thật. Việc phát hiện trường thiếu và luồng xác nhận chạy đúng. Chức năng chưa tạo được thực đơn thực tế vì catalog runtime chưa có nội dung đã duyệt. Phân tích ghi chú tự do cũng chưa chạy vì chưa cấu hình AI parser.

Các beneficiary thử nghiệm đều được xóa qua API sau khi thu response; mỗi lệnh xóa trả `204`.
