# C1 - Container Architecture - CareSitter

**Diagram type:** C4 Container (standard level 2; labelled C1 for the assignment).

**Scope:** Core applications, data stores, and proposed Nutrition, gRPC, and Kafka flows.

**Audience:** Lecturer and technical project team.

## Overview

The existing backend is a modular monolith: Identity, People, Catalog, Booking, Payments, Support, and Promotion run inside one ASP.NET Core API process. Hangfire and the Payments outbox worker also run there. Folder/module boundaries and PostgreSQL schemas are not separate deployed microservices.

The proposed extension adds a Nutrition service accessed through gRPC, a logically isolated Nutrition store, Kafka, and an independent notification consumer. The diagram emphasizes these core flows; Google Identity, Cloudinary, address/routing providers, and direct mobile map-tile connections are expanded in C0 and intentionally omitted here to reduce crossings. The landing page and its assistant are excluded from both new views.

## Diagram

![C1 - CareSitter Container Architecture](../../../docs/architecture/figures/c1-container.png)

Editable source: page **C1 - Container Architecture with Nutrition (Proposed)** in [C.drawio](../../../../C.drawio).

## Legend

- Navy rounded boxes: people. Bright blue rectangles: application containers. Dark blue cylinders: databases/cache. The dark blue rectangle is the Kafka broker. Gray boxes: external systems. All element text is white, matching the supplied reference.
- Dashed proposed links/borders and `*`: proposed scope. Proposed elements use the same colors as their types. The dashed gray enclosing outline is the software-system boundary, not a planned container.
- Black arrows: REST, gRPC, and external communication. Red arrows: Kafka event flows. Green arrows: Redis cache access. Gray arrows: SQL database access. Relationship labels use dark text on a light gray background.
- Cylinders represent data stores, not necessarily distinct physical database servers. Box dimensions have no workload/scaling meaning.
- Arrows are unidirectional request or data flows; ordinary request responses are implied. A callback is shown separately.
- The Kafka-to-worker arrow shows event delivery. The consumer establishes its own Kafka subscription/polling connection; Kafka does not initiate an HTTP request to the worker.
- Following the requested sample, boxes contain only the name and `[technology]` (or `[Person]` / `[External System]`). Shape/color and the Elements table identify each type; responsibilities are listed here rather than inside boxes. Edge labels show concise protocols or Publish/Consume; their full intent is in Key relationships. `Mobile UI` and `Web UI` describe human interaction, not network protocols.

| Abbreviation | Meaning |
|---|---|
| API | Application Programming Interface |
| REST | Representational State Transfer |
| HTTPS / HTTP | Hypertext Transfer Protocol, with / without TLS |
| TLS | Transport Layer Security |
| WS / WSS | WebSocket / WebSocket over TLS |
| HTTP/2 | Version 2 of HTTP, transport for gRPC |
| gRPC | Remote procedure call framework using HTTP/2 and Protocol Buffers |
| SQL | Structured Query Language, over the PostgreSQL wire protocol through Npgsql |
| RESP | Redis Serialization Protocol |
| SPA | Single-Page Application |
| EF Core | Entity Framework Core |
| JWT | JSON Web Token |
| GPS | Global Positioning System |
| OTP | One-Time Password |
| SMTP | Simple Mail Transfer Protocol |
| IPN | Instant Payment Notification |
| FCM | Firebase Cloud Messaging |
| AI | Artificial intelligence |

## Elements

