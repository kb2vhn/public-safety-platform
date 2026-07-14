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

for command_name in \
    go pg_config python3 grep chmod mktemp kill seq sleep cat bash
do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "Required hostile-runtime command available: $command_name"
    pass "Required hostile-runtime command available: $command_name"
done

actual_go="$(GOTOOLCHAIN=local go env GOVERSION)"
[[ "$actual_go" == "$required_go" ]] \
    || fail "Exact Go toolchain = $required_go"
pass "Exact Go toolchain = $required_go"

postgres_bindir="$(pg_config --bindir)"
for postgres_command in postgres initdb pg_ctl psql; do
    [[ -x "$postgres_bindir/$postgres_command" ]] \
        || fail "PostgreSQL command available: $postgres_command"
    pass "PostgreSQL command available: $postgres_command"
done

postgres_version="$("$postgres_bindir/postgres" --version 2>/dev/null || true)"
[[ "$postgres_version" == *" 18."* ]] \
    || fail "Disposable hostile runtime uses PostgreSQL 18"
pass "Disposable hostile runtime uses PostgreSQL 18"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step4-runtime.XXXXXX")"
pgdata="$scratch/pgdata"
socket_dir="$scratch/postgres-socket"
postgres_log="$scratch/postgresql.log"
build_dir="$scratch/build"
mkdir -p "$socket_dir"

postgres_started=false
current_process_id=""
declare -a helper_pids=()

cleanup() {
    if [[ -n "$current_process_id" ]]; then
        kill -TERM "$current_process_id" >/dev/null 2>&1 || true
        wait "$current_process_id" >/dev/null 2>&1 || true
    fi
    for helper_pid in "${helper_pids[@]:-}"; do
        kill -TERM "$helper_pid" >/dev/null 2>&1 || true
        wait "$helper_pid" >/dev/null 2>&1 || true
    done
    if $postgres_started; then
        "$postgres_bindir/pg_ctl" \
            -D "$pgdata" \
            -m immediate \
            stop >/dev/null 2>&1 || true
    fi
    rm -rf -- "$scratch"
}
trap cleanup EXIT

