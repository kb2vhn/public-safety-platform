#!/usr/bin/env bash
#
# Public Safety Platform Foundation SQL test runner
#
# This runner intentionally lives inside:
#   sql/test-framework/sql/schema/scripts/
#
# It applies the live Foundation migrations from:
#   sql/schema/
#
# It runs test-only SQL from:
#   sql/test-framework/sql/tests/
#
# It writes logs and summaries beneath:
#   sql/test-framework/sql/test-results/
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

PROGRAM_NAME="$(basename -- "${BASH_SOURCE[0]}")"

usage() {
    cat <<USAGE
Usage:
  ${PROGRAM_NAME} [options]

Creates a disposable PostgreSQL database, applies the live Foundation
migration manifest, runs the SQL test suite, and writes timestamped log and
summary files inside the self-contained SQL test framework.

Options:
  --keep-database
      Keep the test database after a successful run.

  --drop-on-failure
      Drop the test database after a failed run. By default, failed databases
      are retained for investigation.

  --results-dir PATH
      Write result files beneath PATH instead of:
      sql/test-framework/sql/test-results

  -h, --help
      Show this help text.

PostgreSQL environment variables:
  PGHOST
  PGPORT
  PGUSER
  PGPASSWORD
  PGSSLMODE
      Standard libpq connection settings.

  PGMAINTENANCE_DB
      Database used by createdb and dropdb.
      Default: postgres

  TEST_DATABASE_NAME
      Optional disposable database name. It must begin with:
      psp_foundation_test_

  KEEP_TEST_DB=1
      Same as --keep-database.

  DROP_TEST_DB_ON_FAILURE=1
      Same as --drop-on-failure.

Examples:
  cd sql/test-framework
  make test-sql

  KEEP_TEST_DB=1 make test-sql

  ./sql/schema/scripts/test_foundation.sh --drop-on-failure
USAGE
}

timestamp_iso() {
    if date --iso-8601=seconds >/dev/null 2>&1; then
        date --iso-8601=seconds
    else
        date '+%Y-%m-%dT%H:%M:%S%z'
    fi
}

log() {
    printf '[%s] %s\n' "$(timestamp_iso)" "$*"
}

die() {
    local exit_code="$1"
    shift
    printf '%s\n' "$*" >&2
    exit "$exit_code"
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        die 69 "Required command not found: ${command_name}"
    fi
}

trim_manifest_line() {
    local line="$1"

    printf '%s' "$line" |
        sed 's/\r$//' |
        sed 's/[[:space:]]*#.*$//' |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
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
                die 64 "--results-dir requires a path"
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

case "$keep_database" in
    0|1) ;;
    *) die 64 "KEEP_TEST_DB must be 0 or 1" ;;
esac

case "$drop_on_failure" in
    0|1) ;;
    *) die 64 "DROP_TEST_DB_ON_FAILURE must be 0 or 1" ;;
esac

for command_name in \
    awk \
    basename \
    createdb \
    date \
    dirname \
    dropdb \
    grep \
    ln \
    mkdir \
    mktemp \
    psql \
    rm \
    sed \
    sha256sum \
    tee
do
    require_command "$command_name"
done

# ---------------------------------------------------------------------------
# Resolve the intentionally separate repository and test-framework trees.
#
# Current script:
#   <repo>/sql/test-framework/sql/schema/scripts/test_foundation.sh
#
# Live migrations:
#   <repo>/sql/schema/
#
# Test-only assets:
#   <repo>/sql/test-framework/sql/
# ---------------------------------------------------------------------------

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
test_sql_root="$(cd -- "${script_dir}/../.." && pwd -P)"
test_framework_root="$(cd -- "${test_sql_root}/.." && pwd -P)"
repository_root="$(cd -- "${test_framework_root}/../.." && pwd -P)"

foundation_schema_root="${repository_root}/sql/schema"
foundation_manifest="${foundation_schema_root}/manifests/foundation.manifest"

