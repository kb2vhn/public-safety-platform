#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'EOF'
Usage: tools/validation/phase-gates/validate_phase4_step1.sh [--static-only]

Default:
  Validate the Phase 4 Step 1 architecture contract and rerun the complete
  accepted Foundation PostgreSQL suite.

Options:
  --static-only  Run static contract checks without PostgreSQL.
  -h, --help     Show this help text.
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
    printf 'Bash 4 or newer is required.\n' >&2
    printf 'Arch package: bash\n' >&2
    printf 'Install with: sudo pacman -S --needed bash\n' >&2
    exit 69
fi

declare -A COMMAND_PACKAGE_MAP=(
    [awk]="gawk"
    [bash]="bash"
    [cat]="coreutils"
    [createdb]="postgresql-libs"
    [date]="coreutils"
    [dirname]="coreutils"
    [dropdb]="postgresql-libs"
    [git]="git"
    [grep]="grep"
    [psql]="postgresql-libs"
    [python3]="python"
    [sha256sum]="coreutils"
    [uname]="coreutils"
)

required_commands=(
    awk
    bash
    cat
    createdb
    date
    dirname
    dropdb
    git
    grep
    psql
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

if (( ${#missing_commands[@]} > 0 )); then
    printf 'Missing required commands:\n' >&2

    for command_name in "${missing_commands[@]}"; do
        printf '  %-12s Arch package: %s\n' \
            "$command_name" \
            "${COMMAND_PACKAGE_MAP[$command_name]}" >&2
    done

    printf '\nInstall all missing packages with:\n\n' >&2
    printf '  sudo pacman -S --needed' >&2
    printf ' %s' "${missing_packages[@]}" >&2
    printf '\n\nNo repository file or database was modified.\n' >&2
    exit 69
fi

pass "All required Phase 4 Step 1 commands are available"

if ! repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'Run this validator from inside the repository.\n' >&2
    exit 66
fi

cd "$repository_root"

phase3_tag="phase-3-authorization-control-complete-v1"
phase3_commit="853d26e37f1471aeeaeea4e7690e1a0605a22870"
phase3_acceptance_record="docs/architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md"
phase3_acceptance_sha256="5d69bcb8bd6e1b4c97784803419d0a3029e0aea460010931eae1998742550765"
phase4_contract="docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md"
runner="test-framework/sql/schema/scripts/test_foundation.sh"
previous_validator="tools/validation/phase-gates/validate_phase3_step7.sh"
validator_file="tools/validation/phase-gates/validate_phase4_step1.sh"

phase4_files=(
    "README.md"
    "docs/README.md"
    "docs/architecture/README.md"
    "docs/goals/two-person-concept.md"
    "docs/architecture/foundation/README.md"
    "docs/architecture/foundation/approval-framework.md"
    "docs/architecture/foundation/authority-and-authorization-model.md"
    "docs/architecture/foundation/authorization-evaluation-contract.md"
    "docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md"
    "$phase4_contract"
    "docs/architecture/foundation/sql-migration-map.md"
    "tools/validation/README.md"
    "tools/validation/phase-gates/README.md"
    "$validator_file"
)

required_files=(
    "${phase4_files[@]}"
    "$phase3_acceptance_record"
    "$runner"
    "$previous_validator"
    "sql/schema/manifests/foundation.manifest"
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

if [[ -z "$(git diff --name-only --diff-filter=U)" ]]; then
    pass "No unresolved Git conflicts"
else
    fail "Repository contains unresolved Git conflicts"
fi

section "Accepted Phase 3 boundary"

if [[ "$(git cat-file -t "refs/tags/${phase3_tag}" 2>/dev/null || true)" == "tag" ]]; then
    pass "Phase 3 acceptance tag is annotated"
else
    fail "Phase 3 acceptance tag is missing or not annotated"
fi

if [[ "$(git rev-parse "${phase3_tag}^{}" 2>/dev/null || true)" == "$phase3_commit" ]]; then
    pass "Phase 3 acceptance tag points to the accepted implementation commit"
else
    fail "Phase 3 acceptance tag points to the wrong commit"
fi

if git merge-base --is-ancestor "$phase3_commit" HEAD; then
    pass "Current Phase 4 contract commit descends from accepted Phase 3"
else
    fail "Current HEAD does not descend from accepted Phase 3"
fi

if git diff --quiet "$phase3_commit" -- sql/schema test-framework/sql; then
    pass "Accepted Phase 3 SQL and SQL test tree is unchanged"
else
    fail "SQL or SQL test content differs from accepted Phase 3"
    git diff --name-status "$phase3_commit" -- \
        sql/schema \
        test-framework/sql >&2
fi

tag_message="$(git cat-file -p "refs/tags/${phase3_tag}" 2>/dev/null || true)"

for marker in \
    "33 migrations" \
    "16 sequential tests" \
    "9 concurrency tests" \
    "408 PASS" \
    "0 FAIL" \
    "3 understood WARN"
do
    if grep -Fq "$marker" <<<"$tag_message"; then
        pass "Acceptance tag message contains: $marker"
    else
        fail "Acceptance tag message is missing: $marker"
    fi
done

if [[ -f "$phase3_acceptance_record" ]]; then
    actual_acceptance_hash="$(
        sha256sum "$phase3_acceptance_record" | awk '{print $1}'
    )"

    if [[ "$actual_acceptance_hash" == "$phase3_acceptance_sha256" ]]; then
        pass "Formal Phase 3 acceptance record is unchanged"
    else
        fail "Formal Phase 3 acceptance record hash changed"
    fi
else
    fail "Formal Phase 3 acceptance record is missing"
fi

section "Required files"

for path in "${required_files[@]}"; do
    if [[ -f "$path" ]]; then
        pass "Required file exists: $path"
    else
        fail "Required file is missing: $path"
    fi
done

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 4 Step 1 validation stopped before contract evaluation.\n' >&2
    exit 1
fi

section "Exact Phase 4 Step 1 file boundaries"

if python3 <<'PY'
from pathlib import Path
import hashlib
import sys

checks = {
    'README.md': 'd3747d82147cc928fd07cb969854c5349dfab28271944e5fd97eafcebca3c422',
    'docs/README.md': 'dc2a7774fce8ad95f75c1c3177088f7eebaa728a3c908ac4cd22171fe9bd7997',
    'docs/architecture/README.md': '694007a42b60adf980e6147c7cfa8ff35002417cf0d4c70558c54d37a7a97600',
    'docs/goals/two-person-concept.md': 'b6132cb8742358dd663dd27af8e88b03080327cecf51c9aa9c915a0f78d02ab2',
    'docs/architecture/foundation/README.md': '43192273313789be3528e7d27a181e1052cc7035bf8b5c71851d406d81356826',
    'docs/architecture/foundation/approval-framework.md': 'a591c7568e9cc8d7e4060b34871dbb2145d217e48627c47979c9294e5d84d3a1',
    'docs/architecture/foundation/authority-and-authorization-model.md': 'a7ed63bfb56be17dc539a53522712472072312a6bb58a0943728e16d526f89e8',
    'docs/architecture/foundation/authorization-evaluation-contract.md': '4f947845430565beff12609dcfc2ffc46bbf422d5828329b17216b40894f1f33',
    'docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md': 'a509d83786e632479190719be97800b1b8d404bd67fdf5b3659cf7362b2cd212',
    'docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md': 'b89c8bc7280d5226ad67f3be7081a10b3b392679ea3ef5157e47d7a13166cf44',
    'docs/architecture/foundation/sql-migration-map.md': 'c71e12148b201bf420f242a91afbaa1873b974ad89060a344a46605cb90da817',
    'tools/validation/README.md': '4030e230fc1b984a5038d9a4684ed00dc49249fed32b122c8695d458f53d691f',
    'tools/validation/phase-gates/README.md': '5b95186005cb41084086b4465866c97e90a04dd22c58800c22e86db674d94ed9',
}

failures = []

for raw_path, expected in checks.items():
    path = Path(raw_path)
    actual = hashlib.sha256(path.read_bytes()).hexdigest()

    if actual == expected:
        print(f"EXACT FILE PASS: {path}")
    else:
        failures.append(
            f"{path} sha256={actual} expected={expected}"
        )

if failures:
    for failure in failures:
        print(f"EXACT FILE FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then
    PASS_COUNT=$((PASS_COUNT + 13))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Phase 4 contract boundary"

if python3 <<'PY'
from pathlib import Path
import re
import sys

checks = [
    (
        Path("README.md"),
        "Phase 4 — Approval Independence and Separation of Duties",
    ),
    (
        Path("docs/README.md"),
        "Phase 4 Step 1",
    ),
    (
        Path("docs/architecture/README.md"),
        "083_postgresql_approval_independence_and_separation_of_duties.sql",
    ),
    (
        Path("docs/goals/two-person-concept.md"),
        "Different accounts, sessions, devices, roles, organizations, or delegated grants do not make one identity count as two people.",
    ),
    (
        Path("docs/architecture/foundation/README.md"),
        "Current Phase 4 Boundary",
    ),
    (
        Path("docs/architecture/foundation/approval-framework.md"),
        "Approval Action Record",
    ),
    (
        Path("docs/architecture/foundation/authority-and-authorization-model.md"),
        "JOINT_EXERCISE",
    ),
    (
        Path("docs/architecture/foundation/authorization-evaluation-contract.md"),
        "Active architecture phase",
    ),
    (
        Path("docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md"),
        "supporting-record reference",
    ),
    (
        Path("docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md"),
        "Normative Phase 4 contract; implementation has not started",
    ),
    (
        Path("docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md"),
        "Eligibility and independence are separate evaluations.",
    ),
    (
        Path("docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md"),
        "effective_actor_identity_id = acting_identity_id",
    ),
    (
        Path("docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md"),
        "Directly Affected Identity",
    ),
    (
        Path("docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md"),
        "Circular and Reciprocal Approval",
    ),
    (
        Path("docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md"),
        "CONCURRENT_HOLDING",
    ),
    (
        Path("docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md"),
        "A query that merely counts `APPROVE` rows is not a valid stage evaluation.",
    ),
    (
        Path("docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md"),
        "Approval Request finalization is once-only.",
    ),
    (
        Path("docs/architecture/foundation/sql-migration-map.md"),
        "Planned Step 2 Migration",
    ),
    (
        Path("tools/validation/README.md"),
        "validate_phase4_step1.sh",
    ),
    (
        Path("tools/validation/phase-gates/README.md"),
        "validate_phase4_step1.sh",
    ),
]

def normalize(value: str) -> str:
    value = re.sub(r"[`*>]", "", value)
    return re.sub(r"\s+", " ", value).strip()

failures = []

for path, marker in checks:
    text = path.read_text(encoding="utf-8")

    if normalize(marker) in normalize(text):
        print(f"DOCUMENTATION CHECK PASS: {path} | {marker}")
    else:
        failures.append(f"{path} missing marker: {marker}")

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

section "Terminology discipline"

if python3 - "${phase4_files[@]}" <<'PY'
from pathlib import Path
import re
import sys

patterns = [
    (
        re.compile(
            r"append(?:-|\s+)(?:only|oriented)\s+evidence",
            re.IGNORECASE,
        ),
        "broad append-only evidence phrase",
    ),
    (
        re.compile(r"\bapproval\s+evidence\b", re.IGNORECASE),
        "unqualified approval evidence phrase",
    ),
    (
        re.compile(r"\bsupporting\s+evidence\b", re.IGNORECASE),
        "unqualified supporting evidence phrase",
    ),
]

failures = []

for raw in sys.argv[1:]:
    path = Path(raw)

    if path.suffix != ".md":
        continue

    text = path.read_text(encoding="utf-8")

    for pattern, label in patterns:
        for match in pattern.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            failures.append(f"{path}:{line}: {label}")

if failures:
    for failure in failures:
        print(f"TERMINOLOGY FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

print(
    "TERMINOLOGY PASS: active Phase 4 files use exact record-type terms"
)
PY
then
    pass "Phase 4 terminology boundary is precise"
else
    fail "Phase 4 terminology boundary failed"
fi

section "Step 1 no-SQL boundary"

planned_migration="migrations/foundation/083_postgresql_approval_independence_and_separation_of_duties.sql"
planned_migration_file="sql/schema/${planned_migration}"
planned_test="foundation/170_approval_independence_and_separation_of_duties_structure.sql"
planned_test_file="test-framework/sql/tests/${planned_test}"

if grep -Fxq "$planned_migration" sql/schema/manifests/foundation.manifest; then
    fail "Planned migration 083 must not be in the Step 1 manifest"
else
    pass "Planned migration 083 is not in the Step 1 manifest"
fi

if [[ -e "$planned_migration_file" ]]; then
    fail "Planned migration 083 must not exist during Step 1"
else
    pass "Planned migration 083 does not exist during Step 1"
fi

if grep -Fxq "$planned_test" test-framework/sql/tests/foundation-tests.manifest; then
    fail "Planned structural test 170 must not be in the Step 1 manifest"
else
    pass "Planned structural test 170 is not in the Step 1 manifest"
fi

if [[ -e "$planned_test_file" ]]; then
    fail "Planned structural test 170 must not exist during Step 1"
else
    pass "Planned structural test 170 does not exist during Step 1"
fi

sequential_count="$(
    grep -Ev '^[[:space:]]*(#|$)' \
        test-framework/sql/tests/foundation-tests.manifest |
        wc -l |
        awk '{print $1}'
)"

concurrency_count="$(
    grep -Ev '^[[:space:]]*(#|$)' \
        test-framework/sql/tests/foundation-concurrency-tests.manifest |
        wc -l |
        awk '{print $1}'
)"

if [[ "$sequential_count" == "16" ]]; then
    pass "Sequential test manifest remains at 16 files"
else
    fail "Sequential test manifest count is $sequential_count; expected 16"
fi

if [[ "$concurrency_count" == "9" ]]; then
    pass "Concurrency test manifest remains at 9 files"
else
    fail "Concurrency test manifest count is $concurrency_count; expected 9"
fi

section "Shell and file hygiene"

if bash -n "$runner"; then
    pass "Foundation runner shell syntax is valid"
else
    fail "Foundation runner shell syntax is invalid"
fi

if bash -n "$previous_validator"; then
    pass "Phase 3 Step 7 validator shell syntax is valid"
else
    fail "Phase 3 Step 7 validator shell syntax is invalid"
fi

if bash -n "$validator_file"; then
    pass "Phase 4 Step 1 validator shell syntax is valid"
else
    fail "Phase 4 Step 1 validator shell syntax is invalid"
fi

if python3 - "${phase4_files[@]}" <<'PY'
from pathlib import Path
import sys

failures = []

for raw in sys.argv[1:]:
    path = Path(raw)
    data = path.read_bytes()

    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        failures.append(f"{path} invalid UTF-8: {exc}")
        continue

    if b"\r\n" in data:
        failures.append(f"{path} has CRLF line endings")

    if not data.endswith(b"\n"):
        failures.append(f"{path} lacks one EOF newline")
    elif data.endswith(b"\n\n"):
        failures.append(f"{path} has an extra blank line at EOF")

    for number, line in enumerate(text.splitlines(), 1):
        if line.endswith((" ", "\t")):
            failures.append(f"{path}:{number} trailing whitespace")

        if line.startswith(("<<<<<<<", "=======", ">>>>>>>")):
            failures.append(f"{path}:{number} conflict marker")

if failures:
    for failure in failures:
        print(f"FILE HYGIENE FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

print("FILE HYGIENE PASS: Phase 4 Step 1 files are clean UTF-8 text")
PY
then
    pass "All Phase 4 Step 1 files pass direct hygiene checks"
else
    fail "A Phase 4 Step 1 file failed direct hygiene checks"
fi

if git diff --check -- "${phase4_files[@]}" >/dev/null; then
    pass "Phase 4 Step 1 project files pass git diff --check"
else
    fail "Phase 4 Step 1 project files fail git diff --check"
fi

section "Static result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 4 Step 1 static validation FAILED.\n' >&2
    printf 'No PostgreSQL test was started.\n' >&2
    exit 1
fi

printf '\nPhase 4 Step 1 static validation PASSED.\n'

if (( STATIC_ONLY == 1 )); then
    printf 'PostgreSQL execution was skipped by --static-only.\n'
    exit 0
fi

section "Complete accepted Foundation PostgreSQL suite"

"$runner"

summary="test-framework/sql/test-results/latest-summary.txt"

if [[ ! -f "$summary" ]]; then
    printf 'Foundation runner did not create %s\n' "$summary" >&2
    exit 1
fi

if python3 - "$summary" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
failures = []

checks = {
    "Overall result": r"(?m)^Overall result:[ \t]+PASS[ \t]*$",
    "Runner exit status": r"(?m)^Runner exit status:[ \t]+0[ \t]*$",
    "Sequential test files": r"(?m)^Sequential test files:[ \t]+16[ \t]*$",
    "Concurrency test files": r"(?m)^Concurrency test files:[ \t]+9[ \t]*$",
}

for label, pattern in checks.items():
    if re.search(pattern, text) is None:
        failures.append(f"incorrect {label}")

result_section = re.search(
    r"Result[ ]totals(?P<section>.*?)Failed[ ]assertions",
    text,
    re.DOTALL,
)

if result_section is None:
    failures.append("missing Result totals")
else:
    expected = {
        "PASS": 408,
        "WARN": 3,
        "FAIL": 0,
    }

    for result, expected_count in expected.items():
        match = re.search(
            rf"\|[ \t]*{result}[ \t]*\|[ \t]*(\d+)[ \t]*\|",
            result_section.group("section"),
        )

        actual = (
            0
            if match is None and result == "FAIL"
            else (None if match is None else int(match.group(1)))
        )

        if actual != expected_count:
            failures.append(
                f"{result}={actual} expected={expected_count}"
            )

migration_section = re.search(
    r"Migration[ ]totals(?P<section>.*)",
    text,
    re.DOTALL,
)

if migration_section is None:
    failures.append("missing Migration totals")
else:
    match = re.search(
        r"\|[ \t]*(\d+)[ \t]*\|[ \t]*(\d+)[ \t]*\|",
        migration_section.group("section"),
    )

    if (
        match is None
        or (int(match.group(1)), int(match.group(2))) != (33, 33)
    ):
        failures.append(
            "manifest or registered migration count is not 33"
        )

if failures:
    for failure in failures:
        print(f"SUMMARY CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

for line in [
    "Overall result = PASS",
    "Runner exit status = 0",
    "Sequential test files = 16",
    "Concurrency test files = 9",
    "PASS = 408",
    "FAIL = 0",
    "WARN = 3",
    "Manifest migrations = 33",
    "Registered migrations = 33",
]:
    print(f"SUMMARY CHECK PASS: {line}")
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
    printf '\nPhase 4 Step 1 validation FAILED.\n' >&2
    printf 'Summary: %s\n' "$summary" >&2
    exit 1
fi

printf '\nPhase 4 Step 1 validation PASSED completely.\n'
printf 'The approval-independence and separation-of-duties contract is frozen.\n'
printf 'Phase 4 Step 2 may add the planned migration and structural test.\n'
