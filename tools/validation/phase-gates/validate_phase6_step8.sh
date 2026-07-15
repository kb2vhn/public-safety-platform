#!/usr/bin/env bash
set -Eeuo pipefail

static_only=false
case "${1:-}" in
    "") ;;
    --static-only) static_only=true ;;
    *) printf 'Usage: %s [--static-only]\n' "$0" >&2; exit 2 ;;
esac

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$repo_root" ]] || { printf 'FAIL: Repository is a Git work tree\n' >&2; exit 1; }
cd "$repo_root"

predecessor_commit="79e9723b2dd12e813de8a8c665d08d4f61cc8fab"
canonical_origin="git@github.com:Iron-Signal-Systems/iron-signal-platform.git"
results_dir="${TMPDIR:-/tmp}/phase-6-step-8-results"
pass_count=0
fail_count=0
scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step8-gate.XXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT

pass() { pass_count=$((pass_count + 1)); printf 'PASS: %s\n' "$1"; }
fail() { fail_count=$((fail_count + 1)); printf 'FAIL: %s\n' "$1" >&2; }
require_command() { command -v "$1" >/dev/null 2>&1 && pass "Required command available: $1" || fail "Required command available: $1"; }
require_file() { [[ -f "$1" ]] && pass "$2" || fail "$2"; }
require_executable() { [[ -x "$1" ]] && pass "$2" || fail "$2"; }
require_text() { grep -Fq -- "$2" "$1" && pass "$3" || fail "$3"; }
run_check() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }
finish() {
    printf '\nPASS checks: %d\nFAIL checks: %d\n' "$pass_count" "$fail_count"
    if (( fail_count == 0 )); then
        if $static_only; then
            printf 'Phase 6 Step 8 static validation PASSED completely.\n'
        else
            printf 'Phase 6 Step 8 complete validation PASSED completely.\n'
            printf 'Resource JSON: %s/phase6-step8-resources.json\n' "$results_dir"
            printf 'Resource text: %s/phase6-step8-resources.txt\n' "$results_dir"
        fi
        exit 0
    fi
    printf 'Phase 6 Step 8 validation FAILED.\n'
    exit 1
}

for command_name in git bash go gofmt grep find sort cmp mktemp python3 systemd-analyze systemd-sysusers; do
    require_command "$command_name"
done
if ! $static_only; then
    for command_name in pg_config psql awk sed date uname nproc df sha256sum kill sleep seq; do
        require_command "$command_name"
    done
    [[ -x /usr/bin/time ]] && pass "Required command available: /usr/bin/time" || fail "Required command available: /usr/bin/time"
fi

[[ "$(git branch --show-current)" == dev ]] && pass "Authoritative branch is dev" || fail "Authoritative branch is dev"
[[ "$(git remote get-url origin 2>/dev/null || true)" == "$canonical_origin" ]] && pass "Canonical Iron Signal Systems origin configured" || fail "Canonical Iron Signal Systems origin configured"
git merge-base --is-ancestor "$predecessor_commit" HEAD && pass "Accepted Step 7 commit is an ancestor of the candidate" || fail "Accepted Step 7 commit is an ancestor of the candidate"

if git clone -q --no-hardlinks "$repo_root" "$scratch/predecessor"; then
    (
        cd "$scratch/predecessor"
        git remote set-url origin "$canonical_origin"
        git checkout -q -B dev "$predecessor_commit"
    )
    predecessor_args=()
    $static_only && predecessor_args=(--static-only)
    if (
        cd "$scratch/predecessor"
        bash tools/validation/phase-gates/validate_phase6_step7.sh "${predecessor_args[@]}"
    ) >"$scratch/predecessor.log" 2>&1; then
        pass "Accepted Step 7 predecessor revalidates in isolated dev clone"
    else
        cat "$scratch/predecessor.log" >&2
        fail "Accepted Step 7 predecessor revalidates in isolated dev clone"
    fi
