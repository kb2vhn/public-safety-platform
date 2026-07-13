#!/usr/bin/env bash
#
# Iron Signal Platform Phase 5 Step 2 gate

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

check_absent() {
    local file="$1"
    local pattern="$2"
    local label="$3"

    if grep -Eq -- "$pattern" "$file"; then
        fail "$label"
    else
        pass "$label"
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
echo "== Repository and predecessor checks =="

required_files=(
    "README.md"
    "docs/README.md"
    "docs/architecture/README.md"
    "docs/architecture/postgresql.md"
    "docs/architecture/foundation/README.md"
    "docs/architecture/foundation/database-security-model.md"
    "docs/architecture/foundation/production-database-role-ownership-and-runtime-privilege-model.md"
    "docs/architecture/foundation/phase-5-step-2-deployment-role-topology.md"
    "sql/schema/manifests/foundation.manifest"
    "sql/deployment/manifests/deployment.manifest"
    "sql/deployment/migrations/README.md"
    "sql/deployment/migrations/900_postgresql_role_topology_and_membership.sql"
    "sql/deployment/scripts/apply_deployment.sh"
    "tools/validation/validate_foundation_database_parity.sh"
    "test-framework/sql/deployment/scripts/test_phase5_step2_role_topology.sh"
    "test-framework/sql/tests/README.md"
    "tools/validation/README.md"
    "tools/validation/phase-gates/README.md"
    "tools/validation/phase-gates/validate_phase5_step1.sh"
    "tools/validation/phase-gates/validate_phase5_step2.sh"
)

for file in "${required_files[@]}"; do
    check_file "$file"
done

for file in \
    "sql/deployment/scripts/apply_deployment.sh" \
    "tools/validation/validate_foundation_database_parity.sh" \
    "test-framework/sql/deployment/scripts/test_phase5_step2_role_topology.sh" \
    "tools/validation/phase-gates/validate_phase5_step1.sh" \
    "tools/validation/phase-gates/validate_phase5_step2.sh"
do
    check_executable "$file"
done

pass "Repository is a Git work tree"
check_equal "$(git branch --show-current)" "dev" "Current branch"

origin_url="$(git remote get-url origin 2>/dev/null || true)"
check_equal \
    "$origin_url" \
    "git@github.com:Iron-Signal-Systems/iron-signal-platform.git" \
    "Canonical origin"

check_contains \
    "tools/validation/validate_foundation_database_parity.sh" \
    "ISSP_FOUNDATION_REPOSITORY_DATABASE_PARITY_V1" \
    "Foundation repository/database parity tool is present"

accepted_tag="phase-4-approval-independence-and-separation-of-duties-complete-v1"
accepted_commit="$(git rev-parse "${accepted_tag}^{commit}" 2>/dev/null || true)"

if [[ "$accepted_commit" =~ ^[0-9a-f]{40}$ ]]; then
    pass "Accepted Phase 4 tag resolves to a commit"
else
    fail "Accepted Phase 4 tag resolves to a commit"
fi

accepted_paths=(
    "sql/schema/migrations/foundation"
    "sql/schema/manifests/foundation.manifest"
    "test-framework/sql/tests/foundation-tests.manifest"
    "test-framework/sql/tests/foundation-concurrency-tests.manifest"
    "test-framework/sql/tests/foundation"
    "test-framework/sql/tests/concurrency"
)

if git diff --quiet "$accepted_commit" -- "${accepted_paths[@]}"; then
    pass "Accepted Phase 4 SQL and executable test tree remains unchanged"
else
    fail "Accepted Phase 4 SQL and executable test tree remains unchanged"
fi

echo
echo "== Script syntax and manifest contract =="

for shell_file in \
    "sql/deployment/scripts/apply_deployment.sh" \
    "test-framework/sql/deployment/scripts/test_phase5_step2_role_topology.sh" \
    "tools/validation/phase-gates/validate_phase5_step2.sh"
do
    if bash -n "$shell_file"; then
        pass "Bash syntax: $shell_file"
    else
        fail "Bash syntax: $shell_file"
    fi
done

foundation_count="$(
    grep -Ev '^[[:space:]]*(#|$)' \
        sql/schema/manifests/foundation.manifest \
        | wc -l \
        | tr -d ' '
)"

