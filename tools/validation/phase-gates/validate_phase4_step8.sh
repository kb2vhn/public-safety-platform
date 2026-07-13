#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'USAGE'
Usage: tools/validation/phase-gates/validate_phase4_step8.sh [--static-only]

Validates formal Phase 4 approval-independence and separation-of-duties
acceptance, the annotated release tag, the accepted implementation tree,
documentation synchronization, correctness results, and resource observation.

Options:
  --static-only  Run repository, tag, tree, manifest, SQL, and documentation
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

accepted_tag='phase-4-approval-independence-and-separation-of-duties-complete-v1'
acceptance_record='docs/architecture/foundation/phase-4-approval-independence-and-separation-of-duties-acceptance.md'
normative_model='docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md'
migration='sql/schema/migrations/foundation/083_postgresql_approval_independence_and_separation_of_duties.sql'
foundation_manifest='sql/schema/manifests/foundation.manifest'
sequential_manifest='test-framework/sql/tests/foundation-tests.manifest'
concurrency_manifest='test-framework/sql/tests/foundation-concurrency-tests.manifest'
step6_test='test-framework/sql/tests/foundation/210_approval_stage_satisfaction_and_finalization.sql'
timeout_validator='tools/validation/validate_foundation_migration_timeouts.sh'
resource_runner='test-framework/sql/schema/scripts/test_foundation_with_resources.sh'
correctness_runner='test-framework/sql/schema/scripts/test_foundation.sh'
step7_gate='tools/validation/phase-gates/validate_phase4_step7.sh'
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
    "$normative_model"
    'test-framework/sql/tests/README.md'
    'tools/validation/README.md'
    'tools/validation/phase-gates/README.md'
    "$acceptance_record"
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
    if [[ -f "$path" ]]; then
        pass "File exists: $path"
    else
        fail "Missing file: $path"
    fi
}

check_executable() {
    local path="$1"
    if [[ -x "$path" ]]; then
        pass "Executable: $path"
    else
        fail "Not executable: $path"
    fi
}

check_contains() {
    local path="$1"
    local pattern="$2"
    local label="$3"
    if grep -Fq -- "$pattern" "$path"; then
        pass "$label"
    else
        fail "$label"
    fi
}

check_not_regex() {
    local path="$1"
    local pattern="$2"
    local label="$3"
    if grep -Eq -- "$pattern" "$path"; then
        fail "$label"
    else
        pass "$label"
    fi
}

check_regex() {
    local path="$1"
    local pattern="$2"
    local label="$3"
    if grep -Eq -- "$pattern" "$path"; then
        pass "$label"
    else
        fail "$label"
    fi
}

check_equal() {
    local actual="$1"
    local expected="$2"
    local label="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$label = $expected"
    else
        fail "$label expected $expected, found ${actual:-<empty>}"
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
    "$acceptance_record" \
    "$normative_model" \
    "$migration" \
    "$foundation_manifest" \
    "$sequential_manifest" \
    "$concurrency_manifest" \
    "$step6_test" \
    "$timeout_validator" \
    "$correctness_runner" \
    "$resource_runner" \
    "$step7_gate" \
    "${concurrency_files[@]}" \
    "${status_docs[@]}" \
    "${module_boundary_files[@]}"
do
    check_file "$path"
done

check_executable "$timeout_validator"
check_executable "$correctness_runner"
check_executable "$resource_runner"
check_executable "$step7_gate"
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
    fail "Canonical origin not detected: ${remote_url:-<missing>}"
fi

printf '\n== Annotated acceptance tag and tree integrity ==\n'

accepted_commit="$(
    sed -nE \
        's/^> \*\*Accepted implementation commit:\*\* `([0-9a-f]{40})`$/\1/p' \
        "$acceptance_record" \
        | head -1
)"

if [[ "$accepted_commit" =~ ^[0-9a-f]{40}$ ]]; then
    pass 'Acceptance record contains one full implementation commit'
