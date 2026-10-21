# CHECKIN_OUTSIDE_GEOFENCE timeline branch is unreachable

- Status: Deferred
- Confirmed: 2026-09-15
- Scope: Separate bug-fix task after the Booking MediatR refactor

## Current behavior

`Booking.CheckIn` returns a validation failure when the caregiver is outside the configured
radius. The controller/handler only chooses between `CHECKIN_VALID` and
`CHECKIN_OUTSIDE_GEOFENCE` after a successful domain call, so the outside-geofence branch
cannot be persisted.

## Refactor constraint

Preserve the existing domain guard, check order, error message, and unreachable timeline
branch. Do not fix it as part of the structural refactor.
