#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'EOF'
Usage: tools/validation/phase-gates/validate_phase4_step4.sh [--static-only]

Validates the Phase 4 Step 4 independence-enforcement candidate.

Options:
  --static-only  Run repository, SQL, manifest, and documentation checks only.
  -h, --help     Show this help text.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --static-only) STATIC_ONLY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 64 ;;
    esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repository_root="$(cd -- "${script_dir}/../../.." && pwd -P)"
cd "$repository_root"

migration='sql/schema/migrations/foundation/083_postgresql_approval_independence_and_separation_of_duties.sql'
sequential_manifest='test-framework/sql/tests/foundation-tests.manifest'
concurrency_manifest='test-framework/sql/tests/foundation-concurrency-tests.manifest'
step4_test='test-framework/sql/tests/foundation/190_approval_independence_enforcement.sql'
resource_runner='test-framework/sql/schema/scripts/test_foundation_with_resources.sh'
summary_file='test-framework/sql/test-results/latest-summary.txt'
resource_text='test-framework/sql/test-results/latest-resources.txt'
resource_json='test-framework/sql/test-results/latest-resources.json'

pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

check_file() {
    local path="$1"
    [[ -f "$path" ]] && pass "File exists: $path" || fail "Missing file: $path"
}

check_executable() {
    local path="$1"
    [[ -x "$path" ]] && pass "Executable: $path" || fail "Not executable: $path"
}

check_contains() {
    local path="$1" pattern="$2" label="$3"
    grep -Fq -- "$pattern" "$path" && pass "$label" || fail "$label"
}

check_regex() {
    local path="$1" pattern="$2" label="$3"
    grep -Eq -- "$pattern" "$path" && pass "$label" || fail "$label"
}

check_equal() {
    local actual="$1" expected="$2" label="$3"
    [[ "$actual" == "$expected" ]] \
        && pass "$label = $expected" \
        || fail "$label expected $expected, found ${actual:-<empty>}"
}

trim_manifest() {
    sed 's/\r$//' "$1" \
        | sed 's/[[:space:]]*#.*$//' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -v '^$'
}

preflight_dependencies() {
    local -a required=(awk bash cat dirname git grep python3 sed sha256sum tail tr wc)
    if [[ "$STATIC_ONLY" -eq 0 ]]; then
        required+=(psql createdb dropdb time)
    fi

    local -A packages=(
        [awk]='gawk' [bash]='bash' [cat]='coreutils' [dirname]='coreutils'
        [git]='git' [grep]='grep' [python3]='python' [sed]='sed'
        [sha256sum]='coreutils' [tail]='coreutils' [tr]='coreutils'
        [wc]='coreutils'
        [psql]='postgresql-libs' [createdb]='postgresql-libs'
        [dropdb]='postgresql-libs' [time]='time'
    )
    local -a missing=() missing_packages=()
    local -A seen=()
    local command_name package_name

    for command_name in "${required[@]}"; do
        command -v "$command_name" >/dev/null 2>&1 && continue
        missing+=("$command_name")
        package_name="${packages[$command_name]}"
        if [[ -z "${seen[$package_name]:-}" ]]; then
            missing_packages+=("$package_name")
            seen[$package_name]=1
        fi
    done

    if [[ "${#missing[@]}" -ne 0 ]]; then
        printf 'Dependency preflight: FAIL\n\n' >&2
        printf 'Missing commands:\n' >&2
        for command_name in "${missing[@]}"; do
            printf '  %-12s Arch package: %s\n' \
                "$command_name" "${packages[$command_name]}" >&2
        done
        printf '\nInstall all missing packages with:\n\n  sudo pacman -S --needed' >&2
        printf ' %s' "${missing_packages[@]}" >&2
        printf '\n\nNo validation runner was started.\n' >&2
        exit 69
    fi
    printf 'Dependency preflight: PASS\n'
}

preflight_dependencies

printf '\n== Repository and file checks ==\n'
check_file "$migration"
check_file "$sequential_manifest"
check_file "$concurrency_manifest"
check_file "$step4_test"
check_file "$resource_runner"
check_file 'README.md'
check_file 'docs/README.md'
check_file 'docs/architecture/README.md'
check_file 'docs/architecture/foundation/README.md'
check_file 'docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md'
check_file 'test-framework/sql/tests/README.md'
check_file 'tools/validation/README.md'
check_file 'tools/validation/phase-gates/README.md'
check_executable "$resource_runner"
check_executable "$0"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    pass 'Repository is a Git work tree'
else
    fail 'Repository is not a Git work tree'
