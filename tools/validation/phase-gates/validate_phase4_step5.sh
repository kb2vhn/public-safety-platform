#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'USAGE'
Usage: tools/validation/phase-gates/validate_phase4_step5.sh [--static-only]

Validates the Phase 4 Step 5 incompatible-authority and duty-conflict candidate.

Options:
  --static-only  Run repository, SQL, manifest, and documentation checks only.
  -h, --help     Show this help text.
USAGE
}

while [[ $# -gt 0 ]]; do
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

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repository_root="$(cd -- "${script_dir}/../../.." && pwd -P)"
cd "$repository_root"

migration='sql/schema/migrations/foundation/083_postgresql_approval_independence_and_separation_of_duties.sql'
sequential_manifest='test-framework/sql/tests/foundation-tests.manifest'
concurrency_manifest='test-framework/sql/tests/foundation-concurrency-tests.manifest'
step5_test='test-framework/sql/tests/foundation/200_incompatible_authority_and_duty_conflict_enforcement.sql'
step4_test='test-framework/sql/tests/foundation/190_approval_independence_enforcement.sql'
step3_test='test-framework/sql/tests/foundation/180_controlled_approval_action_recording.sql'
timeout_validator='tools/validation/validate_foundation_migration_timeouts.sh'
resource_runner='test-framework/sql/schema/scripts/test_foundation_with_resources.sh'
summary_file='test-framework/sql/test-results/latest-summary.txt'
resource_text='test-framework/sql/test-results/latest-resources.txt'
resource_json='test-framework/sql/test-results/latest-resources.json'

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS: %s\n' "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL: %s\n' "$1" >&2
}

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
    if [[ "$actual" == "$expected" ]]; then
        pass "$label = $expected"
    else
        fail "$label expected $expected, found ${actual:-}"
    fi
}

trim_manifest() {
    sed 's/\r$//' "$1" \
        | sed 's/[[:space:]]*#.*$//' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -v '^$'
}