test_root="${test_sql_root}/tests"
test_manifest="${test_root}/foundation-tests.manifest"
framework_file="${test_root}/framework/000_test_framework.sql"

if [[ -n "$results_dir_override" ]]; then
    mkdir -p -- "$results_dir_override"
    results_dir="$(cd -- "$results_dir_override" && pwd -P)"
else
    results_dir="${test_sql_root}/test-results"
    mkdir -p -- "$results_dir"
    results_dir="$(cd -- "$results_dir" && pwd -P)"
fi

[[ -d "$foundation_schema_root" ]] ||
    die 66 "Live Foundation schema directory not found: ${foundation_schema_root}"

[[ -f "$foundation_manifest" ]] ||
    die 66 "Live Foundation manifest not found: ${foundation_manifest}"

[[ -f "$test_manifest" ]] ||
    die 66 "Test manifest not found: ${test_manifest}"

[[ -f "$framework_file" ]] ||
    die 66 "Test assertion framework not found: ${framework_file}"

timestamp="$(date +%Y%m%d_%H%M%S)"
run_id="foundation_${timestamp}_$$"

log_file="${results_dir}/${run_id}.log"
summary_file="${results_dir}/${run_id}-summary.txt"
latest_log="${results_dir}/latest.log"
latest_summary="${results_dir}/latest-summary.txt"

maintenance_db="${PGMAINTENANCE_DB:-postgres}"
test_database="${TEST_DATABASE_NAME:-psp_foundation_test_${timestamp}_$$}"

if [[ ! "$test_database" =~ ^psp_foundation_test_[A-Za-z0-9_]+$ ]]; then
    die 64 \
        "Unsafe test database name: ${test_database}
The name must begin with psp_foundation_test_ and contain only letters,
numbers, and underscores."
fi

