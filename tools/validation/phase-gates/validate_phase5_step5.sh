#!/usr/bin/env bash

set -u

PASS_COUNT=0
FAIL_COUNT=0
STATIC_ONLY=false

if [[ "${1:-}" == "--static-only" ]]; then
    STATIC_ONLY=true
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--static-only]" >&2
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
        fail "File exists: $1"
    fi
}

check_executable() {
    if [[ -x "$1" ]]; then
        pass "Executable: $1"
    else
        fail "Executable: $1"
    fi
}

check_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"

    if grep -Fq -- "$pattern" "$file"; then
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
        fail "$label expected=$expected actual=$actual"
    fi
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$repo_root" ]]; then
    echo "FAIL: Repository is a Git work tree" >&2
    exit 1
fi

cd "$repo_root"

echo "Dependency preflight: PASS"
echo
echo "== Repository and frozen-boundary checks =="

required_files=(
    "README.md"
    "docs/README.md"
    "docs/architecture/README.md"
    "docs/architecture/postgresql.md"
    "docs/architecture/foundation/README.md"
    "docs/architecture/foundation/database-security-model.md"
    "docs/architecture/foundation/production-database-role-ownership-and-runtime-privilege-model.md"
    "docs/architecture/foundation/phase-5-step-4-least-privileged-runtime-grants.md"
    "docs/architecture/foundation/phase-5-step-5-review-and-validation-roles.md"
    "sql/schema/manifests/foundation.manifest"
    "sql/deployment/manifests/deployment.manifest"
    "sql/deployment/migrations/900_postgresql_role_topology_and_membership.sql"
    "sql/deployment/migrations/910_database_schema_and_object_ownership.sql"
    "sql/deployment/migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql"
    "sql/deployment/migrations/930_investigator_audit_and_validation_review_surfaces.sql"
    "sql/deployment/scripts/apply_deployment.sh"
    "test-framework/sql/deployment/scripts/test_phase5_step4_runtime_privileges.sh"
    "test-framework/sql/deployment/scripts/test_phase5_step5_review_and_validation_roles.sh"
    "tools/validation/phase-gates/validate_phase4_step8.sh"
    "tools/validation/phase-gates/validate_phase5_step4.sh"
    "tools/validation/phase-gates/validate_phase5_step5.sh"
)

for file in "${required_files[@]}"; do
    check_file "$file"
done

check_executable "sql/deployment/scripts/apply_deployment.sh"
check_executable \
    "test-framework/sql/deployment/scripts/test_phase5_step5_review_and_validation_roles.sh"
check_executable "tools/validation/phase-gates/validate_phase5_step5.sh"

pass "Repository is a Git work tree"
check_equal "$(git branch --show-current)" "dev" "Current branch"
check_equal \
    "$(git remote get-url origin 2>/dev/null || true)" \
    "git@github.com:Iron-Signal-Systems/iron-signal-platform.git" \
    "Canonical origin"

tag="phase-4-approval-independence-and-separation-of-duties-complete-v1"
tag_commit="$(git rev-parse "${tag}^{commit}" 2>/dev/null || true)"

if [[ "$tag_commit" =~ ^[0-9a-f]{40}$ ]]; then
    pass "Phase 4 acceptance tag resolves to a commit"
else
    fail "Phase 4 acceptance tag resolves to a commit"
fi

if git diff --quiet "$tag_commit" -- sql/schema; then
    pass "Frozen Phase 4 sql/schema tree remains unchanged"
else
    fail "Frozen Phase 4 sql/schema tree remains unchanged"
fi

echo
echo "== Step 4 predecessor =="

if ./tools/validation/phase-gates/validate_phase5_step4.sh --static-only; then
    pass "Phase 5 Step 4 static revalidation passed"
else
    fail "Phase 5 Step 4 static revalidation passed"
fi

echo
echo "== Deployment manifest and migration checks =="

mapfile -t deployment_entries < <(
    grep -Ev '^[[:space:]]*(#|$)' \
        sql/deployment/manifests/deployment.manifest
)

