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

predecessor_commit="ec3c36081c686fa8ec82c8fd94bda421ed6cff42"
canonical_origin="git@github.com:Iron-Signal-Systems/iron-signal-platform.git"
pass_count=0
fail_count=0
scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step7-gate.XXXXXX")"
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
            printf 'Phase 6 Step 7 static validation PASSED completely.\n'
        else
            printf 'Phase 6 Step 7 complete validation PASSED completely.\n'
        fi
        exit 0
    fi
    printf 'Phase 6 Step 7 validation FAILED.\n'
    exit 1
}

for command_name in git bash go gofmt grep find sort cmp mktemp python3 systemd-analyze systemd-sysusers; do
    require_command "$command_name"
done

[[ "$(git branch --show-current)" == dev ]] && pass "Authoritative branch is dev" || fail "Authoritative branch is dev"
[[ "$(git remote get-url origin 2>/dev/null || true)" == "$canonical_origin" ]] && pass "Canonical Iron Signal Systems origin configured" || fail "Canonical Iron Signal Systems origin configured"
git merge-base --is-ancestor "$predecessor_commit" HEAD && pass "Accepted Step 6 commit is an ancestor of the candidate" || fail "Accepted Step 6 commit is an ancestor of the candidate"

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
        bash tools/validation/phase-gates/validate_phase6_step6.sh "${predecessor_args[@]}"
    ) >"$scratch/predecessor.log" 2>&1; then
        pass "Accepted Step 6 predecessor revalidates in isolated dev clone"
    else
        cat "$scratch/predecessor.log" >&2
        fail "Accepted Step 6 predecessor revalidates in isolated dev clone"
    fi
else
    fail "Accepted Step 6 predecessor revalidates in isolated dev clone"
fi

frozen_paths=(
    sql/schema
    sql/deployment
    test-framework/sql
    go/platform/go.mod
    go/platform/go.sum
    go/platform/TOOLCHAIN
    go/platform/cmd
    go/platform/internal/authentication
    go/platform/internal/foundation
    go/platform/internal/observability
    go/platform/internal/processhost
    go/platform/internal/transport
    go/platform/deployment/systemd/iron-signal-foundation-api.service
    go/platform/scripts/build.sh
    go/platform/scripts/test-runtime.sh
    go/platform/scripts/test-process-host.sh
    go/platform/scripts/test-process-host-runtime.sh
    go/platform/scripts/test-foundation-adapter.sh
    go/platform/scripts/test-foundation-adapter-runtime.sh
    go/platform/scripts/test-authenticated-transport.sh
    go/platform/scripts/test-authenticated-transport-runtime.sh
    tools/validation/phase-gates/validate_phase6_step1.sh
    tools/validation/phase-gates/validate_phase6_step2.sh
    tools/validation/phase-gates/validate_phase6_step3.sh
    tools/validation/phase-gates/validate_phase6_step4.sh
    tools/validation/phase-gates/validate_phase6_step5.sh
    tools/validation/phase-gates/validate_phase6_step6.sh
)
for frozen_path in "${frozen_paths[@]}"; do
    if git diff --quiet "$predecessor_commit" -- "$frozen_path"; then
        pass "Accepted predecessor path unchanged: $frozen_path"
    else
        fail "Accepted predecessor path unchanged: $frozen_path"
    fi
done

step6_record="docs/architecture/backend-services/phase-6-step-6-authenticated-request-and-transport-boundary.md"
require_text "$step6_record" "Status:** Accepted implementation checkpoint." "Step 6 record identifies accepted checkpoint status"
require_text "$step6_record" "$predecessor_commit" "Step 6 record names the exact accepted commit"
require_text "$step6_record" "92 PASS and 0 FAIL" "Step 6 record preserves the final complete result"

record="docs/architecture/backend-services/phase-6-step-7-integration-and-monitoring-delivery-workers.md"
require_file "$record" "Step 7 delivery-worker record exists"
require_text "$record" "Status:** Implementation candidate." "Step 7 record identifies implementation-candidate status"
require_text "$record" "No Transaction Across External Delivery" "Step 7 record freezes the transaction boundary"
require_text "$record" "ISSP-DELIVERY-V1" "Step 7 record freezes the relay envelope version"
require_text "$record" "1–32" "Step 7 record freezes the claim batch bound"
require_text "$record" "does not claim finite integration retry exhaustion" "Step 7 record preserves the integration retry non-claim"
require_text "$record" "Phase 6 Step 8 may perform" "Step 7 record identifies the next step"

