#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

usage() {
    cat <<'EOF'
Usage: test_foundation_with_resources.sh [options]

Run the normal Foundation correctness suite, retain its disposable database
long enough to record resource observations, write text and JSON reports, and
then drop a successful database unless retention was requested.

Options:
  --keep-database       Retain the successful test database after telemetry.
  --drop-on-failure     Ask the normal runner to drop a failed test database.
  --results-dir PATH    Write all results beneath PATH.
  --label TEXT          Add a non-secret comparison label to resource reports.
  -h, --help            Show this help text.

Correctness and resource observations are separate outcomes. Resource values
are observation-only until governed performance budgets are established.
EOF
}

die() {
    local exit_code="$1"
    shift
    printf '%s\n' "$*" >&2
    exit "$exit_code"
}

quote_sql_literal() {
    local value="$1"
    printf '%s' "${value//\'/\'\'}"
}

print_dependency_failure() {
    local -n commands_ref="$1"
    local -n packages_ref="$2"
    local command_name
    local package_name
    local package_line

    printf 'Resource telemetry dependency preflight: FAIL\n\n' >&2
    printf 'Missing required commands:\n' >&2

    for command_name in "${commands_ref[@]}"; do
        package_name="${COMMAND_PACKAGE_MAP[$command_name]}"
        printf '  %-18s Arch package: %s\n' \
            "$command_name" \
            "$package_name" >&2
    done

    printf -v package_line '%s ' "${packages_ref[@]}"
    package_line="${package_line% }"

    printf '\nInstall all missing packages with:\n\n' >&2
    printf '  sudo pacman -S --needed %s\n' "$package_line" >&2
    printf '\nWhen operating as root without sudo:\n\n' >&2
    printf '  pacman -S --needed %s\n' "$package_line" >&2
    printf '\nNo result file, temporary file, or database was created.\n' >&2
}

keep_database=0
drop_on_failure=0
results_dir_override=""
observation_label=""

