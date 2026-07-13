#!/usr/bin/env bash
#
# validate_phase2_step6.sh
#
# Authoritative Phase 2 Step 6 acceptance and tag validator.
#
# Default behavior:
#   - Requires the complete Step 5 boundary to be committed first.
#   - Validates the Phase 2 acceptance record and accepted documentation.
#   - Runs the complete Foundation clean-install, sequential, and concurrency
#     suite.
#   - Requires 213 PASS, 0 FAIL, and the 3 understood WARN results.
#   - Confirms that the annotated Phase 2 acceptance tag name is available.
#
# --verify-tag reruns the complete gate and verifies that the annotated tag
# exists, points to the clean current HEAD, and carries the required evidence.
#
# Use --static-only only when deliberately checking files on a host that cannot
# reach the PostgreSQL test service.
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly SCRIPT_NAME="${0##*/}"
STATIC_ONLY=0
VERIFY_TAG=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [--static-only] [--verify-tag]

Default:
  Run every check required through Phase 2 Step 6 before the acceptance commit
  and tag are created. The complete Step 5 boundary must already be committed.
  The validator runs the PostgreSQL clean-install, all 12 sequential tests,
  all 4 concurrency tests, and confirms the Phase 2 tag name is available.

Options:
  --static-only
      Run file, manifest, SQL-boundary, acceptance-document, shell, Git, and
      tag-readiness checks without connecting to PostgreSQL.

  --verify-tag
      Rerun the complete gate after the Step 6 acceptance commit and annotated
      tag are created. Require a clean working tree and verify that
      phase-2-session-control-complete-v1 is an annotated tag pointing to HEAD.

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
        --verify-tag)
            VERIFY_TAG=1
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

if (( STATIC_ONLY == 1 && VERIFY_TAG == 1 )); then
    printf '%s\n'         '--static-only and --verify-tag cannot be combined.' >&2
    printf '%s\n'         '--verify-tag intentionally reruns the complete PostgreSQL gate.' >&2
    exit 64
fi

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
concurrency_phase1="test-framework/sql/tests/concurrency/100_authentication_assertion_single_use.sh"
concurrency_establishment="test-framework/sql/tests/concurrency/110_session_establishment_single_use.sh"
concurrency_step_up="test-framework/sql/tests/concurrency/120_session_step_up_single_use.sh"
concurrency_terminal="test-framework/sql/tests/concurrency/130_session_terminal_transition_race.sh"
step2_test="test-framework/sql/tests/foundation/110_session_establishment_and_step_up_behavior.sql"
step2_acceptance="docs/architecture/foundation/phase-2-step-2-session-establishment-and-step-up-acceptance.md"
phase2_acceptance="docs/architecture/foundation/phase-2-session-establishment-step-up-and-lifecycle-acceptance.md"
phase1_tag="phase-1-authentication-assertion-complete-v1"
phase2_tag="phase-2-session-control-complete-v1"
validator_file="validate_phase2_step6.sh"

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
    "$concurrency_phase1"
    "$concurrency_establishment"
    "$concurrency_step_up"
    "$concurrency_terminal"
    "$step2_test"
    "$step2_acceptance"
    "$phase2_acceptance"
    "$validator_file"
)

section "Required files"

for path in "${required_files[@]}"; do
    if [[ -f "$path" ]]; then
        pass "Required file exists: ${path}"
    else
        fail "Required file is missing: ${path}"
    fi
done

