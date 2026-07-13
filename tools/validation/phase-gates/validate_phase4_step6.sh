#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'USAGE'
Usage: tools/validation/phase-gates/validate_phase4_step6.sh [--static-only]

Validates the Phase 4 Step 6 stage-satisfaction and finalization candidate.

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
step3_test='test-framework/sql/tests/foundation/180_controlled_approval_action_recording.sql'
step4_test='test-framework/sql/tests/foundation/190_approval_independence_enforcement.sql'
step5_test='test-framework/sql/tests/foundation/200_incompatible_authority_and_duty_conflict_enforcement.sql'
step6_test='test-framework/sql/tests/foundation/210_approval_stage_satisfaction_and_finalization.sql'
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
    local path="$1"
    local pattern="$2"
    local label="$3"
    grep -Fq -- "$pattern" "$path" && pass "$label" || fail "$label"
}

check_regex() {
    local path="$1"
    local pattern="$2"
    local label="$3"
    grep -Eq -- "$pattern" "$path" && pass "$label" || fail "$label"
}

check_equal() {
    local actual="$1"
    local expected="$2"
    local label="$3"
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
    local -a required=(
        awk bash cat dirname git grep python3 sed tail tr wc
    )
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

    local -a missing=()
    local -a missing_packages=()
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
    "$step6_test" \
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
if [[ "$remote_url" == *'Iron-Signal-Systems/iron-signal-platform'* ]]; then
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
assertion_count="$(grep -Ec '^SELECT sql_test\.assert_' "$step6_test")"

check_equal "$migration_count" '34' 'Manifest migrations'
check_equal "$sequential_count" '21' 'Sequential test files'
check_equal "$concurrency_count" '9' 'Concurrency test files'
check_equal "$assertion_count" '60' 'Step 6 assertions'

last_sequential="$(trim_manifest "$sequential_manifest" | tail -1)"
check_equal "$last_sequential" \
    'foundation/210_approval_stage_satisfaction_and_finalization.sql' \
    'Final sequential manifest entry'

step6_occurrences="$(
    trim_manifest "$sequential_manifest" \
        | grep -xc 'foundation/210_approval_stage_satisfaction_and_finalization.sql' \
        || true
)"
check_equal "$step6_occurrences" '1' 'Step 6 manifest occurrence'

check_equal "$(grep -Ec '^SELECT sql_test\.assert_' "$step5_test")" \
    '50' 'Accepted Step 5 assertions remain frozen'

printf '\n== SQL stage-satisfaction and finalization contract ==\n'
check_contains "$migration" \
    'PHASE 4 STEP 6 STAGE-SATISFACTION AND FINALIZATION CANDIDATE' \
    'Migration declares the Step 6 candidate'
check_contains "$migration" "SET LOCAL lock_timeout = '5s';" \
    'Migration preserves the 5-second lock-wait limit'
check_contains "$migration" "SET LOCAL statement_timeout = '1min';" \
    'Migration preserves the one-minute statement limit'
check_contains "$migration" "SET LOCAL idle_in_transaction_session_timeout = '1min';" \
    'Migration preserves the one-minute idle-transaction limit'

checks=(
    'approval_stage_evaluations_one_finalized_stage_idx|One finalized stage evaluation is enforced'
    'approval.approval_action_is_current|Current Approval Action derivation exists'
    'approval.evaluate_approval_stage|Controlled stage evaluation exists'
    'approval.finalize_approval_request|Controlled Approval Request finalization exists'
    'approval.approval_request_is_current_for_authorization|Later-use approval continuity exists'
    'decision.approval_stage_evaluation_links|Decision Record stage linkage exists'
    'decision.link_approval_stage_evaluation|Controlled Decision Record linking exists'
    'approval_continuity_required|Authorization Lease continuity binding exists'
    'authorization_lease_approval_continuity_guard|Authorization Lease continuity trigger exists'
    'APPROVAL_STAGE_SATISFIED|Stage satisfaction reason exists'
    'BLOCKING_DENY_PRESENT|Blocking denial reason exists'
    'APPROVAL_REQUEST_APPROVED|Approved final result exists'
    'APPROVAL_REQUEST_DENIED|Denied final result exists'
    'APPROVAL_REQUEST_CANCELLED|Cancelled final result exists'
    'APPROVAL_REQUEST_EXPIRED|Expired final result exists'
    'APPROVAL_REQUEST_ESCALATED|Escalated final result exists'
    'APPROVAL_FINAL_RESULT_MISMATCH|Caller-result mismatch is rejected'
    'APPROVAL_CONTINUITY_REQUIRED|Later-use continuity fails closed'
)