| Element | Type | Technology | Responsibility |
|---|---|---|---|
| Customer / Family | Person | - | Arranges care and selects proposed meals. |
| Caregiver | Person | - | Provides care and updates shifts. |
| Administrator | Person | - | Operates the platform. |
| Customer App | Application container | Flutter | Booking, arrival tracking, and proposed meal selection. |
| Caregiver App | Application container | Flutter | Shift operations and GPS sending. |
| Admin Web App | Browser application container | React SPA | Administration and proposed recipe review. |
| Edge Proxy | Application container | Caddy 2 | Terminates TLS and routes API, SignalR, and static-asset requests. |
| Admin Hosting | Application container | Nginx | Serves the compiled React assets; browser SPA execution is separate. |
| Backend API | Application container | ASP.NET Core 8 / MediatR / EF Core | Hosts seven modules, REST, JWT, SignalR, Hangfire, and current outbox processing. |
| Care Database | Data store | PostgreSQL 16 / PostGIS 3.4 | Stores module data, location snapshots, outbox records, and production Hangfire state. |
| Auth Cache | Data store | Redis 7 | Stores OTPs and token-revocation data. It is not the Kafka broker or a SignalR backplane in this diagram. |
| Nutrition Service* | Proposed application container | ASP.NET Core / gRPC | Accepts authorized profile snapshots, applies reviewed rules, and returns meal candidates. |
| Nutrition Store* | Proposed data store | PostgreSQL | Owns recipes, nutrition facts, rules, and saved menu selections. |
| Message Broker* | Proposed event-stream container | Apache Kafka | Carries durable booking, payment, and Nutrition events. |
| Notification Worker* | Proposed application container | .NET BackgroundService | Consumes events, persists notification records through the API, and requests email/push delivery. |
| VNPay | External system | HTTPS | Processes payments and sends status callbacks. |
| Nutrition AI Provider* | Proposed external system | HTTPS; provider unconfirmed | Optionally extracts reported health-profile facts for customer confirmation. |
| Gmail SMTP | External system | SMTP | Delivers current verification email and proposed worker email. |
| Firebase Cloud Messaging | External system | Firebase Admin SDK / HTTPS | Delivers current API push and proposed worker push. |

## Key relationships

| From | To | Intent | Protocol / Technology |
|---|---|---|---|
| Customer / Family | Customer App | Book care and follow arrival | User interaction |
| Caregiver | Caregiver App | Update shifts | User interaction |
| Administrator | Admin Web App | Manage care operations | User interaction |
| Customer App | Edge Proxy | Book care and receive arrival updates | REST / HTTPS; SignalR / WSS |
| Caregiver App | Edge Proxy | Operate shifts and send GPS fixes | REST / HTTPS |
| Admin Web App | Edge Proxy | Invoke admin APIs and fetch web assets | HTTPS |
| Edge Proxy | Backend API | Forward API and hub traffic | HTTP / WebSocket on the internal network |
| Edge Proxy | Admin Hosting | Fetch compiled React assets | HTTP on the internal network |
| Backend API | Care Database | Read and write care records, jobs, and outbox state | SQL / Npgsql |
| Backend API | Auth Cache | Cache and validate auth data | RESP |
| Backend API | Nutrition Service* | Request meal options from an authorized profile snapshot | gRPC / HTTP/2* |
| Nutrition Service* | Nutrition Store* | Read recipes/rules and persist menu selections | SQL / Npgsql* |
| Backend API | Message Broker* | Publish booking/payment events through an adapted outbox | Kafka protocol* |
| Nutrition Service* | Message Broker* | Publish NutritionReady | Kafka protocol* |
| Message Broker* | Notification Worker* | Deliver subscribed care events | Kafka protocol* |
| Notification Worker* | Backend API | Save notification records under module ownership | Internal REST / HTTP* |
| Backend API | VNPay | Create or query payments | HTTPS |
| VNPay | Backend API | Confirm payment through the proxy-routed IPN endpoint | HTTPS at the public edge; internal proxy forwarding is elided |
| Backend API | Gmail SMTP | Send verification email | SMTP |
| Backend API | Firebase Cloud Messaging | Send current push notifications | HTTPS |
| Notification Worker* | Gmail SMTP | Send event-triggered email | SMTP* |
| Notification Worker* | Firebase Cloud Messaging | Send event-triggered push | HTTPS* |
| Nutrition Service* | Nutrition AI Provider* | Optionally extract reported profile facts | HTTPS*; provider unconfirmed |

## Notable architectural decisions

