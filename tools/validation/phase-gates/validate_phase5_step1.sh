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
echo "== Repository and predecessor checks =="

required_files=(
    "README.md"
    "docs/README.md"
    "docs/architecture/README.md"
    "docs/architecture/postgresql.md"
    "docs/architecture/foundation/README.md"
    "docs/architecture/foundation/database-security-model.md"
    "docs/architecture/foundation/production-database-role-ownership-and-runtime-privilege-model.md"
    "docs/architecture/foundation/phase-4-approval-independence-and-separation-of-duties-acceptance.md"
    "sql/schema/manifests/foundation.manifest"
    "test-framework/sql/tests/foundation-tests.manifest"
    "test-framework/sql/tests/foundation-concurrency-tests.manifest"
    "test-framework/sql/tests/README.md"
    "tools/validation/README.md"
    "tools/validation/phase-gates/README.md"
    "tools/validation/phase-gates/validate_phase4_step8.sh"
    "tools/validation/phase-gates/validate_phase5_step1.sh"
)

for file in "${required_files[@]}"; do
    check_file "$file"
done

check_executable "tools/validation/phase-gates/validate_phase4_step8.sh"
check_executable "tools/validation/phase-gates/validate_phase5_step1.sh"

pass "Repository is a Git work tree"

check_equal "$(git branch --show-current)" "dev" "Current branch"

origin_url="$(git remote get-url origin 2>/dev/null || true)"
check_equal \
    "$origin_url" \
    "git@github.com:Iron-Signal-Systems/iron-signal-platform.git" \
    "Canonical origin"

tag="phase-4-approval-independence-and-separation-of-duties-complete-v1"
tag_type="$(git cat-file -t "$tag" 2>/dev/null || true)"
check_equal "$tag_type" "tag" "Phase 4 acceptance tag object type"

tag_commit="$(git rev-parse "${tag}^{commit}" 2>/dev/null || true)"
if [[ "$tag_commit" =~ ^[0-9a-f]{40}$ ]]; then
    pass "Phase 4 acceptance tag resolves to a commit"
else
    fail "Phase 4 acceptance tag resolves to a commit"
fi

if git merge-base --is-ancestor "$tag_commit" HEAD 2>/dev/null; then
    pass "Current dev descends from the accepted Phase 4 tag"
else
    fail "Current dev descends from the accepted Phase 4 tag"
fi

accepted_paths=(
    "sql/schema/migrations/foundation"
    "sql/schema/manifests/foundation.manifest"
    "test-framework/sql/tests/foundation-tests.manifest"
    "test-framework/sql/tests/foundation-concurrency-tests.manifest"
    "test-framework/sql/tests/foundation"
    "test-framework/sql/tests/concurrency"
)

if git diff --quiet "$tag_commit" -- "${accepted_paths[@]}"; then
    pass "Accepted Phase 4 SQL and executable test tree remains unchanged"
else
    fail "Accepted Phase 4 SQL and executable test tree remains unchanged"
fi

echo
echo "== Accepted inventory =="

foundation_migrations="$(
    grep -Ev '^[[:space:]]*(#|$)' \
        sql/schema/manifests/foundation.manifest \
        | wc -l \
        | tr -d ' '
)"
sequential_tests="$(
    grep -Ev '^[[:space:]]*(#|$)' \
        test-framework/sql/tests/foundation-tests.manifest \
        | wc -l \
        | tr -d ' '
)"
concurrency_tests="$(
    grep -Ev '^[[:space:]]*(#|$)' \
        test-framework/sql/tests/foundation-concurrency-tests.manifest \
        | wc -l \
        | tr -d ' '
)"

check_equal "$foundation_migrations" "34" "Foundation manifest migrations"
check_equal "$sequential_tests" "21" "Sequential test files"
check_equal "$concurrency_tests" "16" "Concurrency test files"

if [[ ! -e sql/schema/manifests/deployment.manifest ]]; then
    pass "Step 1 introduces no deployment manifest"
else
    fail "Step 1 introduces no deployment manifest"
fi

if [[ ! -d sql/schema/migrations/deployment ]]; then
    pass "Step 1 introduces no deployment migration directory"
else
    fail "Step 1 introduces no deployment migration directory"
fi

echo
echo "== Phase 5 Step 1 contract =="

model="docs/architecture/foundation/production-database-role-ownership-and-runtime-privilege-model.md"

