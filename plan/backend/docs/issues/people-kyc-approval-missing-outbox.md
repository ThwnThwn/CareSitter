# KYC approval does not publish its integration event

- Status: Deferred
- Confirmed: 2026-09-15
- Scope: Separate bug-fix task after the MediatR refactor

## Current behavior

Approving caregiver KYC updates the People aggregate but does not persist the existing
`KycApproved` integration event to the transactional outbox. Identity and Notifications
therefore cannot react through the intended cross-module path.

## Refactor constraint

Do not add event publication, consumers, or outbox messages during the pure structural move.
