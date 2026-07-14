#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
    printf 'Dependency preflight: FAIL (not a Git work tree)\n' >&2
    exit 1
fi
cd "$repo_root"

static_only=false
if [[ "${1:-}" == "--static-only" ]]; then
    static_only=true
elif [[ $# -gt 0 ]]; then
    printf 'Usage: %s [--static-only]\n' "$0" >&2
    exit 2
fi

pass_count=0
fail_count=0

pass() {
    printf 'PASS: %s\n' "$1"
    pass_count=$((pass_count + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1"
    fail_count=$((fail_count + 1))
}

require_command() {
    local command_name="$1"
    if command -v "$command_name" >/dev/null 2>&1; then
        pass "Command available: $command_name"
    else
        fail "Command available: $command_name"
    fi
}

require_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        pass "File exists: $file_path"
    else
        fail "File exists: $file_path"
    fi
}

require_executable() {
    local file_path="$1"
    if [[ -x "$file_path" ]]; then
        pass "Executable: $file_path"
    else
        fail "Executable: $file_path"
    fi
}

require_text() {
    local file_path="$1"
    local expected="$2"
    local label="$3"
    if grep -Fq -- "$expected" "$file_path"; then
        pass "$label"
    else
        fail "$label"
    fi
}

phase5_tag="phase-5-production-database-security-boundary-complete-v1"
phase5_commit="9f8dbf9d909ef157df72b12511b165a689559093"
phase4_tag="phase-4-approval-independence-and-separation-of-duties-complete-v1"

printf 'Dependency preflight: PASS\n'

printf '\n== Repository and accepted predecessor ==\n'
require_command git
require_command grep
require_command find
require_command bash

for file_path in \
    README.md \
    docs/README.md \
    docs/architecture/README.md \
    docs/architecture/backend-services/README.md \
    docs/architecture/backend-services/production-go-service-boundary-and-runtime-model.md \
    docs/architecture/backend-services/phase-6-step-1-production-go-service-contract.md \
    go/README.md \
    tools/validation/README.md \
    tools/validation/phase-gates/README.md \
    tools/validation/phase-gates/validate_phase5_step8.sh \
    tools/validation/phase-gates/validate_phase6_step1.sh
 do
    require_file "$file_path"
 done

require_executable tools/validation/phase-gates/validate_phase6_step1.sh

if [[ "$(git branch --show-current)" == "dev" ]]; then
    pass "Current branch = dev"
else
    fail "Current branch = dev"
fi

origin_url="$(git remote get-url origin 2>/dev/null || true)"
case "$origin_url" in
    git@github.com:Iron-Signal-Systems/iron-signal-platform.git|https://github.com/Iron-Signal-Systems/iron-signal-platform.git)
        pass "Canonical Iron Signal Systems origin configured"
        ;;
    *)
        fail "Canonical Iron Signal Systems origin configured"
        ;;
esac

if [[ "$(git cat-file -t "$phase5_tag" 2>/dev/null || true)" == "tag" ]]; then
    pass "Phase 5 acceptance reference is an annotated tag"
else
    fail "Phase 5 acceptance reference is an annotated tag"
fi

resolved_phase5="$(git rev-parse "${phase5_tag}^{commit}" 2>/dev/null || true)"
if [[ "$resolved_phase5" == "$phase5_commit" ]]; then
    pass "Phase 5 tag targets the exact accepted implementation commit"
else
    fail "Phase 5 tag targets the exact accepted implementation commit"
fi

if git merge-base --is-ancestor "$phase5_commit" HEAD 2>/dev/null; then
    pass "Current dev tree descends from accepted Phase 5"
else
    fail "Current dev tree descends from accepted Phase 5"
fi

if [[ "$(git cat-file -t "$phase4_tag" 2>/dev/null || true)" == "tag" ]]; then
    pass "Phase 4 acceptance tag remains available"
else
    fail "Phase 4 acceptance tag remains available"
fi

printf '\n== Frozen implementation integrity ==\n'

if git diff --quiet "$phase5_commit" -- sql/deployment; then
    pass "Accepted Phase 5 deployment tree remains unchanged"
else
    fail "Accepted Phase 5 deployment tree remains unchanged"
fi

if git diff --quiet "$phase5_commit" -- test-framework/sql/deployment; then
    pass "Accepted Phase 5 deployment test tree remains unchanged"
else
    fail "Accepted Phase 5 deployment test tree remains unchanged"
fi

phase5_gate_paths=()
for step in 1 2 3 4 5 6 7; do
    phase5_gate_paths+=("tools/validation/phase-gates/validate_phase5_step${step}.sh")
done

if git diff --quiet "$phase5_commit" -- "${phase5_gate_paths[@]}"; then
    pass "Accepted Phase 5 executable implementation gates remain unchanged"
else
    fail "Accepted Phase 5 executable implementation gates remain unchanged"
fi

phase4_commit="$(git rev-parse "${phase4_tag}^{commit}" 2>/dev/null || true)"
if [[ -n "$phase4_commit" ]] && git diff --quiet "$phase4_commit" -- sql/schema; then
    pass "Frozen Phase 4 SQL schema tree remains unchanged"
else
    fail "Frozen Phase 4 SQL schema tree remains unchanged"
fi

if [[ -n "$phase4_commit" ]] && git diff --quiet "$phase4_commit" -- test-framework/sql/schema test-framework/sql/tests/foundation test-framework/sql/tests/concurrency test-framework/sql/tests/foundation-tests.manifest test-framework/sql/tests/foundation-concurrency-tests.manifest; then
    pass "Frozen Foundation executable test tree remains unchanged"
else
    fail "Frozen Foundation executable test tree remains unchanged"
fi

changed_protected="$({ git status --porcelain=v1 --untracked-files=all || true; } | awk '{print $2}' | grep -E '^(sql/(schema|deployment)/|test-framework/sql/(schema|deployment)/)' || true)"
if [[ -z "$changed_protected" ]]; then
    pass "Step 1 candidate changes no accepted SQL or executable database tests"
else
    fail "Step 1 candidate changes no accepted SQL or executable database tests"
fi

printf '\n== Production Go contract ==\n'
contract="docs/architecture/backend-services/production-go-service-boundary-and-runtime-model.md"
record="docs/architecture/backend-services/phase-6-step-1-production-go-service-contract.md"

require_text "$contract" "Phase 6 Step 1 contract freeze" "Contract identifies Phase 6 Step 1"
require_text "$contract" "issp_service_authorization" "Contract maps Foundation API identity"
require_text "$contract" "issp_service_integration_delivery" "Contract maps integration worker identity"
require_text "$contract" "issp_service_monitoring_delivery" "Contract maps monitoring worker identity"
require_text "$contract" "A universal application database identity is prohibited." "Contract prohibits universal application identity"
require_text "$contract" "Normal service startup must not" "Contract prohibits runtime migration behavior"
require_text "$contract" "Direct protected-table mutation is prohibited" "Contract preserves controlled database API boundary"
require_text "$contract" "Transport headers or JSON fields do not become authoritative" "Contract separates caller claims from authority"
require_text "$contract" "Production secrets must not appear" "Contract defines secret exclusion"
require_text "$contract" "Each process owns exactly the pools required" "Contract defines per-process pool ownership"
require_text "$contract" "The service contract is transport-neutral" "Contract preserves transport-independent semantics"
require_text "$contract" "High-cardinality identities" "Contract bounds metric cardinality"
require_text "$contract" "Every executable must support deterministic cancellation" "Contract defines graceful shutdown"
require_text "$contract" "avoid holding database transactions across external network calls" "Worker contract avoids external calls inside transactions"
require_text "$contract" "Mock-only testing cannot prove the PostgreSQL security boundary" "Contract requires real database tests"
require_text "$contract" "go/platform/" "Contract reserves production workspace"
require_text "$contract" "### Step 8 — Formal Acceptance" "Contract defines eight-step Phase 6 plan"
require_text "$contract" "Phase 6 Step 1 does not claim" "Contract records explicit non-claims"

process_mapping_count="$(grep -Ec '^\| (Foundation API process|Integration delivery worker|Monitoring delivery worker) \|' "$contract" || true)"
if [[ "$process_mapping_count" == "3" ]]; then
    pass "Contract contains exactly three initial process identity mappings"
else
    fail "Contract contains exactly three initial process identity mappings"
fi

if [[ ! -e go/platform ]]; then
    pass "Production Go workspace is not created prematurely"
else
    fail "Production Go workspace is not created prematurely"
fi

production_go_files="$({ find go -path 'go/experiments' -prune -o -type f \( -name '*.go' -o -name 'go.mod' -o -name 'go.sum' -o -name 'go.work' -o -name 'go.work.sum' \) -print 2>/dev/null || true; })"
if [[ -z "$production_go_files" ]]; then
    pass "No production Go module or source file is introduced"
else
    fail "No production Go module or source file is introduced"
fi

require_text "$record" "Documentation and validation only" "Step 1 record identifies contract-only scope"
require_text "$record" "no universal application database identity" "Step 1 record preserves service identity separation"
require_text "$record" "Phase 6 Step 2 may create" "Step 1 record identifies next step"

printf '\n== Documentation synchronization ==\n'
for file_path in \
    README.md \
    docs/README.md \
    docs/architecture/README.md \
    docs/architecture/backend-services/README.md \
    go/README.md \
    tools/validation/README.md \
    tools/validation/phase-gates/README.md
 do
    require_text "$file_path" "Phase 6 Step 1" "$file_path identifies Phase 6 Step 1"
 done

require_text README.md "Built on purpose. Backed by discipline. Engineered to endure." "Iron Signal Systems tagline remains present"
require_text README.md "Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency." "Original mission sentence remains present"

printf '\n== Static script checks ==\n'
if bash -n tools/validation/phase-gates/validate_phase6_step1.sh; then
    pass "Phase 6 Step 1 gate Bash syntax"
else
    fail "Phase 6 Step 1 gate Bash syntax"
fi

printf '\n== Phase 5 accepted predecessor ==\n'
predecessor_rc=0
if $static_only; then
    ./tools/validation/phase-gates/validate_phase5_step8.sh --static-only || predecessor_rc=$?
else
    ./tools/validation/phase-gates/validate_phase5_step8.sh || predecessor_rc=$?
fi

if [[ "$predecessor_rc" -eq 0 ]]; then
    pass "Phase 5 formal acceptance revalidation passed"
else
    fail "Phase 5 formal acceptance revalidation passed"
fi

printf '\n== Final result ==\n'
printf 'PASS checks: %d\n' "$pass_count"
printf 'FAIL checks: %d\n' "$fail_count"

if [[ "$fail_count" -ne 0 ]]; then
    printf '\nPhase 6 Step 1 validation FAILED.\n'
    exit 1
fi

if $static_only; then
    printf '\nPhase 6 Step 1 static validation PASSED completely.\n'
else
    printf '\nPhase 6 Step 1 validation PASSED completely.\n'
fi
printf 'The production Go service, database-consumption, runtime, and testing contract is frozen without introducing production Go code.\n'
printf 'Phase 6 Step 2 may create the production Go workspace and reproducible build baseline.\n'