if (( ${#test_database} > 63 )); then
    die 64 "Test database name exceeds PostgreSQL's 63-byte identifier limit: ${test_database}"
fi

: >"$log_file"
rm -f -- "$latest_log" "$latest_summary"
ln -s -- "$(basename -- "$log_file")" "$latest_log"

# Send all subsequent output to both the terminal and the timestamped log.
exec > >(tee -a "$log_file") 2>&1

export PGAPPNAME="public-safety-platform-foundation-test"

database_created=0
expected_sql_file="$(mktemp "${TMPDIR:-/tmp}/psp-foundation-expected.XXXXXX.sql")"
migration_count=0
test_file_count=0

write_summary() {
    local runner_exit_status="$1"
    local overall_result="FAIL"
    local summary_status=0

    if [[ "$runner_exit_status" -eq 0 ]]; then
        overall_result="PASS"
    fi

    if [[ "$database_created" -ne 1 ]]; then
        return 0
    fi

    if ! psql \
        -X \
        --dbname="$test_database" \
        --tuples-only \
        --no-align \
        --command="SELECT 1 FROM pg_namespace WHERE nspname = 'sql_test';" \
        2>/dev/null |
        grep -qx '1'
    then
        return 0
    fi

    {
        printf 'Public Safety Platform - Foundation SQL Test Summary\n'
        printf '====================================================\n'
        printf 'Run ID: %s\n' "$run_id"
        printf 'Overall result: %s\n' "$overall_result"
        printf 'Runner exit status: %s\n' "$runner_exit_status"
        printf 'Database: %s\n' "$test_database"
        printf 'Completed: %s\n' "$(timestamp_iso)"
        printf 'Full log: %s\n\n' "$log_file"

        psql \
            -X \
            --set=ON_ERROR_STOP=1 \
            --dbname="$test_database" <<'SQL'
\pset border 2
\pset pager off

\echo 'Result totals'
SELECT
    status,
    count(*) AS result_count
FROM sql_test.results
GROUP BY status
ORDER BY
    CASE status
        WHEN 'FAIL' THEN 1
        WHEN 'WARN' THEN 2
        ELSE 3
    END;

\echo ''
\echo 'Failed assertions'
SELECT
    test_file,
    test_name,
    COALESCE(details, '') AS details
FROM sql_test.results
WHERE status = 'FAIL'
ORDER BY result_id;

\echo ''
\echo 'Warnings'
SELECT
    test_file,
    test_name,
    COALESCE(details, '') AS details
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
        log "Could not write the SQL summary; use the full log instead."
        rm -f -- "$summary_file"
        return 0
    fi

    ln -s -- "$(basename -- "$summary_file")" "$latest_summary"
}

cleanup() {
    local exit_status=$?

    trap - EXIT INT TERM
    set +e

    write_summary "$exit_status"

    rm -f -- "$expected_sql_file"

    if [[ "$database_created" -eq 1 ]]; then
        if [[ "$exit_status" -eq 0 ]]; then
            if [[ "$keep_database" == "1" ]]; then
                log "Successful test database retained: ${test_database}"
                log "Inspect it with: psql --dbname=${test_database}"
            else
                log "Dropping successful test database: ${test_database}"
                dropdb \
                    --if-exists \
                    --maintenance-db="$maintenance_db" \
                    "$test_database"
            fi
        else
            if [[ "$drop_on_failure" == "1" ]]; then
                log "Dropping failed test database by request: ${test_database}"
                dropdb \
                    --if-exists \
                    --maintenance-db="$maintenance_db" \
                    "$test_database"
            else
                log "FAILED test database retained for investigation: ${test_database}"
                log "Inspect it with: psql --dbname=${test_database}"
            fi
        fi
    fi

    if [[ -f "$summary_file" ]]; then
        log "Summary: ${summary_file}"
        log "Latest summary: ${latest_summary}"
    fi

    log "Full log: ${log_file}"
    log "Latest log: ${latest_log}"

    exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

log "Foundation SQL test run started"
log "Repository root: ${repository_root}"
log "Live schema root: ${foundation_schema_root}"
log "Foundation manifest: ${foundation_manifest}"
log "Test framework root: ${test_framework_root}"
log "Test manifest: ${test_manifest}"
log "Maintenance database: ${maintenance_db}"
log "Test database: ${test_database}"
log "Results directory: ${results_dir}"

quoted_test_database="$(quote_sql_literal "$test_database")"

if psql \
    -X \
    --dbname="$maintenance_db" \
    --tuples-only \
    --no-align \
    --command="SELECT 1 FROM pg_database WHERE datname = '${quoted_test_database}';" |
    grep -qx '1'
then
    log "Refusing to overwrite existing database: ${test_database}"
    exit 65
fi

log "Creating disposable database from template0"
createdb \
    --maintenance-db="$maintenance_db" \
    --template=template0 \
    "$test_database"

database_created=1

server_version="$(
    psql \
        -X \
        --dbname="$test_database" \
        --tuples-only \
        --no-align \
        --command='SHOW server_version;'
)"

server_version_num="$(
    psql \
        -X \
        --dbname="$test_database" \
        --tuples-only \
        --no-align \
        --command="SELECT current_setting('server_version_num');"
)"

log "PostgreSQL server version: ${server_version} (${server_version_num})"

if [[ ! "$server_version_num" =~ ^[0-9]+$ ]]; then
    log "Unable to interpret PostgreSQL server_version_num: ${server_version_num}"
    exit 65
fi

if (( server_version_num < 180000 )); then
    log "PostgreSQL 18 or newer is required; connected server reports ${server_version}"
    exit 69
fi

: >"$expected_sql_file"
printf '%s\n' 'TRUNCATE TABLE sql_test.expected_migrations;' >>"$expected_sql_file"

declare -A seen_migrations=()

log "Applying live Foundation migrations"

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    relative_path="$(trim_manifest_line "$raw_line")"

    [[ -z "$relative_path" ]] && continue

    if [[ ! "$relative_path" =~ ^migrations/foundation/[0-9]{3}_[a-z0-9_]+\.sql$ ]]; then
        log "Invalid Foundation manifest path: ${relative_path}"
        exit 65
    fi

    if [[ -n "${seen_migrations[$relative_path]:-}" ]]; then
        log "Duplicate Foundation manifest entry: ${relative_path}"
        exit 65
    fi
    seen_migrations["$relative_path"]=1

    sql_file="${foundation_schema_root}/${relative_path}"

    if [[ ! -f "$sql_file" ]]; then
        log "Migration file not found: ${sql_file}"
        exit 66
    fi

    migration_count=$((migration_count + 1))
    migration_id="$(basename -- "$relative_path" .sql)"
    checksum="$(sha256sum "$sql_file" | awk '{print $1}')"

    printf \
        "INSERT INTO sql_test.expected_migrations
            (manifest_position, migration_id, relative_path, file_sha256)
         VALUES
            (%d, '%s', '%s', '%s');\n" \
        "$migration_count" \
        "$migration_id" \
        "$relative_path" \
        "$checksum" \
        >>"$expected_sql_file"

    log "Applying ${relative_path}"

    psql \
        -X \
        --set=ON_ERROR_STOP=1 \
        --set=VERBOSITY=verbose \
        --set=SHOW_CONTEXT=errors \
        --dbname="$test_database" \
        --file="$sql_file"
done <"$foundation_manifest"

if [[ "$migration_count" -eq 0 ]]; then
    log "Foundation manifest contains no migration files"
    exit 65
fi

log "Applied ${migration_count} Foundation migration files"

log "Installing the test-only SQL assertion framework"
psql \
    -X \
    --set=ON_ERROR_STOP=1 \
    --set=VERBOSITY=verbose \
    --set=SHOW_CONTEXT=errors \
    --dbname="$test_database" \
    --file="$framework_file"

log "Loading migration manifest expectations and SHA-256 checksums"
psql \
    -X \
    --set=ON_ERROR_STOP=1 \
    --set=VERBOSITY=verbose \
    --set=SHOW_CONTEXT=errors \
    --dbname="$test_database" \
    --file="$expected_sql_file"

declare -A seen_tests=()

log "Running Foundation SQL tests"

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    relative_path="$(trim_manifest_line "$raw_line")"

    [[ -z "$relative_path" ]] && continue

    if [[ ! "$relative_path" =~ ^foundation/[0-9]{3}_[a-z0-9_]+\.sql$ ]]; then
        log "Invalid test manifest path: ${relative_path}"
        exit 65
    fi

    if [[ -n "${seen_tests[$relative_path]:-}" ]]; then
        log "Duplicate test manifest entry: ${relative_path}"
        exit 65
    fi
    seen_tests["$relative_path"]=1

    sql_file="${test_root}/${relative_path}"

    if [[ ! -f "$sql_file" ]]; then
        log "Test file not found: ${sql_file}"
        exit 66
    fi

    test_file_count=$((test_file_count + 1))

    log "Running ${relative_path}"

    psql \
        -X \
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

log "Executed ${test_file_count} Foundation test files"

log "Writing the test result inventory"
psql \
    -X \
    --set=ON_ERROR_STOP=1 \
    --dbname="$test_database" <<'SQL'
\pset border 2
\pset pager off

SELECT
    status,
    count(*) AS result_count
FROM sql_test.results
GROUP BY status
ORDER BY
    CASE status
        WHEN 'FAIL' THEN 1
        WHEN 'WARN' THEN 2
        ELSE 3
    END;

SELECT
    result_id,
    status,
    test_file,
    test_name,
    COALESCE(details, '') AS details
FROM sql_test.results
WHERE status IN ('FAIL', 'WARN')
ORDER BY result_id;
SQL

log "Evaluating final test status"

psql \
    -X \
    --set=ON_ERROR_STOP=1 \
    --dbname="$test_database" \
    --command='SELECT sql_test.finish();'

log "Foundation SQL tests passed"