1. **Respect runtime boundaries.** The seven business modules remain within Backend API. Listing them in documentation keeps C1 at Container level and avoids labelling a modular monolith as seven microservices. The API description's outbox is existing infrastructure; its Kafka publishing adapter is proposed.
2. **Add one purposeful service.** Nutrition provides a useful independent gRPC boundary for the proposed assignment extension. The API performs customer/beneficiary authorization and passes a bounded snapshot; Nutrition does not query the People schema directly.
3. **Separate synchronous and asynchronous flows.** gRPC returns meal candidates; Kafka carries business events for eventual notification delivery. Publishing and consuming require new adapters and contracts; an in-process MediatR publish is not Kafka.
4. **Retain current delivery during migration.** Current API email/push arrows are solid. Proposed worker delivery is dashed. Implementation must choose event ownership and a cutover flag per notification type to avoid duplicate sends.
5. **Keep notification records under Support/API ownership.** The worker uses a proposed authenticated internal endpoint rather than writing module tables directly. This adds an API dependency and requires retry/idempotency when that API is unavailable.
6. **Isolate Nutrition data logically.** Nutrition Store is a separately owned database/schema boundary. MVP hosting may share a PostgreSQL instance if roles prevent cross-module access; a separate physical server is not implied.
7. **Use configuration from environment.** Existing Compose receives environment variables. New service addresses, broker settings, credentials, and feature flags must follow that convention. This diagram adds no appsettings configuration.
8. **Keep the diagram readable.** C0 contains the full external-service list. C1 focuses on core runtime and distributed flows; class structure, module schemas, deployment networks, migrations, and CI/CD belong in separate views.
9. **Follow the supplied visual reference.** Keep the verified runtime boundaries and rename neither modules nor providers to those from the sample. Apply its application/database/broker shapes and color conventions, and show only Customer / Family, Caregiver, and Administrator as actors. Omit the landing page, its actor, and its assistant connections as requested.

## Assumptions and unresolved implementation choices

- Nutrition, its store, Kafka, the notification consumer, and the worker-to-API persistence endpoint are proposals. They are not present in the current Compose file or verified as deployed.
- Event names illustrate intended contracts. Topic names, partitions, retention, schema versions, consumer groups, credentials, transport security, and dead-letter handling remain implementation decisions.
- Proposed publishing requires durable outbox dispatch with idempotent consumers. Retry and replay must not duplicate notification records or provider sends.
- The Nutrition gRPC transport and worker REST authentication need explicit service credentials and network access controls. The diagram states protocol intent, not a completed security configuration.
- Kafka payloads should contain identifiers and bounded business-event facts, excluding raw health descriptions. Optional extraction must return reported facts for customer confirmation rather than inventing diagnoses or thresholds.
- The AI provider for Nutrition is undecided. A rule-based recommendation path should work without that adapter. The external provider node is generic and optional.
- Existing verification email remains in the Identity/API flow. Not every current notification must move to the proposed worker.
- Nutrition's deployment target runtime has not been verified.
- The inspected Compose uses PostgreSQL-backed Hangfire. Local environments may differ. No SignalR Redis backplane is implied by Auth Cache.
- Solid arrows describe code-supported capabilities. Live external availability, production configuration, background GPS behavior, and throughput have not been tested by this diagram task.

## Evidence and review

- [Current deployment](../../../deploy/compose.yml) and [proxy routing](../../../deploy/Caddyfile): API, admin hosting, Caddy, PostgreSQL/PostGIS, Redis, and migration job.
- [API composition](../../../backend/caresitter-be/ApiHost/Program.cs): modules, Redis, routing adapters, SignalR, and Hangfire.
- [Payments outbox dispatcher](../../../backend/caresitter-be/Modules/Payments/Infrastructure/PaymentOutboxDispatcher.cs): currently publishes through MediatR inside the process.
- [Nutrition planning](../../tong-quan/MEAL_RECOMMENDATION_PLAN.md): proposed customer meal suggestions.

Applied the [c4-model Update workflow](https://github.com/cheriftj/c4-model-skill/blob/main/skills/c4-model/mode-update.md) and [review checklist](https://github.com/cheriftj/c4-model-skill/blob/main/skills/c4-model/review-checklist.md). Checked explicit title/type/scope, runtime boundaries, element technologies/responsibilities, directed intent/protocol labels, legends, assumptions, and cross-level consistency. Both new draw.io pages were exported and visually inspected. Original page XML was compared against the pre-change backup; neither original page changed. No application behavior or deployment was changed.

## Links to other levels

- [C0 - System Context](01-context.md)
- [Existing modular-monolith ADR](../adr/0001-clean-modular-monolith.md)
