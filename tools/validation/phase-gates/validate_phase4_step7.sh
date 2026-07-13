#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'USAGE'
Usage: tools/validation/phase-gates/validate_phase4_step7.sh [--static-only]

Validates the Phase 4 Step 7 independent-connection approval concurrency
candidate.

Options:
  --static-only  Run repository, SQL, manifest, script, and documentation
                 checks only.
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
foundation_manifest='sql/schema/manifests/foundation.manifest'
sequential_manifest='test-framework/sql/tests/foundation-tests.manifest'
concurrency_manifest='test-framework/sql/tests/foundation-concurrency-tests.manifest'
step5_test='test-framework/sql/tests/foundation/200_incompatible_authority_and_duty_conflict_enforcement.sql'
step6_test='test-framework/sql/tests/foundation/210_approval_stage_satisfaction_and_finalization.sql'
support_sql='test-framework/sql/tests/concurrency/support/phase4_step7_approval_concurrency_fixture.sql'
timeout_validator='tools/validation/validate_foundation_migration_timeouts.sh'
resource_runner='test-framework/sql/schema/scripts/test_foundation_with_resources.sh'
correctness_runner='test-framework/sql/schema/scripts/test_foundation.sh'
summary_file='test-framework/sql/test-results/latest-summary.txt'
resource_text='test-framework/sql/test-results/latest-resources.txt'
resource_json='test-framework/sql/test-results/latest-resources.json'

concurrency_files=(
    'test-framework/sql/tests/concurrency/190_approval_duplicate_actor_race.sh'
    'test-framework/sql/tests/concurrency/200_approval_stage_finalized_evaluation_race.sh'
    'test-framework/sql/tests/concurrency/210_approval_request_finalization_race.sh'
    'test-framework/sql/tests/concurrency/220_approval_last_approval_finalization_race.sh'
    'test-framework/sql/tests/concurrency/230_approval_withdrawal_finalization_race.sh'
    'test-framework/sql/tests/concurrency/240_approval_authority_revocation_race.sh'
    'test-framework/sql/tests/concurrency/250_approval_reciprocal_approval_race.sh'
)

status_docs=(
    'README.md'
    'docs/README.md'
    'docs/architecture/README.md'
    'docs/architecture/foundation/README.md'
    'docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md'
    'test-framework/sql/tests/README.md'
    'tools/validation/README.md'
    'tools/validation/phase-gates/README.md'
)

module_boundary_files=(
    'docs/architecture/backend-services/README.md'
    'docs/architecture/backend-services/location-service-architecture.md'
    'docs/architecture/communications/README.md'
    'docs/architecture/communications/resource-subscription-and-live-update-model.md'
    'docs/architecture/gis-and-mapping/README.md'
    'docs/architecture/gis-and-mapping/map-rendering-and-data-delivery-architecture.md'
    'modules/CAD/docs/architecture/operational-workstation/README.md'
    'modules/CAD/docs/architecture/operational-workstation/operational-workstation-architecture.md'
    'modules/CAD/docs/architecture/user-interface/README.md'
    'modules/CAD/docs/architecture/user-interface/accessibility-and-inclusive-interaction-model.md'
)

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
    [[ -f "$path" ]] \
        && pass "File exists: $path" \
        || fail "Missing file: $path"
}

check_executable() {
    local path="$1"
    [[ -x "$path" ]] \
        && pass "Executable: $path" \
        || fail "Not executable: $path"
}

check_contains() {
    local path="$1"
    local pattern="$2"
    local label="$3"

    grep -Fq -- "$pattern" "$path" \
        && pass "$label" \
        || fail "$label"
}

check_not_contains() {
    local path="$1"
    local pattern="$2"
    local label="$3"

    if grep -Fq -- "$pattern" "$path"; then
        fail "$label"
    else
        pass "$label"
    fi
}

