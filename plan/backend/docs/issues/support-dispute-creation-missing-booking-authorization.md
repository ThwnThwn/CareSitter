# Dispute creation does not authorize booking membership

- Status: Deferred
- Confirmed: 2026-09-15
- Scope: Separate bug-fix task after the MediatR refactor

## Current behavior

Any authenticated user can create a dispute for any existing booking identifier. The action
checks only whether a dispute already exists and does not verify that the caller is the booking
customer or assigned caregiver.

## Refactor constraint

Preserve the current authorization checks and their order. Do not add booking membership
validation as part of the structural refactor.
