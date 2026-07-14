#!/usr/bin/env bash

set -u

PASS_COUNT=0
FAIL_COUNT=0
STATIC_ONLY=false

if [[ "${1:-}" == "--static-only" ]]; then
    STATIC_ONLY=true
elif [[ $# -ne 0 ]]; then
    printf 'Usage: %s [--static-only]\n' "$0" >&2
    exit 2
fi

pass() {
    printf 'PASS: %s\n' "$1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_file() {
    if [[ -f "$1" ]]; then
        pass "File exists: $1"
    else
        fail "Missing file: $1"
    fi
}

check_executable() {
    if [[ -x "$1" ]]; then
        pass "Executable: $1"
    else
        fail "Not executable: $1"
    fi
}

check_equal() {
    local actual="$1"
    local expected="$2"
    local label="$3"

    if [[ "$actual" == "$expected" ]]; then
        pass "$label = $expected"
    else
        fail "$label expected=$expected actual=${actual:-missing}"
    fi
}

check_contains() {
    local file="$1"
    local needle="$2"
    local label="$3"

    if grep -Fq -- "$needle" "$file"; then
        pass "$label"
    else
        fail "$label"
    fi
}

check_not_contains() {
    local file="$1"
    local needle="$2"
    local label="$3"

    if grep -Fq -- "$needle" "$file"; then
        fail "$label"
    else
        pass "$label"
    fi
}

for command_name in bash git grep sed awk find wc; do
    if command -v "$command_name" >/dev/null 2>&1; then
        :
    else
        printf 'Dependency preflight: FAIL (%s unavailable)\n' "$command_name" >&2
        exit 1
    fi
done

printf 'Dependency preflight: PASS\n'

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
    printf 'FAIL: Repository is a Git work tree\n' >&2
    exit 1
fi

cd "$repo_root"

accepted_tag='phase-5-production-database-security-boundary-complete-v1'
accepted_commit='9f8dbf9d909ef157df72b12511b165a689559093'
phase4_tag='phase-4-approval-independence-and-separation-of-duties-complete-v1'
acceptance_record='docs/architecture/foundation/phase-5-production-database-security-boundary-acceptance.md'
contract='docs/architecture/foundation/production-database-role-ownership-and-runtime-privilege-model.md'
step7_record='docs/architecture/foundation/phase-5-step-7-hostile-condition-and-role-race-validation.md'
step7_gate='tools/validation/phase-gates/validate_phase5_step7.sh'

printf '\n== Repository and acceptance-artifact checks ==\n'

required_files=(
    'README.md'
    'docs/README.md'
    'docs/architecture/README.md'
    'docs/architecture/postgresql.md'
    'docs/architecture/foundation/README.md'
    'docs/architecture/foundation/database-security-model.md'
    "$contract"
    "$step7_record"
    "$acceptance_record"
    'sql/deployment/manifests/deployment.manifest'
    'sql/deployment/migrations/900_postgresql_role_topology_and_membership.sql'
    'sql/deployment/migrations/910_database_schema_and_object_ownership.sql'
    'sql/deployment/migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql'
    'sql/deployment/migrations/930_investigator_audit_and_validation_review_surfaces.sql'
    'sql/deployment/migrations/940_break_glass_and_credential_lifecycle.sql'
    'sql/deployment/scripts/apply_deployment.sh'
    'test-framework/sql/deployment/scripts/test_phase5_step7_hostile_condition_and_role_races.sh'
    'tools/validation/validate_foundation_database_parity.sh'
    "$step7_gate"
    'tools/validation/phase-gates/validate_phase5_step8.sh'
)

for file in "${required_files[@]}"; do
    check_file "$file"
done

check_executable 'sql/deployment/scripts/apply_deployment.sh'
check_executable 'test-framework/sql/deployment/scripts/test_phase5_step7_hostile_condition_and_role_races.sh'
check_executable "$step7_gate"
check_executable 'tools/validation/phase-gates/validate_phase5_step8.sh'

pass 'Repository is a Git work tree'
check_equal "$(git branch --show-current)" 'dev' 'Current branch'
check_equal \
    "$(git remote get-url origin 2>/dev/null || true)" \
    'git@github.com:Iron-Signal-Systems/iron-signal-platform.git' \
    'Canonical origin'

printf '\n== Annotated acceptance tag and tree integrity ==\n'

tag_type="$(git cat-file -t "$accepted_tag" 2>/dev/null || true)"
check_equal "$tag_type" 'tag' 'Phase 5 release tag object type'

tag_commit="$(git rev-parse "${accepted_tag}^{commit}" 2>/dev/null || true)"
check_equal "$tag_commit" "$accepted_commit" 'Annotated Phase 5 tag target'

if [[ -n "$tag_commit" ]] && git merge-base --is-ancestor "$tag_commit" HEAD; then
    pass 'Current dev tree descends from the accepted Phase 5 tag'
else
    fail 'Current dev tree descends from the accepted Phase 5 tag'
fi

phase4_commit="$(git rev-parse "${phase4_tag}^{commit}" 2>/dev/null || true)"
if [[ "$phase4_commit" =~ ^[0-9a-f]{40}$ ]]; then
    pass 'Phase 4 acceptance tag resolves to a commit'
else
    fail 'Phase 4 acceptance tag resolves to a commit'
fi

if [[ -n "$phase4_commit" ]] && git diff --quiet "$phase4_commit" -- sql/schema test-framework/sql/schema test-framework/sql/tests/foundation test-framework/sql/tests/concurrency test-framework/sql/tests/foundation-tests.manifest test-framework/sql/tests/foundation-concurrency-tests.manifest; then
    pass 'Frozen Phase 4 SQL and executable Foundation test tree remains unchanged'
else
    fail 'Frozen Phase 4 SQL and executable Foundation test tree remains unchanged'
fi

implementation_paths=(
    'sql/deployment'
    'test-framework/sql/deployment'
    'tools/validation/validate_foundation_database_parity.sh'
    'tools/validation/phase-gates/validate_phase5_step1.sh'
    'tools/validation/phase-gates/validate_phase5_step2.sh'
    'tools/validation/phase-gates/validate_phase5_step3.sh'
    'tools/validation/phase-gates/validate_phase5_step4.sh'
    'tools/validation/phase-gates/validate_phase5_step5.sh'
    'tools/validation/phase-gates/validate_phase5_step6.sh'
    'tools/validation/phase-gates/validate_phase5_step7.sh'
)

if git diff --quiet "$accepted_commit" -- "${implementation_paths[@]}"; then
    pass 'Accepted Phase 5 deployment and executable validation tree matches the tag'
else
    fail 'Accepted Phase 5 deployment or executable validation tree differs from the tag'
fi

check_contains "$acceptance_record" \
    "**Accepted release tag:** \`$accepted_tag\`" \
    'Acceptance record names the annotated tag'
check_contains "$acceptance_record" \
    "**Accepted implementation commit:** \`$accepted_commit\`" \
    'Acceptance record names the full implementation commit'
check_contains "$acceptance_record" \
    'Phase 5 is accepted.' \
    'Acceptance decision is explicit'
check_contains "$acceptance_record" \
    '97 phase-gate PASS checks' \
    'Acceptance record preserves the final Step 7 gate count'
check_contains "$acceptance_record" \
    '0 phase-gate FAIL checks' \
    'Acceptance record preserves zero Step 7 gate failures'
check_contains "$acceptance_record" \
    'PASS checks: 82' \
    'Acceptance record preserves the hostile-condition PASS count'

printf '\n== Accepted deployment manifest and boundary ==\n'

mapfile -t deployment_entries < <(
    grep -Ev '^[[:space:]]*(#|$)' sql/deployment/manifests/deployment.manifest
)

check_equal "${#deployment_entries[@]}" '5' 'Accepted deployment migration count'
check_equal "${deployment_entries[0]:-missing}" 'migrations/900_postgresql_role_topology_and_membership.sql' 'First deployment migration'
check_equal "${deployment_entries[1]:-missing}" 'migrations/910_database_schema_and_object_ownership.sql' 'Second deployment migration'
check_equal "${deployment_entries[2]:-missing}" 'migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql' 'Third deployment migration'
check_equal "${deployment_entries[3]:-missing}" 'migrations/930_investigator_audit_and_validation_review_surfaces.sql' 'Fourth deployment migration'
check_equal "${deployment_entries[4]:-missing}" 'migrations/940_break_glass_and_credential_lifecycle.sql' 'Fifth deployment migration'

if find sql/deployment/migrations -maxdepth 1 -type f -name '950_*' -print -quit | grep -q .; then
    fail 'Accepted Phase 5 tree contains no migration 950'
else
    pass 'Accepted Phase 5 tree contains no migration 950'
fi

check_contains 'sql/deployment/migrations/940_break_glass_and_credential_lifecycle.sql' \
    'Break-glass SCRAM verifier must use at least 4096 iterations' \
    'Accepted migration 940 preserves the SCRAM iteration floor'
check_contains 'sql/deployment/migrations/940_break_glass_and_credential_lifecycle.sql' \
    'SCRAM verifier does not match the approved credential fingerprint' \
    'Accepted migration 940 preserves verifier-to-fingerprint binding'
check_contains 'test-framework/sql/deployment/scripts/test_phase5_step7_hostile_condition_and_role_races.sh' \
    'Exactly one concurrent activation succeeds' \
    'Accepted Step 7 test preserves activation-race proof'
check_contains 'test-framework/sql/deployment/scripts/test_phase5_step7_hostile_condition_and_role_races.sh' \
    'Expiration-versus-deactivation writes exactly one closure event' \
    'Accepted Step 7 test preserves closure-race proof'
check_contains 'test-framework/sql/deployment/scripts/test_phase5_step7_hostile_condition_and_role_races.sh' \
    'Final break-glass posture is disabled and unprivileged' \
    'Accepted Step 7 test preserves final disabled-posture proof'

printf '\n== Formal acceptance documentation ==\n'

documentation_files=(
    'README.md'
    'docs/README.md'
    'docs/architecture/README.md'
    'docs/architecture/postgresql.md'
    'docs/architecture/foundation/README.md'
    'docs/architecture/foundation/database-security-model.md'
    "$contract"
    'test-framework/sql/tests/README.md'
    'tools/validation/README.md'
    'tools/validation/phase-gates/README.md'
    "$acceptance_record"
)

for file in "${documentation_files[@]}"; do
    check_contains "$file" 'Accepted Phase 5' "$file identifies accepted Phase 5"
done

check_contains README.md \
    'Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.' \
    'Original mission sentence remains exact'
check_contains README.md \
    'Built on purpose. Backed by discipline. Engineered to endure.' \
    'Iron Signal Systems tagline remains exact'
check_contains README.md "$accepted_tag" 'Root README names the accepted tag'
check_contains README.md '97 phase-gate PASS checks' 'Root README preserves the final Step 7 gate count'
check_contains "$contract" '## Phase 5 Step 8 — Formal Acceptance' 'Normative contract records the Step 8 decision'
check_contains "$contract" "$accepted_tag" 'Normative contract names the accepted tag'
check_contains "$step7_record" 'Phase 5 Step 7 is accepted' 'Step 7 implementation record is accepted'
check_not_contains "$step7_record" 'Phase 5 Step 7 candidate.' 'Step 7 implementation record contains no active candidate status'
check_contains 'tools/validation/README.md' 'validate_phase5_step8.sh' 'Validation index points to the formal-acceptance gate'
check_contains 'tools/validation/phase-gates/README.md' '## Active Gate: Phase 5 Step 8' 'Phase-gate index identifies Step 8'

printf '\n== Static script checks ==\n'

if bash -n "$step7_gate"; then
    pass 'Step 7 gate Bash syntax'
else
    fail 'Step 7 gate Bash syntax'
fi

if bash -n tools/validation/phase-gates/validate_phase5_step8.sh; then
    pass 'Step 8 gate Bash syntax'
else
    fail 'Step 8 gate Bash syntax'
fi

printf '\n== Accepted Step 7 predecessor ==\n'

if [[ "$STATIC_ONLY" == true ]]; then
    if "$step7_gate" --static-only; then
        pass 'Phase 5 Step 7 static revalidation passed'
    else
        fail 'Phase 5 Step 7 static revalidation passed'
    fi

    printf '\nStatic-only validation requested; PostgreSQL execution skipped.\n'
else
    if "$step7_gate"; then
        pass 'Phase 5 Step 7 complete revalidation passed'
    else
        fail 'Phase 5 Step 7 complete revalidation passed'
    fi
fi

printf '\n== Final result ==\n'
printf 'PASS checks: %s\n' "$PASS_COUNT"
printf 'FAIL checks: %s\n' "$FAIL_COUNT"

if (( FAIL_COUNT != 0 )); then
    printf '\nPhase 5 Step 8 validation FAILED.\n' >&2
    exit 1
fi

if [[ "$STATIC_ONLY" == true ]]; then
    printf '\nPhase 5 Step 8 static validation PASSED.\n'
else
    printf '\nPhase 5 Step 8 validation PASSED completely.\n'
    printf 'Phase 5 production database security boundary is formally accepted and frozen.\n'
    printf 'Accepted tag: %s\n' "$accepted_tag"
fi
