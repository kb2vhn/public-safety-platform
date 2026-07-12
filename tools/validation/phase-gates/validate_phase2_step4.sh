#!/usr/bin/env bash
#
# validate_phase2_step4.sh
#
# Authoritative Phase 2 Step 4 validator.
#
# Default behavior:
#   - Performs complete dependency and repository preflight.
#   - Validates the accepted Step 3 boundary.
#   - Validates the full Step 4 replacement files.
#   - Runs the complete Foundation clean-install, sequential, and concurrency
#     suite.
#   - Requires the Step 4 result: 188 PASS, 0 FAIL, 3 WARN.
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

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [--static-only]

Default:
  Run every check required through Phase 2 Step 4, including the PostgreSQL
  clean-install, all 12 sequential tests, and the current concurrency test.

Options:
  --static-only
      Run file, manifest, SQL-boundary, shell, and Git-diff checks without
      connecting to PostgreSQL.

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

No results directory, log file, temporary database, or disposable database is
created until all static, dependency, and PostgreSQL preflights pass.
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
    printf 'Install with:\n  sudo pacman -S --needed bash\n' >&2
    exit 69
fi

declare -A COMMAND_PACKAGE_MAP=(
    [awk]="gawk"
    [cat]="coreutils"
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
    [sort]="coreutils"
    [tee]="coreutils"
    [uname]="coreutils"
    [uniq]="coreutils"
    [wc]="coreutils"
)

