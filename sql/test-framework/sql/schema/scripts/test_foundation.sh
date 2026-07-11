#!/usr/bin/env bash
#
# Public Safety Platform Foundation SQL test runner
#
# This runner intentionally lives inside:
#
#   sql/test-framework/sql/schema/scripts/
#
# It applies live Foundation migrations from:
#
#   sql/schema/
#
# It runs test-only SQL from:
#
#   sql/test-framework/sql/tests/
#
# It writes logs and summaries beneath:
#
#   sql/test-framework/sql/test-results/
#
# The dependency, repository, and PostgreSQL preflights complete before the
# runner creates a results directory, log file, temporary file, or database.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

usage() {
    printf '%s\n' \
        'Usage: test_foundation.sh [options]' \
        '' \
        'Creates a disposable PostgreSQL database, applies the live Foundation' \
        'migration manifest, runs the SQL test suite, and writes timestamped' \
        'log and summary files.' \
        '' \
        'Options:' \
        '  --keep-database' \
        '      Keep the test database after a successful run.' \
        '' \
        '  --drop-on-failure' \
        '      Drop the test database after a failed run.' \
        '' \
        '  --results-dir PATH' \
        '      Write results beneath PATH instead of the default test-results' \
        '      directory.' \
        '' \
        '  -h, --help' \
        '      Show this help text.' \
        '' \
        'Environment:' \
        '  PGHOST, PGPORT, PGUSER, PGPASSWORD, PGSSLMODE' \
        '      Standard PostgreSQL connection settings.' \
        '' \
        '  PGMAINTENANCE_DB' \
        '      Database used for preflight, createdb, and dropdb.' \
        '      Default: postgres' \
        '' \
        '  TEST_DATABASE_NAME' \
        '      Optional disposable database name. It must begin with' \
        '      psp_foundation_test_.' \
        '' \
        '  KEEP_TEST_DB=1' \
        '      Same as --keep-database.' \
        '' \
        '  DROP_TEST_DB_ON_FAILURE=1' \
        '      Same as --drop-on-failure.'
}

die() {
    local exit_code="$1"
    shift

    printf '%s\n' "$*" >&2
    exit "$exit_code"
}

timestamp_iso() {
    date --iso-8601=seconds
}

