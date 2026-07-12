#!/usr/bin/env bash
#
# validate_phase3_step2.sh
#
# Authoritative Phase 3 Step 2 validator.
#
# Default behavior:
#   - Performs complete dependency and repository preflight.
#   - Verifies the accepted Phase 2 tag and preserves its SQL/test content.
#   - Validates migration 081, both manifests, the structural test, and docs.
#   - Runs the complete Foundation clean-install, sequential, and concurrency
#     suite through the existing authoritative runner.
#   - Requires 33 migrations, 13 sequential tests, 4 concurrency tests,
#     273 PASS, 0 FAIL, and 3 understood WARN results.
#
# Use --static-only only for a deliberate file check without PostgreSQL.
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
  Validate Phase 3 Step 2 and run the complete Foundation PostgreSQL suite.

Options:
  --static-only
      Run dependency, repository, accepted-boundary, exact-file, manifest,
      migration, documentation, shell, and file-hygiene checks without
      connecting to PostgreSQL.

  -h, --help
      Show this help text.

The existing Foundation runner uses PGHOST, PGPORT, PGUSER, PGPASSWORD,
PGSSLMODE, PGMAINTENANCE_DB, KEEP_TEST_DB, DROP_TEST_DB_ON_FAILURE, and
TEST_DATABASE_NAME when supplied.
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
    [bash]="bash"
    [basename]="coreutils"
    [cat]="coreutils"
    [date]="coreutils"
    [dirname]="coreutils"
    [git]="git"
    [grep]="grep"
    [ln]="coreutils"
    [mkdir]="coreutils"
    [mktemp]="coreutils"
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
    awk bash basename cat date dirname git grep ln mkdir mktemp python3 rm sed
    sha256sum sleep sort tee uname uniq wc
)

if (( STATIC_ONLY == 0 )); then
    COMMAND_PACKAGE_MAP[createdb]="postgresql-libs"
    COMMAND_PACKAGE_MAP[dropdb]="postgresql-libs"
    COMMAND_PACKAGE_MAP[psql]="postgresql-libs"
    required_commands+=(createdb dropdb psql)
fi

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
    printf '\n\nWhen operating as root without sudo:\n\n' >&2
    printf '  pacman -S --needed' >&2
    printf ' %s' "${missing_packages[@]}" >&2
    printf '\n\nNo repository file or database was modified.\n' >&2
    exit 69
fi

pass "All required Phase 3 Step 2 commands are available"

if ! repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'The validator must be run from inside the repository.\n' >&2
    exit 66
fi

cd "$repository_root"

phase2_tag="phase-2-session-control-complete-v1"
phase2_commit="76c7883c9e04cc320c0b133f86fe3c0d9dbbc63b"

migration_081="sql/schema/migrations/foundation/081_postgresql_authorization_decision_and_lease_issuance.sql"
manifest="sql/schema/manifests/foundation.manifest"
test_file="test-framework/sql/tests/foundation/130_authorization_decision_and_lease_structure.sql"
test_manifest="test-framework/sql/tests/foundation-tests.manifest"
concurrency_manifest="test-framework/sql/tests/foundation-concurrency-tests.manifest"
runner="test-framework/sql/schema/scripts/test_foundation.sh"
model="docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md"
foundation_readme="docs/architecture/foundation/README.md"
contract="docs/architecture/foundation/authorization-evaluation-contract.md"
migration_map="docs/architecture/foundation/sql-migration-map.md"
validator_file="validate_phase3_step2.sh"

required_files=(
    "$migration_081"
    "$manifest"
    "$test_file"
    "$test_manifest"
    "$concurrency_manifest"
    "$runner"
    "$model"
    "$foundation_readme"
    "$contract"
    "$migration_map"
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

if tag_type="$(git cat-file -t "refs/tags/${phase2_tag}" 2>/dev/null)"; then
    if [[ "$tag_type" == "tag" ]]; then
        pass "Phase 2 acceptance tag is annotated"
    else
        fail "Phase 2 acceptance tag must be annotated"
    fi
else
    fail "Phase 2 acceptance tag is missing locally"
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
    fail "Could not resolve the Phase 2 acceptance tag"
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
}

result = subprocess.run(
    [
        "git",
        "diff",
        "--name-only",
        phase2_commit,
        "--",
        "sql/schema",
        "test-framework/sql",
    ],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
)

actual = {line for line in result.stdout.splitlines() if line}

if actual != allowed:
    print("ACCEPTED BOUNDARY FAIL: unexpected SQL/test delta", file=sys.stderr)
    print(f"expected={sorted(allowed)}", file=sys.stderr)
    print(f"actual={sorted(actual)}", file=sys.stderr)
    raise SystemExit(1)