else
    fail "Accepted Step 7 predecessor revalidates in isolated dev clone"
fi

expected_paths="$scratch/expected-paths.txt"
actual_paths="$scratch/actual-paths.txt"
cat >"$expected_paths" <<'PATHS'
README.md
docs/README.md
docs/architecture/README.md
docs/architecture/backend-services/README.md
docs/architecture/backend-services/phase-6-step-7-integration-and-monitoring-delivery-workers.md
docs/architecture/backend-services/phase-6-step-8-hostile-failure-concurrency-and-resource-validation.md
docs/architecture/backend-services/production-go-service-boundary-and-runtime-model.md
docs/architecture/foundation/README.md
go/README.md
go/platform/DEPENDENCIES.md
go/platform/README.md
go/platform/deployment/README.md
go/platform/internal/authentication/handoff_step8_hostile_test.go
go/platform/internal/foundation/authorization_policy_step8_integration_test.go
go/platform/internal/transport/business_step8_hostile_test.go
go/platform/internal/workers/delivery_step8_hostile_test.go
go/platform/internal/workers/delivery_step8_integration_test.go
go/platform/scripts/test-phase6-adversarial-runtime.sh
go/platform/scripts/test-phase6-adversarial.sh
go/platform/testdata/phase6-step8/hostile-delivery-fixtures.sql
tools/validation/README.md
tools/validation/phase-gates/README.md
tools/validation/phase-gates/validate_phase6_step8.sh
PATHS
{
    git diff --name-only "$predecessor_commit"
    git ls-files --others --exclude-standard
} | sort -u >"$actual_paths"
sort -o "$expected_paths" "$expected_paths"
if cmp -s "$expected_paths" "$actual_paths"; then
    pass "Step 8 changes exactly the approved 23-path validation boundary"
else
    printf '%s\n' '--- Expected Step 8 paths' >&2
    printf '%s\n' '+++ Actual Step 8 paths' >&2
    diff -u "$expected_paths" "$actual_paths" >&2 || true
    fail "Step 8 changes exactly the approved 23-path validation boundary"
fi

if python3 - "$predecessor_commit" <<'PY_PRODUCTION_FREEZE'
from pathlib import Path
import subprocess
import sys

predecessor = sys.argv[1]
changed = set(
    subprocess.check_output(
        ["git", "diff", "--name-only", predecessor], text=True
    ).splitlines()
)
changed.update(
    subprocess.check_output(
        ["git", "ls-files", "--others", "--exclude-standard"], text=True
    ).splitlines()
)

for path_text in changed:
    path = Path(path_text)
    if path.suffix == ".go" and not path.name.endswith("_test.go"):
        raise SystemExit(f"production Go source changed: {path}")

frozen_prefixes = (
    "sql/schema/",
    "sql/deployment/",
    "test-framework/sql/",
    "go/platform/cmd/",
    "go/platform/deployment/systemd/",
    "go/platform/deployment/sysusers.d/",
)
frozen_exact = {
    "go/platform/go.mod",
    "go/platform/go.sum",
    "go/platform/TOOLCHAIN",
}
for path_text in changed:
    if path_text in frozen_exact or path_text.startswith(frozen_prefixes):
        raise SystemExit(f"frozen production/deployment path changed: {path_text}")
PY_PRODUCTION_FREEZE
then
    pass "Production Go, dependency, migration, test-framework, and service-unit boundaries remain frozen"
else
    fail "Production Go, dependency, migration, test-framework, and service-unit boundaries remain frozen"
fi

step7_record="docs/architecture/backend-services/phase-6-step-7-integration-and-monitoring-delivery-workers.md"
require_text "$step7_record" "Status:** Accepted implementation checkpoint." "Step 7 record identifies accepted checkpoint status"
require_text "$step7_record" "$predecessor_commit" "Step 7 record names the exact accepted commit"
require_text "$step7_record" "142 PASS and 0 FAIL" "Step 7 record preserves both accepted gate results"