log() {
    printf '[%s] %s\n' "$(timestamp_iso)" "$*"
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

print_dependency_failure() {
    local -n missing_command_list_ref="$1"
    local -n missing_package_list_ref="$2"
    local command_name
    local package_name
    local package_line=""

    printf 'Dependency preflight: FAIL\n\n' >&2
    printf 'Missing required commands:\n' >&2

    for command_name in "${missing_command_list_ref[@]}"; do
        package_name="${COMMAND_PACKAGE_MAP[$command_name]}"
        printf '  %-12s Arch package: %s\n' \
            "$command_name" \
            "$package_name" >&2
    done

    printf -v package_line '%s ' "${missing_package_list_ref[@]}"
    package_line="${package_line% }"

    printf '\nInstall all missing packages with:\n\n' >&2
    printf '  sudo pacman -S --needed %s\n' "$package_line" >&2
    printf '\nWhen operating as root without sudo:\n\n' >&2
    printf '  pacman -S --needed %s\n' "$package_line" >&2
    printf '\nNo results directory, log file, temporary file, or database was created.\n' >&2
}

preflight_dependencies() {
    local -a required_commands=(
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
    )
    local -a missing_commands=()
    local -a missing_packages=()
    local -A seen_packages=()
    local command_name
    local package_name

    for command_name in "${required_commands[@]}"; do
        if command -v "$command_name" >/dev/null 2>&1; then
            continue
        fi

        missing_commands+=("$command_name")
        package_name="${COMMAND_PACKAGE_MAP[$command_name]}"

        if [[ -z "${seen_packages[$package_name]:-}" ]]; then
            missing_packages+=("$package_name")
            seen_packages["$package_name"]=1
        fi
    done

    if [[ "${#missing_commands[@]}" -ne 0 ]]; then
        print_dependency_failure missing_commands missing_packages
        exit 69
    fi

    printf 'Dependency preflight: PASS\n'
}

preflight_postgresql() {
    local maintenance_database="$1"
    local preflight_result
    local server_version_number
    local connected_role
    local can_create_database

    printf 'PostgreSQL preflight: checking connection, version, and role privilege...\n'

    if ! preflight_result="$(
        psql \
            -X \
            --no-psqlrc \
            --set=ON_ERROR_STOP=1 \
            --tuples-only \
            --no-align \
            --dbname="$maintenance_database" \
            --command="
                SELECT
                    current_setting('server_version_num')
                    || '|'
                    || current_user
                    || '|'
                    || CASE
                        WHEN role_record.rolsuper
                          OR role_record.rolcreatedb
                        THEN '1'
                        ELSE '0'
                       END
                FROM pg_roles AS role_record
                WHERE role_record.rolname = current_user;
            "
    )"; then
        printf '\nPostgreSQL preflight: FAIL\n' >&2
        printf 'Could not connect to maintenance database: %s\n' \
            "$maintenance_database" >&2
        printf 'Check PGHOST, PGPORT, PGUSER, PGPASSWORD, and PGSSLMODE.\n' >&2
        printf 'No results directory, log file, temporary file, or database was created.\n' >&2
        exit 69
    fi

    IFS='|' read -r \
        server_version_number \
        connected_role \
        can_create_database \
        <<<"$preflight_result"

    if [[ ! "$server_version_number" =~ ^[0-9]+$ ]]; then
        printf '\nPostgreSQL preflight: FAIL\n' >&2
        printf 'Could not interpret server_version_num: %s\n' \
            "$server_version_number" >&2
        printf 'No results directory, log file, temporary file, or database was created.\n' >&2
        exit 69
    fi

    if (( server_version_number < 180000 )); then
        printf '\nPostgreSQL preflight: FAIL\n' >&2
        printf 'PostgreSQL 18 or newer is required; server_version_num=%s\n' \
            "$server_version_number" >&2
        printf 'No results directory, log file, temporary file, or database was created.\n' >&2
        exit 69
    fi

    if [[ "$can_create_database" != "1" ]]; then
        printf '\nPostgreSQL preflight: FAIL\n' >&2
        printf 'Connected role %s lacks CREATEDB or SUPERUSER.\n' \
            "$connected_role" >&2
        printf 'The disposable test framework must create and drop its test database.\n' >&2
        printf 'No results directory, log file, temporary file, or database was created.\n' >&2
        exit 77
    fi

    POSTGRESQL_SERVER_VERSION_NUM="$server_version_number"
    POSTGRESQL_CONNECTED_ROLE="$connected_role"

    printf 'PostgreSQL preflight: PASS (role=%s, server_version_num=%s)\n' \
        "$connected_role" \
        "$server_version_number"
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
    0|1)
        ;;
    *)
        die 64 "KEEP_TEST_DB must be 0 or 1"
        ;;
esac

case "$drop_on_failure" in
    0|1)
        ;;
    *)
        die 64 "DROP_TEST_DB_ON_FAILURE must be 0 or 1"
        ;;
esac

if (( BASH_VERSINFO[0] < 4 )); then
    printf 'Bash 4 or newer is required; running version is %s\n' \
        "${BASH_VERSION}" >&2
    printf 'Arch Linux package: bash\n' >&2
    printf 'No results directory, log file, temporary file, or database was created.\n' >&2
    exit 69
fi

declare -A COMMAND_PACKAGE_MAP=(
    [awk]="gawk"
    [basename]="coreutils"
    [createdb]="postgresql-libs"
    [date]="coreutils"
    [dirname]="coreutils"
    [dropdb]="postgresql-libs"
    [grep]="grep"
    [ln]="coreutils"
    [mkdir]="coreutils"
    [mktemp]="coreutils"
    [psql]="postgresql-libs"
    [rm]="coreutils"
    [sed]="sed"
    [sha256sum]="coreutils"
    [tee]="coreutils"
)

preflight_dependencies

# ---------------------------------------------------------------------------
# Resolve the intentionally separate repository and test-framework trees.
#
# Current script:
#   /sql/test-framework/sql/schema/scripts/test_foundation.sh
#
# Live migrations:
#   /sql/schema/
#
# Test-only assets:
#   /sql/test-framework/sql/
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

[[ -d "$foundation_schema_root" ]] ||
    die 66 "Live Foundation schema directory not found: ${foundation_schema_root}"

[[ -f "$foundation_manifest" ]] ||
    die 66 "Live Foundation manifest not found: ${foundation_manifest}"

[[ -f "$test_manifest" ]] ||
    die 66 "Test manifest not found: ${test_manifest}"

[[ -f "$framework_file" ]] ||
    die 66 "Test assertion framework not found: ${framework_file}"

maintenance_db="${PGMAINTENANCE_DB:-postgres}"

export PGAPPNAME="public-safety-platform-foundation-test"

POSTGRESQL_SERVER_VERSION_NUM=""
POSTGRESQL_CONNECTED_ROLE=""

