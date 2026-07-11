# Foundation SQL Test Framework

> **Scope:** Test-only PostgreSQL, `psql`, and Bash infrastructure for the active Platform Foundation SQL.
>
> **Location:** This framework intentionally remains self-contained under `sql/test-framework/`. It is not copied into the live migration tree.
>
> **Minimal-host rule:** The Bash runner is the primary interface. GNU `make` is optional and exists only as a convenience wrapper.

## Purpose

The Foundation SQL is being developed and strengthened in deliberate stages.

The test framework provides a repeatable way to:

- Install the current live Foundation migrations into a new disposable database
- Detect migration-order and dependency failures
- Verify catalog, constraint, index, and privilege invariants
- Exercise database behavior and expected failure paths
- Record warnings for known incomplete controls
- Produce writable logs and summaries for review
- Preserve the exact failed database state for investigation

A passing test run means the assertions currently implemented by the suite passed.

It does **not** mean every normative Foundation requirement has already been implemented or tested.

## Separation from Live SQL

Live Foundation SQL:

```text
sql/schema/
├── manifests/
│   └── foundation.manifest
├── migrations/
│   └── foundation/
└── scripts/
    ├── apply_foundation.sh
    └── validate_foundation.sh
```

Self-contained test framework:

```text
sql/test-framework/
├── INSTALL.txt
├── Makefile
└── sql/
    ├── schema/
    │   └── scripts/
    │       └── test_foundation.sh
    ├── tests/
    │   ├── foundation-tests.manifest
    │   ├── framework/
    │   │   └── 000_test_framework.sql
    │   └── foundation/
    └── test-results/
```

No file beneath `sql/test-framework/sql/tests/` belongs in the live Foundation migration manifest.

The test-only `sql_test` schema exists only inside the disposable test database.

## How the Runner Resolves Paths

The runner is located at:

```text
sql/test-framework/sql/schema/scripts/test_foundation.sh
```

From that location, it resolves two separate roots:

```text
Live Foundation SQL:
sql/schema/

Test-only SQL and results:
sql/test-framework/sql/
```

The authoritative live migration order is read from:

```text
sql/schema/manifests/foundation.manifest
```

The test execution order is read from:

```text
sql/test-framework/sql/tests/foundation-tests.manifest
```

The framework must remain at `sql/test-framework/` for this relative path resolution to remain valid.

## Primary Run Command

From the repository root:

```bash
./sql/test-framework/sql/schema/scripts/test_foundation.sh
```

This is the primary and lowest-dependency way to run the suite.

From inside `sql/test-framework/`, the equivalent command is:

```bash
./sql/schema/scripts/test_foundation.sh
```

Show runner options:

```bash
./sql/test-framework/sql/schema/scripts/test_foundation.sh --help
```

## Initial Setup

Make the runner executable from the repository root:

```bash
chmod +x sql/test-framework/sql/schema/scripts/test_foundation.sh
```

## Required Software

The direct Bash runner requires:

- PostgreSQL 18 or newer
- Bash
- PostgreSQL client tools
- GNU `awk`
- GNU core utilities
- GNU `grep`
- GNU `sed`

The runner directly uses these commands:

```text
awk
basename
createdb
date
dirname
dropdb
grep
ln
mkdir
mktemp
psql
rm
sed
sha256sum
tee
```

`make` is **not required** to run the framework.

## Minimal Arch Linux Dependencies

On a minimal Arch Linux host, the required commands are provided by:

| Arch package | Commands or purpose |
|---|---|
| `bash` | Bash runner |
| `postgresql-libs` | `psql`, `createdb`, and `dropdb` |
| `gawk` | `awk` |
| `coreutils` | `basename`, `date`, `dirname`, `ln`, `mkdir`, `mktemp`, `rm`, `sha256sum`, and `tee` |
| `grep` | `grep` |
| `sed` | `sed` |

Install the complete direct-runner dependency set with:

```bash
sudo pacman -S --needed     bash     postgresql-libs     gawk     coreutils     grep     sed
```

