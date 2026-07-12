#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'EOF'
Usage: tools/validation/phase-gates/validate_phase3_step6.sh [--static-only]

Default:
  Validate Phase 3 Step 6 and run the complete Foundation PostgreSQL suite.

Options:
  --static-only  Run static checks without PostgreSQL.
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
    [createdb]="postgresql-libs" [date]="coreutils" [dirname]="coreutils"
    [dropdb]="postgresql-libs" [git]="git" [grep]="grep"
    [mkdir]="coreutils" [mktemp]="coreutils" [psql]="postgresql-libs"
    [python3]="python" [rm]="coreutils" [sed]="sed"
    [sha256sum]="coreutils" [sleep]="coreutils" [sort]="coreutils"
    [tail]="coreutils" [tee]="coreutils" [uname]="coreutils" [wc]="coreutils"
)

required_commands=(
    awk bash cat createdb date dirname dropdb git grep mkdir mktemp psql python3 rm
    sed sha256sum sleep sort tail tee uname wc
)
missing_commands=()
missing_packages=()
declare -A seen_packages=()

for command_name in "${required_commands[@]}"; do
    if command -v "$command_name" >/dev/null 2>&1; then continue; fi
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
        printf '  %-12s Arch package: %s\n' "$command_name" "${COMMAND_PACKAGE_MAP[$command_name]}" >&2
    done
    printf '\nInstall all missing packages with:\n\n  sudo pacman -S --needed' >&2
    printf ' %s' "${missing_packages[@]}" >&2
    printf '\n\nNo repository file or database was modified.\n' >&2
    exit 69
fi
pass "All required Phase 3 Step 6 commands are available"

if ! repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'Run this validator from inside the repository.\n' >&2
    exit 66
fi
cd "$repository_root"

phase2_tag="phase-2-session-control-complete-v1"
phase2_commit="76c7883c9e04cc320c0b133f86fe3c0d9dbbc63b"
runner="test-framework/sql/schema/scripts/test_foundation.sh"
sequential_manifest="test-framework/sql/tests/foundation-tests.manifest"
concurrency_manifest="test-framework/sql/tests/foundation-concurrency-tests.manifest"
previous_validator="tools/validation/phase-gates/validate_phase3_step5.sh"
validator_file="tools/validation/phase-gates/validate_phase3_step6.sh"

new_concurrency_files=(
    "test-framework/sql/tests/concurrency/140_authorization_decision_finalization_race.sh"
    "test-framework/sql/tests/concurrency/150_authorization_lease_issuance_race.sh"
    "test-framework/sql/tests/concurrency/160_authorization_lease_single_use_race.sh"
    "test-framework/sql/tests/concurrency/170_authorization_lease_limited_use_race.sh"
    "test-framework/sql/tests/concurrency/180_authorization_lease_terminal_transition_race.sh"
)

