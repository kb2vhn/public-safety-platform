#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
repo_root="$(cd -- "$module_root/../.." && pwd -P)"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")"

pass_count=0
pass() { pass_count=$((pass_count + 1)); printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

required_commands=(go pg_config python3 grep chmod mktemp psql awk sed sort)
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "Required worker runtime command available: $command_name"
    pass "Required worker runtime command available: $command_name"
done

actual_go="$(GOTOOLCHAIN=local go env GOVERSION)"
[[ "$actual_go" == "$required_go" ]] || fail "Exact Go toolchain = $required_go"
pass "Exact Go toolchain = $required_go"

postgres_bindir="$(pg_config --bindir)"
for postgres_command in postgres initdb pg_ctl psql; do
    [[ -x "$postgres_bindir/$postgres_command" ]] || fail "PostgreSQL command available: $postgres_command"
    pass "PostgreSQL command available: $postgres_command"
done
postgres_version="$($postgres_bindir/postgres --version 2>/dev/null || true)"
[[ "$postgres_version" == *" 18."* ]] || fail "Disposable worker runtime uses PostgreSQL 18"
pass "Disposable worker runtime uses PostgreSQL 18"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step7-runtime.XXXXXX")"
pgdata="$scratch/pgdata"
socket_dir="$scratch/socket"
postgres_log="$scratch/postgresql.log"
database_name="issp_phase6_step7"
mkdir -p "$socket_dir"

pick_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}
postgres_port="$(pick_port)"
postgres_started=false
cleanup() {
    if $postgres_started; then
        "$postgres_bindir/pg_ctl" -D "$pgdata" -m immediate stop >/dev/null 2>&1 || true
    fi
    rm -rf -- "$scratch"
}
trap cleanup EXIT

"$postgres_bindir/initdb" -D "$pgdata" --username=postgres --auth-local=trust --auth-host=scram-sha-256 --no-instructions >/dev/null
pass "Disposable PostgreSQL cluster initialized"
"$postgres_bindir/pg_ctl" -D "$pgdata" -l "$postgres_log" -o "-F -p $postgres_port -h 127.0.0.1 -k $socket_dir" -w start >/dev/null
postgres_started=true
pass "Disposable PostgreSQL cluster started"

export PATH="$postgres_bindir:$PATH"
export PGHOST="$socket_dir"
export PGPORT="$postgres_port"
export PGUSER=postgres
export PGDATABASE="$database_name"
psql_super=("$postgres_bindir/psql" -X --no-psqlrc --set=ON_ERROR_STOP=1 -h "$socket_dir" -p "$postgres_port" -U postgres)

"${psql_super[@]}" -d postgres -c "CREATE DATABASE $database_name" >/dev/null
pass "Disposable Step 7 database created"

foundation_log="$scratch/foundation-apply.log"
deployment_log="$scratch/deployment-apply.log"
(cd "$repo_root" && bash sql/schema/scripts/apply_foundation.sh "$database_name") >"$foundation_log" 2>&1
pass "Accepted Foundation migrations applied"
(cd "$repo_root" && bash sql/deployment/scripts/apply_deployment.sh "$database_name") >"$deployment_log" 2>&1
pass "Accepted Phase 5 deployment boundary applied"

"${psql_super[@]}" -d "$database_name" <<'SQL' >/dev/null
SET password_encryption = 'scram-sha-256';
ALTER ROLE issp_service_integration_delivery PASSWORD 'Step7Validation2026';
ALTER ROLE issp_service_monitoring_delivery PASSWORD 'Step7Validation2026';
SQL
pass "Disposable worker credentials provisioned outside repository SQL"

fixture_file="$module_root/testdata/phase6-step7/delivery-worker-fixtures.sql"
"${psql_super[@]}" -qAt -d "$database_name" -f "$fixture_file" >"$scratch/fixture-output.txt"
pass "Step 7 integration and monitoring fixtures created"

integration_dsn="$scratch/integration-delivery.url"
monitoring_dsn="$scratch/monitoring-delivery.url"
printf 'postgresql://%s:%s@127.0.0.1:%s/%s?sslmode=disable\n' \
    'issp_service_integration_delivery' 'Step7Validation2026' "$postgres_port" "$database_name" >"$integration_dsn"
printf 'postgresql://%s:%s@127.0.0.1:%s/%s?sslmode=disable\n' \
    'issp_service_monitoring_delivery' 'Step7Validation2026' "$postgres_port" "$database_name" >"$monitoring_dsn"
chmod 0600 "$integration_dsn" "$monitoring_dsn"

delivery_token="$scratch/delivery-token"
python3 - "$delivery_token" <<'PY'
import base64
import pathlib
import sys
value = b"0123456789abcdef0123456789abcdef"
pathlib.Path(sys.argv[1]).write_text(
    base64.urlsafe_b64encode(value).decode("ascii").rstrip("=") + "\n",
    encoding="utf-8",
)
PY
chmod 0600 "$delivery_token"

cd "$module_root"
export GOTOOLCHAIN=local
export GOFLAGS='-mod=readonly'
worker_test_log="$scratch/delivery-worker-test.log"
ISSP_TEST_INTEGRATION_DSN_FILE="$integration_dsn" \
ISSP_TEST_MONITORING_DSN_FILE="$monitoring_dsn" \
ISSP_TEST_DELIVERY_TOKEN_FILE="$delivery_token" \
    go test -tags=integration -run '^TestIntegrationDeliveryWorkers$' ./internal/workers >"$worker_test_log" 2>&1
