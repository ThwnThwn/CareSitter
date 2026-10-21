# CareSitter — Bản đồ Module

Cập nhật 2026-10-04. **Modular monolith** (.NET 8 / EF Core 8 / PostgreSQL + PostGIS): 7 module nghiệp vụ, 3 project Shared và ApiHost. Mỗi module sở hữu một schema; EF map/query, SQL quản lý schema.

## Sở hữu dữ liệu

| Module / schema | Trách nhiệm | Bảng |
|---|---|---|
| Identity / `identity` | Danh tính, phiên, thiết bị, audit | users, user_devices, refresh_tokens, audit_logs |
| Catalog / `catalog` | Địa chỉ, media, dịch vụ, giá | addresses, media_assets, service_types, pricing_rules |
| People / `people` | Beneficiary, liên hệ gia đình, caregiver/KYC | beneficiaries, family_contacts, caregiver_profiles |
| Booking / `booking` | Ca chăm sóc, matching, giữ slot, checklist, tracking/sync | bookings, booking_assignments, caregiver_slot_holds, care_tasks, package_task_templates, care_timeline_events, gps_tracks, booking_sync_events; checkout_reviews còn trong SQL |
| Payments / `payments` | Intent, reconciliation, ví/ledger, refund/payout | payment_intents, payment_webhooks, outbox_messages, ledger_entries, wallet_accounts, payout_requests |
| Support / `support` | Tranh chấp, ticket, review, inbox | disputes, support_tickets, reviews, notifications |
| Promotion / `promotion` | Ưu đãi, phạm vi dịch vụ, reservation/redeem | promotions, promotion_service_scopes, promotion_redemptions |

Có entity/bảng không đồng nghĩa production-ready. Các gate FIN01/FIN02/SEC01 và vận hành nằm trong [PRODUCTION_PROGRESS.md](PRODUCTION_PROGRESS.md).

## Cấu trúc thực tế

```text
backend/
├── CareSitter.sln
├── caresitter-be/
│   ├── ApiHost/                          # composition root, auth/middleware
│   │   ├── Controllers/                  # metadata/dashboard
│   │   ├── Endpoints/                    # media Minimal API
│   │   └── Routing/, Security/, OpenApi/, Persistence/, wwwroot/
│   ├── Shared/
│   │   ├── CareSitter.SharedKernel/       # Domain, Results, ValueObjects, module abstraction
│   │   ├── CareSitter.Contracts/          # Services/ports, Routing DTOs, IntegrationEvents
│   │   └── CareSitter.Infrastructure/     # Auth, Media, Email, Hubs, Outbox, Persistence, Security, Time
│   └── Modules/<Name>/
│       ├── <Name>Module.cs                # DI + DbContext/adapter registration
│       ├── Domain/                        # entities, transitions, invariants
│       ├── Application/                   # Commands, Queries, Ports, Models, Mapping, Errors
│       ├── Infrastructure/                # EF, provider IO, workers
│       └── Controllers/                   # HTTP contracts và controller gọi MediatR
├── init-db/                               # SQL có thứ tự: nguồn chuẩn schema
├── scripts/                               # migration, baseline, smoke, process regression
├── tests/                                 # 7 module unit suites + Routing + Integration + Architecture
└── docs/                                  # migration runbook + EF archive không compile
```

Cả 7 module đều có Application/Controllers. ApiHost nạp controller bằng `AddApplicationPart` và `MapControllers`; `IModule.MapEndpoints` hiện không map nghiệp vụ. Routing là adapter tại host, không phải module thứ tám.

## Ranh giới

- Module project chỉ reference SharedKernel, Contracts, Infrastructure; không reference project/namespace module khác.
- Controllers gọi Application, không query EF/gọi Infrastructure trực tiếp. Application không import EF, ASP.NET hay HTTP/cache/config adapters. Domain không phụ thuộc tầng ngoài.
- Cross-module port/DTO đặt trong Contracts, implementation thuộc module sở hữu dữ liệu. Không truyền DbContext/entity nội bộ qua boundary.
- SQL FK UUID có thể qua schema nhưng runtime không query chéo schema. Customer/Admin trỏ `identity.users`; Caregiver nghiệp vụ trỏ `people.caregiver_profiles`, không nhầm với user ID.
- Tách policy không thay thế lock/transaction/outbox và kiểm tra race lúc ghi.

