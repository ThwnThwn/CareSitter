# Address deletion maps every DbUpdateException to an in-use conflict

- Status: Deferred
- Confirmed: 2026-09-15
- Scope: Separate bug-fix task after the MediatR refactor

## Current behavior

Every `DbUpdateException` raised while deleting an address is returned as the same 409
"address in use" response, even when the exception is unrelated to a foreign-key reference.

## Refactor constraint

Preserve the broad mapping and exact response text during the structural move.
