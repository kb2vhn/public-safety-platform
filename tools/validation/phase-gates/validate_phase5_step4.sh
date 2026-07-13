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
    "docs/architecture/foundation/phase-5-step-3-ownership-and-default-privileges.md"
    "docs/architecture/foundation/phase-5-step-4-least-privileged-runtime-grants.md"
    "sql/schema/manifests/foundation.manifest"
    "sql/deployment/manifests/deployment.manifest"
    "sql/deployment/migrations/900_postgresql_role_topology_and_membership.sql"
    "sql/deployment/migrations/910_database_schema_and_object_ownership.sql"
    "sql/deployment/migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql"
    "sql/deployment/scripts/apply_deployment.sh"
    "test-framework/sql/deployment/scripts/test_phase5_step3_ownership_and_default_privileges.sh"
    "test-framework/sql/deployment/scripts/test_phase5_step4_runtime_privileges.sh"
    "tools/validation/phase-gates/validate_phase4_step8.sh"
    "tools/validation/phase-gates/validate_phase5_step3.sh"
    "tools/validation/phase-gates/validate_phase5_step4.sh"
)

for file in "${required_files[@]}"; do
    check_file "$file"
done

check_executable "sql/deployment/scripts/apply_deployment.sh"
check_executable \
    "test-framework/sql/deployment/scripts/test_phase5_step4_runtime_privileges.sh"
check_executable "tools/validation/phase-gates/validate_phase5_step4.sh"

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
echo "== Step 3 predecessor =="

if ./tools/validation/phase-gates/validate_phase5_step3.sh --static-only; then
    pass "Phase 5 Step 3 static revalidation passed"
else
    fail "Phase 5 Step 3 static revalidation passed"
fi

echo
echo "== Deployment manifest and migration checks =="

mapfile -t deployment_entries < <(
    grep -Ev '^[[:space:]]*(#|$)' \
        sql/deployment/manifests/deployment.manifest
)

