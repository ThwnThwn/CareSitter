# Mục lục tài liệu CareSitter

> Cập nhật: 21/10/2026. Tài liệu Markdown dự án tập trung trong `plan/`, lưu local theo yêu cầu; chưa commit/push.

## Đọc trước

| Tài liệu | Nội dung |
| --- | --- |
| [Rule bắt buộc trước khi code](../AGENTS.md) | Yêu cầu đọc đầy đủ quy ước trước khi viết/sửa source; áp dụng toàn repository |
| [Quy ước code, tài liệu và secret](QUY_UOC_CODE_VA_SECRET.md) | Quy tắc áp dụng cho thay đổi mới, tên cấu hình đúng và kiểm chứng |
| [rule.frontend — Flutter + Riverpod](frontend/RULE_FRONTEND.md) | Bắt buộc đọc toàn bộ trước khi sửa Flutter; ranh giới tầng, state, lifecycle, formatter và tokens |
| [Prompt Stitch: xếp màn hình và bổ sung Nutrition](frontend/stitch/STITCH_PROMPTS.md) | Ba lượt prompt theo luồng, dựa trên source ngày 14/10/2026; phân biệt frame thiết kế với chức năng đã triển khai |
| [Hệ thống thiết kế bàn giao cho Stitch](frontend/stitch/DESIGN.md) | Theo yêu cầu mới, Customer/Nutrition dùng màu Landing teal; component, typography, trạng thái và giới hạn Nutrition |
| [Kiểm tra màn hình và phạm vi phi y tế](frontend/stitch/KIEM_TRA_MAN_HINH_PHI_Y_TE.md) | Đối chiếu route Customer/Caregiver/Admin/Landing, màn thiếu và nội dung y tế cần bỏ trong thiết kế |
| [Đối chiếu PRM323 Lab 2](frontend/stitch/PRM323_LAB2_DOI_CHIEU.md) | Tám màn đại diện, ba luồng, sáu page Figma, 12 slide và bằng chứng còn thiếu; phân biệt Stitch với bài nộp |
| [Đối chiếu PRM393 Persona Guideline 21/10](prm/PRM393_DOI_CHIEU_PERSONA_GUIDELINE_2026-10-21.md) | So sánh hồ sơ local với guideline chính thức và repo LAB2_PRM tại commit cố định; ma trận 10 tiêu chí, mâu thuẫn và checklist bổ sung evidence |
| [Ba luồng người dùng Lab 2](ux/user-flow.md) | Booking/thanh toán, theo dõi ca, Nutrition; happy, alternate và error/recovery |
| [Rà cấu trúc toàn dự án 13/10/2026](kiem-thu/PROJECT_STRUCTURE_AUDIT_2026-10-13.md) | Backend, Customer, Caregiver, Admin, Landing, Nutrition và AppHost; 37 kiểm tra kiến trúc pass, nợ còn lại và thứ tự sửa |
| [Khắc phục theo audit toàn dự án 13/10/2026](kiem-thu/PROJECT_STRUCTURE_FIXES_2026-10-13.md) | Customer/Caregiver, Wallet/Booking jobs, Nutrition, Admin và Landing AI; kết quả test local, Vercel và giới hạn Docker/PostGIS |
| [Dọn wrapper frontend 13/10/2026](kiem-thu/FRONTEND_WRAPPER_FIXES_2026-10-13.md) | Profile/password/addresses/Auth/Live map Customer; Auth/Home/map/list Caregiver; 267 và 96 test pass, chưa commit/push/APK |
| [Khắc phục cấu trúc frontend 13/10/2026](kiem-thu/FRONTEND_STRUCTURE_FIXES_2026-10-13.md) | Cách ly phiên, form hai app, booking, yêu cầu tư vấn/Admin; kết quả kiểm chứng và các nhóm còn lại |
| [Kết quả refactor frontend 12/10/2026](kiem-thu/FRONTEND_REFACTOR_2026-10-12.md) | Năm nhóm ưu tiên đã triển khai, kết quả analyze/test và phần còn lại |
| [Hoàn thiện kiến trúc Customer](kiem-thu/CUSTOMER_ARCHITECTURE_REFACTOR_2026-10-12.md) | Đợt Customer trước Caregiver: controller, toàn bộ giới hạn UI và kiểm chứng cuối |
| [Hoàn thiện kiến trúc Caregiver](kiem-thu/CAREGIVER_ARCHITECTURE_REFACTOR_2026-10-12.md) | Home/lịch/ca/tài khoản, lifecycle theo phiên, retry payout và 81 test local; dừng build APK theo yêu cầu |
| [Rà soát quy ước](RA_SOAT_QUY_UOC.md) | Những điểm đã sửa, bổ sung và giới hạn còn cần kiểm tra |
| [Kiến trúc hiện tại](tong-quan/ARCHITECTURE.md) | Thành phần, module và luồng tích hợp |
| [Báo cáo chức năng](tong-quan/BAOCAO_CHUC_NANG.md) | Các chức năng đã có, chưa có và phạm vi đã kiểm chứng |
| [Nguồn dinh dưỡng theo bệnh lý](tong-quan/NGUON_DINH_DUONG_THEO_BENH_LY.md) | Nguồn chính cho thực đơn Beneficiary: Dinh dưỡng lâm sàng, dữ liệu thành phần thực phẩm và khuyến nghị Việt Nam; bản PDF trong book/ |
| [Kế hoạch catalog và AI parser Nutrition](backend/NUTRITION_CATALOG_AI_IMPLEMENTATION_PLAN.md) | Các đợt triển khai để có bữa ăn có nguồn và phân tích ghi chú; pipeline duyệt/phát hành, phạm vi bệnh/thuốc và nghiệm thu API thật |
| [Kế hoạch test Nutrition trên iPhone](frontend/customer-app/NUTRITION_IPHONE_DEVICE_TEST_PLAN.md) | Mac/Xcode hoặc TestFlight; HTTPS backend, signing, catalog tổng hợp, happy path và ca lỗi iOS bắt buộc |
| [Kế hoạch phối hợp REST, gRPC, Kafka và SignalR](backend/REST_GRPC_KAFKA_INTEGRATION_PLAN.md) | Quyết định giao thức theo ranh giới hiện tại và backlog kiểm chứng sau khi hoàn thiện Nutrition |
| [Kế hoạch P2: 12 bữa và rule bệnh lý Nutrition](backend/NUTRITION_P2_CONTENT_PLAN.md) | P2A bữa nền, P2B rule tăng huyết áp/đái tháo đường, provenance, duyệt 64 tổ hợp và cổng nghiệm thu API |
| [Kế hoạch seed GraphRAG local cho Nutrition](backend/NUTRITION_LOCAL_GRAPHRAG_SEED_PLAN_2026-10-20.md) | Pipeline Python/Ollama local, graph nháp có provenance, benchmark, cổng quyền dữ liệu và ranh giới với catalog published |
| [Checklist G0 GraphRAG Nutrition local](backend/NUTRITION_LOCAL_GRAPHRAG_G0_2026-10-20.md) | Khóa quyền nguồn, môi trường offline, benchmark fixture và cổng go/no-go; chỉ là plan, chưa triển khai |
| [Nghiên cứu rule dinh dưỡng theo bệnh 16/10/2026](backend/NUTRITION_DISEASE_RULE_RESEARCH_2026-10-16.md) | Thứ tự lipid → T2D → béo phì → loãng xương → gout; profile, nutrient keys, hard block, nguồn chính thức và sáu nhóm tiếp tục chuyển chuyên gia |
| [Nguồn sách chăm sóc tổng quát](tong-quan/NGUON_SACH_THAM_KHAO.md) | Giáo trình trợ giúp chăm sóc để tham khảo vai trò caregiver; đã đính chính, không dùng làm nguồn quy tắc Nutrition |
| [Khởi chạy và kiểm tra local](tong-quan/README.md) | Lệnh backend, hai app và admin web |
| [Roadmap production 14 ngày](backend/ROADMAP_PRODUCTION_14_NGAY.md) | Phạm vi phát hành và công việc theo ngày |
| [CARTO và Google tùy chọn](cartodb-map-integration/huong-dan-su-dung.md) | Cấu hình bản đồ, token Basemaps và giới hạn hiện tại |
| [Thanh toán payOS](backend/PAYOS.md) | Cấu hình, callback và kiểm thử thanh toán |
| [Kế hoạch chat hỗ trợ trực tuyến](backend/SUPPORT_CHAT_IMPLEMENTATION_PLAN.md) | Vòng đời conversation, quyền xử lý, transaction/outbox, retry, đồng bộ, backlog và nghiệm thu Customer/Caregiver ↔ Admin; đã bổ sung sau review 15/10 |
| [Kế hoạch chat theo lịch chăm sóc](backend/BOOKING_PARTY_CHAT_IMPLEMENTATION_PLAN.md) | Customer ↔ caregiver đang được phân công; vòng đời theo booking, tin “Tôi sắp tới”, realtime, quyền và backlog |
| [Kế hoạch hoàn thiện Booking Chat](backend/BOOKING_CHAT_REMAINING_IMPLEMENTATION_PLAN.md) | Notification push, Admin/report/legal hold, test Flutter, CI và rollout phần còn lại |
| [Kế hoạch hoàn thiện và bàn giao 18/10](bao-cao/KE_HOACH_HOAN_THIEN_VA_BAN_GIAO_2026-10-18.md) | Gate sửa blocker Booking Chat/Nutrition, khép luồng production, CI/E2E/vận hành và gói bàn giao H0–H2 |
| [Thuật ngữ miền CareSitter](tong-quan/GLOSSARY.md) | Phân biệt booking chat, support chat, caregiver được phân công, quick message và system event |