for item in "${checks[@]}"; do
    pattern="${item%%|*}"
    label="${item#*|}"
    check_contains "$migration" "$pattern" "$label"
done

check_contains "$step6_test" \
    'A withdrawn Approval Action is no longer current' \
    'Step 6 test covers withdrawal-aware current action derivation'
check_contains "$step6_test" \
    'Two current independent approvals satisfy the primary stage' \
    'Step 6 test covers stage satisfaction'
check_contains "$step6_test" \
    'A current blocking denial finalizes the request as DENIED' \
    'Step 6 test covers blocking denial'
check_contains "$step6_test" \
    'A finalized Approval Request cannot be finalized again' \
    'Step 6 test covers finalization once'
check_contains "$step6_test" \
    'Caller-selected DENIED cannot replace computed APPROVED state' \
    'Step 6 test covers caller-result mismatch'
check_contains "$step6_test" \
    'A Decision evaluation links to the exact first finalized stage' \
    'Step 6 test covers exact Decision Record linkage'
check_contains "$step6_test" \
    'Approval continuity fails closed after a counted Authority Grant is suspended' \
    'Step 6 test covers later-use continuity loss'
check_contains "$step6_test" \
    'Approval-unrelated Authorization Leases remain outside Step 6 continuity binding' \
    'Step 6 preserves approval-unrelated lease behavior'

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
    check_contains "$status_doc" 'Phase 4 Step 6' \
        "$status_doc identifies Phase 4 Step 6"
done

check_contains README.md \
    'Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.' \
    'Original mission sentence remains exact'
check_contains README.md \
    '**Built on purpose. Backed by discipline. Engineered to endure.**' \
    'Iron Signal Systems tagline remains exact'
check_contains README.md '21 sequential test files' \
    'Root README has the Step 6 sequential count'
check_contains README.md '650 PASS' \
    'Root README has the Step 6 PASS target'
check_contains README.md 'validate_phase4_step6.sh' \
    'Root README names the Step 6 gate'
check_contains docs/README.md '590 PASS, 0 FAIL, 3 understood WARN' \
    'Documentation index preserves accepted Step 5 results'
check_contains test-framework/sql/tests/README.md \
    'Test `210`: 60 stage-satisfaction and finalization assertions.' \
    'Test documentation states the exact new assertion count'
check_contains tools/validation/README.md 'validate_phase4_step6.sh' \
    'Validation index points to the active Step 6 gate'
check_contains \
    docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md \
    '## 31. Step 6 Acceptance Criteria' \
    'Normative model defines Step 6 acceptance criteria'
check_contains \
    docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md \
    'No Phase 4 Step 7 concurrency behavior is claimed by Step 6.' \
    'Normative model preserves the Step 7 boundary'

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
        check_contains "$summary_file" 'Sequential test files: 21' \
            'Correctness summary has 21 sequential tests'
        check_contains "$summary_file" 'Concurrency test files: 9' \
            'Correctness summary has 9 concurrency tests'
        check_regex "$summary_file" \
            '\|[[:space:]]*PASS[[:space:]]*\|[[:space:]]*650[[:space:]]*\|' \
            'Correctness summary has 650 PASS'
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

run_ids = [
    str(value)
    for key, value in walk(data)
    if key.replace('-', '_') == 'run_id'
]

if expected not in run_ids:
    raise SystemExit(
        f'run id mismatch: expected {expected!r}, found {run_ids!r}'
    )
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
    printf '\nPhase 4 Step 6 validation FAILED.\n' >&2
    exit 1
fi

if [[ "$STATIC_ONLY" -eq 1 ]]; then
    printf '\nPhase 4 Step 6 static validation PASSED.\n'
else
    printf '\nPhase 4 Step 6 validation PASSED completely.\n'
    printf 'Stage-satisfaction and finalization enforcement is ready for Phase 4 Step 7 concurrency work.\n'
fi