contract_checks=(
    "Phase 5 Step 1 contract freeze."
    "No production login role may own protected Platform Foundation schemas"
    "issp_database_owner"
    "issp_foundation_owner"
    "issp_extension_owner"
    "issp_migration_executor"
    "issp_runtime"
    "issp_service_<service_key>"
    "issp_writer_<bounded_capability>"
    "issp_read_only_investigator"
    "issp_audit_reader"
    "issp_validation_reader"
    "issp_break_glass"
    "The role-membership graph must be acyclic and reviewable."
    'Foundation schemas are owned by `issp_foundation_owner`'
    "Protected writes must use controlled routines"
    "Default privileges must be established for every role that can create"
    'A security-sensitive `SECURITY DEFINER` routine must:'
    "Production credentials must not be committed to the repository."
    'Deployment and bootstrap SQL belongs in the reserved `900–999` range.'
    "Tests that create cluster roles must use a disposable PostgreSQL cluster"
    "Step 1 — Contract Freeze"
    "Step 8 — Formal Acceptance"
    "Phase 5 Step 1 does not claim:"
)

for pattern in "${contract_checks[@]}"; do
    check_contains "$model" "$pattern" "Contract contains: $pattern"
done

echo
echo "== Documentation synchronization =="

check_contains \
    "README.md" \
    "### Active Phase 5 — Production Database Security Boundary" \
    "Root README identifies active Phase 5"

check_contains \
    "README.md" \
    "Phase 5 Step 1 freezes the production database role, ownership, migration, and runtime-privilege contract." \
    "Root README identifies Step 1 contract"

check_contains \
    "docs/README.md" \
    "## Active Phase 5 Step 1" \
    "Documentation index identifies Phase 5 Step 1"

check_contains \
    "docs/architecture/README.md" \
    "## Active Phase 5 — Production Database Security Boundary" \
    "Architecture index identifies active Phase 5"

check_contains \
    "docs/architecture/foundation/README.md" \
    "## Active Phase 5 Boundary" \
    "Foundation index identifies active Phase 5"

check_contains \
    "docs/architecture/foundation/database-security-model.md" \
    "## Phase 5 Step 1 Role and Ownership Contract" \
    "Database security model identifies Step 1"

check_contains \
    "docs/architecture/postgresql.md" \
    "## Active Phase 5 Database Security Work" \
    "PostgreSQL architecture identifies Phase 5"

check_contains \
    "test-framework/sql/tests/README.md" \
    "## Phase 5 Step 1 Regression Boundary" \
    "Test documentation identifies unchanged regression boundary"

check_contains \
    "tools/validation/README.md" \
    "## Phase 5 Step 1 Gate" \
    "Validation index identifies Phase 5 gate"

check_contains \
    "tools/validation/phase-gates/README.md" \
    "## Phase 5 Step 1" \
    "Phase-gate index identifies Phase 5 Step 1"

check_contains \
    "README.md" \
    "Built on purpose. Backed by discipline. Engineered to endure." \
    "Iron Signal Systems tagline remains present"

check_contains \
    "README.md" \
    "Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency." \
    "Original mission sentence remains present"

echo
echo "== Accepted Phase 4 revalidation =="

if ./tools/validation/phase-gates/validate_phase4_step8.sh --static-only; then
    pass "Phase 4 Step 8 static revalidation passed"
else
    fail "Phase 4 Step 8 static revalidation passed"
fi

if $STATIC_ONLY; then
    echo
    echo "Static-only validation requested; PostgreSQL execution skipped."
else
    echo
    echo "== Complete regression execution =="

    if ./tools/validation/phase-gates/validate_phase4_step8.sh; then
        pass "Phase 4 Step 8 complete regression passed"
    else
        fail "Phase 4 Step 8 complete regression passed"
    fi

    summary="test-framework/sql/test-results/latest-summary.txt"
    resources="test-framework/sql/test-results/latest-resources.txt"
    resources_json="test-framework/sql/test-results/latest-resources.json"

    check_file "$summary"
    check_file "$resources"
    check_file "$resources_json"

    if [[ -f "$summary" ]]; then
        check_contains "$summary" "Correctness result: PASS" \
            "Correctness summary result is PASS"
        check_contains "$summary" "Sequential test files: 21" \
            "Correctness summary has 21 sequential tests"
        check_contains "$summary" "Concurrency test files: 16" \
            "Correctness summary has 16 concurrency tests"
    fi

    if [[ -f "$resources" ]]; then
        check_contains "$resources" "Correctness result: PASS" \
            "Resource report records correctness PASS"
        check_contains "$resources" "Resource observation: RECORDED" \
            "Resource observation is recorded"
        check_contains "$resources" "Performance thresholds: NOT_EVALUATED" \
            "Performance thresholds remain observation-only"
    fi
fi

echo
echo "== Final result =="
echo "PASS checks: $PASS_COUNT"
echo "FAIL checks: $FAIL_COUNT"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
    echo
    echo "Phase 5 Step 1 validation FAILED."
    exit 1
fi

echo
echo "Phase 5 Step 1 validation PASSED completely."
echo "The production database role, ownership, and runtime-privilege contract is frozen."
echo "Phase 5 Step 2 may implement the deployment manifest and PostgreSQL role topology."
