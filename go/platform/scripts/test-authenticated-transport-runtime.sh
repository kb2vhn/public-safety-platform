#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
repo_root="$(cd -- "$module_root/../.." && pwd -P)"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")"

pass_count=0
pass() { pass_count=$((pass_count + 1)); printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

required_commands=(go pg_config python3 grep chmod mktemp kill sleep cat)
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "Required runtime-test command available: $command_name"
    pass "Required runtime-test command available: $command_name"
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
postgres_version="$($postgres_bindir/postgres --version 2>/dev/null || true)"
[[ "$postgres_version" == *" 18."* ]] \
    || fail "Disposable transport runtime uses PostgreSQL 18"
pass "Disposable transport runtime uses PostgreSQL 18"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step6-runtime.XXXXXX")"
pgdata="$scratch/pgdata"
socket_dir="$scratch/socket"
postgres_log="$scratch/postgresql.log"
runtime_log="$scratch/foundation-api.log"
database_name="issp_phase6_step6"
mkdir -p "$socket_dir"

pick_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'
}

postgres_port="$(pick_port)"
admin_port="$(pick_port)"
while [[ "$admin_port" == "$postgres_port" ]]; do
    admin_port="$(pick_port)"
done
business_port="$(pick_port)"
while [[ "$business_port" == "$postgres_port" || "$business_port" == "$admin_port" ]]; do
    business_port="$(pick_port)"