## Cách tổ chức

```text
plan/
├── README.md
├── QUY_UOC_CODE_VA_SECRET.md
├── RA_SOAT_QUY_UOC.md
├── tong-quan/
├── backend/
├── frontend/
├── deploy/
├── docs/
├── cartodb-map-integration/
├── bao-cao/
└── kiem-thu/
```

Đã chuyển **73 tài liệu nguồn** từ repository, các Markdown ở `D:\EXE`, báo cáo frontend cũ và hướng dẫn APK vào đây. Giữ tên file/thư mục con để tránh ghi đè những file cùng tên như `README.md`, `PRODUCT.md` và `DESIGN.md`.

`AGENTS.md` ở workspace/repository cùng `frontend/landing-page/AGENTS.md` và `CLAUDE.md` giữ ở vị trí mà công cụ tự đọc. Rule yêu cầu đọc toàn bộ bản quy ước trước khi code. Dependency, bản build/preview và snapshot sao lưu không thuộc bộ tài liệu nguồn này. File SQL, source archive EF, ảnh và tài sản ứng dụng vẫn ở thư mục source; link tài liệu đã được điều chỉnh theo vị trí mới.

Các lệnh thực thi chạy tại thư mục source của repository/app được ghi trong từng tài liệu, **không chạy trong `plan/`**. Kết quả/ngày trong tài liệu lịch sử vẫn là kết quả ở lần rà soát đó, chưa phải xác nhận production hiện tại.

