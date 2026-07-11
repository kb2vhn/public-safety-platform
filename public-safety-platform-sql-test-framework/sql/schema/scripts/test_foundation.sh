#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
    cat <<'USAGE'
Usage: test_foundation.sh [options]

Creates a disposable PostgreSQL database, applies the Foundation migration
manifest, runs the SQL test suite, and writes timestamped log and summary files.

Options:
  --keep-database      Keep the test database after a successful run.
  --drop-on-failure    Drop the test database after a failed run.
  --results-dir PATH   Write results beneath PATH instead of sql/test-results.
  -h, --help           Show this help text.

Environment:
  PGHOST, PGPORT, PGUSER, PGPASSWORD
      Standard PostgreSQL connection settings.

  PGMAINTENANCE_DB
      Database used by createdb and dropdb. Default: postgres

  TEST_DATABASE_NAME
      Optional test database name. It must begin with psp_foundation_test_.

  KEEP_TEST_DB=1
      Same as --keep-database.

  DROP_TEST_DB_ON_FAILURE=1
      Same as --drop-on-failure.
USAGE
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$1" >&2
        exit 69
    fi
}

log() {
    printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"
}

quote_sql_literal() {
    local value="$1"
    printf '%s' "${value//\'/\'\'}"
}

keep_database="${KEEP_TEST_DB:-0}"
drop_on_failure="${DROP_TEST_DB_ON_FAILURE:-0}"
results_dir_override=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-database)
            keep_database=1
            shift
            ;;
        --drop-on-failure)
            drop_on_failure=1
            shift
            ;;
        --results-dir)
            if [[ $# -lt 2 ]]; then
                printf '%s\n' '--results-dir requires a path' >&2
                exit 64
            fi
            results_dir_override="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

for command_name in psql createdb dropdb sha256sum awk sed grep tee date mktemp ln; do
    require_command "$command_name"
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
schema_root="$(cd "$script_dir/.." && pwd)"
sql_root="$(cd "$schema_root/.." && pwd)"
repo_root="$(cd "$sql_root/.." && pwd)"

manifest_file="$schema_root/manifests/foundation.manifest"
test_root="$sql_root/tests"
test_manifest="$test_root/foundation-tests.manifest"
framework_file="$test_root/framework/000_test_framework.sql"

if [[ -n "$results_dir_override" ]]; then
    results_dir="$results_dir_override"
else
    results_dir="$sql_root/test-results"
fi
mkdir -p "$results_dir"
results_dir="$(cd "$results_dir" && pwd)"

timestamp="$(date +%Y%m%d_%H%M%S)"
run_id="foundation_${timestamp}_$$"
log_file="$results_dir/${run_id}.log"
summary_file="$results_dir/${run_id}-summary.txt"
latest_log="$results_dir/latest.log"
latest_summary="$results_dir/latest-summary.txt"
maintenance_db="${PGMAINTENANCE_DB:-postgres}"
test_database="${TEST_DATABASE_NAME:-psp_foundation_test_${timestamp}_$$}"

if [[ ! "$test_database" =~ ^psp_foundation_test_[A-Za-z0-9_]+$ ]]; then
    printf 'Unsafe test database name: %s\n' "$test_database" >&2
    printf '%s\n' 'The name must begin with psp_foundation_test_ and contain only letters, numbers, and underscores.' >&2
    exit 64
fi

if (( ${#test_database} > 63 )); then
    printf 'Test database name exceeds PostgreSQL identifier length: %s\n' "$test_database" >&2
    exit 64
fi

if [[ ! -f "$manifest_file" ]]; then
    printf 'Foundation manifest not found: %s\n' "$manifest_file" >&2
    exit 66
fi
if [[ ! -f "$test_manifest" ]]; then
    printf 'Test manifest not found: %s\n' "$test_manifest" >&2
    exit 66
fi
if [[ ! -f "$framework_file" ]]; then
    printf 'Test framework not found: %s\n' "$framework_file" >&2
    exit 66
fi

export PGAPPNAME="public-safety-platform-foundation-test"

database_created=0
expected_sql_file="$(mktemp)"

write_summary() {
    local summary_status=0
    if [[ "$database_created" -ne 1 ]]; then
        return 0
    fi

    if ! psql -X --dbname="$test_database" --tuples-only --no-align \
        --command="SELECT 1 FROM pg_namespace WHERE nspname = 'sql_test';" \
        2>/dev/null | grep -qx '1'; then
        return 0
    fi

    {
        printf 'Public Safety Platform - Foundation SQL Test Summary\n'
        printf '====================================================\n'
        printf 'Run ID: %s\n' "$run_id"
        printf 'Database: %s\n' "$test_database"
        printf 'Completed: %s\n' "$(date --iso-8601=seconds)"
        printf 'Full log: %s\n\n' "$log_file"

        psql -X --set=ON_ERROR_STOP=1 --dbname="$test_database" <<'SQL'
\pset border 2
\pset pager off
\echo 'Result totals'
SELECT status, count(*) AS result_count
FROM sql_test.results
GROUP BY status
ORDER BY CASE status WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END;

\echo ''
\echo 'Failed assertions'
SELECT test_file, test_name, COALESCE(details, '') AS details
FROM sql_test.results
WHERE status = 'FAIL'
ORDER BY result_id;

\echo ''
\echo 'Warnings'
SELECT test_file, test_name, COALESCE(details, '') AS details
FROM sql_test.results
WHERE status = 'WARN'
ORDER BY result_id;

\echo ''
\echo 'Migration totals'
SELECT
    (SELECT count(*) FROM sql_test.expected_migrations) AS manifest_migrations,
    (SELECT count(*) FROM foundation_meta.applied_migrations) AS registered_migrations;
SQL
    } >"$summary_file" 2>&1 || summary_status=$?

    if [[ "$summary_status" -ne 0 ]]; then
        log "Could not write SQL summary; see the full log."
        return 0
    fi

    ln -sfn "$(basename "$summary_file")" "$latest_summary"
}

cleanup() {
    local exit_status=$?
    trap - EXIT
    set +e

    write_summary
    ln -sfn "$(basename "$log_file")" "$latest_log"
    rm -f "$expected_sql_file"

    if [[ "$database_created" -eq 1 ]]; then
        if [[ "$exit_status" -eq 0 ]]; then
            if [[ "$keep_database" == "1" ]]; then
                log "Successful test database retained: $test_database"
            else
                log "Dropping successful test database: $test_database"
                dropdb --if-exists --maintenance-db="$maintenance_db" "$test_database"
            fi
        else
            if [[ "$drop_on_failure" == "1" ]]; then
                log "Dropping failed test database by request: $test_database"
                dropdb --if-exists --maintenance-db="$maintenance_db" "$test_database"
            else
                log "FAILED test database retained for investigation: $test_database"
            fi
        fi
    fi

    if [[ -f "$summary_file" ]]; then
        log "Summary: $summary_file"
    fi
    log "Full log: $log_file"

    exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

exec > >(tee -a "$log_file") 2>&1

log "Foundation SQL test run started"
log "Repository root: $repo_root"
log "Foundation manifest: $manifest_file"
log "Test manifest: $test_manifest"
log "Maintenance database: $maintenance_db"
log "Test database: $test_database"
log "Results directory: $results_dir"

if psql -X --dbname="$maintenance_db" --tuples-only --no-align \
    --command="SELECT 1 FROM pg_database WHERE datname = '$(quote_sql_literal "$test_database")';" \
    | grep -qx '1'; then
    log "Refusing to overwrite existing database: $test_database"
    exit 65
fi

log "Creating disposable database"
createdb --maintenance-db="$maintenance_db" --template=template0 "$test_database"
database_created=1

server_version="$(psql -X --dbname="$test_database" --tuples-only --no-align --command='SHOW server_version;')"
server_version_num="$(psql -X --dbname="$test_database" --tuples-only --no-align --command="SELECT current_setting('server_version_num');")"
log "PostgreSQL server version: $server_version ($server_version_num)"

migration_count=0
: >"$expected_sql_file"
printf '%s\n' 'TRUNCATE TABLE sql_test.expected_migrations;' >>"$expected_sql_file"

log "Applying Foundation migrations"
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    relative_path="$(printf '%s' "$raw_line" | sed 's/\r$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$relative_path" ]] && continue
    [[ "$relative_path" =~ ^# ]] && continue

    if [[ ! "$relative_path" =~ ^migrations/foundation/[0-9]{3}_[a-z0-9_]+\.sql$ ]]; then
        log "Invalid Foundation manifest path: $relative_path"
        exit 65
    fi

    sql_file="$schema_root/$relative_path"
    if [[ ! -f "$sql_file" ]]; then
        log "Migration not found: $sql_file"
        exit 66
    fi

    migration_count=$((migration_count + 1))
    migration_id="$(basename "$relative_path" .sql)"
    checksum="$(sha256sum "$sql_file" | awk '{print $1}')"

    printf "INSERT INTO sql_test.expected_migrations (manifest_position, migration_id, relative_path, file_sha256) VALUES (%d, '%s', '%s', '%s');\n" \
        "$migration_count" "$migration_id" "$relative_path" "$checksum" >>"$expected_sql_file"

    log "Applying $relative_path"
    psql -X \
        --set=ON_ERROR_STOP=1 \
        --set=VERBOSITY=verbose \
        --set=SHOW_CONTEXT=errors \
        --dbname="$test_database" \
        --file="$sql_file"
done <"$manifest_file"

if [[ "$migration_count" -eq 0 ]]; then
    log "Foundation manifest contains no migrations"
    exit 65
fi
log "Applied $migration_count Foundation migration files"

log "Installing test-only assertion framework"
psql -X \
    --set=ON_ERROR_STOP=1 \
    --set=VERBOSITY=verbose \
    --set=SHOW_CONTEXT=errors \
    --dbname="$test_database" \
    --file="$framework_file"

log "Loading manifest expectations and file checksums"
psql -X \
    --set=ON_ERROR_STOP=1 \
    --set=VERBOSITY=verbose \
    --set=SHOW_CONTEXT=errors \
    --dbname="$test_database" \
    --file="$expected_sql_file"

log "Running Foundation SQL tests"
test_file_count=0
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    relative_path="$(printf '%s' "$raw_line" | sed 's/\r$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$relative_path" ]] && continue
    [[ "$relative_path" =~ ^# ]] && continue

    if [[ ! "$relative_path" =~ ^foundation/[0-9]{3}_[a-z0-9_]+\.sql$ ]]; then
        log "Invalid test manifest path: $relative_path"
        exit 65
    fi

    sql_file="$test_root/$relative_path"
    if [[ ! -f "$sql_file" ]]; then
        log "Test file not found: $sql_file"
        exit 66
    fi

    test_file_count=$((test_file_count + 1))
    log "Running $relative_path"
    psql -X \
        --set=ON_ERROR_STOP=1 \
        --set=VERBOSITY=verbose \
        --set=SHOW_CONTEXT=errors \
        --dbname="$test_database" \
        --file="$sql_file"
done <"$test_manifest"

if [[ "$test_file_count" -eq 0 ]]; then
    log "Test manifest contains no test files"
    exit 65
fi

log "Writing test result inventory"
psql -X --set=ON_ERROR_STOP=1 --dbname="$test_database" <<'SQL'
\pset border 2
\pset pager off
SELECT status, count(*) AS result_count
FROM sql_test.results
GROUP BY status
ORDER BY CASE status WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END;

SELECT result_id, status, test_file, test_name, COALESCE(details, '') AS details
FROM sql_test.results
WHERE status IN ('FAIL', 'WARN')
ORDER BY result_id;
SQL

log "Evaluating final test status"
psql -X --set=ON_ERROR_STOP=1 --dbname="$test_database" \
    --command='SELECT sql_test.finish();'

log "Foundation SQL tests passed"
