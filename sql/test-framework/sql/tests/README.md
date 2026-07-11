# Foundation SQL Test Framework

> **Scope:** Test-only PostgreSQL, `psql`, and Bash infrastructure for the active Platform Foundation SQL.
>
> **Location:** This framework intentionally remains self-contained under `sql/test-framework/`. It is not copied into the live migration tree.

## Purpose

The Foundation SQL is being developed and strengthened in stages.

The test framework provides a repeatable way to:

- Install the current live Foundation migrations into a new disposable database,
- Detect migration-order and dependency failures,
- Verify catalog and privilege invariants,
- Exercise database behavior and expected failure paths,
- Record warnings for known incomplete controls,
- Produce writable logs and summaries for review,
- Preserve the exact failed database state for investigation.

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

The runner is installed at:

```text
sql/test-framework/sql/schema/scripts/test_foundation.sh
```

From that location it resolves two separate roots:

```text
Live Foundation SQL:
sql/schema/

Test-only SQL and results:
sql/test-framework/sql/
```

The framework reads the authoritative live migration order from:

```text
sql/schema/manifests/foundation.manifest
```

The framework reads the test order from:

```text
sql/test-framework/sql/tests/foundation-tests.manifest
```

## What the Runner Does

The runner:

1. Validates required command-line tools.
2. Resolves the repository and framework paths.
3. Creates a uniquely named disposable database from `template0`.
4. Verifies PostgreSQL 18 or newer.
5. Reads the live Foundation manifest.
6. Validates migration paths and detects duplicate entries.
7. Calculates the SHA-256 digest of every migration file.
8. Applies every live Foundation migration in manifest order.
9. Installs the test-only `sql_test` assertion framework.
10. Loads expected migration names, positions, paths, and file digests.
11. Runs every SQL test listed in the test manifest.
12. Writes a complete timestamped log.
13. Writes a compact text summary.
14. Evaluates the final pass/fail result.
15. Drops a successful test database unless retention was requested.
16. Preserves a failed test database by default.

## Current Test Layers

The suite is intended to grow in layers.

### Installation and Smoke Tests

These verify that:

- PostgreSQL meets the required version,
- The migration registry exists,
- The schema registry exists,
- The migration-registration function exists,
- Required extensions are installed correctly,
- The manifest and migration registry agree,
- No unexpected migration is registered,
- Foundation migrations do not create regular tables in `public`.

### Schema and Privilege Security

These verify selected baseline conditions such as:

- `PUBLIC` cannot create in the `public` schema,
- `PUBLIC` has no access to registered Foundation schemas,
- `PUBLIC` has no table, view, sequence, or routine privileges within the Foundation,
- Type privileges that require later defense-in-depth review are reported.

### Function Security

These inspect Foundation routines for:

- Explicit controlled `search_path` settings where applicable,
- `pg_catalog` precedence,
- References to existing schemas,
- Exclusion of `public`, `pg_temp`, and `$user`,
- Use of trusted procedural languages.

A clean inventory with no `SECURITY DEFINER` functions means no unsafe functions of that class were found. It does not prove a future least-privileged controlled API until such functions and deployment roles exist.

### Migration Registry Behavior

Negative tests verify expected SQLSTATE behavior for:

- Malformed migration identifiers,
- Empty migration names,
- Empty migration layers,
- Malformed SHA-256 values,
- Conflicting migration re-registration,
- Exact idempotent re-registration.

### Catalog Integrity

These verify selected structural properties such as:

- Validated constraints,
- Valid and ready indexes,
- Valid foreign-key targets,
- Primary keys on regular Foundation tables,
- Time-zone-aware operational timestamp columns.

### Validation Views

These verify that migration `099` created the expected security-validation views and that selected views agree with PostgreSQL catalogs.

### Inventory Reporting

The suite writes useful inventories to the full log, including migration registration, table counts, security-sensitive routine inventory, and `PUBLIC` schema privilege posture.

## Current Development Limits

The Foundation SQL and test suite remain active work.

The suite does not yet fully prove:

- Trust Assertion audience, environment, identity, device, and session binding,
- Single-use assertion behavior under concurrency,
- Session expiration and revocation behavior,
- Approval independence and self-approval prevention,
- Authorization Lease scope binding,
- Lease revocation, expiration, consumption, and replay behavior,
- Decision Record final-result consistency,
- Complete append-only mutation denial,
- Final production ownership and login-role boundaries,
- Runtime denial of direct table access,
- Off-host integrity and recovery controls.

These tests will be added as the corresponding controls are implemented.

## Prerequisites

Required software:

- PostgreSQL 18 or newer
- PostgreSQL client tools
- Bash
- GNU core utilities
- GNU `sha256sum`
- `make`

Required commands include:

```text
psql
createdb
dropdb
sha256sum
make
```

The PostgreSQL role running the framework must be able to:

- Connect to the maintenance database,
- Create a disposable database,
- Drop the disposable database,
- Create the objects required by the live Foundation migrations.

## Initial Setup

From the repository root:

```bash
chmod +x sql/test-framework/sql/schema/scripts/test_foundation.sh
```

## Run the Suite