Các file Markdown trước đây đã tracked sẽ hiện là xóa ở vị trí cũ trong working tree; không stage/push những thay đổi này khi chỉ đẩy source. Mục `plan/` đã được ignore. Bản gốc và bảng ánh xạ di chuyển được sao lưu local tại `D:\EXE\.codex-output\markdown-reorganization-20261008`.

## Toàn bộ tài liệu theo nhóm

### Tổng quan dự án — 14 tài liệu

- [ARCHITECTURE.md](tong-quan/ARCHITECTURE.md)
- [BAOCAO_CHUC_NANG.md](tong-quan/BAOCAO_CHUC_NANG.md)
- [NGUON_SACH_THAM_KHAO.md — Nguồn sách và cách trích dẫn](tong-quan/NGUON_SACH_THAM_KHAO.md)
- [NGUON_DINH_DUONG_THEO_BENH_LY.md — Nguồn cho thực đơn Beneficiary](tong-quan/NGUON_DINH_DUONG_THEO_BENH_LY.md)
- [boicanh.md](tong-quan/boicanh.md)
- [BUSINESS_FLOW.md](tong-quan/BUSINESS_FLOW.md)
- [db.md](tong-quan/db.md)
- [DESIGN.md](tong-quan/DESIGN.md)
- [MEAL_RECOMMENDATION_PLAN.md](tong-quan/MEAL_RECOMMENDATION_PLAN.md)
- [NUTRITION_EDGE_CASE_IMPLEMENTATION_PLAN.md — Triển khai 9 tình huống Nutrition](tong-quan/NUTRITION_EDGE_CASE_IMPLEMENTATION_PLAN.md)
- [SELF_BOOKING_PLAN.md — Đặt cho tôi](tong-quan/SELF_BOOKING_PLAN.md)
- [PRODUCT.md](tong-quan/PRODUCT.md)
- [GLOSSARY.md — Thuật ngữ miền](tong-quan/GLOSSARY.md)
- [README.md](tong-quan/README.md)

