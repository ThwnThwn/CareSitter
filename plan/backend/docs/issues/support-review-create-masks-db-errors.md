# Review creation maps every DbUpdateException to a duplicate conflict

- Status: Deferred
- Confirmed: 2026-09-15
- Scope: Separate bug-fix task after the MediatR refactor

## Current behavior

Every `DbUpdateException` raised while saving a review is returned as the same duplicate-review
409 response, even when the exception is not caused by the unique booking index.

## Refactor constraint

Preserve the broad mapping and exact response text during the structural move.
