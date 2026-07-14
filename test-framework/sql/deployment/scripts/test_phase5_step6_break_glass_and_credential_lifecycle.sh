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

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase5-step6.XXXXXX")"
data_dir="$temp_root/data"
socket_dir="$temp_root/socket"
log_file="$temp_root/postgresql.log"
deployment_log="$temp_root/deployment.log"
step6_deployment_root="$temp_root/step6-deployment"
port=55436
database_name="issp_phase5_step6_test"
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
max_connections = 30
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

mkdir -p "$step6_deployment_root"
cp -R "$repo_root/sql/deployment/." "$step6_deployment_root/"
cat >"$step6_deployment_root/manifests/deployment.manifest" <<'MANIFEST'
migrations/900_postgresql_role_topology_and_membership.sql
migrations/910_database_schema_and_object_ownership.sql
migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql
migrations/930_investigator_audit_and_validation_review_surfaces.sql
migrations/940_break_glass_and_credential_lifecycle.sql
MANIFEST
chmod +x "$step6_deployment_root/scripts/apply_deployment.sh"

if PGHOST="$socket_dir" \
   PGPORT="$port" \
   PGUSER=postgres \
   "$step6_deployment_root/scripts/apply_deployment.sh" \
   "$database_name" \
   >"$deployment_log" 2>&1; then
    pass "Applied deployment migrations through Step 6"
else
    fail "Applied deployment migrations through Step 6"
    cat "$deployment_log" >&2
fi

if PGHOST="$socket_dir" \
   PGPORT="$port" \
   PGUSER=postgres \
   "$step6_deployment_root/scripts/apply_deployment.sh" \
   "$database_name" \
   >>"$deployment_log" 2>&1; then
    pass "Step 6 deployment prefix reapplication is idempotent"
else
    fail "Step 6 deployment prefix reapplication is idempotent"
    cat "$deployment_log" >&2
fi

query_scalar() {
    "${psql_base[@]}" \
        --tuples-only \
        --no-align \
        --command="$1" \
        | sed '/^[[:space:]]*$/d' \
        | tail -n 1
}

assert_scalar() {
    local label="$1"
    local expected="$2"
    local sql="$3"
    local actual
    actual="$(query_scalar "$sql" 2>/dev/null || true)"
    if [[ "$actual" == "$expected" ]]; then
        pass "$label = $expected"
    else
        fail "$label expected=$expected actual=${actual:-missing}"
    fi
}

