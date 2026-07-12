#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'EOF'
Usage: tools/validation/phase-gates/validate_phase3_step4.sh [--static-only]

Default:
  Validate Phase 3 Step 4 and run the complete Foundation PostgreSQL suite.

Options:
  --static-only  Run static checks without PostgreSQL.
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
    [dropdb]="postgresql-libs"
    [git]="git"
    [grep]="grep"
    [mkdir]="coreutils"
    [mktemp]="coreutils"
    [psql]="postgresql-libs"
    [python3]="python"
    [rm]="coreutils"
    [sed]="sed"
    [sha256sum]="coreutils"
    [sort]="coreutils"
    [tee]="coreutils"
    [uname]="coreutils"
    [wc]="coreutils"
)

required_commands=(
    awk bash cat createdb date dropdb git grep mkdir mktemp psql python3 rm
    sed sha256sum sort tee uname wc
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
            "$command_name" "${COMMAND_PACKAGE_MAP[$command_name]}" >&2
    done
    printf '\nInstall all missing packages with:\n\n' >&2
    printf '  sudo pacman -S --needed' >&2
    printf ' %s' "${missing_packages[@]}" >&2
    printf '\n\nNo repository file or database was modified.\n' >&2
    exit 69
fi

pass "All required Phase 3 Step 4 commands are available"

if ! repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'Run this validator from inside the repository.\n' >&2
    exit 66
fi

cd "$repository_root"

phase2_tag="phase-2-session-control-complete-v1"
phase2_commit="76c7883c9e04cc320c0b133f86fe3c0d9dbbc63b"

migration_081="sql/schema/migrations/foundation/081_postgresql_authorization_decision_and_lease_issuance.sql"
foundation_manifest="sql/schema/manifests/foundation.manifest"
structure_test="test-framework/sql/tests/foundation/130_authorization_decision_and_lease_structure.sql"
test_file="test-framework/sql/tests/foundation/150_authorization_lease_issuance_and_use.sql"
test_manifest="test-framework/sql/tests/foundation-tests.manifest"
concurrency_manifest="test-framework/sql/tests/foundation-concurrency-tests.manifest"
runner="test-framework/sql/schema/scripts/test_foundation.sh"
model="docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md"
foundation_readme="docs/architecture/foundation/README.md"
contract="docs/architecture/foundation/authorization-evaluation-contract.md"
migration_map="docs/architecture/foundation/sql-migration-map.md"
root_readme="README.md"
docs_readme="docs/README.md"
architecture_readme="docs/architecture/README.md"
tools_readme="tools/README.md"
validation_readme="tools/validation/README.md"
phase_gates_readme="tools/validation/phase-gates/README.md"
previous_validator="tools/validation/phase-gates/validate_phase3_step3.sh"
validator_file="tools/validation/phase-gates/validate_phase3_step4.sh"

required_files=(
    "$migration_081"
    "$foundation_manifest"
    "$structure_test"
    "$test_file"
    "$test_manifest"
    "$concurrency_manifest"
    "$runner"
    "$model"
    "$foundation_readme"
    "$contract"
    "$migration_map"
    "$root_readme"
    "$docs_readme"
    "$architecture_readme"
    "$tools_readme"
    "$validation_readme"
    "$phase_gates_readme"
    "$previous_validator"
    "$validator_file"
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

section "Accepted Phase 2 boundary"

if [[ "$(git cat-file -t "refs/tags/${phase2_tag}" 2>/dev/null || true)" == "tag" ]]; then
    pass "Phase 2 acceptance tag is annotated"
else
    fail "Phase 2 acceptance tag is missing or not annotated"
fi

if [[ "$(git rev-parse "${phase2_tag}^{}" 2>/dev/null || true)" == "$phase2_commit" ]]; then
    pass "Phase 2 acceptance tag points to the accepted commit"
else
    fail "Phase 2 acceptance tag points to the wrong commit"
fi

if python3 - "$phase2_commit" <<'PY'
from __future__ import annotations

import subprocess
import sys

phase2_commit = sys.argv[1]
allowed = {
    "sql/schema/manifests/foundation.manifest",
    "sql/schema/migrations/foundation/081_postgresql_authorization_decision_and_lease_issuance.sql",
    "test-framework/sql/tests/foundation-tests.manifest",
    "test-framework/sql/tests/foundation/130_authorization_decision_and_lease_structure.sql",
    "test-framework/sql/tests/foundation/140_authorization_policy_selection_and_decision_finalization.sql",
    "test-framework/sql/tests/foundation/150_authorization_lease_issuance_and_use.sql",
}

result = subprocess.run(
    [
        "git", "diff", "--name-only", phase2_commit, "--",
        "sql/schema", "test-framework/sql",
    ],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
)

actual = {line for line in result.stdout.splitlines() if line}

if actual != allowed:
    print("ACCEPTED BOUNDARY FAIL:", file=sys.stderr)
    print(f"expected={sorted(allowed)}", file=sys.stderr)
    print(f"actual={sorted(actual)}", file=sys.stderr)
    raise SystemExit(1)

print("ACCEPTED BOUNDARY PASS: only approved Phase 3 SQL/test paths differ")
PY
then
    pass "Accepted Phase 2 SQL and test content is preserved"
else
    fail "Unexpected SQL or test content differs from accepted Phase 2"
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
    printf '\nPhase 3 Step 4 validation stopped before database execution.\n' >&2
    exit 1
fi

section "Exact Step 4 file boundaries"

if python3 <<'PY'
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

checks = {
    'sql/schema/migrations/foundation/081_postgresql_authorization_decision_and_lease_issuance.sql': 'e788b9a28b6e2d107728e45490b838888375d617f5276edd6f13219739b2bf52',
    'sql/schema/manifests/foundation.manifest': 'a20ae81980e72b715ff1974017db6acc2e14356e752a18d59d3203cc1b8e8a02',
    'test-framework/sql/tests/foundation/130_authorization_decision_and_lease_structure.sql': 'b0549e8b48307d121289e3ace064354a621ea654ed15bc2b29e110dca7de060a',
    'test-framework/sql/tests/foundation/150_authorization_lease_issuance_and_use.sql': '2a53629be749b7c3c51fd7296b7c19e60b9eacde67c20fb9868ecc874156af27',
    'test-framework/sql/tests/foundation-tests.manifest': '864f0fe0b51f6a7ea226e2541d675d8aa69b3be9a3ee35e35280c2eb73586ed1',
    'docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md': '741eed7d6949c03da6acbc02d577ea97c9590fc7d29ae7c07a34857792255233',
    'docs/architecture/foundation/README.md': 'c5c5e45c3e95460a35cfb9acf92bad2ab58f7f2ef0e433e1a805295316806f8a',
    'docs/architecture/foundation/authorization-evaluation-contract.md': 'be0733ee7caeb1abd4e7b0fa44932854a1971d0466061f1f2a7c9ac04f37b08d',
    'docs/architecture/foundation/sql-migration-map.md': 'cf1ecac1a96a8aa15e7a287107efbf71e3fe122a90ed0cdda66504e24b31c169',
    'README.md': '7fbde55d3bc588f377976532ea951898bea3d5cb5965494f4d3875265f1b8537',
    'docs/README.md': 'f15ee5e5d88bf0b190bb827326a3ad8d912432812e7a684e541f3576625183fa',
    'docs/architecture/README.md': '971a17ac569140610b6b35503a0f9db1e3fc9b84504324508efb6bb97e8532a3',
    'tools/README.md': '3cc5ad24c4d7e11f726dbd99cff29ce3267900c83ef2cc77cb7bd90e2f5b9f11',
    'tools/validation/README.md': 'e65545cb1b3f842a73eecb0e545ee461a8e4550207901ca0d4aa75e8faeb637b',
    'tools/validation/phase-gates/README.md': '439c35d77ee74dc45fe14152cbf2b8cacd9af4bb9be01db41261f49b5dfa9bea',
}
failures = []

for raw_path, expected in checks.items():
    path = Path(raw_path)
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual == expected:
        print(f"EXACT FILE PASS: {raw_path}")
    else:
        failures.append(
            f"{raw_path} expected={expected} actual={actual}"
        )

if failures:
    for failure in failures:
        print(f"EXACT FILE FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then
    PASS_COUNT=$((PASS_COUNT + 15))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Manifest boundaries"

if python3 - "$foundation_manifest" "$test_manifest" "$concurrency_manifest" <<'PY'
from pathlib import Path
import sys

def entries(path: str) -> list[str]:
    return [
        line.strip()
        for line in Path(path).read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]

migrations = entries(sys.argv[1])
sequential = entries(sys.argv[2])
concurrency = entries(sys.argv[3])
failures = []

if len(migrations) != 33:
    failures.append(f"migrations={len(migrations)} expected=33")

if migrations[16] != (
    "migrations/foundation/"
    "081_postgresql_authorization_decision_and_lease_issuance.sql"
):
    failures.append("migration 081 is not immediately after 080")

if len(sequential) != 15:
    failures.append(f"sequential={len(sequential)} expected=15")

if sequential[-3:] != [
    "foundation/130_authorization_decision_and_lease_structure.sql",
    "foundation/140_authorization_policy_selection_and_decision_finalization.sql",
    "foundation/150_authorization_lease_issuance_and_use.sql",
]:
    failures.append("Phase 3 Step 2 through Step 4 tests are not the final ordered entries")

if len(concurrency) != 4:
    failures.append(f"concurrency={len(concurrency)} expected=4")

if len(set(migrations)) != len(migrations):
    failures.append("duplicate migration manifest entry")

if len(set(sequential)) != len(sequential):
    failures.append("duplicate sequential manifest entry")

if failures:
    for failure in failures:
        print(f"MANIFEST CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

print("MANIFEST CHECK PASS: migrations = 33")
print("MANIFEST CHECK PASS: sequential tests = 15")
print("MANIFEST CHECK PASS: concurrency tests = 4")
print("MANIFEST CHECK PASS: Step 4 test is final")
PY
then
    PASS_COUNT=$((PASS_COUNT + 4))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Controlled lease routine boundary"

if python3 - "$migration_081" "$test_file" <<'PY'
from __future__ import annotations
import re
import sys
from pathlib import Path

migration = Path(sys.argv[1]).read_text(encoding="utf-8")
test = Path(sys.argv[2]).read_text(encoding="utf-8")
routines = [
    "issue_authorization_lease_from_decision",
    "authorization_lease_context_is_usable",
    "consume_authorization_lease",
    "expire_authorization_lease",
    "revoke_lease",
]
failures = []
for routine in routines:
    if re.search(rf"CREATE(?: OR REPLACE)? FUNCTION\s+access_control\.{routine}\s*\(", migration, re.I):
        print(f"ROUTINE CHECK PASS: access_control.{routine}")
    else:
        failures.append(f"missing access_control.{routine}")
    if re.search(rf"COMMENT ON FUNCTION(?:\s+access_control\.{routine}|\s*\n\s*access_control\.{routine})\s*\(", migration, re.I):
        print(f"COMMENT CHECK PASS: access_control.{routine}")
    else:
        failures.append(f"missing COMMENT for access_control.{routine}")
    if re.search(rf"REVOKE ALL ON FUNCTION(?:\s+access_control\.{routine}|\s*\n\s*access_control\.{routine})\s*\(", migration, re.I):
        print(f"REVOKE CHECK PASS: access_control.{routine}")
    else:
        failures.append(f"missing PUBLIC revoke for access_control.{routine}")
if "SECURITY DEFINER" in migration.upper():
    failures.append("migration unexpectedly contains SECURITY DEFINER")
else:
    print("ROUTINE SECURITY PASS: no SECURITY DEFINER")
assertion_count = len(re.findall(r"SELECT\s+sql_test\.assert_(?:true|raises)\s*\(", test, re.I))
if assertion_count == 32:
    print("TEST ASSERTION COUNT PASS: 32")
else:
    failures.append(f"Step 4 test assertions={assertion_count} expected=32")
for marker in [
    "v_decision.record_status <> 'FINALIZED'",
    "v_decision.final_result <> 'ALLOW'",
    "v_decision.authorization_lease_id IS NOT NULL",
    "session_context_is_locally_usable",
    "lease.lease_audience = p_lease_audience",
    "authorization_lease_use_events",
    "use_decision.authorization_lease_id =",
    "use_decision.request_id = p_request_id",
    "supporting.required_for_result",
]:
    if marker not in migration:
        failures.append(f"missing fail-closed marker: {marker}")
    else:
        print(f"FAIL-CLOSED MARKER PASS: {marker}")
if failures:
    for failure in failures:
        print(f"ROUTINE BOUNDARY FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then
    PASS_COUNT=$((PASS_COUNT + 25))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Documentation ownership, layout, and file hygiene"

if python3 - "$model" "$foundation_readme" "$contract" "$migration_map" "$root_readme" "$docs_readme" "$architecture_readme" "$tools_readme" "$validation_readme" "$phase_gates_readme" <<'PY'
from pathlib import Path
import re
import sys
checks = [
    (Path(sys.argv[1]), "Step 4 controlled lease-issuance and use implementation candidate"),
    (Path(sys.argv[1]), "150_authorization_lease_issuance_and_use.sql"),
    (Path(sys.argv[2]), "validate_phase3_step4.sh"),
    (Path(sys.argv[3]), "issue_authorization_lease_from_decision"),
    (Path(sys.argv[4]), "Phase 3 Step 4 Result Target"),
    (Path(sys.argv[4]), "329 PASS"),
    (Path(sys.argv[5]), "An Iron Signal Systems project"),
    (Path(sys.argv[5]), "tools/validation/phase-gates/"),
    (Path(sys.argv[6]), "Owner: Iron Signal Systems"),
    (Path(sys.argv[7]), "Owner: Iron Signal Systems"),
    (Path(sys.argv[8]), "Owner: Iron Signal Systems"),
    (Path(sys.argv[9]), "Owner: Iron Signal Systems"),
    (Path(sys.argv[10]), "Owner: Iron Signal Systems"),
    (Path(sys.argv[9]), "validate_phase3_step4.sh"),
    (Path(sys.argv[10]), "validate_phase3_step4.sh"),
]
def normalize(value: str) -> str:
    value = re.sub(r"[`*>]", "", value)
    return re.sub(r"\s+", " ", value).strip()
failures=[]
for path, marker in checks:
    if normalize(marker) in normalize(path.read_text(encoding="utf-8")):
        print(f"DOCUMENTATION CHECK PASS: {path}")
    else:
        failures.append(f"{path} missing marker: {marker}")
for path in Path('.').rglob('*.md'):
    text = path.read_text(encoding="utf-8")
    if "github.com/kb2vhn/public-safety-platform" in text:
        failures.append(f"{path} contains the retired personal repository URL")
    if "git@github.com:kb2vhn/public-safety-platform.git" in text:
        failures.append(f"{path} contains the retired personal Git remote")
    if re.search(r"(?m)^\s*\./validate_phase[0-9_]", text):
        failures.append(f"{path} contains an obsolete root-level phase-gate command")
if failures:
    for failure in failures:
        print(f"DOCUMENTATION CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then
    PASS_COUNT=$((PASS_COUNT + 15))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if bash -n "$runner"; then
    pass "Foundation runner shell syntax is valid"
else
    fail "Foundation runner shell syntax is invalid"
fi

if bash -n "$previous_validator"; then
    pass "Relocated Phase 3 Step 3 validator shell syntax is valid"
else
    fail "Relocated Phase 3 Step 3 validator shell syntax is invalid"
fi

if bash -n "$validator_file"; then
    pass "Phase 3 Step 4 validator shell syntax is valid"
else
    fail "Phase 3 Step 4 validator shell syntax is invalid"
fi

if python3 - \
    "$migration_081" "$foundation_manifest" "$structure_test" "$test_file" "$test_manifest" \
    "$model" "$foundation_readme" "$contract" "$migration_map" \
    "$root_readme" "$docs_readme" "$architecture_readme" "$tools_readme" \
    "$validation_readme" "$phase_gates_readme" "$validator_file" <<'PY'
from pathlib import Path
import sys

failures = []

for raw_path in sys.argv[1:]:
    path = Path(raw_path)
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

    for number, line in enumerate(text.splitlines(), start=1):
        if line.endswith((" ", "\t")):
            failures.append(f"{path}:{number} trailing whitespace")
        if line.startswith(("<<<<<<<", "=======", ">>>>>>>")):
            failures.append(f"{path}:{number} conflict marker")

if failures:
    for failure in failures:
        print(f"FILE HYGIENE FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

print("FILE HYGIENE PASS: all Step 4 files are clean UTF-8 text")
PY
then
    pass "All Phase 3 Step 4 files pass direct hygiene checks"
else
    fail "A Phase 3 Step 4 file failed direct hygiene checks"
fi

if git diff --check -- \
    "$migration_081" "$foundation_manifest" "$structure_test" "$test_file" "$test_manifest" \
    "$model" "$foundation_readme" "$contract" "$migration_map" \
    "$root_readme" "$docs_readme" "$architecture_readme" "$tools_readme" \
    "$validation_readme" "$phase_gates_readme" "$validator_file" >/dev/null; then
    pass "Step 4 project files pass git diff --check"
else
    fail "Step 4 project files fail git diff --check"
fi

section "Static result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 3 Step 4 static validation FAILED.\n' >&2
    printf 'No PostgreSQL test was started.\n' >&2
    exit 1
fi

printf '\nPhase 3 Step 4 static validation PASSED.\n'

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
    "Sequential test files": r"(?m)^Sequential test files:[ \t]+15[ \t]*$",
    "Concurrency test files": r"(?m)^Concurrency test files:[ \t]+4[ \t]*$",
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
    section = result_section.group("section")
    expected = {"PASS": 329, "WARN": 3, "FAIL": 0}
    for result, expected_count in expected.items():
        match = re.search(
            rf"\|[ \t]*{result}[ \t]*\|[ \t]*(\d+)[ \t]*\|",
            section,
        )
        actual = 0 if match is None and result == "FAIL" else (
            None if match is None else int(match.group(1))
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
    if match is None:
        failures.append("could not parse Migration totals")
    elif (int(match.group(1)), int(match.group(2))) != (33, 33):
        failures.append(
            "manifest or registered migration count is not 33"
        )

if failures:
    for failure in failures:
        print(f"SUMMARY CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

print("SUMMARY CHECK PASS: Overall result = PASS")
print("SUMMARY CHECK PASS: Runner exit status = 0")
print("SUMMARY CHECK PASS: Sequential test files = 15")
print("SUMMARY CHECK PASS: Concurrency test files = 4")
print("SUMMARY CHECK PASS: PASS = 329")
print("SUMMARY CHECK PASS: FAIL = 0")
print("SUMMARY CHECK PASS: WARN = 3")
print("SUMMARY CHECK PASS: Manifest migrations = 33")
print("SUMMARY CHECK PASS: Registered migrations = 33")
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
    printf '\nPhase 3 Step 4 validation FAILED.\n' >&2
    printf 'Summary: %s\n' "$summary" >&2
    exit 1
fi

printf '\nPhase 3 Step 4 validation PASSED completely.\n'
printf 'Controlled Authorization Lease issuance and use are ready for Phase 3 Step 5 behavioral expansion and Step 6 concurrency proof.\n'
