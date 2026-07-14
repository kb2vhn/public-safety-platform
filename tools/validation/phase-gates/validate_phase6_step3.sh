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
step2_commit="2c154e4f7e7cbb050c39f8ff99d132fae8c90658"
module_root="go/platform"
module_path="github.com/Iron-Signal-Systems/iron-signal-platform/go/platform"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN" 2>/dev/null || true)"

printf 'Dependency preflight: PASS\n'
printf '\n== Repository and predecessor integrity ==\n'
for command_name in git grep find bash go gofmt sha256sum mktemp sort python3 awk cmp chmod; do
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
    docs/architecture/backend-services/phase-6-step-3-runtime-bootstrap-and-postgresql-connectivity.md \
    go/README.md \
    go/platform/go.mod \
    go/platform/go.sum \
    go/platform/TOOLCHAIN \
    go/platform/DEPENDENCIES.md \
    go/platform/README.md \
    go/platform/cmd/foundation-api/main.go \
    go/platform/cmd/integration-delivery-worker/main.go \
    go/platform/cmd/monitoring-delivery-worker/main.go \
    go/platform/internal/bootstrap/run.go \
    go/platform/internal/bootstrap/run_test.go \
    go/platform/internal/config/config.go \
    go/platform/internal/config/config_test.go \
    go/platform/internal/database/identity.go \
    go/platform/internal/database/pool.go \
    go/platform/internal/database/pool_test.go \
    go/platform/internal/database/runtime_integration_test.go \
    go/platform/internal/observability/logging.go \
    go/platform/internal/observability/logging_test.go \
    go/platform/internal/transport/health.go \
    go/platform/internal/transport/health_test.go \
    go/platform/scripts/build.sh \
    go/platform/scripts/check.sh \
    go/platform/scripts/test-runtime.sh \
    tools/validation/README.md \
    tools/validation/phase-gates/README.md \
    tools/validation/phase-gates/validate_phase6_step1.sh \
    tools/validation/phase-gates/validate_phase6_step2.sh \
    tools/validation/phase-gates/validate_phase6_step3.sh
do
    require_file "$file_path"
done

for executable_path in \
    go/platform/scripts/build.sh \
    go/platform/scripts/check.sh \
    go/platform/scripts/test-runtime.sh \
    tools/validation/phase-gates/validate_phase6_step1.sh \
    tools/validation/phase-gates/validate_phase6_step2.sh \
    tools/validation/phase-gates/validate_phase6_step3.sh
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
if git cat-file -e "${step2_commit}^{commit}" 2>/dev/null; then
    pass "Phase 6 Step 2 predecessor commit exists"
else
    fail "Phase 6 Step 2 predecessor commit exists"
fi
if git merge-base --is-ancestor "$step2_commit" HEAD 2>/dev/null; then
    pass "Current tree descends from the Step 2 predecessor"
else
    fail "Current tree descends from the Step 2 predecessor"
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
if git diff --quiet "$step2_commit" -- \
    tools/validation/phase-gates/validate_phase6_step1.sh \
    tools/validation/phase-gates/validate_phase6_step2.sh; then
    pass "Accepted Phase 6 Step 1 and Step 2 gates remain unchanged"
else
    fail "Accepted Phase 6 Step 1 and Step 2 gates remain unchanged"
fi

changed_protected="$({ git status --porcelain=v1 --untracked-files=all || true; } \
    | awk '{print $2}' \
    | grep -E '^(sql/|test-framework/sql/(schema|deployment)/|tools/validation/phase-gates/validate_phase(5_|6_step[12]\.sh))' || true)"
if [[ -z "$changed_protected" ]]; then
    pass "Step 3 candidate changes no accepted SQL, database tests, or historical gates"
else
    printf '%s\n' "$changed_protected"
    fail "Step 3 candidate changes no accepted SQL, database tests, or historical gates"
fi

printf '\n== Toolchain and dependency boundary ==\n'
require_text "$module_root/go.mod" "module $module_path" "Production module path is canonical"
require_text "$module_root/go.mod" "go 1.26.0" "Go language baseline remains 1.26.0"
require_text "$module_root/go.mod" "toolchain go1.26.5" "Go toolchain directive remains go1.26.5"
require_text "$module_root/go.mod" "github.com/jackc/pgx/v5 v5.10.0" "pgx direct dependency is exactly v5.10.0"
require_text "$module_root/go.sum" "github.com/jackc/pgx/v5 v5.10.0 h1:VhSvgU2jSli8o3AqIEOTJr7rZwAEUVo4E4XhR94Zfr0=" "pgx module checksum is frozen"

