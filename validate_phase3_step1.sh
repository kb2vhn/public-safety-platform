#!/usr/bin/env bash

#
# validate_phase3_step1.sh
#
# Authoritative Phase 3 Step 1 architecture-boundary validator.
#
# Step 1 is intentionally documentation-only. The validator proves that the
# accepted Phase 2 SQL and test boundary remains unchanged, validates the
# complete Phase 3 contract replacement, and exits before any file or database
# modification.
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

SCRIPT_NAME="$(basename -- "$0")"
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'EOF'
Usage: validate_phase3_step1.sh

Validate the Phase 3 Step 1 architecture freeze.

This validator:
  - Performs a complete dependency preflight.
  - Requires the dev branch.
  - Verifies the annotated Phase 2 acceptance tag and accepted commit.
  - Confirms current HEAD descends from the accepted Phase 2 commit.
  - Confirms SQL, manifests, runner, and tests are unchanged from Phase 2.
  - Validates the exact Step 1 documentation replacements.
  - Allows only the five Step 1 files to be changed in the working tree.
  - Does not connect to PostgreSQL or modify the repository.
EOF
}

pass() {
    printf 'PASS: %s\n' "$1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

section() {
    printf '\n== %s ==\n' "$1"
}

if [[ $# -ne 0 ]]; then
    case "${1:-}" in
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
fi

if (( BASH_VERSINFO[0] < 4 )); then
    printf 'Bash 4 or newer is required; running version is %s\n' \
        "$BASH_VERSION" >&2
    printf 'Arch Linux package: bash\n' >&2
    printf 'No repository file or database was modified.\n' >&2
    exit 69
fi

declare -A COMMAND_PACKAGE_MAP=(
    [bash]="bash"
    [basename]="coreutils"
    [dirname]="coreutils"
    [git]="git"
    [grep]="grep"
    [python3]="python"
    [sha256sum]="coreutils"
    [uname]="coreutils"
)

required_commands=(
    bash
    basename
    dirname
    git
    grep
    python3
    sha256sum
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

section "Dependency preflight"

if [[ "${#missing_commands[@]}" -ne 0 ]]; then
    printf 'Dependency preflight: FAIL\n\n' >&2
    printf 'Missing required commands:\n' >&2

    for command_name in "${missing_commands[@]}"; do
        printf '  %-12s Arch package: %s\n' \
            "$command_name" \
            "${COMMAND_PACKAGE_MAP[$command_name]}" >&2
    done

    printf -v package_line '%s ' "${missing_packages[@]}"
    package_line="${package_line% }"

    printf '\nInstall all missing packages with:\n\n' >&2
    printf '  sudo pacman -S --needed %s\n' "$package_line" >&2
    printf '\nWhen operating as root without sudo:\n\n' >&2
    printf '  pacman -S --needed %s\n' "$package_line" >&2
    printf '\nNo repository file or database was modified.\n' >&2
    exit 69
fi

pass "All Phase 3 Step 1 validator commands are available"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if ! repository_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'The validator must be run from inside the repository.\n' >&2
    exit 66
fi

cd "$repository_root"

phase2_tag="phase-2-session-control-complete-v1"
phase2_commit="76c7883c9e04cc320c0b133f86fe3c0d9dbbc63b"

model="docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md"
foundation_readme="docs/architecture/foundation/README.md"
evaluation_contract="docs/architecture/foundation/authorization-evaluation-contract.md"
migration_map="docs/architecture/foundation/sql-migration-map.md"
validator_file="validate_phase3_step1.sh"

required_files=(
    "$model"
    "$foundation_readme"
    "$evaluation_contract"
    "$migration_map"
    "$validator_file"
    "docs/architecture/foundation/phase-2-session-establishment-step-up-and-lifecycle-acceptance.md"
    "sql/schema/migrations/foundation/055_authority_purpose_and_authorization_policy.sql"
    "sql/schema/migrations/foundation/060_sessions.sql"
    "sql/schema/migrations/foundation/065_authorization_leases.sql"
    "sql/schema/migrations/foundation/070_postgresql_authentication_assertion_gate.sql"
    "sql/schema/migrations/foundation/072_postgresql_session_control.sql"
    "sql/schema/migrations/foundation/075_controlled_authorization_api.sql"
    "sql/schema/migrations/foundation/080_decision_record_repository.sql"
    "sql/schema/manifests/foundation.manifest"
    "test-framework/sql/schema/scripts/test_foundation.sh"
    "test-framework/sql/tests/foundation-tests.manifest"
    "test-framework/sql/tests/foundation-concurrency-tests.manifest"
)

section "Repository identity"

printf 'Repository root: %s\n' "$repository_root"
printf 'Host: %s\n' "$(uname -n)"
printf 'Operating system: %s\n' "$(uname -s)"
printf 'Current branch: %s\n' "$(git branch --show-current)"
printf 'Current commit: %s\n' "$(git rev-parse --short=12 HEAD)"

if [[ "$(git branch --show-current)" == "dev" ]]; then
    pass "Current branch is dev"
else
    fail "Current branch must be dev"
fi

if git diff --name-only --diff-filter=U | grep -q .; then
    fail "Repository contains unresolved Git conflicts"
else
    pass "No unresolved Git conflicts"
fi

section "Accepted Phase 2 boundary"

if tag_type="$(git cat-file -t "refs/tags/${phase2_tag}" 2>/dev/null)"; then
    if [[ "$tag_type" == "tag" ]]; then
        pass "Phase 2 acceptance tag is annotated"
    else
        fail "Phase 2 acceptance tag must be annotated; object type=${tag_type}"
    fi
else
    fail "Phase 2 acceptance tag is missing locally: ${phase2_tag}"
    printf '      Fetch tags with: git fetch --tags origin\n' >&2
fi

if tag_target="$(git rev-parse "${phase2_tag}^{}" 2>/dev/null)"; then
    if [[ "$tag_target" == "$phase2_commit" ]]; then
        pass "Phase 2 acceptance tag points to the accepted commit"
    else
        fail "Phase 2 acceptance tag points to the wrong commit"
        printf '      expected: %s\n' "$phase2_commit" >&2
        printf '      actual:   %s\n' "$tag_target" >&2
    fi
else
    fail "Could not resolve the Phase 2 acceptance tag target"
fi

if git merge-base --is-ancestor "$phase2_commit" HEAD; then
    pass "Current HEAD descends from the accepted Phase 2 commit"
else
    fail "Current HEAD does not descend from the accepted Phase 2 commit"
fi

section "Required files"

for path in "${required_files[@]}"; do
    if [[ -f "$path" ]]; then
        pass "Required file exists: ${path}"
    else
        fail "Required file is missing: ${path}"
    fi
done

if (( FAIL_COUNT != 0 )); then
    printf '\nPhase 3 Step 1 validation stopped because required boundaries are missing.\n' >&2
    printf 'No repository file or database was modified.\n' >&2
    exit 1
fi

section "Accepted SQL and test immutability"

if git diff --quiet "$phase2_commit" -- \
    sql/schema \
    test-framework/sql; then
    pass "SQL schema, manifests, runner, and tests are unchanged from accepted Phase 2"
else
    fail "SQL schema or test framework changed after the accepted Phase 2 tag"
    git diff --name-status "$phase2_commit" -- \
        sql/schema \
        test-framework/sql >&2
fi

for migration in \
    055_authority_purpose_and_authorization_policy.sql \
    060_sessions.sql \
    065_authorization_leases.sql \
    070_postgresql_authentication_assertion_gate.sql \
    072_postgresql_session_control.sql \
    075_controlled_authorization_api.sql \
    080_decision_record_repository.sql; do

    if git diff --quiet "$phase2_commit" -- \
        "sql/schema/migrations/foundation/${migration}"; then
        pass "Accepted migration is unchanged: ${migration}"
    else
        fail "Accepted migration changed during Step 1: ${migration}"
    fi
done

section "Exact Step 1 file boundaries"

if python3 <<'PY'
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

checks = [
    (
        Path("docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md"),
        "9ba88eea8a2e39ca65217f77d8ff8d22f0bd739059e8ea9d7c7c24b2160b2876",
        "Phase 3 normative model matches the full replacement",
    ),
    (
        Path("docs/architecture/foundation/README.md"),
        "9022bb2bc33789b9b09ccf8f0ed06a3f9a94e8bb1742a4fcef07457de363441d",
        "Foundation README matches the full replacement",
    ),
    (
        Path("docs/architecture/foundation/authorization-evaluation-contract.md"),
        "7580f0dd5dafb977e68fd41a9b1bcfe2d3459f38a7152caa985802cb35426e7e",
        "Authorization Evaluation Contract matches the full replacement",
    ),
    (
        Path("docs/architecture/foundation/sql-migration-map.md"),
        "437cce23fa62fe2801badd1c831414e53b29ef7c2a1d1df973fd6f5c5885aad9",
        "SQL Migration Map matches the full replacement",
    ),
]

failures = []

for path, expected, description in checks:
    actual = hashlib.sha256(path.read_bytes()).hexdigest()

    if actual == expected:
        print(f"EXACT FILE PASS: {description}")
    else:
        failures.append(
            f"{description}: expected {expected}, actual {actual}"
        )

if failures:
    for failure in failures:
        print(f"EXACT FILE FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then
    PASS_COUNT=$((PASS_COUNT + 4))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Normative contract markers"

if python3 - "$model" "$foundation_readme" "$evaluation_contract" "$migration_map" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

model = Path(sys.argv[1])
readme = Path(sys.argv[2])
contract = Path(sys.argv[3])
migration_map = Path(sys.argv[4])

checks = [
    (model, "Status: Normative Phase 3 contract; Step 1 architecture freeze"),
    (model, "phase-2-session-control-complete-v1"),
    (model, "081_postgresql_authorization_decision_and_lease_issuance.sql"),
    (model, "Exactly one applicable Authorization Policy Version is selected."),
    (model, "A Decision Record cannot finalize as ALLOW while any required stage"),
    (model, "One Decision Record may issue at most one Authorization Lease."),
    (model, "A caller-supplied allowed=true"),
    (model, "SINGLE_USE"),
    (model, "LIMITED_USE"),
    (model, "A passing historical result does not replace a fresh run"),
    (readme, "Current implementation phase: Phase 3"),
    (readme, "Accepted Phase 2 Boundary"),
    (readme, "Current Phase 3 Boundary"),
    (readme, "213 PASS"),
    (contract, "Phase 3 Controlled Decision and Lease-Issuance Boundary"),
    (contract, "081_postgresql_authorization_decision_and_lease_issuance.sql"),
    (migration_map, "Accepted Phase 2 Mapping"),
    (migration_map, "Active Phase 3 Mapping"),
    (migration_map, "Migration 081 is not part of the current Foundation manifest during Step 1."),
    (migration_map, "Step 1 is architecture-only."),
]

failures = []

def normalize_markdown(value: str) -> str:
    value = re.sub(r"[`*>]", "", value)
    return re.sub(r"\s+", " ", value).strip()


for path, marker in checks:
    normalized_text = normalize_markdown(
        path.read_text(encoding="utf-8")
    )
    normalized_marker = normalize_markdown(marker)

    if normalized_marker in normalized_text:
        print(f"DOCUMENTATION CHECK PASS: {path}")
    else:
        failures.append(f"{path}: missing normalized marker: {normalized_marker}")

if failures:
    for failure in failures:
        print(f"DOCUMENTATION CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then
    PASS_COUNT=$((PASS_COUNT + 20))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Working-tree boundary"

if python3 - \
    "$model" \
    "$foundation_readme" \
    "$evaluation_contract" \
    "$migration_map" \
    "$validator_file" <<'PY'
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
        print(f"WORKTREE BOUNDARY FAIL: unexpected change: {entry}", file=sys.stderr)
    raise SystemExit(1)

print("WORKTREE BOUNDARY PASS: only the five Phase 3 Step 1 files are changed")
PY
then
    PASS_COUNT=$((PASS_COUNT + 1))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if git diff --name-only -- \
    sql \
    test-framework | grep -q .; then
    fail "Step 1 unexpectedly changes SQL or test-framework files"
else
    pass "Step 1 changes no SQL or test-framework files"
fi

section "Shell and file hygiene"

if bash -n "$validator_file"; then
    pass "Phase 3 Step 1 validator shell syntax is valid"
else
    fail "Phase 3 Step 1 validator shell syntax is invalid"
fi

if python3 - \
    "$model" \
    "$foundation_readme" \
    "$evaluation_contract" \
    "$migration_map" \
    "$validator_file" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

failures = []

for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    data = path.read_bytes()

    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        failures.append(f"{path}: invalid UTF-8: {exc}")
        continue

    if b"\r\n" in data:
        failures.append(f"{path}: CRLF line endings are not permitted")

    if not data.endswith(b"\n"):
        failures.append(f"{path}: file must end with one newline")
    elif data.endswith(b"\n\n"):
        failures.append(f"{path}: extra blank line at EOF")

    for line_number, line in enumerate(text.splitlines(), start=1):
        if line.endswith((" ", "\t")):
            failures.append(f"{path}:{line_number}: trailing whitespace")

        if line.startswith(("<<<<<<<", "=======", ">>>>>>>")):
            failures.append(f"{path}:{line_number}: conflict marker")

if failures:
    for failure in failures:
        print(f"FILE HYGIENE FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

print("FILE HYGIENE PASS: all Step 1 files have clean UTF-8 line boundaries")
PY
then
    pass "All Phase 3 Step 1 files pass direct file hygiene checks"
else
    fail "A Phase 3 Step 1 file failed direct file hygiene checks"
fi

section "Final result"

printf 'PASS checks: %s\n' "$PASS_COUNT"
printf 'FAIL checks: %s\n' "$FAIL_COUNT"

if (( FAIL_COUNT != 0 )); then
    printf '\nPhase 3 Step 1 validation FAILED.\n' >&2
    printf 'No PostgreSQL test was started because Step 1 is architecture-only.\n' >&2
    exit 1
fi

printf '\nPhase 3 Step 1 validation PASSED completely.\n'
printf 'The authorization decision and controlled lease-issuance contract is ready to commit.\n'
printf 'No PostgreSQL test was required because accepted SQL and tests are unchanged.\n'
