# Foundation SQL Tests

> **Owner:** Iron Signal Systems
>
> **Current checkpoint:** Phase 3 Step 6 concurrency-proof candidate
>
> **Scope:** Test-only PostgreSQL, `psql`, and Bash infrastructure for the
> active Platform Foundation SQL.

## Authoritative Paths

```text
sql/schema/manifests/foundation.manifest

test-framework/sql/tests/foundation-tests.manifest
test-framework/sql/tests/foundation-concurrency-tests.manifest

test-framework/sql/schema/scripts/test_foundation.sh
```

The Foundation runner installs the live migration manifest into a disposable
PostgreSQL database, installs the test-only `sql_test` assertion framework,
runs the sequential manifest, then runs the concurrency manifest against the
same database.

## Primary Command

From the repository root:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

The current phase gate is:

```bash
./tools/validation/phase-gates/validate_phase3_step6.sh
```

## Dependency Preflight

The runner and phase gates stop before database creation when required commands
are missing. On minimal Arch Linux, the direct runner depends on packages such
as `bash`, `postgresql-libs`, `gawk`, `coreutils`, `grep`, and `sed`.

## Sequential Tests

The sequential manifest contains 16 files. It preserves every accepted Phase 1
and Phase 2 regression test and adds Phase 3 structural, finalization, lease,
and fail-closed behavior tests through:

```text
foundation/130_authorization_decision_and_lease_structure.sql
foundation/140_authorization_policy_selection_and_decision_finalization.sql
foundation/150_authorization_lease_issuance_and_use.sql
foundation/160_authorization_lease_fail_closed_behavior.sql
```

## Concurrency Tests

The concurrency manifest preserves the four accepted Authentication Assertion
and session proofs, then adds five Phase 3 authorization races:

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

Each race uses independent PostgreSQL connections behind an advisory-lock
release barrier. Both workers record readiness before the controller releases
them. The tests assert the final durable state, not merely worker exit codes.

The shared test-only fixture is:

```text
concurrency/support/phase3_authorization_concurrency_fixture.sql
```

## Step 6 Target

```text
33 manifest migrations
33 registered migrations
16 sequential test files
9 concurrency test files
408 PASS
0 FAIL
3 understood WARN
```

The three warnings remain deliberate development signals:

1. migration files are hashed by the runner but migrations register NULL
   checksums,
2. Foundation-defined types still expose direct PUBLIC USAGE grants that are
   unreachable without schema USAGE but remain a defense-in-depth review item,
3. the applied-migration registry is documented append-only but lacks an
   enabled immutable-write trigger against owner UPDATE or DELETE.

## Results

Results are written beneath:

```text
test-framework/sql/test-results/
```

The latest compact and full outputs are:

```text
test-framework/sql/test-results/latest-summary.txt
test-framework/sql/test-results/latest.log
```

Successful disposable databases are dropped. Failed databases are retained by
default for investigation.

## Boundary

Passing tests prove only the implemented assertions. They do not establish
production readiness, final deployment-role separation, host-compromise
containment, protected backups, off-host audit durability, break-glass
operations, or trusted rebuild and recovery.
