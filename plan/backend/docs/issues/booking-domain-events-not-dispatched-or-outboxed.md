# Booking domain events are not dispatched or persisted to the outbox

- Status: Deferred
- Confirmed: 2026-09-15
- Scope: Separate bug-fix task after the Booking MediatR refactor

## Current behavior

Booking aggregate methods raise `IDomainEvent` instances, but `BookingDbContext` ignores the
collection and `ModuleDbContext.SaveChangesAsync` has no dispatcher/outbox serialization
step. Existing explicit post-commit SignalR and notification calls remain the observable
side-effect path.

## Refactor constraint

Do not introduce dispatch, consumers, or outbox writes as part of the structural move.