check_regex() {
    local path="$1"
    local pattern="$2"
    local label="$3"

    grep -Eq -- "$pattern" "$path" \
        && pass "$label" \
        || fail "$label"
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
        awk
        bash
        cat
        dirname
        git
        grep
        python3
        sed
        tail
        tr
        wc
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
    local command_name
    local package_name

    for command_name in "${required[@]}"; do
        command -v "$command_name" >/dev/null 2>&1 && continue
        missing+=("$command_name")
        package_name="${packages[$command_name]}"
        if [[ -z "${seen[$package_name]:-}" ]]; then
            missing_packages+=("$package_name")
            seen["$package_name"]=1
        fi
    done

    if [[ "${#missing[@]}" -ne 0 ]]; then
        printf 'Dependency preflight: FAIL\n\n' >&2
        printf 'Missing commands:\n' >&2
        for command_name in "${missing[@]}"; do
            printf '  %-12s Arch package: %s\n' \
                "$command_name" "${packages[$command_name]}" >&2
        done
        printf '\nInstall all missing packages with:\n\n' >&2
        printf '  sudo pacman -S --needed' >&2
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
    "$foundation_manifest" \
    "$sequential_manifest" \
    "$concurrency_manifest" \
    "$step5_test" \
    "$step6_test" \
    "$support_sql" \
    "$timeout_validator" \
    "$correctness_runner" \
    "$resource_runner" \
    "${concurrency_files[@]}" \
    "${status_docs[@]}" \
    "${module_boundary_files[@]}"
do
    check_file "$path"
done

check_executable "$timeout_validator"
check_executable "$correctness_runner"
check_executable "$resource_runner"
check_executable "$0"

for path in "${concurrency_files[@]}"; do
    check_executable "$path"
    if bash -n "$path"; then
        pass "Bash syntax: $path"
    else
        fail "Bash syntax: $path"
    fi
done

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

migration_count="$(trim_manifest "$foundation_manifest" | wc -l | tr -d ' ')"
sequential_count="$(trim_manifest "$sequential_manifest" | wc -l | tr -d ' ')"
concurrency_count="$(trim_manifest "$concurrency_manifest" | wc -l | tr -d ' ')"
step6_assertions="$(grep -Ec '^SELECT sql_test\.assert_' "$step6_test")"

check_equal "$migration_count" '34' 'Manifest migrations'
check_equal "$sequential_count" '21' 'Sequential test files'
check_equal "$concurrency_count" '16' 'Concurrency test files'
check_equal "$step6_assertions" '60' 'Accepted Step 6 assertions remain frozen'

last_concurrency="$(trim_manifest "$concurrency_manifest" | tail -1)"
check_equal "$last_concurrency" \
    'concurrency/250_approval_reciprocal_approval_race.sh' \
    'Final concurrency manifest entry'

total_step7_assertions=0
for path in "${concurrency_files[@]}"; do
    assertion_count="$(grep -Ec '^SELECT sql_test\.assert_' "$path")"
    check_equal "$assertion_count" '12' "$(basename "$path") assertions"
    total_step7_assertions=$((total_step7_assertions + assertion_count))

    relative_path="${path#test-framework/sql/tests/}"
    occurrence_count="$(
        trim_manifest "$concurrency_manifest" \
            | grep -Fxc "$relative_path" \
            || true
    )"
    check_equal "$occurrence_count" '1' "$(basename "$path") manifest occurrence"
done

check_equal "$total_step7_assertions" '84' 'Step 7 concurrency assertions'

printf '\n== SQL concurrency-enforcement contract ==\n'

check_contains "$migration" \
    'PHASE 4 STEP 7 INDEPENDENT-CONNECTION CONCURRENCY CANDIDATE' \
    'Migration declares the Step 7 candidate'

check_contains "$migration" \
    "SET LOCAL lock_timeout = '5s';" \
    'Migration preserves the 5-second lock-wait limit'

check_contains "$migration" \
    "SET LOCAL statement_timeout = '1min';" \
    'Migration preserves the one-minute statement limit'

check_contains "$migration" \
    "SET LOCAL idle_in_transaction_session_timeout = '1min';" \
    'Migration preserves the one-minute idle-transaction limit'

check_contains "$migration" \
    'Phase 4 Step 7 cross-request concurrency serialization' \
    'Cross-request serialization block exists'

check_contains "$migration" \
    'ORDER BY related_request.approval_request_id' \
    'Related Approval Requests lock in stable UUID order'

