# Dispute resolution does not publish its integration event

- Status: Deferred
- Confirmed: 2026-09-15
- Scope: Separate bug-fix task after the MediatR refactor

## Current behavior

Resolving a dispute updates only the Support aggregate. It does not persist the existing
`DisputeResolved` integration event to the transactional outbox, so Payments does not receive
the refund and caregiver-penalty instruction described by the endpoint and contract comments.

## Refactor constraint

Do not add ledger writes, event publication, consumers, or outbox messages during the pure
structural move.