required_commands=(
    awk
    basename
    cat
    createdb
    date
    dirname
    dropdb
    git
    grep
    ln
    mkdir
    mktemp
    psql
    python3
    rm
    sed
    sha256sum
    sleep
    sort
    tee
    uname
    uniq
    wc
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

section "Dependency preflight"

if (( ${#missing_commands[@]} > 0 )); then
    printf 'Dependency preflight: FAIL\n\n' >&2
    printf 'Missing required commands:\n' >&2

    for command_name in "${missing_commands[@]}"; do
        printf '  %-12s Arch package: %s\n' \
            "$command_name" \
            "${COMMAND_PACKAGE_MAP[$command_name]}" >&2
    done

    printf '\nInstall all missing packages with:\n\n' >&2
    printf '  sudo pacman -S --needed' >&2
    printf ' %s' "${missing_packages[@]}" >&2
    printf '\n\nNo database test was started.\n' >&2
    exit 69
fi

pass "All validator and Foundation-runner commands are available"

if ! date --iso-8601=seconds >/dev/null 2>&1; then
    printf 'GNU date with --iso-8601=seconds is required.\n' >&2
    printf 'Arch package: coreutils\n' >&2
    printf 'Install with:\n  sudo pacman -S --needed coreutils\n' >&2
    exit 69
fi

pass "GNU date behavior required by the Foundation runner is available"

if ! repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'Not inside a Git working tree.\n' >&2
    exit 66
fi

cd "$repository_root"

section "Repository identity"

printf 'Repository root: %s\n' "$repository_root"
printf 'Host: %s\n' "$(uname -n 2>/dev/null || printf 'unknown')"
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

migration_060="sql/schema/migrations/foundation/060_sessions.sql"
migration_070="sql/schema/migrations/foundation/070_postgresql_authentication_assertion_gate.sql"
migration_072="sql/schema/migrations/foundation/072_postgresql_session_control.sql"
foundation_manifest="sql/schema/manifests/foundation.manifest"
model="docs/architecture/foundation/session-establishment-step-up-and-lifecycle-model.md"
migration_map="docs/architecture/foundation/sql-migration-map.md"
test_file="test-framework/sql/tests/foundation/120_session_lifecycle_behavior.sql"
test_manifest="test-framework/sql/tests/foundation-tests.manifest"
concurrency_manifest="test-framework/sql/tests/foundation-concurrency-tests.manifest"
runner="test-framework/sql/schema/scripts/test_foundation.sh"
concurrency_test="test-framework/sql/tests/concurrency/100_authentication_assertion_single_use.sh"
step2_test="test-framework/sql/tests/foundation/110_session_establishment_and_step_up_behavior.sql"
step2_acceptance="docs/architecture/foundation/phase-2-step-2-session-establishment-and-step-up-acceptance.md"

required_files=(
    "$migration_060"
    "$migration_070"
    "$migration_072"
    "$foundation_manifest"
    "$model"
    "$migration_map"
    "$test_file"
    "$test_manifest"
    "$concurrency_manifest"
    "$runner"
    "$concurrency_test"
    "$step2_test"
    "$step2_acceptance"
)

section "Required files"

for path in "${required_files[@]}"; do
    if [[ -f "$path" ]]; then
        pass "Required file exists: ${path}"
    else
        fail "Required file is missing: ${path}"
    fi
done

section "Exact accepted and Step 4 file boundaries"

export PSP_REPOSITORY_ROOT="$repository_root"

if python3 <<'PY'
from __future__ import annotations

import hashlib
import os
import sys
from pathlib import Path

repo = Path(os.environ["PSP_REPOSITORY_ROOT"])

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
        "validated Step 3 migration 072 is unchanged",
    ),
    (
        repo / "docs/architecture/foundation/session-establishment-step-up-and-lifecycle-model.md",
        "c32c46e9d4640937590540fd3a482b7975d2be03abdef3aa50c27f6af8829e29",
        "Step 4 normative model matches the full replacement",
    ),
    (
        repo / "docs/architecture/foundation/sql-migration-map.md",
        "9eb092a9f58fc1a4755e421c01977ae89220500960f63dd9347b63deae05308f",
        "Step 4 migration map matches the full replacement",
    ),
    (
        repo / "test-framework/sql/tests/foundation/120_session_lifecycle_behavior.sql",
        "4b36e22fe2e0440c436796cfae62b9b171108c74f34ebea2617dcd26ff30fb7b",
        "Step 4 lifecycle test matches the full replacement",
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

section "Sequential manifest boundary"

manifest_entries=()
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    entry="$(
        printf '%s' "$raw_line" \
            | sed 's/\r$//' \
            | sed 's/[[:space:]]*#.*$//' \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    )"

    [[ -z "$entry" ]] && continue
    manifest_entries+=("$entry")
done <"$test_manifest"

if (( ${#manifest_entries[@]} == 12 )); then
    pass "Sequential manifest contains exactly 12 test files"
else
    fail "Sequential manifest must contain 12 test files; found ${#manifest_entries[@]}"
fi

if [[ "${manifest_entries[10]:-}" == "foundation/110_session_establishment_and_step_up_behavior.sql" ]]; then
    pass "Accepted Step 2 test remains immediately before Step 4"
else
    fail "Accepted Step 2 test is not in manifest position 11"
fi

if [[ "${manifest_entries[11]:-}" == "foundation/120_session_lifecycle_behavior.sql" ]]; then
    pass "Step 4 lifecycle test is the final sequential manifest entry"
else
    fail "Step 4 lifecycle test is not the final sequential manifest entry"
fi

duplicate_count="$(
    printf '%s\n' "${manifest_entries[@]}" \
        | sort \
        | uniq -d \
        | wc -l
)"

if [[ "$duplicate_count" == "0" ]]; then
    pass "Sequential manifest contains no duplicate entries"
else
    fail "Sequential manifest contains duplicate entries"
fi

pass "Sequential manifest is validated semantically rather than by comment-sensitive whole-file hash"

if grep -Fq -- \
    "concurrency/100_authentication_assertion_single_use.sh" \
    "$concurrency_manifest"; then
    pass "Accepted Phase 1 concurrency proof remains in the normal path"
else
    fail "Accepted Phase 1 concurrency proof is missing"
fi

section "Step 4 lifecycle test boundary"

assertion_count="$(
    grep -Eoc \
        'sql_test[.]assert_(true|false|equal_bigint|schema_exists|relation_exists|no_rows|query_returns_rows|raises)[[:space:]]*[(]' \
        "$test_file"
)"

if [[ "$assertion_count" == "41" ]]; then
    pass "Step 4 test defines exactly 41 recorded assertions"
else
    fail "Step 4 test must define 41 recorded assertions; found ${assertion_count}"
fi

required_test_markers=(
    "Activity records for an active usable session"
    "Administrative unlock revalidates current local trust"
    "Absolute expiration creates one terminal EXPIRED state"
    "Inactivity expiration creates one terminal EXPIRED state"
    "Revocation transitions a locked session"
    "Termination transitions a locked session"
    "A terminal session rejects every later lifecycle operation"
    "Session state constraints reject a contradictory terminal timestamp"
    "All nine Phase 2 session functions are unavailable to PUBLIC"
    "All nine Phase 2 session functions use the fixed trusted search path"
)

for marker in "${required_test_markers[@]}"; do
    if grep -Fq -- "$marker" "$test_file"; then
        pass "Step 4 test marker exists: ${marker}"
    else
        fail "Step 4 test marker is missing: ${marker}"
    fi
done

if grep -Eq -- \
    'CREATE[[:space:]]+FUNCTION[[:space:]]+access_control[.]' \
    "$test_file"; then
    fail "Step 4 test must not replace production access_control functions"
else
    pass "Step 4 test does not replace production access_control functions"
fi

if grep -Eq -- \
    '^[[:space:]]*SECURITY[[:space:]]+DEFINER([[:space:]]|$)' \
    "$test_file"; then
    fail "Step 4 test unexpectedly creates SECURITY DEFINER code"
else
    pass "Step 4 test does not create SECURITY DEFINER code"
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
        "$migration_072"; then
        pass "Function exists: access_control.${function_name}"
    else
        fail "Function is missing: access_control.${function_name}"
    fi
done

create_count="$(grep -c '^CREATE FUNCTION access_control\.' "$migration_072" || true)"
comment_count="$(grep -c '^COMMENT ON FUNCTION access_control\.' "$migration_072" || true)"
revoke_count="$(grep -c '^REVOKE ALL ON FUNCTION access_control\.' "$migration_072" || true)"
search_path_count="$(grep -c '^SET search_path = pg_catalog, access_control$' "$migration_072" || true)"

[[ "$create_count" == "9" ]] \
    && pass "Migration 072 defines exactly 9 controlled/helper functions" \
    || fail "Expected 9 CREATE FUNCTION statements; found ${create_count}"

[[ "$comment_count" == "9" ]] \
    && pass "Every migration 072 function has a COMMENT" \
    || fail "Expected 9 COMMENT ON FUNCTION statements; found ${comment_count}"

[[ "$revoke_count" == "9" ]] \
    && pass "Every migration 072 function is revoked from PUBLIC" \
    || fail "Expected 9 REVOKE statements; found ${revoke_count}"

[[ "$search_path_count" == "9" ]] \
    && pass "Every migration 072 function has the fixed trusted search path" \
    || fail "Expected 9 trusted search paths; found ${search_path_count}"

section "Documentation boundary"

if python3 - "$model" "$migration_map" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

model_path = Path(sys.argv[1])
migration_map_path = Path(sys.argv[2])

checks = [
    (
        model_path,
        "Step 2 accepted; Step 3 validated; Step 4 expanded sequential "
        "behavior tests are an implementation candidate",
    ),
    (
        model_path,
        "120_session_lifecycle_behavior.sql",
    ),
    (
        model_path,
        "A complete clean run with the updated sequential manifest is "
        "required before Step 5 begins.",
    ),
    (
        migration_map_path,
        "The authoritative sequential manifest now contains 12 test files.",
    ),
    (
        migration_map_path,
        "Step 5 remains responsible for the three required multi-connection "
        "concurrency proofs.",
    ),
]

failures: list[str] = []

for path, marker in checks:
    normalized_text = re.sub(
        r"\s+",
        " ",
        path.read_text(encoding="utf-8"),
    ).strip()
    normalized_marker = re.sub(r"\s+", " ", marker).strip()

    if normalized_marker in normalized_text:
        print(f"DOCUMENTATION CHECK PASS: {path}")
    else:
        failures.append(
            f"{path}: missing normalized marker: {normalized_marker}"
        )

if failures:
    for failure in failures:
        print(f"DOCUMENTATION CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then
    PASS_COUNT=$((PASS_COUNT + 5))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Shell and Git hygiene"

if bash -n "$runner"; then
    pass "Foundation test runner shell syntax is valid"
else
    fail "Foundation test runner shell syntax is invalid"
fi

if bash -n "$concurrency_test"; then
    pass "Concurrency test shell syntax is valid"
else
    fail "Concurrency test shell syntax is invalid"
fi

if bash -n "$0"; then
    pass "Step 4 validator shell syntax is valid"
else
    fail "Step 4 validator shell syntax is invalid"
fi

if git diff --check -- \
    "$model" \
    "$migration_map" \
    "$test_file" \
    "$test_manifest" >/dev/null; then
    pass "Changed Step 4 project files pass git diff --check"
else
    fail "Changed Step 4 project files contain whitespace or conflict-marker problems"
    git diff --check -- \
        "$model" \
        "$migration_map" \
        "$test_file" \
        "$test_manifest" >&2 || true
fi

section "Static result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 2 Step 4 static validation FAILED.\n' >&2
    printf 'No PostgreSQL test was started.\n' >&2
    exit 1
fi

printf '\nPhase 2 Step 4 static validation PASSED.\n'

if (( STATIC_ONLY == 1 )); then
    printf 'Static-only mode was requested; the PostgreSQL gate was intentionally skipped.\n'
    exit 0
fi

section "PostgreSQL environment preflight"

maintenance_database="${PGMAINTENANCE_DB:-postgres}"
export PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-3}"

if ! connection_result="$(
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
                    WHEN role_record.rolsuper
                         OR role_record.rolcreatedb
                    THEN '1'
                    ELSE '0'
                END
            FROM pg_roles AS role_record
            WHERE role_record.rolname = current_user;
        "
)"; then
    printf 'PostgreSQL environment preflight: BLOCKED\n\n' >&2
    printf 'Could not connect to maintenance database: %s\n' \
        "$maintenance_database" >&2
    printf 'PGHOST: %s\n' "${PGHOST:-<unset/libpq default>}" >&2
    printf 'PGPORT: %s\n' "${PGPORT:-<unset/default>}" >&2
    printf 'PGUSER: %s\n' "${PGUSER:-<unset/current OS user>}" >&2
    printf 'No test result directory or disposable database was created by this validator.\n' >&2
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
    exit 77
fi

pass "PostgreSQL connection succeeds"
pass "PostgreSQL version is supported: ${server_version_number}"
pass "Connected role can create the disposable database: ${connected_role}"

section "Foundation clean-install and Step 4 regression gate"

"$runner"

summary="test-framework/sql/test-results/latest-summary.txt"

if [[ ! -f "$summary" ]]; then
    printf 'The Foundation runner did not create the expected summary:\n' >&2
    printf '  %s\n' "$summary" >&2
    exit 1
fi

if python3 - "$summary" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
summary_text = summary_path.read_text(encoding="utf-8")

failures: list[str] = []

line_checks = {
    "overall result": r"(?m)^Overall result:[ \t]+PASS[ \t]*$",
    "runner exit status": r"(?m)^Runner exit status:[ \t]+0[ \t]*$",
    "sequential test count": r"(?m)^Sequential test files:[ \t]+12[ \t]*$",
    "concurrency test count": r"(?m)^Concurrency test files:[ \t]+1[ \t]*$",
}

for label, pattern in line_checks.items():
    if re.search(pattern, summary_text) is None:
        failures.append(f"Missing or incorrect {label}")

result_totals_match = re.search(
    r"Result[ ]totals(?P<section>.*?)Failed[ ]assertions",
    summary_text,
    re.DOTALL,
)

if result_totals_match is None:
    failures.append("Could not locate Result totals")
else:
    totals = result_totals_match.group("section")

    pass_match = re.search(
        r"\|[ \t]*PASS[ \t]*\|[ \t]*(\d+)[ \t]*\|",
        totals,
    )
    warn_match = re.search(
        r"\|[ \t]*WARN[ \t]*\|[ \t]*(\d+)[ \t]*\|",
        totals,
    )
    fail_match = re.search(
        r"\|[ \t]*FAIL[ \t]*\|[ \t]*(\d+)[ \t]*\|",
        totals,
    )

    if pass_match is None or int(pass_match.group(1)) != 188:
        failures.append("Result totals do not report PASS=188")

    if warn_match is None or int(warn_match.group(1)) != 3:
        failures.append("Result totals do not report WARN=3")

    if fail_match is not None and int(fail_match.group(1)) != 0:
        failures.append(
            f"Result totals report FAIL={fail_match.group(1)} instead of zero"
        )

failed_assertions_match = re.search(
    r"Failed[ ]assertions(?P<section>.*?)Warnings",
    summary_text,
    re.DOTALL,
)

if failed_assertions_match is None:
    failures.append("Could not locate Failed assertions")
elif re.search(
    r"\(0[ ]rows\)",
    failed_assertions_match.group("section"),
) is None:
    failures.append("Failed assertions section is not empty")

migration_totals_match = re.search(
    r"Migration[ ]totals(?P<section>.*)",
    summary_text,
    re.DOTALL,
)

if migration_totals_match is None:
    failures.append("Could not locate Migration totals")
else:
    totals_match = re.search(
        r"\|[ \t]*(\d+)[ \t]*\|[ \t]*(\d+)[ \t]*\|",
        migration_totals_match.group("section"),
    )

    if totals_match is None:
        failures.append("Could not parse migration totals")
    else:
        if int(totals_match.group(1)) != 32:
            failures.append("Manifest migration count is not 32")
        if int(totals_match.group(2)) != 32:
            failures.append("Registered migration count is not 32")

if failures:
    for failure in failures:
        print(f"SUMMARY CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

print("SUMMARY CHECK PASS: Overall result is PASS")
print("SUMMARY CHECK PASS: Runner exit status is 0")
print("SUMMARY CHECK PASS: Sequential test files = 12")
print("SUMMARY CHECK PASS: Concurrency test files = 1")
print("SUMMARY CHECK PASS: PASS = 188")
print("SUMMARY CHECK PASS: FAIL = 0")
print("SUMMARY CHECK PASS: WARN = 3")
print("SUMMARY CHECK PASS: Manifest migrations = 32")
print("SUMMARY CHECK PASS: Registered migrations = 32")
PY
then
    PASS_COUNT=$((PASS_COUNT + 9))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Final result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 2 Step 4 validation FAILED.\n' >&2
    printf 'Summary: %s\n' "$summary" >&2
    exit 1
fi

printf '\nPhase 2 Step 4 validation PASSED completely.\n'
printf 'Step 4 is ready to commit before Phase 2 Step 5 concurrency work begins.\n'