deployment_count="$(
    grep -Ev '^[[:space:]]*(#|$)' \
        sql/deployment/manifests/deployment.manifest \
        | wc -l \
        | tr -d ' '
)"

check_equal "$foundation_count" "34" "Foundation manifest migrations"
check_equal "$deployment_count" "1" "Deployment manifest migrations"

check_equal \
    "$(grep -Ev '^[[:space:]]*(#|$)' sql/deployment/manifests/deployment.manifest)" \
    "migrations/900_postgresql_role_topology_and_membership.sql" \
    "Deployment manifest entry"

migration="sql/deployment/migrations/900_postgresql_role_topology_and_membership.sql"

check_contains "$migration" "SET LOCAL lock_timeout = '5s';" \
    "Deployment migration preserves five-second lock timeout"
check_contains "$migration" "SET LOCAL statement_timeout = '1min';" \
    "Deployment migration preserves one-minute statement timeout"
check_contains "$migration" "SET LOCAL idle_in_transaction_session_timeout = '1min';" \
    "Deployment migration preserves one-minute idle-transaction timeout"
check_contains "$migration" "deployment_meta.applied_deployment_migrations" \
    "Deployment migration creates an independent migration registry"
check_contains "$migration" "p_migration_checksum => :'deployment_migration_checksum'" \
    "Deployment migration registers its exact SHA-256 checksum"
check_contains "$migration" "PASSWORD NULL" \
    "Login roles are created without repository-provisioned passwords"
check_contains "$migration" "WITH INHERIT TRUE" \
    "Capability memberships explicitly inherit"
check_contains "$migration" "WITH SET FALSE" \
    "Capability memberships prohibit SET ROLE"
check_contains "$migration" "WITH ADMIN FALSE" \
    "Capability memberships prohibit membership administration"
check_contains "$migration" "Unexpected membership involving a canonical Iron Signal Platform role" \
    "Migration rejects unexpected canonical memberships"
check_contains "$migration" "Phase 5 Step 2 must not transfer current database ownership" \
    "Migration rejects premature database ownership transfer"
check_contains "$migration" "Phase 5 Step 2 must not transfer schema ownership" \
    "Migration rejects premature schema ownership transfer"

canonical_roles=(
    "issp_database_owner"
    "issp_foundation_owner"
    "issp_extension_owner"
    "issp_migration_executor"
    "issp_runtime"
    "issp_writer_authentication_assertion"
    "issp_writer_session_control"
    "issp_writer_authorization_decision"
    "issp_writer_approval"
    "issp_writer_integration_delivery"
    "issp_writer_monitoring_delivery"
    "issp_read_only_investigator"
    "issp_audit_reader"
    "issp_validation_reader"
    "issp_break_glass"
    "issp_service_authorization"
    "issp_service_integration_delivery"
    "issp_service_monitoring_delivery"
)

for role_name in "${canonical_roles[@]}"; do
    check_contains "$migration" "'$role_name'" \
        "Canonical role is declared: $role_name"
done

check_equal "${#canonical_roles[@]}" "18" "Canonical role inventory"

check_absent \
    "$migration" \
    "PASSWORD[[:space:]]+'" \
    "Deployment migration contains no literal password"

check_absent \
    "$migration" \
    'ALTER[[:space:]]+(DATABASE|SCHEMA|TABLE|SEQUENCE|FUNCTION|PROCEDURE|ROUTINE|EXTENSION).*[[:space:]]OWNER[[:space:]]+TO[[:space:]]+issp_' \
    "Step 2 performs no canonical object ownership transfer"

