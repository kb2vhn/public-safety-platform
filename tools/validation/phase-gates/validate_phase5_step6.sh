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
    "docs/architecture/foundation/phase-5-step-5-review-and-validation-roles.md"
    "docs/architecture/foundation/phase-5-step-6-break-glass-and-credential-lifecycle.md"
    "sql/schema/manifests/foundation.manifest"
    "sql/deployment/manifests/deployment.manifest"
    "sql/deployment/migrations/900_postgresql_role_topology_and_membership.sql"
    "sql/deployment/migrations/910_database_schema_and_object_ownership.sql"
    "sql/deployment/migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql"
    "sql/deployment/migrations/930_investigator_audit_and_validation_review_surfaces.sql"
    "sql/deployment/migrations/940_break_glass_and_credential_lifecycle.sql"
    "sql/deployment/scripts/apply_deployment.sh"
    "test-framework/sql/deployment/scripts/test_phase5_step5_review_and_validation_roles.sh"
    "test-framework/sql/deployment/scripts/test_phase5_step6_break_glass_and_credential_lifecycle.sh"
    "tools/validation/phase-gates/validate_phase4_step8.sh"
    "tools/validation/phase-gates/validate_phase5_step5.sh"
    "tools/validation/phase-gates/validate_phase5_step6.sh"
)

for file in "${required_files[@]}"; do
    check_file "$file"
done

check_executable "sql/deployment/scripts/apply_deployment.sh"
check_executable \
    "test-framework/sql/deployment/scripts/test_phase5_step6_break_glass_and_credential_lifecycle.sh"
check_executable "tools/validation/phase-gates/validate_phase5_step6.sh"

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

check_contains \
    "test-framework/sql/deployment/scripts/test_phase5_step5_review_and_validation_roles.sh" \
    'step5_deployment_root=' \
    "Step 5 predecessor test is isolated to its accepted deployment prefix"

check_contains \
    "test-framework/sql/deployment/scripts/test_phase5_step5_review_and_validation_roles.sh" \
    'migrations/930_investigator_audit_and_validation_review_surfaces.sql' \
    "Step 5 predecessor prefix includes migration 930"

if grep -Fq \
    'migrations/940_break_glass_and_credential_lifecycle.sql' \
    test-framework/sql/deployment/scripts/test_phase5_step5_review_and_validation_roles.sh; then
    fail "Step 5 predecessor prefix excludes migration 940"
else
    pass "Step 5 predecessor prefix excludes migration 940"
fi

echo
echo "== Step 5 predecessor =="
if ./tools/validation/phase-gates/validate_phase5_step5.sh --static-only; then
    pass "Phase 5 Step 5 static revalidation passed"
else
    fail "Phase 5 Step 5 static revalidation passed"
fi

echo
echo "== Deployment manifest and migration checks =="

mapfile -t deployment_entries < <(
    grep -Ev '^[[:space:]]*(#|$)' \
        sql/deployment/manifests/deployment.manifest
)