print("ACCEPTED BOUNDARY PASS: only the four Step 2 SQL/test paths differ")
PY
then
    pass "Accepted Phase 2 SQL and test content is preserved"
else
    fail "Accepted Phase 2 SQL or test content changed outside Step 2"
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
    printf '\nPhase 3 Step 2 validation stopped before database execution.\n' >&2
    printf 'No repository file or database was modified.\n' >&2
    exit 1
fi

section "Exact Step 2 file boundaries"

if python3 <<'PY'
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

checks = [
    (
        Path("sql/schema/migrations/foundation/081_postgresql_authorization_decision_and_lease_issuance.sql"),
        "42648c93789fee61e7ddd39ea6ce000741536b366fda0003c43a3a70c6af754c",
        "Step 2 migration 081",
    ),
    (
        Path("sql/schema/manifests/foundation.manifest"),
        "a20ae81980e72b715ff1974017db6acc2e14356e752a18d59d3203cc1b8e8a02",
        "Step 2 Foundation manifest",
    ),
    (
        Path("test-framework/sql/tests/foundation/130_authorization_decision_and_lease_structure.sql"),
        "bbdb1cc673b3daa3d703b8f13ac1fb124613af24515bd42bb351fdf3f6bc4820",
        "Step 2 structural test",
    ),
    (
        Path("test-framework/sql/tests/foundation-tests.manifest"),
        "51e880eb9651c5d10db4f346b61e89b365d527bf13733c4df14f6e50d06e9073",
        "Step 2 sequential manifest",
    ),
    (
        Path("docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md"),
        "85d2206bf6255c3aeb16d87d175104fc4097245d6c7d5dbbbee72530f268a594",
        "Step 2 normative model",
    ),
    (
        Path("docs/architecture/foundation/README.md"),
        "39099eefaa9706f9c692cc7d08aff0085ebae617f03b3870e229e2d97c9b6646",
        "Step 2 Foundation README",
    ),
    (
        Path("docs/architecture/foundation/authorization-evaluation-contract.md"),
        "2a49cdabafdc7b5033e264a1011e4ed911d64f136282759a517c5b8afad949cd",
        "Step 2 authorization contract",
    ),
    (
        Path("docs/architecture/foundation/sql-migration-map.md"),
        "fa2ec0807490b1fc0112da413aa829140b7db5244ca1afb3d0a9e057a9fd15cc",
        "Step 2 migration map",
    ),
]

failures = []

for path, expected, label in checks:
    actual = hashlib.sha256(path.read_bytes()).hexdigest()

    if actual == expected:
        print(f"EXACT FILE PASS: {label}")
    else:
        failures.append(
            f"{label} expected={expected} actual={actual}"
        )

