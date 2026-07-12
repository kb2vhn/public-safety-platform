# Foundation Migration Timeout and Execution Performance Standard

> **Layer:** Platform Foundation SQL migration and validation boundary
>
> **Status:** Normative technical requirement
>
> **Current implementation scope:** Clean installation of the manifest-driven
> Foundation migrations in `sql/schema/migrations/foundation/`
>
> **Current checkpoint:** Phase 4 Step 3 accepted; Phase 4 Step 4 independence-
> enforcement candidate

## Purpose

Define one explicit execution contract for ordinary Platform Foundation
migrations so that lock contention, stalled migration clients, and unexpectedly
slow SQL are exposed early rather than hidden by generous timeouts or oversized
infrastructure.

The governing rule is:

> A timeout is a safety ceiling, not an expected execution duration.

This document defines execution limits for clean-install migrations. It does
not activate a general performance-regression pass/fail budget for the complete
test suite.

## Scope

This standard applies to every migration listed by:

```text
sql/schema/manifests/foundation.manifest
```

while the Foundation remains pre-stable and is validated by rebuilding empty,
disposable databases.

It applies to:

- Clean Foundation installation
- Disposable correctness-test databases
- Structural and catalog validation
- Migration execution performed by the current test framework
- Static validation of migration timeout declarations

It does not automatically govern future populated-production operations such
as large backfills, concurrent index creation, deferred constraint validation,
large table rewrites, or maintenance-window transformations. Those operations
require a separately classified and documented execution plan.

## Required Header

Every ordinary Foundation migration MUST establish the following transaction-
local settings immediately after `BEGIN;`:

```sql
BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';
```

`SET LOCAL` is mandatory. The settings must end automatically at `COMMIT` or
`ROLLBACK` and must not alter the database-wide or session-wide defaults for
later work.

## Current Foundation Targets

| Measurement | Current Foundation target |
| --- | ---: |
| Expected ordinary DDL statement | Under a few seconds |
| Investigate an individual statement | Over 10 seconds |
| Hard statement safety limit | 1 minute |
| Lock-wait safety limit | 5 seconds |
| Idle open-transaction limit | 1 minute |
| Exception requiring explanation | Any timeout above the default or any observed statement over 10 seconds |

The ten-second investigation threshold is a review trigger. It is not by itself
an SQL correctness failure or a general performance-budget failure.

## Timeout Semantics

### `lock_timeout`

Limits only the time a statement waits to acquire a PostgreSQL lock. It does
not limit execution time after the lock is acquired.

A five-second lock wait during a clean installation is abnormal and must expose
unexpected concurrent activity, an abandoned transaction, incorrect migration
ordering, or a migration that belongs in another execution class.

### `statement_timeout`

Limits each SQL statement independently. It does not limit the migration file
as one combined unit.

One minute is a hard safety ceiling for the current clean-install Foundation
migrations. Ordinary schema creation, function creation, constraints, indexes
on empty or test-scale tables, migration registration, and bounded validation
should finish substantially faster.

### `idle_in_transaction_session_timeout`

Terminates a session that is inside an open transaction but is waiting for the
client to send another command.

An automated migration runner should not leave a transaction idle for one
minute. Reaching this timeout indicates a runner, connectivity, orchestration,
or operator failure rather than normal migration behavior.

## Normative Requirements

### MIG-TIMEOUT-001 — Transaction-Local Lock Limit

Every manifest migration MUST contain exactly one effective declaration:

```sql
SET LOCAL lock_timeout = '5s';
```

The migration MUST fail rather than wait indefinitely for a conflicting lock.

### MIG-TIMEOUT-002 — Transaction-Local Statement Limit

Every manifest migration MUST contain exactly one effective declaration:

```sql
SET LOCAL statement_timeout = '1min';
```

A migration MUST NOT silently raise this limit to make an unexplained slow
statement pass.

### MIG-TIMEOUT-003 — Transaction-Local Idle Limit

Every manifest migration MUST contain exactly one effective declaration:

```sql
SET LOCAL idle_in_transaction_session_timeout = '1min';
```

### MIG-TIMEOUT-004 — Header Order

The migration transaction and three timeout declarations MUST appear in this
order near the beginning of the migration:

1. `BEGIN;`
2. `lock_timeout`
3. `statement_timeout`
4. `idle_in_transaction_session_timeout`

Comments may precede `BEGIN;`, but authorization, schema, table, function, or
data-changing statements MUST NOT run before the timeout contract is active.

### MIG-PERF-001 — Ordinary Execution Expectation

An ordinary clean-install DDL statement SHOULD complete within a few seconds on
the minimum supported validation profile.

### MIG-PERF-002 — Investigation Threshold

Any individual migration statement observed above ten seconds MUST be
investigated. The review should identify, when applicable:

