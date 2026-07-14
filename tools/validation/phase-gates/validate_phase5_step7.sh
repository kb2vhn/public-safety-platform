#!/usr/bin/env bash

set -u

PASS_COUNT=0
FAIL_COUNT=0
STATIC_ONLY=false

if [[ "${1:-}" == "--static-only" ]]; then
    STATIC_ONLY=true
elif [[ $# -ne 0 ]]; then
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

check_equal() {
    local actual="$1"
    local expected="$2"
    local description="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$description = $expected"
    else
        fail "$description expected=$expected actual=${actual:-missing}"
    fi
}

check_contains() {
    local file="$1"
    local needle="$2"
    local description="$3"
    if grep -Fq "$needle" "$file"; then
        pass "$description"
    else
        fail "$description"
    fi
}

for command_name in bash git grep sed awk; do
    if command -v "$command_name" >/dev/null 2>&1; then
        :
    else
        echo "Dependency preflight: FAIL ($command_name unavailable)" >&2
        exit 1
    fi
done
echo "Dependency preflight: PASS"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
    echo "FAIL: Repository is a Git work tree" >&2
    exit 1
fi
cd "$repo_root"

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
    "docs/architecture/foundation/phase-5-step-6-break-glass-and-credential-lifecycle.md"
    "docs/architecture/foundation/phase-5-step-7-hostile-condition-and-role-race-validation.md"
    "sql/schema/manifests/foundation.manifest"
    "sql/deployment/manifests/deployment.manifest"
    "sql/deployment/migrations/900_postgresql_role_topology_and_membership.sql"
    "sql/deployment/migrations/910_database_schema_and_object_ownership.sql"
    "sql/deployment/migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql"
    "sql/deployment/migrations/930_investigator_audit_and_validation_review_surfaces.sql"
    "sql/deployment/migrations/940_break_glass_and_credential_lifecycle.sql"
    "sql/deployment/scripts/apply_deployment.sh"
    "test-framework/sql/deployment/scripts/test_phase5_step6_break_glass_and_credential_lifecycle.sh"
    "test-framework/sql/deployment/scripts/test_phase5_step7_hostile_condition_and_role_races.sh"
    "tools/validation/phase-gates/validate_phase4_step8.sh"
    "tools/validation/phase-gates/validate_phase5_step6.sh"
    "tools/validation/phase-gates/validate_phase5_step7.sh"
)
for file in "${required_files[@]}"; do
    check_file "$file"
done

check_executable "sql/deployment/scripts/apply_deployment.sh"
check_executable "test-framework/sql/deployment/scripts/test_phase5_step6_break_glass_and_credential_lifecycle.sh"
check_executable "test-framework/sql/deployment/scripts/test_phase5_step7_hostile_condition_and_role_races.sh"
check_executable "tools/validation/phase-gates/validate_phase5_step7.sh"

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
    "test-framework/sql/deployment/scripts/test_phase5_step6_break_glass_and_credential_lifecycle.sh" \
    'step6_deployment_root=' \
    "Step 6 predecessor test is isolated to its accepted deployment prefix"
check_contains \
    "test-framework/sql/deployment/scripts/test_phase5_step6_break_glass_and_credential_lifecycle.sh" \
    'migrations/940_break_glass_and_credential_lifecycle.sql' \
    "Step 6 predecessor prefix includes migration 940"
if grep -Fq 'migrations/950_' test-framework/sql/deployment/scripts/test_phase5_step6_break_glass_and_credential_lifecycle.sh; then
    fail "Step 6 predecessor prefix excludes later migrations"
else
    pass "Step 6 predecessor prefix excludes later migrations"
fi

echo
echo "== Step 6 predecessor =="
if ./tools/validation/phase-gates/validate_phase5_step6.sh --static-only; then
    pass "Phase 5 Step 6 static revalidation passed"
else
    fail "Phase 5 Step 6 static revalidation passed"
fi

echo
echo "== Pre-freeze hardening and deployment boundary =="
mapfile -t deployment_entries < <(
    grep -Ev '^[[:space:]]*(#|$)' sql/deployment/manifests/deployment.manifest
)
check_equal "${#deployment_entries[@]}" "5" "Deployment manifest remains at the accepted Step 6 boundary"
check_equal "${deployment_entries[0]:-missing}" "migrations/900_postgresql_role_topology_and_membership.sql" "First deployment migration"
check_equal "${deployment_entries[1]:-missing}" "migrations/910_database_schema_and_object_ownership.sql" "Second deployment migration"
check_equal "${deployment_entries[2]:-missing}" "migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql" "Third deployment migration"
check_equal "${deployment_entries[3]:-missing}" "migrations/930_investigator_audit_and_validation_review_surfaces.sql" "Fourth deployment migration"
check_equal "${deployment_entries[4]:-missing}" "migrations/940_break_glass_and_credential_lifecycle.sql" "Fifth deployment migration"

if find sql/deployment/migrations -maxdepth 1 -type f -name '950_*' -print -quit | grep -q .; then
    fail "Step 7 introduces no migration 950"
else
    pass "Step 7 introduces no migration 950"
fi

migration_940="sql/deployment/migrations/940_break_glass_and_credential_lifecycle.sql"
check_contains "$migration_940" "Break-glass SCRAM verifier must use at least 4096 iterations" "Migration 940 enforces the SCRAM iteration floor"
check_contains "$migration_940" "extensions.digest(" "Migration 940 hashes the supplied verifier"
check_contains "$migration_940" "SCRAM verifier does not match the approved credential fingerprint" "Migration 940 binds activation to the approved fingerprint"
check_contains "test-framework/sql/deployment/scripts/test_phase5_step6_break_glass_and_credential_lifecycle.sh" "fingerprint = hashlib.sha256(verifier.encode" "Step 6 test derives fingerprints from ephemeral verifiers"
if grep -Fq 'fingerprint_one="1111111111111111111111111111111111111111111111111111111111111111"' test-framework/sql/deployment/scripts/test_phase5_step6_break_glass_and_credential_lifecycle.sh; then
    fail "Step 6 test no longer uses placeholder fingerprints"
else
    pass "Step 6 test no longer uses placeholder fingerprints"
fi

step7_test="test-framework/sql/deployment/scripts/test_phase5_step7_hostile_condition_and_role_races.sh"
step7_markers=(
    "Concurrent preparation race"
    "Concurrent activation race"
    "Live-session termination and controlled closure"
    "Use recording versus deactivation race"
    "Forced expiration versus deactivation race"
    "Exactly one concurrent preparation succeeds"
    "Exactly one concurrent activation succeeds"
    "Controlled deactivation terminates the active break-glass session"
    "Expiration-versus-deactivation writes exactly one closure event"
    "A fingerprint that reached ACTIVATED cannot be reused"
    "Activation rejects a verifier below the minimum SCRAM iteration count"
    "Activation rejects a verifier that does not match the approved fingerprint"
    "Every break-glass event has one off-host evidence record"
    "PUBLIC cannot execute emergency-control routines"
    "Final break-glass posture is disabled and unprivileged"
    "step7_deployment_root="
    "migrations/940_break_glass_and_credential_lifecycle.sql"
)
for marker in "${step7_markers[@]}"; do
    check_contains "$step7_test" "$marker" "Step 7 test contains: $marker"
done

if grep -Fq 'migrations/950_' "$step7_test"; then
    fail "Step 7 disposable test excludes migration 950"
else
    pass "Step 7 disposable test excludes migration 950"
fi

if grep -Eq 'BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|PGPASSWORD=[^"$]' "$step7_test"; then
    fail "Step 7 test contains no literal credential or private key"
else
    pass "Step 7 test contains no literal credential or private key"
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
    check_contains "$file" "Phase 5 Step 7" "$file identifies Phase 5 Step 7"
done

step7_document="docs/architecture/foundation/phase-5-step-7-hostile-condition-and-role-race-validation.md"
document_markers=(
    "pre-freeze hardening correction"
    'No migration `950` is introduced'
    "cryptographically match the independently approved credential fingerprint"
    "4096 iterations"
    "Concurrent preparation"
    "Concurrent activation"
    "Session termination during deactivation"
    "Use recording versus deactivation"
    "Expiration versus deactivation"
    "off_host_export_required"
    "hostile PostgreSQL superuser"
    "Unix-socket-only disposable PostgreSQL cluster"
    "Phase 5 Step 8"
)
for marker in "${document_markers[@]}"; do
    check_contains "$step7_document" "$marker" "Step 7 document contains: $marker"
done

check_contains \
    "README.md" \
    "Built on purpose. Backed by discipline. Engineered to endure." \
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
if bash -n "$step7_test"; then
    pass "Step 7 disposable-cluster test Bash syntax"
else
    fail "Step 7 disposable-cluster test Bash syntax"
fi
if bash -n tools/validation/phase-gates/validate_phase5_step7.sh; then
    pass "Step 7 gate Bash syntax"
else
    fail "Step 7 gate Bash syntax"
fi

if [[ "$STATIC_ONLY" == true ]]; then
    echo
    echo "Static-only validation requested; PostgreSQL execution skipped."
else
    echo
    echo "== Complete Step 6 predecessor revalidation =="
    if ./tools/validation/phase-gates/validate_phase5_step6.sh; then
        pass "Complete Phase 5 Step 6 predecessor validation passed"
    else
        fail "Complete Phase 5 Step 6 predecessor validation passed"
    fi

    echo
    echo "== Hostile-condition and role-race execution =="
    if ./test-framework/sql/deployment/scripts/test_phase5_step7_hostile_condition_and_role_races.sh; then
        pass "Phase 5 Step 7 hostile-condition and role-race execution passed"
    else
        fail "Phase 5 Step 7 hostile-condition and role-race execution passed"
    fi
fi

echo
echo "== Final result =="
printf 'PASS checks: %s\n' "$PASS_COUNT"
printf 'FAIL checks: %s\n' "$FAIL_COUNT"

if (( FAIL_COUNT == 0 )); then
    echo
    echo "Phase 5 Step 7 validation PASSED completely."
    echo "Hostile inputs and concurrent break-glass lifecycle operations remained deterministic, attributable, and fail-closed."
    echo "Phase 5 Step 8 may formally accept and freeze the production database security boundary."
    exit 0
fi

echo
echo "Phase 5 Step 7 validation FAILED." >&2
exit 1