record="docs/architecture/backend-services/phase-6-step-8-hostile-failure-concurrency-and-resource-validation.md"
require_file "$record" "Step 8 hostile-validation record exists"
require_text "$record" "Status:** Implementation candidate. Acceptance is not yet claimed." "Step 8 record identifies candidate status"
require_text "$record" "validation code, hostile fixtures, orchestration" "Step 8 record freezes the validation-only boundary"
require_text "$record" "ISSP-PHASE6-STEP8-RESOURCE-V1" "Step 8 record freezes the resource schema"
require_text "$record" "Correctness result: PASS or FAIL" "Step 8 record separates correctness"
require_text "$record" "Resource observation: RECORDED or NOT_RECORDED" "Step 8 record separates resource observation"
require_text "$record" "Performance thresholds: NOT_EVALUATED" "Step 8 record preserves observation-only thresholds"
require_text "$record" "Phase 6 Step 9" "Step 8 record identifies formal acceptance as Step 9"

required_files=(
    go/platform/internal/authentication/handoff_step8_hostile_test.go
    go/platform/internal/foundation/authorization_policy_step8_integration_test.go
    go/platform/internal/transport/business_step8_hostile_test.go
    go/platform/internal/workers/delivery_step8_hostile_test.go
    go/platform/internal/workers/delivery_step8_integration_test.go
    go/platform/testdata/phase6-step8/hostile-delivery-fixtures.sql
    go/platform/scripts/test-phase6-adversarial.sh
    go/platform/scripts/test-phase6-adversarial-runtime.sh
    tools/validation/phase-gates/validate_phase6_step8.sh
)
for required_path in "${required_files[@]}"; do
    require_file "$required_path" "Step 8 artifact exists: $required_path"
done
for executable_path in go/platform/scripts/test-phase6-adversarial.sh go/platform/scripts/test-phase6-adversarial-runtime.sh tools/validation/phase-gates/validate_phase6_step8.sh; do
    require_executable "$executable_path" "Executable: $executable_path"
done

require_text go/platform/internal/authentication/handoff_step8_hostile_test.go "MaximumReplayEntries" "Replay-capacity test uses the accepted exact bound"
require_text go/platform/internal/authentication/handoff_step8_hostile_test.go "ErrorCapacity" "Replay-capacity overflow must fail closed"
require_text go/platform/internal/authentication/handoff_step8_hostile_test.go "expired replay entries were not removed" "Replay-expiration cleanup is asserted"
require_text go/platform/internal/authentication/handoff_step8_hostile_test.go "Verify() accepted signed-field tampering" "Signed-field tampering matrix is asserted"
require_text go/platform/internal/authentication/handoff_step8_hostile_test.go "wrong-key error" "Signature key mismatch is asserted"

require_text go/platform/internal/transport/business_step8_hostile_test.go "DuplicateAuthenticationHeadersFailClosed" "Duplicate authentication headers are hostile-tested"
require_text go/platform/internal/transport/business_step8_hostile_test.go "BodyAndSignedIdentityTamperingFailBeforeAdapter" "Body and identity tampering are rejected before the adapter"
for header_name in Forwarded X-Forwarded-For X-Forwarded-Host X-Forwarded-Proto X-Real-IP; do
    require_text go/platform/internal/transport/business_step8_hostile_test.go "$header_name" "Proxy-authority header is hostile-tested: $header_name"
done
require_text go/platform/internal/transport/business_step8_hostile_test.go "StatusGatewayTimeout" "Parent deadline maps to bounded timeout"
require_text go/platform/internal/transport/business_step8_hostile_test.go "status line = %q, want 431" "Actual listener oversized-header rejection is asserted"
require_text go/platform/internal/transport/business_step8_hostile_test.go "DoNotConsumeHandoff" "Pre-authentication route/media rejection preserves replay state"

