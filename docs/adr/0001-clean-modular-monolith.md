# ADR 0001: Clean modular monolith boundaries

- Status: accepted
- Date: 2026-09-23

## Context

CareSitter is a modular monolith with six PostgreSQL-backed business modules. Before this decision, Application and HTTP code could depend directly on EF Core, module infrastructure, and other module implementations. Those boundaries now need to remain enforceable by the compiler and CI.

## Decision

The backend uses the following dependency direction:

```text
ApiHost -> Presentation -> Application -> Domain -> SharedKernel
                         -> Module Contracts
Infrastructure ---------> Application + Domain
```

The rules are:

1. Domain code is framework-independent.
2. Application code depends on ports, never infrastructure implementations or `DbContext`.
3. HTTP controllers only translate transport input/output and dispatch use cases.
4. A module owns all reads and writes to its schema.
5. Cross-module communication uses public contracts. Post-commit side effects are isolated from the committed transaction; a durable outbox remains a separate reliability improvement.
6. Cross-schema operations that require strong consistency use an explicit outer transaction coordinator in ApiHost, not a direct business-module dependency.
7. A coordinator may span schemas on one database, while ordinary reads and writes stay behind the module that owns the schema.
8. Architecture tests reject new boundary violations immediately; the architecture allowlists are empty.

## Consequences

- Existing behavior and database schemas remain stable during the refactor.
- Module projects do not reference other business module projects; collaboration goes through `CareSitter.Contracts`.
- Domain and Application layers remain framework-adapter independent, and controllers remain transport-only.
- Adding an architecture exception requires a new architecture decision rather than an allowlist edit.