if failures:
    for failure in failures:
        print(f"EXACT FILE FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then
    PASS_COUNT=$((PASS_COUNT + 8))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Manifest boundaries"

if python3 - "$manifest" "$test_manifest" "$concurrency_manifest" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path


def entries(path: Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


migration_manifest = entries(Path(sys.argv[1]))
sequential_manifest = entries(Path(sys.argv[2]))
concurrency_manifest = entries(Path(sys.argv[3]))
failures = []

if len(migration_manifest) != 33:
    failures.append(
        f"Foundation manifest contains {len(migration_manifest)} entries; expected 33"
    )

expected_081 = (
    "migrations/foundation/"
    "081_postgresql_authorization_decision_and_lease_issuance.sql"
)

position_080 = migration_manifest.index(
    "migrations/foundation/080_decision_record_repository.sql"
)
position_081 = migration_manifest.index(expected_081)
position_082 = migration_manifest.index(
    "migrations/foundation/082_data_classification_and_governance.sql"
)

if not (position_080 + 1 == position_081 == position_082 - 1):
    failures.append("Migration 081 is not exactly between 080 and 082")

if len(set(migration_manifest)) != len(migration_manifest):
    failures.append("Foundation manifest contains duplicate entries")

if len(sequential_manifest) != 13:
    failures.append(
        f"Sequential manifest contains {len(sequential_manifest)} entries; expected 13"
    )

if sequential_manifest[-1] != (
    "foundation/130_authorization_decision_and_lease_structure.sql"
):
    failures.append("Step 2 structural test is not the final sequential entry")

if len(set(sequential_manifest)) != len(sequential_manifest):
    failures.append("Sequential manifest contains duplicate entries")

expected_concurrency = [
    "concurrency/100_authentication_assertion_single_use.sh",
    "concurrency/110_session_establishment_single_use.sh",
    "concurrency/120_session_step_up_single_use.sh",
    "concurrency/130_session_terminal_transition_race.sh",
]

if concurrency_manifest != expected_concurrency:
    failures.append("Accepted four-file concurrency manifest changed")

if failures:
    for failure in failures:
        print(f"MANIFEST CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

print("MANIFEST CHECK PASS: Foundation migrations = 33")
print("MANIFEST CHECK PASS: Migration 081 is between 080 and 082")
print("MANIFEST CHECK PASS: Sequential tests = 13")
print("MANIFEST CHECK PASS: Step 2 structural test is final")
print("MANIFEST CHECK PASS: Concurrency tests remain the accepted 4")
PY
then
    PASS_COUNT=$((PASS_COUNT + 5))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Migration and structural-test boundary"

if python3 - "$migration_081" "$test_file" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

migration = Path(sys.argv[1]).read_text(encoding="utf-8")
test = Path(sys.argv[2]).read_text(encoding="utf-8")

required_markers = [
    "081_postgresql_authorization_decision_and_lease_issuance",
    "authorization_policy_versions_phase3_lookup_idx",
    "authorization_policy_stage_not_required_rule_ck",
    "decision_records_lease_request_shape_ck",
    "evaluation_records_stage_requirement_fk",
    "supporting_records_evidence_identity_uq",
    "authorization_leases_chronology_ck",
    "authorization_leases_state_shape_ck",
    "authorization_leases_issuing_decision_uq",
    "authorization_leases_decision_context_fk",
    "lease_authority_grants_evaluation_decision_fk",
    "authorization_lease_use_events_decision_fk",
]

failures = []

for marker in required_markers:
    if marker in migration:
        print(f"MIGRATION MARKER PASS: {marker}")
    else:
        failures.append(f"Migration 081 is missing marker: {marker}")

if re.search(
    r"(?i)CREATE\s+(OR\s+REPLACE\s+)?(FUNCTION|PROCEDURE)",
    migration,
):
    failures.append(
        "Step 2 migration must not add controlled production routines"
    )
else:
    print("MIGRATION ROUTINE BOUNDARY PASS: migration 081 adds no routine")

assertion_count = len(
    re.findall(r"SELECT\s+sql_test\.assert_true\s*\(", test)
)

if assertion_count == 60:
    print("STRUCTURAL TEST ASSERTION COUNT PASS: 60")
else:
    failures.append(
        f"Structural test defines {assertion_count} assertions; expected 60"
    )

if re.search(
    r"(?i)CREATE\s+(OR\s+REPLACE\s+)?(FUNCTION|PROCEDURE)\s+"
    r"(access_control|decision)\.",
    test,
):
    failures.append("Structural test replaces a production routine")
else:
    print("STRUCTURAL TEST BOUNDARY PASS: no production routine replacement")

if failures:
    for failure in failures:
        print(f"STEP 2 STRUCTURE FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then
    PASS_COUNT=$((PASS_COUNT + 15))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Documentation boundary"

if python3 - "$model" "$foundation_readme" "$contract" "$migration_map" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

checks = [
    (Path(sys.argv[1]), "Step 2 structural implementation candidate"),
    (Path(sys.argv[1]), "130_authorization_decision_and_lease_structure.sql"),
    (Path(sys.argv[1]), "Step 2 does not implement policy selection"),
    (Path(sys.argv[1]), "273 PASS assertions"),
    (Path(sys.argv[2]), "Phase 3 Step 2 implementation candidate"),
    (Path(sys.argv[2]), "273 passes"),
    (Path(sys.argv[3]), "migrations 050–081"),
    (Path(sys.argv[3]), "Phase 3 Step 2 adds migration 081"),
    (Path(sys.argv[4]), "081_postgresql_authorization_decision_and_lease_issuance.sql"),
    (Path(sys.argv[4]), "33 manifest migrations"),
    (Path(sys.argv[4]), "273 PASS"),
]


def normalize(value: str) -> str:
    value = re.sub(r"[`*>]", "", value)
    return re.sub(r"\s+", " ", value).strip()


failures = []

for path, marker in checks:
    if normalize(marker) in normalize(path.read_text(encoding="utf-8")):
        print(f"DOCUMENTATION CHECK PASS: {path}")
    else:
        failures.append(f"{path} missing marker: {marker}")

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

if bash -n "$validator_file"; then
    pass "Phase 3 Step 2 validator shell syntax is valid"
else
    fail "Phase 3 Step 2 validator shell syntax is invalid"
fi

if python3 - \
    "$migration_081" \
    "$manifest" \
    "$test_file" \
    "$test_manifest" \
    "$model" \
    "$foundation_readme" \
    "$contract" \
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
        failures.append(f"{path}: CRLF line endings")

    if not data.endswith(b"\n"):
        failures.append(f"{path}: missing EOF newline")
    elif data.endswith(b"\n\n"):
        failures.append(f"{path}: extra blank line at EOF")

    for line_number, line in enumerate(text.splitlines(), start=1):
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

print("FILE HYGIENE PASS: all Step 2 files are clean UTF-8 text")
PY
then
    pass "All Phase 3 Step 2 files pass direct hygiene checks"
else
    fail "A Phase 3 Step 2 file failed direct hygiene checks"
fi

if git diff --check -- \
    "$migration_081" \
    "$manifest" \
    "$test_file" \
    "$test_manifest" \
    "$model" \
    "$foundation_readme" \
    "$contract" \
    "$migration_map" \
    "$validator_file" >/dev/null; then
    pass "Step 2 project files pass git diff --check"
else
    fail "Step 2 project files fail git diff --check"
fi

section "Static result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 3 Step 2 static validation FAILED.\n' >&2
    printf 'No PostgreSQL test was started.\n' >&2
    exit 1
fi

printf '\nPhase 3 Step 2 static validation PASSED.\n'

if (( STATIC_ONLY == 1 )); then
    printf 'PostgreSQL execution was skipped by --static-only.\n'
    exit 0
fi

section "Complete Foundation PostgreSQL suite"

"$runner"

summary="test-framework/sql/test-results/latest-summary.txt"

if [[ ! -f "$summary" ]]; then
    printf 'Foundation runner did not create: %s\n' "$summary" >&2
    exit 1
fi

if python3 - "$summary" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

summary_text = Path(sys.argv[1]).read_text(encoding="utf-8")
failures = []

line_checks = {
    "overall result": r"(?m)^Overall result:[ \t]+PASS[ \t]*$",
    "runner exit status": r"(?m)^Runner exit status:[ \t]+0[ \t]*$",
    "sequential test count": r"(?m)^Sequential test files:[ \t]+13[ \t]*$",
    "concurrency test count": r"(?m)^Concurrency test files:[ \t]+4[ \t]*$",
}

for label, pattern in line_checks.items():
    if re.search(pattern, summary_text) is None:
        failures.append(f"Missing or incorrect {label}")

result_section = re.search(
    r"Result[ ]totals(?P<section>.*?)Failed[ ]assertions",
    summary_text,
    re.DOTALL,
)

if result_section is None:
    failures.append("Could not locate Result totals")
else:
    totals = result_section.group("section")
    expected = {"PASS": 273, "WARN": 3, "FAIL": 0}

    for result_name, expected_count in expected.items():
        match = re.search(
            rf"\|[ \t]*{result_name}[ \t]*\|[ \t]*(\d+)[ \t]*\|",
            totals,
        )

        if match is None:
            actual = 0 if result_name == "FAIL" else None
        else:
            actual = int(match.group(1))

        if actual != expected_count:
            failures.append(
                f"Result totals report {result_name}={actual}; "
                f"expected {expected_count}"
            )

failed_section = re.search(
    r"Failed[ ]assertions(?P<section>.*?)Warnings",
    summary_text,
    re.DOTALL,
)

if failed_section is None or re.search(
    r"\(0[ ]rows\)",
    failed_section.group("section"),
) is None:
    failures.append("Failed assertions section is not empty")

migration_section = re.search(
    r"Migration[ ]totals(?P<section>.*)",
    summary_text,
    re.DOTALL,
)

if migration_section is None:
    failures.append("Could not locate Migration totals")
else:
    match = re.search(
        r"\|[ \t]*(\d+)[ \t]*\|[ \t]*(\d+)[ \t]*\|",
        migration_section.group("section"),
    )

    if match is None:
        failures.append("Could not parse migration totals")
    else:
        if int(match.group(1)) != 33:
            failures.append("Manifest migrations are not 33")
        if int(match.group(2)) != 33:
            failures.append("Registered migrations are not 33")

if failures:
    for failure in failures:
        print(f"SUMMARY CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

print("SUMMARY CHECK PASS: Overall result = PASS")
print("SUMMARY CHECK PASS: Runner exit status = 0")
print("SUMMARY CHECK PASS: Sequential test files = 13")
print("SUMMARY CHECK PASS: Concurrency test files = 4")
print("SUMMARY CHECK PASS: PASS = 273")
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
    printf '\nPhase 3 Step 2 validation FAILED.\n' >&2
    printf 'Summary: %s\n' "$summary" >&2
    exit 1
fi

printf '\nPhase 3 Step 2 validation PASSED completely.\n'
printf 'Migration 081 structural boundaries are ready for Phase 3 Step 3 controlled decision finalization.\n'