pick_port() {
    python3 -c \
        'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}

cat >"$scratch/notify_receiver.py" <<'PY'
import os
import socket
import sys

socket_path, log_path = sys.argv[1], sys.argv[2]
try:
    os.unlink(socket_path)
except FileNotFoundError:
    pass

receiver = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
receiver.bind(socket_path)
with open(log_path, "ab", buffering=0) as output:
    while True:
        payload = receiver.recv(4096)
        output.write(b"--- datagram ---\n")
        output.write(payload)
        output.write(b"\n")
        if b"STOPPING=1" in payload:
            break
PY

receiver_pid_result=""

start_receiver() {
    local notify_socket="$1"
    local notify_log="$2"

    python3 "$scratch/notify_receiver.py" \
        "$notify_socket" \
        "$notify_log" \
        >/dev/null 2>&1 &
    receiver_pid_result=$!
    helper_pids+=("$receiver_pid_result")

    for _ in $(seq 1 100); do
        [[ -S "$notify_socket" ]] && return 0
        sleep 0.02
    done
    return 1
}

wait_for_log() {
    local pattern="$1"
    local log_file="$2"
    local attempts="${3:-150}"

    for _ in $(seq 1 "$attempts"); do
        grep -Fq "$pattern" "$log_file" 2>/dev/null && return 0
        sleep 0.04
    done
    return 1
}

wait_for_exit() {
    local process_id="$1"
    local attempts="${2:-150}"

    for _ in $(seq 1 "$attempts"); do
        kill -0 "$process_id" 2>/dev/null || return 0
        sleep 0.04
    done
    return 1
}

"$postgres_bindir/initdb" \
    -D "$pgdata" \
    --username=postgres \
    --auth-local=trust \
    --auth-host=scram-sha-256 \
    --no-instructions >/dev/null
pass "Disposable PostgreSQL cluster initialized"

postgres_port="$(pick_port)"
"$postgres_bindir/pg_ctl" \
    -D "$pgdata" \
    -l "$postgres_log" \
    -o "-F -p $postgres_port -h 127.0.0.1 -k $socket_dir" \
    -w start >/dev/null
postgres_started=true
pass "Disposable PostgreSQL cluster started"

psql=(
    "$postgres_bindir/psql"
    -X
    -v ON_ERROR_STOP=1
    -h "$socket_dir"
    -p "$postgres_port"
    -U postgres
)

"${psql[@]}" -d postgres \
    -c "CREATE DATABASE issp_phase6_step4" >/dev/null
"${psql[@]}" -d postgres <<'SQL' >/dev/null
SET password_encryption = 'scram-sha-256';
CREATE ROLE issp_service_authorization LOGIN PASSWORD 'Step4Validation2026' CONNECTION LIMIT 4;
CREATE ROLE issp_service_integration_delivery LOGIN PASSWORD 'Step4Validation2026' CONNECTION LIMIT 4;
CREATE ROLE issp_service_monitoring_delivery LOGIN PASSWORD 'Step4Validation2026' CONNECTION LIMIT 4;
SQL
pass "Exact disposable Step 4 service roles created"

cd "$module_root"
export GOTOOLCHAIN=local
export GOFLAGS='-mod=readonly'
"$script_dir/build.sh" "$build_dir" >/dev/null
pass "Step 4 runtime binaries built"

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

    printf 'postgresql://%s:%s@127.0.0.1:%s/issp_phase6_step4?sslmode=disable\n' \
        "$role" \
        'Step4Validation2026' \
        "$postgres_port" >"$dsn_file"
    chmod 0600 "$dsn_file"

    notify_socket="$scratch/$executable.notify"
    notify_log="$scratch/$executable.notify.log"
    runtime_log="$scratch/$executable.runtime.log"

    start_receiver "$notify_socket" "$notify_log" \
        || fail "$executable notification receiver started"
    receiver_pid="$receiver_pid_result"

    admin_port="$(pick_port)"
    ISSP_ADMIN_LISTEN_ADDRESS="127.0.0.1:$admin_port" \
    ISSP_DATABASE_DSN_FILE="$dsn_file" \
    ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true \
    NOTIFY_SOCKET="$notify_socket" \
    WATCHDOG_USEC=2000000 \
        bash -c 'export WATCHDOG_PID=$$; exec "$1"' \
        _ "$build_dir/bin/$executable" \
        2>"$runtime_log" &
    process_id=$!
    current_process_id="$process_id"

    wait_for_log 'READY=1' "$notify_log" \
        || {
            cat "$runtime_log" >&2
            cat "$notify_log" >&2
            fail "$executable emitted readiness notification"
        }
    pass "$executable emitted readiness notification"

    ready=false
    for _ in $(seq 1 100); do
        if python3 -c \
            'import sys, urllib.request; r=urllib.request.urlopen(sys.argv[1], timeout=.2); sys.exit(0 if r.status == 200 else 1)' \
            "http://127.0.0.1:$admin_port/readyz" \
            >/dev/null 2>&1
        then
            ready=true
            break
        fi
        sleep 0.04
    done
    $ready || {
        cat "$runtime_log" >&2
        fail "$executable became ready"
    }
    pass "$executable became ready"

    wait_for_log 'WATCHDOG=1' "$notify_log" \
        || {
            cat "$runtime_log" >&2
            cat "$notify_log" >&2
            fail "$executable emitted watchdog notification"
        }
    pass "$executable emitted watchdog notification"

    kill -TERM "$process_id"
    set +e
    wait "$process_id"
    process_rc=$?
    set -e
    current_process_id=""

    [[ "$process_rc" -eq 0 ]] \
        || {
            cat "$runtime_log" >&2
            fail "$executable graceful SIGTERM exit status"
        }
    pass "$executable graceful SIGTERM exit status"

    wait_for_log 'STOPPING=1' "$notify_log" \
        || {
            cat "$notify_log" >&2
            fail "$executable emitted stopping notification"
        }
    pass "$executable emitted stopping notification"

    wait "$receiver_pid" >/dev/null 2>&1 || true

    if grep -Fq 'Step4Validation2026' "$runtime_log" ||
        grep -Fq 'postgresql://' "$runtime_log" ||
        grep -Fq 'Step4Validation2026' "$notify_log" ||
        grep -Fq 'postgresql://' "$notify_log"
    then
        fail "$executable host output contains no database secret"
    fi
    pass "$executable host output contains no database secret"
done

foundation_dsn="$scratch/issp_service_authorization.url"

malformed_log="$scratch/malformed-notify.log"
set +e
ISSP_ADMIN_LISTEN_ADDRESS="127.0.0.1:$(pick_port)" \
ISSP_DATABASE_DSN_FILE="$foundation_dsn" \
ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true \
NOTIFY_SOCKET=relative-notify.sock \
    "$build_dir/bin/foundation-api" 2>"$malformed_log"
malformed_rc=$?
set -e
[[ "$malformed_rc" -eq 71 ]] \
    || {
        cat "$malformed_log" >&2
        fail "Malformed notification socket exits 71"
    }
pass "Malformed notification socket exits 71"

watchdog_log="$scratch/malformed-watchdog.log"
set +e
ISSP_ADMIN_LISTEN_ADDRESS="127.0.0.1:$(pick_port)" \
ISSP_DATABASE_DSN_FILE="$foundation_dsn" \
ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true \
NOTIFY_SOCKET="$scratch/not-created.notify" \
WATCHDOG_USEC=invalid \
    "$build_dir/bin/foundation-api" 2>"$watchdog_log"
watchdog_rc=$?
set -e
[[ "$watchdog_rc" -eq 78 ]] \
    || {
        cat "$watchdog_log" >&2
        fail "Malformed watchdog interval exits 78"
    }
pass "Malformed watchdog interval exits 78"

occupied_port="$(pick_port)"
python3 -c \
    'import socket,sys,time; s=socket.socket(); s.bind(("127.0.0.1",int(sys.argv[1]))); s.listen(); time.sleep(30)' \
    "$occupied_port" &
holder_pid=$!
helper_pids+=("$holder_pid")
sleep 0.1

occupied_log="$scratch/occupied-port.log"
set +e
ISSP_ADMIN_LISTEN_ADDRESS="127.0.0.1:$occupied_port" \
ISSP_DATABASE_DSN_FILE="$foundation_dsn" \
ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true \
    "$build_dir/bin/foundation-api" 2>"$occupied_log"
occupied_rc=$?
set -e
kill -TERM "$holder_pid" >/dev/null 2>&1 || true
wait "$holder_pid" >/dev/null 2>&1 || true
[[ "$occupied_rc" -eq 71 ]] \
    || {
        cat "$occupied_log" >&2
        fail "Occupied administrative port exits 71"
    }
pass "Occupied administrative port exits 71"

failure_socket="$scratch/watchdog-failure.notify"
failure_notify_log="$scratch/watchdog-failure.notify.log"
failure_runtime_log="$scratch/watchdog-failure.runtime.log"
start_receiver "$failure_socket" "$failure_notify_log" \
    || fail "Watchdog-failure notification receiver started"
failure_receiver_pid="$receiver_pid_result"

failure_admin_port="$(pick_port)"
ISSP_ADMIN_LISTEN_ADDRESS="127.0.0.1:$failure_admin_port" \
ISSP_DATABASE_DSN_FILE="$foundation_dsn" \
ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true \
NOTIFY_SOCKET="$failure_socket" \
WATCHDOG_USEC=2000000 \
    bash -c 'export WATCHDOG_PID=$$; exec "$1"' \
    _ "$build_dir/bin/foundation-api" \
    2>"$failure_runtime_log" &
failure_pid=$!
current_process_id="$failure_pid"

wait_for_log 'READY=1' "$failure_notify_log" \
    || fail "Watchdog-failure process became ready"
wait_for_log 'WATCHDOG=1' "$failure_notify_log" \
    || fail "Watchdog-failure process sent initial watchdog"

kill -TERM "$failure_receiver_pid" >/dev/null 2>&1 || true
wait "$failure_receiver_pid" >/dev/null 2>&1 || true
rm -f -- "$failure_socket"

wait_for_exit "$failure_pid" 150 \
    || {
        cat "$failure_runtime_log" >&2
        fail "Disappeared notification socket terminates process"
    }

set +e
wait "$failure_pid"
failure_rc=$?
set -e
current_process_id=""
[[ "$failure_rc" -eq 70 ]] \
    || {
        cat "$failure_runtime_log" >&2
        fail "Disappeared notification socket exits 70"
    }
pass "Disappeared notification socket exits 70"

# A database startup failure must never emit READY.
unavailable_socket="$scratch/database-unavailable.notify"
unavailable_notify_log="$scratch/database-unavailable.notify.log"
unavailable_runtime_log="$scratch/database-unavailable.runtime.log"
start_receiver "$unavailable_socket" "$unavailable_notify_log" \
    || fail "Database-unavailable notification receiver started"
unavailable_receiver_pid="$receiver_pid_result"

unavailable_port="$(pick_port)"
unavailable_dsn="$scratch/database-unavailable.url"
printf 'postgresql://%s:%s@127.0.0.1:%s/issp_phase6_step4?sslmode=disable\n' \
    'issp_service_authorization' \
    'Step4Validation2026' \
    "$unavailable_port" >"$unavailable_dsn"
chmod 0600 "$unavailable_dsn"

set +e
ISSP_ADMIN_LISTEN_ADDRESS="127.0.0.1:$(pick_port)" \
ISSP_DATABASE_DSN_FILE="$unavailable_dsn" \
ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true \
NOTIFY_SOCKET="$unavailable_socket" \
    "$build_dir/bin/foundation-api" \
    2>"$unavailable_runtime_log"
unavailable_rc=$?
set -e

[[ "$unavailable_rc" -eq 69 ]] \
    || {
        cat "$unavailable_runtime_log" >&2
        fail "Database-unavailable startup exits 69"
    }
pass "Database-unavailable startup exits 69"

wait "$unavailable_receiver_pid" >/dev/null 2>&1 || true
if grep -Fq 'READY=1' "$unavailable_notify_log"; then
    fail "Database-unavailable startup emits no readiness notification"
fi
grep -Fq 'STOPPING=1' "$unavailable_notify_log" \
    || fail "Database-unavailable startup emits stopping notification"
pass "Database-unavailable startup emits no readiness notification"

# Cancellation while PostgreSQL startup is blocked must stop cleanly, remain
# unready, and emit STOPPING without waiting for the startup timeout.
blackhole_port="$(pick_port)"
blackhole_listening="$scratch/blackhole.listening"
blackhole_accepted="$scratch/blackhole.accepted"

python3 -c '
import pathlib
import socket
import sys
import time

port = int(sys.argv[1])
listening = pathlib.Path(sys.argv[2])
accepted = pathlib.Path(sys.argv[3])

server = socket.socket()
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("127.0.0.1", port))
server.listen(1)
listening.write_text("ready", encoding="utf-8")
connection, _ = server.accept()
accepted.write_text("accepted", encoding="utf-8")
try:
    time.sleep(30)
