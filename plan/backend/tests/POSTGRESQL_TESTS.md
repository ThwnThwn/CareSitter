# PostgreSQL regression tests

## Why these tests can be skipped

`PostgresFactAttribute` skips database tests when
`CARESITTER_TEST_ADMIN_CONNECTION` is not configured. A normal `dotnet test`
without this variable does **not** validate PostgreSQL constraints, row locks,
advisory locks or concurrent wallet transactions. A skipped test is neither a
pass nor a failure.

## Recommended local command

Start Docker Desktop, then run from the repository root with PowerShell:

```powershell
./backend/scripts/test-races.ps1 -Repeat 3
```

The runner creates a disposable `postgis/postgis:16-3.4` container, publishes a
random port on `127.0.0.1`, and uses generated test-only credentials. Each test
creates a separate `caresitter_race_<32-hex-digits>` database, applies all SQL
files under `backend/init-db`, and drops only that generated database afterward.
The runner removes the container it created and restores any previous value of
the connection variable, including after a failure. It does not start the app,
deploy, or migrate the development database.

TRX evidence is saved under `backend/artifacts/postgres/<run-id>/`. The command
fails if no tests run, any selected test is skipped, or any selected test fails.
Use `-ArtifactsDirectory <path>` to select another evidence directory.

For a deliberately selected existing **local test container**:

```powershell
./backend/scripts/test-races.ps1 -ContainerName my-test-postgres -Repeat 3
```

The container must expose `POSTGRES_USER`, `POSTGRES_PASSWORD`, and a published
IPv4 port for `5432/tcp`. The runner discovers the actual host port; it does not
assume port 5432. An explicitly selected container is not removed. Do not use a
production container or credentials. The test account needs database creation
and extension privileges; schema setup requires PostGIS, pgcrypto and btree_gist.

To include the non-database booking-flow tests as well:

```powershell
./backend/scripts/test-phase8.ps1 -Repeat 3
```

For direct .NET execution, supply the test-only connection in the process
environment and use `--filter 'Category=PostgreSQL'`. The four fixture classes
are explicitly tagged. `PostgresTestDiscoveryTests` verifies that newly added
`[PostgresFact]` methods remain included by this category.

## The original 14 cases

| # | Fixture / test | What it asserts |
|---|---|---|
| 1 | SlotHoldRaceTests.SameCaregiver_CannotCommitOverlappingBookings | Two overlapping committed holds for one caregiver cannot both commit; one exclusion violation and one hold remain. |
| 2 | SlotHoldRaceTests.SameBooking_CannotBeCommittedToTwoCaregivers | One booking cannot acquire committed holds for two caregivers; one unique violation and one hold remain. |
| 3 | PromotionRaceTests.ConcurrentReservations_CannotExceedPromotionQuota | Two requests for a one-use promotion yield only one successful reservation. |
| 4 | PaymentRaceTests.ConcurrentPayouts_CannotReserveMoreThanAvailableBalance | Two 100,000 VND withdrawals from 150,000 VND cannot overdraw; 50,000 available and 100,000 pending remain. |
| 5 | PaymentRaceTests.ConcurrentPayoutRetry_WithSameKey_ReservesExactlyOnce | Retrying the same withdrawal key reserves funds once and returns one existing request. |
| 6 | PaymentRaceTests.ConcurrentApproveAndReject_OnlyOneTransitionChangesMoney | Concurrent approve/reject yields one winner, with the matching wallet and ledger outcome. |
| 7 | PaymentRaceTests.ConcurrentSettlement_CreditsCaregiverExactlyOnce | Duplicate settlement creates one caregiver earning and one platform fee. |
| 8 | PaymentRaceTests.ConcurrentPaymentFinalization_FinalizesBookingAndEscrowOnce | Duplicate payment finalization leaves one succeeded intent, one escrow lock and a confirmed booking. |
| 9 | BookingTransactionIntegrityTests.ConcurrentOverlappingBookings_ForSameBeneficiary_OnlyOneCanCommit | Overlapping active bookings for the same beneficiary cannot both commit. |
| 10 | BookingTransactionIntegrityTests.ConcurrentRefundRetry_CreditsCustomerExactlyOnce | Duplicate refunds credit the customer wallet exactly once. |
| 11 | BookingTransactionIntegrityTests.ConcurrentPartialDisputeResolution_DistributesEscrowExactlyOnce | The same partial decision submitted twice distributes 100,000 VND once: 40,000 refund, 40,000 earning, 15,000 fee, 5,000 penalty. |
| 12 | BookingTransactionIntegrityTests.CustomerWins_WithAdministrativePenalty_RefundsOnlyLockedEscrow | Full customer victory refunds 100,000 VND; an administrative penalty does not create additional money. |
| 13 | BookingTransactionIntegrityTests.ConcurrentMatureSettlement_ReleasesOnceAndStampsBooking | Duplicate release credits one settlement and records settlement release on the booking. |
| 14 | BookingTransactionIntegrityTests.OpenDispute_BlocksMatureSettlement | An open dispute prevents release, caregiver credit and the settlement timestamp. |

## Coverage boundaries

These are real PostgreSQL tests, but not full browser-to-bank acceptance tests.
Some call services or SQL directly and use stubs for other modules. For example,
payment finalization uses a test outbox dispatcher; the partial-dispute test
repeats the **same** financial decision, not contradictory decisions through
the full Support handler. Passing does not prove bank transfers, external
callbacks, crash recovery across modules, or every admin workflow is complete.

## Verification on 2026-10-03

The original 14 tests passed once before code changes and three consecutive
runs after runner hardening, with no skipped cases. Changes address test
selection (the old `~RaceTests` filter omitted six integrity cases), dynamic
ports, isolated setup/cleanup, restoration of environment variables, explicit
failure for incomplete runs, fixture initialization failure cleanup, and
pool cleanup scoped to the fixture database. No production business rule was
changed merely to make these tests pass.

The full backend suite then passed **198/198, zero skipped**, including the new
discovery guard test. The Phase 8 wrapper passed **19/19**, and reusing a test
container with a random host port preserved the original connection variable.
An invalid container was also checked to fail safely and restore that variable.

For the requested code-only push, repository-root `vercel.json` disables Git
deployments only on `feat/google-sign-in-account-chooser`. Other branches,
including `main`, retain their existing behavior. Remove that branch rule only
when deployment from this branch is intentionally wanted.