required_files=(
    'README.md'
    'docs/README.md'
    'docs/architecture/README.md'
    'docs/architecture/foundation/README.md'
    'docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md'
    'docs/architecture/foundation/authorization-evaluation-contract.md'
    'docs/architecture/foundation/sql-migration-map.md'
    'sql/schema/manifests/foundation.manifest'
    'sql/schema/migrations/foundation/081_postgresql_authorization_decision_and_lease_issuance.sql'
    'test-framework/sql/tests/README.md'
    'test-framework/sql/tests/foundation-tests.manifest'
    'test-framework/sql/tests/foundation-concurrency-tests.manifest'
    'test-framework/sql/tests/foundation/130_authorization_decision_and_lease_structure.sql'
    'test-framework/sql/tests/foundation/140_authorization_policy_selection_and_decision_finalization.sql'
    'test-framework/sql/tests/foundation/150_authorization_lease_issuance_and_use.sql'
    'test-framework/sql/tests/foundation/160_authorization_lease_fail_closed_behavior.sql'
    'test-framework/sql/tests/concurrency/support/phase3_authorization_concurrency_fixture.sql'
    'test-framework/sql/tests/concurrency/140_authorization_decision_finalization_race.sh'
    'test-framework/sql/tests/concurrency/150_authorization_lease_issuance_race.sh'
    'test-framework/sql/tests/concurrency/160_authorization_lease_single_use_race.sh'
    'test-framework/sql/tests/concurrency/170_authorization_lease_limited_use_race.sh'
    'test-framework/sql/tests/concurrency/180_authorization_lease_terminal_transition_race.sh'
    'tools/README.md'
    'tools/validation/README.md'
    'tools/validation/phase-gates/README.md'
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
[[ "$(git branch --show-current)" == "dev" ]] && pass "Current branch is dev" || fail "Current branch must be dev"
[[ -z "$(git diff --name-only --diff-filter=U)" ]] && pass "No unresolved Git conflicts" || fail "Repository contains unresolved Git conflicts"

section "Accepted Phase 2 boundary"
[[ "$(git cat-file -t "refs/tags/${phase2_tag}" 2>/dev/null || true)" == "tag" ]] && pass "Phase 2 acceptance tag is annotated" || fail "Phase 2 acceptance tag is missing or not annotated"
[[ "$(git rev-parse "${phase2_tag}^{}" 2>/dev/null || true)" == "$phase2_commit" ]] && pass "Phase 2 acceptance tag points to the accepted commit" || fail "Phase 2 acceptance tag points to the wrong commit"

if python3 - "$phase2_commit" <<'PY'
from __future__ import annotations
import subprocess
import sys

phase2_commit = sys.argv[1]
allowed = {
    "sql/schema/manifests/foundation.manifest",
    "sql/schema/migrations/foundation/081_postgresql_authorization_decision_and_lease_issuance.sql",
    "test-framework/sql/tests/README.md",
    "test-framework/sql/tests/foundation-tests.manifest",
    "test-framework/sql/tests/foundation-concurrency-tests.manifest",
    "test-framework/sql/tests/foundation/130_authorization_decision_and_lease_structure.sql",
    "test-framework/sql/tests/foundation/140_authorization_policy_selection_and_decision_finalization.sql",
    "test-framework/sql/tests/foundation/150_authorization_lease_issuance_and_use.sql",
    "test-framework/sql/tests/foundation/160_authorization_lease_fail_closed_behavior.sql",
    "test-framework/sql/tests/concurrency/support/phase3_authorization_concurrency_fixture.sql",
    "test-framework/sql/tests/concurrency/140_authorization_decision_finalization_race.sh",
    "test-framework/sql/tests/concurrency/150_authorization_lease_issuance_race.sh",
    "test-framework/sql/tests/concurrency/160_authorization_lease_single_use_race.sh",
    "test-framework/sql/tests/concurrency/170_authorization_lease_limited_use_race.sh",
    "test-framework/sql/tests/concurrency/180_authorization_lease_terminal_transition_race.sh",
}
result = subprocess.run(
    ["git", "diff", "--name-only", phase2_commit, "--", "sql/schema", "test-framework/sql"],
    check=True, text=True, stdout=subprocess.PIPE,
)
actual = {line for line in result.stdout.splitlines() if line}
if actual != allowed:
    print("ACCEPTED BOUNDARY FAIL:", file=sys.stderr)
    print(f"expected={sorted(allowed)}", file=sys.stderr)
    print(f"actual={sorted(actual)}", file=sys.stderr)
    raise SystemExit(1)
print("ACCEPTED BOUNDARY PASS: only approved Phase 3 SQL/test paths differ")
PY
then pass "Accepted Phase 2 SQL and test content is preserved"; else fail "Unexpected SQL or test content differs from accepted Phase 2"; fi

section "Required files"
for path in "${required_files[@]}"; do
    [[ -f "$path" ]] && pass "Required file exists: $path" || fail "Required file is missing: $path"
done
if (( FAIL_COUNT > 0 )); then
    printf '
Phase 3 Step 6 validation stopped before database execution.
' >&2
    exit 1
fi

section "Exact Step 6 file boundaries"
if python3 <<'PY'
from pathlib import Path
import hashlib
import sys
checks = {
    'README.md': '578b98743b30e0d71742ff807384cfe9dd73a80d4788a3d50c225bb78771857e',
    'docs/README.md': '1cb2f58fe0ebe0aed0e4a35d120221a57af8ab930a0e7f906b3ecfd91ff68157',
    'docs/architecture/README.md': '008612e2a95e1ba9d86d9562bf8a496a232796ddbc09e7095daf82a6713220b7',
    'docs/architecture/foundation/README.md': '6b41fc5ef62a58561ea6f023addcbd506df3a86801fac9d4c31853af033e9956',
    'docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md': '2332999ae8fadd63b09ce9e83473eb5d12ae16c7144f817fd2462139c8eedc33',
    'docs/architecture/foundation/authorization-evaluation-contract.md': '936605d2c1fe6c48ad72d962307a3822cc91e296f17897fe303fa6a052f0850c',
    'docs/architecture/foundation/sql-migration-map.md': '33d452e04e54b34d8fe5c1beec312f687dac5ae7ceac461f725bfbf0eec7a277',
    'sql/schema/manifests/foundation.manifest': 'a20ae81980e72b715ff1974017db6acc2e14356e752a18d59d3203cc1b8e8a02',
    'sql/schema/migrations/foundation/081_postgresql_authorization_decision_and_lease_issuance.sql': 'c6e52d50a4b12c5584d235804825c89c420ddf624d4829b324b524921a429e2e',
    'test-framework/sql/tests/README.md': '869238810d9a878e5ecc648a57c0a474d84e0d1d7193658c23d38a58bc582de5',
    'test-framework/sql/tests/foundation-tests.manifest': 'fc526ed3e8aa05994f55cfff29ae2955cc03bf72f378f07a0b4929966c526623',
    'test-framework/sql/tests/foundation-concurrency-tests.manifest': '59ea8b16aa6550150c12480b297b1d109f1ed0dba66b61681708162174d33e68',
    'test-framework/sql/tests/foundation/130_authorization_decision_and_lease_structure.sql': 'b0549e8b48307d121289e3ace064354a621ea654ed15bc2b29e110dca7de060a',
    'test-framework/sql/tests/foundation/140_authorization_policy_selection_and_decision_finalization.sql': 'd705b074f8f828abd0a1c49095745b12ba824fa6177298046e02b14986b15a99',
    'test-framework/sql/tests/foundation/150_authorization_lease_issuance_and_use.sql': '1495ba7f8aea6c0d8df347df1165b334840b93e7b2f679c1005fb11102bfa62c',
    'test-framework/sql/tests/foundation/160_authorization_lease_fail_closed_behavior.sql': 'c33245d1653e1cc08555c8c2ece4c083858dc2f684cc587c4bab8bafb4214e02',
    'test-framework/sql/tests/concurrency/support/phase3_authorization_concurrency_fixture.sql': 'eeaa0fb7c52b209f78691d17685fb107e1f5691bfc7234dd2b667c33f9a8d84b',
    'test-framework/sql/tests/concurrency/140_authorization_decision_finalization_race.sh': 'c72c9c5d66317b41731b7afae7dd9477e6dfbad046735e84ce9f2c9c52eeb84d',
    'test-framework/sql/tests/concurrency/150_authorization_lease_issuance_race.sh': 'ec380f4586844c1c15cab5c0a7f54ce66053f6762e6e37377b24427abc2888cf',
    'test-framework/sql/tests/concurrency/160_authorization_lease_single_use_race.sh': 'f484d24c82315dae81d91e1234378b1dcffde6d61e4e63461a66d690c345c8fe',
    'test-framework/sql/tests/concurrency/170_authorization_lease_limited_use_race.sh': '97a565040cc98fce7ace1b42a468f383263439581680606e36bfd8ffc65f05dd',
    'test-framework/sql/tests/concurrency/180_authorization_lease_terminal_transition_race.sh': 'ef63fb36747d366bd471c3dcb70a2f3eeeff4279a0ada41cf35d5b624e958a59',
    'tools/README.md': '3cc5ad24c4d7e11f726dbd99cff29ce3267900c83ef2cc77cb7bd90e2f5b9f11',
    'tools/validation/README.md': '5a6c964a288f948a1a3ea414b5f1ec822f73ae8b43ff75a28ef04de941ab781c',
    'tools/validation/phase-gates/README.md': '1c010b4df19be05f933d750f75b88b550c33a6a0ccf108068b3cb7b31cd067d2',
}
failures = []
for raw, expected in checks.items():
    path = Path(raw)
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual == expected:
        print(f"EXACT FILE PASS: {path}")
    else:
        failures.append(f"{path}: expected={expected} actual={actual}")
if failures:
    for failure in failures:
        print(f"EXACT FILE FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then PASS_COUNT=$((PASS_COUNT + 25)); else FAIL_COUNT=$((FAIL_COUNT + 1)); fi

section "Manifest and concurrency boundaries"
if python3 - "$sequential_manifest" "$concurrency_manifest" "${new_concurrency_files[@]}" <<'PY'
from pathlib import Path
import sys

def entries(path: Path) -> list[str]:
    return [line.strip() for line in path.read_text(encoding='utf-8').splitlines()
            if line.strip() and not line.lstrip().startswith('#')]
seq = entries(Path(sys.argv[1]))
con = entries(Path(sys.argv[2]))
new = [str(Path(value).relative_to('test-framework/sql/tests')) for value in sys.argv[3:]]
failures = []
if len(seq) != 16: failures.append(f"sequential tests={len(seq)} expected=16")
if len(con) != 9: failures.append(f"concurrency tests={len(con)} expected=9")
if con[-5:] != new: failures.append(f"final concurrency entries={con[-5:]} expected={new}")
if len(set(con)) != len(con): failures.append("duplicate concurrency manifest entry")
for path in new:
    if not (Path('test-framework/sql/tests') / path).is_file():
        failures.append(f"missing concurrency file: {path}")
if failures:
    for failure in failures: print(f"MANIFEST CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
print("MANIFEST CHECK PASS: sequential tests = 16")
print("MANIFEST CHECK PASS: concurrency tests = 9")
print("MANIFEST CHECK PASS: five Phase 3 races are final and ordered")
PY
then PASS_COUNT=$((PASS_COUNT + 3)); else FAIL_COUNT=$((FAIL_COUNT + 1)); fi

section "Concurrency proof boundary"
if python3 - "${new_concurrency_files[@]}" <<'PY'
from pathlib import Path
import re
import sys
paths = [Path(value) for value in sys.argv[1:]]
expected = {
    '140_authorization_decision_finalization_race.sh': 10,
    '150_authorization_lease_issuance_race.sh': 11,
    '160_authorization_lease_single_use_race.sh': 11,
    '170_authorization_lease_limited_use_race.sh': 12,
    '180_authorization_lease_terminal_transition_race.sh': 11,
}
markers = {
    '140_authorization_decision_finalization_race.sh': ['Exactly one concurrent Decision Record finalization succeeds', 'finalize_authorization_decision'],
    '150_authorization_lease_issuance_race.sh': ['Exactly one concurrent lease issuance succeeds', 'issue_authorization_lease_from_decision'],
    '160_authorization_lease_single_use_race.sh': ['Exactly one concurrent single-use lease consumption succeeds', 'consume_authorization_lease'],
    '170_authorization_lease_limited_use_race.sh': ['Exactly one concurrent final limited-use slot succeeds', 'contiguous unique use numbers one and two'],
    '180_authorization_lease_terminal_transition_race.sh': ['Exactly one expiration-or-revocation transition succeeds', 'expire_authorization_lease', 'revoke_lease'],
}
failures = []
total = 0
for path in paths:
    text = path.read_text(encoding='utf-8')
    count = len(re.findall(r"SELECT\s+sql_test\.assert_(?:true|false|equal_bigint|no_rows|raises)\s*\(", text))
    total += count
    if count != expected[path.name]:
        failures.append(f"{path.name} assertions={count} expected={expected[path.name]}")
    for marker in markers[path.name]:
        if marker not in text: failures.append(f"{path.name} missing marker: {marker}")
    for marker in ['pg_advisory_lock', 'concurrency_readiness', 'worker_one', 'worker_two']:
        if marker not in text: failures.append(f"{path.name} missing barrier marker: {marker}")
if total != 55: failures.append(f"total new assertions={total} expected=55")
if failures:
    for failure in failures: print(f"CONCURRENCY BOUNDARY FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
print("CONCURRENCY ASSERTION COUNT PASS: 55")
print("CONCURRENCY BARRIER PASS: all five proofs use two independent workers")
print("CONCURRENCY COVERAGE PASS: finalization, issuance, consumption, expiration, and revocation")
PY
then PASS_COUNT=$((PASS_COUNT + 3)); else FAIL_COUNT=$((FAIL_COUNT + 1)); fi

section "Documentation and shell hygiene"
if python3 <<'PY'
from pathlib import Path
import re
import sys
checks = [
    (Path('README.md'), '408 PASS'),
    (Path('docs/README.md'), 'Phase 3 Step 6'),
    (Path('docs/architecture/README.md'), 'independent-connection'),
    (Path('docs/architecture/foundation/README.md'), 'Current Phase 3 Step 6 candidate'),
    (Path('docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md'), 'Step 6 concurrency-proof candidate'),
    (Path('docs/architecture/foundation/authorization-evaluation-contract.md'), 'Phase 3 Step 6 Independent-Connection Concurrency Proof'),
    (Path('docs/architecture/foundation/sql-migration-map.md'), 'Phase 3 Step 6 Result Target'),
    (Path('test-framework/sql/tests/README.md'), '9 concurrency test files'),
    (Path('tools/validation/README.md'), 'validate_phase3_step6.sh'),
    (Path('tools/validation/phase-gates/README.md'), 'validate_phase3_step6.sh'),
]
failures = []
def normalize(value: str) -> str:
    value = re.sub(r'[`*>]', '', value)
    return re.sub(r'\s+', ' ', value).strip()
for path, marker in checks:
    if normalize(marker) in normalize(path.read_text(encoding='utf-8')):
        print(f"DOCUMENTATION CHECK PASS: {path}")
    else:
        failures.append(f"{path} missing marker: {marker}")
for path in Path('.').rglob('*.md'):
    body = path.read_text(encoding='utf-8')
    if 'github.com/kb2vhn/public-safety-platform' in body:
        failures.append(f"{path} contains retired personal repository URL")
    if re.search(r'(?m)^\s*\./validate_phase[0-9_]', body):
        failures.append(f"{path} contains obsolete root-level gate command")
if failures:
    for failure in failures: print(f"DOCUMENTATION CHECK FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
then PASS_COUNT=$((PASS_COUNT + 10)); else FAIL_COUNT=$((FAIL_COUNT + 1)); fi

if bash -n "$runner"; then pass "Foundation runner shell syntax is valid"; else fail "Foundation runner shell syntax is invalid"; fi
if bash -n "$previous_validator"; then pass "Phase 3 Step 5 validator shell syntax is valid"; else fail "Phase 3 Step 5 validator shell syntax is invalid"; fi
for path in "${new_concurrency_files[@]}"; do
    if bash -n "$path"; then pass "Concurrency shell syntax is valid: $path"; else fail "Concurrency shell syntax is invalid: $path"; fi
    if [[ -x "$path" ]]; then pass "Concurrency script is executable: $path"; else fail "Concurrency script is not executable: $path"; fi
done
if bash -n "$validator_file"; then pass "Phase 3 Step 6 validator shell syntax is valid"; else fail "Phase 3 Step 6 validator shell syntax is invalid"; fi

hygiene_files=()
for path in "${required_files[@]}"; do
    [[ "$path" == "$runner" ]] && continue
    hygiene_files+=("$path")
done

if python3 - "${hygiene_files[@]}" <<'PY'
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

print("FILE HYGIENE PASS: Step 6-owned files are clean UTF-8 text")
PY
then pass "All Phase 3 Step 6-owned files pass direct hygiene checks"; else fail "A Phase 3 Step 6-owned file failed direct hygiene checks"; fi

if git diff --check -- "${required_files[@]}" >/dev/null; then pass "Step 6 project files pass git diff --check"; else fail "Step 6 project files fail git diff --check"; fi

section "Static result"
printf 'PASS checks: %d
' "$PASS_COUNT"
printf 'FAIL checks: %d
' "$FAIL_COUNT"
if (( FAIL_COUNT > 0 )); then
    printf '
Phase 3 Step 6 static validation FAILED.
No PostgreSQL test was started.
' >&2
    exit 1
fi
printf '
Phase 3 Step 6 static validation PASSED.
'
if (( STATIC_ONLY == 1 )); then printf 'PostgreSQL execution was skipped by --static-only.
'; exit 0; fi

section "Complete Foundation PostgreSQL suite"
"$runner"
summary="test-framework/sql/test-results/latest-summary.txt"
[[ -f "$summary" ]] || { printf 'Foundation runner did not create %s
' "$summary" >&2; exit 1; }

if python3 - "$summary" <<'PY'
from pathlib import Path
import re
import sys
text = Path(sys.argv[1]).read_text(encoding='utf-8')
failures = []
checks = {
    'Overall result': r'(?m)^Overall result:[ 	]+PASS[ 	]*$',
    'Runner exit status': r'(?m)^Runner exit status:[ 	]+0[ 	]*$',
    'Sequential test files': r'(?m)^Sequential test files:[ 	]+16[ 	]*$',
    'Concurrency test files': r'(?m)^Concurrency test files:[ 	]+9[ 	]*$',
}
for label, pattern in checks.items():
    if re.search(pattern, text) is None: failures.append(f'incorrect {label}')
section = re.search(r'Result[ ]totals(?P<section>.*?)Failed[ ]assertions', text, re.DOTALL)
if section is None:
    failures.append('missing Result totals')
else:
    expected = {'PASS': 408, 'WARN': 3, 'FAIL': 0}
    for result, expected_count in expected.items():
        match = re.search(rf'\|[ 	]*{result}[ 	]*\|[ 	]*(\d+)[ 	]*\|', section.group('section'))
        actual = 0 if match is None and result == 'FAIL' else (None if match is None else int(match.group(1)))
        if actual != expected_count: failures.append(f'{result}={actual} expected={expected_count}')
migration_section = re.search(r'Migration[ ]totals(?P<section>.*)', text, re.DOTALL)
if migration_section is None:
    failures.append('missing Migration totals')
else:
    match = re.search(r'\|[ 	]*(\d+)[ 	]*\|[ 	]*(\d+)[ 	]*\|', migration_section.group('section'))
    if match is None or (int(match.group(1)), int(match.group(2))) != (33, 33):
        failures.append('manifest or registered migration count is not 33')
if failures:
    for failure in failures: print(f'SUMMARY CHECK FAIL: {failure}', file=sys.stderr)
    raise SystemExit(1)
for line in [
    'Overall result = PASS', 'Runner exit status = 0',
    'Sequential test files = 16', 'Concurrency test files = 9',
    'PASS = 408', 'FAIL = 0', 'WARN = 3',
    'Manifest migrations = 33', 'Registered migrations = 33',
]: print(f'SUMMARY CHECK PASS: {line}')
PY
then PASS_COUNT=$((PASS_COUNT + 9)); else FAIL_COUNT=$((FAIL_COUNT + 1)); fi

section "Final result"
printf 'PASS checks: %d
' "$PASS_COUNT"
printf 'FAIL checks: %d
' "$FAIL_COUNT"
if (( FAIL_COUNT > 0 )); then
    printf '
Phase 3 Step 6 validation FAILED.
Summary: %s
' "$summary" >&2
    exit 1
fi
printf '
Phase 3 Step 6 validation PASSED completely.
'
printf 'Independent-connection authorization races are ready for formal Phase 3 acceptance.
'