else
    fail 'Acceptance record implementation commit is missing or malformed'
fi

tag_type="$(git cat-file -t "$accepted_tag" 2>/dev/null || true)"
check_equal "$tag_type" 'tag' 'Phase 4 release tag object type'

tag_commit="$(git rev-parse "${accepted_tag}^{commit}" 2>/dev/null || true)"
check_equal "$tag_commit" "$accepted_commit" 'Annotated tag target'

if [[ -n "$tag_commit" ]] && git merge-base --is-ancestor "$tag_commit" HEAD; then
    pass 'Current dev tree descends from the accepted Phase 4 tag'
else
    fail 'Current dev tree does not descend from the accepted Phase 4 tag'
fi

implementation_paths=(
    'sql/schema'
    'test-framework/sql/schema'
    'test-framework/sql/tests/foundation-tests.manifest'
    'test-framework/sql/tests/foundation-concurrency-tests.manifest'
    'test-framework/sql/tests/foundation'
    'test-framework/sql/tests/concurrency'
    'tools/validation/phase-gates/validate_phase4_step7.sh'
)

if [[ -n "$tag_commit" ]] && git diff --quiet "$tag_commit" -- "${implementation_paths[@]}"; then
    pass 'Accepted SQL and executable test tree is unchanged after the tag'
else
    fail 'Accepted SQL or executable test tree differs from the tag'
fi

check_contains "$acceptance_record" \
    "**Accepted release tag:** \`$accepted_tag\`" \
    'Acceptance record names the annotated tag'
check_contains "$acceptance_record" \
    'Phase 4 is accepted.' \
    'Acceptance decision is explicit'
check_contains "$acceptance_record" \
    '159 phase-gate PASS checks' \
    'Acceptance record preserves the final Step 7 gate count'
check_contains "$acceptance_record" \
    '0 phase-gate FAIL checks' \
    'Acceptance record preserves zero Step 7 gate failures'

printf '\n== Foundation migration execution contract ==\n'

if "$timeout_validator"; then
    pass 'Foundation migration timeout contract passed'
else
    fail 'Foundation migration timeout contract failed'
fi

printf '\n== Accepted manifest and test inventory ==\n'

migration_count="$(trim_manifest "$foundation_manifest" | wc -l | tr -d ' ')"
sequential_count="$(trim_manifest "$sequential_manifest" | wc -l | tr -d ' ')"
concurrency_count="$(trim_manifest "$concurrency_manifest" | wc -l | tr -d ' ')"
step6_assertions="$(grep -Ec '^SELECT sql_test\.assert_' "$step6_test")"

check_equal "$migration_count" '34' 'Manifest migrations'
check_equal "$sequential_count" '21' 'Sequential test files'
check_equal "$concurrency_count" '16' 'Concurrency test files'
check_equal "$step6_assertions" '60' 'Accepted Step 6 assertions remain frozen'

last_sequential="$(trim_manifest "$sequential_manifest" | tail -1)"
last_concurrency="$(trim_manifest "$concurrency_manifest" | tail -1)"
check_equal "$last_sequential" \
    'foundation/210_approval_stage_satisfaction_and_finalization.sql' \
    'Final sequential manifest entry'
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
check_equal "$total_step7_assertions" '84' 'Phase 4 concurrency assertions'

printf '\n== Accepted SQL and concurrency contract ==\n'

check_contains "$migration" \
    'PHASE 4 STEP 7 INDEPENDENT-CONNECTION CONCURRENCY CANDIDATE' \
    'Tagged migration contains the accepted Step 7 serialization block'
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
    'ORDER BY related_request.approval_request_id' \
    'Related Approval Requests lock in stable UUID order'
check_contains "$migration" \
    "'approval.request.' ||" \
    'Approval Request advisory-lock namespace is explicit'
check_contains "$migration" \
    'FOR SHARE;' \
    'Authority Grant current-state read excludes concurrent mutation'