check_contains "$migration" \
    "'approval.request.' ||" \
    'Approval Request advisory-lock namespace is explicit'

check_contains "$migration" \
    'RECIPROCAL_REVIEW' \
    'Reciprocal request linkage participates in serialization'

check_contains "$migration" \
    'SHARED_APPROVAL_CHAIN' \
    'Shared approval chains participate in serialization'

check_contains "$migration" \
    'FOR SHARE;' \
    'Authority Grant current-state read excludes concurrent mutation'

check_contains "$migration" \
    'CREATE FUNCTION approval.evaluate_approval_stage(' \
    'Accepted controlled stage evaluation remains present'

check_contains "$migration" \
    'CREATE FUNCTION approval.finalize_approval_request(' \
    'Accepted controlled request finalization remains present'

check_contains "$migration" \
    'approval_stage_evaluations_one_finalized_stage_idx' \
    'One finalized stage evaluation remains enforced'

check_not_contains "$migration" \
    'pg_advisory_xact_lock(0)' \
    'Step 7 does not introduce one global approval lock'

printf '\n== Independent-connection proof contract ==\n'

check_contains "${concurrency_files[0]}" \
    'DUPLICATE_EFFECTIVE_ACTOR' \
    'Duplicate actor race verifies the stable rejection reason'

check_contains "${concurrency_files[1]}" \
    'Exactly one concurrent finalized stage evaluation succeeds' \
    'Finalized stage-evaluation race is asserted'

check_contains "${concurrency_files[2]}" \
    'APPROVAL_REQUEST_FINALIZED' \
    'Approval Request finalization race verifies closed state'

check_contains "${concurrency_files[3]}" \
    'Last-approval race leaves exactly two current approvals' \
    'Last approval versus finalization race is asserted'

check_contains "${concurrency_files[4]}" \
    'Withdrawal and finalization produce exactly one winning transition' \
    'Withdrawal versus finalization race is asserted'

check_contains "${concurrency_files[5]}" \
    'Authority Grant is SUSPENDED after the race' \
    'Authority revocation versus approval race is asserted'

check_contains "${concurrency_files[6]}" \
    'CIRCULAR_APPROVAL_PROHIBITED' \
    'Reciprocal approval race verifies the stable rejection reason'

for path in "${concurrency_files[@]}"; do
    check_contains "$path" \
        'ISSP_TEST_DATABASE' \
        "$(basename "$path") uses the ISSP database environment"
    check_contains "$path" \
        'issp-phase4-step7-' \
        "$(basename "$path") uses ISSP temporary-file naming"
done

check_contains "$support_sql" \
    'sql_test.create_phase4_step7_fixture' \
    'General Step 7 concurrency fixture exists'

check_contains "$support_sql" \
    'sql_test.create_phase4_step7_reciprocal_fixture' \
    'Reciprocal Step 7 concurrency fixture exists'

check_contains "$correctness_runner" \
    'ISSP_TEST_DATABASE=' \
    'Correctness runner exports the ISSP concurrency database variable'

check_contains "$correctness_runner" \
    'issp_foundation_test_' \
    'Correctness runner uses the ISSP disposable database prefix'

check_not_contains "$correctness_runner" \
    'psp_foundation_test_' \
    'Correctness runner contains no legacy PSP database prefix'

printf '\n== Documentation and module-boundary synchronization ==\n'

for path in "${status_docs[@]}"; do
    check_contains "$path" \
        'Phase 4 Step 7' \
        "$path identifies Phase 4 Step 7"
done

check_contains README.md \
    'Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.' \
    'Original mission sentence remains exact'

check_contains README.md \
    '**Built on purpose. Backed by discipline. Engineered to endure.**' \
    'Iron Signal Systems tagline remains exact'

check_contains README.md \
    'Phase 4 Step 6 is accepted' \
    'Root README preserves accepted Step 6 status'

check_contains README.md \
    '16 concurrency test files' \
    'Root README has the Step 7 concurrency count'

check_contains README.md \
    '734 PASS' \
    'Root README has the Step 7 PASS target'

check_contains README.md \
    'validate_phase4_step7.sh' \
    'Root README names the Step 7 gate'

check_contains docs/README.md \
    '84 new assertions' \
    'Documentation index states the Step 7 assertion increase'