section "Exact accepted and Step 6 file boundaries"

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
        "validated Step 3 migration 072 is unchanged",
    ),
    (
        repo / "docs/architecture/foundation/session-establishment-step-up-and-lifecycle-model.md",
        "1fdb6b0d8b1decbcc3e5c73725170e9553e15253d0a277cd23d01b2f2089aff1",
        "Step 6 accepted normative model matches the full replacement",
    ),
    (
        repo / "docs/architecture/foundation/sql-migration-map.md",
        "112dd17045d57f902d2bea3453a5b7f48a3d3c374759851c929771caf06f2d42",
        "Step 6 accepted migration map matches the full replacement",
    ),
    (
        repo / "docs/architecture/foundation/phase-2-session-establishment-step-up-and-lifecycle-acceptance.md",
        "7ea960a5a36b4dd9878618595fd37f0e8279f4ecb035f43f4dec6e8e03089354",
        "Phase 2 acceptance record matches the full replacement",
    ),
    (
        repo / "test-framework/sql/tests/foundation/120_session_lifecycle_behavior.sql",
        "4b36e22fe2e0440c436796cfae62b9b171108c74f34ebea2617dcd26ff30fb7b",
        "Step 4 lifecycle test matches the full replacement",
    ),
    (
        repo / "test-framework/sql/tests/concurrency/110_session_establishment_single_use.sh",
        "3fca6984a649bab91f0db827996f359e335d65f9c9cda7713b2f34f841dd56f2",
        "Step 5 establishment race matches the full replacement",
    ),
    (
        repo / "test-framework/sql/tests/concurrency/120_session_step_up_single_use.sh",
        "d1b41e28e71e09121db6b06f3cea0365f65eea8a961ecbbd834ee6712654f085",
        "Step 5 step-up race matches the full replacement",
    ),
    (
        repo / "test-framework/sql/tests/concurrency/130_session_terminal_transition_race.sh",
        "3fbd6867088cddb6918b6095b5809807add9e17339af78706296dfd1e1d3a00e",
        "Step 5 terminal race matches the full replacement",
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
    PASS_COUNT=$((PASS_COUNT + 10))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Committed Step 5 baseline"

if python3 - "$VERIFY_TAG" <<'PY'
from __future__ import annotations

import hashlib
import subprocess
import sys

verify_tag = sys.argv[1] == "1"
baseline_revision = "HEAD^" if verify_tag else "HEAD"

checks = [
    (
        "docs/architecture/foundation/session-establishment-step-up-and-lifecycle-model.md",
        "cfac8b49859aec9606010fa0b05830aa42fed9c3b61aef0fcd93c8b8821de554",
    ),
    (
        "docs/architecture/foundation/sql-migration-map.md",
        "79147d5af21ddfc366e71ab8c472224d3d61d4bfc05983e961b93e77e5859a32",
    ),
    (
        "test-framework/sql/tests/foundation/120_session_lifecycle_behavior.sql",
        "4b36e22fe2e0440c436796cfae62b9b171108c74f34ebea2617dcd26ff30fb7b",
    ),
    (
        "test-framework/sql/tests/foundation-concurrency-tests.manifest",
        "afe0c34278885baabfc7d0deb9b7b2e30b3d99f0a694205fc67078623d8dbcdc",
    ),
    (
        "test-framework/sql/tests/concurrency/110_session_establishment_single_use.sh",
        "3fca6984a649bab91f0db827996f359e335d65f9c9cda7713b2f34f841dd56f2",
    ),
    (
        "test-framework/sql/tests/concurrency/120_session_step_up_single_use.sh",
        "d1b41e28e71e09121db6b06f3cea0365f65eea8a961ecbbd834ee6712654f085",
    ),
    (
        "test-framework/sql/tests/concurrency/130_session_terminal_transition_race.sh",
        "3fbd6867088cddb6918b6095b5809807add9e17339af78706296dfd1e1d3a00e",
    ),
]

failures = []

for path, expected in checks:
    result = subprocess.run(
        ["git", "show", f"{baseline_revision}:{path}"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    if result.returncode != 0:
        failures.append(
            f"{path} is not present at {baseline_revision}; the parent acceptance boundary must be committed Step 5"
        )
        continue

    actual = hashlib.sha256(result.stdout).hexdigest()

    if actual == expected:
        print(f"COMMITTED BASELINE PASS: {path}")
    else:
        failures.append(
            f"{path} at {baseline_revision} does not match the validated Step 5 boundary "
            f"(expected {expected}, actual {actual})"
        )

if failures:
    for failure in failures:
        print(f"COMMITTED BASELINE FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then
    PASS_COUNT=$((PASS_COUNT + 7))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Acceptance tag and working-tree boundary"

if git rev-parse -q --verify "refs/tags/${phase1_tag}" >/dev/null; then
    pass "Accepted Phase 1 tag remains identifiable: ${phase1_tag}"
else
    fail "Accepted Phase 1 tag is missing locally: ${phase1_tag}"
    printf '      Fetch tags with: git fetch --tags origin\n' >&2
fi

if (( VERIFY_TAG == 0 )); then
    if git rev-parse -q --verify "refs/tags/${phase2_tag}" >/dev/null; then
        fail "Phase 2 tag already exists; use --verify-tag instead of recreating it"
    else
        pass "Phase 2 acceptance tag name is available: ${phase2_tag}"
    fi

    if python3 - "$phase2_acceptance" "$model" "$migration_map" "$validator_file" <<'PY'
from __future__ import annotations

import subprocess
import sys

allowed = set(sys.argv[1:])
result = subprocess.run(
    ["git", "status", "--porcelain=v1", "--untracked-files=all"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
)

unexpected = []

for raw_line in result.stdout.splitlines():
    if not raw_line:
        continue

    path = raw_line[3:]

    if " -> " in path:
        path = path.split(" -> ", 1)[1]

    if path not in allowed:
        unexpected.append(f"{raw_line[:2]} {path}")

if unexpected:
    for entry in unexpected:
        print(
            f"WORKTREE BOUNDARY FAIL: unexpected change: {entry}",
            file=sys.stderr,
        )
    raise SystemExit(1)

print(
    "WORKTREE BOUNDARY PASS: only the four Step 6 acceptance files are changed"
)
PY
    then
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    if [[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]]; then
        pass "Tagged acceptance verification uses a clean working tree"
    else
        fail "Tagged acceptance verification requires a clean working tree"
        git status --short >&2
    fi
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

section "Concurrency manifest boundary"

concurrency_entries=()
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    entry="$(
        printf '%s' "$raw_line" \
            | sed 's/\r$//' \
            | sed 's/[[:space:]]*#.*$//' \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    )"

    [[ -z "$entry" ]] && continue
    concurrency_entries+=("$entry")
done <"$concurrency_manifest"

expected_concurrency_entries=(
    "concurrency/100_authentication_assertion_single_use.sh"
    "concurrency/110_session_establishment_single_use.sh"
    "concurrency/120_session_step_up_single_use.sh"
    "concurrency/130_session_terminal_transition_race.sh"
)

if (( ${#concurrency_entries[@]} == 4 )); then
    pass "Concurrency manifest contains exactly 4 test files"
else
    fail "Concurrency manifest must contain 4 test files; found ${#concurrency_entries[@]}"
fi

for index in "${!expected_concurrency_entries[@]}"; do
    expected_entry="${expected_concurrency_entries[$index]}"
    actual_entry="${concurrency_entries[$index]:-}"

    if [[ "$actual_entry" == "$expected_entry" ]]; then
        pass "Concurrency manifest position $((index + 1)) is correct: ${expected_entry}"
    else
        fail "Concurrency manifest position $((index + 1)) must be ${expected_entry}; found ${actual_entry:-<missing>}"
    fi
done

concurrency_duplicate_count="$(
    printf '%s\n' "${concurrency_entries[@]}" \
        | sort \
        | uniq -d \
        | wc -l
)"

if [[ "$concurrency_duplicate_count" == "0" ]]; then
    pass "Concurrency manifest contains no duplicate entries"
else
    fail "Concurrency manifest contains duplicate entries"
fi

section "Step 5 multi-connection race boundary"

declare -A concurrency_assertion_expectations=(
    ["$concurrency_establishment"]=8
    ["$concurrency_step_up"]=8
    ["$concurrency_terminal"]=9
)

for path in \
    "$concurrency_establishment" \
    "$concurrency_step_up" \
    "$concurrency_terminal"; do

    assertion_total="$(
        grep -Eoc \
            'sql_test[.]assert_(true|false|equal_bigint|no_rows|raises)[[:space:]]*[(]' \
            "$path"
    )"

    expected_total="${concurrency_assertion_expectations[$path]}"

    if [[ "$assertion_total" == "$expected_total" ]]; then
        pass "${path} defines exactly ${expected_total} recorded assertions"
    else
        fail "${path} must define ${expected_total} recorded assertions; found ${assertion_total}"
    fi

    if grep -Fq -- "run_worker worker_one" "$path" \
       && grep -Fq -- "run_worker worker_two" "$path" \
       && grep -Fq -- "pg_advisory_lock_shared" "$path" \
       && grep -Fq -- "concurrency_readiness" "$path"; then
        pass "${path} uses two independent workers and a release barrier"
    else
        fail "${path} is missing the independent-worker release barrier"
    fi

    if grep -Eq -- \
        'CREATE[[:space:]]+FUNCTION[[:space:]]+access_control[.]' \
        "$path"; then
        fail "${path} must not replace production access_control functions"
    else
        pass "${path} does not replace production access_control functions"
    fi
done

required_establishment_markers=(
    "Exactly one concurrent session-establishment worker succeeds"
    "Exactly one concurrent session-establishment worker is denied"
    "Session-establishment race creates exactly one session"
    "Session-establishment race writes exactly one CREATED event"
    "Session-establishment race preserves exact session and event linkage"
)

for marker in "${required_establishment_markers[@]}"; do
    if grep -Fq -- "$marker" "$concurrency_establishment"; then
        pass "Establishment race marker exists: ${marker}"
    else
        fail "Establishment race marker is missing: ${marker}"
    fi
done

required_step_up_markers=(
    "Exactly one concurrent session step-up worker succeeds"
    "Exactly one concurrent session step-up worker is denied"
    "Session step-up race consumes the assertion exactly once"
    "Session step-up race writes exactly one STEP_UP_COMPLETED event"
    "Session step-up race preserves exact assertion timestamp and event linkage"
)

for marker in "${required_step_up_markers[@]}"; do
    if grep -Fq -- "$marker" "$concurrency_step_up"; then
        pass "Step-up race marker exists: ${marker}"
    else
        fail "Step-up race marker is missing: ${marker}"
    fi
done

required_terminal_markers=(
    "Exactly one incompatible terminal transition succeeds"
    "Exactly one incompatible terminal transition observes the terminal state"
    "Terminal-transition race records exactly one terminal timestamp"
    "Terminal-transition race writes exactly one terminal event"
    "Terminal-transition race creates no mixed terminal state"
)

for marker in "${required_terminal_markers[@]}"; do
    if grep -Fq -- "$marker" "$concurrency_terminal"; then
        pass "Terminal race marker exists: ${marker}"
    else
        fail "Terminal race marker is missing: ${marker}"
    fi
done

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

if python3 - "$model" "$migration_map" "$phase2_acceptance" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

model_path = Path(sys.argv[1])
migration_map_path = Path(sys.argv[2])
acceptance_path = Path(sys.argv[3])

checks = [
    (model_path, "Phase 2 accepted; authoritative acceptance record and tag"),
    (
        model_path,
        "phase-2-session-establishment-step-up-and-lifecycle-acceptance.md",
    ),
    (model_path, "phase-2-session-control-complete-v1"),
    (model_path, "213 passes and zero failed assertions"),
    (
        migration_map_path,
        "The accepted Step 5 run completed with 213 passes, zero failures, "
        "and three understood warnings.",
    ),
    (migration_map_path, "phase-2-session-control-complete-v1"),
    (acceptance_path, "Run ID: foundation_20260712_082801_183214"),
    (acceptance_path, "Sequential test files: 12"),
    (acceptance_path, "Concurrency test files: 4"),
    (acceptance_path, "PASS: 213"),
    (acceptance_path, "FAIL: 0"),
    (acceptance_path, "WARN: 3"),
    (
        acceptance_path,
        "is the durable identifier for the exact accepted repository tree.",
    ),
    (
        acceptance_path,
        "A passing historical result does not replace a fresh run after a "
        "relevant change.",
    ),
]

failures = []

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
    PASS_COUNT=$((PASS_COUNT + 14))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Shell and Git hygiene"

if bash -n "$runner"; then
    pass "Foundation test runner shell syntax is valid"
else
    fail "Foundation test runner shell syntax is invalid"
fi

for path in \
    "$concurrency_phase1" \
    "$concurrency_establishment" \
    "$concurrency_step_up" \
    "$concurrency_terminal"; do

    if bash -n "$path"; then
        pass "Concurrency test shell syntax is valid: ${path}"
    else
        fail "Concurrency test shell syntax is invalid: ${path}"
    fi
done

if bash -n "$0"; then
    pass "Step 6 validator shell syntax is valid"
else
    fail "Step 6 validator shell syntax is invalid"
fi

if python3 - \
    "$model" \
    "$migration_map" \
    "$phase2_acceptance" \
    "$validator_file" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

failures: list[str] = []

for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    data = path.read_bytes()

    if b"\r\n" in data:
        failures.append(f"{path}: CRLF line endings are not permitted")

    if not data.endswith(b"\n"):
        failures.append(f"{path}: file must end with one newline")
    elif data.endswith(b"\n\n"):
        failures.append(f"{path}: new blank line at EOF")

    for line_number, line in enumerate(
        data.decode("utf-8").splitlines(),
        start=1,
    ):
        if line.endswith((" ", "\t")):
            failures.append(
                f"{path}:{line_number}: trailing whitespace"
            )

        if line.startswith(("<<<<<<<", "=======", ">>>>>>>")):
            failures.append(
                f"{path}:{line_number}: conflict marker"
            )

if failures:
    for failure in failures:
        print(f"FILE HYGIENE FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

print("FILE HYGIENE PASS: all Step 6 files have clean UTF-8 line boundaries")
PY
then
    pass "Changed Step 6 acceptance files pass direct file hygiene checks"
else
    fail "Changed Step 6 acceptance files contain whitespace, EOF, or conflict-marker problems"
fi

section "Static result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 2 Step 6 static validation FAILED.\n' >&2
    printf 'No PostgreSQL test was started.\n' >&2
    exit 1
fi

printf '\nPhase 2 Step 6 static validation PASSED.\n'

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

section "Foundation clean-install and Phase 2 acceptance gate"

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
    "concurrency test count": r"(?m)^Concurrency test files:[ \t]+4[ \t]*$",
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

    if pass_match is None or int(pass_match.group(1)) != 213:
        failures.append("Result totals do not report PASS=213")

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
print("SUMMARY CHECK PASS: Concurrency test files = 4")
print("SUMMARY CHECK PASS: PASS = 213")
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

if (( VERIFY_TAG == 1 )); then
    section "Annotated acceptance tag verification"

    if ! tag_object_type="$(git cat-file -t "refs/tags/${phase2_tag}" 2>/dev/null)"; then
        fail "Phase 2 acceptance tag does not exist: ${phase2_tag}"
    elif [[ "$tag_object_type" != "tag" ]]; then
        fail "Phase 2 acceptance tag must be annotated; object type is ${tag_object_type}"
    else
        pass "Phase 2 acceptance tag is annotated"
    fi

    if tag_target="$(git rev-parse "${phase2_tag}^{}" 2>/dev/null)"; then
        head_commit="$(git rev-parse HEAD)"

        if [[ "$tag_target" == "$head_commit" ]]; then
            pass "Phase 2 acceptance tag points to the current HEAD"
        else
            fail "Phase 2 acceptance tag does not point to the current HEAD"
            printf '      tag target: %s\n' "$tag_target" >&2
            printf '      current HEAD: %s\n' "$head_commit" >&2
        fi
    else
        fail "Could not resolve Phase 2 acceptance tag target"
    fi

    if tag_message="$(git for-each-ref \
        --format='%(contents)' \
        "refs/tags/${phase2_tag}")"; then
        required_tag_markers=(
            "Phase 2 session control acceptance"
            "213 PASS"
            "0 FAIL"
            "3 WARN"
            "docs/architecture/foundation/phase-2-session-establishment-step-up-and-lifecycle-acceptance.md"
        )

        for marker in "${required_tag_markers[@]}"; do
            if grep -Fq -- "$marker" <<<"$tag_message"; then
                pass "Annotated tag message contains: ${marker}"
            else
                fail "Annotated tag message is missing: ${marker}"
            fi
        done
    else
        fail "Could not read the annotated Phase 2 tag message"
    fi
fi

section "Final result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 2 Step 6 acceptance validation FAILED.\n' >&2
    printf 'Summary: %s\n' "$summary" >&2
    exit 1
fi

if (( VERIFY_TAG == 1 )); then
    printf '\nPhase 2 Step 6 validation PASSED completely.\n'
    printf 'The annotated Phase 2 acceptance tag is verified at the clean current HEAD.\n'
else
    printf '\nPhase 2 Step 6 pre-tag validation PASSED completely.\n'
    printf 'Commit the four Step 6 acceptance files, create the annotated tag, push both, and rerun with --verify-tag.\n'
fi