required_files=(
    go/platform/internal/config/delivery_test.go
    go/platform/internal/database/delivery.go
    go/platform/internal/workers/delivery.go
    go/platform/internal/workers/delivery_test.go
    go/platform/internal/workers/delivery_integration_test.go
    go/platform/internal/workers/runner.go
    go/platform/testdata/phase6-step7/delivery-worker-fixtures.sql
    go/platform/scripts/test-delivery-workers.sh
    go/platform/scripts/test-delivery-workers-runtime.sh
    tools/validation/phase-gates/validate_phase6_step7.sh
)
for required_path in "${required_files[@]}"; do
    require_file "$required_path" "Step 7 artifact exists: $required_path"
done
for executable_path in go/platform/scripts/test-delivery-workers.sh go/platform/scripts/test-delivery-workers-runtime.sh tools/validation/phase-gates/validate_phase6_step7.sh; do
    require_executable "$executable_path" "Executable: $executable_path"
done

required_routines=(
    integration.claim_outbox_events
    integration.mark_outbox_event_delivered
    integration.reschedule_outbox_event
    observability.claim_monitoring_deliveries
    observability.mark_monitoring_delivery_delivered
    observability.reschedule_monitoring_delivery
)
for routine in "${required_routines[@]}"; do
    count="$(grep -R -F "$routine" go/platform/internal --include='*.go' | grep -v '_test.go' | wc -l)"
    [[ "$count" -eq 1 ]] && pass "Protected worker routine is confined to one operation-specific database statement: $routine" || fail "Protected worker routine is confined to one operation-specific database statement: $routine"
done

require_text go/platform/internal/database/delivery.go "ClaimIntegrationOutbox" "Database package exposes the exact integration claim boundary"
require_text go/platform/internal/database/delivery.go "MarkIntegrationDelivered" "Database package exposes the exact integration completion boundary"
require_text go/platform/internal/database/delivery.go "RescheduleIntegration" "Database package exposes the exact integration retry boundary"
require_text go/platform/internal/database/delivery.go "ClaimMonitoringDeliveries" "Database package exposes the exact monitoring claim boundary"
require_text go/platform/internal/database/delivery.go "MarkMonitoringDelivered" "Database package exposes the exact monitoring completion boundary"
require_text go/platform/internal/database/delivery.go "RescheduleMonitoring" "Database package exposes the exact monitoring retry boundary"
require_text go/platform/internal/database/delivery.go "statement_timestamp() + (\$3::bigint * interval '1 microsecond')" "Retry time is based on PostgreSQL statement time"

if grep -R -E '\b(Begin|BeginTx|Commit|Rollback)\s*\(' go/platform/internal/workers --include='*.go' | grep -v '_test.go' >/dev/null 2>&1; then
    fail "Worker package opens no PostgreSQL transaction around external delivery"
else
    pass "Worker package opens no PostgreSQL transaction around external delivery"
fi
if grep -R -E '\b(SELECT|INSERT|UPDATE|DELETE|CALL)\b|integration\.|observability\.' go/platform/internal/workers --include='*.go' | grep -v '_test.go' >/dev/null 2>&1; then
    fail "Worker package contains no SQL or protected routine reference"
else
    pass "Worker package contains no SQL or protected routine reference"
fi
if grep -R -F 'github.com/jackc/pgx' go/platform/internal --include='*.go' | grep -v 'internal/database/' >/dev/null 2>&1; then
    fail "pgx imports remain confined to internal/database"
else
    pass "pgx imports remain confined to internal/database"
fi

