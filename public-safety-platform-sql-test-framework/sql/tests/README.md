# Foundation SQL Test Framework

This directory contains the test-only SQL framework for the Public Safety
Platform Foundation migrations.

The framework is deliberately built from PostgreSQL, `psql`, and Bash. It does
not require pgTAP or install test objects in a production database.

## What the runner does

`sql/schema/scripts/test_foundation.sh` performs the following steps:

1. Creates a uniquely named disposable database.
2. Applies every migration in `sql/schema/manifests/foundation.manifest`.
3. Calculates the SHA-256 digest of every migration file.
4. Installs the test-only `sql_test` schema.
5. Runs every file in `sql/tests/foundation-tests.manifest`.
6. Writes a timestamped full log and compact text summary.
7. Drops a successful test database unless it was requested to remain.
8. Preserves a failed database by default for investigation.

No file under `sql/tests` belongs in a production migration manifest.

## Prerequisites

- PostgreSQL 18 server and client tools
- `psql`, `createdb`, and `dropdb`
- A PostgreSQL role permitted to create databases
- Bash
- GNU `sha256sum`

The runner inherits normal PostgreSQL environment variables such as `PGHOST`,
`PGPORT`, `PGUSER`, and `PGPASSWORD`.

## Run the suite

From the repository root:

```bash
make test-sql
```

Or run it directly:

```bash
./sql/schema/scripts/test_foundation.sh
```

Keep a successful database for manual inspection:

```bash
make test-sql-keep
```

Drop a failed database instead of preserving it:

```bash
make test-sql-drop-failed
```

## Output files

Results are written beneath `sql/test-results`:

```text
foundation_YYYYMMDD_HHMMSS_PID.log
foundation_YYYYMMDD_HHMMSS_PID-summary.txt
latest.log
latest-summary.txt
```

`latest.log` and `latest-summary.txt` are symbolic links to the newest run.
The full log is the best file to upload when a migration or assertion fails.

A failed run also prints the retained test database name. Connect to that
specific database with `psql` or pgAdmin to inspect the exact failed state.

## Result meanings

- `PASS` — the tested invariant held.
- `FAIL` — the invariant was violated; the runner exits unsuccessfully.
- `WARN` — the suite found a condition that requires review but does not yet
  block the build.

The initial suite intentionally warns when migration checksums are `NULL` in
`foundation_meta.applied_migrations`. The runner calculates file checksums and
will fail on a mismatch whenever a migration later records a checksum.

## Adding tests

Create a numbered SQL file under `sql/tests/foundation` and add it to
`sql/tests/foundation-tests.manifest`.

Each file should begin with:

```sql
SELECT sql_test.begin_file('NNN_test_name.sql');
```

Prefer catalog-driven assertions and negative tests that verify a specific
SQLSTATE. Avoid inserting long-lived fixture data unless the file cleans it up
or the behavior is isolated to the disposable database.
