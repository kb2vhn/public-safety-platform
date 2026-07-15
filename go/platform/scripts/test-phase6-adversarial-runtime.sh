#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

usage() {
    cat <<'USAGE'
Usage: test-phase6-adversarial-runtime.sh [--results-dir PATH]

Run the Phase 6 Step 8 hostile PostgreSQL and relay campaign, then record
observation-only resource telemetry. Correctness and resource observation are
reported separately; no performance threshold is evaluated.
USAGE
}

results_dir="${TMPDIR:-/tmp}/issp-phase6-step8-results"
while (( $# > 0 )); do
    case "$1" in
        --results-dir)
            (( $# >= 2 )) || { usage >&2; exit 64; }
            results_dir="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
repo_root="$(cd -- "$module_root/../.." && pwd -P)"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")"

pass_count=0
pass() { pass_count=$((pass_count + 1)); printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

required_commands=(
    go pg_config python3 grep chmod mktemp psql awk sed sort cmp
    date uname nproc df sha256sum bash kill sleep seq
)
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "Required Step 8 runtime command available: $command_name"
    pass "Required Step 8 runtime command available: $command_name"
done
[[ -x /usr/bin/time ]] || fail "Required Step 8 runtime command available: /usr/bin/time"
pass "Required Step 8 runtime command available: /usr/bin/time"

actual_go="$(GOTOOLCHAIN=local go env GOVERSION)"
[[ "$actual_go" == "$required_go" ]] || fail "Exact Go toolchain = $required_go"
pass "Exact Go toolchain = $required_go"

postgres_bindir="$(pg_config --bindir)"
for postgres_command in postgres initdb pg_ctl psql; do
    [[ -x "$postgres_bindir/$postgres_command" ]] \
        || fail "PostgreSQL command available: $postgres_command"
    pass "PostgreSQL command available: $postgres_command"
done
postgres_version="$($postgres_bindir/postgres --version 2>/dev/null || true)"
[[ "$postgres_version" == *" 18."* ]] \
    || fail "Disposable Step 8 runtime uses PostgreSQL 18"
pass "Disposable Step 8 runtime uses PostgreSQL 18"

mkdir -p -- "$results_dir"
results_dir="$(cd -- "$results_dir" && pwd -P)"
rm -f -- \
    "$results_dir/phase6-step8-resources.json" \
    "$results_dir/phase6-step8-resources.txt"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step8-runtime.XXXXXX")"
pgdata="$scratch/pgdata"
socket_dir="$scratch/socket"
postgres_log="$scratch/postgresql.log"
database_name="issp_phase6_step8"
time_file="$scratch/campaign.time"
campaign_log="$scratch/campaign.log"
mkdir -p "$socket_dir"

pick_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}
postgres_port="$(pick_port)"
postgres_started=false
lock_pid=""
cleanup() {
    if [[ -n "$lock_pid" ]]; then
        kill "$lock_pid" >/dev/null 2>&1 || true
        wait "$lock_pid" >/dev/null 2>&1 || true
    fi
    if $postgres_started; then
        "$postgres_bindir/pg_ctl" -D "$pgdata" -m immediate stop >/dev/null 2>&1 || true
    fi
    rm -rf -- "$scratch"
}
trap cleanup EXIT

start_epoch_ns="$(date +%s%N)"
"$postgres_bindir/initdb" \
    -D "$pgdata" \
    --username=postgres \
    --auth-local=trust \
    --auth-host=scram-sha-256 \
    --no-instructions >/dev/null
pass "Disposable PostgreSQL cluster initialized"

cat >>"$pgdata/postgresql.conf" <<'PGCONF'
track_io_timing = on
log_lock_waits = on
deadlock_timeout = '100ms'
shared_buffers = '64MB'
max_connections = 40
PGCONF

"$postgres_bindir/pg_ctl" \
    -D "$pgdata" \
    -l "$postgres_log" \
    -o "-F -p $postgres_port -h 127.0.0.1 -k $socket_dir" \
    -w start >/dev/null
postgres_started=true
pass "Disposable PostgreSQL cluster started with hostile-campaign observation settings"

export PATH="$postgres_bindir:$PATH"
export PGHOST="$socket_dir"
export PGPORT="$postgres_port"
export PGUSER=postgres
export PGDATABASE="$database_name"
psql_super=(
    "$postgres_bindir/psql" -X --no-psqlrc --set=ON_ERROR_STOP=1
    -h "$socket_dir" -p "$postgres_port" -U postgres
)

"${psql_super[@]}" -d postgres -c "CREATE DATABASE $database_name" >/dev/null
pass "Disposable Step 8 database created"
start_wal_lsn="$(${psql_super[@]} -qAt -d postgres -c 'SELECT pg_current_wal_lsn()::text')"

foundation_log="$scratch/foundation-apply.log"
deployment_log="$scratch/deployment-apply.log"
(cd "$repo_root" && bash sql/schema/scripts/apply_foundation.sh "$database_name") >"$foundation_log" 2>&1
pass "Accepted Foundation migrations applied"
(cd "$repo_root" && bash sql/deployment/scripts/apply_deployment.sh "$database_name") >"$deployment_log" 2>&1
pass "Accepted Phase 5 deployment boundary applied"

"${psql_super[@]}" -d "$database_name" <<'SQL' >/dev/null
SET password_encryption = 'scram-sha-256';
ALTER ROLE issp_service_authorization PASSWORD 'Step8Authorization2026';
ALTER ROLE issp_service_integration_delivery PASSWORD 'Step8Integration2026';
ALTER ROLE issp_service_monitoring_delivery PASSWORD 'Step8Monitoring2026';
SQL
pass "Distinct disposable service credentials provisioned outside repository SQL"

fixture_output="$scratch/fixture-output.txt"
"${psql_super[@]}" -qAt -d "$database_name" \
    -f "$module_root/testdata/phase6-step5/authorization-policy-binding-fixtures.sql" \
    >"$fixture_output"
locked_decision_id="$(${psql_super[@]} -qAt -d "$database_name" -c "SELECT step5_test.create_fixture('step8_locked', 1, false)::text")"
[[ "$locked_decision_id" =~ ^[0-9a-f-]{36}$ ]] || fail "Locked adapter fixture created"
pass "Locked adapter fixture created"

"${psql_super[@]}" -qAt -d "$database_name" \
    -f "$module_root/testdata/phase6-step8/hostile-delivery-fixtures.sql" \
    >>"$fixture_output"
grep -Fxq 'integration_rows|8' "$fixture_output" || fail "Eight hostile integration fixtures created"
pass "Eight hostile integration fixtures created"
grep -Fxq 'monitoring_rows|8' "$fixture_output" || fail "Eight hostile monitoring fixtures created"
pass "Eight hostile monitoring fixtures created"

foundation_dsn="$scratch/foundation-api.url"
integration_dsn="$scratch/integration-delivery.url"
monitoring_dsn="$scratch/monitoring-delivery.url"
printf 'postgresql://%s:%s@127.0.0.1:%s/%s?sslmode=disable\n' \
    'issp_service_authorization' 'Step8Authorization2026' "$postgres_port" "$database_name" >"$foundation_dsn"
printf 'postgresql://%s:%s@127.0.0.1:%s/%s?sslmode=disable\n' \
    'issp_service_integration_delivery' 'Step8Integration2026' "$postgres_port" "$database_name" >"$integration_dsn"
printf 'postgresql://%s:%s@127.0.0.1:%s/%s?sslmode=disable\n' \
    'issp_service_monitoring_delivery' 'Step8Monitoring2026' "$postgres_port" "$database_name" >"$monitoring_dsn"
chmod 0600 "$foundation_dsn" "$integration_dsn" "$monitoring_dsn"

integration_token="$scratch/integration-delivery-token"
monitoring_token="$scratch/monitoring-delivery-token"
python3 - "$integration_token" "$monitoring_token" <<'PY'
import base64
import pathlib
import sys
values = (
    b"phase6-step8-integration-token-01",
    b"phase6-step8-monitoring-token--02",
)
for path, value in zip(sys.argv[1:], values):
    pathlib.Path(path).write_text(
        base64.urlsafe_b64encode(value).decode("ascii").rstrip("=") + "\n",
        encoding="utf-8",
    )
PY
chmod 0600 "$integration_token" "$monitoring_token"
[[ "$(sha256sum "$integration_token" | awk '{print $1}')" != "$(sha256sum "$monitoring_token" | awk '{print $1}')" ]] \
    || fail "Worker relay credentials are distinct"
pass "Worker relay credentials are distinct"

lock_ready="$scratch/lock-ready"
lock_log="$scratch/locked-record.log"
"${psql_super[@]}" -d "$database_name" >"$lock_log" 2>&1 <<SQL &
BEGIN;
SELECT decision_id
FROM decision.decision_records
WHERE decision_id = '$locked_decision_id'::uuid
FOR UPDATE;
\! touch '$lock_ready'
SELECT pg_sleep(60);
ROLLBACK;
SQL
lock_pid=$!
for _ in $(seq 1 100); do
    [[ -f "$lock_ready" ]] && break
    sleep 0.05
done
[[ -f "$lock_ready" ]] || fail "Protected Decision Record lock acquired for cancellation test"
pass "Protected Decision Record lock acquired for cancellation test"

campaign_script="$scratch/run-campaign.sh"
cat >"$campaign_script" <<'CAMPAIGN'
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$MODULE_ROOT"
export GOTOOLCHAIN=local
export GOFLAGS='-mod=readonly'
ISSP_TEST_DATABASE_DSN_FILE="$FOUNDATION_DSN" \
ISSP_TEST_LOCKED_DECISION_ID="$LOCKED_DECISION_ID" \
    go test -tags=integration -count=1 \
        -run '^TestPhase6Step8AuthorizationPolicyLockWaitHonorsCallerDeadline$' \
        ./internal/foundation
ISSP_TEST_INTEGRATION_DSN_FILE="$INTEGRATION_DSN" \
ISSP_TEST_MONITORING_DSN_FILE="$MONITORING_DSN" \
ISSP_TEST_INTEGRATION_TOKEN_FILE="$INTEGRATION_TOKEN" \
ISSP_TEST_MONITORING_TOKEN_FILE="$MONITORING_TOKEN" \
    go test -tags=integration -count=1 \
        -run '^TestPhase6Step8HostileDeliveryRuntime$' \
        ./internal/workers
CAMPAIGN
chmod 0700 "$campaign_script"

export MODULE_ROOT="$module_root"
export FOUNDATION_DSN="$foundation_dsn"
export LOCKED_DECISION_ID="$locked_decision_id"
export LOCK_PID="$lock_pid"
export INTEGRATION_DSN="$integration_dsn"
export MONITORING_DSN="$monitoring_dsn"
export INTEGRATION_TOKEN="$integration_token"
export MONITORING_TOKEN="$monitoring_token"

set +e
LC_ALL=C /usr/bin/time --verbose --output="$time_file" \
    "$campaign_script" >"$campaign_log" 2>&1
campaign_status=$?
set -e
kill "$lock_pid" >/dev/null 2>&1 || true
wait "$lock_pid" >/dev/null 2>&1 || true
lock_pid=""
if (( campaign_status != 0 )); then
    cat "$campaign_log" >&2
    fail "Step 8 adapter and hostile relay integration campaign passes"
fi
pass "Step 8 adapter and hostile relay integration campaign passes"

integration_status="$(${psql_super[@]} -qAt -d "$database_name" -c "
SELECT string_agg(outbox_event_id::text || ':' || status || ':' || COALESCE(last_error, ''), ',' ORDER BY outbox_event_id)
FROM integration.outbox_events
WHERE integration_contract_id = '81000000-0000-0000-0000-000000000001';
")"
expected_integration='81100000-0000-0000-0000-000000000001:DELIVERED:,81100000-0000-0000-0000-000000000002:RETRY:delivery_timeout,81100000-0000-0000-0000-000000000003:RETRY:delivery_network_error,81100000-0000-0000-0000-000000000004:RETRY:delivery_relay_unavailable,81100000-0000-0000-0000-000000000005:RETRY:delivery_relay_rejected,81100000-0000-0000-0000-000000000006:RETRY:delivery_network_error,81100000-0000-0000-0000-000000000007:RETRY:delivery_network_error,81100000-0000-0000-0000-000000000008:DELIVERED:'
[[ "$integration_status" == "$expected_integration" ]] || { printf 'Actual integration state: %s\n' "$integration_status" >&2; fail "Hostile integration outcomes persist exactly"; }
pass "Hostile integration outcomes persist exactly"

monitoring_status="$(${psql_super[@]} -qAt -d "$database_name" -c "
SELECT string_agg(monitoring_delivery_state_id::text || ':' || delivery_status || ':' || COALESCE(last_error, ''), ',' ORDER BY monitoring_delivery_state_id)
FROM observability.monitoring_delivery_state
WHERE monitoring_subscription_id = '82200000-0000-0000-0000-000000000001';
")"
expected_monitoring='82300000-0000-0000-0000-000000000001:DELIVERED:,82300000-0000-0000-0000-000000000002:RETRY:delivery_timeout,82300000-0000-0000-0000-000000000003:RETRY:delivery_network_error,82300000-0000-0000-0000-000000000004:RETRY:delivery_relay_unavailable,82300000-0000-0000-0000-000000000005:RETRY:delivery_relay_rejected,82300000-0000-0000-0000-000000000006:RETRY:delivery_network_error,82300000-0000-0000-0000-000000000007:FAILED:delivery_network_error,82300000-0000-0000-0000-000000000008:DELIVERED:'
[[ "$monitoring_status" == "$expected_monitoring" ]] || { printf 'Actual monitoring state: %s\n' "$monitoring_status" >&2; fail "Hostile monitoring outcomes persist exactly"; }
pass "Hostile monitoring outcomes persist exactly"

role_psql() {
    local role="$1"
    local password="$2"
    local sql="$3"
    PGPASSWORD="$password" "$postgres_bindir/psql" \
        -X --no-psqlrc --set=ON_ERROR_STOP=1 -qAt \
        -h 127.0.0.1 -p "$postgres_port" -U "$role" -d "$database_name" \
        -c "$sql"
}

expect_role_failure() {
    local label="$1"
    local role="$2"
    local password="$3"
    local sql="$4"
    local output="$scratch/role-failure-$pass_count.log"
    set +e
    role_psql "$role" "$password" "$sql" >"$output" 2>&1
    local status=$?
    set -e
    [[ $status -ne 0 ]] || fail "$label"
    pass "$label"
}

expect_role_failure \
    "Foundation identity cannot claim integration work" \
    issp_service_authorization Step8Authorization2026 \
    "SELECT count(*) FROM integration.claim_outbox_events(1, interval '30 seconds')"
expect_role_failure \
    "Integration identity cannot claim monitoring work" \
    issp_service_integration_delivery Step8Integration2026 \
    "SELECT count(*) FROM observability.claim_monitoring_deliveries(1, interval '30 seconds')"
expect_role_failure \
    "Monitoring identity cannot bind authorization policy" \
    issp_service_monitoring_delivery Step8Monitoring2026 \
    "SELECT decision.bind_authorization_policy('$locked_decision_id'::uuid)"
expect_role_failure \
    "Integration identity has no direct outbox table read" \
    issp_service_integration_delivery Step8Integration2026 \
    "SELECT count(*) FROM integration.outbox_events"
expect_role_failure \
    "Monitoring identity has no direct delivery-state table read" \
    issp_service_monitoring_delivery Step8Monitoring2026 \
    "SELECT count(*) FROM observability.monitoring_delivery_state"

"${psql_super[@]}" -d "$database_name" <<'SQL' >/dev/null
UPDATE integration.outbox_events
SET next_attempt_at = statement_timestamp() + interval '1 hour'
WHERE outbox_event_id IN (
    '81100000-0000-0000-0000-000000000002',
    '81100000-0000-0000-0000-000000000003',
    '81100000-0000-0000-0000-000000000004',
    '81100000-0000-0000-0000-000000000005',
    '81100000-0000-0000-0000-000000000006',
    '81100000-0000-0000-0000-000000000007'
)
AND status = 'RETRY';

UPDATE observability.monitoring_delivery_state
SET next_attempt_at = statement_timestamp() + interval '1 hour'
WHERE monitoring_delivery_state_id IN (
    '82300000-0000-0000-0000-000000000002',
    '82300000-0000-0000-0000-000000000003',
    '82300000-0000-0000-0000-000000000004',
    '82300000-0000-0000-0000-000000000005',
    '82300000-0000-0000-0000-000000000006'
)
AND delivery_status = 'RETRY';

INSERT INTO integration.outbox_events (
    outbox_event_id, integration_contract_id, event_type, aggregate_type,
    aggregate_id, payload, created_at, available_at, status, attempt_count
) VALUES
('81100000-0000-0000-0000-000000000101','81000000-0000-0000-0000-000000000001','STEP8_LEASE_RECOVERY','TEST_RECORD','lease','{}',statement_timestamp()-interval '2 minutes',statement_timestamp()-interval '2 minutes','PENDING',0),
('81100000-0000-0000-0000-000000000102','81000000-0000-0000-0000-000000000001','STEP8_COMPLETION_RACE','TEST_RECORD','race','{}',statement_timestamp()-interval '1 minute',statement_timestamp()-interval '1 minute','PENDING',0);

INSERT INTO observability.health_events (
    health_event_id, component_id, event_type, severity, status,
    first_observed_at, last_observed_at, owner_reference
) VALUES
('82100000-0000-0000-0000-000000000101','82000000-0000-0000-0000-000000000001','STEP8_LEASE_RECOVERY','INFO','OPEN',statement_timestamp(),statement_timestamp(),'phase6-step8'),
('82100000-0000-0000-0000-000000000102','82000000-0000-0000-0000-000000000001','STEP8_COMPLETION_RACE','INFO','OPEN',statement_timestamp(),statement_timestamp(),'phase6-step8');

INSERT INTO observability.monitoring_delivery_state (
    monitoring_delivery_state_id, monitoring_subscription_id, health_event_id,
    delivery_status, attempt_count, next_attempt_at
) VALUES
('82300000-0000-0000-0000-000000000101','82200000-0000-0000-0000-000000000001','82100000-0000-0000-0000-000000000101','PENDING',0,NULL),
('82300000-0000-0000-0000-000000000102','82200000-0000-0000-0000-000000000001','82100000-0000-0000-0000-000000000102','PENDING',0,statement_timestamp()+interval '1 hour');
SQL
pass "Lease-recovery and completion-race fixtures created"

integration_first_claim="$(role_psql issp_service_integration_delivery Step8Integration2026 "SELECT outbox_event_id::text || '|' || attempt_number::text FROM integration.claim_outbox_events(1, interval '10 seconds')")"
[[ "$integration_first_claim" == '81100000-0000-0000-0000-000000000101|1' ]] || fail "Integration lease fixture receives first claim"
pass "Integration lease fixture receives first claim"
"${psql_super[@]}" -d "$database_name" -c "UPDATE integration.outbox_events SET next_attempt_at=statement_timestamp()-interval '1 second' WHERE outbox_event_id='81100000-0000-0000-0000-000000000101'" >/dev/null
integration_second_claim="$(role_psql issp_service_integration_delivery Step8Integration2026 "SELECT outbox_event_id::text || '|' || attempt_number::text FROM integration.claim_outbox_events(1, interval '10 seconds')")"
[[ "$integration_second_claim" == '81100000-0000-0000-0000-000000000101|2' ]] || fail "Expired integration claim is recovered exactly once"
pass "Expired integration claim is recovered exactly once"
[[ "$(role_psql issp_service_integration_delivery Step8Integration2026 "SELECT integration.mark_outbox_event_delivered('81100000-0000-0000-0000-000000000101'::uuid)::integer")" == '1' ]] || fail "Recovered integration claim completes"
pass "Recovered integration claim completes"

integration_race_claim="$(role_psql issp_service_integration_delivery Step8Integration2026 "SELECT outbox_event_id::text FROM integration.claim_outbox_events(1, interval '10 seconds')")"
[[ "$integration_race_claim" == '81100000-0000-0000-0000-000000000102' ]] || fail "Integration completion-race fixture claimed"
pass "Integration completion-race fixture claimed"
integration_race_pids=()
for suffix in a b; do
    (role_psql issp_service_integration_delivery Step8Integration2026 "SELECT integration.mark_outbox_event_delivered('81100000-0000-0000-0000-000000000102'::uuid)::integer" >"$scratch/integration-race-$suffix") &
    integration_race_pids+=("$!")
done
for race_pid in "${integration_race_pids[@]}"; do
    wait "$race_pid"
done
integration_race_result="$(cat "$scratch"/integration-race-* | sort | tr '\n' ' ' | sed 's/ $//')"
[[ "$integration_race_result" == '0 1' ]] || fail "Concurrent integration completion has one winner"
pass "Concurrent integration completion has one winner"

monitoring_first_claim="$(role_psql issp_service_monitoring_delivery Step8Monitoring2026 "SELECT monitoring_delivery_state_id::text || '|' || attempt_number::text FROM observability.claim_monitoring_deliveries(1, interval '10 seconds')")"
[[ "$monitoring_first_claim" == '82300000-0000-0000-0000-000000000101|1' ]] || fail "Monitoring lease fixture receives first claim"
pass "Monitoring lease fixture receives first claim"
"${psql_super[@]}" -d "$database_name" -c "UPDATE observability.monitoring_delivery_state SET next_attempt_at=statement_timestamp()-interval '1 second' WHERE monitoring_delivery_state_id='82300000-0000-0000-0000-000000000101'" >/dev/null
monitoring_second_claim="$(role_psql issp_service_monitoring_delivery Step8Monitoring2026 "SELECT monitoring_delivery_state_id::text || '|' || attempt_number::text FROM observability.claim_monitoring_deliveries(1, interval '10 seconds')")"
[[ "$monitoring_second_claim" == '82300000-0000-0000-0000-000000000101|2' ]] || fail "Expired monitoring claim is recovered exactly once"
pass "Expired monitoring claim is recovered exactly once"
[[ "$(role_psql issp_service_monitoring_delivery Step8Monitoring2026 "SELECT observability.mark_monitoring_delivery_delivered('82300000-0000-0000-0000-000000000101'::uuid)::integer")" == '1' ]] || fail "Recovered monitoring claim completes"
pass "Recovered monitoring claim completes"

"${psql_super[@]}" -d "$database_name" -c "UPDATE observability.monitoring_delivery_state SET next_attempt_at=statement_timestamp()-interval '1 second' WHERE monitoring_delivery_state_id='82300000-0000-0000-0000-000000000102'" >/dev/null
monitoring_race_claim="$(role_psql issp_service_monitoring_delivery Step8Monitoring2026 "SELECT monitoring_delivery_state_id::text FROM observability.claim_monitoring_deliveries(1, interval '10 seconds')")"
[[ "$monitoring_race_claim" == '82300000-0000-0000-0000-000000000102' ]] || fail "Monitoring completion-race fixture claimed"
pass "Monitoring completion-race fixture claimed"
monitoring_race_pids=()
for suffix in a b; do
    (role_psql issp_service_monitoring_delivery Step8Monitoring2026 "SELECT observability.mark_monitoring_delivery_delivered('82300000-0000-0000-0000-000000000102'::uuid)::integer" >"$scratch/monitoring-race-$suffix") &
    monitoring_race_pids+=("$!")
done
for race_pid in "${monitoring_race_pids[@]}"; do
    wait "$race_pid"
done
monitoring_race_result="$(cat "$scratch"/monitoring-race-* | sort | tr '\n' ' ' | sed 's/ $//')"
[[ "$monitoring_race_result" == '0 1' ]] || fail "Concurrent monitoring completion has one winner"
pass "Concurrent monitoring completion has one winner"

if grep -R -Fq --include='*.log' 'Step8Authorization2026' "$scratch" \
    || grep -R -Fq --include='*.log' 'Step8Integration2026' "$scratch" \
    || grep -R -Fq --include='*.log' 'Step8Monitoring2026' "$scratch" \
    || grep -R -Fq --include='*.log' 'postgresql://' "$scratch" \
    || grep -R -Fq --include='*.log' 'cGhhc2U2LXN0ZXA4' "$scratch"
then
    fail "Step 8 runtime logs contain no database or relay secret"
fi
pass "Step 8 runtime logs contain no database or relay secret"

"${psql_super[@]}" -d "$database_name" -c 'SELECT pg_stat_force_next_flush()' >/dev/null 2>&1 || true
end_wal_lsn="$(${psql_super[@]} -qAt -d postgres -c 'SELECT pg_current_wal_lsn()::text')"
wal_bytes="$(${psql_super[@]} -qAt -d postgres -c "SELECT pg_wal_lsn_diff('$end_wal_lsn', '$start_wal_lsn')::bigint")"
postgres_metrics="$(${psql_super[@]} -qAt -d postgres -c "
SELECT
    pg_database_size(datname)::bigint || '|' ||
    xact_commit::bigint || '|' ||
    xact_rollback::bigint || '|' ||
    blks_read::bigint || '|' ||
    blks_hit::bigint || '|' ||
    temp_files::bigint || '|' ||
    temp_bytes::bigint || '|' ||
    deadlocks::bigint || '|' ||
    tup_returned::bigint || '|' ||
    tup_fetched::bigint || '|' ||
    tup_inserted::bigint || '|' ||
    tup_updated::bigint || '|' ||
    tup_deleted::bigint
FROM pg_stat_database
WHERE datname = '$database_name';
")"
IFS='|' read -r database_bytes xact_commit xact_rollback blks_read blks_hit temp_files temp_bytes deadlocks tup_returned tup_fetched tup_inserted tup_updated tup_deleted <<<"$postgres_metrics"
[[ "$deadlocks" == "0" ]] || fail "Hostile runtime records zero PostgreSQL deadlocks"
pass "Hostile runtime records zero PostgreSQL deadlocks"

end_epoch_ns="$(date +%s%N)"
total_elapsed_ns=$((end_epoch_ns - start_epoch_ns))
host_name=""
if [[ -r /proc/sys/kernel/hostname ]]; then
    IFS= read -r host_name </proc/sys/kernel/hostname || true
fi
if [[ -z "$host_name" ]]; then
    host_name="$(uname -n 2>/dev/null || true)"
fi
[[ -n "$host_name" ]] || host_name="unknown"
kernel="$(uname -srmo)"
os_description="$(. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-unknown}" || printf 'unknown')"
logical_cpus="$(nproc)"
cpu_model="$(awk -F: '/^model name[[:space:]]*:/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
memory_kib="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || printf '0')"
disk_available_bytes="$(df -B1 --output=avail "$scratch" | awk 'NR==2 {print $1}')"
postgres_server_version="$(${psql_super[@]} -qAt -d postgres -c "SELECT current_setting('server_version')")"
postgres_server_version_num="$(${psql_super[@]} -qAt -d postgres -c "SELECT current_setting('server_version_num')")"

resources_json="$results_dir/phase6-step8-resources.json"
resources_text="$results_dir/phase6-step8-resources.txt"
export STEP8_TIME_FILE="$time_file"
export STEP8_RESOURCES_JSON="$resources_json"
export STEP8_RESOURCES_TEXT="$resources_text"
export STEP8_HOST_NAME="$host_name"
export STEP8_KERNEL="$kernel"
export STEP8_OS_DESCRIPTION="$os_description"
export STEP8_LOGICAL_CPUS="$logical_cpus"
export STEP8_CPU_MODEL="$cpu_model"
export STEP8_MEMORY_KIB="$memory_kib"
export STEP8_DISK_AVAILABLE_BYTES="$disk_available_bytes"
export STEP8_GO_VERSION="$actual_go"
export STEP8_POSTGRES_VERSION="$postgres_server_version"
export STEP8_POSTGRES_VERSION_NUM="$postgres_server_version_num"
export STEP8_TOTAL_ELAPSED_NS="$total_elapsed_ns"
export STEP8_DATABASE_BYTES="$database_bytes"
export STEP8_WAL_BYTES="$wal_bytes"
export STEP8_XACT_COMMIT="$xact_commit"
export STEP8_XACT_ROLLBACK="$xact_rollback"
export STEP8_BLKS_READ="$blks_read"
export STEP8_BLKS_HIT="$blks_hit"
export STEP8_TEMP_FILES="$temp_files"
export STEP8_TEMP_BYTES="$temp_bytes"
export STEP8_DEADLOCKS="$deadlocks"
export STEP8_TUP_RETURNED="$tup_returned"
export STEP8_TUP_FETCHED="$tup_fetched"
export STEP8_TUP_INSERTED="$tup_inserted"
export STEP8_TUP_UPDATED="$tup_updated"
export STEP8_TUP_DELETED="$tup_deleted"

python3 <<'PY'
import json
import os
import pathlib
import re


def integer(name):
    return int(os.environ[name])


def floating(value):
    try:
        return float(value)
    except ValueError:
        return 0.0


time_text = pathlib.Path(os.environ["STEP8_TIME_FILE"]).read_text(encoding="utf-8", errors="replace")
fields = {}
for line in time_text.splitlines():
    if ": " in line:
        key, value = line.strip().split(": ", 1)
        fields[key] = value

def time_value(prefix):
    for key, value in fields.items():
        if key.startswith(prefix):
            return value
    return ""

cpu_percent_text = time_value("Percent of CPU this job got").rstrip("%")
report = {
    "schema_version": "ISSP-PHASE6-STEP8-RESOURCE-V1",
    "correctness_result": "PASS",
    "resource_observation": "RECORDED",
    "performance_thresholds": "NOT_EVALUATED",
    "environment": {
        "host_name": os.environ["STEP8_HOST_NAME"],
        "kernel": os.environ["STEP8_KERNEL"],
        "operating_system": os.environ["STEP8_OS_DESCRIPTION"],
        "logical_cpu_count": integer("STEP8_LOGICAL_CPUS"),
        "cpu_model": os.environ["STEP8_CPU_MODEL"],
        "installed_memory_kib": integer("STEP8_MEMORY_KIB"),
        "disk_available_bytes": integer("STEP8_DISK_AVAILABLE_BYTES"),
        "go_version": os.environ["STEP8_GO_VERSION"],
        "postgresql_version": os.environ["STEP8_POSTGRES_VERSION"],
        "postgresql_version_num": integer("STEP8_POSTGRES_VERSION_NUM"),
    },
    "timing": {
        "total_elapsed_ns": integer("STEP8_TOTAL_ELAPSED_NS"),
        "campaign_elapsed_text": time_value("Elapsed (wall clock) time"),
    },
    "process_tree": {
        "user_cpu_seconds": floating(time_value("User time (seconds)")),
        "system_cpu_seconds": floating(time_value("System time (seconds)")),
        "cpu_percent": floating(cpu_percent_text),
        "maximum_resident_set_kib": int(time_value("Maximum resident set size (kbytes)") or 0),
        "major_page_faults": int(time_value("Major (requiring I/O) page faults") or 0),
        "minor_page_faults": int(time_value("Minor (reclaiming a frame) page faults") or 0),
        "filesystem_inputs": int(time_value("File system inputs") or 0),
        "filesystem_outputs": int(time_value("File system outputs") or 0),
        "voluntary_context_switches": int(time_value("Voluntary context switches") or 0),
        "involuntary_context_switches": int(time_value("Involuntary context switches") or 0),
    },
    "postgresql": {
        "database_size_bytes": integer("STEP8_DATABASE_BYTES"),
        "wal_generation_bytes": integer("STEP8_WAL_BYTES"),
        "transactions_committed": integer("STEP8_XACT_COMMIT"),
        "transactions_rolled_back": integer("STEP8_XACT_ROLLBACK"),
        "shared_blocks_read": integer("STEP8_BLKS_READ"),
        "shared_blocks_hit": integer("STEP8_BLKS_HIT"),
        "temporary_files": integer("STEP8_TEMP_FILES"),
        "temporary_bytes": integer("STEP8_TEMP_BYTES"),
        "deadlocks": integer("STEP8_DEADLOCKS"),
        "tuples_returned": integer("STEP8_TUP_RETURNED"),
        "tuples_fetched": integer("STEP8_TUP_FETCHED"),
        "tuples_inserted": integer("STEP8_TUP_INSERTED"),
        "tuples_updated": integer("STEP8_TUP_UPDATED"),
        "tuples_deleted": integer("STEP8_TUP_DELETED"),
    },
    "campaign": {
        "adapter_lock_cancellation": "PASS",
        "relay_timeout": "PASS",
        "relay_disconnect": "PASS",
        "relay_redirect_rejection": "PASS",
        "relay_malformed_response": "PASS",
        "relay_response_redaction": "PASS",
        "ambient_proxy_rejection": "PASS",
        "claim_lease_recovery": "PASS",
        "completion_race_single_winner": "PASS",
        "cross_role_denial": "PASS",
    },
}

failures = []
if report["correctness_result"] != "PASS": failures.append("correctness result")
if report["resource_observation"] != "RECORDED": failures.append("resource observation")
if report["performance_thresholds"] != "NOT_EVALUATED": failures.append("threshold status")
if report["timing"]["total_elapsed_ns"] <= 0: failures.append("total elapsed")
if report["process_tree"]["maximum_resident_set_kib"] <= 0: failures.append("maximum RSS")
if report["postgresql"]["database_size_bytes"] <= 0: failures.append("database size")
if report["postgresql"]["wal_generation_bytes"] < 0: failures.append("WAL")
if report["postgresql"]["deadlocks"] != 0: failures.append("deadlocks")
if report["environment"]["logical_cpu_count"] <= 0: failures.append("CPU count")
if report["environment"]["installed_memory_kib"] <= 0: failures.append("memory")
if not report["environment"]["host_name"]: failures.append("host")
if failures:
    raise SystemExit("Malformed Step 8 resource report: " + ", ".join(failures))

json_path = pathlib.Path(os.environ["STEP8_RESOURCES_JSON"])
text_path = pathlib.Path(os.environ["STEP8_RESOURCES_TEXT"])
json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
text_path.write_text(
    "\n".join([
        "Iron Signal Platform Phase 6 Step 8 Resource Observation",
        "",
        "Correctness result: PASS",
        "Resource observation: RECORDED",
        "Performance thresholds: NOT_EVALUATED",
        "",
        f"Host: {report['environment']['host_name']}",
        f"Kernel: {report['environment']['kernel']}",
        f"Operating system: {report['environment']['operating_system']}",
        f"Logical CPUs: {report['environment']['logical_cpu_count']}",
        f"Installed memory KiB: {report['environment']['installed_memory_kib']}",
        f"Go version: {report['environment']['go_version']}",
        f"PostgreSQL version: {report['environment']['postgresql_version']}",
        f"Total elapsed ns: {report['timing']['total_elapsed_ns']}",
        f"Maximum resident set KiB: {report['process_tree']['maximum_resident_set_kib']}",
        f"Database size bytes: {report['postgresql']['database_size_bytes']}",
        f"WAL generation bytes: {report['postgresql']['wal_generation_bytes']}",
        f"Shared blocks read: {report['postgresql']['shared_blocks_read']}",
        f"Shared blocks hit: {report['postgresql']['shared_blocks_hit']}",
        f"Temporary files: {report['postgresql']['temporary_files']}",
        f"Temporary bytes: {report['postgresql']['temporary_bytes']}",
        f"Deadlocks: {report['postgresql']['deadlocks']}",
        "",
    ]) + "\n",
    encoding="utf-8",
)
PY
pass "Observation-only resource reports are complete and machine-readable"

printf 'Correctness result: PASS\n'
printf 'Resource observation: RECORDED\n'
printf 'Performance thresholds: NOT_EVALUATED\n'
printf 'Resource JSON: %s\n' "$resources_json"
printf 'Resource text: %s\n' "$resources_text"
printf 'RESOURCE OBSERVATION: database_bytes=%s wal_bytes=%s max_rss_kib=%s thresholds=NOT_EVALUATED\n' \
    "$database_bytes" "$wal_bytes" \
    "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["process_tree"]["maximum_resident_set_kib"])' "$resources_json")"
printf '\nPhase 6 Step 8 hostile runtime: %d PASS, 0 FAIL\n' "$pass_count"