require_text go/platform/internal/foundation/authorization_policy_step8_integration_test.go "context.WithTimeout" "Adapter lock-wait integration test uses a caller deadline"
require_text go/platform/internal/foundation/authorization_policy_step8_integration_test.go "AuthorizationPolicyLockWaitHonorsCallerDeadline" "Blocked protected operation cancellation is integration-tested"

require_text go/platform/internal/workers/delivery_step8_hostile_test.go "RelayHostileResponsesRemainBoundedAndRedacted" "Relay timeout, disconnect, redirect, and malformed responses are hostile-tested"
require_text go/platform/internal/workers/delivery_step8_hostile_test.go "RunnerStopsClaimingImmediatelyOnCancellation" "Worker claim cancellation is hostile-tested"
require_text go/platform/internal/workers/delivery_step8_hostile_test.go "CompletionAndRescheduleErrorsDoNotDiscloseIdentifiers" "Completion and reschedule logs are redaction-tested"
require_text go/platform/internal/workers/delivery_step8_integration_test.go "HTTP_PROXY" "Ambient proxy escape is integration-tested"
require_text go/platform/internal/workers/delivery_step8_integration_test.go "redirect target calls" "Redirect target non-use is integration-tested"
require_text go/platform/internal/workers/delivery_step8_integration_test.go "Idempotency-Key" "Durable idempotency key is verified at the hostile relay"
require_text go/platform/internal/workers/delivery_step8_integration_test.go "integrationToken" "Integration relay credential is independently verified"
require_text go/platform/internal/workers/delivery_step8_integration_test.go "monitoringToken" "Monitoring relay credential is independently verified"

require_text go/platform/testdata/phase6-step8/hostile-delivery-fixtures.sql "database-selected-destination-is-metadata-only" "Hostile database destination metadata is fixture-controlled"
require_text go/platform/testdata/phase6-step8/hostile-delivery-fixtures.sql "81100000-0000-0000-0000-000000000008" "Eight integration hostile outcomes are fixed"
require_text go/platform/testdata/phase6-step8/hostile-delivery-fixtures.sql "82300000-0000-0000-0000-000000000008" "Eight monitoring hostile outcomes are fixed"
require_text go/platform/testdata/phase6-step8/hostile-delivery-fixtures.sql "'PENDING',2" "Monitoring retry-exhaustion fixture starts at the exact prior attempt"

require_text go/platform/scripts/test-phase6-adversarial.sh "go test -count=3" "Static campaign repeats package tests three times"
require_text go/platform/scripts/test-phase6-adversarial.sh "go test -race -count=2" "Static campaign repeats race detection twice"
require_text go/platform/scripts/test-phase6-adversarial.sh "-run '^TestPhase6Step8' -count=2" "Step 8 hostile tests receive an extra repeat campaign"
require_text go/platform/scripts/test-phase6-adversarial.sh "t\\.Skip\\(" "Static campaign rejects skipped non-integration hostile tests"

