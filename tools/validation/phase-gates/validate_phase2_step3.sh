#!/usr/bin/env bash
#
# validate_phase2_step3.sh
#
# Authoritative validator for the Phase 2 Step 3 full-replacement package.
#
# Default behavior:
#   1. Validate the complete Step 3 repository state.
#   2. Validate every dependency needed by the Foundation SQL runner.
#   3. Validate the PostgreSQL connection, version, and CREATEDB privilege.
#   4. Run the complete Foundation clean-install, sequential, and concurrency
#      test suite.
#   5. Validate the generated summary against the current Step 3 gate.
#
# Use --static-only only when deliberately checking files on a host that cannot
# reach the PostgreSQL test service.
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly SCRIPT_NAME="${0##*/}"

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0
INFO_COUNT=0

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [--static-only]

Default:
  Run every check required through Phase 2 Step 3, including the PostgreSQL
  clean-install and accepted regression suite.

Options:
  --static-only
      Validate files, manifests, function boundaries, shell syntax, and Git
      diff hygiene, but intentionally do not connect to PostgreSQL.

  -h, --help
      Show this help text.

PostgreSQL connection environment:
  PGHOST
  PGPORT
  PGUSER
  PGPASSWORD
  PGSSLMODE
  PGMAINTENANCE_DB   Default: postgres
  PGCONNECT_TIMEOUT Default: 3 seconds

The script never creates a result directory or disposable database until every
static, dependency, and PostgreSQL preflight has passed.
EOF
}

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS: %s\n' "$*"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL: %s\n' "$*" >&2
}

info() {
    INFO_COUNT=$((INFO_COUNT + 1))
    printf 'INFO: %s\n' "$*"
}

section() {
    printf '\n== %s ==\n' "$*"
}