### Backend và nghiệp vụ — 35 tài liệu

- [CAREGIVER_LIVE_TRACKING_PLAN.md](backend/CAREGIVER_LIVE_TRACKING_PLAN.md)
- [CHAT_RECOVERY_PLAN.md](backend/CHAT_RECOVERY_PLAN.md)
- [SUPPORT_CHAT_IMPLEMENTATION_PLAN.md — Chat hỗ trợ trực tuyến](backend/SUPPORT_CHAT_IMPLEMENTATION_PLAN.md)
- [BOOKING_PARTY_CHAT_IMPLEMENTATION_PLAN.md — Chat Customer ↔ Caregiver theo lịch](backend/BOOKING_PARTY_CHAT_IMPLEMENTATION_PLAN.md)
- [BOOKING_CHAT_REMAINING_IMPLEMENTATION_PLAN.md — Notification, Admin và test Flutter](backend/BOOKING_CHAT_REMAINING_IMPLEMENTATION_PLAN.md)
- [decisions.md](backend/decisions.md)
- [docs/issues/booking-checkin-outside-geofence-unreachable.md](backend/docs/issues/booking-checkin-outside-geofence-unreachable.md)
- [docs/issues/booking-domain-events-not-dispatched-or-outboxed.md](backend/docs/issues/booking-domain-events-not-dispatched-or-outboxed.md)
- [docs/issues/catalog-address-delete-masks-db-errors.md](backend/docs/issues/catalog-address-delete-masks-db-errors.md)
- [docs/issues/people-kyc-approval-missing-outbox.md](backend/docs/issues/people-kyc-approval-missing-outbox.md)
- [docs/issues/people-kyc-rejection-reason-not-persisted.md](backend/docs/issues/people-kyc-rejection-reason-not-persisted.md)
- [docs/issues/support-dispute-creation-missing-booking-authorization.md](backend/docs/issues/support-dispute-creation-missing-booking-authorization.md)
- [docs/issues/support-dispute-resolution-missing-outbox.md](backend/docs/issues/support-dispute-resolution-missing-outbox.md)
- [docs/issues/support-review-create-masks-db-errors.md](backend/docs/issues/support-review-create-masks-db-errors.md)
- [docs/legacy-ef-migrations/README.md](backend/docs/legacy-ef-migrations/README.md)
- [docs/LIVE_TRACKING.md](backend/docs/LIVE_TRACKING.md)
- [docs/MIGRATIONS.md](backend/docs/MIGRATIONS.md)
- [IDEMPOTENCY_PLAN.md](backend/IDEMPOTENCY_PLAN.md)
- [KAFKA_LOCAL.md](backend/KAFKA_LOCAL.md)
- [module.md](backend/module.md)
- [NUTRITION_ANALYSIS_SPEC.md](backend/NUTRITION_ANALYSIS_SPEC.md)
- [NUTRITION_SERVICE_RUNBOOK.md — Cấu hình service Nutrition độc lập](backend/NUTRITION_SERVICE_RUNBOOK.md)
- [NUTRITION_CATALOG_AI_IMPLEMENTATION_PLAN.md — Hoàn thiện catalog và AI parser](backend/NUTRITION_CATALOG_AI_IMPLEMENTATION_PLAN.md)
- [NUTRITION_P2_CONTENT_PLAN.md — 12 bữa và rule bệnh lý](backend/NUTRITION_P2_CONTENT_PLAN.md)
- [NUTRITION_DISEASE_RULE_RESEARCH_2026-10-16.md — Nguồn và gate cho các bệnh tiếp theo](backend/NUTRITION_DISEASE_RULE_RESEARCH_2026-10-16.md)
- [REST_GRPC_KAFKA_INTEGRATION_PLAN.md — Phối hợp giao thức theo ranh giới](backend/REST_GRPC_KAFKA_INTEGRATION_PLAN.md)
- [Nutrition staging — DB riêng, TLS/gRPC, migration và backup mã hóa](deploy/NUTRITION_STAGING.md)
- [NUTRITION_SERVICE_IMPLEMENTATION_2026-10-11.md — Kết quả triển khai và kiểm thử local](kiem-thu/NUTRITION_SERVICE_IMPLEMENTATION_2026-10-11.md)
- [PASSWORD_RECOVERY.md](backend/PASSWORD_RECOVERY.md)
- [PAYOS.md](backend/PAYOS.md)
- [PRODUCTION_PLAN.md](backend/PRODUCTION_PLAN.md)
- [PRODUCTION_PROGRESS.md](backend/PRODUCTION_PROGRESS.md)
- [PROMOTION_ADMIN.md](backend/PROMOTION_ADMIN.md)
- [ROADMAP_PRODUCTION_14_NGAY.md](backend/ROADMAP_PRODUCTION_14_NGAY.md)
- [SEC01_PLAN.md](backend/SEC01_PLAN.md)
- [SECURITY.md](backend/SECURITY.md)
- [tests/POSTGRESQL_TESTS.md](backend/tests/POSTGRESQL_TESTS.md)
- [VNPAY_READING_GUIDE.md](backend/VNPAY_READING_GUIDE.md)

