# CareSitter admin web

## Development and verification

```powershell
npm ci
npm run dev
npm test
npm run build
```

Development uses `http://localhost:5033` for the API; override with
`VITE_API_BASE_URL` when needed. Production uses the same origin by default.
Authentication and operational metadata come from the backend. Test fixtures
are confined to `*.test.ts(x)` and are not used by the application.

## Admin hardening — 2026-10-03

Implemented:

- Logout revokes the current backend session before clearing the browser token.
  A network failure still clears the local token and reports that remote
  revocation was not confirmed. HTTP 403 no longer expires a valid session;
  a late 401 from an old token cannot expire a newer login.
- Pricing edits preserve local date/time and milliseconds when converting to
  UTC. The current price respects the effective date range and newest eligible
  rule, matching backend selection rules.
- Paginated queues ignore obsolete requests, cancel reads on unmount, reset
  filters to page 1, and recover when the last item on a page disappears.
  Failed loads are not presented as successful empty queues.
- Checklist forms reset their draft and edit identity when switching services.
  Empty/error/retry states work without leaving a permanent spinner. Mutations
  disable conflicting controls; saved policy changes survive service switching.
- Disputes load current dispute/booking data, require an explicit decision,
  validate partial refunds and penalties, and show/confirm the financial split.
  Full wins use the backend's automatic allocation; editable penalty is limited
  to partial refunds. This does **not** make the backend settlement atomic.
- Booking completion requires successfully loaded detail, checklist and timeline.
  The confirmation explains the dispute window rather than immediate release.
  Reviewers can inspect actual times, required tasks, skip reasons and evidence.
- Payment reconciliation has an amount/booking confirmation. Payout approval
  copy describes accounting approval and does not claim a bank transfer occurred.
- KYC document counts reflect actual files. ADMIN role changes require explicit
  confirmation. Drawers contain keyboard focus and resist dismissal during saves.
- The dashboard preserves CRITICAL/HIGH priority when combining queues, before
  the 12-item limit; it displays the data timestamp and priority.

## Verification evidence

- `npm test`: **33 passed**, six files, including component interaction tests
  for service switching and dispute allocation. HTTP responses in frontend
  tests are fixtures; these are not authenticated end-to-end tests.
- `npm run build`: passed (TypeScript and Vite production build).
- Pricing helper tests also passed with `TZ=Asia/Ho_Chi_Minh` and `TZ=UTC`.
- `dotnet test backend/CareSitter.sln --configuration Release`: **199 passed,
  zero skipped**, including all 14 PostgreSQL tests using isolated databases.
  Local TRX evidence: `backend/artifacts/admin-hardening-20261003/`.
- Browser smoke check: local login page renders without console errors. Full
  authenticated browser acceptance against representative data remains pending.
- No deployment performed. The root `vercel.json` disables Git deployments for
  `feat/google-sign-in-account-chooser` only. This does not prevent manual CLI
  deployments or disable deployments from other branches.

## Remaining work (not marked complete)

1. **Dispute cancellation and settlement**: agree whether cancellation withdraws
   the case/restores the booking or rejects it with a financial outcome. Implement
   durable, immutable resolution with recovery across Support, Payments and
   Booking, plus concurrent-decision/failure-between-steps regression tests.
   Current cancellation only closes the dispute; its confirmation says so.
2. **Payout lifecycle**: choose manual transfer with reference/evidence or a
   payout provider. Separate review approval from paid/failed confirmation and
   make ledger posting/reversal and retries consistent. Current approval still
   records accounting withdrawal without proving bank transfer.
3. **Server-side search/pagination**: booking search still filters the current
   page (now explicitly labeled); reconciliation still returns up to 100 records
   and filters those loaded records. These limits are not resolved by UI changes.
4. **Operational workflows**: KYC rejection history/notifications; ticket
   assignment concurrency, notes and handoff; dashboard deep links to exact
   records; pricing holiday calendar and quote preview; concurrent last-admin
   protection and a usable audit history.
5. Complete authenticated end-to-end acceptance of the workflows above before
   deployment. The passing suite verifies its existing cases, not every missing
   workflow or every real-world transfer scenario.