while (( $# > 0 )); do
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
            (( $# >= 2 )) || die 64 '--results-dir requires a path'
            results_dir_override="$2"
            shift 2
            ;;
        --label)
            (( $# >= 2 )) || die 64 '--label requires text'
            observation_label="$2"
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

if [[ "$observation_label" == *$'\n'* || "$observation_label" == *$'\r'* ]]; then
    die 64 'Observation label must be a single line'
fi

if (( BASH_VERSINFO[0] < 4 )); then
    printf 'Bash 4 or newer is required.\n' >&2
    printf 'Arch package: bash\n' >&2
    printf 'Install with: sudo pacman -S --needed bash\n' >&2
    printf 'No result file, temporary file, or database was created.\n' >&2
    exit 69
fi

declare -A COMMAND_PACKAGE_MAP=(
    [awk]='gawk'
    [basename]='coreutils'
    [date]='coreutils'
    [dirname]='coreutils'
    [dropdb]='postgresql-libs'
    [grep]='grep'
    [ln]='coreutils'
    [mkdir]='coreutils'
    [mktemp]='coreutils'
    [nproc]='coreutils'
    [psql]='postgresql-libs'
    [python3]='python'
    [rm]='coreutils'
    [sed]='sed'
    [sleep]='coreutils'
    [uname]='coreutils'
    [/usr/bin/time]='time'
)

required_commands=(
    awk
    basename
    date
    dirname
    dropdb
    grep
    ln
    mkdir
    mktemp
    nproc
    psql
    python3
    rm
    sed
    sleep
    uname
)

missing_commands=()
missing_packages=()
declare -A seen_packages=()

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

if [[ ! -x /usr/bin/time ]]; then
    missing_commands+=('/usr/bin/time')
    if [[ -z "${seen_packages[time]:-}" ]]; then
        missing_packages+=('time')
        seen_packages[time]=1
    fi
fi

if (( ${#missing_commands[@]} > 0 )); then
    print_dependency_failure missing_commands missing_packages
    exit 69
fi

printf 'Resource telemetry dependency preflight: PASS\n'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
test_sql_root="$(cd -- "${script_dir}/../.." && pwd -P)"
runner="${script_dir}/test_foundation.sh"

[[ -x "$runner" ]] \
    || die 66 "Foundation correctness runner is not executable: ${runner}"

maintenance_db="${PGMAINTENANCE_DB:-postgres}"

if ! start_probe="$(
    psql \
        -X \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --tuples-only \
        --no-align \
        --dbname="$maintenance_db" \
        --command="
            SELECT
                pg_current_wal_lsn()::text || '|' ||
                current_setting('server_version') || '|' ||
                current_setting('server_version_num') || '|' ||
                current_user;
        "
)"; then
    die 69 \
        "Resource telemetry PostgreSQL preflight failed for maintenance database: ${maintenance_db}"
fi

IFS='|' read -r \
    start_wal_lsn \
    postgresql_version \
    postgresql_version_num \
    connected_role \
    <<<"$start_probe"

printf 'Resource telemetry PostgreSQL preflight: PASS (role=%s, server_version_num=%s)\n' \
    "$connected_role" \
    "$postgresql_version_num"

if [[ -n "$results_dir_override" ]]; then
    mkdir -p -- "$results_dir_override"
    results_dir="$(cd -- "$results_dir_override" && pwd -P)"
else
    results_dir="${test_sql_root}/test-results"
    mkdir -p -- "$results_dir"
    results_dir="$(cd -- "$results_dir" && pwd -P)"
fi

time_file="$(mktemp "${TMPDIR:-/tmp}/psp-foundation-time.XXXXXX")"

cleanup_time_file() {
    rm -f -- "$time_file"
}

trap cleanup_time_file EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

runner_args=(
    --keep-database
    --results-dir "$results_dir"
)

if (( drop_on_failure == 1 )); then
    runner_args+=(--drop-on-failure)
fi

start_epoch_ns="$(date +%s%N)"

set +e
LC_ALL=C /usr/bin/time \
    --verbose \
    --output="$time_file" \
    "$runner" "${runner_args[@]}"
runner_status=$?
set -e

end_epoch_ns="$(date +%s%N)"
summary_file="${results_dir}/latest-summary.txt"
log_file="${results_dir}/latest.log"

[[ -f "$summary_file" ]] || die 70 \
    "Correctness runner did not create ${summary_file}; resource telemetry cannot be completed"

run_id="$(awk -F': ' '/^Run ID:/ {print $2; exit}' "$summary_file")"
test_database="$(awk -F': ' '/^Database:/ {print $2; exit}' "$summary_file")"
overall_result="$(awk -F': ' '/^Overall result:/ {print $2; exit}' "$summary_file")"

[[ -n "$run_id" ]] || die 70 \
    'Could not read Run ID from the correctness summary'

[[ "$test_database" =~ ^psp_foundation_test_[A-Za-z0-9_]+$ ]] \
    || die 70 "Unsafe or missing test database name in summary: ${test_database}"

quoted_test_database="$(quote_sql_literal "$test_database")"

database_exists="$(
    psql \
        -X \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --tuples-only \
        --no-align \
        --dbname="$maintenance_db" \
        --command="
            SELECT CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM pg_database
                    WHERE datname = '${quoted_test_database}'
                ) THEN '1'
                ELSE '0'
            END;
        "
)"

database_stats='|||||||||||'
database_size_bytes=''

if [[ "$database_exists" == '1' ]]; then
    sleep 1

    database_stats="$(
        psql \
            -X \
            --no-psqlrc \
            --set=ON_ERROR_STOP=1 \
            --tuples-only \
            --no-align \
            --dbname="$maintenance_db" \
            --command="
                SELECT pg_stat_clear_snapshot();

                SELECT
                    COALESCE(xact_commit, 0) || '|' ||
                    COALESCE(xact_rollback, 0) || '|' ||
                    COALESCE(blks_read, 0) || '|' ||
                    COALESCE(blks_hit, 0) || '|' ||
                    COALESCE(temp_files, 0) || '|' ||
                    COALESCE(temp_bytes, 0) || '|' ||
                    COALESCE(deadlocks, 0) || '|' ||
                    COALESCE(tup_returned, 0) || '|' ||
                    COALESCE(tup_fetched, 0) || '|' ||
                    COALESCE(tup_inserted, 0) || '|' ||
                    COALESCE(tup_updated, 0) || '|' ||
                    COALESCE(tup_deleted, 0)
                FROM pg_stat_database
                WHERE datname = '${quoted_test_database}';
            " \
        | grep -E '^[0-9|]+$' \
        | tail -n 1
    )"

    database_size_bytes="$(
        psql \
            -X \
            --no-psqlrc \
            --set=ON_ERROR_STOP=1 \
            --tuples-only \
            --no-align \
            --dbname="$maintenance_db" \
            --command="SELECT pg_database_size('${quoted_test_database}');"
    )"
fi

end_wal_lsn="$(
    psql \
        -X \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --tuples-only \
        --no-align \
        --dbname="$maintenance_db" \
        --command='SELECT pg_current_wal_lsn()::text;'
)"

wal_bytes="$(
    psql \
        -X \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --tuples-only \
        --no-align \
        --dbname="$maintenance_db" \
        --command="
            SELECT pg_wal_lsn_diff(
                '${end_wal_lsn}',
                '${start_wal_lsn}'
            )::bigint;
        "
)"

IFS='|' read -r \
    xact_commit \
    xact_rollback \
    blks_read \
    blks_hit \
    temp_files \
    temp_bytes \
    deadlocks \
    tup_returned \
    tup_fetched \
    tup_inserted \
    tup_updated \
    tup_deleted \
    <<<"$database_stats"

logical_cpus="$(nproc)"
installed_memory_kib="$(
    awk '/^MemTotal:/ {print $2; exit}' \
        /proc/meminfo 2>/dev/null || true
)"
cpu_model="$(
    awk -F': ' '/^model name[[:space:]]*:/ {print $2; exit}' \
        /proc/cpuinfo 2>/dev/null || true
)"