while (( $# > 0 )); do
    case "$1" in
        --static-only)
            STATIC_ONLY=1
            shift
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

if (( BASH_VERSINFO[0] < 4 )); then
    printf 'Bash 4 or newer is required; found %s\n' "$BASH_VERSION" >&2
    printf 'Arch package: bash\n' >&2
    printf 'Install on Arch Linux with:\n' >&2
    printf '  sudo pacman -S --needed bash\n' >&2
    exit 69
fi

declare -A COMMAND_PACKAGE_MAP=(
    [awk]="gawk"
    [basename]="coreutils"
    [createdb]="postgresql-libs"
    [date]="coreutils"
    [dirname]="coreutils"
    [dropdb]="postgresql-libs"
    [git]="git"
    [grep]="grep"
    [ln]="coreutils"
    [mkdir]="coreutils"
    [mktemp]="coreutils"
    [psql]="postgresql-libs"
    [python3]="python"
    [rm]="coreutils"
    [sed]="sed"
    [sha256sum]="coreutils"
    [sleep]="coreutils"
    [tee]="coreutils"
)

required_static_commands=(
    awk
    git
    grep
    python3
    sed
)

required_database_commands=(
    basename
    createdb
    date
    dirname
    dropdb
    ln
    mkdir
    mktemp
    psql
    rm
    sha256sum
    sleep
    tee
)

preflight_commands() {
    local -a commands=("$@")
    local -a missing_commands=()
    local -a missing_packages=()
    local command_name=""
    local package_name=""
    declare -A seen_packages=()

    for command_name in "${commands[@]}"; do
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

    if (( ${#missing_commands[@]} == 0 )); then
        return 0
    fi

    printf 'Missing required commands:\n' >&2
    for command_name in "${missing_commands[@]}"; do
        printf '  %-12s Arch package: %s\n' \
            "$command_name" \
            "${COMMAND_PACKAGE_MAP[$command_name]}" >&2
    done

    printf '\nInstall all missing Arch packages with:\n\n' >&2
    printf '  sudo pacman -S --needed' >&2
    printf ' %s' "${missing_packages[@]}" >&2
    printf '\n\nNo database test was started.\n' >&2
    return 1
}

section "Dependency preflight"

if preflight_commands "${required_static_commands[@]}"; then
    pass "Static-validation commands are available"
else
    exit 69
fi

if ! repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'Not inside a Git working tree.\n' >&2
    exit 66
fi

cd "$repository_root"

section "Repository identity"

printf 'Repository root: %s\n' "$repository_root"
printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'unknown')"
printf 'Operating system: %s\n' "$(uname -s)"
printf 'Current branch: %s\n' "$(git branch --show-current 2>/dev/null || printf 'detached')"
printf 'Current commit: %s\n' "$(git rev-parse --short=12 HEAD)"

if [[ "$(git branch --show-current)" == "dev" ]]; then
    pass "Current branch is dev"
else
    fail "Current branch must be dev"
fi

if [[ -z "$(git diff --name-only --diff-filter=U)" ]]; then
    pass "No unresolved Git conflicts"
else
    fail "Unresolved Git conflicts exist"
    git diff --name-only --diff-filter=U | sed 's/^/      /' >&2
fi

migration="sql/schema/migrations/foundation/072_postgresql_session_control.sql"
model="docs/architecture/foundation/session-establishment-step-up-and-lifecycle-model.md"
migration_map="docs/architecture/foundation/sql-migration-map.md"
migration_060="sql/schema/migrations/foundation/060_sessions.sql"
migration_070="sql/schema/migrations/foundation/070_postgresql_authentication_assertion_gate.sql"
foundation_manifest="sql/schema/manifests/foundation.manifest"
test_manifest="test-framework/sql/tests/foundation-tests.manifest"
concurrency_manifest="test-framework/sql/tests/foundation-concurrency-tests.manifest"
runner="test-framework/sql/schema/scripts/test_foundation.sh"
acceptance="docs/architecture/foundation/phase-2-step-2-session-establishment-and-step-up-acceptance.md"

required_files=(
    "$migration"
    "$model"
    "$migration_map"
    "$migration_060"
    "$migration_070"
    "$foundation_manifest"
    "$test_manifest"
    "$concurrency_manifest"
    "$runner"
    "$acceptance"
    "test-framework/sql/tests/foundation/110_session_establishment_and_step_up_behavior.sql"
    "test-framework/sql/tests/concurrency/100_authentication_assertion_single_use.sh"
)

section "Required files"

for path in "${required_files[@]}"; do
    if [[ -f "$path" ]]; then
        pass "Required file exists: ${path}"
    else
        fail "Required file is missing: ${path}"
    fi
done

section "Exact accepted and Step 3 file boundaries"

export ISSP_REPOSITORY_ROOT="$repository_root"

if python3 <<'PY'
from __future__ import annotations

import hashlib
import os
import sys
from pathlib import Path

repo = Path(os.environ["ISSP_REPOSITORY_ROOT"])

checks = [
    (
        repo / "sql/schema/migrations/foundation/060_sessions.sql",
        "9c7c81cb67e8910e73aaac5579601d2318b69b30fb19230e96f526de55d3c5d9",
        "accepted migration 060 is unchanged",
    ),
    (
        repo / "sql/schema/migrations/foundation/070_postgresql_authentication_assertion_gate.sql",
        "c8173ffda5b4c2d4bef6a544979e2cd74e667d876a79664496fd9eef31201765",
        "accepted migration 070 is unchanged",
    ),
    (
        repo / "sql/schema/migrations/foundation/072_postgresql_session_control.sql",
        "b2d142d3b0174e63c4e9d66b5b92bf07e98f0fe7072e4c99090fcaef29c4794c",
        "Step 3 migration 072 matches the full replacement",
    ),
    (
        repo / "docs/architecture/foundation/session-establishment-step-up-and-lifecycle-model.md",
        "939302e01fb04905c73a5f5d4dec8e87b12cc2603a3c754f85eb879617bba1b9",
        "Step 3 normative model matches the full replacement",
    ),
    (
        repo / "docs/architecture/foundation/sql-migration-map.md",
        "f23a641eb1c947f8d757ce1f34aa21213982750d4add0a95e0709c7ed8977ebf",
        "Step 3 migration map matches the full replacement",
    ),
    (
        repo / "test-framework/sql/tests/foundation-tests.manifest",
        "c36edf884e321f8cf19e0e5278e720795ed0a3c31bdd52de7adf6a2b300ac6cd",
        "Step 4 sequential manifest remains unchanged",
    ),
]

failed = False

for path, expected, label in checks:
    if not path.is_file():
        failed = True
        print(f"FAIL: Cannot hash missing file: {path}", file=sys.stderr)
        continue

    actual = hashlib.sha256(path.read_bytes()).hexdigest()

    if actual == expected:
        print(f"PASS: {label}")
    else:
        failed = True
        print(
            f"FAIL: {label}\n"
            f"      expected: {expected}\n"
            f"      actual:   {actual}",
            file=sys.stderr,
        )

raise SystemExit(1 if failed else 0)
PY
then
    PASS_COUNT=$((PASS_COUNT + 6))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Step 3 controlled function boundary"

function_names=(
    "session_context_is_locally_usable"
    "establish_session_from_authentication_assertion"
    "complete_session_step_up"
    "record_session_activity"
    "lock_session"
    "unlock_session"
    "expire_session"
    "revoke_session"
    "terminate_session"
)

for function_name in "${function_names[@]}"; do
    if grep -Fq -- \
        "CREATE FUNCTION access_control.${function_name}(" \
        "$migration"; then
        pass "Function exists: access_control.${function_name}"
    else
        fail "Function is missing: access_control.${function_name}"
    fi
done

create_count="$(grep -c '^CREATE FUNCTION access_control\.' "$migration" || true)"
comment_count="$(grep -c '^COMMENT ON FUNCTION access_control\.' "$migration" || true)"
revoke_count="$(grep -c '^REVOKE ALL ON FUNCTION access_control\.' "$migration" || true)"
search_path_count="$(grep -c '^SET search_path = pg_catalog, access_control$' "$migration" || true)"

[[ "$create_count" == "9" ]] \
    && pass "Migration defines exactly 9 controlled/helper functions" \
    || fail "Expected 9 CREATE FUNCTION statements; found ${create_count}"

[[ "$comment_count" == "9" ]] \
    && pass "Every migration function has a COMMENT" \
    || fail "Expected 9 COMMENT ON FUNCTION statements; found ${comment_count}"

[[ "$revoke_count" == "9" ]] \
    && pass "Every migration function is revoked from PUBLIC" \
    || fail "Expected 9 REVOKE ALL ON FUNCTION statements; found ${revoke_count}"

[[ "$search_path_count" == "9" ]] \
    && pass "Every migration function has the fixed trusted search_path" \
    || fail "Expected 9 trusted search_path settings; found ${search_path_count}"

if grep -Eq -- \
    'p_[a-z_]*(at|time|timestamp)[[:space:]]+timestamptz' \
    "$migration"; then
    fail "A controlled API accepts a caller-supplied transition timestamp"
else
    pass "No controlled API accepts a caller-supplied transition timestamp"
fi

if grep -Fq -- "SECURITY DEFINER" "$migration"; then
    fail "Migration unexpectedly adds SECURITY DEFINER"
else
    pass "Migration does not add SECURITY DEFINER"
fi

section "Manifest and documentation boundary"

required_markers=(
    "$foundation_manifest|migrations/foundation/072_postgresql_session_control.sql"
    "$test_manifest|foundation/110_session_establishment_and_step_up_behavior.sql"
    "$concurrency_manifest|concurrency/100_authentication_assertion_single_use.sh"
    "$model|Step 2 accepted; Step 3 implementation candidate"
    "$model|Implementation candidate in migration \`072\`; clean-install and regression validation are required before Step 4 begins."
    "$migration_map|Expanded sequential behavior tests remain Step 4 work."
)

for entry in "${required_markers[@]}"; do
    file="${entry%%|*}"
    marker="${entry#*|}"

    if grep -Fq -- "$marker" "$file"; then
        pass "Required marker exists: ${file}"
    else
        fail "Required marker is missing from ${file}: ${marker}"
    fi
done

if grep -Fq -- "foundation/120_" "$test_manifest"; then
    fail "Step 4 test was added before the Step 3 regression gate"
else
    pass "Sequential test manifest remains at the accepted Step 2 boundary"
fi

section "Shell and Git hygiene"

if bash -n "$runner"; then
    pass "Foundation test runner shell syntax is valid"
else
    fail "Foundation test runner shell syntax is invalid"
fi

if bash -n "test-framework/sql/tests/concurrency/100_authentication_assertion_single_use.sh"; then
    pass "Concurrency test shell syntax is valid"
else
    fail "Concurrency test shell syntax is invalid"
fi

if git diff --check >/dev/null; then
    pass "git diff --check passes"
else
    fail "git diff --check reports whitespace or conflict-marker problems"
    git diff --check >&2 || true
fi

section "Static result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'INFO checks: %d\n' "$INFO_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 2 Step 3 static validation FAILED.\n' >&2
    printf 'No PostgreSQL test was started.\n' >&2
    exit 1
fi

printf '\nPhase 2 Step 3 static validation PASSED.\n'

if (( STATIC_ONLY == 1 )); then
    printf 'Static-only mode was requested; the PostgreSQL gate was intentionally skipped.\n'
    exit 0
fi

section "Database-runner dependency preflight"

if preflight_commands "${required_database_commands[@]}"; then
    pass "Every Foundation database-runner command is available"
else
    exit 69
fi

if ! date --iso-8601=seconds >/dev/null 2>&1; then
    printf 'The available date command does not support --iso-8601=seconds.\n' >&2
    printf 'The authoritative runner requires GNU coreutils date.\n' >&2
    printf 'On Arch Linux:\n' >&2
    printf '  sudo pacman -S --needed coreutils\n' >&2
    printf 'Run the database gate on the PostgreSQL/Arch test host when the local OS uses BSD date.\n' >&2
    exit 69
fi
pass "GNU date behavior required by the runner is available"

section "PostgreSQL environment preflight"

maintenance_database="${PGMAINTENANCE_DB:-postgres}"
export PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-3}"

original_pghost_is_set=0
original_pghost=""

if [[ ${PGHOST+x} ]]; then
    original_pghost_is_set=1
    original_pghost="$PGHOST"
fi

declare -a candidate_hosts=()

if (( original_pghost_is_set == 1 )); then
    candidate_hosts+=("$original_pghost")
else
    candidate_hosts+=("__LIBPQ_DEFAULT__")

    for socket_directory in /run/postgresql /var/run/postgresql /tmp; do
        [[ -d "$socket_directory" ]] || continue

        duplicate=0
        for existing_candidate in "${candidate_hosts[@]}"; do
            [[ "$existing_candidate" == "$socket_directory" ]] \
                && duplicate=1 \
                && break
        done

        (( duplicate == 0 )) && candidate_hosts+=("$socket_directory")
    done

    candidate_hosts+=("localhost")
fi

connection_succeeded=0
connection_result=""
connection_error=""
selected_host=""

for candidate_host in "${candidate_hosts[@]}"; do
    error_file="$(mktemp "${TMPDIR:-/tmp}/psp-step3-pg-preflight.XXXXXX")"

    if [[ "$candidate_host" == "__LIBPQ_DEFAULT__" ]]; then
        unset PGHOST
        host_description="<libpq default>"
    else
        export PGHOST="$candidate_host"
        host_description="$candidate_host"
    fi

    if connection_result="$(
        psql \
            -X \
            -w \
            --no-psqlrc \
            --set=ON_ERROR_STOP=1 \
            --tuples-only \
            --no-align \
            --dbname="$maintenance_database" \
            --command="
                SELECT
                    current_setting('server_version_num')
                    || '|' || current_user
                    || '|' ||
                    CASE
                        WHEN role_record.rolsuper OR role_record.rolcreatedb
                        THEN '1'
                        ELSE '0'
                    END
                FROM pg_roles AS role_record
                WHERE role_record.rolname = current_user;
            " \
            2>"$error_file"
    )"; then
        connection_succeeded=1
        selected_host="$host_description"
        rm -f -- "$error_file"
        break
    fi

    connection_error+="HOST ${host_description}:"$'\n'
    connection_error+="$(sed 's/^/  /' "$error_file")"$'\n'
    rm -f -- "$error_file"
done

if (( connection_succeeded == 0 )); then
    if (( original_pghost_is_set == 1 )); then
        export PGHOST="$original_pghost"
    else
        unset PGHOST
    fi

    printf 'PostgreSQL environment preflight: BLOCKED\n\n' >&2
    printf 'The Step 3 files passed every static check, but this host could not\n' >&2
    printf 'connect to the maintenance database "%s".\n\n' "$maintenance_database" >&2
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'unknown')" >&2
    printf 'Operating system: %s\n' "$(uname -s)" >&2
    printf 'PGHOST: %s\n' "${original_pghost:-<unset>}" >&2
    printf 'PGPORT: %s\n' "${PGPORT:-<unset/default>}" >&2
    printf 'PGUSER: %s\n' "${PGUSER:-<unset/current OS user>}" >&2
    printf 'PGSSLMODE: %s\n' "${PGSSLMODE:-<unset/default>}" >&2
    printf 'PGMAINTENANCE_DB: %s\n\n' "$maintenance_database" >&2
    printf 'Connection attempts:\n%s\n' "$connection_error" >&2
    printf 'No test result directory, log, temporary database, or disposable database was created.\n\n' >&2
    printf 'Run this same validator on the PostgreSQL test host, or supply the connection explicitly:\n\n' >&2
    printf '  PGHOST=server.example \\\n' >&2
    printf '  PGPORT=5432 \\\n' >&2
    printf '  PGUSER=database_role \\\n' >&2
    printf '  PGMAINTENANCE_DB=postgres \\\n' >&2
    printf '  ./%s\n\n' "$SCRIPT_NAME" >&2
    printf 'This is an environment block, not a Step 3 implementation failure.\n' >&2
    exit 69