runtime_script="go/platform/scripts/test-phase6-adversarial-runtime.sh"
require_text "$runtime_script" "Disposable Step 8 runtime uses PostgreSQL 18" "Runtime campaign requires PostgreSQL 18"
require_text "$runtime_script" "/usr/bin/time --verbose" "Runtime campaign records process-tree resource telemetry"
require_text "$runtime_script" "pg_wal_lsn_diff" "Runtime campaign records WAL generation"
require_text "$runtime_script" "pg_database_size" "Runtime campaign records database size"
require_text "$runtime_script" "FROM pg_stat_database" "Runtime campaign records PostgreSQL statistics"
require_text "$runtime_script" "deadlocks" "Runtime campaign records and checks deadlocks"
require_text "$runtime_script" "Foundation identity cannot claim integration work" "Runtime campaign proves cross-role routine denial"
require_text "$runtime_script" "Integration identity has no direct outbox table read" "Runtime campaign proves direct integration-table denial"
require_text "$runtime_script" "Monitoring identity has no direct delivery-state table read" "Runtime campaign proves direct monitoring-table denial"
require_text "$runtime_script" "Expired integration claim is recovered exactly once" "Runtime campaign proves integration lease recovery"
require_text "$runtime_script" "Expired monitoring claim is recovered exactly once" "Runtime campaign proves monitoring lease recovery"
require_text "$runtime_script" "Concurrent integration completion has one winner" "Runtime campaign proves integration completion race"
require_text "$runtime_script" "Concurrent monitoring completion has one winner" "Runtime campaign proves monitoring completion race"
require_text "$runtime_script" "statement_timestamp() + interval '1 hour'" "Runtime campaign isolates later race fixtures from prior retry eligibility"
require_text "$runtime_script" "'82300000-0000-0000-0000-000000000102','82200000-0000-0000-0000-000000000001','82100000-0000-0000-0000-000000000102','PENDING',0,statement_timestamp()+interval '1 hour'" "Monitoring completion-race fixture remains ineligible during lease recovery"
require_text "$runtime_script" "WHERE monitoring_delivery_state_id='82300000-0000-0000-0000-000000000102'" "Monitoring completion-race fixture is released only after lease recovery"
require_text "$runtime_script" "ISSP-PHASE6-STEP8-RESOURCE-V1" "Runtime campaign writes the frozen resource schema"
require_text "$runtime_script" "Correctness result: PASS" "Runtime campaign reports correctness separately"
require_text "$runtime_script" "Resource observation: RECORDED" "Runtime campaign reports resource observation separately"
require_text "$runtime_script" "Performance thresholds: NOT_EVALUATED" "Runtime campaign leaves thresholds unevaluated"

run_check "Repository diff is whitespace-clean" git diff --check

if (cd go/platform && bash scripts/check.sh) >"$scratch/go-check.log" 2>&1; then
    pass "Production Go checks pass with Step 8 tests present"
else
    cat "$scratch/go-check.log" >&2
    fail "Production Go checks pass with Step 8 tests present"
fi
if (cd go/platform && bash scripts/test-process-host.sh) >"$scratch/process-host.log" 2>&1; then
    pass "Accepted process-host static and race validation remains valid"
else
    cat "$scratch/process-host.log" >&2
    fail "Accepted process-host static and race validation remains valid"
fi
if (cd go/platform && bash scripts/test-foundation-adapter.sh) >"$scratch/foundation-adapter.log" 2>&1; then
    pass "Accepted controlled adapter static and race validation remains valid"
else
    cat "$scratch/foundation-adapter.log" >&2
    fail "Accepted controlled adapter static and race validation remains valid"
fi
if (cd go/platform && bash scripts/test-authenticated-transport.sh) >"$scratch/authenticated-transport.log" 2>&1; then
    pass "Accepted authenticated transport static and race validation remains valid"
else
    cat "$scratch/authenticated-transport.log" >&2
    fail "Accepted authenticated transport static and race validation remains valid"
fi
if (cd go/platform && bash scripts/test-delivery-workers.sh) >"$scratch/delivery-workers.log" 2>&1; then
    pass "Accepted delivery-worker static and race validation remains valid"
else
    cat "$scratch/delivery-workers.log" >&2
    fail "Accepted delivery-worker static and race validation remains valid"
fi
if (cd go/platform && GOTOOLCHAIN=local GOFLAGS='-mod=readonly' go test -tags=integration -run '^$' ./internal/foundation ./internal/workers) >"$scratch/integration-compile.log" 2>&1; then
    pass "Step 8 integration tests compile without execution"
else
    cat "$scratch/integration-compile.log" >&2
    fail "Step 8 integration tests compile without execution"
fi
if (cd go/platform && bash scripts/test-phase6-adversarial.sh) >"$scratch/adversarial.log" 2>&1; then
    pass "Step 8 repeated hostile and race campaign passes"
else
    cat "$scratch/adversarial.log" >&2
    fail "Step 8 repeated hostile and race campaign passes"