if (( ${#deployment_entries[@]} >= 4 )); then
    pass "Deployment manifest contains the required Step 5 prefix"
else
    fail "Deployment manifest contains the required Step 5 prefix"
fi

check_equal \
    "${deployment_entries[0]:-missing}" \
    "migrations/900_postgresql_role_topology_and_membership.sql" \
    "First deployment migration"

check_equal \
    "${deployment_entries[1]:-missing}" \
    "migrations/910_database_schema_and_object_ownership.sql" \
    "Second deployment migration"

check_equal \
    "${deployment_entries[2]:-missing}" \
    "migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql" \
    "Third deployment migration"

check_equal \
    "${deployment_entries[3]:-missing}" \
    "migrations/930_investigator_audit_and_validation_review_surfaces.sql" \
    "Fourth deployment migration"

migration_930="sql/deployment/migrations/930_investigator_audit_and_validation_review_surfaces.sql"

if [[ "$(sed -n '1p' "$migration_930")" == "-- ============================================================================" ]]; then
    pass "Migration 930 begins with SQL rather than a psql meta-command"
else
    fail "Migration 930 begins with SQL rather than a psql meta-command"
fi

migration_markers=(
    "PHASE 5 STEP 5 CANDIDATE"
    "CREATE SCHEMA security_review AUTHORIZATION issp_foundation_owner"
    "CREATE TABLE deployment_meta.review_privilege_contract"
    "Review privilege contract row count is not 40"
    "security_review.investigator_decision_summary"
    "security_review.investigator_approval_summary"
    "security_review.audit_decision_records"
    "security_review.audit_decision_evaluations"
    "security_review.audit_approval_requests"
    "security_review.audit_approval_actions"
    "security_review.audit_approval_stage_evaluations"
    "security_review.audit_session_events"
    "security_review.audit_authorization_lease_events"
    "security_review.audit_lifecycle_events"
    "deployment_meta.deployment_migration_status"
    "deployment_meta.canonical_role_posture"
    "deployment_meta.canonical_membership_posture"
    "deployment_meta.review_privilege_contract_summary"
    "WITH (security_barrier = true)"
    "A review role received direct protected base-table privileges"
    "A review role received protected routine EXECUTE privilege"
    "An investigator view exposes a prohibited direct-identifier or raw-context column"
    "An audit view exposes prohibited secret or raw-context material"
    "930_investigator_audit_and_validation_review_surfaces"
)

for marker in "${migration_markers[@]}"; do
    check_contains "$migration_930" "$marker" "Migration 930 contains: $marker"
done

check_equal \
    "$(grep -c '^CREATE VIEW security_review[.]' "$migration_930")" \
    "10" \
    "Migration 930 security_review view definitions"

check_equal \
    "$(grep -c '^CREATE VIEW deployment_meta[.]' "$migration_930")" \
    "4" \
    "Migration 930 deployment posture view definitions"

contract_block="$(sed -n \
    '/INSERT INTO deployment_meta.review_privilege_contract/,/DO \$validate_review_contract_count\$/p' \
    "$migration_930")"

check_equal \
    "$(printf '%s\n' "$contract_block" | grep -c "'930_investigator_audit_and_validation_review_surfaces'")" \
    "40" \
    "Migration 930 review privilege contract rows"

check_equal \
    "$(printf '%s\n' "$contract_block" | grep -c "'DATABASE',")" \
    "3" \
    "Migration 930 database allowlist rows"

check_equal \
    "$(printf '%s\n' "$contract_block" | grep -c "'SCHEMA',")" \
    "4" \
    "Migration 930 schema allowlist rows"

check_equal \
    "$(printf '%s\n' "$contract_block" | grep -c "'VIEW',")" \
    "33" \
    "Migration 930 view allowlist rows"

if grep -Eq \
    'GRANT[[:space:]]+(INSERT|UPDATE|DELETE|TRUNCATE|REFERENCES|TRIGGER)' \
    "$migration_930"; then
    fail "Migration 930 grants no mutation privilege"
else
    pass "Migration 930 grants no mutation privilege"
fi

if grep -Eq \
    'GRANT[[:space:]]+(USAGE|SELECT|UPDATE)[[:space:]]+ON[[:space:]]+SEQUENCE' \
    "$migration_930"; then
    fail "Migration 930 grants no sequence privilege"
else
    pass "Migration 930 grants no sequence privilege"
fi

if grep -Eq \
    'GRANT[[:space:]]+EXECUTE[[:space:]]+ON' \
    "$migration_930"; then
    fail "Migration 930 grants no routine execution"
else
    pass "Migration 930 grants no routine execution"
fi

if grep -Eq \
    'GRANT[[:space:]].*[[:space:]]TO[[:space:]]issp_service_' \
    "$migration_930"; then
    fail "Migration 930 grants no review privilege directly to service logins"
else
    pass "Migration 930 grants no review privilege directly to service logins"
fi

echo
echo "== Documentation synchronization =="

documentation_files=(
    "README.md"
    "docs/README.md"
    "docs/architecture/README.md"
    "docs/architecture/postgresql.md"
    "docs/architecture/foundation/README.md"
    "docs/architecture/foundation/database-security-model.md"
    "docs/architecture/foundation/production-database-role-ownership-and-runtime-privilege-model.md"
    "test-framework/sql/tests/README.md"
    "tools/validation/README.md"
    "tools/validation/phase-gates/README.md"
    "sql/deployment/migrations/README.md"
)

for file in "${documentation_files[@]}"; do
    check_contains "$file" "Phase 5 Step 5" "$file identifies Phase 5 Step 5"
done

step5_document="docs/architecture/foundation/phase-5-step-5-review-and-validation-roles.md"

step5_document_markers=(
    "40-row review privilege contract"
    "2 reduced-disclosure investigator views"
    "8 audit-lineage views"
    "23 validation-posture views"
    "No review role receives direct protected base-table access"
    "security_barrier"
    "issp_read_only_investigator"
    "issp_audit_reader"
    "issp_validation_reader"
    "Phase 5 Step 6"
)

for marker in "${step5_document_markers[@]}"; do
    check_contains "$step5_document" "$marker" "Step 5 document contains: $marker"
done

check_contains \
    "README.md" \
    "Iron Signal Systems" \
    "Iron Signal Systems tagline remains present"

check_contains \
    "README.md" \
    "Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency." \
    "Original mission sentence remains present"

echo
echo "== Static script checks =="

if bash -n sql/deployment/scripts/apply_deployment.sh; then
    pass "Deployment runner Bash syntax"
else
    fail "Deployment runner Bash syntax"
fi

if bash -n \
    test-framework/sql/deployment/scripts/test_phase5_step5_review_and_validation_roles.sh; then
    pass "Step 5 disposable-cluster test Bash syntax"
else
    fail "Step 5 disposable-cluster test Bash syntax"
fi

if bash -n tools/validation/phase-gates/validate_phase5_step5.sh; then
    pass "Step 5 gate Bash syntax"
else
    fail "Step 5 gate Bash syntax"
fi

if [[ "$STATIC_ONLY" == true ]]; then
    echo
    echo "Static-only validation requested; PostgreSQL execution skipped."
else
    echo
    echo "== Complete Step 4 predecessor revalidation =="

    if ./tools/validation/phase-gates/validate_phase5_step4.sh; then
        pass "Phase 5 Step 4 complete revalidation passed"
    else
        fail "Phase 5 Step 4 complete revalidation passed"
    fi

    echo
    echo "== Step 5 disposable-cluster validation =="

    if ./test-framework/sql/deployment/scripts/test_phase5_step5_review_and_validation_roles.sh; then
        pass "Phase 5 Step 5 disposable-cluster validation passed"
    else
        fail "Phase 5 Step 5 disposable-cluster validation passed"
    fi
fi

echo
echo "== Final result =="
printf 'PASS checks: %s\n' "$PASS_COUNT"
printf 'FAIL checks: %s\n' "$FAIL_COUNT"

if (( FAIL_COUNT == 0 )); then
    echo
    echo "Phase 5 Step 5 validation PASSED completely."
    echo "Investigator, audit-reader, and validation-reader access is restricted to exact approved review views."
    echo "Phase 5 Step 6 may implement disabled-at-rest break-glass activation and credential lifecycle controls."
    exit 0
fi

echo
echo "Phase 5 Step 5 validation FAILED." >&2
exit 1