require_text go/platform/internal/workers/delivery.go "deliveryEnvelopeVersion  = \"ISSP-DELIVERY-V1\"" "Worker uses the exact relay envelope version"
require_text go/platform/internal/workers/delivery.go "maximumEnvelopeBytes     = 256 * 1024" "Worker envelope size is bounded"
require_text go/platform/internal/workers/delivery.go "Idempotency-Key" "Worker sends the durable idempotency key"
require_text go/platform/internal/workers/delivery.go "func (c *httpRelayClient) Close()" "Relay client defines explicit credential cleanup"
require_text go/platform/internal/workers/delivery.go "c.token[index] = 0" "Relay client zeroes the retained credential"
require_text go/platform/internal/bootstrap/run.go "deliveryRunner.Close()" "Bootstrap closes the drained worker credential boundary"
require_text go/platform/internal/workers/delivery.go "Proxy:                 nil" "Worker disables ambient HTTP proxies"
require_text go/platform/internal/workers/delivery.go "CheckRedirect" "Worker rejects redirects"
require_text go/platform/internal/workers/delivery.go "tls.VersionTLS12" "Worker enforces a minimum TLS version"
require_text go/platform/internal/workers/delivery.go "http.NewRequestWithContext(requestContext, http.MethodPost, c.endpoint" "Network authority is confined to the deployment endpoint"
require_text go/platform/internal/workers/runner.go "database.IntegrationDeliveryWorker" "Integration worker identity is explicit"
require_text go/platform/internal/workers/runner.go "database.MonitoringDeliveryWorker" "Monitoring worker identity is explicit"
require_text go/platform/internal/workers/runner.go "semaphore := make(chan struct{}, r.cfg.MaxConcurrent)" "Worker concurrency is bounded"
require_text go/platform/internal/workers/runner.go "waitGroup.Wait()" "Worker drains the current bounded batch"
require_text go/platform/internal/bootstrap/run.go "stopDeliveryWorker" "Bootstrap drains workers before database closure"

if grep -R -E 'http\.NewRequest.*(DestinationReference|ExternalSystemName|ContractKey)' go/platform/internal/workers --include='*.go' >/dev/null 2>&1; then
    fail "Claimed database destination metadata never selects a network address"
else
    pass "Claimed database destination metadata never selects a network address"
fi
if grep -R -F 'ProxyFromEnvironment' go/platform/internal/workers --include='*.go' >/dev/null 2>&1; then
    fail "Worker ignores ambient proxy authority"
else
    pass "Worker ignores ambient proxy authority"
fi
if python3 - <<'PY_DATABASE_BOUNDARY'
from pathlib import Path
import re

for path in Path("go/platform/internal/database").glob("*.go"):
    if path.name.endswith("_test.go"):
        continue
    source = path.read_text(encoding="utf-8")
    for match in re.finditer(
        r"func \([^)]*\*Pool\)\s+([A-Za-z0-9_]+)\s*\((.*?)\)\s*([^\{]*)\{",
        source,
        flags=re.DOTALL,
    ):
        name, parameters, results = match.groups()
        if name in {"Begin", "BeginTx", "Exec", "Query", "QueryRow", "SendBatch", "CopyFrom"}:
            raise SystemExit(1)
        if re.search(r"\b(?:statement|query|sql)\s+string\b", parameters, flags=re.IGNORECASE):
            raise SystemExit(1)
        if "...any" in parameters or "pgx" in results or "pgxpool" in results:
            raise SystemExit(1)
PY_DATABASE_BOUNDARY
then
    pass "Database wrapper exposes no new generic SQL or transaction primitive"
else
    fail "Database wrapper exposes no new generic SQL or transaction primitive"
fi

if git diff --name-only "$predecessor_commit" -- go/platform/go.mod go/platform/go.sum | grep -q .; then
    fail "Step 7 adds no Go module dependency"
else
    pass "Step 7 adds no Go module dependency"
fi
if git diff --name-only "$predecessor_commit" -- sql/schema sql/deployment | grep -q .; then
    fail "Step 7 adds no Foundation or deployment migration"
else
    pass "Step 7 adds no Foundation or deployment migration"
fi
if git diff --name-only "$predecessor_commit" -- go/platform/internal/transport go/platform/internal/authentication go/platform/internal/foundation | grep -q .; then
    fail "Step 7 changes no accepted adapter, authentication, or business transport source"
else
    pass "Step 7 changes no accepted adapter, authentication, or business transport source"
fi

