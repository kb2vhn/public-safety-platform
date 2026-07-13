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
    "docs/architecture/foundation/phase-5-step-2-deployment-role-topology.md"
    "docs/architecture/foundation/phase-5-step-3-ownership-and-default-privileges.md"
    "sql/schema/manifests/foundation.manifest"
    "sql/deployment/manifests/deployment.manifest"
    "sql/deployment/migrations/900_postgresql_role_topology_and_membership.sql"
    "sql/deployment/migrations/910_database_schema_and_object_ownership.sql"
    "sql/deployment/scripts/apply_deployment.sh"
    "test-framework/sql/deployment/scripts/test_phase5_step2_role_topology.sh"
    "test-framework/sql/deployment/scripts/test_phase5_step3_ownership_and_default_privileges.sh"
    "tools/validation/phase-gates/validate_phase4_step8.sh"
    "tools/validation/phase-gates/validate_phase5_step2.sh"
    "tools/validation/phase-gates/validate_phase5_step3.sh"
)

for file in "${required_files[@]}"; do
    check_file "$file"
done

check_executable "sql/deployment/scripts/apply_deployment.sh"
check_executable \
    "test-framework/sql/deployment/scripts/test_phase5_step3_ownership_and_default_privileges.sh"
check_executable "tools/validation/phase-gates/validate_phase5_step3.sh"

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
echo "== Manifest and migration checks =="

mapfile -t deployment_entries < <(
    grep -Ev '^[[:space:]]*(#|$)' \
        sql/deployment/manifests/deployment.manifest
)

if (( ${#deployment_entries[@]} >= 2 )); then
    pass "Deployment manifest contains the required Step 3 prefix"
else
    fail "Deployment manifest contains the required Step 3 prefix"
fi

check_equal \
    "${deployment_entries[0]:-missing}" \
    "migrations/900_postgresql_role_topology_and_membership.sql" \
    "First deployment migration"

check_equal \
    "${deployment_entries[1]:-missing}" \
    "migrations/910_database_schema_and_object_ownership.sql" \
    "Second deployment migration"

migration_900="sql/deployment/migrations/900_postgresql_role_topology_and_membership.sql"
migration_910="sql/deployment/migrations/910_database_schema_and_object_ownership.sql"

check_contains "$migration_900" \
    "PHASE 5 STEP 2 CANDIDATE" \
    "Migration 900 remains the Step 2 role topology"

check_contains "$migration_900" \
    "issp_database_owner" \
    "Migration 900 retains database owner role"

check_contains "$migration_900" \
    "issp_foundation_owner" \
    "Migration 900 retains Foundation owner role"

check_contains "$migration_900" \
    "issp_extension_owner" \
    "Migration 900 retains extension owner role"

step3_markers=(
    "PHASE 5 STEP 3 CANDIDATE"
    "ALTER DATABASE %I OWNER TO issp_database_owner"
    "'extensions'::text, 'issp_extension_owner'::name"
    "'deployment_meta'::text, 'issp_database_owner'::name"
    "'foundation_meta'::text, 'issp_foundation_owner'::name"
    "ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE ALL PRIVILEGES ON ROUTINES FROM PUBLIC"
    "ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE ALL PRIVILEGES ON TYPES FROM PUBLIC"
    "REVOKE ALL PRIVILEGES ON DATABASE %I FROM PUBLIC"
    "CREATE TABLE deployment_meta.ownership_exceptions"
    "PostgreSQL 18 does not provide ALTER EXTENSION OWNER"
    "review_required_before_production"
    "910_database_schema_and_object_ownership"
)

for marker in "${step3_markers[@]}"; do
    check_contains "$migration_910" "$marker" \
        "Migration 910 contains: $marker"
done

if ! grep -Eq \
    'GRANT[[:space:]]+issp_(database|foundation|extension)_owner[[:space:]]+TO' \
    "$migration_910"
then
    pass "Migration 910 creates no standing owner-role membership"
else
    fail "Migration 910 creates no standing owner-role membership"
fi

if ! grep -Eq \
    'GRANT[[:space:]]+.*(issp_runtime|issp_service_|issp_writer_)' \
    "$migration_910"
then
    pass "Migration 910 grants no runtime object privileges"
else
    fail "Migration 910 grants no runtime object privileges"
fi

if ! grep -Fq "UPDATE pg_catalog.pg_extension" "$migration_910" \
   && ! grep -Fq "UPDATE pg_extension" "$migration_910"
then
    pass "Migration 910 does not modify PostgreSQL extension catalogs directly"
else
    fail "Migration 910 does not modify PostgreSQL extension catalogs directly"
fi

echo
echo "== Documentation synchronization =="

documentation_checks=(
    "README.md|### Active Phase 5 Step 3 — Ownership and Default Privileges"
    "docs/README.md|## Active Phase 5 Step 3"
    "docs/architecture/README.md|## Active Phase 5 Step 3"
    "docs/architecture/foundation/README.md|## Active Phase 5 Step 3"
    "docs/architecture/postgresql.md|## Phase 5 Step 3 Ownership Boundary"
    "docs/architecture/foundation/database-security-model.md|## Phase 5 Step 3 Ownership Implementation"
    "test-framework/sql/tests/README.md|## Phase 5 Step 3 Deployment Validation"
    "tools/validation/README.md|## Phase 5 Step 3 Gate"
    "tools/validation/phase-gates/README.md|## Phase 5 Step 3"
    "sql/deployment/migrations/README.md|## Phase 5 Step 3"
)

for item in "${documentation_checks[@]}"; do
    file="${item%%|*}"
    pattern="${item#*|}"
    check_contains "$file" "$pattern" "$file identifies Phase 5 Step 3"
done

step3_doc="docs/architecture/foundation/phase-5-step-3-ownership-and-default-privileges.md"

doc_markers=(
    "Current Iron Signal Platform database"
    "issp_database_owner"
    "issp_foundation_owner"
    "issp_extension_owner"
    "Creator-Specific Default Privileges"
    "PostgreSQL Extension Catalog-Owner Limitation"
    "Direct catalog modification is prohibited."
    "Phase 5 Step 4 grants only the minimum approved database"
)

for marker in "${doc_markers[@]}"; do
    check_contains "$step3_doc" "$marker" \
        "Step 3 document contains: $marker"
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
    test-framework/sql/deployment/scripts/test_phase5_step3_ownership_and_default_privileges.sh \
    && pass "Step 3 disposable-cluster test Bash syntax" \
    || fail "Step 3 disposable-cluster test Bash syntax"

bash -n tools/validation/phase-gates/validate_phase5_step3.sh \
    && pass "Step 3 gate Bash syntax" \
    || fail "Step 3 gate Bash syntax"

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
    echo "== Disposable-cluster ownership validation =="

    if ./test-framework/sql/deployment/scripts/test_phase5_step3_ownership_and_default_privileges.sh; then
        pass "Phase 5 Step 3 disposable-cluster test passed"
    else
        fail "Phase 5 Step 3 disposable-cluster test passed"
    fi
fi

echo
echo "== Final result =="
echo "PASS checks: $PASS_COUNT"
echo "FAIL checks: $FAIL_COUNT"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
    echo
    echo "Phase 5 Step 3 validation FAILED."
    exit 1
fi

echo
echo "Phase 5 Step 3 validation PASSED completely."
echo "Protected database ownership and creator-specific default privileges are implemented."
echo "Phase 5 Step 4 may grant least-privileged runtime access to controlled APIs and approved read surfaces."