pass "Typed integration and monitoring worker runtime tests pass"

integration_status="$(${psql_super[@]} -qAt -d "$database_name" -c "
SELECT string_agg(outbox_event_id::text || ':' || status || ':' || COALESCE(last_error, ''), ',' ORDER BY outbox_event_id)
FROM integration.outbox_events;
")"
expected_integration='71100000-0000-0000-0000-000000000001:DELIVERED:,71100000-0000-0000-0000-000000000002:DELIVERED:,71100000-0000-0000-0000-000000000003:DELIVERED:,71100000-0000-0000-0000-000000000004:RETRY:delivery_relay_unavailable'
[[ "$integration_status" == "$expected_integration" ]] || { printf 'actual integration state: %s\n' "$integration_status" >&2; fail "Integration completion and retry state persists exactly"; }
pass "Integration completion and retry state persists exactly"

monitoring_status="$(${psql_super[@]} -qAt -d "$database_name" -c "
SELECT string_agg(monitoring_delivery_state_id::text || ':' || delivery_status || ':' || COALESCE(last_error, ''), ',' ORDER BY monitoring_delivery_state_id)
FROM observability.monitoring_delivery_state;
")"
expected_monitoring='72300000-0000-0000-0000-000000000001:DELIVERED:,72300000-0000-0000-0000-000000000002:RETRY:delivery_relay_unavailable,72300000-0000-0000-0000-000000000003:FAILED:delivery_relay_unavailable'
[[ "$monitoring_status" == "$expected_monitoring" ]] || { printf 'actual monitoring state: %s\n' "$monitoring_status" >&2; fail "Monitoring delivered, retry, and exhausted state persists exactly"; }
pass "Monitoring delivered, retry, and exhausted state persists exactly"

privilege_posture="$(${psql_super[@]} -qAt -d "$database_name" -c "
SELECT
    has_function_privilege('issp_service_integration_delivery','integration.claim_outbox_events(integer,interval)','EXECUTE')::integer || '|' ||
    has_function_privilege('issp_service_integration_delivery','integration.mark_outbox_event_delivered(uuid)','EXECUTE')::integer || '|' ||
    has_function_privilege('issp_service_integration_delivery','integration.reschedule_outbox_event(uuid,text,timestamptz)','EXECUTE')::integer || '|' ||
    has_function_privilege('issp_service_monitoring_delivery','observability.claim_monitoring_deliveries(integer,interval)','EXECUTE')::integer || '|' ||
    has_function_privilege('issp_service_monitoring_delivery','observability.mark_monitoring_delivery_delivered(uuid)','EXECUTE')::integer || '|' ||
    has_function_privilege('issp_service_monitoring_delivery','observability.reschedule_monitoring_delivery(uuid,text,timestamptz)','EXECUTE')::integer || '|' ||
    has_function_privilege('issp_service_monitoring_delivery','integration.claim_outbox_events(integer,interval)','EXECUTE')::integer || '|' ||
    has_function_privilege('issp_service_integration_delivery','observability.claim_monitoring_deliveries(integer,interval)','EXECUTE')::integer || '|' ||
    (has_table_privilege('issp_service_integration_delivery','integration.outbox_events','SELECT') OR has_table_privilege('issp_service_integration_delivery','integration.outbox_events','UPDATE'))::integer || '|' ||
    (has_table_privilege('issp_service_monitoring_delivery','observability.monitoring_delivery_state','SELECT') OR has_table_privilege('issp_service_monitoring_delivery','observability.monitoring_delivery_state','UPDATE'))::integer;
")"
[[ "$privilege_posture" == '1|1|1|1|1|1|0|0|0|0' ]] || fail "Exact worker routine privilege and no direct table privilege posture"
pass "Exact worker routine privilege and no direct table privilege posture"

for wrong_role in issp_service_integration_delivery issp_service_monitoring_delivery; do
    wrong_log="$scratch/$wrong_role-wrong-routine.log"
    if [[ "$wrong_role" == 'issp_service_integration_delivery' ]]; then
        wrong_sql="SELECT count(*) FROM observability.claim_monitoring_deliveries(1, interval '30 seconds');"
    else
        wrong_sql="SELECT count(*) FROM integration.claim_outbox_events(1, interval '30 seconds');"
    fi
    set +e
    PGPASSWORD='Step7Validation2026' "$postgres_bindir/psql" -X --no-psqlrc --set=ON_ERROR_STOP=1 -h 127.0.0.1 -p "$postgres_port" -U "$wrong_role" -d "$database_name" -c "$wrong_sql" >"$wrong_log" 2>&1
    wrong_rc=$?
    set -e
    [[ "$wrong_rc" -ne 0 ]] || fail "Cross-worker routine invocation is denied: $wrong_role"
    pass "Cross-worker routine invocation is denied: $wrong_role"
done

if grep -R -Fq --include='*.log' 'Step7Validation2026' "$scratch" \
    || grep -R -Fq --include='*.log' 'postgresql://' "$scratch" \
    || grep -R -Fq --include='*.log' 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY' "$scratch"
then
    fail "Step 7 runtime logs contain no database or relay secret"
fi
pass "Step 7 runtime logs contain no database or relay secret"

printf 'RESOURCE OBSERVATION: fixture_rows=7 worker_processes=2 thresholds=NOT_EVALUATED\n'
printf '\nPhase 6 Step 7 worker runtime: %d PASS, 0 FAIL\n' "$pass_count"