The PostgreSQL server may run locally or on another reachable host. Installing `postgresql-libs` provides the client commands required by the runner; it does not require the test database server to run on the same machine.

## Dependency Failure Behavior

The runner checks its required commands before creating the disposable database.

When a required command is absent, the run stops before migration application or database creation.

Repository maintenance and update scripts for this project should perform a complete dependency preflight before modifying files. They should report all missing commands and their Arch package names together.

## PostgreSQL Role Requirements

The PostgreSQL role running the framework must be able to:

- Connect to the maintenance database
- Create a disposable database
- Drop the disposable database
- Create the schemas, extensions, tables, indexes, constraints, functions, and views required by the Foundation migrations

The framework currently requires PostgreSQL 18 or newer.

## PostgreSQL Connection Settings

The runner uses normal libpq environment variables:

```text
PGHOST
PGPORT
PGUSER
PGPASSWORD
PGSSLMODE
```

Example:

```bash
export PGHOST=127.0.0.1
export PGPORT=5432
export PGUSER=jwood
```

The maintenance database defaults to:

```text
postgres
```

Override it with:

```bash
export PGMAINTENANCE_DB=postgres
```

An optional test database name may be supplied:

```bash
export TEST_DATABASE_NAME=psp_foundation_test_manual
```

For safety, a supplied database name must:

- Begin with `psp_foundation_test_`
- Contain only letters, numbers, and underscores
- Fit within PostgreSQL's identifier-length limit

## What the Runner Does

The runner:

1. Validates required command-line tools.
2. Resolves the repository and test-framework paths.
3. Creates a uniquely named disposable database from `template0`.
4. Verifies PostgreSQL 18 or newer.
5. Reads the live Foundation manifest.
6. Validates migration paths.
7. Detects duplicate migration entries.
8. Calculates the SHA-256 digest of every migration file.
9. Applies every live Foundation migration in manifest order.
10. Installs the test-only `sql_test` assertion framework.
11. Loads expected migration names, positions, paths, and file digests.
12. Reads the Foundation test manifest.
13. Validates test paths and detects duplicate entries.
14. Runs every listed Foundation SQL test.
15. Writes a complete timestamped log.
16. Writes a compact text summary.
17. Evaluates the final pass or fail result.
18. Drops a successful test database unless retention was requested.
19. Preserves a failed test database by default.

## Database Retention Modes

### Normal run

```bash
./sql/test-framework/sql/schema/scripts/test_foundation.sh
```

A successful disposable database is dropped.

A failed disposable database is retained.

### Keep a successful database

```bash
./sql/test-framework/sql/schema/scripts/test_foundation.sh     --keep-database
```

The environment-variable form is:

```bash
KEEP_TEST_DB=1 ./sql/test-framework/sql/schema/scripts/test_foundation.sh
```

### Drop a failed database

```bash
./sql/test-framework/sql/schema/scripts/test_foundation.sh     --drop-on-failure
```

The environment-variable form is:

```bash
DROP_TEST_DB_ON_FAILURE=1 ./sql/test-framework/sql/schema/scripts/test_foundation.sh
```

### Write results to another directory

```bash
./sql/test-framework/sql/schema/scripts/test_foundation.sh     --results-dir /path/to/results
```

## Optional Makefile Convenience Commands

The repository retains a Makefile for developers who already have GNU `make` installed.

It does not add test behavior. It only provides shorter command names around the Bash runner.

Install it on Arch Linux only when desired:

```bash
sudo pacman -S --needed make
```

From `sql/test-framework/`:

```bash
make test-sql
```

Keep a successful database:

```bash
make test-sql-keep
```

Drop a failed database:

```bash
make test-sql-drop-failed
```

From the repository root:

```bash
make -C sql/test-framework test-sql
```

The direct Bash runner remains the authoritative execution path.

## Current Test Layers

The suite is intended to grow in layers.

### Installation and Smoke Tests

These verify that:

- PostgreSQL meets the required version
- The migration registry exists
- The schema registry exists
- The migration-registration function exists
- Required extensions are installed correctly
- The manifest and migration registry agree
- No unexpected migration is registered
- Foundation migrations do not create regular tables in `public`

### Schema and Privilege Security

These verify selected baseline conditions such as:

- `PUBLIC` cannot create objects in the `public` schema
- `PUBLIC` has no access to registered Foundation schemas
- `PUBLIC` has no table or view privileges within the Foundation
- `PUBLIC` has no sequence privileges within the Foundation
- `PUBLIC` cannot execute Foundation routines
- Type privileges requiring later defense-in-depth review are reported

### Function Security

These inspect Foundation routines for:

- Explicit controlled `search_path` settings where applicable
- `pg_catalog` precedence
- References to existing schemas
- Exclusion of `public`, `pg_temp`, and `$user`
- Use of trusted procedural languages

A clean inventory with no `SECURITY DEFINER` functions means no unsafe functions of that class were found.

It does not prove a future least-privileged controlled API until those functions and deployment roles exist.

### Migration Registry Behavior

Negative tests verify expected SQLSTATE behavior for:

- Malformed migration identifiers
- Empty migration names
- Empty migration layers
- Malformed SHA-256 values
- Conflicting migration re-registration
- Exact idempotent re-registration

### Catalog Integrity

These verify selected structural properties such as:

- Validated constraints
- Valid and ready indexes
- Valid foreign-key targets
- Primary keys on regular Foundation tables
- Time-zone-aware operational timestamp columns

### Foundation Baseline Integrity

The Phase −1 tests verify selected behavioral invariants such as:

- Revocation types matching their referenced targets
- Positive certificate public-key sizes
- Device identities requiring device subjects
- Historical provider identity mappings
- Only one current provider-subject mapping
- Valid identity-suspension chronology
- Same-organization organizational-unit parentage
- Unambiguous configuration scope
- Versioned participation agreements
- Prevention of self-delegation
- Identity and person consistency in attestations
- Statement-consistent Authorization Lease time evaluation

### Validation Views

These verify that migration `099` created the expected security-validation views and that selected views agree with the PostgreSQL catalogs.

### Inventory Reporting

The suite writes useful inventories to the full log, including:

- Migration registration
- Foundation table counts
- Security-sensitive routine inventory
- `PUBLIC` schema privilege posture

## Current Development Limits

The Foundation SQL and test suite remain active work.

The suite does not yet fully prove:

- Authentication Assertion audience, environment, identity, device, and session binding
- Single-use Authentication Assertion behavior under concurrency
- Session expiration and revocation behavior
- Approval independence and self-approval prevention
- Authorization Lease scope binding
- Lease revocation, expiration, consumption, and replay behavior
- Decision Record final-result consistency
- Complete append-only mutation denial
- Final production ownership and login-role boundaries
- Runtime denial of direct table access
- Off-host integrity and recovery controls

These tests will be added as the corresponding controls are implemented.

## Output Files

Results are written under:

```text
sql/test-framework/sql/test-results/
```

Timestamped files:

```text
foundation_YYYYMMDD_HHMMSS_PID.log
foundation_YYYYMMDD_HHMMSS_PID-summary.txt
```

Convenience links for the newest completed run:

```text
latest.log
latest-summary.txt
```

The full log includes:

- Runner path resolution
- PostgreSQL version
- Migration execution
- PostgreSQL notices and errors
- Assertion results
- Warnings
- Catalog inventories
- Final pass or fail evaluation
- Retained database information when applicable

The summary includes:

- Overall result
- Runner exit status
- Database name
- Result totals
- Failed assertions
- Warnings
- Manifest and migration-registry totals

The full log is normally the best file to upload for review:

```text
sql/test-framework/sql/test-results/latest.log
```

## Result Meanings

- `PASS` — the tested invariant held.
- `FAIL` — the tested invariant was violated; the runner exits unsuccessfully.
- `WARN` — the suite found a known incomplete or review-required condition that does not yet block the run.

Warnings are deliberate development signals.

A warning should eventually be:

- Resolved
- Refined into a more precise test
- Documented as an accepted design condition
- Promoted to a failure once the associated control becomes mandatory

## Expected Notices

Migration `099` may report that validation views do not exist before it recreates them:

```text
NOTICE: view "..." does not exist, skipping
```

These notices are expected on a clean database when `DROP VIEW IF EXISTS` is used.

They are not failures.

## Adding a Test File

Create a numbered SQL file beneath:

```text
sql/test-framework/sql/tests/foundation/
```

Example:

```text
090_trust_assertion_behavior.sql
```

Add the relative path to:

```text
sql/test-framework/sql/tests/foundation-tests.manifest
```

Example:

```text
foundation/090_trust_assertion_behavior.sql
```

Each test file should begin with:

```sql
SELECT sql_test.begin_file('090_trust_assertion_behavior.sql');
```

## Test Design Rules

Prefer tests that are:

- Catalog-driven where structure is being verified
- Behavioral where authorization or lifecycle behavior is being verified
- Negative where invalid actions must fail
- Specific about expected SQLSTATE values
- Isolated to the disposable database
- Deterministic
- Safe to repeat
- Clear about whether a condition is a failure or a staged warning

Do not make a test pass merely because no matching object exists when the architecture requires that object to exist.

For example, a function-hardening test and a controlled-runtime-permission test answer different questions and should remain separate assertions.

## Fixtures and Cleanup

Small fixture data may be inserted into the disposable database.

Fixture data should:

- Use clearly recognizable test identifiers
- Be created in a known dependency order
- Avoid external systems
- Avoid real identities, credentials, keys, or protected data
- Be cleaned up when later assertions could be affected
- Remain understandable in a preserved failed database

Because the database is disposable, cleanup is not always required at the end of the entire suite.

Isolation between test files is still required.

## Concurrency Tests

Controls involving consumption, replay protection, uniqueness, or state transitions should eventually include concurrent tests.

Examples include:

- Authentication Assertion single use
- Authorization Lease consumption
- Approval finalization
- Outbox claiming
- Provider delivery-state transitions

Concurrency tests must demonstrate that only the permitted transaction succeeds and that the final state remains valid.

SQL files alone may not be sufficient for race-condition testing. The framework may use controlled Bash orchestration with multiple `psql` processes when concurrency testing is introduced.

## Migration Checksums

The runner calculates a SHA-256 digest for every live migration file.

Current migrations may still register `NULL` checksums while checksum injection and enforcement are being developed.

The suite should:

- Warn while checksums are intentionally absent
- Fail when a stored checksum differs from the calculated file digest
- Eventually fail when a required checksum is missing

The checksum should be supplied by the migration runner.

It should not be hardcoded into the file whose digest is being calculated.

## Investigating a Failed Database

The runner prints the retained database name.

Connect with:

```bash
psql --dbname=DATABASE_NAME
```

The same database may be inspected with pgAdmin.

Remove it manually after investigation:

```bash
dropdb     --maintenance-db=postgres     DATABASE_NAME
```

## Checking the Runner

Check Bash syntax without running the suite:

```bash
bash -n     sql/test-framework/sql/schema/scripts/test_foundation.sh
```

Display available options:

```bash
./sql/test-framework/sql/schema/scripts/test_foundation.sh     --help
```

## Documentation

Operational installation details are also maintained in:

[`../../INSTALL.txt`](../../INSTALL.txt)

The live migration order is maintained in:

[`../../../schema/manifests/foundation.manifest`](../../../schema/manifests/foundation.manifest)

The Platform Foundation architecture is documented under:

```text
docs/architecture/foundation/
```

## Completion Standard

A test file is not complete merely because its positive path succeeds.

For protected behavior, the suite should demonstrate:

1. The valid operation succeeds.
2. Invalid identity or scope fails.
3. Expired state fails.
4. Revoked state fails.
5. Replayed or duplicate state fails.
6. Unauthorized direct table access fails.
7. Required Decision Records are created.
8. Historical records cannot be silently rewritten.
9. Concurrent execution preserves the invariant.
