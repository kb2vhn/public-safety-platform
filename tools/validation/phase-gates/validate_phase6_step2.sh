#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
    printf 'ERROR: not inside a Git work tree.\n' >&2
    exit 1
fi
cd "$repo_root"

static_only=false
if [[ "${1:-}" == "--static-only" ]]; then
    static_only=true
elif [[ $# -ne 0 ]]; then
    printf 'Usage: %s [--static-only]\n' "$0" >&2
    exit 2
fi

pass_count=0
fail_count=0

pass() {
    pass_count=$((pass_count + 1))
    printf 'PASS: %s\n' "$1"
}

fail() {
    fail_count=$((fail_count + 1))
    printf 'FAIL: %s\n' "$1"
}

require_command() {
    if command -v "$1" >/dev/null 2>&1; then
        pass "Command available: $1"
    else
        fail "Command available: $1"
    fi
}

require_file() {
    if [[ -f "$1" ]]; then
        pass "File exists: $1"
    else
        fail "File exists: $1"
    fi
}

require_executable() {
    if [[ -x "$1" ]]; then
        pass "Executable: $1"
    else
        fail "Executable: $1"
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
step1_commit="77f9ead23f5275e97989ea8c59b0c9c44f0c5a0b"
module_root="go/platform"
module_path="github.com/Iron-Signal-Systems/iron-signal-platform/go/platform"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")"

printf 'Dependency preflight: PASS\n'

printf '\n== Repository and predecessor integrity ==\n'
for command_name in git grep find bash go sha256sum mktemp; do
    require_command "$command_name"
done

for file_path in \
    README.md \
    docs/README.md \
    docs/architecture/README.md \
    docs/architecture/backend-services/README.md \
    docs/architecture/backend-services/production-go-service-boundary-and-runtime-model.md \
    docs/architecture/backend-services/phase-6-step-1-production-go-service-contract.md \
    docs/architecture/backend-services/phase-6-step-2-production-go-workspace-and-build-baseline.md \
    go/README.md \
    go/platform/go.mod \
    go/platform/TOOLCHAIN \
    go/platform/DEPENDENCIES.md \
    go/platform/README.md \
    go/platform/cmd/foundation-api/main.go \
    go/platform/cmd/integration-delivery-worker/main.go \
    go/platform/cmd/monitoring-delivery-worker/main.go \
    go/platform/internal/bootstrap/run.go \
    go/platform/internal/bootstrap/run_test.go \
    go/platform/internal/config/doc.go \
    go/platform/internal/database/identity.go \
    go/platform/internal/database/identity_test.go \
    go/platform/internal/foundation/doc.go \
    go/platform/internal/observability/doc.go \
    go/platform/internal/transport/doc.go \
    go/platform/internal/workers/doc.go \
    go/platform/scripts/build.sh \
    go/platform/scripts/check.sh \
    tools/validation/README.md \
    tools/validation/phase-gates/README.md \
    tools/validation/phase-gates/validate_phase6_step1.sh \
    tools/validation/phase-gates/validate_phase6_step2.sh
 do
    require_file "$file_path"
 done

for executable_path in \
    go/platform/scripts/build.sh \
    go/platform/scripts/check.sh \
    tools/validation/phase-gates/validate_phase6_step1.sh \
    tools/validation/phase-gates/validate_phase6_step2.sh
 do
    require_executable "$executable_path"
 done

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

if [[ "$(git rev-parse "${phase5_tag}^{commit}" 2>/dev/null || true)" == "$phase5_commit" ]]; then
    pass "Phase 5 tag targets the exact accepted implementation commit"
else
    fail "Phase 5 tag targets the exact accepted implementation commit"
fi

if git cat-file -e "${step1_commit}^{commit}" 2>/dev/null; then
    pass "Phase 6 Step 1 predecessor commit exists"
else
    fail "Phase 6 Step 1 predecessor commit exists"
fi

if git merge-base --is-ancestor "$step1_commit" HEAD 2>/dev/null; then
    pass "Current tree descends from the Step 1 predecessor"
else
    fail "Current tree descends from the Step 1 predecessor"
fi

if git diff --quiet "$phase5_commit" -- sql/deployment test-framework/sql/deployment; then
    pass "Accepted Phase 5 deployment and deployment-test trees remain unchanged"
else
    fail "Accepted Phase 5 deployment and deployment-test trees remain unchanged"
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

changed_protected="$({ git status --porcelain=v1 --untracked-files=all || true; } | awk '{print $2}' | grep -E '^(sql/|test-framework/sql/(schema|deployment)/)' || true)"
if [[ -z "$changed_protected" ]]; then
    pass "Step 2 candidate changes no accepted SQL or executable database tests"
else
    fail "Step 2 candidate changes no accepted SQL or executable database tests"
fi

printf '\n== Toolchain, module, and dependency baseline ==\n'
require_text "$module_root/go.mod" "module $module_path" "Production module path is canonical"
require_text "$module_root/go.mod" "go 1.26.0" "Go language baseline = 1.26.0"
require_text "$module_root/go.mod" "toolchain go1.26.5" "Go toolchain directive = go1.26.5"

actual_go="$(GOTOOLCHAIN=local go env GOVERSION 2>/dev/null || true)"
if [[ "$actual_go" == "$required_go" ]]; then
    pass "Local Go toolchain = $required_go"
else
    fail "Local Go toolchain = $required_go (actual=${actual_go:-missing})"
fi

if [[ "$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")" == "$required_go" ]]; then
    pass "TOOLCHAIN file freezes the exact validated compiler build"
else
    fail "TOOLCHAIN file freezes the exact validated compiler build"
fi

if [[ ! -e "$module_root/go.sum" ]]; then
    pass "No go.sum exists without third-party modules"
else
    fail "No go.sum exists without third-party modules"
fi

if [[ ! -e go/go.work && ! -e go/go.work.sum ]]; then
    pass "No unnecessary go.work file exists"
else
    fail "No unnecessary go.work file exists"
fi

module_inventory="$(cd "$module_root" && GOTOOLCHAIN=local go list -m all 2>/dev/null || true)"
if [[ "$module_inventory" == "$module_path" ]]; then
    pass "Module graph contains only the production module"
else
    fail "Module graph contains only the production module"
fi

require_text "$module_root/DEPENDENCIES.md" "zero third-party runtime or build" "Dependency record freezes zero-third-party baseline"
require_text "$module_root/DEPENDENCIES.md" 'Production packages must not import code under `go/experiments/`' "Dependency record isolates experiments"

printf '\n== Package and process boundary ==\n'
main_count="$(find "$module_root/cmd" -mindepth 2 -maxdepth 2 -type f -name main.go | wc -l | tr -d '[:space:]')"
if [[ "$main_count" == "3" ]]; then
    pass "Exactly three bounded executable entrypoints exist"
else
    fail "Exactly three bounded executable entrypoints exist"
fi

require_text "$module_root/internal/database/identity.go" "issp_service_authorization" "Foundation API database identity is typed"
require_text "$module_root/internal/database/identity.go" "issp_service_integration_delivery" "Integration worker database identity is typed"
require_text "$module_root/internal/database/identity.go" "issp_service_monitoring_delivery" "Monitoring worker database identity is typed"
require_text "$module_root/internal/bootstrap/run.go" "ExitConfiguration = 78" "Skeleton uses fail-closed exit status 78"
require_text "$module_root/internal/bootstrap/run.go" "runtime bootstrap is not implemented" "Skeleton reports explicit non-operational status"

for directory in bootstrap config database foundation observability transport workers; do
    if [[ -d "$module_root/internal/$directory" ]]; then
        pass "Internal package boundary exists: $directory"
    else
        fail "Internal package boundary exists: $directory"
    fi
done

if ! grep -R -E '"(database/sql|net|net/http|os/exec)"' "$module_root" --include='*.go' >/dev/null 2>&1; then
    pass "Step 2 source imports no database, listener, or process-execution package"
else
    fail "Step 2 source imports no database, listener, or process-execution package"
fi

if ! grep -R -F 'go/experiments' "$module_root" --include='*.go' >/dev/null 2>&1; then
    pass "Production source imports no experiment package"
else
    fail "Production source imports no experiment package"
fi

printf '\n== Build and validation baseline ==\n'
require_text "$module_root/scripts/build.sh" "GOTOOLCHAIN=local" "Build forbids implicit toolchain replacement"
require_text "$module_root/scripts/build.sh" "CGO_ENABLED=0" "Build disables CGO"
require_text "$module_root/scripts/build.sh" "-trimpath" "Build removes local source paths"
require_text "$module_root/scripts/build.sh" "-buildvcs=false" "Build controls VCS metadata"
require_text "$module_root/scripts/build.sh" "-ldflags=-buildid=" "Build removes volatile linker build ID"
require_text "$module_root/scripts/build.sh" "build-manifest.json" "Build records an artifact manifest"
require_text "$module_root/scripts/check.sh" "go vet ./..." "Validation includes go vet"
require_text "$module_root/scripts/check.sh" "go test ./..." "Validation includes package tests"
require_text "$module_root/scripts/check.sh" "Reproducible binary" "Validation compares repeated builds"

if bash -n "$module_root/scripts/build.sh"; then
    pass "Build script Bash syntax"
else
    fail "Build script Bash syntax"
fi
if bash -n "$module_root/scripts/check.sh"; then
    pass "Go check script Bash syntax"
else
    fail "Go check script Bash syntax"
fi
if bash -n tools/validation/phase-gates/validate_phase6_step2.sh; then
    pass "Phase 6 Step 2 gate Bash syntax"
else
    fail "Phase 6 Step 2 gate Bash syntax"
fi

check_rc=0
"$module_root/scripts/check.sh" || check_rc=$?
if [[ "$check_rc" -eq 0 ]]; then
    pass "Production Go baseline checks passed"
else
    fail "Production Go baseline checks passed"
fi

printf '\n== Documentation synchronization ==\n'
record="docs/architecture/backend-services/phase-6-step-2-production-go-workspace-and-build-baseline.md"
require_text "$record" "$step1_commit" "Step 2 record names the exact Step 1 predecessor commit"
placeholder='__PHASE6_'"STEP1_COMMIT__"
if grep -Fq "$placeholder" "$record" tools/validation/phase-gates/validate_phase6_step2.sh; then
    fail "No unresolved Step 1 commit placeholder remains"
else
    pass "No unresolved Step 1 commit placeholder remains"
fi
require_text "$record" "toolchain go1.26.5" "Step 2 record freezes exact Go toolchain"
require_text "$record" "zero-third-party dependency posture" "Step 2 record freezes dependency posture"
require_text "$record" "Phase 6 Step 3 may implement" "Step 2 record identifies next step"

for file_path in \
    README.md \
    docs/README.md \
    docs/architecture/README.md \
    docs/architecture/backend-services/README.md \
    go/README.md \
    tools/validation/README.md \
    tools/validation/phase-gates/README.md
 do
    require_text "$file_path" "Phase 6 Step 2" "$file_path identifies Phase 6 Step 2"
 done

require_text README.md "Built on purpose. Backed by discipline. Engineered to endure." "Iron Signal Systems tagline remains present"
require_text README.md "Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency." "Original mission sentence remains present"

printf '\n== Step 1 predecessor revalidation ==\n'
predecessor_parent="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step1-clone.XXXXXX")"
predecessor_repo="$predecessor_parent/repository"

cleanup_predecessor() {
    rm -rf -- "$predecessor_parent"
}
trap cleanup_predecessor EXIT

predecessor_rc=0

if git clone --quiet --no-hardlinks "$repo_root" "$predecessor_repo"; then
    git -C "$predecessor_repo" remote set-url origin "$origin_url"

    if git -C "$predecessor_repo" checkout --quiet -B dev "$step1_commit"; then
        if $static_only; then
            (
                cd "$predecessor_repo"
                ./tools/validation/phase-gates/validate_phase6_step1.sh --static-only
            ) || predecessor_rc=$?
        else
            (
                cd "$predecessor_repo"
                ./tools/validation/phase-gates/validate_phase6_step1.sh
            ) || predecessor_rc=$?
        fi
    else
        predecessor_rc=1
    fi
else
    predecessor_rc=1
fi

cleanup_predecessor
trap - EXIT

if [[ "$predecessor_rc" -eq 0 ]]; then
    pass "Phase 6 Step 1 predecessor revalidation passed"
else
    fail "Phase 6 Step 1 predecessor revalidation passed"
fi

printf '\n== Final result ==\n'
printf 'PASS checks: %d\n' "$pass_count"
printf 'FAIL checks: %d\n' "$fail_count"

if [[ "$fail_count" -ne 0 ]]; then
    printf '\nPhase 6 Step 2 validation FAILED.\n'
    exit 1
fi

if $static_only; then
    printf '\nPhase 6 Step 2 static validation PASSED completely.\n'
else
    printf '\nPhase 6 Step 2 validation PASSED completely.\n'
fi
printf 'The production Go workspace, exact toolchain, zero-third-party module graph, bounded executable skeletons, and reproducible build baseline are established.\n'
printf 'Phase 6 Step 3 may implement typed configuration, bounded PostgreSQL connectivity, compatibility checks, health/readiness, cancellation, and graceful shutdown without protected business operations.\n'
