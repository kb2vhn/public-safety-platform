#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'EOF'
Usage: tools/validation/phase-gates/validate_phase3_step7.sh [--static-only]

Default:
  Validate the formal Phase 3 acceptance record and rerun the complete
  Foundation PostgreSQL suite.

Options:
  --static-only  Run static acceptance checks without PostgreSQL.
  -h, --help     Show this help text.
EOF
}

pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$*"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$*" >&2; }
section() { printf '\n== %s ==\n' "$*"; }

while (( $# > 0 )); do
    case "$1" in
        --static-only) STATIC_ONLY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 64 ;;
    esac
done

if (( BASH_VERSINFO[0] < 4 )); then
    printf 'Bash 4 or newer is required.\n' >&2
    printf 'Arch package: bash\n' >&2
    printf 'Install with: sudo pacman -S --needed bash\n' >&2
    exit 69
fi

declare -A COMMAND_PACKAGE_MAP=(
    [awk]="gawk" [bash]="bash" [cat]="coreutils"
    [createdb]="postgresql-libs" [date]="coreutils"
    [dirname]="coreutils" [dropdb]="postgresql-libs"
    [git]="git" [grep]="grep" [psql]="postgresql-libs"
    [python3]="python" [sha256sum]="coreutils"
    [uname]="coreutils"
)

required_commands=(
    awk bash cat createdb date dirname dropdb git grep psql python3
    sha256sum uname
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
        printf '  %-12s Arch package: %s\n'             "$command_name"             "${COMMAND_PACKAGE_MAP[$command_name]}" >&2
    done
    printf '\nInstall all missing packages with:\n\n' >&2
    printf '  sudo pacman -S --needed' >&2
    printf ' %s' "${missing_packages[@]}" >&2
    printf '\n\nNo repository file or database was modified.\n' >&2
    exit 69
fi
pass "All required Phase 3 Step 7 commands are available"

if ! repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'Run this validator from inside the repository.\n' >&2
    exit 66
fi
cd "$repository_root"

phase3_tag="phase-3-authorization-control-complete-v1"
phase3_commit="853d26e37f1471aeeaeea4e7690e1a0605a22870"
runner="test-framework/sql/schema/scripts/test_foundation.sh"
previous_validator="tools/validation/phase-gates/validate_phase3_step6.sh"
validator_file="tools/validation/phase-gates/validate_phase3_step7.sh"
acceptance_record="docs/architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md"

required_files=(
    "README.md"
    "docs/README.md"
    "docs/architecture/README.md"
    "docs/architecture/foundation/README.md"
    "docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md"
    "docs/architecture/foundation/authorization-evaluation-contract.md"
    "docs/architecture/foundation/sql-migration-map.md"
    "$acceptance_record"
    "tools/validation/README.md"
    "tools/validation/phase-gates/README.md"
    "$runner"
    "$previous_validator"
    "$validator_file"
)

section "Repository identity"
printf 'Repository root: %s\n' "$repository_root"
printf 'Host: %s\n' "$(uname -n)"
printf 'Operating system: %s\n' "$(uname -s)"
printf 'Current branch: %s\n' "$(git branch --show-current)"
printf 'Current commit: %s\n' "$(git rev-parse --short=12 HEAD)"

[[ "$(git branch --show-current)" == "dev" ]]     && pass "Current branch is dev"     || fail "Current branch must be dev"

[[ -z "$(git diff --name-only --diff-filter=U)" ]]     && pass "No unresolved Git conflicts"     || fail "Repository contains unresolved Git conflicts"

section "Formal Phase 3 acceptance tag"

[[ "$(git cat-file -t "refs/tags/${phase3_tag}" 2>/dev/null || true)" == "tag" ]]     && pass "Phase 3 acceptance tag is annotated"     || fail "Phase 3 acceptance tag is missing or not annotated"

[[ "$(git rev-parse "${phase3_tag}^{}" 2>/dev/null || true)" == "$phase3_commit" ]]     && pass "Phase 3 acceptance tag points to the accepted implementation commit"     || fail "Phase 3 acceptance tag points to the wrong commit"

if git merge-base --is-ancestor "$phase3_commit" HEAD; then
    pass "Current documentation commit descends from the accepted Phase 3 tag"
else
    fail "Current HEAD does not descend from the accepted Phase 3 tag"
fi

if git diff --quiet "$phase3_commit" -- sql/schema test-framework/sql; then
    pass "Current SQL and test tree matches the accepted Phase 3 tag"
else
    fail "Current SQL or test content differs from the accepted Phase 3 tag"
    git diff --name-status "$phase3_commit" --         sql/schema test-framework/sql >&2
fi

tag_message="$(git cat-file -p "refs/tags/${phase3_tag}" 2>/dev/null || true)"
for marker in     "33 migrations"     "16 sequential tests"     "9 concurrency tests"     "408 PASS"     "0 FAIL"     "3 understood WARN"
do
    if grep -Fq "$marker" <<<"$tag_message"; then
        pass "Acceptance tag message contains: $marker"
    else
        fail "Acceptance tag message is missing: $marker"
    fi
done

section "Required files"
for path in "${required_files[@]}"; do
    [[ -f "$path" ]]         && pass "Required file exists: $path"         || fail "Required file is missing: $path"
done

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 3 Step 7 validation stopped before database execution.\n' >&2
    exit 1
fi

section "Exact acceptance-document boundaries"
if python3 <<'PY'
from pathlib import Path
import hashlib
import sys

checks = {
    'README.md': '0ce782bd1a6d21b05465ab37c2e0ef900e1b4efb20395e859bdcc87d65928fa4',
    'docs/README.md': '789a9b59f258b70c45e2ecec39c3007939a4f799e53c9ab022c6b088bcd1377d',
    'docs/architecture/README.md': '8f3c41d63f98595094628c56dbbd0230ef4a997559193fc99520b54c65cd3bfd',
    'docs/architecture/foundation/README.md': 'a5c51e00f7372190c9a9bda440e6515fc139138e89bf52e7a0bfa79b89d32d5e',
    'docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md': 'ac69cfb15bda685f092c91a145c66dda1c139a9e3c057a613738415f992e2b44',
    'docs/architecture/foundation/authorization-evaluation-contract.md': '6e2176b39b4a90581dec3fb0db17a753e05c7e73441512165d6fe4b6dcc62880',
    'docs/architecture/foundation/sql-migration-map.md': 'b392d0be45b83d51da402421645c603442307ecfee87908be737240f7f9f1112',
    'docs/architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md': '5d69bcb8bd6e1b4c97784803419d0a3029e0aea460010931eae1998742550765',
    'tools/validation/README.md': '1b7cd715803a8514ca511d0f753c7dda047b3f032108b24ce71c0977a522d1d6',
    'tools/validation/phase-gates/README.md': '221f3482d139e02bf948600fb4f801a0fbc871623f6d74f5e97c3424ce9e58eb',
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
    PASS_COUNT=$((PASS_COUNT + 10))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Acceptance-record contract"
if python3 <<'PY'
from pathlib import Path
import re
import sys

checks = [
    (
        Path("docs/architecture/foundation/"
             "phase-3-authorization-decision-and-controlled-lease-acceptance.md"),
        "Phase 3 is accepted.",
    ),
    (Path("README.md"), "phase-3-authorization-control-complete-v1"),
    (Path("README.md"), "408 PASS"),
    (Path("docs/README.md"), "Phase 3 accepted"),
    (Path("docs/architecture/README.md"), "Phase 3 are accepted"),
    (Path("docs/architecture/foundation/README.md"), "Accepted Phase 3 Boundary"),
    (
        Path("docs/architecture/foundation/"
             "authorization-decision-and-lease-issuance-model.md"),
        "Normative Phase 3 contract; accepted",
    ),
    (
        Path("docs/architecture/foundation/"
             "authorization-evaluation-contract.md"),
        "Accepted implementation boundary",
    ),
    (
        Path("docs/architecture/foundation/sql-migration-map.md"),
        "Phase 3 Formal Acceptance",
    ),
    (
        Path("tools/validation/README.md"),
        "validate_phase3_step7.sh",
    ),
    (
        Path("tools/validation/phase-gates/README.md"),
        "validate_phase3_step7.sh",
    ),
]

failures = []

def normalize(value: str) -> str:
    value = re.sub(r"[`*>]", "", value)
    return re.sub(r"\s+", " ", value).strip()

for path, marker in checks:
    text = path.read_text(encoding="utf-8")
    if normalize(marker) in normalize(text):
        print(f"DOCUMENTATION CHECK PASS: {path}")
    else:
        failures.append(f"{path} missing marker: {marker}")

retired_markers = [
    "Current Phase 3 Step 6 candidate",
    "Step 6 concurrency-proof candidate",
    "Formal Phase 3 acceptance and tagging remain",
    "Formal Phase 3 acceptance remains",
]

for path in [
    Path("README.md"),
    Path("docs/README.md"),
    Path("docs/architecture/README.md"),
    Path("docs/architecture/foundation/README.md"),
    Path("docs/architecture/foundation/"
         "authorization-decision-and-lease-issuance-model.md"),
    Path("docs/architecture/foundation/"
         "authorization-evaluation-contract.md"),
    Path("docs/architecture/foundation/sql-migration-map.md"),
]:
    text = path.read_text(encoding="utf-8")
    for marker in retired_markers:
        if marker in text:
            failures.append(f"{path} retains stale marker: {marker}")
    if "github.com/kb2vhn/iron-signal-platform" in text:
        failures.append(f"{path} contains retired personal repository URL")

if failures:
    for failure in failures:
        print(f"DOCUMENTATION CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then
    PASS_COUNT=$((PASS_COUNT + 11))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Shell and file hygiene"

if bash -n "$runner"; then
    pass "Foundation runner shell syntax is valid"
else
    fail "Foundation runner shell syntax is invalid"
fi

if bash -n "$previous_validator"; then
    pass "Accepted Phase 3 Step 6 validator shell syntax is valid"
else
    fail "Accepted Phase 3 Step 6 validator shell syntax is invalid"
fi

if bash -n "$validator_file"; then
    pass "Phase 3 Step 7 validator shell syntax is valid"
else
    fail "Phase 3 Step 7 validator shell syntax is invalid"
fi

if python3 - "${required_files[@]}" <<'PY'
from pathlib import Path
import sys

failures = []

for raw in sys.argv[1:]:
    path = Path(raw)
    if path.name == "test_foundation.sh":
        continue

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

print("FILE HYGIENE PASS: Phase 3 Step 7 files are clean UTF-8 text")
PY
then
    pass "All Phase 3 Step 7 files pass direct hygiene checks"
else
    fail "A Phase 3 Step 7 file failed direct hygiene checks"
fi

if git diff --check -- "${required_files[@]}" >/dev/null; then
    pass "Phase 3 Step 7 project files pass git diff --check"
else
    fail "Phase 3 Step 7 project files fail git diff --check"
fi

section "Static result"
printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 3 Step 7 static validation FAILED.\n' >&2
    printf 'No PostgreSQL test was started.\n' >&2
    exit 1
fi

printf '\nPhase 3 Step 7 static validation PASSED.\n'

if (( STATIC_ONLY == 1 )); then
    printf 'PostgreSQL execution was skipped by --static-only.\n'
    exit 0
fi

section "Complete Foundation PostgreSQL suite"
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
    expected = {"PASS": 408, "WARN": 3, "FAIL": 0}
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
    printf '\nPhase 3 Step 7 validation FAILED.\n' >&2
    printf 'Summary: %s\n' "$summary" >&2
    exit 1
fi

printf '\nPhase 3 Step 7 validation PASSED completely.\n'
printf 'The formal Phase 3 acceptance record matches the annotated accepted tree.\n'
printf 'Phase 4 architecture may begin without changing the accepted Phase 3 boundary.\n'