preflight_dependencies() {
    local -a required=(awk bash cat dirname git grep python3 sed tail tr wc)
    if [[ "$STATIC_ONLY" -eq 0 ]]; then
        required+=(psql createdb dropdb time)
    fi

    local -A packages=(
        [awk]='gawk'
        [bash]='bash'
        [cat]='coreutils'
        [dirname]='coreutils'
        [git]='git'
        [grep]='grep'
        [python3]='python'
        [sed]='sed'
        [tail]='coreutils'
        [tr]='coreutils'
        [wc]='coreutils'
        [psql]='postgresql-libs'
        [createdb]='postgresql-libs'
        [dropdb]='postgresql-libs'
        [time]='time'
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
for path in \
    "$migration" \
    "$sequential_manifest" \
    "$concurrency_manifest" \
    "$step3_test" \
    "$step4_test" \
    "$step5_test" \
    "$timeout_validator" \
    "$resource_runner" \
    README.md \
    docs/README.md \
    docs/architecture/README.md \
    docs/architecture/foundation/README.md \
    docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md \
    test-framework/sql/tests/README.md \
    tools/validation/README.md \
    tools/validation/phase-gates/README.md
do
    check_file "$path"
done

check_executable "$timeout_validator"
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
    fail "Canonical origin not detected: ${remote_url:-}"
fi

printf '\n== Foundation migration execution contract ==\n'
if "$timeout_validator"; then
    pass 'Foundation migration timeout contract passed'
else
    fail 'Foundation migration timeout contract failed'
fi

printf '\n== Manifest and test inventory ==\n'
migration_count="$(trim_manifest 'sql/schema/manifests/foundation.manifest' | wc -l | tr -d ' ')"
sequential_count="$(trim_manifest "$sequential_manifest" | wc -l | tr -d ' ')"
concurrency_count="$(trim_manifest "$concurrency_manifest" | wc -l | tr -d ' ')"
assertion_count="$(grep -Ec '^SELECT sql_test\.assert_' "$step5_test")"

check_equal "$migration_count" '34' 'Manifest migrations'
check_equal "$sequential_count" '20' 'Sequential test files'
check_equal "$concurrency_count" '9' 'Concurrency test files'
check_equal "$assertion_count" '50' 'Step 5 assertions'

last_sequential="$(trim_manifest "$sequential_manifest" | tail -1)"
check_equal "$last_sequential" \
    'foundation/200_incompatible_authority_and_duty_conflict_enforcement.sql' \
    'Final sequential manifest entry'

step5_manifest_occurrences="$(trim_manifest "$sequential_manifest" \
    | grep -xc 'foundation/200_incompatible_authority_and_duty_conflict_enforcement.sql' || true)"
check_equal "$step5_manifest_occurrences" '1' 'Step 5 manifest occurrence'

printf '\n== SQL delegation and conflict contract ==\n'
check_contains "$migration" \
    'PHASE 4 STEP 5 INCOMPATIBLE-AUTHORITY AND DUTY-CONFLICT CANDIDATE' \
    'Migration declares the Step 5 candidate'
check_contains "$migration" "SET LOCAL lock_timeout = '5s';" \
    'Migration preserves the 5-second lock-wait limit'
check_contains "$migration" "SET LOCAL statement_timeout = '1min';" \
    'Migration preserves the one-minute statement limit'
check_contains "$migration" "SET LOCAL idle_in_transaction_session_timeout = '1min';" \
    'Migration preserves the one-minute idle-transaction limit'
check_contains "$migration" 'delegated_from_authority_grant_id' \
    'Authority Grant delegation parent is explicit'
check_contains "$migration" 'delegation_depth integer NOT NULL DEFAULT 0' \
    'Authority Grant delegation depth is explicit'
check_contains "$migration" 'authority_grants_delegation_not_self_ck' \
    'Authority Grant self-delegation link is constrained'
check_contains "$migration" 'authority_grants_delegation_shape_ck' \
    'Authority Grant delegation shape is constrained'
check_contains "$migration" 'authority_grants_delegation_lineage_idx' \
    'Authority Grant delegation lineage index exists'
check_contains "$migration" 'approval.authority_grant_is_current_for_approval' \
    'Current Authority Grant helper exists'
check_contains "$migration" 'approval.approval_request_is_in_duty_scope' \
    'Duty-scope helper exists'
check_contains "$migration" 'approval.enforce_approval_action_conflicts' \
    'Step 5 conflict helper exists'
check_contains "$migration" 'INSERT INTO approval.approval_action_duties' \
    'Successful approvals record typed duties'
check_contains "$migration" \
    'Successful APPROVE actions receive one immutable APPROVE duty link.' \
    'APPROVE duty is bound to the exact action and evaluation time'

reason_codes=(
    DELEGATED_AUTHORITY_NOT_ALLOWED
    DELEGATION_DEPTH_EXCEEDED
    DELEGATED_AUTHORITY_LINEAGE_INVALID
    INCOMPATIBLE_AUTHORITY_SET_NOT_ACTIVE
    INCOMPATIBLE_AUTHORITY_POLICY_INVALID
    INCOMPATIBLE_AUTHORITY_JOINT_EXERCISE
    INCOMPATIBLE_AUTHORITY_CONCURRENT_HOLDING
    INCOMPATIBLE_AUTHORITY_CHAIN_PARTICIPATION
    PROHIBITED_DUTY_COMBINATION
    DUTY_SCOPE_NOT_EVALUATED
)

for reason in "${reason_codes[@]}"; do
    check_contains "$migration" "$reason" "Migration reason code exists: $reason"
    check_contains "$step5_test" "$reason" "Step 5 test covers: $reason"
done

for mode in JOINT_EXERCISE CONCURRENT_HOLDING CHAIN_PARTICIPATION; do
    check_contains "$migration" "$mode" "Migration supports $mode"
    check_contains "$step5_test" "$mode" "Step 5 test exercises $mode"
done

check_contains "$step5_test" \
    'A withdrawn member-authority action no longer creates a JOINT_EXERCISE conflict' \
    'JOINT_EXERCISE replacement is withdrawal-aware'
check_contains "$step5_test" \
    'A withdrawn chain action no longer blocks later member-authority participation' \
    'CHAIN_PARTICIPATION replacement is withdrawal-aware'
check_contains "$step5_test" \
    'Controlled non-APPROVE actions receive no automatic duty links' \
    'Non-APPROVE duty invariant exists'
check_contains "$step5_test" \
    'Every controlled Step 5 APPROVE action has exactly one APPROVE duty' \
    'APPROVE duty cardinality invariant exists'
check_contains "$step3_test" \
    'Later Phase 4 duty recording adds one APPROVE duty without changing the Step 3 action count' \
    'Accepted Step 3 test is synchronized with Step 5 duty recording'

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
    check_contains "$status_doc" 'Step 5' "$status_doc identifies Step 5"
done

check_contains README.md \
    'Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.' \
    'Original mission sentence remains exact'
check_contains README.md $'Built on purpose.\nBacked by discipline.\nEngineered to endure.' \
    'Iron Signal Systems tagline remains exact'
check_contains README.md '20 sequential test files' \
    'Root README has the Step 5 sequential count'
check_contains README.md '590 PASS' \
    'Root README has the Step 5 PASS target'
check_contains README.md 'validate_phase4_step5.sh' \
    'Root README names the Step 5 gate'
check_contains docs/README.md '540 PASS, 0 FAIL, 3 understood WARN' \
    'Documentation index preserves accepted Step 4 results'
check_contains docs/README.md '590 PASS' \
    'Documentation index states the Step 5 target'
check_contains test-framework/sql/tests/README.md \
    'Test `200`: 50 incompatible-authority and duty-conflict assertions.' \
    'Test documentation states the exact new assertion count'
check_contains tools/validation/README.md 'validate_phase4_step5.sh' \
    'Validation index points to the active gate'
check_contains docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md \
    '## 30. Step 5 Acceptance Criteria' \
    'Normative model defines Step 5 acceptance criteria'
check_contains docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md \
    'No Step 6 or Step 7 behavior is claimed by Step 5.' \
    'Normative model preserves the next-step boundary'

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
        check_contains "$summary_file" 'Sequential test files: 20' \
            'Correctness summary has 20 sequential tests'
        check_contains "$summary_file" 'Concurrency test files: 9' \
            'Correctness summary has 9 concurrency tests'
        check_regex "$summary_file" \
            '\|[[:space:]]*PASS[[:space:]]*\|[[:space:]]*590[[:space:]]*\|' \
            'Correctness summary has 590 PASS'
        check_regex "$summary_file" \
            '\|[[:space:]]*WARN[[:space:]]*\|[[:space:]]*3[[:space:]]*\|' \
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
import json
import sys

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
    raise SystemExit(
        f'run id mismatch: expected {expected!r}, found {run_ids!r}'
    )
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
    printf '\nPhase 4 Step 5 validation FAILED.\n' >&2
    exit 1
fi

if [[ "$STATIC_ONLY" -eq 1 ]]; then
    printf '\nPhase 4 Step 5 static validation PASSED.\n'
else
    printf '\nPhase 4 Step 5 validation PASSED completely.\n'
    printf 'Incompatible-authority and duty-conflict enforcement is ready for Phase 4 Step 6 stage-satisfaction and finalization work.\n'
fi
