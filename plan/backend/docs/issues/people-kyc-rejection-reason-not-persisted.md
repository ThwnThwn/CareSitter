# KYC rejection reason is not persisted or delivered

- Status: Deferred
- Confirmed: 2026-09-15
- Scope: Separate bug-fix task after the MediatR refactor

## Current behavior

The KYC rejection endpoint accepts a reason but only echoes it in the HTTP response. The value
is not stored and no notification is sent to the caregiver.

## Refactor constraint

Preserve the response and the absence of persistence/notification during the structural move.