integration_unit="go/platform/deployment/systemd/iron-signal-integration-delivery-worker.service"
monitoring_unit="go/platform/deployment/systemd/iron-signal-monitoring-delivery-worker.service"
for unit in "$integration_unit" "$monitoring_unit"; do
    require_text "$unit" "LoadCredentialEncrypted=delivery-token:" "Worker unit receives an encrypted relay credential: $unit"
    require_text "$unit" 'Environment=ISSP_DELIVERY_TOKEN_FILE=%d/delivery-token' "Worker unit uses the service credential directory: $unit"
    require_text "$unit" "Environment=ISSP_DELIVERY_BATCH_SIZE=8" "Worker unit bounds claim batch: $unit"
    require_text "$unit" "Environment=ISSP_DELIVERY_MAX_CONCURRENT=4" "Worker unit bounds concurrency: $unit"
    require_text "$unit" "Environment=ISSP_DELIVERY_CLAIM_LEASE=30s" "Worker unit bounds claim lease: $unit"
    require_text "$unit" "Environment=ISSP_DELIVERY_REQUEST_TIMEOUT=5s" "Worker unit bounds request timeout: $unit"
    require_text "$unit" "Environment=ISSP_DELIVERY_RETRY_MAXIMUM=5m" "Worker unit bounds retry delay: $unit"
    if grep -E 'ISSP_BUSINESS_LISTEN_ADDRESS|ISSP_TRANSPORT_HMAC_KEY_FILE|transport-hmac-key' "$unit" >/dev/null 2>&1; then
        fail "Worker unit receives no Foundation business transport authority: $unit"
    else
        pass "Worker unit receives no Foundation business transport authority: $unit"
    fi
done
require_text "$integration_unit" "integration-delivery-worker.delivery-token.cred" "Integration worker uses its distinct relay credential"
require_text "$monitoring_unit" "monitoring-delivery-worker.delivery-token.cred" "Monitoring worker uses its distinct relay credential"
if cmp -s "$integration_unit" "$monitoring_unit"; then
    fail "Worker units remain distinct"
else
    pass "Worker units remain distinct"
fi

run_check "Repository diff is whitespace-clean" git diff --check

if (cd go/platform && bash scripts/check.sh) >"$scratch/go-check.log" 2>&1; then pass "Production Go checks pass"; else cat "$scratch/go-check.log" >&2; fail "Production Go checks pass"; fi
if (cd go/platform && bash scripts/test-process-host.sh) >"$scratch/process-host.log" 2>&1; then pass "Accepted process-host static and race validation remains valid"; else cat "$scratch/process-host.log" >&2; fail "Accepted process-host static and race validation remains valid"; fi
if (cd go/platform && bash scripts/test-foundation-adapter.sh) >"$scratch/foundation-adapter.log" 2>&1; then pass "Accepted controlled adapter static and race validation remains valid"; else cat "$scratch/foundation-adapter.log" >&2; fail "Accepted controlled adapter static and race validation remains valid"; fi
if (cd go/platform && bash scripts/test-authenticated-transport.sh) >"$scratch/authenticated-transport.log" 2>&1; then pass "Accepted authenticated transport static and race validation remains valid"; else cat "$scratch/authenticated-transport.log" >&2; fail "Accepted authenticated transport static and race validation remains valid"; fi
if (cd go/platform && bash scripts/test-delivery-workers.sh) >"$scratch/delivery-workers.log" 2>&1; then pass "Delivery-worker static and race validation passes"; else cat "$scratch/delivery-workers.log" >&2; fail "Delivery-worker static and race validation passes"; fi

synchronized_docs=(
    README.md
    docs/README.md
    docs/architecture/README.md
    docs/architecture/backend-services/README.md
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
    require_text "$doc" "Phase 6 Step 7" "Documentation synchronized for Step 7: $doc"
done
if grep -E 'Step 6.*(implementation candidate|active implementation)' "${synchronized_docs[@]}" >/dev/null 2>&1; then
    fail "Stale Step 6 candidate status is absent from current indexes"
else
    pass "Stale Step 6 candidate status is absent from current indexes"
fi

if $static_only; then
    pass "Static-only mode skips disposable delivery-worker execution"
else
    if (cd go/platform && bash scripts/test-delivery-workers-runtime.sh) >"$scratch/step7-runtime.log" 2>&1; then
        pass "Step 7 delivery-worker runtime validation passes"
    else
        cat "$scratch/step7-runtime.log" >&2
        fail "Step 7 delivery-worker runtime validation passes"
    fi
fi

finish