finally:
    connection.close()
    server.close()
' "$blackhole_port" "$blackhole_listening" "$blackhole_accepted" &
blackhole_pid=$!
helper_pids+=("$blackhole_pid")

for _ in $(seq 1 100); do
    [[ -f "$blackhole_listening" ]] && break
    sleep 0.02
done
[[ -f "$blackhole_listening" ]] \
    || fail "Blocked database-startup listener became available"

blocked_dsn="$scratch/blocked-startup.url"
printf 'postgresql://%s:%s@127.0.0.1:%s/issp_phase6_step4?sslmode=disable\n' \
    'issp_service_authorization' \
    'Step4Validation2026' \
    "$blackhole_port" >"$blocked_dsn"
chmod 0600 "$blocked_dsn"

blocked_socket="$scratch/blocked-startup.notify"
blocked_notify_log="$scratch/blocked-startup.notify.log"
blocked_runtime_log="$scratch/blocked-startup.runtime.log"
start_receiver "$blocked_socket" "$blocked_notify_log" \
    || fail "Blocked-startup notification receiver started"
blocked_receiver_pid="$receiver_pid_result"
blocked_admin_port="$(pick_port)"

ISSP_ADMIN_LISTEN_ADDRESS="127.0.0.1:$blocked_admin_port" \
ISSP_DATABASE_DSN_FILE="$blocked_dsn" \
ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true \
ISSP_DATABASE_CONNECT_TIMEOUT=20s \
ISSP_STARTUP_TIMEOUT=20s \
NOTIFY_SOCKET="$blocked_socket" \
    "$build_dir/bin/foundation-api" \
    2>"$blocked_runtime_log" &