check_contains test-framework/sql/tests/README.md \
    'Each file contributes exactly 12 assertions.' \
    'Test documentation states per-file Step 7 assertions'

check_contains tools/validation/README.md \
    'validate_phase4_step7.sh' \
    'Validation index points to the active Step 7 gate'

check_contains \
    docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md \
    '## 32. Step 7 Acceptance Criteria' \
    'Normative model defines Step 7 acceptance criteria'

check_contains \
    docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md \
    'Formal Phase 4 acceptance and the annotated release tag remain Step 8 work.' \
    'Normative model preserves the Step 8 boundary'

check_contains README.md \
    'Domain-specific records and workflows belong in their modules.' \
    'Root README preserves the Foundation and module boundary'

check_contains docs/architecture/README.md \
    'Backend services may consume Foundation decisions' \
    'Architecture index preserves downstream service dependency'

check_contains docs/architecture/README.md \
    'None of those downstream areas becomes an independent source' \
    'Architecture index prevents downstream authority creation'

check_contains docs/architecture/backend-services/location-service-architecture.md \
    'PostgreSQL' \
    'Location Service architecture remains present and PostgreSQL-aware'

check_contains docs/architecture/gis-and-mapping/map-rendering-and-data-delivery-architecture.md \
    'render' \
    'GIS architecture remains client-rendering aware'

check_contains modules/CAD/docs/architecture/operational-workstation/operational-workstation-architecture.md \
    'Unable to convert a local presentation decision into platform authority.' \
    'Operational Workstation cannot convert presentation into authority'

check_contains modules/CAD/docs/architecture/operational-workstation/operational-workstation-architecture.md \
    'Grant protected platform authority.' \
    'Operational Workstation cannot grant protected platform authority'

check_contains modules/CAD/docs/architecture/operational-workstation/operational-workstation-architecture.md \
    'Replace the Foundation Decision Engine.' \
    'Operational Workstation cannot replace the Foundation Decision Engine'

check_contains modules/CAD/docs/architecture/user-interface/README.md \
    'does not independently create identity, Authority Grants, Approval Action Records, Authorization Decisions, Authorization Leases, committed state, or canonical truth' \
    'User interface cannot independently create governed truth'

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
        check_contains "$summary_file" \
            'Overall result: PASS' \
            'Correctness summary result is PASS'
        check_contains "$summary_file" \
            'Runner exit status: 0' \
            'Correctness runner exit status is zero'
        check_contains "$summary_file" \
            'Sequential test files: 21' \
            'Correctness summary has 21 sequential tests'
        check_contains "$summary_file" \
            'Concurrency test files: 16' \
            'Correctness summary has 16 concurrency tests'
        check_regex "$summary_file" \
            '\|[[:space:]]*PASS[[:space:]]*\|[[:space:]]*734[[:space:]]*\|' \
            'Correctness summary has 734 PASS'
        check_regex "$summary_file" \
            '\|[[:space:]]*WARN[[:space:]]*\|[[:space:]]*3[[:space:]]*\|' \
            'Correctness summary has 3 WARN'
    fi

    if [[ -f "$resource_text" ]]; then
        check_contains "$resource_text" \
            'Correctness result: PASS' \
            'Resource report records correctness PASS'
        check_contains "$resource_text" \
            'Resource observation: RECORDED' \
            'Resource report is recorded'
        check_contains "$resource_text" \
            'Performance thresholds: NOT_EVALUATED' \
            'Performance thresholds remain observation-only'
    fi

    if [[ -f "$summary_file" && -f "$resource_json" ]]; then
        summary_run_id="$(
            awk -F': ' '/^Run ID:/ {print $2; exit}' "$summary_file"
        )"

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
    printf '\nPhase 4 Step 7 validation FAILED.\n' >&2
    exit 1
fi

if [[ "$STATIC_ONLY" -eq 1 ]]; then
    printf '\nPhase 4 Step 7 static validation PASSED.\n'
else
    printf '\nPhase 4 Step 7 validation PASSED completely.\n'
    printf 'Independent-connection approval concurrency enforcement is ready for Phase 4 Step 8 formal acceptance work.\n'
fi