if (( ${#deployment_entries[@]} >= 3 )); then
    pass "Deployment manifest contains the required Step 4 prefix"
else
    fail "Deployment manifest contains the required Step 4 prefix"
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

migration_920="sql/deployment/migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql"

if [[ "$(sed -n '1p' "$migration_920")" == "-- ============================================================================" ]]; then
    pass "Migration 920 begins with SQL rather than a psql meta-command"
else
    fail "Migration 920 begins with SQL rather than a psql meta-command"
fi

migration_markers=(
    "PHASE 5 STEP 4 CANDIDATE"
    "CREATE TABLE deployment_meta.runtime_privilege_contract"
    "Runtime privilege contract row count is not 40"
    "GRANT CONNECT ON DATABASE %I TO issp_runtime"
    "GRANT USAGE ON SCHEMA %I TO %I"
    "ALTER FUNCTION %s SECURITY DEFINER"
    "GRANT EXECUTE ON FUNCTION %s TO %I"
    "integration.claim_outbox_events"
    "FOR UPDATE OF event_record SKIP LOCKED"
    "integration.mark_outbox_event_delivered"
    "integration.reschedule_outbox_event"
    "observability.claim_monitoring_deliveries"
    "FOR UPDATE OF delivery_record SKIP LOCKED"
    "observability.mark_monitoring_delivery_delivered"
    "observability.reschedule_monitoring_delivery"
    "extensions.digest(bytea, text)"
    "A non-owner canonical role received direct relation or sequence privileges"
    "920_least_privileged_runtime_grants_and_controlled_service_apis"
)

for marker in "${migration_markers[@]}"; do
    check_contains "$migration_920" "$marker" \
        "Migration 920 contains: $marker"
done

schema_contract_rows="$(
    grep -Ec \
        "'SCHEMA', '[a-z_]+', 'USAGE', false" \
        "$migration_920"
)"
check_equal "$schema_contract_rows" "8" \
    "Migration 920 schema allowlist rows"

routine_contract_rows="$(
    grep -Ec \
        "'ROUTINE', '[a-z_]+[.][a-z_]+[(]" \
        "$migration_920"
)"
check_equal "$routine_contract_rows" "31" \
    "Migration 920 routine allowlist rows"

if ! grep -Eq \
    'GRANT[[:space:]]+(SELECT|INSERT|UPDATE|DELETE|TRUNCATE|REFERENCES|TRIGGER|USAGE)[[:space:]]+ON[[:space:]]+(TABLE|ALL TABLES|SEQUENCE|ALL SEQUENCES)' \
    "$migration_920"; then
    pass "Migration 920 grants no direct relation or sequence privileges"
else
    fail "Migration 920 grants no direct relation or sequence privileges"
fi

if ! grep -Eq \
    'GRANT[[:space:]]+.*[[:space:]]+TO[[:space:]]+issp_service_' \
    "$migration_920"; then
    pass "Migration 920 grants no object privilege directly to service logins"
else
    fail "Migration 920 grants no object privilege directly to service logins"
fi

if ! grep -Eq \
    'GRANT[[:space:]]+.*[[:space:]]+TO[[:space:]]+(issp_read_only_investigator|issp_audit_reader|issp_validation_reader|issp_break_glass)' \
    "$migration_920"; then
    pass "Migration 920 grants no review or break-glass object privileges"
else
    fail "Migration 920 grants no review or break-glass object privileges"
fi

echo
echo "== Documentation synchronization =="

documentation_checks=(
    "README.md|### Active Phase 5 Step 4 — Least-Privileged Runtime Grants"
    "docs/README.md|## Active Phase 5 Step 4"
    "docs/architecture/README.md|## Active Phase 5 Step 4"
    "docs/architecture/foundation/README.md|## Active Phase 5 Step 4"
    "docs/architecture/postgresql.md|## Phase 5 Step 4 Runtime Privilege Boundary"
    "docs/architecture/foundation/database-security-model.md|## Phase 5 Step 4 Runtime Grant Implementation"
    "docs/architecture/foundation/production-database-role-ownership-and-runtime-privilege-model.md|## Phase 5 Step 4 Implementation Status"
    "test-framework/sql/tests/README.md|## Phase 5 Step 4 Deployment Validation"
    "tools/validation/README.md|## Phase 5 Step 4 Gate"
    "tools/validation/phase-gates/README.md|## Phase 5 Step 4"
    "sql/deployment/migrations/README.md|## Phase 5 Step 4"
)

for item in "${documentation_checks[@]}"; do
    file="${item%%|*}"
    pattern="${item#*|}"
    check_contains "$file" "$pattern" \
        "$file identifies Phase 5 Step 4"
done

step4_doc="docs/architecture/foundation/phase-5-step-4-least-privileged-runtime-grants.md"

step4_doc_markers=(
    "31 routines"
    "40 total rows"
    "No service login receives a direct schema grant."
    "Step 4 grants no direct privileges on protected tables"
    "FOR UPDATE SKIP LOCKED"
    "issp_read_only_investigator"
    "Phase 5 Step 5 implements separately governed investigator"
)

for marker in "${step4_doc_markers[@]}"; do
    check_contains "$step4_doc" "$marker" \
        "Step 4 document contains: $marker"
done

check_contains "README.md" \
    "Built on purpose. Backed by discipline. Engineered to endure." \
    "Iron Signal Systems tagline remains present"

check_contains "README.md" \
    "Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency." \
    "Original mission sentence remains present"

echo
echo "== Static script checks =="

bash -n sql/deployment/scripts/apply_deployment.sh \
    && pass "Deployment runner Bash syntax" \
    || fail "Deployment runner Bash syntax"

bash -n \
    test-framework/sql/deployment/scripts/test_phase5_step4_runtime_privileges.sh \
    && pass "Step 4 disposable-cluster test Bash syntax" \
    || fail "Step 4 disposable-cluster test Bash syntax"

bash -n tools/validation/phase-gates/validate_phase5_step4.sh \
    && pass "Step 4 gate Bash syntax" \
    || fail "Step 4 gate Bash syntax"

if $STATIC_ONLY; then
    echo
    echo "Static-only validation requested; PostgreSQL execution skipped."
else
    echo
    echo "== Accepted Foundation regression =="

    if ./tools/validation/phase-gates/validate_phase4_step8.sh; then
        pass "Phase 4 Step 8 complete regression passed"
    else
        fail "Phase 4 Step 8 complete regression passed"
    fi

    echo
    echo "== Disposable-cluster runtime privilege validation =="

    if ./test-framework/sql/deployment/scripts/test_phase5_step4_runtime_privileges.sh; then
        pass "Phase 5 Step 4 disposable-cluster test passed"
    else
        fail "Phase 5 Step 4 disposable-cluster test passed"
    fi
fi

echo
echo "== Final result =="
echo "PASS checks: $PASS_COUNT"
echo "FAIL checks: $FAIL_COUNT"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
    echo
    echo "Phase 5 Step 4 validation FAILED."
    exit 1
fi

echo
echo "Phase 5 Step 4 validation PASSED completely."
echo "Least-privileged runtime access is restricted to inherited CONNECT, exact schema USAGE, and controlled routine EXECUTE."
echo "Phase 5 Step 5 may implement investigator, audit-reader, and validation-reader access through approved review surfaces."