fi

current_branch="$(git branch --show-current 2>/dev/null || true)"
check_equal "$current_branch" 'dev' 'Current branch'

remote_url="$(git remote get-url origin 2>/dev/null || true)"
if [[ "$remote_url" == *'Iron-Signal-Systems/public-safety-platform'* ]]; then
    pass 'Canonical Iron Signal Systems origin is configured'
else
    fail "Canonical origin not detected: ${remote_url:-<none>}"
fi

printf '\n== Manifest and test inventory ==\n'
migration_count="$(trim_manifest 'sql/schema/manifests/foundation.manifest' | wc -l | tr -d ' ')"
sequential_count="$(trim_manifest "$sequential_manifest" | wc -l | tr -d ' ')"
concurrency_count="$(trim_manifest "$concurrency_manifest" | wc -l | tr -d ' ')"
assertion_count="$(grep -Ec '^SELECT sql_test\.assert_' "$step4_test")"

check_equal "$migration_count" '34' 'Manifest migrations'
check_equal "$sequential_count" '19' 'Sequential test files'
check_equal "$concurrency_count" '9' 'Concurrency test files'
check_equal "$assertion_count" '40' 'Step 4 assertions'

last_sequential="$(trim_manifest "$sequential_manifest" | tail -1)"
check_equal "$last_sequential" \
    'foundation/190_approval_independence_enforcement.sql' \
    'Final sequential manifest entry'

step4_manifest_occurrences="$(trim_manifest "$sequential_manifest" \
    | grep -xc 'foundation/190_approval_independence_enforcement.sql' || true)"
check_equal "$step4_manifest_occurrences" '1' 'Step 4 manifest occurrence'

printf '\n== SQL independence contract ==\n'
check_contains "$migration" \
    'PHASE 4 STEP 4 INDEPENDENCE ENFORCEMENT CANDIDATE' \
    'Migration declares the Step 4 candidate'
check_contains "$migration" 'SELF_APPROVAL_PROHIBITED' \
    'Self-approval reason code exists'
check_contains "$migration" 'AFFECTED_IDENTITY_APPROVAL_PROHIBITED' \
    'Affected-identity reason code exists'
check_contains "$migration" 'DUPLICATE_EFFECTIVE_ACTOR' \
    'Duplicate-actor reason code exists'
check_contains "$migration" 'INDEPENDENT_ORGANIZATION_REQUIRED' \
    'Organization-independence reason code exists'
check_contains "$migration" 'AUTHORITY_ORIGIN_NOT_INDEPENDENT' \
    'Authority-origin reason code exists'
check_contains "$migration" 'CIRCULAR_APPROVAL_PROHIBITED' \
    'Circular-approval reason code exists'
check_contains "$migration" 'approval_actions_phase4_organization_idx' \
    'Organization lookup index exists'
check_contains "$migration" "p_action_type = 'APPROVE'" \
    'Independence checks apply to new approvals'
check_contains "$migration" "'WITHDRAW_APPROVAL'," \
    'Current-action derivation recognizes withdrawal'
check_contains "$migration" "'RECIPROCAL_REVIEW'," \
    'Reciprocal relationships use typed dependencies'
check_contains "$migration" 'linked_request.approval_chain_id =' \
    'Circular evaluation uses explicit approval chains'

for reason in \
    SELF_APPROVAL_PROHIBITED \
    AFFECTED_IDENTITY_APPROVAL_PROHIBITED \
    DUPLICATE_EFFECTIVE_ACTOR \
    INDEPENDENT_ORGANIZATION_REQUIRED \
    AUTHORITY_ORIGIN_NOT_INDEPENDENT \
    CIRCULAR_APPROVAL_PROHIBITED
do
    check_contains "$step4_test" "$reason" \
        "Step 4 test covers $reason"
done

check_contains "$step4_test" \
    'No reciprocal cycle is inferred from time proximity without explicit linkage' \
    'Negative time-only cycle inference test exists'
check_contains "$step4_test" \
    'Actor may record a replacement approval after the prior approval is withdrawn' \
    'Withdrawal-aware replacement approval test exists'

printf '\n== Documentation synchronization ==\n'
for status_doc in \
    README.md \
    docs/README.md \
    docs/architecture/README.md \
    docs/architecture/foundation/README.md \
    docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md \
    test-framework/sql/tests/README.md \
    tools/validation/README.md \
    tools/validation/phase-gates/README.md
