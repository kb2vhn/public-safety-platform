# Foundation SQL Tests

> **Owner:** Iron Signal Systems
>
> **Current checkpoint:** Phase 4 Step 3 controlled-action candidate
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
```

## Correctness Runner

Run the normal correctness suite from the repository root:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

It installs the live migration manifest into a disposable PostgreSQL database,
installs the test-only `sql_test` framework, runs the sequential manifest, runs
the concurrency manifest, writes the result inventory, and returns a correctness
exit status.

## Resource-Aware Runner

Run correctness plus resource observation with:

```bash
./test-framework/sql/schema/scripts/test_foundation_with_resources.sh
```

The wrapper invokes the normal runner with `--keep-database`, measures the
runner process tree, observes the retained disposable database, writes text and
JSON resource reports, and then drops the successful database unless
`--keep-database` was supplied.

The outcomes remain separate:

```text
Correctness result: PASS or FAIL
Resource observation: RECORDED or NOT_RECORDED
Performance thresholds: NOT_EVALUATED
```

Phase 4 Step 3 does not enforce a performance budget.

On minimal Arch Linux, the resource-aware path additionally requires GNU
`time`, provided by package `time`.

## Sequential Tests

The sequential manifest contains 18 files.

Phase 4 Step 3 adds controlled behavioral coverage:

```text
foundation/180_controlled_approval_action_recording.sql
```

Test `170` retains 37 structural assertions. Test `180` contributes 55
functional assertions for the controlled write boundary, exact actor/session/
organization/Authority Grant binding, action-lineage behavior, and append-only
mutation guards.

Current target:

```text
34 manifest migrations
34 registered migrations
18 sequential test files
9 concurrency test files
500 PASS
0 FAIL
3 understood WARN
```

The resource-aware wrapper adds no SQL PASS rows. Correctness remains the
authority, resource observation remains `RECORDED`, and performance thresholds
remain `NOT_EVALUATED`.

## Concurrency Tests

The concurrency manifest remains at nine accepted tests:

```text
concurrency/100_authentication_assertion_single_use.sh
concurrency/110_session_establishment_single_use.sh
concurrency/120_session_step_up_single_use.sh
concurrency/130_session_terminal_transition_race.sh
concurrency/140_authorization_decision_finalization_race.sh
concurrency/150_authorization_lease_issuance_race.sh
concurrency/160_authorization_lease_single_use_race.sh
concurrency/170_authorization_lease_limited_use_race.sh
concurrency/180_authorization_lease_terminal_transition_race.sh
```

## Step 3 Correctness Target

```text
34 manifest migrations
34 registered migrations
18 sequential test files
9 concurrency test files
500 PASS
0 FAIL
3 understood WARN
```

The three warnings remain deliberate development signals:

1. Migration files are hashed by the runner, but migrations register NULL
   checksums.
2. Foundation-defined types still expose direct PUBLIC USAGE grants that are
   unreachable without schema USAGE but remain a defense-in-depth review item.
3. The applied-migration registry is documented append-only but lacks an
   enabled immutable-write trigger against owner UPDATE or DELETE.

## Result Files

Normal correctness outputs:

```text
test-framework/sql/test-results/
├── foundation_<run-id>-summary.txt
├── foundation_<run-id>.log
├── latest-summary.txt
└── latest.log
```

Resource-aware outputs:

```text
test-framework/sql/test-results/
├── foundation_<run-id>-resources.txt
├── foundation_<run-id>-resources.json
├── latest-resources.txt
└── latest-resources.json
```

Resource reports are observations, not automatically Assurance Artifacts.

## Failure Behavior

- Successful databases are dropped after observation unless retention was
  requested.
- Failed databases are retained by default.
- A correctness failure remains a correctness failure.
- A required missing or malformed resource report is a validation
  infrastructure failure.
- No resource value causes a performance failure during Step 2.

## Boundary

Passing tests prove only the implemented assertions. Resource observations
describe execution cost for that run. Neither establishes production readiness,
final deployment-role separation, host-compromise containment, protected
backups, off-host durability, break-glass operations, or trusted rebuild and
recovery.