### Ứng dụng và giao diện web — 16 tài liệu

- [admin-web/README.md](frontend/admin-web/README.md)
- [caregiver-app/DESIGN.md](frontend/caregiver-app/DESIGN.md)
- [caregiver-app/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md](frontend/caregiver-app/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md)
- [customer-app/assets/icons/GOOGLE_ASSET.md](frontend/customer-app/assets/icons/GOOGLE_ASSET.md)
- [customer-app/DESIGN.md](frontend/customer-app/DESIGN.md)
- [customer-app/GOOGLE_MAPS_LIVE_TRACKING.md](frontend/customer-app/GOOGLE_MAPS_LIVE_TRACKING.md)
- [customer-app/GOOGLE_SIGN_IN_SETUP.md](frontend/customer-app/GOOGLE_SIGN_IN_SETUP.md)
- [customer-app/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md](frontend/customer-app/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md)
- [customer-app/PRODUCT.md](frontend/customer-app/PRODUCT.md)
- [landing-page/DESIGN.md](frontend/landing-page/DESIGN.md)
- [landing-page/PRODUCT.md](frontend/landing-page/PRODUCT.md)
- [landing-page/README.md](frontend/landing-page/README.md)
- [stitch/DESIGN.md](frontend/stitch/DESIGN.md)
- [stitch/STITCH_PROMPTS.md](frontend/stitch/STITCH_PROMPTS.md)
- [stitch/KIEM_TRA_MAN_HINH_PHI_Y_TE.md](frontend/stitch/KIEM_TRA_MAN_HINH_PHI_Y_TE.md)
- [stitch/PRM323_LAB2_DOI_CHIEU.md](frontend/stitch/PRM323_LAB2_DOI_CHIEU.md)

### Tài liệu PRM323 Lab 2 — 5 tài liệu

- [Persona giả định](ux/persona.md)
- [Ba luồng người dùng](ux/user-flow.md)
- [Nhật ký thiết kế AI và bằng chứng còn thiếu](ai/ai-design-log.md)
- [Quyết định thiết kế](design-decisions.md)
- [Bàn giao Flutter](flutter-handoff.md)

### Hồ sơ PRM393 Persona — 5 tài liệu

- [Đối chiếu Persona Guideline và repository tham khảo](prm/PRM393_DOI_CHIEU_PERSONA_GUIDELINE_2026-10-21.md)
- [Hồ sơ Persona và thiết kế CareSitter](prm/PRM393_PERSONA_VA_THIET_KE_CARESITTER.md)
- [Hồ sơ minh chứng rà soát](prm/PRM393_MINH_CHUNG_RASOAT_HO_SO.md)
- [Ma trận P0/G0](prm/PRM393_P0_G0_EVIDENCE_MATRIX.md)
- [Ma trận responsive/accessibility](prm/PRM393_RESPONSIVE_ACCESSIBILITY_EVIDENCE.md)

### Triển khai — 1 tài liệu

- [README.md](deploy/README.md)

### Kiến trúc, quyết định và nghiệm thu — 11 tài liệu