actual_go="$(GOTOOLCHAIN=local go env GOVERSION 2>/dev/null || true)"
if [[ -n "$required_go" && "$actual_go" == "$required_go" ]]; then
    pass "Local Go toolchain = $required_go"
else
    fail "Local Go toolchain = $required_go (actual=${actual_go:-missing})"
fi

expected_modules="$(cat <<'MODULES'
github.com/davecgh/go-spew v1.1.1
github.com/Iron-Signal-Systems/iron-signal-platform/go/platform
github.com/jackc/pgpassfile v1.0.0
github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761
github.com/jackc/pgx/v5 v5.10.0
github.com/jackc/puddle/v2 v2.2.2
github.com/kr/pretty v0.3.0
github.com/pmezard/go-difflib v1.0.0
github.com/stretchr/objx v0.1.0
github.com/stretchr/testify v1.11.1
golang.org/x/mod v0.27.0
golang.org/x/sync v0.17.0
golang.org/x/text v0.29.0
golang.org/x/tools v0.36.0
gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c
gopkg.in/yaml.v3 v3.0.1
MODULES
)"
actual_modules="$(cd "$module_root" && GOTOOLCHAIN=local GOFLAGS='-mod=readonly' go list -m all 2>/dev/null | sort || true)"
if [[ "$actual_modules" == "$(printf '%s\n' "$expected_modules" | sort)" ]]; then
    pass "Module graph equals the exact accepted Step 3 inventory"
else
    printf 'Expected modules:\n%s\nActual modules:\n%s\n' "$expected_modules" "$actual_modules"
    fail "Module graph equals the exact accepted Step 3 inventory"
fi

require_text "$module_root/DEPENDENCIES.md" "github.com/jackc/pgx/v5 v5.10.0" "Dependency record names exact pgx version"
require_text "$module_root/DEPENDENCIES.md" "No ORM" "Dependency record excludes ORM and framework expansion"
require_text "$module_root/DEPENDENCIES.md" "confined to `internal/database/`" "Dependency record confines pgx authority"

pgx_imports_outside_database="$(grep -R -l -F 'github.com/jackc/pgx/v5' "$module_root"/internal --include='*.go' \
    | grep -v '^go/platform/internal/database/' || true)"
if [[ -z "$pgx_imports_outside_database" ]]; then
    pass "pgx imports are confined to internal/database"
else
    printf '%s\n' "$pgx_imports_outside_database"
    fail "pgx imports are confined to internal/database"
fi

printf '\n== Typed configuration and secret boundary ==\n'
config_file="$module_root/internal/config/config.go"
require_text "$config_file" 'ISSP_ADMIN_LISTEN_ADDRESS' "Configuration names explicit administrative listener variable"
require_text "$config_file" 'ISSP_DATABASE_DSN_FILE' "Configuration names protected PostgreSQL URL file variable"
require_text "$config_file" 'group and other permission bits must be zero' "Secret file rejects group and other access"
require_text "$config_file" 'symlinks are prohibited' "Secret file rejects symlinks"
require_text "$config_file" 'configured file changed during validation' "Secret file detects path replacement during open"
require_text "$config_file" 'host must be a literal loopback address' "Administrative listener requires literal loopback"
require_text "$config_file" 'maximumSecretFileSize' "Secret file size is bounded"
require_text "$config_file" 'MaxConnections' "Pool maximum is typed"
require_text "$config_file" 'StartupTimeout' "Startup timeout is typed"
require_text "$config_file" 'ShutdownTimeout' "Shutdown timeout is typed"

if grep -R -E 'ISSP_DATABASE_(URL|PASSWORD|DSN)=' "$module_root" --include='*.go' >/dev/null 2>&1; then
    fail "Source defines no direct database secret environment variable"
else
    pass "Source defines no direct database secret environment variable"
fi

