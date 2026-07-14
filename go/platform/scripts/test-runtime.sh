#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")"

pass_count=0
pass() {
    pass_count=$((pass_count + 1))
    printf 'PASS: %s\n' "$1"
}
fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

for command_name in go pg_config python3 grep chmod mktemp kill seq sleep cat; do
    command -v "$command_name" >/dev/null 2>&1 || fail "Required runtime-test command available: $command_name"
    pass "Required runtime-test command available: $command_name"
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
[[ "$postgres_version" == *" 18."* ]] || fail "Disposable runtime uses PostgreSQL 18"
pass "Disposable runtime uses PostgreSQL 18"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step3-runtime.XXXXXX")"
pgdata="$scratch/pgdata"
socket_dir="$scratch/socket"
log_file="$scratch/postgresql.log"
build_dir="$scratch/build"
mkdir -p "$socket_dir"

pick_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}

postgres_port="$(pick_port)"
postgres_started=false
current_process_id=""
cleanup() {
    if [[ -n "$current_process_id" ]]; then
        kill -TERM "$current_process_id" >/dev/null 2>&1 || true
        wait "$current_process_id" >/dev/null 2>&1 || true
    fi
    if $postgres_started; then
        "$postgres_bindir/pg_ctl" -D "$pgdata" -m immediate stop >/dev/null 2>&1 || true
    fi
    rm -rf -- "$scratch"
}
trap cleanup EXIT

"$postgres_bindir/initdb" \
    -D "$pgdata" \
    --username=postgres \
    --auth-local=trust \
    --auth-host=scram-sha-256 \
    --no-instructions >/dev/null
pass "Disposable PostgreSQL cluster initialized"

"$postgres_bindir/pg_ctl" \
    -D "$pgdata" \
    -l "$log_file" \
    -o "-F -p $postgres_port -h 127.0.0.1 -k $socket_dir" \
    -w start >/dev/null
postgres_started=true
pass "Disposable PostgreSQL cluster started"

psql=("$postgres_bindir/psql" -X -v ON_ERROR_STOP=1 -h "$socket_dir" -p "$postgres_port" -U postgres)
"${psql[@]}" -d postgres -c "CREATE DATABASE issp_phase6_step3" >/dev/null
"${psql[@]}" -d postgres <<'SQL' >/dev/null
SET password_encryption = 'scram-sha-256';
CREATE ROLE issp_service_authorization LOGIN PASSWORD 'Step3Validation2026' CONNECTION LIMIT 4;
CREATE ROLE issp_service_integration_delivery LOGIN PASSWORD 'Step3Validation2026' CONNECTION LIMIT 4;
CREATE ROLE issp_service_monitoring_delivery LOGIN PASSWORD 'Step3Validation2026' CONNECTION LIMIT 4;
SQL
pass "Exact disposable service login roles created"

cd "$module_root"
export GOTOOLCHAIN=local
export GOFLAGS='-mod=readonly'
"$script_dir/build.sh" "$build_dir" >/dev/null
pass "Step 3 runtime binaries built"

roles=(
    issp_service_authorization
    issp_service_integration_delivery
    issp_service_monitoring_delivery
)
executables=(
    foundation-api
    integration-delivery-worker
    monitoring-delivery-worker
)

for index in 0 1 2; do
    role="${roles[$index]}"
    executable="${executables[$index]}"
    dsn_file="$scratch/$role.url"
    printf 'postgresql://%s:%s@127.0.0.1:%s/issp_phase6_step3?sslmode=disable\n' \
        "$role" 'Step3Validation2026' "$postgres_port" >"$dsn_file"
    chmod 0600 "$dsn_file"

    ISSP_TEST_DATABASE_DSN_FILE="$dsn_file" \
    ISSP_TEST_DATABASE_ROLE="$role" \
        go test -tags=integration ./internal/database >/dev/null
    pass "$executable PostgreSQL identity, compatibility, and cancellation integration tests"

    admin_port="$(pick_port)"
    runtime_log="$scratch/$executable.log"
    ISSP_ADMIN_LISTEN_ADDRESS="127.0.0.1:$admin_port" \
    ISSP_DATABASE_DSN_FILE="$dsn_file" \
    ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true \
        "$build_dir/bin/$executable" 2>"$runtime_log" &
    process_id=$!
    current_process_id="$process_id"

    ready=false
    for _ in $(seq 1 100); do
        if ! kill -0 "$process_id" 2>/dev/null; then
            break
        fi
        if python3 -c 'import sys, urllib.request; response=urllib.request.urlopen(sys.argv[1], timeout=0.2); sys.exit(0 if response.status == 200 else 1)' \
            "http://127.0.0.1:$admin_port/readyz" >/dev/null 2>&1; then
            ready=true
            break
        fi
        sleep 0.05
    done
    $ready || {
        cat "$runtime_log" >&2
        fail "$executable became ready"
    }
    pass "$executable became ready"

    python3 -c 'import sys, urllib.request; response=urllib.request.urlopen(sys.argv[1], timeout=1); sys.exit(0 if response.status == 200 else 1)' \
        "http://127.0.0.1:$admin_port/healthz" >/dev/null
    pass "$executable health endpoint remained live"

    kill -TERM "$process_id"
    set +e
    wait "$process_id"
    process_rc=$?
    set -e
    current_process_id=""
    [[ "$process_rc" -eq 0 ]] || {
        cat "$runtime_log" >&2
        fail "$executable graceful SIGTERM exit status"
    }
    pass "$executable graceful SIGTERM exit status"

    if grep -Fq 'Step3Validation2026' "$runtime_log" || grep -Fq 'postgresql://' "$runtime_log"; then
        cat "$runtime_log" >&2
        fail "$executable runtime log contains no database secret"
    fi
    pass "$executable runtime log contains no database secret"
done

wrong_dsn="$scratch/wrong-role.url"
printf 'postgresql://%s:%s@127.0.0.1:%s/issp_phase6_step3?sslmode=disable\n' \
    'issp_service_integration_delivery' 'Step3Validation2026' "$postgres_port" >"$wrong_dsn"
chmod 0600 "$wrong_dsn"
wrong_port="$(pick_port)"
wrong_log="$scratch/wrong-role.log"
set +e
ISSP_ADMIN_LISTEN_ADDRESS="127.0.0.1:$wrong_port" \
ISSP_DATABASE_DSN_FILE="$wrong_dsn" \
ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true \
    "$build_dir/bin/foundation-api" 2>"$wrong_log"
wrong_rc=$?
set -e
[[ "$wrong_rc" -eq 69 ]] || {
    cat "$wrong_log" >&2
    fail "Foundation API rejects another service role with status 69"
}
pass "Foundation API rejects another service role with status 69"

if grep -Fq 'Step3Validation2026' "$wrong_log" || grep -Fq 'postgresql://' "$wrong_log"; then
    cat "$wrong_log" >&2
    fail "Wrong-role denial log contains no database secret"
fi
pass "Wrong-role denial log contains no database secret"

printf '\nPhase 6 Step 3 runtime integration: %d PASS, 0 FAIL\n' "$pass_count"