[[ -n "$cpu_model" ]] || cpu_model='unavailable'

resource_collection_epoch_ns="$(date +%s%N)"

resource_text="${results_dir}/${run_id}-resources.txt"
resource_json="${results_dir}/${run_id}-resources.json"
latest_resource_text="${results_dir}/latest-resources.txt"
latest_resource_json="${results_dir}/latest-resources.json"

export ISSP_RESOURCE_RUN_ID="$run_id"
export ISSP_RESOURCE_DATABASE="$test_database"
export ISSP_RESOURCE_DATABASE_EXISTS="$database_exists"
export ISSP_RESOURCE_OVERALL_RESULT="$overall_result"
export ISSP_RESOURCE_RUNNER_STATUS="$runner_status"
export ISSP_RESOURCE_LABEL="$observation_label"
export ISSP_RESOURCE_START_NS="$start_epoch_ns"
export ISSP_RESOURCE_END_NS="$end_epoch_ns"
export ISSP_RESOURCE_COLLECTION_NS="$resource_collection_epoch_ns"
export ISSP_RESOURCE_TIME_FILE="$time_file"
export ISSP_RESOURCE_LOG_FILE="$log_file"
export ISSP_RESOURCE_TEXT_FILE="$resource_text"
export ISSP_RESOURCE_JSON_FILE="$resource_json"
export ISSP_RESOURCE_HOST="$(uname -n)"
export ISSP_RESOURCE_KERNEL="$(uname -srmo)"
export ISSP_RESOURCE_LOGICAL_CPUS="$logical_cpus"
export ISSP_RESOURCE_CPU_MODEL="$cpu_model"
export ISSP_RESOURCE_MEMORY_KIB="$installed_memory_kib"
export ISSP_RESOURCE_POSTGRES_VERSION="$postgresql_version"
export ISSP_RESOURCE_POSTGRES_VERSION_NUM="$postgresql_version_num"
export ISSP_RESOURCE_POSTGRES_ROLE="$connected_role"
export ISSP_RESOURCE_DB_SIZE_BYTES="$database_size_bytes"
export ISSP_RESOURCE_WAL_BYTES="$wal_bytes"
export ISSP_RESOURCE_WAL_START="$start_wal_lsn"
export ISSP_RESOURCE_WAL_END="$end_wal_lsn"
export ISSP_RESOURCE_XACT_COMMIT="$xact_commit"
export ISSP_RESOURCE_XACT_ROLLBACK="$xact_rollback"
export ISSP_RESOURCE_BLKS_READ="$blks_read"
export ISSP_RESOURCE_BLKS_HIT="$blks_hit"
export ISSP_RESOURCE_TEMP_FILES="$temp_files"
export ISSP_RESOURCE_TEMP_BYTES="$temp_bytes"
export ISSP_RESOURCE_DEADLOCKS="$deadlocks"
export ISSP_RESOURCE_TUP_RETURNED="$tup_returned"
export ISSP_RESOURCE_TUP_FETCHED="$tup_fetched"
export ISSP_RESOURCE_TUP_INSERTED="$tup_inserted"
export ISSP_RESOURCE_TUP_UPDATED="$tup_updated"
export ISSP_RESOURCE_TUP_DELETED="$tup_deleted"