blocked_pid=$!
current_process_id="$blocked_pid"

for _ in $(seq 1 150); do
    [[ -f "$blackhole_accepted" ]] && break
    sleep 0.04
done
[[ -f "$blackhole_accepted" ]] \
    || {
        cat "$blocked_runtime_log" >&2
        fail "Database startup reached blocked connection"
    }

if ! python3 -c '
import sys
import urllib.error
import urllib.request

try:
    urllib.request.urlopen(sys.argv[1], timeout=0.5)
except urllib.error.HTTPError as error:
    raise SystemExit(0 if error.code == 503 else 1)
except Exception:
    raise SystemExit(1)
raise SystemExit(1)
' "http://127.0.0.1:$blocked_admin_port/readyz"
then
    cat "$blocked_runtime_log" >&2
    fail "Blocked database startup remains administratively unready"
fi
pass "Blocked database startup remains administratively unready"

kill -TERM "$blocked_pid"
set +e
wait "$blocked_pid"
blocked_rc=$?
set -e
current_process_id=""

[[ "$blocked_rc" -eq 0 ]] \
    || {
        cat "$blocked_runtime_log" >&2
        fail "SIGTERM during database startup exits cleanly"
    }

wait "$blocked_receiver_pid" >/dev/null 2>&1 || true
if grep -Fq 'READY=1' "$blocked_notify_log"; then
    fail "SIGTERM during database startup emits no readiness notification"