printf '\n== PostgreSQL connectivity and compatibility boundary ==\n'
database_file="$module_root/internal/database/pool.go"
require_text "$database_file" 'sslmode=verify-full' "Remote database operation requires verify-full TLS"
require_text "$database_file" 'insecure mode requires a literal loopback host and sslmode=disable' "Insecure exception is loopback-only and explicit"
require_text "$database_file" 'poolConfig.MaxConns' "Pool maximum is enforced"
require_text "$database_file" 'poolConfig.ConnConfig.Fallbacks = nil' "Fallback hosts are disabled"
require_text "$database_file" 'search_path' "Database session search_path is fixed"
require_text "$database_file" 'statement_timeout' "Database session statement timeout is fixed"
require_text "$database_file" 'idle_in_transaction_session_timeout' "Idle transaction timeout is fixed"
require_text "$database_file" 'current_user' "Compatibility query verifies current_user"
require_text "$database_file" "current_setting('server_version_num')" "Compatibility query verifies server version"
require_text "$database_file" 'minimumPostgreSQLVersion = 180000' "PostgreSQL 18 minimum is explicit"
require_text "$database_file" 'maximumPostgreSQLVersion = 190000' "PostgreSQL 19 boundary is explicit"
require_text "$database_file" 'URL user must equal the compiled service role' "URL identity is bound to compiled role"
require_text "$database_file" 'an explicit TCP port between 1 and 65535 is required' "Database URL requires an explicit bounded port"
require_text "$database_file" 'databaseURL' "Database URL remains local to database package"

protected_sql="$(grep -R -E -i '\b(INSERT|UPDATE|DELETE|MERGE|CALL|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|COPY)\b' \
    "$module_root/internal/database" --include='*.go' || true)"
if [[ -z "$protected_sql" ]]; then
    pass "Step 3 database source contains no mutating or protected SQL verb"
else
    printf '%s\n' "$protected_sql"
    fail "Step 3 database source contains no mutating or protected SQL verb"
fi

printf '\n== Administrative health and lifecycle boundary ==\n'
transport_file="$module_root/internal/transport/health.go"
bootstrap_file="$module_root/internal/bootstrap/run.go"
require_text "$transport_file" '"/healthz"' "Administrative surface includes /healthz"
require_text "$transport_file" '"/readyz"' "Administrative surface includes /readyz"
handler_count="$(grep -c 'mux.HandleFunc' "$transport_file" || true)"
if [[ "$handler_count" == "2" ]]; then
    pass "Administrative surface contains exactly two handlers"
else
    fail "Administrative surface contains exactly two handlers"
fi
require_text "$transport_file" 'http.StatusServiceUnavailable' "Not-ready response is HTTP 503"
require_text "$transport_file" 'ReadHeaderTimeout' "Administrative server has read-header timeout"
require_text "$transport_file" 'MaxHeaderBytes' "Administrative server bounds request headers"
require_text "$bootstrap_file" 'state.SetReady(true)' "Readiness activates only after startup checks"
require_text "$bootstrap_file" 'state.SetReady(false)' "Readiness clears before shutdown"
require_text "$bootstrap_file" 'context.WithTimeout' "Lifecycle operations use bounded contexts"
require_text "$bootstrap_file" 'pool.Close()' "Database pool closes during shutdown"
require_text "$bootstrap_file" 'ExitConfiguration = 78' "Configuration rejection exit code remains 78"
require_text "$bootstrap_file" 'ExitUnavailable' "Database unavailability has bounded exit code"

for main_file in \
    "$module_root/cmd/foundation-api/main.go" \
    "$module_root/cmd/integration-delivery-worker/main.go" \
    "$module_root/cmd/monitoring-delivery-worker/main.go"
do
    require_text "$main_file" 'signal.NotifyContext' "$main_file derives cancellation from process signals"
    require_text "$main_file" 'syscall.SIGTERM' "$main_file handles SIGTERM"
done

printf '\n== Build and local validation ==\n'
for script_path in \
    "$module_root/scripts/build.sh" \
    "$module_root/scripts/check.sh" \
    "$module_root/scripts/test-runtime.sh" \
    tools/validation/phase-gates/validate_phase6_step3.sh
do
    if bash -n "$script_path"; then
        pass "Bash syntax: $script_path"
    else
        fail "Bash syntax: $script_path"
    fi
done