python3 <<'PY_RESOURCE_REPORT'
from __future__ import annotations

from datetime import datetime
import json
import os
from pathlib import Path
import re


def env(name: str, default: str = '') -> str:
    return os.environ.get(name, default)


def integer(name: str):
    value = env(name)
    return None if value == '' else int(value)


def parse_gnu_time(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}

    for line in path.read_text(
        encoding='utf-8',
        errors='replace',
    ).splitlines():
        if ':' not in line:
            continue

        key, value = line.strip().split(':', 1)
        result[key.strip()] = value.strip()

    return result


def parse_phase_seconds(path: Path) -> dict[str, float]:
    found: dict[str, datetime] = {}
    timestamp_pattern = re.compile(r'^\[([^]]+)\] (.*)$')

    if not path.exists():
        return {}

    for line in path.read_text(
        encoding='utf-8',
        errors='replace',
    ).splitlines():
        match = timestamp_pattern.match(line)
        if match is None:
            continue

        timestamp = datetime.fromisoformat(match.group(1))
        message = match.group(2)

        if (
            message == 'Creating disposable database from template0'
            and 'migration_started' not in found
        ):
            found['migration_started'] = timestamp
        elif (
            message.startswith('Applied ')
            and message.endswith(' Foundation migration files')
        ):
            found['migration_completed'] = timestamp
        elif message == 'Running Foundation sequential SQL tests':
            found['sequential_started'] = timestamp
        elif (
            message.startswith('Executed ')
            and message.endswith(' Foundation sequential test files')
        ):
            found['sequential_completed'] = timestamp
        elif message == 'Running Foundation concurrency tests':
            found['concurrency_started'] = timestamp
        elif (
            message.startswith('Executed ')
            and message.endswith(' Foundation concurrency test files')
        ):
            found['concurrency_completed'] = timestamp
        elif message == 'Writing the test result inventory':
            found['result_started'] = timestamp
        elif message == 'Foundation SQL tests passed':
            found['result_completed'] = timestamp

    output: dict[str, float] = {}

    for name, start_key, end_key in [
        (
            'migration_and_database_setup_seconds',
            'migration_started',
            'migration_completed',
        ),
        (
            'sequential_tests_seconds',
            'sequential_started',
            'sequential_completed',
        ),
        (
            'concurrency_tests_seconds',
            'concurrency_started',
            'concurrency_completed',
        ),
        (
            'result_finalization_seconds',
            'result_started',
            'result_completed',
        ),
    ]:
        if start_key in found and end_key in found:
            output[name] = (
                found[end_key] - found[start_key]
            ).total_seconds()

    return output


gnu = parse_gnu_time(Path(env('ISSP_RESOURCE_TIME_FILE')))
phase = parse_phase_seconds(Path(env('ISSP_RESOURCE_LOG_FILE')))

start_ns = integer('ISSP_RESOURCE_START_NS')
end_ns = integer('ISSP_RESOURCE_END_NS')
collection_ns = integer('ISSP_RESOURCE_COLLECTION_NS')

if (
    start_ns is None
    or end_ns is None
    or collection_ns is None
    or end_ns <= start_ns
    or collection_ns < end_ns
):
    raise SystemExit('Invalid elapsed-time boundary')