check_contains "$migration" \
    'CREATE FUNCTION approval.evaluate_approval_stage(' \
    'Controlled stage evaluation remains present'
check_contains "$migration" \
    'CREATE FUNCTION approval.finalize_approval_request(' \
    'Controlled request finalization remains present'
check_contains "$migration" \
    'approval_stage_evaluations_one_finalized_stage_idx' \
    'One finalized stage evaluation remains enforced'
check_not_regex "$migration" \
    'pg_advisory_xact_lock[[:space:]]*\([[:space:]]*0[[:space:]]*\)' \
    'Accepted Phase 4 does not use one global approval lock'

check_contains "${concurrency_files[0]}" \
    'DUPLICATE_EFFECTIVE_ACTOR' \
    'Duplicate effective-actor race remains reason-coded'
check_contains "${concurrency_files[1]}" \
    'Exactly one concurrent finalized stage evaluation succeeds' \
    'Finalized stage-evaluation race remains asserted'
check_contains "${concurrency_files[2]}" \
    'APPROVAL_REQUEST_FINALIZED' \
    'Approval Request finalization race remains reason-coded'
check_contains "${concurrency_files[3]}" \
    'Last-approval race leaves exactly two current approvals' \
    'Last approval versus finalization race remains asserted'
check_contains "${concurrency_files[4]}" \
    'Withdrawal and finalization produce exactly one winning transition' \
    'Withdrawal versus finalization race remains asserted'
check_contains "${concurrency_files[5]}" \
    'Authority Grant is SUSPENDED after the race' \
    'Authority revocation versus approval race remains asserted'
check_contains "${concurrency_files[6]}" \
    'CIRCULAR_APPROVAL_PROHIBITED' \
    'Reciprocal approval race remains reason-coded'

printf '\n== Formal acceptance documentation ==\n'

for path in "${status_docs[@]}"; do
    check_contains "$path" \
        'Phase 4' \
        "$path identifies Phase 4"
done

check_contains README.md \
    'Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.' \
    'Original mission sentence remains exact'
check_contains README.md \
    '**Built on purpose. Backed by discipline. Engineered to endure.**' \
    'Iron Signal Systems tagline remains exact'
check_contains README.md \
    '### Accepted Phase 4 — Approval Independence and Separation of Duties' \
    'Root README records formal Phase 4 acceptance'
check_contains README.md \
    "$accepted_tag" \
    'Root README names the accepted tag'
check_contains README.md \
    '734 PASS' \
    'Root README preserves the accepted PASS result'
check_contains README.md \
    '159 phase-gate PASS checks' \
    'Root README preserves the final implementation-gate count'
check_contains docs/README.md \
    'Phase 4 approval independence and separation of duties' \
    'Documentation index records the accepted Phase 4 boundary'
check_contains docs/architecture/README.md \
    '## Accepted Architecture Boundary' \
    'Architecture index records the accepted boundary'
check_contains docs/architecture/foundation/README.md \
    '## Accepted Phase 4 Boundary' \
    'Foundation index records the accepted boundary'
check_contains "$normative_model" \
    '## 33. Step 8 Acceptance Criteria and Decision' \
    'Normative model records the Step 8 decision'
check_contains "$normative_model" \
    "$accepted_tag" \
    'Normative model names the accepted tag'
check_contains test-framework/sql/tests/README.md \
    'Accepted Phase 4 result:' \
    'Test documentation records the accepted result'
check_contains tools/validation/README.md \
    'validate_phase4_step8.sh' \
    'Validation index points to the formal-acceptance gate'
check_contains tools/validation/phase-gates/README.md \
    '## Active Gate: Phase 4 Step 8' \
    'Phase-gate index identifies Step 8'

for path in \
    README.md \
    docs/README.md \
    docs/architecture/README.md \
    docs/architecture/foundation/README.md \
    "$normative_model" \
    test-framework/sql/tests/README.md \
    tools/validation/README.md \
    tools/validation/phase-gates/README.md