check_rc=0
"$module_root/scripts/check.sh" || check_rc=$?
if [[ "$check_rc" -eq 0 ]]; then
    pass "Production Go Step 3 checks passed"
else
    fail "Production Go Step 3 checks passed"
fi

printf '\n== Documentation synchronization ==\n'
record="docs/architecture/backend-services/phase-6-step-3-runtime-bootstrap-and-postgresql-connectivity.md"
require_text "$record" "$step2_commit" "Step 3 record names the exact Step 2 predecessor commit"
require_text "$record" 'github.com/jackc/pgx/v5 v5.10.0' "Step 3 record names exact pgx version"
require_text "$record" 'No universal application login is introduced.' "Step 3 record preserves service identity separation"
require_text "$record" 'sslmode=verify-full' "Step 3 record requires verified remote TLS"
require_text "$record" 'Step 3 still introduces no protected business operation.' "Step 3 record excludes protected operations"
require_text "$record" 'Phase 6 Step 4 may implement' "Step 3 record identifies the next step"

placeholder="__PHASE6_"'STEP2_COMMIT__'
if grep -Fq "$placeholder" "$record" tools/validation/phase-gates/validate_phase6_step3.sh; then
    fail "No unresolved Step 2 commit placeholder remains"
else
    pass "No unresolved Step 2 commit placeholder remains"
fi

for file_path in \
    README.md \
    docs/README.md \
    docs/architecture/README.md \
    docs/architecture/backend-services/README.md \
    go/README.md \
    tools/validation/README.md \
    tools/validation/phase-gates/README.md
do
    require_text "$file_path" "Phase 6 Step 3" "$file_path identifies Phase 6 Step 3"
done

require_text README.md "Built on purpose. Backed by discipline. Engineered to endure." "Iron Signal Systems tagline remains present"
require_text README.md "Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency." "Original mission sentence remains present"

printf '\n== Step 2 predecessor revalidation ==\n'
predecessor_parent="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step2-clone.XXXXXX")"
predecessor_repo="$predecessor_parent/repository"
cleanup_predecessor() {
    rm -rf -- "$predecessor_parent"
}
trap cleanup_predecessor EXIT

predecessor_rc=0
if git clone --quiet --no-hardlinks "$repo_root" "$predecessor_repo"; then
    git -C "$predecessor_repo" remote set-url origin "$origin_url"
    if git -C "$predecessor_repo" checkout --quiet -B dev "$step2_commit"; then
        if $static_only; then
            (
                cd "$predecessor_repo"
                ./tools/validation/phase-gates/validate_phase6_step2.sh --static-only
            ) || predecessor_rc=$?
        else
            (
                cd "$predecessor_repo"
                ./tools/validation/phase-gates/validate_phase6_step2.sh
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
    pass "Phase 6 Step 2 predecessor revalidation passed"
else
    fail "Phase 6 Step 2 predecessor revalidation passed"
fi

printf '\n== Disposable PostgreSQL runtime validation ==\n'
if $static_only; then
    printf 'Static-only validation requested; PostgreSQL execution skipped.\n'
    pass "PostgreSQL runtime validation intentionally skipped in static-only mode"
else
    runtime_rc=0
    "$module_root/scripts/test-runtime.sh" || runtime_rc=$?
    if [[ "$runtime_rc" -eq 0 ]]; then
        pass "Phase 6 Step 3 disposable PostgreSQL runtime validation passed"
    else
        fail "Phase 6 Step 3 disposable PostgreSQL runtime validation passed"
    fi
fi

printf '\n== Final result ==\n'
printf 'PASS checks: %d\n' "$pass_count"
printf 'FAIL checks: %d\n' "$fail_count"

if [[ "$fail_count" -ne 0 ]]; then
    printf '\nPhase 6 Step 3 validation FAILED.\n'
    exit 1
fi

if $static_only; then
    printf '\nPhase 6 Step 3 static validation PASSED completely.\n'
else
    printf '\nPhase 6 Step 3 validation PASSED completely.\n'
fi
printf 'Typed configuration, protected secret loading, exact PostgreSQL identity and compatibility checks, local health/readiness, cancellation, and graceful shutdown are established.\n'
printf 'No protected business operation, business listener, migration, or durable worker loop is implemented.\n'
printf 'Phase 6 Step 4 may implement process-host integration and hostile runtime failure validation.\n'