runner_elapsed = (end_ns - start_ns) / 1_000_000_000
collection_elapsed = (
    collection_ns - start_ns
) / 1_000_000_000
user_cpu = float(gnu.get('User time (seconds)', '0') or 0)
system_cpu = float(gnu.get('System time (seconds)', '0') or 0)
cpu_seconds = user_cpu + system_cpu
cpu_percent = (cpu_seconds / runner_elapsed) * 100

blks_read = integer('ISSP_RESOURCE_BLKS_READ')
blks_hit = integer('ISSP_RESOURCE_BLKS_HIT')

cache_denominator = (
    None
    if blks_read is None or blks_hit is None
    else blks_read + blks_hit
)

cache_hit_percent = (
    None
    if not cache_denominator
    else (blks_hit / cache_denominator) * 100
)

record = {
    'schema_version': 1,
    'run_id': env('ISSP_RESOURCE_RUN_ID'),
    'observation_label': env('ISSP_RESOURCE_LABEL') or None,
    'correctness': {
        'overall_result': env('ISSP_RESOURCE_OVERALL_RESULT'),
        'runner_exit_status': integer('ISSP_RESOURCE_RUNNER_STATUS'),
    },
    'resource_observation': {
        'status': 'RECORDED',
        'performance_threshold_status': 'NOT_EVALUATED',
        'comparison_rule': (
            'Compare only with representative runs having a compatible '
            'environment fingerprint.'
        ),
    },
    'environment': {
        'host': env('ISSP_RESOURCE_HOST'),
        'kernel': env('ISSP_RESOURCE_KERNEL'),
        'logical_cpus': integer('ISSP_RESOURCE_LOGICAL_CPUS'),
        'cpu_model': env('ISSP_RESOURCE_CPU_MODEL'),
        'installed_memory_kib': integer('ISSP_RESOURCE_MEMORY_KIB'),
        'postgresql_version': env('ISSP_RESOURCE_POSTGRES_VERSION'),
        'postgresql_version_num': integer(
            'ISSP_RESOURCE_POSTGRES_VERSION_NUM'
        ),
        'postgresql_role': env('ISSP_RESOURCE_POSTGRES_ROLE'),
    },
    'timing': {
        'correctness_runner_elapsed_seconds': runner_elapsed,
        'resource_collection_elapsed_seconds': collection_elapsed,
        **phase,
    },
    'process_tree': {
        'user_cpu_seconds': user_cpu,
        'system_cpu_seconds': system_cpu,
        'effective_cpu_percent': cpu_percent,
        'gnu_time_reported_cpu_percent': gnu.get(
            'Percent of CPU this job got'
        ),
        'maximum_resident_set_kib': int(
            gnu.get(
                'Maximum resident set size (kbytes)',
                '0',
            ) or 0
        ),
        'major_page_faults': int(
            gnu.get(
                'Major (requiring I/O) page faults',
                '0',
            ) or 0
        ),
        'minor_page_faults': int(
            gnu.get(
                'Minor (reclaiming a frame) page faults',
                '0',
            ) or 0
        ),
        'filesystem_inputs': int(
            gnu.get('File system inputs', '0') or 0
        ),
        'filesystem_outputs': int(
            gnu.get('File system outputs', '0') or 0
        ),
        'voluntary_context_switches': int(
            gnu.get('Voluntary context switches', '0') or 0
        ),
        'involuntary_context_switches': int(
            gnu.get('Involuntary context switches', '0') or 0
        ),
    },
    'postgresql': {
        'database': env('ISSP_RESOURCE_DATABASE'),
        'database_retained_during_observation': (
            env('ISSP_RESOURCE_DATABASE_EXISTS') == '1'
        ),
        'database_size_bytes': integer(
            'ISSP_RESOURCE_DB_SIZE_BYTES'
        ),
        'wal_start_lsn': env('ISSP_RESOURCE_WAL_START'),
        'wal_end_lsn': env('ISSP_RESOURCE_WAL_END'),
        'observed_cluster_wal_bytes': integer(
            'ISSP_RESOURCE_WAL_BYTES'
        ),
        'xact_commit': integer('ISSP_RESOURCE_XACT_COMMIT'),
        'xact_rollback': integer('ISSP_RESOURCE_XACT_ROLLBACK'),
        'blocks_read': blks_read,
        'blocks_hit': blks_hit,
        'cache_hit_percent': cache_hit_percent,
        'temporary_files': integer('ISSP_RESOURCE_TEMP_FILES'),
        'temporary_bytes': integer('ISSP_RESOURCE_TEMP_BYTES'),
        'deadlocks': integer('ISSP_RESOURCE_DEADLOCKS'),
        'tuples_returned': integer('ISSP_RESOURCE_TUP_RETURNED'),
        'tuples_fetched': integer('ISSP_RESOURCE_TUP_FETCHED'),
        'tuples_inserted': integer('ISSP_RESOURCE_TUP_INSERTED'),
        'tuples_updated': integer('ISSP_RESOURCE_TUP_UPDATED'),
        'tuples_deleted': integer('ISSP_RESOURCE_TUP_DELETED'),
    },
    'limitations': [
        (
            'Resource thresholds are observation-only during baseline '
            'collection.'
        ),
        (
            'Observed WAL is cluster-wide between the captured LSNs and may '
            'include unrelated activity.'
        ),
        (
            'GNU time filesystem counters are operating-system observations '
            'and are not byte counts.'
        ),
        (
            'Peak resident memory is the largest observed process value, not '
            'the sum of every concurrently running worker.'
        ),
        (
            'Phase timing is derived from second-resolution runner log '
            'timestamps; runner elapsed and CPU measurements are higher '
            'resolution.'
        ),
    ],
}