Run from the test-framework directory:

```bash
cd sql/test-framework
make test-sql
```

From the repository root, the equivalent command is:

```bash
make -C sql/test-framework test-sql
```

Run the shell script directly from the repository root:

```bash
./sql/test-framework/sql/schema/scripts/test_foundation.sh
```

Run it directly from inside `sql/test-framework`:

```bash
./sql/schema/scripts/test_foundation.sh
```

Show runner options:

```bash
./sql/schema/scripts/test_foundation.sh --help
```

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

The maintenance database defaults to `postgres`.

Override it with:

```bash
export PGMAINTENANCE_DB=postgres
```

An optional test database name may be supplied:

```bash
export TEST_DATABASE_NAME=psp_foundation_test_manual
```

For safety, a supplied database name must begin with:

```text
psp_foundation_test_
```

and contain only letters, numbers, and underscores.

## Database Retention Modes

### Normal Run

```bash
make test-sql
```

A successful database is dropped.

A failed database is preserved.

### Keep a Successful Database

```bash
make test-sql-keep
```

or:

```bash
KEEP_TEST_DB=1 make test-sql
```

### Drop a Failed Database

```bash
make test-sql-drop-failed
```

or:

```bash
DROP_TEST_DB_ON_FAILURE=1 make test-sql
```

### Direct Runner Options

```bash
./sql/schema/scripts/test_foundation.sh --keep-database
```

```bash
./sql/schema/scripts/test_foundation.sh --drop-on-failure
```

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

- Runner path resolution,
- PostgreSQL version,
- Migration execution,
- PostgreSQL notices and errors,
- Assertion results,
- Warnings,
- Catalog inventories,
- Final pass/fail evaluation,
- Retained database information when applicable.

The summary includes:

- Overall result,
- Runner exit status,
- Database name,
- Result totals,
- Failed assertions,
- Warnings,
- Manifest and migration-registry totals.

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

- Resolved,
- Refined into a more precise test,
- Documented as an accepted design condition, or
- Promoted to a failure once the associated control becomes mandatory.

## Expected Notices

Migration `099` may issue notices that validation views do not yet exist before it recreates them:

```text
NOTICE: view "..." does not exist, skipping
```

These notices are expected on a clean database when `DROP VIEW IF EXISTS` is used. They are not failures.

## Adding a Test File

Create a numbered SQL file beneath:

```text
sql/test-framework/sql/tests/foundation/
```

Example:

```text
080_trust_assertion_behavior.sql
```

Add the relative path to:

```text
sql/test-framework/sql/tests/foundation-tests.manifest
```

Example:

```text
foundation/080_trust_assertion_behavior.sql
```

Each test file should begin with:

```sql
SELECT sql_test.begin_file('080_trust_assertion_behavior.sql');
```

## Test Design Rules

Prefer tests that are:

- Catalog-driven where structure is being verified,
- Behavioral where authorization or lifecycle behavior is being verified,
- Negative where invalid actions must fail,
- Specific about expected SQLSTATE values,
- Isolated to the disposable database,
- Deterministic,
- Safe to repeat,
- Clear about whether a condition is a failure or a staged warning.

Do not make a test pass merely because no matching object exists when the architecture requires that object to exist.

For example, a function-hardening test and a controlled-runtime-permission test answer different questions and should be separate assertions.

## Fixtures and Cleanup

Small fixture data may be inserted into the disposable database.

Fixture data should:

- Use clearly recognizable test identifiers,
- Be created in a known dependency order,
- Avoid external systems,
- Avoid real identities, credentials, keys, or protected data,
- Be cleaned up when later assertions could be affected,
- Remain understandable in a preserved failed database.

Because the database is disposable, cleanup is not always required at the end of the entire suite. Isolation between test files is still required.

## Concurrency Tests

Controls involving consumption, replay protection, uniqueness, or state transitions should eventually include concurrent tests.

Examples include:

- Trust Assertion single use,
- Authorization Lease consumption,
- Approval finalization,
- Outbox claiming,
- Provider delivery-state transitions.

Concurrency tests must demonstrate that only the permitted transaction succeeds and that the final state remains valid.

## Migration Checksums

The runner calculates a SHA-256 digest for every live migration file.

Current migrations may still register `NULL` checksums while checksum injection and enforcement are being developed.

The suite should:

- Warn while checksums are intentionally absent,
- Fail when a stored checksum differs from the calculated file digest,
- Eventually fail when a required checksum is missing.

The checksum should be supplied by the migration runner. It should not be hardcoded into the file whose digest is being calculated.

## Investigating a Failed Database

The runner prints the retained database name.

Connect with:

```bash
psql --dbname=DATABASE_NAME
```

or inspect it with pgAdmin.

Remove it manually after investigation:

```bash
dropdb --maintenance-db=postgres DATABASE_NAME
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

1. The valid operation succeeds,
2. Invalid identity or scope fails,
3. Expired state fails,
4. Revoked state fails,
5. Replayed or duplicate state fails,
6. Unauthorized direct table access fails,
7. Required Decision Records are created,
8. Historical records cannot be silently rewritten,
9. Concurrent execution preserves the invariant.