Đây là hàng rào source tests, chưa tách assembly theo từng layer. SharedKernel còn framework reference; Domain Catalog/People dùng NetTopologySuite. Không tuyên bố core đã độc lập mọi library.

## Quy ước Application và HTTP contracts

Nhóm use case **theo CQRS**, sau đó theo chủ đề và use case; một handler mới cho mỗi use case. HTTP request/response và mapper sang command thuộc Controllers, còn kết quả trả từ handler thuộc Application:

```text
Application/
├── Commands/<Feature>/<UseCase>/
│   ├── <UseCase>Command.cs
│   ├── <UseCase>CommandHandler.cs
│   └── <UseCase>CommandValidator.cs       # nếu cần
├── Commands/Shared/                       # kết quả dùng chung giữa các command
├── Queries/<Feature>/<UseCase>/
│   ├── <UseCase>Query.cs
│   ├── <UseCase>QueryHandler.cs
│   └── <UseCase>Dto.cs                    # kết quả riêng của query, nếu có
├── Queries/Shared/                        # DTO/enum dùng chung nhiều query
├── Ports/I<Feature>Store.cs
├── Models/<InternalSnapshot>.cs
├── Mapping/                               # mapping nội bộ Application
├── Errors/<Module>Errors.cs
└── Services/                              # logic điều phối dùng chung nhiều use case, nếu cần

Controllers/
├── <Feature>Controller.cs
└── Contracts/
    ├── <Feature>/Requests/<Action>Request.cs   # HTTP input
    ├── <Feature>/Responses/<Action>Response.cs # HTTP-only output, nếu có
    └── Mapping/<Feature>RequestMapper.cs       # mapper HTTP request sang command

Domain/Policies/<Feature>Policy.cs         # chỉ khi không phụ thuộc Application/IO
```

- Controller bind HTTP contract, map sang command/query rồi gọi MediatR. Validator của command vẫn kiểm nghiệp vụ; metadata/model validation HTTP và authorization giữ nguyên.
- DTO kết quả của handler ở ngay use case nếu chỉ một nơi dùng, hoặc ở `Queries/Shared`/`Commands/Shared` nếu nhiều use case dùng. Tên `Response` trong Application không tự động biến type thành HTTP contract: đó là kết quả của handler, được controller tuần tự hóa khi trả API. HTTP-only response nằm trong `Controllers/Contracts`.
- Các model nội bộ như BookingPage/BookingSyncDeltaResult, GoogleIdentity, IssuedTokenPair và VNPayFullRefundRequest ở `Models`; controller không trả chúng ra API. API sync dùng BookingSyncResponse. Provider refund model giữ factory và validation riêng, không dùng tên Request để suy ra đó là body client.
- Đợt sắp xếp thư mục giữ tên type và phần lớn namespace cũ để hạn chế ảnh hưởng tới reflection, OpenAPI schema và các chỗ gọi. Vì vậy namespace C# của một số HTTP contract vẫn mang tên `.Application` hoặc `.Controllers` cũ; đường dẫn file thể hiện boundary mới.
- Không đổi JSON casing/enum/null/default để khớp tên thư mục. Đặc biệt VNPAY IPN giữ `RspCode`/`Message`, booking sync giữ bỏ qua Items/HasMore khi null, KYC dùng media IDs (không public URL); Google role vẫn do endpoint quyết định.
- Policy thuần chỉ dùng Domain và SharedKernel ở `Domain/Policies` (Google login role và Promotion eligibility). Matching/PaymentIntent policy vẫn ở Application vì còn phụ thuộc snapshot/kiểu của Application hoặc Contracts.
- Handler điều phối qua port. Policy nhận snapshot/time/options tường minh, trả decision/result; không đọc DB/HTTP/`UtcNow`, không nhận `IOptions`.
- Domain giữ invariant/state machine; Application policy kết hợp snapshot; Infrastructure lấy dữ liệu, giữ lock/transaction và thực thi side effect.
- Command và query của cả 7 module nằm trong `Commands/<Feature>/<UseCase>` và `Queries/<Feature>/<UseCase>`. Handler gộp cũ của Booking/Promotion đã tách theo use case; không thêm handler mới gộp nhiều request.