json_path = Path(env('ISSP_RESOURCE_JSON_FILE'))
text_path = Path(env('ISSP_RESOURCE_TEXT_FILE'))

json_path.write_text(
    json.dumps(record, indent=2, sort_keys=True) + '\n',
    encoding='utf-8',
)


def fmt(value, suffix: str = '') -> str:
    if value is None:
        return 'unavailable'
    if isinstance(value, float):
        return f'{value:.3f}{suffix}'
    return f'{value}{suffix}'


lines = [
    'Iron Signal Platform - Foundation Resource Observation',
    '======================================================',
    f"Run ID: {record['run_id']}",
    (
        'Observation label: '
        f"{record['observation_label'] or '(none)'}"
    ),
    (
        'Correctness result: '
        f"{record['correctness']['overall_result']}"
    ),
    (
        'Correctness runner exit status: '
        f"{record['correctness']['runner_exit_status']}"
    ),
    'Resource observation: RECORDED',
    'Performance thresholds: NOT_EVALUATED',
    '',
    'Environment fingerprint',
    '-----------------------',
    f"Host: {record['environment']['host']}",
    f"Kernel: {record['environment']['kernel']}",
    (
        'Logical CPUs: '
        f"{fmt(record['environment']['logical_cpus'])}"
    ),
    f"CPU model: {record['environment']['cpu_model']}",
    (
        'Installed memory: '
        f"{fmt(record['environment']['installed_memory_kib'], ' KiB')}"
    ),
    (
        'PostgreSQL: '
        f"{record['environment']['postgresql_version']} "
        f"({record['environment']['postgresql_version_num']})"
    ),
    (
        'PostgreSQL role: '
        f"{record['environment']['postgresql_role']}"
    ),
    '',
    'Timing',
    '------',
    (
        'Correctness runner elapsed: '
        f"{fmt(record['timing']['correctness_runner_elapsed_seconds'], ' seconds')}"
    ),
    (
        'Resource collection elapsed: '
        f"{fmt(record['timing']['resource_collection_elapsed_seconds'], ' seconds')}"
    ),
    (
        'Migration and database setup: '
        f"{fmt(record['timing'].get('migration_and_database_setup_seconds'), ' seconds')}"
    ),
    (
        'Sequential tests: '
        f"{fmt(record['timing'].get('sequential_tests_seconds'), ' seconds')}"
    ),
    (
        'Concurrency tests: '
        f"{fmt(record['timing'].get('concurrency_tests_seconds'), ' seconds')}"
    ),
    (
        'Result finalization: '
        f"{fmt(record['timing'].get('result_finalization_seconds'), ' seconds')}"
    ),
    '',
    'Process tree',
    '------------',
    (
        'User CPU: '
        f"{fmt(record['process_tree']['user_cpu_seconds'], ' seconds')}"
    ),
    (
        'System CPU: '
        f"{fmt(record['process_tree']['system_cpu_seconds'], ' seconds')}"
    ),
    (
        'Effective CPU utilization: '
        f"{fmt(record['process_tree']['effective_cpu_percent'], ' percent')}"
    ),
    (
        'Peak resident memory: '
        f"{fmt(record['process_tree']['maximum_resident_set_kib'], ' KiB')}"
    ),
    (
        'Filesystem inputs: '
        f"{fmt(record['process_tree']['filesystem_inputs'])}"
    ),
    (
        'Filesystem outputs: '
        f"{fmt(record['process_tree']['filesystem_outputs'])}"
    ),
    (
        'Major page faults: '
        f"{fmt(record['process_tree']['major_page_faults'])}"
    ),
    (
        'Minor page faults: '
        f"{fmt(record['process_tree']['minor_page_faults'])}"
    ),
    '',
    'PostgreSQL observation',
    '----------------------',
    f"Database: {record['postgresql']['database']}",
    (
        'Database size: '
        f"{fmt(record['postgresql']['database_size_bytes'], ' bytes')}"
    ),
    (
        'Observed cluster WAL: '
        f"{fmt(record['postgresql']['observed_cluster_wal_bytes'], ' bytes')}"
    ),
    (
        'Transactions committed: '
        f"{fmt(record['postgresql']['xact_commit'])}"
    ),
    (
        'Transactions rolled back: '
        f"{fmt(record['postgresql']['xact_rollback'])}"
    ),
    (
        'Blocks read: '
        f"{fmt(record['postgresql']['blocks_read'])}"
    ),
    (
        'Blocks hit: '
        f"{fmt(record['postgresql']['blocks_hit'])}"
    ),
    (
        'Cache hit ratio: '
        f"{fmt(record['postgresql']['cache_hit_percent'], ' percent')}"
    ),
    (
        'Temporary files: '
        f"{fmt(record['postgresql']['temporary_files'])}"
    ),
    (
        'Temporary bytes: '
        f"{fmt(record['postgresql']['temporary_bytes'])}"
    ),
    f"Deadlocks: {fmt(record['postgresql']['deadlocks'])}",
    '',
    'Interpretation',
    '--------------',
    'Correctness and resource observations are separate outcomes.',
    'No performance threshold is enforced during baseline collection.',
    'Compare trends only across compatible environment fingerprints.',
]

