# Foundation SQL Tests

> **Owner:** Iron Signal Systems
>
> **Current checkpoint:** Phase 4 approval independence and separation of
> duties formally accepted at `phase-4-approval-independence-and-separation-of-duties-complete-v1`
>
> **Scope:** Test-only PostgreSQL, `psql`, Bash, and resource-observation
> infrastructure for the active Platform Foundation SQL.

## Authoritative Paths

```text
sql/schema/manifests/foundation.manifest
test-framework/sql/tests/foundation-tests.manifest
test-framework/sql/tests/foundation-concurrency-tests.manifest
test-framework/sql/schema/scripts/test_foundation.sh
test-framework/sql/schema/scripts/test_foundation_with_resources.sh
tools/validation/validate_foundation_migration_timeouts.sh
```

## Run

Migration timeout contract only:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

Correctness only:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

Correctness plus observation-only resource telemetry:

```bash
./test-framework/sql/schema/scripts/test_foundation_with_resources.sh
```

The Phase 4 formal-acceptance gate invokes the timeout validator before
execution. The timeout check contributes no SQL PASS rows.

## Sequential Tests

The accepted Phase 4 boundary contains 21 sequential tests. The Phase 4 files
are:

```text
foundation/170_approval_independence_and_separation_of_duties_structure.sql
foundation/180_controlled_approval_action_recording.sql
foundation/190_approval_independence_enforcement.sql
foundation/200_incompatible_authority_and_duty_conflict_enforcement.sql
foundation/210_approval_stage_satisfaction_and_finalization.sql
```

- Test `170`: 37 structural assertions.
- Test `180`: 55 controlled-action assertions.
- Test `190`: 40 independence-enforcement assertions.
- Test `200`: 50 incompatible-authority and duty-conflict assertions.
- Test `210`: 60 stage-satisfaction and finalization assertions.

## Accepted Phase 4 Concurrency Tests

```text
concurrency/190_approval_duplicate_actor_race.sh
concurrency/200_approval_stage_finalized_evaluation_race.sh
concurrency/210_approval_request_finalization_race.sh
concurrency/220_approval_last_approval_finalization_race.sh
concurrency/230_approval_withdrawal_finalization_race.sh
concurrency/240_approval_authority_revocation_race.sh
concurrency/250_approval_reciprocal_approval_race.sh
```

Each file contributes exactly 12 assertions. The seven files contribute
84 assertions and increase the concurrency inventory from 9 to 16.

Accepted Phase 4 result:

```text
34 manifest migrations
34 registered migrations
21 sequential test files
16 concurrency test files
734 PASS
0 FAIL
3 understood WARN
Correctness result: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

Accepted tag: `phase-4-approval-independence-and-separation-of-duties-complete-v1`

Formal acceptance record:

- [Phase 4 Approval Independence and Separation of Duties Acceptance](../../../docs/architecture/foundation/phase-4-approval-independence-and-separation-of-duties-acceptance.md)

## Understood Warnings

1. Migration file hashes are calculated by the runner but are not yet stored in
   the applied-migration registry.
2. Foundation-defined types retain direct PUBLIC USAGE grants that remain a
   defense-in-depth review item.
3. The applied-migration registry is documented append-only but lacks an
   enabled immutable-write trigger.

## Migration Execution Boundary

Every manifest migration must use `SET LOCAL` with a `5s` lock timeout, a
`1min` statement timeout, and a `1min` idle-in-transaction timeout. Individual
statements observed above ten seconds require investigation under the
Foundation migration execution standard.

## Boundary

Passing tests prove only the asserted database behavior. They do not establish
production readiness, host compromise containment, protected backups, off-host
durability, break-glass operations, or trusted rebuild and recovery.