fi

IFS='|' read -r server_version_number connected_role can_create_database \
    <<<"$connection_result"

if [[ ! "$server_version_number" =~ ^[0-9]+$ ]]; then
    printf 'Could not interpret PostgreSQL server_version_num: %s\n' \
        "$server_version_number" >&2
    exit 69
fi

if (( server_version_number < 180000 )); then
    printf 'PostgreSQL 18 or newer is required; server_version_num=%s\n' \
        "$server_version_number" >&2
    exit 69
fi

if [[ "$can_create_database" != "1" ]]; then
    printf 'Connected role %s lacks CREATEDB or SUPERUSER.\n' \
        "$connected_role" >&2
    printf 'The disposable test framework must create and drop its test database.\n' >&2
    exit 77
fi

pass "PostgreSQL connection succeeds through ${selected_host}"
pass "PostgreSQL version is supported: ${server_version_number}"
pass "Connected role can create the disposable database: ${connected_role}"

section "Foundation clean-install and regression gate"

"$runner"

summary="test-framework/sql/test-results/latest-summary.txt"

if [[ ! -f "$summary" ]]; then
    printf 'The test runner completed without creating the expected summary:\n' >&2
    printf '  %s\n' "$summary" >&2
    exit 1
fi

required_summary_markers=(
    "Overall result: PASS"
    "Runner exit status: 0"
    "Sequential test files: 11"
    "Concurrency test files: 1"
    "PASS"
    "147"
    "FAIL"
    "0"
    "WARN"
    "3"
)

for marker in "${required_summary_markers[@]}"; do
    if grep -Fq -- "$marker" "$summary"; then
        pass "Summary contains: ${marker}"
    else
        fail "Summary is missing expected marker: ${marker}"
    fi
done

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 2 Step 3 database gate FAILED.\n' >&2
    printf 'Summary: %s\n' "$summary" >&2
    exit 1
fi

section "Final result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'INFO checks: %d\n' "$INFO_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"
printf '\nPhase 2 Step 3 validation PASSED completely.\n'
printf 'The implementation is ready to commit before beginning Step 4.\n'
