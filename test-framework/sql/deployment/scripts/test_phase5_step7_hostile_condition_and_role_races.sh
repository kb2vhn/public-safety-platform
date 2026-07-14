#!/usr/bin/env bash

set -u

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    printf 'PASS: %s\n' "$1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_equal() {
    local actual="$1"
    local expected="$2"
    local description="$3"

    if [[ "$actual" == "$expected" ]]; then
        pass "$description = $expected"
    else
        fail "$description expected=$expected actual=${actual:-missing}"
    fi
}

check_one_of() {
    local actual="$1"
    local expected_one="$2"
    local expected_two="$3"
    local description="$4"

    if [[ "$actual" == "$expected_one" || "$actual" == "$expected_two" ]]; then
        pass "$description = $actual"
    else
        fail "$description expected=$expected_one-or-$expected_two actual=${actual:-missing}"
    fi
}

require_command() {
    if command -v "$1" >/dev/null 2>&1; then
        pass "Command available: $1"
    else
        fail "Command available: $1"
    fi
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
    echo "FAIL: Repository is a Git work tree" >&2
    exit 1
fi
cd "$repo_root"

for command_name in initdb pg_ctl createdb psql python3; do
    require_command "$command_name"
done

if (( FAIL_COUNT != 0 )); then
    printf '\nDependency preflight failed.\n' >&2
    exit 1
fi

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase5-step7.XXXXXX")"
data_dir="$temp_root/data"
socket_dir="$temp_root/socket"
log_file="$temp_root/postgresql.log"
deployment_log="$temp_root/deployment.log"
step7_deployment_root="$temp_root/step7-deployment"
port=55437
database_name="issp_phase5_step7_test"
cluster_started=false
mkdir -p "$socket_dir"

cleanup() {
    local cleanup_status=$?
    if [[ "$cluster_started" == true ]]; then
        pg_ctl -D "$data_dir" -m immediate -w stop >/dev/null 2>&1 || true
    fi
    rm -rf "$temp_root"
    exit "$cleanup_status"
}
trap cleanup EXIT INT TERM

if initdb \
    -D "$data_dir" \
    --auth=trust \
    --username=postgres \
    --no-locale \
    --encoding=UTF8 \
    >/dev/null 2>&1; then
    pass "Disposable PostgreSQL cluster initialized"
else
    fail "Disposable PostgreSQL cluster initialized"
fi

cat >>"$data_dir/postgresql.conf" <<CONF
listen_addresses = ''
unix_socket_directories = '$socket_dir'
port = $port
max_connections = 40
password_encryption = 'scram-sha-256'
log_min_messages = warning
CONF

cat >"$data_dir/pg_hba.conf" <<'HBA'
local all issp_break_glass scram-sha-256
local all all trust
HBA

if pg_ctl -D "$data_dir" -l "$log_file" -w start >/dev/null 2>&1; then
    cluster_started=true
    pass "Disposable PostgreSQL cluster started"
else
    fail "Disposable PostgreSQL cluster started"
    cat "$log_file" >&2 2>/dev/null || true
fi

if createdb \
    --host="$socket_dir" \
    --port="$port" \
    --username=postgres \
    --template=template0 \
    "$database_name"; then
    pass "Disposable database created from template0"
else
    fail "Disposable database created from template0"
fi

psql_base=(
    psql
    --no-psqlrc
    --set=ON_ERROR_STOP=1
    --host="$socket_dir"
    --port="$port"
    --username=postgres
    --dbname="$database_name"
)

sql_scalar() {
    "${psql_base[@]}" \
        --tuples-only \
        --no-align \
        --command "$1" \
        2>/dev/null \
        | tr -d '[:space:]'
}

sql_succeeds() {
    "${psql_base[@]}" --command "$1" >/dev/null 2>&1
}

expect_sql_failure() {
    local description="$1"
    local sql="$2"

    if sql_succeeds "$sql"; then
        fail "$description"
    else
        pass "$description"
    fi
}

foundation_ok=true
while IFS= read -r migration_path; do
    [[ "$migration_path" =~ ^[[:space:]]*(#|$) ]] && continue
    if ! "${psql_base[@]}" \
        --file="$repo_root/sql/schema/$migration_path" \
        >/dev/null; then
        foundation_ok=false
        break
    fi
done <"$repo_root/sql/schema/manifests/foundation.manifest"

if [[ "$foundation_ok" == true ]]; then
    pass "Applied all Foundation migrations"
else
    fail "Applied all Foundation migrations"
fi

mkdir -p "$step7_deployment_root"
cp -R "$repo_root/sql/deployment/." "$step7_deployment_root/"
cat >"$step7_deployment_root/manifests/deployment.manifest" <<'MANIFEST'
migrations/900_postgresql_role_topology_and_membership.sql
migrations/910_database_schema_and_object_ownership.sql
migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql
migrations/930_investigator_audit_and_validation_review_surfaces.sql
migrations/940_break_glass_and_credential_lifecycle.sql
MANIFEST
chmod +x "$step7_deployment_root/scripts/apply_deployment.sh"

if PGHOST="$socket_dir" \
   PGPORT="$port" \
   PGUSER=postgres \
   "$step7_deployment_root/scripts/apply_deployment.sh" \
   "$database_name" \
   >"$deployment_log" 2>&1; then
    pass "Applied accepted deployment prefix through Step 6"
else
    fail "Applied accepted deployment prefix through Step 6"
    cat "$deployment_log" >&2 2>/dev/null || true
fi

if PGHOST="$socket_dir" \
   PGPORT="$port" \
   PGUSER=postgres \
   "$step7_deployment_root/scripts/apply_deployment.sh" \
   "$database_name" \
   >>"$deployment_log" 2>&1; then
    pass "Accepted deployment prefix reapplication is idempotent"
else
    fail "Accepted deployment prefix reapplication is idempotent"
    cat "$deployment_log" >&2 2>/dev/null || true
fi

credential_file="$temp_root/credentials.tsv"
python3 >"$credential_file" <<'PY'
import base64
import hashlib
import hmac
import secrets


def make_scram():
    password = secrets.token_hex(24)
    salt = secrets.token_bytes(16)
    iterations = 4096
    salted = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        iterations,
    )
    client_key = hmac.new(salted, b"Client Key", hashlib.sha256).digest()
    stored_key = hashlib.sha256(client_key).digest()
    server_key = hmac.new(salted, b"Server Key", hashlib.sha256).digest()
    verifier = (
        f"SCRAM-SHA-256${iterations}:"
        f"{base64.b64encode(salt).decode()}$"
        f"{base64.b64encode(stored_key).decode()}:"
        f"{base64.b64encode(server_key).decode()}"
    )
    fingerprint = hashlib.sha256(verifier.encode("utf-8")).hexdigest()
    return password, verifier, fingerprint


for _ in range(6):
    print("\t".join(make_scram()))
PY

mapfile -t generated_credentials <"$credential_file"
if [[ "${#generated_credentials[@]}" == "6" ]]; then
    pass "Generated six ephemeral test-only SCRAM credentials"
else
    fail "Generated six ephemeral test-only SCRAM credentials"
fi

IFS=$'\t' read -r password_one verifier_one fingerprint_one <<<"${generated_credentials[0]:-}"
IFS=$'\t' read -r password_two verifier_two fingerprint_two <<<"${generated_credentials[1]:-}"
IFS=$'\t' read -r password_three verifier_three fingerprint_three <<<"${generated_credentials[2]:-}"
IFS=$'\t' read -r password_four verifier_four fingerprint_four <<<"${generated_credentials[3]:-}"
IFS=$'\t' read -r password_five verifier_five fingerprint_five <<<"${generated_credentials[4]:-}"
IFS=$'\t' read -r password_six verifier_six fingerprint_six <<<"${generated_credentials[5]:-}"

run_race_pair() {
    local race_name="$1"
    local sql_one="$2"
    local sql_two="$3"
    local race_dir="$temp_root/$race_name"

    rm -rf "$race_dir"
    mkdir -p "$race_dir"

    (
        touch "$race_dir/ready-one"
        while [[ ! -e "$race_dir/go" ]]; do sleep 0.01; done
        if "${psql_base[@]}" --tuples-only --no-align --command "$sql_one" \
            >"$race_dir/out-one" 2>"$race_dir/err-one"; then
            printf '0\n' >"$race_dir/status-one"
        else
            printf '%s\n' "$?" >"$race_dir/status-one"
        fi
    ) &
    local pid_one=$!

    (
        touch "$race_dir/ready-two"
        while [[ ! -e "$race_dir/go" ]]; do sleep 0.01; done
        if "${psql_base[@]}" --tuples-only --no-align --command "$sql_two" \
            >"$race_dir/out-two" 2>"$race_dir/err-two"; then
            printf '0\n' >"$race_dir/status-two"
        else
            printf '%s\n' "$?" >"$race_dir/status-two"
        fi
    ) &
    local pid_two=$!

    while [[ ! -e "$race_dir/ready-one" || ! -e "$race_dir/ready-two" ]]; do
        sleep 0.01
    done
    touch "$race_dir/go"

    wait "$pid_one" 2>/dev/null || true
    wait "$pid_two" 2>/dev/null || true

    RACE_DIR="$race_dir"
    RACE_STATUS_ONE="$(cat "$race_dir/status-one" 2>/dev/null || printf 'missing')"
    RACE_STATUS_TWO="$(cat "$race_dir/status-two" 2>/dev/null || printf 'missing')"
}

echo
echo "== Baseline disabled-at-rest and hostile-input checks =="

check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.applied_deployment_migrations WHERE migration_id LIKE '9%';")" "5" "Registered deployment migrations"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_roles WHERE rolname='issp_break_glass' AND NOT rolcanlogin AND NOT rolsuper AND NOT rolcreaterole AND NOT rolcreatedb AND NOT rolreplication AND NOT rolbypassrls;")" "1" "Break-glass role begins disabled and unprivileged"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member WHERE r.rolname='issp_break_glass';")" "0" "Break-glass begins without memberships"
check_equal "$(sql_scalar "SELECT has_database_privilege('issp_break_glass', current_database(), 'CONNECT')::int;")" "0" "Break-glass begins without database CONNECT"

expect_sql_failure \
    "Runtime service cannot prepare break-glass" \
    "SET ROLE issp_service_authorization; SELECT emergency_control.prepare_break_glass_activation('INC-HOSTILE-1','denied','runtime','approver-a','approver-b','vault://denied','$fingerprint_one',interval '15 minutes');"
expect_sql_failure \
    "Repeated requester and approver identities are rejected" \
    "SELECT emergency_control.prepare_break_glass_activation('INC-HOSTILE-2','duplicate actors','actor-a','actor-a','actor-b','vault://duplicate','$fingerprint_one',interval '15 minutes');"
expect_sql_failure \
    "Duration shorter than five minutes is rejected" \
    "SELECT emergency_control.prepare_break_glass_activation('INC-HOSTILE-3','short duration','requester-a','approver-a','approver-b','vault://short','$fingerprint_one',interval '4 minutes');"
expect_sql_failure \
    "Duration longer than one hour is rejected" \
    "SELECT emergency_control.prepare_break_glass_activation('INC-HOSTILE-4','long duration','requester-a','approver-a','approver-b','vault://long','$fingerprint_one',interval '61 minutes');"
expect_sql_failure \
    "Malformed credential fingerprint is rejected" \
    "SELECT emergency_control.prepare_break_glass_activation('INC-HOSTILE-5','bad fingerprint','requester-a','approver-a','approver-b','vault://bad','not-a-sha256',interval '15 minutes');"
expect_sql_failure \
    "Migration executor cannot alter the break-glass role" \
    "SET ROLE issp_migration_executor; ALTER ROLE issp_break_glass LOGIN;"
expect_sql_failure \
    "Migration executor cannot grant emergency membership" \
    "SET ROLE issp_migration_executor; GRANT issp_database_owner TO issp_break_glass;"
expect_sql_failure \
    "Runtime role cannot write emergency request evidence" \
    "SET ROLE issp_runtime; INSERT INTO deployment_meta.break_glass_requests(incident_reference,reason,requested_by,approver_one,approver_two,activate_before,expires_at,requested_duration,external_credential_reference,credential_fingerprint) VALUES ('INC-DIRECT','direct','a','b','c',clock_timestamp()+interval '1 minute',clock_timestamp()+interval '10 minutes',interval '10 minutes','vault://direct','$fingerprint_one');"
if sql_succeeds "CREATE ROLE issp_step7_public_probe NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;"; then
    pass "Created an unprivileged PUBLIC-only probe role"
else
    fail "Created an unprivileged PUBLIC-only probe role"
fi
expect_sql_failure \
    "PUBLIC-only role cannot execute emergency preparation" \
    "SET ROLE issp_step7_public_probe; SELECT emergency_control.prepare_break_glass_activation('INC-PUBLIC','denied','a','b','c','vault://public','$fingerprint_one',interval '15 minutes');"

echo
echo "== Concurrent preparation race =="

prepare_sql_one="SELECT emergency_control.prepare_break_glass_activation('INC-RACE-PREP-A','concurrent preparation','requester-a','approver-a1','approver-a2','vault://step7/one','$fingerprint_one',interval '20 minutes');"
prepare_sql_two="SELECT emergency_control.prepare_break_glass_activation('INC-RACE-PREP-B','concurrent preparation','requester-b','approver-b1','approver-b2','vault://step7/two','$fingerprint_two',interval '20 minutes');"
run_race_pair "prepare-race" "$prepare_sql_one" "$prepare_sql_two"

prepare_successes=0
[[ "$RACE_STATUS_ONE" == "0" ]] && prepare_successes=$((prepare_successes + 1))
[[ "$RACE_STATUS_TWO" == "0" ]] && prepare_successes=$((prepare_successes + 1))
check_equal "$prepare_successes" "1" "Exactly one concurrent preparation succeeds"

if [[ "$RACE_STATUS_ONE" == "0" ]]; then
    request_one="$(tr -d '[:space:]' <"$RACE_DIR/out-one")"
    winning_fingerprint="$fingerprint_one"
    winning_password="$password_one"
    winning_verifier="$verifier_one"
else
    request_one="$(tr -d '[:space:]' <"$RACE_DIR/out-two")"
    winning_fingerprint="$fingerprint_two"
    winning_password="$password_two"
    winning_verifier="$verifier_two"
fi

check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.break_glass_requests;")" "1" "Preparation race creates one request"
check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.break_glass_events WHERE event_type='REQUESTED';")" "1" "Preparation race creates one REQUESTED event"
check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.break_glass_evidence_outbox WHERE evidence_type='REQUESTED';")" "1" "Preparation race creates one REQUESTED evidence record"
check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.credential_lifecycle_events WHERE event_type='STAGED';")" "1" "Preparation race creates one STAGED credential event"

if [[ "$winning_fingerprint" == "$fingerprint_one" ]]; then
    mismatched_verifier="$verifier_two"
else
    mismatched_verifier="$verifier_one"
fi
low_iteration_prefix='SCRAM-SHA-256$4096:'
low_iteration_replacement='SCRAM-SHA-256$1:'
low_iteration_verifier="${winning_verifier/#$low_iteration_prefix/$low_iteration_replacement}"

expect_sql_failure \
    "Activation operator cannot reuse a request actor identity" \
    "SELECT emergency_control.activate_break_glass($request_one,(SELECT requested_by FROM deployment_meta.break_glass_requests WHERE break_glass_request_id=$request_one),'$winning_verifier');"
expect_sql_failure \
    "Activation rejects non-SCRAM material under contention" \
    "SELECT emergency_control.activate_break_glass($request_one,'independent-operator','plaintext-password');"
expect_sql_failure \
    "Activation rejects a verifier below the minimum SCRAM iteration count" \
    "SELECT emergency_control.activate_break_glass($request_one,'independent-operator','$low_iteration_verifier');"
expect_sql_failure \
    "Activation rejects a verifier that does not match the approved fingerprint" \
    "SELECT emergency_control.activate_break_glass($request_one,'independent-operator','$mismatched_verifier');"


echo
echo "== Concurrent activation race =="

activate_sql_one="SELECT emergency_control.activate_break_glass($request_one,'activation-operator-one','$winning_verifier');"
activate_sql_two="SELECT emergency_control.activate_break_glass($request_one,'activation-operator-two','$winning_verifier');"
run_race_pair "activation-race" "$activate_sql_one" "$activate_sql_two"

activation_successes=0
[[ "$RACE_STATUS_ONE" == "0" ]] && activation_successes=$((activation_successes + 1))
[[ "$RACE_STATUS_TWO" == "0" ]] && activation_successes=$((activation_successes + 1))
check_equal "$activation_successes" "1" "Exactly one concurrent activation succeeds"
check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.break_glass_events WHERE break_glass_request_id=$request_one AND event_type='ACTIVATED';")" "1" "Activation race creates one ACTIVATED event"
check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.credential_lifecycle_events WHERE role_name='issp_break_glass' AND event_type='ACTIVATED';")" "1" "Activation race creates one credential ACTIVATED event"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_roles WHERE rolname='issp_break_glass' AND rolcanlogin AND rolconnlimit=1 AND NOT rolsuper;")" "1" "Activation race leaves one constrained LOGIN role"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_auth_members m JOIN pg_roles member_role ON member_role.oid=m.member JOIN pg_roles granted_role ON granted_role.oid=m.roleid WHERE member_role.rolname='issp_break_glass' AND granted_role.rolname IN ('issp_database_owner','issp_foundation_owner','issp_extension_owner') AND NOT m.admin_option AND m.set_option AND NOT m.inherit_option;")" "3" "Activation race grants exactly three SET-only owner memberships"
check_equal "$(sql_scalar "SELECT has_database_privilege('issp_break_glass', current_database(), 'CONNECT')::int;")" "1" "Activation race grants database CONNECT"

expect_sql_failure \
    "A second activation after the race is rejected" \
    "SELECT emergency_control.activate_break_glass($request_one,'late-operator','$winning_verifier');"


echo
echo "== Live-session termination and controlled closure =="

PGPASSWORD="$winning_password" psql \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --host="$socket_dir" \
    --port="$port" \
    --username=issp_break_glass \
    --dbname="$database_name" \
    --command="SELECT pg_sleep(30);" \
    >"$temp_root/break-glass-session.out" \
    2>"$temp_root/break-glass-session.err" &
break_glass_client_pid=$!

session_seen=0
for _ in $(seq 1 100); do
    session_seen="$(sql_scalar "SELECT (count(*) > 0)::int FROM pg_stat_activity WHERE usename='issp_break_glass';")"
    [[ "$session_seen" == "1" ]] && break
    sleep 0.05
done
check_equal "$session_seen" "1" "Password-authenticated break-glass session becomes active"

if sql_succeeds "SELECT emergency_control.deactivate_break_glass($request_one,'closure-operator','Step 7 live-session termination test completed.');"; then
    pass "Controlled deactivation succeeds while a session is active"
else
    fail "Controlled deactivation succeeds while a session is active"
fi

if wait "$break_glass_client_pid" 2>/dev/null; then
    fail "Controlled deactivation terminates the active break-glass session"
else
    pass "Controlled deactivation terminates the active break-glass session"
fi

check_equal "$(sql_scalar "SELECT count(*) FROM pg_stat_activity WHERE usename='issp_break_glass';")" "0" "No break-glass sessions remain after deactivation"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_authid WHERE rolname='issp_break_glass' AND NOT rolcanlogin AND rolpassword IS NULL;")" "1" "Deactivation restores NOLOGIN and clears the verifier"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member WHERE r.rolname='issp_break_glass';")" "0" "Deactivation revokes temporary memberships"
check_equal "$(sql_scalar "SELECT has_database_privilege('issp_break_glass', current_database(), 'CONNECT')::int;")" "0" "Deactivation revokes database CONNECT"
check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.break_glass_events WHERE break_glass_request_id=$request_one AND event_type='DEACTIVATED';")" "1" "Deactivation creates one closure event"

expect_sql_failure \
    "Repeated deactivation is rejected" \
    "SELECT emergency_control.deactivate_break_glass($request_one,'repeat-operator','duplicate closure');"
expect_sql_failure \
    "A fingerprint that reached ACTIVATED cannot be reused" \
    "SELECT emergency_control.prepare_break_glass_activation('INC-REUSE','reuse attempt','requester-r','approver-r1','approver-r2','vault://reuse','$winning_fingerprint',interval '20 minutes');"


echo
echo "== Use recording versus deactivation race =="

request_two="$(sql_scalar "SELECT emergency_control.prepare_break_glass_activation('INC-RACE-USE','use versus close','requester-c','approver-c1','approver-c2','vault://step7/three','$fingerprint_three',interval '20 minutes');")"
if [[ "$request_two" =~ ^[0-9]+$ ]]; then
    pass "Prepared request for use-versus-deactivation race"
else
    fail "Prepared request for use-versus-deactivation race"
fi

if sql_succeeds "SELECT emergency_control.activate_break_glass($request_two,'activation-operator-three','$verifier_three');"; then
    pass "Activated request for use-versus-deactivation race"
else
    fail "Activated request for use-versus-deactivation race"
fi

use_sql="SELECT emergency_control.record_break_glass_use($request_two,'use-operator','Reviewed protected ownership posture.','deployment_meta.break_glass_posture');"
close_sql="SELECT emergency_control.deactivate_break_glass($request_two,'deactivation-operator','Concurrent use-versus-deactivation race completed.');"
run_race_pair "use-close-race" "$use_sql" "$close_sql"

check_equal "$RACE_STATUS_TWO" "0" "Deactivation succeeds in the use-versus-deactivation race"
if [[ "$RACE_STATUS_ONE" == "0" ]] || grep -Fq "active unexpired request" "$RACE_DIR/err-one"; then
    pass "Use-versus-deactivation reaches an allowed serialized outcome"
else
    fail "Use-versus-deactivation reaches an allowed serialized outcome"
fi
check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.break_glass_events WHERE break_glass_request_id=$request_two AND event_type='DEACTIVATED';")" "1" "Use-versus-deactivation writes one closure event"
check_one_of "$(sql_scalar "SELECT count(*) FROM deployment_meta.break_glass_events WHERE break_glass_request_id=$request_two AND event_type='USE_RECORDED';")" "0" "1" "Use-versus-deactivation writes at most one use event"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_authid WHERE rolname='issp_break_glass' AND NOT rolcanlogin AND rolpassword IS NULL;")" "1" "Use-versus-deactivation ends disabled"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member WHERE r.rolname='issp_break_glass';")" "0" "Use-versus-deactivation leaves no memberships"


echo
echo "== Forced expiration versus deactivation race =="

request_three="$(sql_scalar "SELECT emergency_control.prepare_break_glass_activation('INC-RACE-EXPIRE','expiration versus close','requester-d','approver-d1','approver-d2','vault://step7/four','$fingerprint_four',interval '20 minutes');")"
if [[ "$request_three" =~ ^[0-9]+$ ]]; then
    pass "Prepared request for expiration-versus-deactivation race"
else
    fail "Prepared request for expiration-versus-deactivation race"
fi

if sql_succeeds "SELECT emergency_control.activate_break_glass($request_three,'activation-operator-four','$verifier_four');"; then
    pass "Activated request for expiration-versus-deactivation race"
else
    fail "Activated request for expiration-versus-deactivation race"
fi

expire_sql="SELECT emergency_control.enforce_break_glass_expiration('expiration-operator',clock_timestamp()+interval '2 hours');"
deactivate_sql="SELECT emergency_control.deactivate_break_glass($request_three,'deactivation-operator-two','Concurrent expiration-versus-deactivation race completed.');"
run_race_pair "expire-close-race" "$expire_sql" "$deactivate_sql"

if [[ "$RACE_STATUS_ONE" == "0" || "$RACE_STATUS_TWO" == "0" ]]; then
    pass "Expiration-versus-deactivation has at least one successful closer"
else
    fail "Expiration-versus-deactivation has at least one successful closer"
fi

check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.break_glass_events WHERE break_glass_request_id=$request_three AND event_type IN ('DEACTIVATED','EXPIRED');")" "1" "Expiration-versus-deactivation writes exactly one closure event"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_authid WHERE rolname='issp_break_glass' AND NOT rolcanlogin AND rolpassword IS NULL;")" "1" "Expiration-versus-deactivation ends disabled"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member WHERE r.rolname='issp_break_glass';")" "0" "Expiration-versus-deactivation leaves no memberships"
check_equal "$(sql_scalar "SELECT has_database_privilege('issp_break_glass', current_database(), 'CONNECT')::int;")" "0" "Expiration-versus-deactivation revokes CONNECT"


echo
echo "== Evidence, privilege, and final-posture invariants =="

check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.break_glass_events e LEFT JOIN deployment_meta.break_glass_evidence_outbox o ON o.break_glass_event_id=e.break_glass_event_id WHERE o.evidence_record_id IS NULL;")" "0" "Every break-glass event has one off-host evidence record"
check_equal "$(sql_scalar "SELECT count(*) FROM (SELECT break_glass_event_id FROM deployment_meta.break_glass_evidence_outbox GROUP BY break_glass_event_id HAVING count(*) <> 1) AS duplicate_record;")" "0" "No break-glass event has duplicate evidence"
check_equal "$(sql_scalar "SELECT count(*) FROM deployment_meta.break_glass_evidence_outbox WHERE NOT off_host_export_required;")" "0" "Every emergency evidence record requires off-host export"
check_equal "$(sql_scalar "SELECT count(*) FROM information_schema.columns WHERE table_schema='deployment_meta' AND table_name IN ('break_glass_requests','break_glass_events','break_glass_evidence_outbox','credential_lifecycle_events') AND column_name ~ '(password|verifier|secret|private_key|token)';")" "0" "Emergency evidence schemas contain no raw credential columns"

expect_sql_failure \
    "Emergency request evidence rejects UPDATE" \
    "UPDATE deployment_meta.break_glass_requests SET reason='tampered' WHERE break_glass_request_id=$request_one;"
expect_sql_failure \
    "Emergency event evidence rejects DELETE" \
    "DELETE FROM deployment_meta.break_glass_events WHERE break_glass_request_id=$request_one;"
expect_sql_failure \
    "Credential lifecycle evidence rejects UPDATE" \
    "UPDATE deployment_meta.credential_lifecycle_events SET reason='tampered' WHERE role_name='issp_break_glass';"
expect_sql_failure \
    "Runtime service cannot read emergency base evidence" \
    "SET ROLE issp_service_authorization; SELECT count(*) FROM deployment_meta.break_glass_events;"
expect_sql_failure \
    "Validation reader cannot execute emergency controls" \
    "SET ROLE issp_validation_reader; SELECT emergency_control.enforce_break_glass_expiration('validation-reader');"
expect_sql_failure \
    "Audit reader cannot mutate emergency evidence" \
    "SET ROLE issp_audit_reader; DELETE FROM deployment_meta.break_glass_events;"

check_equal "$(sql_scalar "SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN LATERAL pg_catalog.aclexplode(coalesce(p.proacl,pg_catalog.acldefault('f',p.proowner))) acl WHERE n.nspname='emergency_control' AND acl.grantee=0 AND acl.privilege_type='EXECUTE';")" "0" "PUBLIC cannot execute emergency-control routines"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_authid WHERE rolname='issp_break_glass' AND NOT rolcanlogin AND rolpassword IS NULL AND NOT rolsuper AND NOT rolcreaterole AND NOT rolcreatedb AND NOT rolreplication AND NOT rolbypassrls;")" "1" "Final break-glass posture is disabled and unprivileged"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member WHERE r.rolname='issp_break_glass';")" "0" "Final break-glass posture has no memberships"
check_equal "$(sql_scalar "SELECT has_database_privilege('issp_break_glass', current_database(), 'CONNECT')::int;")" "0" "Final break-glass posture has no database CONNECT"
check_equal "$(sql_scalar "SELECT count(*) FROM pg_stat_activity WHERE usename='issp_break_glass';")" "0" "Final break-glass posture has no active sessions"

printf '\n== Disposable-cluster final result ==\n'
printf 'PASS checks: %s\n' "$PASS_COUNT"
printf 'FAIL checks: %s\n' "$FAIL_COUNT"

if (( FAIL_COUNT == 0 )); then
    printf '\nPhase 5 Step 7 hostile-condition and role-race validation PASSED.\n'
    printf 'Concurrent preparation, activation, use, deactivation, expiration, and hostile-input boundaries remained deterministic and fail-closed.\n'
    exit 0
fi

printf '\nPhase 5 Step 7 hostile-condition and role-race validation FAILED.\n' >&2
exit 1