check_absent \
    "$migration" \
    'GRANT[[:space:]]+.*[[:space:]]ON[[:space:]].*[[:space:]]TO[[:space:]]+issp_' \
    "Step 2 grants no object privilege to canonical roles"

check_contains \
    "test-framework/sql/deployment/scripts/test_phase5_step2_role_topology.sh" \
    "initdb" \
    "Role tests create a disposable PostgreSQL cluster"
check_contains \
    "test-framework/sql/deployment/scripts/test_phase5_step2_role_topology.sh" \
    "listen_addresses = ''" \
    "Disposable cluster disables TCP listening"
check_contains \
    "test-framework/sql/deployment/scripts/test_phase5_step2_role_topology.sh" \
    "Break-glass role cannot log in at rest" \
    "Disposable test proves disabled break-glass"
check_contains \
    "test-framework/sql/deployment/scripts/test_phase5_step2_role_topology.sh" \
    "Migration executor has no standing Foundation-owner transition" \
    "Disposable test proves migration-owner separation"

echo
echo "== Documentation synchronization =="

check_contains "README.md" "### Active Phase 5 Step 2 — Deployment Role Topology" \
    "Root README identifies Phase 5 Step 2"
check_contains "docs/README.md" "## Active Phase 5 Step 2" \
    "Documentation index identifies Phase 5 Step 2"
check_contains "docs/architecture/README.md" "## Active Phase 5 Step 2" \
    "Architecture index identifies Phase 5 Step 2"
check_contains "docs/architecture/foundation/README.md" "## Phase 5 Step 2 Implementation" \
    "Foundation index identifies Step 2 implementation"
check_contains "docs/architecture/foundation/database-security-model.md" "## Phase 5 Step 2 Role Topology" \
    "Database security model identifies Step 2"
check_contains "docs/architecture/postgresql.md" "## Phase 5 Step 2 Deployment Role Topology" \
    "PostgreSQL architecture identifies Step 2"
check_contains "test-framework/sql/tests/README.md" "## Phase 5 Step 2 Disposable-Cluster Tests" \
    "Test documentation identifies disposable role tests"
check_contains "tools/validation/README.md" "## Phase 5 Step 2 Gate" \
    "Validation index identifies Step 2 gate"
check_contains "tools/validation/phase-gates/README.md" "## Phase 5 Step 2" \
    "Phase-gate index identifies Step 2"
check_contains \
    "docs/architecture/foundation/production-database-role-ownership-and-runtime-privilege-model.md" \
    "## Phase 5 Step 2 Implementation Status" \
    "Normative role model records Step 2 implementation status"

echo
echo "== Phase 5 Step 1 predecessor revalidation =="

if ./tools/validation/phase-gates/validate_phase5_step1.sh --static-only; then
    pass "Phase 5 Step 1 static revalidation passed"
else
    fail "Phase 5 Step 1 static revalidation passed"
fi

if $STATIC_ONLY; then
    echo
    echo "Static-only validation requested; PostgreSQL execution skipped."
else
    echo
    echo "== Complete Foundation regression =="

    if ./tools/validation/phase-gates/validate_phase5_step1.sh; then
        pass "Phase 5 Step 1 complete regression passed"
    else
        fail "Phase 5 Step 1 complete regression passed"
    fi

    echo
    echo "== Disposable PostgreSQL role-topology execution =="

    if ./test-framework/sql/deployment/scripts/test_phase5_step2_role_topology.sh; then
        pass "Phase 5 Step 2 disposable role-topology test passed"
    else
        fail "Phase 5 Step 2 disposable role-topology test passed"
    fi
fi

echo
echo "== Final result =="
echo "PASS checks: $PASS_COUNT"
echo "FAIL checks: $FAIL_COUNT"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
    echo
    echo "Phase 5 Step 2 validation FAILED."
    exit 1
fi

echo
echo "Phase 5 Step 2 validation PASSED completely."
echo "The deployment manifest and PostgreSQL role topology are implemented."
echo "Phase 5 Step 3 may transfer ownership and establish creator-specific default privileges."