- Exact statement and migration
- Total duration and lock-wait duration
- Rows or objects affected
- Temporary-file activity
- WAL generation
- Storage latency or queueing
- Environmental interference
- Repeatability
- Whether the operation belongs in another migration class

The result may remain observation-only until a governed budget explicitly makes
the threshold enforceable.

### MIG-PERF-003 — No Hardware Masking

A migration that only succeeds acceptably after increasing CPU, memory, or
storage performance MUST be investigated before the larger hardware profile is
accepted as the remedy.

Hardware may provide capacity and resilience. It must not conceal unexplained
migration behavior.

### MIG-EXCEPTION-001 — Explicit Exception

Any migration requiring a timeout above the default MUST include an immediately
adjacent exception block:

```sql
-- TIMEOUT EXCEPTION
-- Requirement:
-- Reason:
-- Operation:
-- Expected duration:
-- Maximum supported data volume:
-- Locking behavior:
-- Operational effect:
-- Retry behavior:
-- Rollback or recovery behavior:
-- Validation evidence:
-- Revalidation condition:
```

An exception MUST be deliberate, bounded, reviewable, supported by evidence,
and limited to the smallest applicable operation.

No timeout exception is currently approved for a migration in the Foundation
manifest. Admitting one requires a governed update to this standard, the static
validator, the applicable phase gate, and the validation evidence; the comment
block alone does not bypass the canonical validator.

### MIG-EXCEPTION-002 — No Silent Runner Override

The migration runner MUST NOT silently relax database-wide or session-wide
timeouts to bypass a migration's declared contract.

Any administrative override must be visible in the execution record and treated
as an exception requiring review.

### MIG-VALIDATION-001 — Static Contract Validation

The repository MUST provide a static validator that reads the authoritative
manifest and verifies the required declaration count, values, order, and use of
`SET LOCAL` for every listed migration.

Current validator:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

The active Phase 4 Step 4 gate invokes this validator before database
execution. The validator remains independently runnable and contributes no SQL
PASS rows; it validates repository policy.

### MIG-VALIDATION-002 — Clean Installation

A timeout-policy change MUST be followed by a complete clean installation into
a disposable database.

Validation must confirm that all manifest migrations apply in authoritative
order and register successfully without unexpected lock, statement, or idle-
transaction timeout failures.

### MIG-VALIDATION-003 — Complete Regression

A material timeout-policy change MUST be followed by the complete applicable
Foundation regression path, including sequential tests, concurrency tests, and
resource observation required by the active phase gate.

### MIG-VALIDATION-004 — Correctness and Resource Separation

Timeout failures are execution failures. Resource observations remain separate
from SQL correctness totals and from future performance-budget results.

A statement exceeding ten seconds may require investigation even when the
complete run is correct and no performance threshold is active.

## Pre-Stable Migration Maintenance

The current repository is pre-alpha, migration checksums are not yet enforced,
and development/test databases are rebuilt from empty databases when mutable
migration content changes.

Therefore, the existing manifest migrations may be normalized to this standard
as one controlled maintenance change only when:

- The accepted tags remain unchanged as historical evidence
- The change is limited to the timeout execution contract
- Documentation and static validation are updated together
- The entire current Foundation suite is rerun
- Resource observation is recorded through the active gate

After migration checksums and stable upgrade history are enforced, previously
applied migrations MUST NOT be edited merely to change timeout policy. Future
changes must use a governed runner policy, a new migration, or another explicit
upgrade mechanism.

## Future Migration Classes

### Class A — Clean-Install Foundation Migration

Uses the default `5s / 1min / 1min` contract and must pass on the minimum
validation profile.

### Class B — Short Online Production Migration

Runs against a populated operational database, minimizes blocking, and defines
a production lock and interruption budget.

### Class C — Controlled Data Backfill

Runs in bounded batches, records progress, supports retry, and limits
transaction size, lock duration, WAL generation, and replica impact.

### Class D — Concurrent or Nontransactional Maintenance

Uses a specialized runner for operations that cannot execute inside the
standard transaction wrapper. Partial-failure detection and recovery are
mandatory.

### Class E — Maintenance-Window Transformation

Requires an approved maintenance window, measured execution duration,
operational communication, and rollback or recovery procedures.

## Acceptance Criteria

This standard is integrated when:

- Every manifest migration uses the required header
- The static validator passes
- No unexplained timeout variation remains
- The complete clean-install and regression path passes
- Required resource observation is recorded
- Documentation indexes and migration mapping reference this standard
- Any statement above ten seconds has a recorded investigation

## Related Documents

- [SQL Migration Map](sql-migration-map.md)
- [Resource Telemetry and Performance-Regression Testing Model](resource-telemetry-and-performance-regression-testing-model.md)
- [Performance, Efficiency, and Resource Governance](performance-efficiency-and-resource-governance-model.md)
- [Observability, Health, and Operational Telemetry](observability-health-and-operational-telemetry-model.md)
- [Database Security Model](database-security-model.md)