assert_sql_succeeds() {
    local label="$1"
    local sql="$2"
    if "${psql_base[@]}" --command="$sql" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_sql_fails() {
    local label="$1"
    local sql="$2"
    if "${psql_base[@]}" --command="$sql" >/dev/null 2>&1; then
        fail "$label"
    else
        pass "$label"
    fi
}

assert_succeeds_as_role() {
    local role_name="$1"
    local label="$2"
    local sql="$3"
    if "${psql_base[@]}" \
        --command="SET ROLE ${role_name}; ${sql}" \
        >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_fails_as_role() {
    local role_name="$1"
    local label="$2"
    local sql="$3"
    if "${psql_base[@]}" \
        --command="SET ROLE ${role_name}; ${sql}" \
        >/dev/null 2>&1; then
        fail "$label"
    else
        pass "$label"
    fi
}

read -r \
    test_password_one \
    test_scram_verifier_one \
    fingerprint_one \
    test_password_two \
    test_scram_verifier_two \
    fingerprint_two < <(
    python3 - <<'PYCODE'
import base64
import hashlib
import hmac
import secrets


def make_credential():
    password = secrets.token_urlsafe(24)
    salt = secrets.token_bytes(18)
    iterations = 4096
    salted_password = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        iterations,
    )
    client_key = hmac.new(
        salted_password,
        b"Client Key",
        hashlib.sha256,
    ).digest()
    stored_key = hashlib.sha256(client_key).digest()
    server_key = hmac.new(
        salted_password,
        b"Server Key",
        hashlib.sha256,
    ).digest()
    verifier = (
        f"SCRAM-SHA-256${iterations}:"
        f"{base64.b64encode(salt).decode('ascii')}$"
        f"{base64.b64encode(stored_key).decode('ascii')}:"
        f"{base64.b64encode(server_key).decode('ascii')}"
    )
    fingerprint = hashlib.sha256(verifier.encode("utf-8")).hexdigest()
    return password, verifier, fingerprint

password_one, verifier_one, fingerprint_one = make_credential()
password_two, verifier_two, fingerprint_two = make_credential()
print(
    password_one, verifier_one, fingerprint_one,
    password_two, verifier_two, fingerprint_two,
)
PYCODE
)

if [[ -n "$test_password_one" \
      && "$test_scram_verifier_one" == SCRAM-SHA-256\$* \
      && -n "$test_password_two" \
      && "$test_scram_verifier_two" == SCRAM-SHA-256\$* \
      && "$test_scram_verifier_one" != "$test_scram_verifier_two" ]]; then
    pass "Generated two ephemeral test-only SCRAM credentials"
else
    fail "Generated two ephemeral test-only SCRAM credentials"
fi

printf '\n== Deployment and lifecycle inventory ==\n'

assert_scalar \
    "Registered deployment migrations" \
    "5" \
    "SELECT count(*) FROM deployment_meta.applied_deployment_migrations;"

assert_scalar \
    "Credential lifecycle policy rows" \
    "5" \
    "SELECT count(*) FROM deployment_meta.credential_lifecycle_policy;"

assert_scalar \
    "Step 6 security-barrier views" \
    "5" \
    "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='deployment_meta' AND c.relname IN ('audit_break_glass_events','audit_credential_lifecycle_events','break_glass_posture','credential_lifecycle_posture','break_glass_evidence_posture') AND c.relkind='v' AND 'security_barrier=true'=ANY(coalesce(c.reloptions,ARRAY[]::text[]));"

assert_scalar \
    "Append-only emergency evidence triggers" \
    "4" \
    "SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='deployment_meta' AND c.relname IN ('credential_lifecycle_events','break_glass_requests','break_glass_events','break_glass_evidence_outbox') AND NOT t.tgisinternal AND t.tgenabled <> 'D';"

printf '\n== Disabled-at-rest posture ==\n'

assert_scalar \
    "Break-glass role is NOLOGIN and unprivileged" \
    "1" \
    "SELECT count(*) FROM pg_roles WHERE rolname='issp_break_glass' AND NOT rolcanlogin AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolreplication AND NOT rolbypassrls AND rolconnlimit=-1;"

assert_scalar \
    "Break-glass role has no password" \
    "1" \
    "SELECT count(*) FROM pg_authid WHERE rolname='issp_break_glass' AND rolpassword IS NULL;"

assert_scalar \
    "Break-glass role has no standing memberships" \
    "0" \
    "SELECT count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member WHERE r.rolname='issp_break_glass';"

assert_scalar \
    "Break-glass role lacks database CONNECT at rest" \
    "0" \
    "SELECT has_database_privilege('issp_break_glass', current_database(), 'CONNECT')::int;"

if PGPASSWORD="$test_password_one" psql \
    --no-psqlrc \
    --host="$socket_dir" \
    --port="$port" \
    --username=issp_break_glass \
    --dbname="$database_name" \
    --command='SELECT 1;' \
    >/dev/null 2>&1; then
    fail "Break-glass cannot connect at rest"
else
    pass "Break-glass cannot connect at rest"
fi

printf '\n== Request and independent approval enforcement ==\n'




assert_sql_fails \
    "Request rejects reused or non-independent approvers" \
    "SELECT emergency_control.prepare_break_glass_activation('INC-STEP6-FAIL','Test rejection','requester-a','approver-b','approver-b','vault://break-glass/fail','${fingerprint_one}',interval '30 minutes');"

request_one="$(query_scalar "SELECT emergency_control.prepare_break_glass_activation('INC-STEP6-001','Controlled Step 6 activation test','requester-a','approver-b','approver-c','vault://break-glass/certificate-001','${fingerprint_one}',interval '30 minutes');")"
if [[ "$request_one" =~ ^[0-9]+$ ]]; then
    pass "Prepared dual-approved break-glass request"
else
    fail "Prepared dual-approved break-glass request"
fi

assert_scalar \
    "Initial request event recorded" \
    "1" \
    "SELECT count(*) FROM deployment_meta.break_glass_events WHERE break_glass_request_id=${request_one} AND event_type='REQUESTED';"

assert_scalar \
    "Initial off-host evidence record created" \
    "1" \
    "SELECT count(*) FROM deployment_meta.break_glass_evidence_outbox WHERE break_glass_request_id=${request_one} AND evidence_type='REQUESTED' AND off_host_export_required;"

assert_sql_fails \
    "Activation operator must be independent" \
    "SELECT emergency_control.activate_break_glass(${request_one},'approver-b','${test_scram_verifier_one}');"

assert_sql_fails \
    "Activation rejects non-SCRAM credential material" \
    "SELECT emergency_control.activate_break_glass(${request_one},'operator-d','not-a-scram-verifier');"

assert_fails_as_role \
    "issp_service_authorization" \
    "Runtime service cannot activate break-glass" \
    "SELECT emergency_control.activate_break_glass(${request_one},'service-operator','${test_scram_verifier_one}');"

activation_expiry="$(query_scalar "SELECT emergency_control.activate_break_glass(${request_one},'operator-d','${test_scram_verifier_one}');")"
if [[ -n "$activation_expiry" ]]; then
    pass "Activated break-glass through controlled procedure"
else
    fail "Activated break-glass through controlled procedure"
fi

printf '\n== Active emergency boundary ==\n'

assert_scalar \
    "Break-glass role is LOGIN with connection limit one" \
    "1" \
    "SELECT count(*) FROM pg_roles WHERE rolname='issp_break_glass' AND rolcanlogin AND rolconnlimit=1 AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolreplication AND NOT rolbypassrls;"

assert_scalar \
    "Break-glass role has a temporary SCRAM verifier while active" \
    "1" \
    "SELECT count(*) FROM pg_authid WHERE rolname='issp_break_glass' AND rolpassword LIKE 'SCRAM-SHA-256$%';"

assert_scalar \
    "Break-glass password expiration matches the approved request" \
    "1" \
    "SELECT count(*) FROM pg_roles r JOIN deployment_meta.break_glass_requests q ON q.break_glass_request_id=${request_one} WHERE r.rolname='issp_break_glass' AND r.rolvaliduntil=q.expires_at AND r.rolvaliduntil>clock_timestamp();"

assert_scalar \
    "Break-glass receives three temporary owner memberships" \
    "3" \
    "SELECT count(*) FROM pg_auth_members m JOIN pg_roles member_role ON member_role.oid=m.member JOIN pg_roles granted_role ON granted_role.oid=m.roleid WHERE member_role.rolname='issp_break_glass' AND granted_role.rolname IN ('issp_database_owner','issp_foundation_owner','issp_extension_owner') AND NOT m.admin_option AND NOT m.inherit_option AND m.set_option;"

assert_scalar \
    "Break-glass has database CONNECT while active" \
    "1" \
    "SELECT has_database_privilege('issp_break_glass', current_database(), 'CONNECT')::int;"

if PGPASSWORD="$test_password_one" psql \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --host="$socket_dir" \
    --port="$port" \
    --username=issp_break_glass \
    --dbname="$database_name" \
    --command='SET ROLE issp_foundation_owner; SELECT current_user;' \
    >/dev/null 2>&1; then
    pass "Active break-glass can connect and SET ROLE to Foundation owner"
else
    fail "Active break-glass can connect and SET ROLE to Foundation owner"
fi

if PGPASSWORD="$test_password_one" psql \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --host="$socket_dir" \
    --port="$port" \
    --username=issp_break_glass \
    --dbname="$database_name" \
    --command='SET ROLE issp_runtime; SELECT current_user;' \
    >/dev/null 2>&1; then
    fail "Active break-glass cannot assume unrelated runtime role"
else
    pass "Active break-glass cannot assume unrelated runtime role"
fi

assert_sql_succeeds \
    "Recorded attributable break-glass use" \
    "SELECT emergency_control.record_break_glass_use(${request_one},'operator-d','Reviewed and repaired governed deployment posture','deployment_meta');"

assert_scalar \
    "Use evidence is present" \
    "1" \
    "SELECT count(*) FROM deployment_meta.break_glass_events WHERE break_glass_request_id=${request_one} AND event_type='USE_RECORDED';"

printf '\n== Controlled deactivation and rotation ==\n'

assert_sql_succeeds \
    "Controlled deactivation succeeds" \
    "SELECT emergency_control.deactivate_break_glass(${request_one},'operator-e','Emergency activity completed and independently handed off for review.');"

assert_scalar \
    "Break-glass returns to NOLOGIN" \
    "1" \
    "SELECT count(*) FROM pg_roles WHERE rolname='issp_break_glass' AND NOT rolcanlogin AND rolconnlimit=-1;"

assert_scalar \
    "Temporary owner memberships are revoked" \
    "0" \
    "SELECT count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member WHERE r.rolname='issp_break_glass';"

assert_scalar \
    "Database CONNECT is revoked after deactivation" \
    "0" \
    "SELECT has_database_privilege('issp_break_glass', current_database(), 'CONNECT')::int;"

assert_scalar \
    "Temporary SCRAM verifier is cleared after deactivation" \
    "1" \
    "SELECT count(*) FROM pg_authid WHERE rolname='issp_break_glass' AND rolpassword IS NULL;"

assert_scalar \
    "Credential rotation is required after use" \
    "1" \
    "SELECT count(*) FROM deployment_meta.credential_lifecycle_events WHERE role_name='issp_break_glass' AND event_type='ROTATION_REQUIRED' AND credential_fingerprint='${fingerprint_one}';"

assert_sql_fails \
    "Activated credential fingerprint cannot be reused" \
    "SELECT emergency_control.prepare_break_glass_activation('INC-STEP6-REUSE','Fingerprint reuse test','requester-f','approver-g','approver-h','vault://break-glass/certificate-001','${fingerprint_one}',interval '30 minutes');"

printf '\n== Forced expiration ==\n'

request_two="$(query_scalar "SELECT emergency_control.prepare_break_glass_activation('INC-STEP6-002','Expiration enforcement test','requester-f','approver-g','approver-h','vault://break-glass/certificate-002','${fingerprint_two}',interval '30 minutes');")"
if [[ "$request_two" =~ ^[0-9]+$ ]]; then
    pass "Prepared second request with rotated credential fingerprint"
else
    fail "Prepared second request with rotated credential fingerprint"
fi

assert_sql_succeeds \
    "Second request activates" \
    "SELECT emergency_control.activate_break_glass(${request_two},'operator-i','${test_scram_verifier_two}');"

assert_scalar \
    "Expiration enforcement closes one active request" \
    "1" \
    "SELECT emergency_control.enforce_break_glass_expiration('expiration-controller',clock_timestamp()+interval '2 hours');"

assert_scalar \
    "Expiration event recorded" \
    "1" \
    "SELECT count(*) FROM deployment_meta.break_glass_events WHERE break_glass_request_id=${request_two} AND event_type='EXPIRED';"

assert_scalar \
    "Break-glass is disabled after expiration" \
    "1" \
    "SELECT count(*) FROM pg_roles WHERE rolname='issp_break_glass' AND NOT rolcanlogin AND rolconnlimit=-1;"

printf '\n== Evidence immutability and review boundaries ==\n'

assert_sql_fails \
    "Break-glass request evidence rejects UPDATE" \
    "UPDATE deployment_meta.break_glass_requests SET reason='tampered' WHERE break_glass_request_id=${request_one};"

assert_sql_fails \
    "Break-glass event evidence rejects DELETE" \
    "DELETE FROM deployment_meta.break_glass_events WHERE break_glass_request_id=${request_one};"

assert_scalar \
    "Every break-glass event has an off-host evidence record" \
    "0" \
    "SELECT count(*) FROM deployment_meta.break_glass_events e LEFT JOIN deployment_meta.break_glass_evidence_outbox o ON o.break_glass_event_id=e.break_glass_event_id WHERE o.break_glass_event_id IS NULL OR NOT o.off_host_export_required;"

assert_scalar \
    "No raw credential storage columns exist" \
    "0" \
    "SELECT count(*) FROM information_schema.columns WHERE table_schema='deployment_meta' AND table_name IN ('credential_lifecycle_events','break_glass_requests','break_glass_events','break_glass_evidence_outbox') AND column_name IN ('password','secret','private_key','credential_value','token_value');"

assert_succeeds_as_role \
    "issp_audit_reader" \
    "Audit reader can review break-glass events" \
    "SELECT count(*) FROM deployment_meta.audit_break_glass_events;"

assert_succeeds_as_role \
    "issp_audit_reader" \
    "Audit reader can review credential lifecycle events" \
    "SELECT count(*) FROM deployment_meta.audit_credential_lifecycle_events;"

assert_fails_as_role \
    "issp_audit_reader" \
    "Audit reader cannot read break-glass request base table" \
    "SELECT count(*) FROM deployment_meta.break_glass_requests;"

assert_succeeds_as_role \
    "issp_validation_reader" \
    "Validation reader can read break-glass posture" \
    "SELECT count(*) FROM deployment_meta.break_glass_posture;"

assert_succeeds_as_role \
    "issp_validation_reader" \
    "Validation reader can read credential lifecycle posture" \
    "SELECT count(*) FROM deployment_meta.credential_lifecycle_posture;"

assert_fails_as_role \
    "issp_validation_reader" \
    "Validation reader cannot execute emergency controls" \
    "SELECT emergency_control.enforce_break_glass_expiration('validation-reader');"

assert_fails_as_role \
    "issp_service_authorization" \
    "Runtime service cannot read emergency review views" \
    "SELECT count(*) FROM deployment_meta.break_glass_posture;"

assert_scalar \
    "PUBLIC cannot execute emergency-control routines" \
    "0" \
    "SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN LATERAL pg_catalog.aclexplode(coalesce(p.proacl,pg_catalog.acldefault('f',p.proowner))) AS acl_record WHERE n.nspname='emergency_control' AND acl_record.grantee=0 AND acl_record.privilege_type='EXECUTE';"

printf '\n== Disposable-cluster final result ==\n'
printf 'PASS checks: %s\n' "$PASS_COUNT"
printf 'FAIL checks: %s\n' "$FAIL_COUNT"

if (( FAIL_COUNT == 0 )); then
    printf '\nPhase 5 Step 6 disposable-cluster validation PASSED.\n'
    printf 'Break-glass is disabled at rest, independently approved, time-bounded, attributable, forcibly deactivated, and credential-rotation governed.\n'
    exit 0
fi

printf '\nPhase 5 Step 6 disposable-cluster validation FAILED.\n' >&2
exit 1