- [admin-functional-review-2026-10-03.md](docs/admin-functional-review-2026-10-03.md)
- [adr/0001-clean-modular-monolith.md](docs/adr/0001-clean-modular-monolith.md)
- [architecture/01-context.md](docs/architecture/01-context.md)
- [architecture/02-container.md](docs/architecture/02-container.md)
- [architecture/adr-kafka-messaging.md](docs/architecture/adr-kafka-messaging.md)
- [architecture/kafka-messaging-runbook.md](docs/architecture/kafka-messaging-runbook.md)
- [backend-main-flow-review-2026-10-03.md](docs/backend-main-flow-review-2026-10-03.md)
- [firebase-setup.md](docs/firebase-setup.md)
- [phase-7-acceptance.md](docs/phase-7-acceptance.md)
- [phase-8-acceptance.md](docs/phase-8-acceptance.md)
- [release-roadmap.md](docs/release-roadmap.md)

### Kế hoạch tích hợp CARTO — 6 tài liệu

- [huong-dan-su-dung.md](cartodb-map-integration/huong-dan-su-dung.md)
- [phase-01-env-config.md](cartodb-map-integration/phase-01-env-config.md)
- [phase-02-map-widgets.md](cartodb-map-integration/phase-02-map-widgets.md)
- [phase-03-local-config-docs.md](cartodb-map-integration/phase-03-local-config-docs.md)
- [phase-04-verification.md](cartodb-map-integration/phase-04-verification.md)
- [plan.md](cartodb-map-integration/plan.md)

### Báo cáo đã lưu — 6 tài liệu

- [Kế hoạch hoàn thiện và bàn giao 18/10](bao-cao/KE_HOACH_HOAN_THIEN_VA_BAN_GIAO_2026-10-18.md)
- [api_technical_reference.md](bao-cao/api_technical_reference.md)
- [backend_flows_report.md](bao-cao/backend_flows_report.md)
- [bao_cao_ngay_08_09.md](bao-cao/bao_cao_ngay_08_09.md)
- [baocao.md](bao-cao/baocao.md)
- [fe_be_integration_report.md](bao-cao/fe_be_integration_report.md)

### Hướng dẫn kiểm thử và cài APK — 11 tài liệu

- [apk/2026-10-07/HUONG_DAN.md](kiem-thu/apk/2026-10-07/HUONG_DAN.md)
- [Sửa luồng cập nhật hồ sơ người thân](kiem-thu/BENEFICIARY_UPDATE_2026_10_11.md)
- [Đối chiếu source với hình container CareSitter — 11/10/2026](kiem-thu/KIEN_TRUC_CONTAINER_DOI_CHIEU_2026-10-11.md)
- [Nutrition: façade REST, gRPC và AppHost — 11/10/2026](kiem-thu/NUTRITION_GRPC_APPHOST_2026-10-11.md)
- [Nutrition: hồ sơ sức khỏe, DB và AppHost runtime — 11/10/2026](kiem-thu/NUTRITION_HEALTH_DATABASE_2026-10-11.md)
- [Nutrition: hạ tầng staging và kiểm thử local — 13/10/2026](kiem-thu/NUTRITION_STAGING_2026-10-13.md)
- [Nutrition: smoke qua API thật — 15/10/2026](kiem-thu/NUTRITION_API_SMOKE_2026-10-15.md)
- [Nutrition P4: câu hỏi, nguồn món và generate/replace/save qua ApiHost thật — 16/10/2026](kiem-thu/NUTRITION_P4_API_SMOKE_2026-10-16.md)
- [Nutrition: kịch bản hồ sơ thiếu thông tin — 15/10/2026](kiem-thu/NUTRITION_KICH_BAN_THIEU_THONG_TIN_2026-10-15.md)
- [Luồng đặt lịch chính: source, PostgreSQL race và Customer — 14/10/2026](kiem-thu/BOOKING_MAIN_FLOW_REVIEW_2026-10-14.md)
- [Sửa CI backend: lifetime EF trong integration fixture — 14/10/2026](kiem-thu/CI_BACKEND_FIX_2026-10-14.md)
- [Rà soát toàn bộ cấu trúc frontend — 12/10/2026](kiem-thu/FRONTEND_STRUCTURE_AUDIT_2026-10-12.md)