preflight_postgresql "$maintenance_db"

timestamp="$(date +%Y%m%d_%H%M%S)"
run_id="foundation_${timestamp}_$$"
test_database="${TEST_DATABASE_NAME:-psp_foundation_test_${timestamp}_$$}"

if [[ ! "$test_database" =~ ^psp_foundation_test_[A-Za-z0-9_]+$ ]]; then
    die 64 \
        "Unsafe test database name: ${test_database}
The name must begin with psp_foundation_test_ and contain only letters, numbers, and underscores.
No results directory, log file, temporary file, or database was created."
fi

if (( ${#test_database} > 63 )); then
    die 64 \
        "Test database name exceeds PostgreSQL's 63-byte identifier limit: ${test_database}
No results directory, log file, temporary file, or database was created."
fi

quoted_test_database="$(quote_sql_literal "$test_database")"

if psql \
    -X \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --dbname="$maintenance_db" \
    --tuples-only \
    --no-align \
    --command="
        SELECT 1
        FROM pg_database
        WHERE datname = '${quoted_test_database}';
    " |
    grep -qx '1'
then
    die 65 \
        "Refusing to overwrite existing database: ${test_database}
No results directory, log file, or temporary file was created."
fi

if [[ -n "$results_dir_override" ]]; then
    mkdir -p -- "$results_dir_override"
    results_dir="$(cd -- "$results_dir_override" && pwd -P)"
else
    results_dir="${test_sql_root}/test-results"
    mkdir -p -- "$results_dir"
    results_dir="$(cd -- "$results_dir" && pwd -P)"
fi

log_file="${results_dir}/${run_id}.log"
summary_file="${results_dir}/${run_id}-summary.txt"
latest_log="${results_dir}/latest.log"
latest_summary="${results_dir}/latest-summary.txt"

: >"$log_file"
rm -f -- "$latest_log" "$latest_summary"
ln -s -- "$(basename -- "$log_file")" "$latest_log"

# Send all subsequent output to both the terminal and the timestamped log.
exec > >(tee -a "$log_file") 2>&1

database_created=0
expected_sql_file=""
migration_count=0
test_file_count=0

expected_sql_file="$(
    mktemp "${TMPDIR:-/tmp}/psp-foundation-expected.XXXXXX.sql"
)"

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
        --no-psqlrc \
        --dbname="$test_database" \
        --tuples-only \
        --no-align \
        --command="
            SELECT 1
            FROM pg_namespace
            WHERE nspname = 'sql_test';
        " \
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
            --no-psqlrc \
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
    (
        SELECT count(*)
        FROM sql_test.expected_migrations
    ) AS manifest_migrations,
    (
        SELECT count(*)
        FROM foundation_meta.applied_migrations
    ) AS registered_migrations;
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

    if [[ -n "$expected_sql_file" ]]; then
        rm -f -- "$expected_sql_file"
    fi

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
log "Connected PostgreSQL role: ${POSTGRESQL_CONNECTED_ROLE}"
log "PostgreSQL server_version_num: ${POSTGRESQL_SERVER_VERSION_NUM}"
log "Test database: ${test_database}"
log "Results directory: ${results_dir}"

log "Creating disposable database from template0"

createdb \
    --maintenance-db="$maintenance_db" \
    --template=template0 \
    "$test_database"

database_created=1

server_version="$(
    psql \
        -X \
        --no-psqlrc \
        --dbname="$test_database" \
        --tuples-only \
        --no-align \
        --command='SHOW server_version;'
)"

server_version_num="$(
    psql \
        -X \
        --no-psqlrc \
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
printf '%s\n' \
    'TRUNCATE TABLE sql_test.expected_migrations;' \
    >>"$expected_sql_file"

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
        "INSERT INTO sql_test.expected_migrations (manifest_position, migration_id, relative_path, file_sha256) VALUES (%d, '%s', '%s', '%s');\n" \
        "$migration_count" \
        "$migration_id" \
        "$relative_path" \
        "$checksum" \
        >>"$expected_sql_file"

    log "Applying ${relative_path}"

    psql \
        -X \
        --no-psqlrc \
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
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --set=VERBOSITY=verbose \
    --set=SHOW_CONTEXT=errors \
    --dbname="$test_database" \
    --file="$framework_file"

log "Loading migration manifest expectations and SHA-256 checksums"

psql \
    -X \
    --no-psqlrc \
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
        --no-psqlrc \
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
    --no-psqlrc \
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
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --dbname="$test_database" \
    --command='SELECT sql_test.finish();'

log "Foundation SQL tests passed"