fi
grep -Fq 'STOPPING=1' "$blocked_notify_log" \
    || fail "SIGTERM during database startup emits stopping notification"
pass "SIGTERM during database startup exits cleanly without readiness"

kill -TERM "$blackhole_pid" >/dev/null 2>&1 || true
wait "$blackhole_pid" >/dev/null 2>&1 || true

# SIGINT and a repeated termination signal during shutdown must remain bounded.
signal_socket="$scratch/repeated-signal.notify"
signal_notify_log="$scratch/repeated-signal.notify.log"
signal_runtime_log="$scratch/repeated-signal.runtime.log"
start_receiver "$signal_socket" "$signal_notify_log" \
    || fail "Repeated-signal notification receiver started"
signal_receiver_pid="$receiver_pid_result"
signal_admin_port="$(pick_port)"

ISSP_ADMIN_LISTEN_ADDRESS="127.0.0.1:$signal_admin_port" \
ISSP_DATABASE_DSN_FILE="$foundation_dsn" \
ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true \
NOTIFY_SOCKET="$signal_socket" \
    "$build_dir/bin/foundation-api" \
    2>"$signal_runtime_log" &
signal_pid=$!
current_process_id="$signal_pid"

wait_for_log 'READY=1' "$signal_notify_log" \
    || {
        cat "$signal_runtime_log" >&2
        fail "Repeated-signal process became ready"
    }

kill -INT "$signal_pid"
kill -TERM "$signal_pid" >/dev/null 2>&1 || true

set +e
wait "$signal_pid"
signal_rc=$?
set -e
current_process_id=""

[[ "$signal_rc" -eq 0 ]] \
    || {
        cat "$signal_runtime_log" >&2
        fail "SIGINT plus repeated termination exits cleanly"
    }

wait "$signal_receiver_pid" >/dev/null 2>&1 || true
grep -Fq 'STOPPING=1' "$signal_notify_log" \
    || fail "SIGINT plus repeated termination emits stopping notification"
pass "SIGINT plus repeated termination exits cleanly"

if grep -R -Fq 'Step4Validation2026' "$scratch"/*.log 2>/dev/null ||
    grep -R -Fq 'postgresql://' "$scratch"/*.log 2>/dev/null
then
    fail "Hostile runtime logs contain no database secret"
fi
pass "Hostile runtime logs contain no database secret"

printf '\nPhase 6 Step 4 hostile runtime integration: %d PASS, 0 FAIL\n' \
    "$pass_count"