do
    check_contains "$status_doc" 'Step 4' "$status_doc identifies Step 4"
done

check_contains 'README.md' \
    'Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.' \
    'Original mission sentence remains exact'
check_contains 'README.md' \
    'Built on purpose. Backed by discipline. Engineered to endure.' \
    'Iron Signal Systems tagline remains exact'
check_contains 'README.md' '19 sequential test files' \
    'Root README has the Step 4 sequential count'
check_contains 'README.md' '540 PASS' \
    'Root README has the Step 4 PASS target'
check_contains 'README.md' 'validate_phase4_step4.sh' \
    'Root README names the Step 4 gate'
check_contains 'docs/README.md' '500 PASS, 0 FAIL, 3 understood WARN' \
    'Documentation index preserves accepted Step 3 results'
check_contains 'docs/README.md' '540 PASS' \
    'Documentation index states the Step 4 target'
check_contains 'test-framework/sql/tests/README.md' \
    'Test `190`: 40 independence-enforcement assertions.' \
    'Test documentation states the exact new assertion count'
check_contains 'tools/validation/README.md' 'validate_phase4_step4.sh' \
    'Validation index points to the active gate'

if [[ "$STATIC_ONLY" -eq 1 ]]; then
    printf '\nStatic-only validation requested; PostgreSQL execution skipped.\n'
else
    printf '\n== Correctness and resource execution ==\n'
    if "$resource_runner"; then
        pass 'Resource-aware Foundation runner exited successfully'
    else
        fail 'Resource-aware Foundation runner failed'
    fi

    check_file "$summary_file"
    check_file "$resource_text"
    check_file "$resource_json"

    if [[ -f "$summary_file" ]]; then
        check_contains "$summary_file" 'Overall result: PASS' \
            'Correctness summary result is PASS'
        check_contains "$summary_file" 'Runner exit status: 0' \
            'Correctness runner exit status is zero'
        check_contains "$summary_file" 'Sequential test files: 19' \
            'Correctness summary has 19 sequential tests'
        check_contains "$summary_file" 'Concurrency test files: 9' \
            'Correctness summary has 9 concurrency tests'
        check_regex "$summary_file" '\|[[:space:]]*PASS[[:space:]]*\|[[:space:]]*540[[:space:]]*\|' \
            'Correctness summary has 540 PASS'
        check_regex "$summary_file" '\|[[:space:]]*WARN[[:space:]]*\|[[:space:]]*3[[:space:]]*\|' \
            'Correctness summary has 3 WARN'
    fi

    if [[ -f "$resource_text" ]]; then
        check_contains "$resource_text" 'Correctness result: PASS' \
            'Resource report records correctness PASS'
        check_contains "$resource_text" 'Resource observation: RECORDED' \
            'Resource report is recorded'
        check_contains "$resource_text" 'Performance thresholds: NOT_EVALUATED' \
            'Performance thresholds remain observation-only'
    fi

    if [[ -f "$summary_file" && -f "$resource_json" ]]; then
        summary_run_id="$(awk -F': ' '/^Run ID:/ {print $2; exit}' "$summary_file")"
        if python3 - "$resource_json" "$summary_run_id" <<'PY'
import json, sys
path, expected = sys.argv[1:]
with open(path, encoding='utf-8') as handle:
    data = json.load(handle)

def walk(value):
    if isinstance(value, dict):
        for key, child in value.items():
            yield str(key).lower(), child
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)

pairs = list(walk(data))
run_ids = [str(v) for k, v in pairs if k.replace('-', '_') == 'run_id']
if expected not in run_ids:
    raise SystemExit(f'run id mismatch: expected {expected!r}, found {run_ids!r}')
print('resource JSON run id matches')
PY
        then
            pass 'Resource JSON run ID matches correctness summary'
        else
            fail 'Resource JSON run ID does not match correctness summary'
        fi
    fi
fi

printf '\n== Final result ==\n'
printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
    printf '\nPhase 4 Step 4 validation FAILED.\n' >&2
    exit 1
fi

if [[ "$STATIC_ONLY" -eq 1 ]]; then
    printf '\nPhase 4 Step 4 static validation PASSED.\n'
else
    printf '\nPhase 4 Step 4 validation PASSED completely.\n'
    printf 'Approval independence enforcement is ready for Phase 4 Step 5 incompatible-authority and separation-of-duties work.\n'
fi