| Module | Chủ đề use case |
|---|---|
| Identity | Authentication, Profile, AdminUsers, Devices, Common |
| Catalog | Addresses, Services, Places |
| People | Beneficiaries, FamilyContacts, Caregivers, Kyc, Common |
| Booking | Bookings, Matching, Tracking, CareTasks, ChecklistTemplates |
| Payments | PaymentIntents, Wallet, Ledger, Reconciliation, VNPay, Payouts, Webhooks, Common |
| Promotion | Promotions |
| Support | Disputes, Notifications, Reviews, Tickets, Common |

## Policy đã tách và phạm vi còn lại

| Feature | Application quyết định thuần | Infrastructure còn giữ |
|---|---|---|
| Booking matching | eligibility, kỹ năng/khoảng cách, shortlist, điểm và tie-break/rank | đọc profile/address/conflict, route matrix, offer persistence/expansion, SignalR/notification |
| Payments intent | admission/deadline, previous attempt, retry provider state, conflict sau finalization | query VNPAY, finalizer, giữ slot, unique-race, intent/outbox persistence |
| Promotion | thời gian/service, khách mới, quota/discount, binding reservation | usage/history query, loại booking hiện tại khỏi count, row lock, transaction, refresh/redeem/release |

Đây là tách dần, chưa chuyển hết orchestration khỏi Infrastructure. Lát tiếp theo cần regression/race tests và port rõ ràng, không chỉ chuyển file EF sang Application.

## Migration/mapping

Theo [docs/MIGRATIONS.md](docs/MIGRATIONS.md). SQL là cơ chế duy nhất; [EF Identity archive](docs/legacy-ef-migrations/README.md) nằm ngoài project, không compile/chạy. Không sửa SQL đã triển khai hay chạy EF rollback.

Map rõ schema/cột snake_case, jsonb/geography và constraint; generated columns thuộc DB. Trạng thái varchar CHECK dùng string tương thích DB; không tự đổi enum serialization khi refactor. Trigger/RLS cần test bằng đúng DB role trước khi dựa vào chúng cho production authorization.

## Tests và thư mục cũ

- Mỗi module có `CareSitter.Modules.<Name>.UnitTests`: domain/policy, không cần DB thật. Bộ mới là baseline ban đầu, không có nghĩa coverage đã đầy đủ.
- IntegrationTests vẫn giữ contract API, DI, auth và PostgreSQL/race tests; không bỏ coverage chỉ vì có unit suite mới.
- ArchitectureTests duyệt mọi module Application (gồm Promotion), Domain/Controller/boundary/SQL. HTTP contract guard chặn khai báo nhiều type, trộn CQRS/port và khai báo DTO trong controller class. Integration guard kiểm compiled HTTP contract không lộ entity Domain và controller body không bind MediatR request; regression JSON/mapping bao phủ input mới, Google role, KYC, VNPAY IPN và sync null semantics. ProjectReference đọc bằng XML, bắt sibling/conditional reference; dynamic reference phải review guard riêng. Runtime không được có EF schema management.
- Baseline tự tìm mọi test project, build Release, fresh DB + legacy upgrade/replay, smoke, TRX đủ và 0 fail/skip; chạy lặp 2 lần.
- Các thư mục rỗng cũ `ApiHost/Jobs`, `ApiHost/Matching`, `Identity/Endpoints`, `Identity/Application/{Audit,AuthSessions,Push,Security}` không có chức năng runtime và không nên tái tạo.
- `Identity/Modules/obj` là residue tooling, không phải module lồng. Generated `bin/obj` không dùng mô tả kiến trúc hay đưa vào Git.