fi

synchronized_docs=(
    README.md
    docs/README.md
    docs/architecture/README.md
    docs/architecture/backend-services/README.md
    docs/architecture/backend-services/phase-6-step-7-integration-and-monitoring-delivery-workers.md
    docs/architecture/backend-services/phase-6-step-8-hostile-failure-concurrency-and-resource-validation.md
    docs/architecture/backend-services/production-go-service-boundary-and-runtime-model.md
    docs/architecture/foundation/README.md
    go/README.md
    go/platform/README.md
    go/platform/DEPENDENCIES.md
    go/platform/deployment/README.md
    tools/validation/README.md
    tools/validation/phase-gates/README.md
)
for doc in "${synchronized_docs[@]}"; do
    require_text "$doc" "Phase 6 Step 8" "Documentation synchronized for Step 8: $doc"
done
for doc in README.md docs/README.md docs/architecture/README.md docs/architecture/backend-services/README.md go/README.md go/platform/README.md tools/validation/README.md tools/validation/phase-gates/README.md; do
    require_text "$doc" "$predecessor_commit" "Accepted Step 7 commit synchronized: $doc"
done
if grep -E 'Step 7.*(implementation candidate|active implementation)|Step 6 is the newest accepted' "${synchronized_docs[@]}" >/dev/null 2>&1; then
    fail "Stale Step 6 or Step 7 candidate status is absent from current indexes"
else
    pass "Stale Step 6 or Step 7 candidate status is absent from current indexes"
fi

if $static_only; then
    pass "Static-only mode skips disposable Step 8 hostile runtime execution"
else
    rm -rf -- "$results_dir"
    mkdir -p -- "$results_dir"
    runtime_passed=false
    if (cd go/platform && bash scripts/test-phase6-adversarial-runtime.sh --results-dir "$results_dir") >"$scratch/step8-runtime.log" 2>&1; then
        pass "Step 8 hostile PostgreSQL and relay runtime validation passes"
        runtime_passed=true
    else
        cat "$scratch/step8-runtime.log" >&2
        fail "Step 8 hostile PostgreSQL and relay runtime validation passes"
    fi

    if $runtime_passed; then
        resources_json="$results_dir/phase6-step8-resources.json"
        resources_text="$results_dir/phase6-step8-resources.txt"
        require_file "$resources_json" "Step 8 machine-readable resource report exists"
        require_file "$resources_text" "Step 8 human-readable resource report exists"

        if python3 - "$resources_json" <<'PY_RESOURCE_REPORT'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
assert data["schema_version"] == "ISSP-PHASE6-STEP8-RESOURCE-V1"
assert data["correctness_result"] == "PASS"
assert data["resource_observation"] == "RECORDED"
assert data["performance_thresholds"] == "NOT_EVALUATED"
assert data["timing"]["total_elapsed_ns"] > 0
assert data["process_tree"]["maximum_resident_set_kib"] > 0
assert data["postgresql"]["database_size_bytes"] > 0
assert data["postgresql"]["wal_generation_bytes"] >= 0
assert data["postgresql"]["deadlocks"] == 0
assert data["environment"]["logical_cpu_count"] > 0
assert data["environment"]["installed_memory_kib"] > 0
assert data["environment"]["postgresql_version_num"] >= 180000
assert data["campaign"]
assert all(value == "PASS" for value in data["campaign"].values())
PY_RESOURCE_REPORT
        then
            pass "Step 8 resource report is complete, bounded, and machine-readable"
        else
            fail "Step 8 resource report is complete, bounded, and machine-readable"
        fi
        require_text "$resources_text" "Correctness result: PASS" "Human-readable report records correctness PASS"
        require_text "$resources_text" "Resource observation: RECORDED" "Human-readable report records resource observation"
        require_text "$resources_text" "Performance thresholds: NOT_EVALUATED" "Human-readable report preserves observation-only thresholds"
    fi
fi

finish
