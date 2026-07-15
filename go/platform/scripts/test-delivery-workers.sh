#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")"

pass_count=0
pass() { pass_count=$((pass_count + 1)); printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

for command_name in go gofmt grep find sort cmp mktemp python3 bash; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "Required worker-test command available: $command_name"
    pass "Required worker-test command available: $command_name"
done

actual_go="$(GOTOOLCHAIN=local go env GOVERSION)"
[[ "$actual_go" == "$required_go" ]] \
    || fail "Exact Go toolchain = $required_go"
pass "Exact Go toolchain = $required_go"

cd "$module_root"

unformatted="$(gofmt -l internal/config internal/database internal/bootstrap internal/workers)"
[[ -z "$unformatted" ]] || { printf '%s\n' "$unformatted" >&2; fail "Step 7 Go source is gofmt-clean"; }
pass "Step 7 Go source is gofmt-clean"

GOTOOLCHAIN=local GOFLAGS='-mod=readonly' go vet ./... >/dev/null
pass "go vet ./..."
GOTOOLCHAIN=local GOFLAGS='-mod=readonly' go test ./... >/dev/null
pass "go test ./..."
GOTOOLCHAIN=local GOFLAGS='-mod=readonly' go test -race ./internal/config ./internal/database ./internal/bootstrap ./internal/workers >/dev/null
pass "Step 7 configuration, database, bootstrap, and worker race tests"
GOTOOLCHAIN=local go mod verify >/dev/null
pass "Go module checksums verify"

required_routines=(
    integration.claim_outbox_events
    integration.mark_outbox_event_delivered
    integration.reschedule_outbox_event
    observability.claim_monitoring_deliveries
    observability.mark_monitoring_delivery_delivered
    observability.reschedule_monitoring_delivery
)
for routine in "${required_routines[@]}"; do
    count="$(grep -R -F "$routine" internal --include='*.go' | grep -v '_test.go' | wc -l)"
    [[ "$count" -eq 1 ]] || fail "Protected worker routine is confined to one operation-specific database statement: $routine"
    pass "Protected worker routine is confined to one operation-specific database statement: $routine"
done

if grep -R -E '\b(Begin|BeginTx|Commit|Rollback)\s*\(' internal/workers --include='*.go' | grep -v '_test.go' >/dev/null 2>&1; then
    fail "Worker package opens no PostgreSQL transaction around external delivery"
fi
pass "Worker package opens no PostgreSQL transaction around external delivery"

if grep -R -E '\b(SELECT|INSERT|UPDATE|DELETE|CALL)\b|integration\.|observability\.' internal/workers --include='*.go' | grep -v '_test.go' >/dev/null 2>&1; then
    fail "Worker package contains no SQL or protected routine reference"
fi
pass "Worker package contains no SQL or protected routine reference"

if grep -R -F 'ProxyFromEnvironment' internal/workers --include='*.go' >/dev/null 2>&1; then
    fail "Outbound relay bypasses ambient proxy configuration"
fi
pass "Outbound relay bypasses ambient proxy configuration"

grep -Fq 'Proxy:                 nil' internal/workers/delivery.go \
    || fail "Outbound relay explicitly disables ambient proxies"
pass "Outbound relay explicitly disables ambient proxies"
grep -Fq 'Idempotency-Key' internal/workers/delivery.go \
    || fail "Outbound delivery sends an idempotency key"
pass "Outbound delivery sends an idempotency key"
grep -Fq 'func (c *httpRelayClient) Close()' internal/workers/delivery.go \
    || fail "Relay client defines explicit credential cleanup"
pass "Relay client defines explicit credential cleanup"
grep -Fq 'c.token[index] = 0' internal/workers/delivery.go \
    || fail "Relay client zeroes the retained credential"
pass "Relay client zeroes the retained credential"
grep -Fq 'maximumEnvelopeBytes     = 256 * 1024' internal/workers/delivery.go \
    || fail "Outbound delivery envelope is bounded"
pass "Outbound delivery envelope is bounded"
grep -Fq 'databaseOperationTimeout = 3 * time.Second' internal/workers/delivery.go \
    || fail "Worker database operations are bounded"
pass "Worker database operations are bounded"
grep -Fq 'statement_timestamp() + ($3::bigint * interval' internal/database/delivery.go \
    || fail "Retry timestamps use PostgreSQL statement time"
pass "Retry timestamps use PostgreSQL statement time"

if grep -R -E 'http\.NewRequest.*(DestinationReference|ExternalSystemName|ContractKey)' internal/workers --include='*.go' >/dev/null 2>&1; then
    fail "Claimed destination metadata is never used as a network address"
fi
pass "Claimed destination metadata is never used as a network address"
grep -Fq 'http.NewRequestWithContext(requestContext, http.MethodPost, c.endpoint' internal/workers/delivery.go \
    || fail "Outbound network authority is confined to the deployment-owned endpoint"
pass "Outbound network authority is confined to the deployment-owned endpoint"

for identity in IntegrationDeliveryWorker MonitoringDeliveryWorker; do
    grep -Fq "database.$identity" internal/workers/runner.go \
        || fail "Worker identity is explicit: $identity"
    pass "Worker identity is explicit: $identity"
done

if grep -R -E '"(delivery_id|outbox_event_id|monitoring_delivery_state_id|aggregate_id|destination_reference)"' internal/workers --include='*.go' | grep -v '_test.go' | grep -E 'logger\.|slog\.' >/dev/null 2>&1; then
    fail "Worker logs contain no protected delivery identifier"
fi
pass "Worker logs contain no protected delivery identifier"

if ! python3 - <<'PY_DATABASE_BOUNDARY'
from pathlib import Path
import re

for path in Path("internal/database").glob("*.go"):
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
    fail "Database wrapper exposes no generic SQL or transaction primitive"
fi
pass "Database wrapper exposes no generic SQL or transaction primitive"

bash -n scripts/test-delivery-workers.sh
pass "Worker static-test Bash syntax"
bash -n scripts/test-delivery-workers-runtime.sh
pass "Worker runtime-test Bash syntax"

printf '\nPhase 6 Step 7 worker static checks: %d PASS, 0 FAIL\n' "$pass_count"