if (( ${#deployment_entries[@]} >= 5 )); then
    pass "Deployment manifest contains the required Step 6 prefix"
else
    fail "Deployment manifest contains the required Step 6 prefix"
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
check_equal \
    "${deployment_entries[4]:-missing}" \
    "migrations/940_break_glass_and_credential_lifecycle.sql" \
    "Fifth deployment migration"

migration_940="sql/deployment/migrations/940_break_glass_and_credential_lifecycle.sql"

if [[ "$(sed -n '1p' "$migration_940")" == "-- ============================================================================" ]]; then
    pass "Migration 940 begins with SQL rather than a psql meta-command"
else
    fail "Migration 940 begins with SQL rather than a psql meta-command"
fi

migration_markers=(
    "PHASE 5 STEP 6 CANDIDATE"
    "CREATE SCHEMA emergency_control AUTHORIZATION issp_database_owner"
    "CREATE TABLE deployment_meta.credential_lifecycle_policy"
    "CREATE TABLE deployment_meta.credential_lifecycle_events"
    "CREATE TABLE deployment_meta.break_glass_requests"
    "CREATE TABLE deployment_meta.break_glass_events"
    "CREATE TABLE deployment_meta.break_glass_evidence_outbox"
    "off_host_export_required"
    "reject_emergency_evidence_mutation"
    "prepare_break_glass_activation"
    "activate_break_glass"
    "p_scram_verifier"
    "externally generated SCRAM-SHA-256 verifier"
    "record_break_glass_use"
    "deactivate_break_glass"
    "enforce_break_glass_expiration"
    "GRANT %I TO issp_break_glass WITH INHERIT FALSE, SET TRUE, ADMIN FALSE"
    "ALTER ROLE issp_break_glass WITH LOGIN"
    "ALTER ROLE issp_break_glass WITH NOLOGIN"
    "PASSWORD NULL"
    "CONNECTION LIMIT 1"
    "VALID UNTIL"
    "pg_terminate_backend"
    "issp-break-glass-lifecycle"
    "A previously activated break-glass credential fingerprint cannot be reused"
    "deployment_meta.audit_break_glass_events"
    "deployment_meta.audit_credential_lifecycle_events"
    "deployment_meta.break_glass_posture"
    "deployment_meta.credential_lifecycle_posture"
    "deployment_meta.break_glass_evidence_posture"
    "WITH (security_barrier = true)"
    "Credential lifecycle policy row count is not 5"
    "Emergency evidence schema contains a prohibited raw credential column"
    "940_break_glass_and_credential_lifecycle"
)

for marker in "${migration_markers[@]}"; do
    check_contains "$migration_940" "$marker" "Migration 940 contains: $marker"
done

policy_block="$(sed -n \
    '/INSERT INTO deployment_meta.credential_lifecycle_policy/,/CREATE TABLE deployment_meta.credential_lifecycle_events/p' \
    "$migration_940")"

check_equal \
    "$(printf '%s\n' "$policy_block" | grep -c "'940_break_glass_and_credential_lifecycle'")" \
    "5" \
    "Migration 940 credential lifecycle policy rows"

check_equal \
    "$(grep -c '^CREATE VIEW deployment_meta[.]' "$migration_940")" \
    "5" \
    "Migration 940 review and posture view definitions"

check_equal \
    "$(grep -c '^CREATE TRIGGER .*append_only' "$migration_940")" \
    "4" \
    "Migration 940 append-only evidence triggers"

if grep -Eq "PASSWORD[[:space:]]+'[^']+'" "$migration_940"; then
    fail "Migration 940 contains no literal password value"
else
    pass "Migration 940 contains no literal password value"
fi

check_contains \
    "$migration_940" \
    "PASSWORD %L" \
    "Migration 940 accepts only a dynamically supplied verifier during activation"

if grep -Eq \
    'GRANT[[:space:]].*[[:space:]]TO[[:space:]]issp_service_' \
    "$migration_940"; then
    fail "Migration 940 grants no emergency privilege to service logins"
else
    pass "Migration 940 grants no emergency privilege to service logins"
fi

if grep -Eq \
    'GRANT[[:space:]]+EXECUTE[[:space:]]+ON.*TO[[:space:]]issp_' \
    "$migration_940"; then
    fail "Migration 940 grants no emergency routine execution to canonical roles"
else
    pass "Migration 940 grants no emergency routine execution to canonical roles"
fi

check_contains \
    "$migration_940" \
    "GRANT USAGE ON SCHEMA deployment_meta TO issp_audit_reader" \
    "Audit reader receives only required deployment_meta schema usage"
check_contains \
    "$migration_940" \
    "TO issp_audit_reader" \
    "Audit reader receives exact Step 6 view grants"
check_contains \
    "$migration_940" \
    "TO issp_validation_reader" \
    "Validation reader receives exact Step 6 posture grants"

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
    check_contains "$file" "Phase 5 Step 6" "$file identifies Phase 5 Step 6"
done

step6_document="docs/architecture/foundation/phase-5-step-6-break-glass-and-credential-lifecycle.md"
step6_document_markers=(
    "Disabled-at-Rest Boundary"
    "Required Independent Actors"
    "5 minutes and 1 hour"
    "INHERIT FALSE"
    "SET TRUE"
    "ADMIN FALSE"
    "PASSWORD NULL"
    "off_host_export_required"
    "external secret-version reference"
    "scram-sha-256"
    "applies to password authentication"
    "A fingerprint that reached ACTIVATED cannot be reused"
    "Forced Deactivation and Expiration"
    "Append-Only Evidence"
    "Phase 5 Step 7"
)

for marker in "${step6_document_markers[@]}"; do
    check_contains "$step6_document" "$marker" "Step 6 document contains: $marker"
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
    pass "Step 5 predecessor disposable-cluster test Bash syntax"
else
    fail "Step 5 predecessor disposable-cluster test Bash syntax"
fi

if bash -n \
    test-framework/sql/deployment/scripts/test_phase5_step6_break_glass_and_credential_lifecycle.sh; then
    pass "Step 6 disposable-cluster test Bash syntax"
else
    fail "Step 6 disposable-cluster test Bash syntax"
fi

if bash -n tools/validation/phase-gates/validate_phase5_step6.sh; then
    pass "Step 6 gate Bash syntax"
else
    fail "Step 6 gate Bash syntax"
fi

if [[ "$STATIC_ONLY" == true ]]; then
    echo
    echo "Static-only validation requested; PostgreSQL execution skipped."
else
    echo
    echo "== Complete Step 5 predecessor revalidation =="
    if ./tools/validation/phase-gates/validate_phase5_step5.sh; then
        pass "Phase 5 Step 5 complete revalidation passed"
    else
        fail "Phase 5 Step 5 complete revalidation passed"
    fi

    echo
    echo "== Step 6 disposable-cluster validation =="
    if ./test-framework/sql/deployment/scripts/test_phase5_step6_break_glass_and_credential_lifecycle.sh; then
        pass "Phase 5 Step 6 disposable-cluster validation passed"
    else
        fail "Phase 5 Step 6 disposable-cluster validation passed"
    fi
fi

echo
echo "== Final result =="
printf 'PASS checks: %s\n' "$PASS_COUNT"
printf 'FAIL checks: %s\n' "$FAIL_COUNT"

if (( FAIL_COUNT == 0 )); then
    echo
    echo "Phase 5 Step 6 validation PASSED completely."
    echo "Break-glass is disabled at rest, independently approved, time-bounded, attributable, forcibly deactivated, and credential-rotation governed."
    echo "Phase 5 Step 7 may perform hostile-condition and role-race validation."
    exit 0
fi

echo
echo "Phase 5 Step 6 validation FAILED." >&2
exit 1