done
postgres_started=false
service_pid=""
cleanup() {
    if [[ -n "$service_pid" ]]; then
        kill -TERM "$service_pid" >/dev/null 2>&1 || true
        wait "$service_pid" >/dev/null 2>&1 || true
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
    -l "$postgres_log" \
    -o "-F -p $postgres_port -h 127.0.0.1 -k $socket_dir" \
    -w start >/dev/null
postgres_started=true
pass "Disposable PostgreSQL cluster started"

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
pass "Disposable Step 6 database created"

(
    cd "$repo_root"
    bash sql/schema/scripts/apply_foundation.sh "$database_name"
) >"$scratch/foundation-apply.log" 2>&1
pass "Accepted Foundation migrations applied"
(
    cd "$repo_root"
    bash sql/deployment/scripts/apply_deployment.sh "$database_name"
) >"$scratch/deployment-apply.log" 2>&1
pass "Accepted Phase 5 deployment boundary applied"

"${psql_super[@]}" -d "$database_name" <<'SQL' >/dev/null
SET password_encryption = 'scram-sha-256';
ALTER ROLE issp_service_authorization PASSWORD 'Step6Validation2026';
SQL
pass "Disposable Foundation API credential provisioned"

mapfile -t fixture_lines < <(
    "${psql_super[@]}" -qAt -d "$database_name" \
        -f "$module_root/testdata/phase6-step5/authorization-policy-binding-fixtures.sql"
)
selected_decision_id=""
for fixture_line in "${fixture_lines[@]}"; do
    [[ "$fixture_line" == selected'|'* ]] || continue
    selected_decision_id="${fixture_line#*|}"
done
[[ -n "$selected_decision_id" ]] || fail "Selected transport fixture created"
pass "Selected transport fixture created"

dsn_file="$scratch/database-url"
printf 'postgresql://%s:%s@127.0.0.1:%s/%s?sslmode=disable\n' \
    'issp_service_authorization' 'Step6Validation2026' \
    "$postgres_port" "$database_name" >"$dsn_file"
chmod 0600 "$dsn_file"

key_file="$scratch/transport-hmac-key"
python3 - "$key_file" <<'PY'
import base64
import pathlib
import sys
key = b"0123456789abcdef0123456789abcdef"
pathlib.Path(sys.argv[1]).write_text(
    base64.urlsafe_b64encode(key).rstrip(b"=").decode("ascii") + "\n",
    encoding="ascii",
)
PY
chmod 0600 "$key_file"

cd "$module_root"
export GOTOOLCHAIN=local
export GOFLAGS='-mod=readonly'
go build -trimpath -o "$scratch/foundation-api" ./cmd/foundation-api
pass "Foundation API binary built"

ISSP_ADMIN_LISTEN_ADDRESS="127.0.0.1:$admin_port" \
ISSP_BUSINESS_LISTEN_ADDRESS="127.0.0.1:$business_port" \
ISSP_TRANSPORT_HMAC_KEY_FILE="$key_file" \
ISSP_TRANSPORT_MAX_CONCURRENT_REQUESTS=2 \
ISSP_DATABASE_DSN_FILE="$dsn_file" \
ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true \
    "$scratch/foundation-api" 2>"$runtime_log" &
service_pid=$!

python3 - "http://127.0.0.1:$admin_port/readyz" <<'PY'
import sys
import time
import urllib.request
url = sys.argv[1]
for _ in range(200):
    try:
        with urllib.request.urlopen(url, timeout=0.2) as response:
            if response.status == 200:
                raise SystemExit(0)
    except Exception:
        pass
    time.sleep(0.05)
raise SystemExit(1)
PY
pass "Foundation API reaches readiness with business listener active"

python3 - "$business_port" "$selected_decision_id" <<'PY'
import base64
import hashlib
import hmac
import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

port = int(sys.argv[1])
decision_id = sys.argv[2]
url = f"http://127.0.0.1:{port}/v1/foundation/authorization-policy-bindings"
key = b"0123456789abcdef0123456789abcdef"


def signed_request(body, request_id, nonce_seed, when=None, signature_key=key, extra=None):
    if when is None:
        when = datetime.now(timezone.utc)
    when = when.astimezone(timezone.utc)
    fraction = f"{when.microsecond:06d}".rstrip("0")
    authenticated_at = when.strftime("%Y-%m-%dT%H:%M:%S")
    if fraction:
        authenticated_at += "." + fraction
    authenticated_at += "Z"
    nonce = base64.urlsafe_b64encode(hashlib.sha256(nonce_seed.encode()).digest()[:16]).rstrip(b"=").decode()
    correlation_id = "22222222-2222-2222-2222-222222222222"
    subject = "identity:runtime-user"
    provider = "gateway:runtime"
    assertion = "assertion:runtime-1"
    digest = hashlib.sha256(body).hexdigest()
    canonical = "\n".join([
        "ISSP-HANDOFF-V1", "POST", "/v1/foundation/authorization-policy-bindings",
        request_id, correlation_id, subject, provider, assertion,
        authenticated_at, nonce, digest,
    ]).encode()
    signature = "v1=" + hmac.new(signature_key, canonical, hashlib.sha256).hexdigest()
    headers = {
        "Content-Type": "application/json",
        "X-Iron-Signal-Request-ID": request_id,
        "X-Iron-Signal-Correlation-ID": correlation_id,
        "X-Iron-Signal-Subject": subject,
        "X-Iron-Signal-Provider": provider,
        "X-Iron-Signal-Assertion-ID": assertion,
        "X-Iron-Signal-Authenticated-At": authenticated_at,
        "X-Iron-Signal-Nonce": nonce,
        "X-Iron-Signal-Signature": signature,
    }
    if extra:
        headers.update(extra)
    return urllib.request.Request(url, data=body, headers=headers, method="POST")


def perform(request):
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()

body = json.dumps({"decision_id": decision_id}, separators=(",", ":")).encode()
request_id = "11111111-1111-1111-1111-111111111111"
request = signed_request(body, request_id, "success")
status, response_body = perform(request)
assert status == 200, (status, response_body)
payload = json.loads(response_body)
assert payload["request_id"] == request_id
assert payload["result"]["decision_id"] == decision_id
assert payload["result"]["reason_code"] == "AUTHORIZATION_POLICY_SELECTED"

status, response_body = perform(request)
assert status == 401 and "AUTHENTICATION_REQUIRED" in response_body

bad_signature = signed_request(body, "33333333-3333-3333-3333-333333333333", "bad-signature", signature_key=b"x" * 32)
status, response_body = perform(bad_signature)
assert status == 401 and "AUTHENTICATION_REQUIRED" in response_body

stale = signed_request(body, "44444444-4444-4444-4444-444444444444", "stale", datetime.now(timezone.utc) - timedelta(minutes=2))
status, response_body = perform(stale)
assert status == 401 and "AUTHENTICATION_REQUIRED" in response_body

unknown_body = json.dumps({"decision_id": decision_id, "extra": True}, separators=(",", ":")).encode()
unknown = signed_request(unknown_body, "55555555-5555-5555-5555-555555555555", "unknown")
status, response_body = perform(unknown)
assert status == 400 and "INVALID_REQUEST" in response_body

proxy = signed_request(body, "66666666-6666-6666-6666-666666666666", "proxy", extra={"X-Forwarded-For": "198.51.100.1"})
status, response_body = perform(proxy)
assert status == 400 and "INVALID_REQUEST" in response_body

wrong_method = urllib.request.Request(url, method="GET")
status, response_body = perform(wrong_method)
assert status == 405 and "METHOD_NOT_ALLOWED" in response_body

wrong_media = urllib.request.Request(url, data=b"{}", headers={"Content-Type": "text/plain"}, method="POST")
status, response_body = perform(wrong_media)
assert status == 415 and "UNSUPPORTED_MEDIA_TYPE" in response_body

large = urllib.request.Request(url, data=b"x" * 1025, headers={"Content-Type": "application/json"}, method="POST")
status, response_body = perform(large)
assert status == 413 and "REQUEST_TOO_LARGE" in response_body
PY
pass "Authenticated transport positive, replay, spoofing, freshness, and request-limit campaign passes"

state="$("${psql_super[@]}" -qAt -d "$database_name" -c "SELECT record_status || '|' || (authorization_policy_version_id IS NOT NULL)::integer FROM decision.decision_records WHERE decision_id = '$selected_decision_id'::uuid")"
[[ "$state" == 'DRAFT|1' ]] || fail "Transport operation persisted expected policy binding"
pass "Transport operation persisted expected policy binding"

kill -TERM "$service_pid"
set +e
wait "$service_pid"
service_rc=$?
set -e
service_pid=""
[[ "$service_rc" -eq 0 ]] || { cat "$runtime_log" >&2; fail "Foundation API exits cleanly after authenticated transport campaign"; }
pass "Foundation API exits cleanly after authenticated transport campaign"

if grep -Fq 'Step6Validation2026' "$runtime_log" || \
   grep -Fq 'postgresql://' "$runtime_log" || \
   grep -Fq '0123456789abcdef' "$runtime_log" || \
   grep -Fq 'identity:runtime-user' "$runtime_log" || \
   grep -Fq 'assertion:runtime-1' "$runtime_log"
then
    fail "Authenticated transport logs contain no credentials or authentication identity"
fi
pass "Authenticated transport logs contain no credentials or authentication identity"

printf '\nPhase 6 Step 6 authenticated transport runtime: %d PASS, 0 FAIL\n' "$pass_count"