do
    check_not_regex "$path" \
        'Phase 4 Step 7 (is the current candidate|is the active candidate)|independent-connection approval concurrency candidate|Step 7 candidate target:|Step 7 target:|## Active Phase 4 Step 7|## Phase 4 Step 7 Candidate' \
        "$path contains no active Step 7 candidate status"
done

check_contains docs/architecture/README.md \
    'Backend services may consume Foundation decisions' \
    'Architecture index preserves downstream service dependency'
check_contains docs/architecture/README.md \
    'None of those downstream areas becomes an independent source' \
    'Architecture index prevents downstream authority creation'
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
        # STEP8_SUMMARY_TABLE_PARSER_V1
        summary_metrics="$(
            python3 - "$summary_file" <<'PY_SUMMARY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
lines = text.splitlines()

status_counts = {
    "PASS": 0,
    "FAIL": 0,
    "WARN": 0,
}

saw_result_totals = False
in_result_totals = False

manifest_migrations = "MISSING"
registered_migrations = "MISSING"
in_migration_totals = False

status_row = re.compile(
    r"^\|\s*(PASS|FAIL|WARN)\s*\|\s*(\d+)\s*\|$"
)
migration_row = re.compile(
    r"^\|\s*(\d+)\s*\|\s*(\d+)\s*\|$"
)

for line in lines:
    stripped = line.strip()

    if stripped == "Result totals":
        saw_result_totals = True
        in_result_totals = True
        continue

    if stripped == "Failed assertions":
        in_result_totals = False
        continue

    if stripped == "Migration totals":
        in_migration_totals = True
        continue

    if in_result_totals:
        match = status_row.match(line)
        if match:
            status_counts[match.group(1)] = int(match.group(2))

    if in_migration_totals:
        match = migration_row.match(line)
        if match:
            manifest_migrations = match.group(1)
            registered_migrations = match.group(2)
            in_migration_totals = False

if not saw_result_totals:
    status_counts = {
        "PASS": "MISSING",
        "FAIL": "MISSING",
        "WARN": "MISSING",
    }

print(
    "|".join(
        str(value)
        for value in (
            manifest_migrations,
            registered_migrations,
            status_counts["PASS"],
            status_counts["FAIL"],
            status_counts["WARN"],
        )
    )
)
PY_SUMMARY
        )"

        IFS='|' read -r \
            summary_manifest_migrations \
            summary_registered_migrations \
            summary_pass_count \
            summary_fail_count \
            summary_warn_count \
            <<<"$summary_metrics"

        check_equal \
            "$summary_manifest_migrations" \
            '34' \
            'Correctness summary has 34 manifest migrations'

        check_equal \
            "$summary_registered_migrations" \
            '34' \
            'Correctness summary has 34 registered migrations'

        check_contains "$summary_file" \
            'Sequential test files: 21' \
            'Correctness summary has 21 sequential tests'

        check_contains "$summary_file" \
            'Concurrency test files: 16' \
            'Correctness summary has 16 concurrency tests'

        check_equal \
            "$summary_pass_count" \
            '734' \
            'Correctness summary has 734 PASS'

        check_equal \
            "$summary_fail_count" \
            '0' \
            'Correctness summary has 0 FAIL'

        check_equal \
            "$summary_warn_count" \
            '3' \
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
    printf '\nPhase 4 Step 8 validation FAILED.\n' >&2
    exit 1
fi

if [[ "$STATIC_ONLY" -eq 1 ]]; then
    printf '\nPhase 4 Step 8 static validation PASSED.\n'
else
    printf '\nPhase 4 Step 8 validation PASSED completely.\n'
    printf 'Phase 4 approval independence and separation of duties is formally accepted.\n'
    printf 'Accepted tag: %s\n' "$accepted_tag"
fi