text_path.write_text(
    '\n'.join(lines) + '\n',
    encoding='utf-8',
)
PY_RESOURCE_REPORT

rm -f -- "$latest_resource_text" "$latest_resource_json"
ln -s -- "$(basename -- "$resource_text")" "$latest_resource_text"
ln -s -- "$(basename -- "$resource_json")" "$latest_resource_json"

printf 'Resource observation: %s\n' "$resource_text"
printf 'Resource observation JSON: %s\n' "$resource_json"
printf 'Latest resource observation: %s\n' "$latest_resource_text"
printf 'Latest resource observation JSON: %s\n' "$latest_resource_json"

if [[ "$database_exists" == '1' ]]; then
    if (( runner_status == 0 )); then
        if (( keep_database == 1 )); then
            printf 'Successful test database retained after telemetry: %s\n' \
                "$test_database"
        else
            printf 'Dropping successful test database after telemetry: %s\n' \
                "$test_database"
            dropdb \
                --if-exists \
                --maintenance-db="$maintenance_db" \
                "$test_database"
        fi
    elif (( drop_on_failure == 1 )); then
        printf 'Dropping failed test database after telemetry by request: %s\n' \
            "$test_database"
        dropdb \
            --if-exists \
            --maintenance-db="$maintenance_db" \
            "$test_database"
    else
        printf 'Failed test database retained for investigation: %s\n' \
            "$test_database"
    fi
fi

if (( runner_status != 0 )); then
    printf 'Correctness result: FAIL\n' >&2
    printf 'Resource observation: RECORDED\n' >&2
    printf 'Performance thresholds: NOT_EVALUATED\n' >&2
    exit "$runner_status"
fi

printf 'Correctness result: PASS\n'
printf 'Resource observation: RECORDED\n'
printf 'Performance thresholds: NOT_EVALUATED\n'
