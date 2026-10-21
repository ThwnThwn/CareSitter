# C0 - System Context - CareSitter

**Diagram type:** C4 System Context (standard level 1; labelled C0 for the assignment).

**Scope:** CareSitter, its users, and the external systems it integrates with.

**Audience:** Lecturer, project team, and stakeholders.

## Overview

CareSitter connects families with caregivers for at-home care. Customers book care and follow arrival updates; caregivers operate their shifts; administrators manage the platform. This view focuses on care operations and proposed Nutrition; the landing page and its assistant are excluded.

Nutrition is proposed scope: customers describe a beneficiary's health situation, confirm the extracted facts, and select suggested meals. This diagram does not claim that Nutrition or the distributed architecture has been implemented.

## Diagram

![C0 - CareSitter System Context](../../../docs/architecture/figures/c0-context.png)

Editable source: page **C0 - Context with Nutrition (Proposed)** in [C.drawio](../../../../C.drawio).

## Legend

- Navy rounded box: person. Blue box: CareSitter software system. Gray box: external software system.
- Solid arrow: existing integration represented in the repository; environment configuration and credentials determine runtime availability.
- Dashed arrow: optional or fallback integration. `*`: proposed Nutrition capability.
- Each arrow expresses a request or data flow in one direction. Responses to requests are implied. Payment callbacks have a separate reverse arrow.
- Box size and position have no quantitative meaning. No deployment topology or internal containers are shown here.
- Boxes use the requested compact notation: name plus `[Person]`, `[Software System]`, or `[External System]`. Responsibilities are in the Elements table below.
- SMTP: Simple Mail Transfer Protocol; FCM: Firebase Cloud Messaging; AI: artificial intelligence; gRPC: remote procedure call framework; Kafka: event broker. gRPC and Kafka are internal and appear in C1 only.

## Elements

| Element | Type | Technology | Responsibility |
|---|---|---|---|
| Customer / Family | Person | - | Books care, follows caregiver arrival, and selects meals in the proposed feature. |
| Caregiver | Person | - | Provides home care and updates shifts. |
| Administrator | Person | - | Manages accounts, care operations, and proposed recipe review. |
| CareSitter | Software system | Intentionally abstract at Context level | Care booking, profiles, payments, tracking, and proposed meal suggestions. |
| Gmail SMTP | External system | SMTP | Delivers verification emails; proposed worker delivery may reuse it. |
| Google Identity | External system | Google identity tokens / HTTPS | Supplies Google sign-in identity and verification material. |
| Cloudinary | External system | HTTPS API | Stores and delivers uploaded media. |
| Firebase Cloud Messaging | External system | Firebase Admin SDK / HTTPS | Delivers mobile push notifications. |
| VNPay | External system | HTTPS | Processes payments and sends payment callbacks. |
| Geoapify | External system | HTTPS API | Supplies address lookup and route information. |
| OpenRouteService | External system | HTTPS API | Supplies the configured alternative/fallback route provider. |
| OpenStreetMap Tiles | External system | HTTPS tile endpoints | Supplies map tiles loaded by the mobile applications. |
| Nutrition AI Provider* | Proposed external system | HTTPS API; provider unconfirmed | Optionally extracts reported health-profile facts for customer confirmation. |

## Key relationships

| From | To | Intent | Protocol / Technology |
|---|---|---|---|
| Customer / Family | CareSitter | Book care, track arrival, and select proposed meals | User interaction |
| Caregiver | CareSitter | Update care shifts | User interaction |
| Administrator | CareSitter | Manage operations | User interaction |
| CareSitter | Gmail SMTP | Send verification emails | SMTP |
| CareSitter | Google Identity | Verify sign-in identity | HTTPS / Google ID tokens |
| CareSitter | Cloudinary | Upload and store media | HTTPS |
| CareSitter | Firebase Cloud Messaging | Request push delivery | HTTPS |
| CareSitter | VNPay | Request or query payment | HTTPS |
| VNPay | CareSitter | Confirm payment status | HTTPS callback |
| CareSitter | Geoapify | Look up addresses and routes | HTTPS |
| CareSitter | OpenRouteService | Request routes from the configured alternative provider | HTTPS |
| CareSitter | OpenStreetMap Tiles | Load mobile map tiles | HTTPS |
| CareSitter | Nutrition AI Provider* | Optionally extract reported Nutrition facts | HTTPS* |

## Notable architectural decisions

1. Keep the teacher's C0/C1 numbering while naming the standard C4 diagram types explicitly.
2. Keep databases, Redis, Kafka, and internal services out of Context. They are internal implementation choices, shown in C1.
3. Show only the optional Nutrition AI integration. Name it generically because its provider is undecided; the landing-page assistant is outside this view.
4. Preserve the original two draw.io pages and revise only the two added pages. The earlier detailed draft remains in `D:/EXE/C.before-simplify.drawio`.
5. Show three actors: Customer / Family, Caregiver, and Administrator. Omit the landing page and its separate visitor actor, as requested. Use the supplied reference's blue application boxes, dark blue data cylinders, and gray external systems.

## Assumptions

- This is a repository-based architecture view, not a verification of the currently deployed environment. Solid lines do not assert that external credentials are configured or calls are succeeding in production.
- Customers select meals for reference. Recipe/rule review and fact confirmation are proposed requirements, not existing UI capabilities.
- Nutrition AI Provider is an optional proposal, with no selected vendor implied.
- Route fallback depends on the actual provider configuration; a dashed line does not promise automatic failover for every API operation.

## Evidence and review

Sources: [API composition](../../../backend/caresitter-be/ApiHost/Program.cs), [deployment Compose](../../../deploy/compose.yml), [meal plan](../../tong-quan/MEAL_RECOMMENDATION_PLAN.md), and the mobile map/infrastructure adapters.

Applied the [c4-model skill](https://github.com/cheriftj/c4-model-skill/blob/main/skills/c4-model/SKILL.md) in Update mode. Review covered title, scope, element types/responsibilities, directed relationship intent, legend, assumptions, and consistency with C1. Both new pages were exported with the native draw.io CLI and visually inspected.

## Links to other levels

- [C1 - Container Architecture](02-container.md)

