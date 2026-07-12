# Foundation SQL Tests

> **Owner:** Iron Signal Systems
>
> **Current checkpoint:** Phase 4 Step 3 accepted; Phase 4 Step 4
> independence-enforcement candidate
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

This is a repository-policy check. The active Step 4 gate invokes it before
database execution. It contributes no SQL PASS rows and does not change the
Step 4 target.

Correctness only:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

Correctness plus observation-only resource telemetry:

```bash
./test-framework/sql/schema/scripts/test_foundation_with_resources.sh
```

## Sequential Tests

The Step 4 candidate contains 19 sequential test files. The Phase 4 files are:

```text
foundation/170_approval_independence_and_separation_of_duties_structure.sql
foundation/180_controlled_approval_action_recording.sql
foundation/190_approval_independence_enforcement.sql
```

- Test `170`: 37 structural assertions.
- Test `180`: 55 controlled-action assertions.
- Test `190`: 40 independence-enforcement assertions.

Step 4 target:

```text
34 manifest migrations
34 registered migrations
19 sequential test files
9 concurrency test files
540 PASS
0 FAIL
3 understood WARN
Correctness result: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

The nine accepted concurrency tests remain unchanged in Step 4. Approval race
proofs are intentionally reserved for Phase 4 Step 7.

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
