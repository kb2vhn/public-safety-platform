#!/usr/bin/env bash
#
# Iron Signal Platform
# Phase 5 Step 4 disposable-cluster runtime privilege validation
#
# This script creates and destroys an isolated PostgreSQL cluster. It does not
# create roles in the shared development cluster.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

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

for command_name in initdb pg_ctl createdb psql; do
    require_command "$command_name"
done

if [[ "$FAIL_COUNT" -ne 0 ]]; then
    exit 1
fi

work_root="$(mktemp -d)"
data_dir="$work_root/data"
socket_dir="$work_root/socket"
log_file="$work_root/postgresql.log"
database_name="issp_phase5_step4_test"
port="$((20000 + ($$ % 20000)))"
cluster_started=false

cleanup() {
    if $cluster_started; then
        pg_ctl \
            -D "$data_dir" \
            -m immediate \
            -w \
            stop >/dev/null 2>&1 || true
    fi

    rm -rf "$work_root"
}
trap cleanup EXIT

mkdir -p "$socket_dir"

initdb \
    -D "$data_dir" \
    --username=postgres \
    --auth=trust \
    --encoding=UTF8 \
    --no-locale \
    >/dev/null

cat >>"$data_dir/postgresql.conf" <<EOF
listen_addresses = ''
unix_socket_directories = '$socket_dir'
port = $port
max_connections = 40
fsync = off
synchronous_commit = off
full_page_writes = off
EOF

pg_ctl \
    -D "$data_dir" \
    -l "$log_file" \
    -w \
    start >/dev/null

cluster_started=true
pass "Disposable PostgreSQL cluster started"

export PGHOST="$socket_dir"
export PGPORT="$port"
export PGDATABASE="$database_name"
export PGUSER="postgres"

createdb \
    --template=template0 \
    "$database_name"

pass "Disposable database created from template0"

foundation_manifest="sql/schema/manifests/foundation.manifest"

while IFS= read -r migration_relative_path; do
    [[ -n "$migration_relative_path" ]] || continue
    [[ "$migration_relative_path" =~ ^[[:space:]]*# ]] && continue

    psql \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --file="sql/schema/$migration_relative_path" \
        >/dev/null
done <"$foundation_manifest"

pass "Applied all Foundation migrations"

sql/deployment/scripts/apply_deployment.sh \
    "$database_name" \
    >/dev/null

pass "Applied deployment migrations 900, 910, and 920"

sql/deployment/scripts/apply_deployment.sh \
    "$database_name" \
    >/dev/null

pass "Reapplied deployment manifest idempotently"

sql_value() {
    local role_name="$1"
    local sql="$2"

    PGUSER="$role_name" \
    psql \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --tuples-only \
        --no-align \
        --quiet \
        --command="$sql" \
        | sed '/^[[:space:]]*$/d' \
        | tail -n 1
}

assert_equal() {
    local label="$1"
    local expected="$2"
    local role_name="$3"
    local sql="$4"
    local actual

    if ! actual="$(sql_value "$role_name" "$sql" 2>"$work_root/assert.err")"; then
        fail "$label"
        sed 's/^/    /' "$work_root/assert.err" >&2
        return
    fi

    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label (expected=$expected actual=$actual)"
    fi
}

assert_denied() {
    local label="$1"
    local role_name="$2"
    local sql="$3"

    if PGUSER="$role_name" \
       psql \
           --no-psqlrc \
           --set=ON_ERROR_STOP=1 \
           --quiet \
           --command="$sql" \
           >"$work_root/denied.out" \
           2>"$work_root/denied.err"; then
        fail "$label"
        return
    fi

    if grep -Eqi \
        'permission denied|must be owner|not allowed to connect' \
        "$work_root/denied.err"; then
        pass "$label"
    else
        fail "$label (failure was not a privilege denial)"
        sed 's/^/    /' "$work_root/denied.err" >&2
    fi
}

assert_equal \
    "Deployment registry contains three migrations" \
    "3" \
    "postgres" \
    "SELECT count(*) FROM deployment_meta.applied_deployment_migrations;"

assert_equal \
    "Runtime privilege allowlist contains 40 rows" \
    "40" \
    "postgres" \
    "SELECT count(*) FROM deployment_meta.runtime_privilege_contract;"

assert_equal \
    "Runtime allowlist contains eight schema grants" \
    "8" \
    "postgres" \
    "SELECT count(*) FROM deployment_meta.runtime_privilege_contract WHERE object_kind = 'SCHEMA';"

assert_equal \
    "Runtime allowlist contains 31 routine grants" \
    "31" \
    "postgres" \
    "SELECT count(*) FROM deployment_meta.runtime_privilege_contract WHERE object_kind = 'ROUTINE';"

assert_equal \
    "issp_runtime has database CONNECT" \
    "t" \
    "postgres" \
    "SELECT has_database_privilege('issp_runtime', current_database(), 'CONNECT');"

assert_equal \
    "Authorization service inherits database CONNECT" \
    "t" \
    "postgres" \
    "SELECT has_database_privilege('issp_service_authorization', current_database(), 'CONNECT');"

assert_equal \
    "Integration service inherits database CONNECT" \
    "t" \
    "postgres" \
    "SELECT has_database_privilege('issp_service_integration_delivery', current_database(), 'CONNECT');"

assert_equal \
    "Monitoring service inherits database CONNECT" \
    "t" \
    "postgres" \
    "SELECT has_database_privilege('issp_service_monitoring_delivery', current_database(), 'CONNECT');"

assert_equal \
    "Deferred and emergency roles remain disconnected" \
    "0" \
    "postgres" \
    "SELECT count(*) FROM (VALUES ('issp_migration_executor'::name), ('issp_read_only_investigator'::name), ('issp_audit_reader'::name), ('issp_validation_reader'::name), ('issp_break_glass'::name)) AS denied(role_name) WHERE has_database_privilege(denied.role_name, current_database(), 'CONNECT');"

assert_equal \
    "Runtime and service roles lack TEMPORARY" \
    "0" \
    "postgres" \
    "SELECT count(*) FROM (VALUES ('issp_runtime'::name), ('issp_service_authorization'::name), ('issp_service_integration_delivery'::name), ('issp_service_monitoring_delivery'::name)) AS runtime_role(role_name) WHERE has_database_privilege(runtime_role.role_name, current_database(), 'TEMPORARY');"

assert_equal \
    "All 31 exposed routines are SECURITY DEFINER and Foundation-owned" \
    "31" \
    "postgres" \
    "SELECT count(*) FROM deployment_meta.runtime_privilege_contract AS contract JOIN pg_proc AS routine_record ON routine_record.oid = to_regprocedure(contract.object_identity) WHERE contract.object_kind = 'ROUTINE' AND routine_record.prosecdef AND pg_get_userbyid(routine_record.proowner) = 'issp_foundation_owner';"

assert_equal \
    "All 31 exposed routines have fixed pg_catalog-first search paths" \
    "31" \
    "postgres" \
    "SELECT count(*) FROM deployment_meta.runtime_privilege_contract AS contract JOIN pg_proc AS routine_record ON routine_record.oid = to_regprocedure(contract.object_identity) WHERE contract.object_kind = 'ROUTINE' AND EXISTS (SELECT 1 FROM unnest(COALESCE(routine_record.proconfig, ARRAY[]::text[])) AS configuration(setting) WHERE configuration.setting LIKE 'search_path=pg_catalog,%');"

assert_equal \
    "PUBLIC cannot execute exposed runtime routines" \
    "0" \
    "postgres" \
    "SELECT count(*) FROM deployment_meta.runtime_privilege_contract AS contract WHERE contract.object_kind = 'ROUTINE' AND has_function_privilege('public', to_regprocedure(contract.object_identity), 'EXECUTE');"

assert_equal \
    "Canonical non-owner roles have no direct relation or sequence grants" \
    "0" \
    "postgres" \
    "SELECT count(*) FROM pg_class AS relation_record JOIN pg_namespace AS namespace_record ON namespace_record.oid = relation_record.relnamespace CROSS JOIN LATERAL aclexplode(relation_record.relacl) AS privilege_record JOIN pg_roles AS grantee_role ON grantee_role.oid = privilege_record.grantee JOIN deployment_meta.database_roles AS canonical_role ON canonical_role.role_name = grantee_role.rolname WHERE NOT canonical_role.ownership_role AND namespace_record.nspname IN ('foundation_meta','trust','identity','organization','service','attestation','approval','access_control','decision','governance','compliance','risk','resilience','performance','observability','integration','security_validation') AND privilege_record.privilege_type IN ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','USAGE');"

assert_equal \
    "Service logins receive no direct routine ACL entries" \
    "0" \
    "postgres" \
    "SELECT count(*) FROM pg_proc AS routine_record CROSS JOIN LATERAL aclexplode(routine_record.proacl) AS privilege_record JOIN pg_roles AS grantee_role ON grantee_role.oid = privilege_record.grantee WHERE grantee_role.rolname IN ('issp_service_authorization','issp_service_integration_delivery','issp_service_monitoring_delivery');"

assert_equal \
    "Foundation owner has extensions schema USAGE" \
    "t" \
    "postgres" \
    "SELECT has_schema_privilege('issp_foundation_owner', 'extensions', 'USAGE');"

assert_equal \
    "Foundation owner can execute the approved digest dependency" \
    "t" \
    "postgres" \
    "SELECT has_function_privilege('issp_foundation_owner', 'extensions.digest(bytea,text)', 'EXECUTE');"

assert_equal \
    "Authorization service inherits 25 approved routine grants" \
    "25" \
    "postgres" \
    "SELECT count(*) FROM deployment_meta.runtime_privilege_contract AS contract WHERE contract.object_kind = 'ROUTINE' AND has_function_privilege('issp_service_authorization', to_regprocedure(contract.object_identity), 'EXECUTE');"

assert_equal \
    "Integration service inherits three approved routine grants" \
    "3" \
    "postgres" \
    "SELECT count(*) FROM deployment_meta.runtime_privilege_contract AS contract WHERE contract.object_kind = 'ROUTINE' AND has_function_privilege('issp_service_integration_delivery', to_regprocedure(contract.object_identity), 'EXECUTE');"

assert_equal \
    "Monitoring service inherits three approved routine grants" \
    "3" \
    "postgres" \
    "SELECT count(*) FROM deployment_meta.runtime_privilege_contract AS contract WHERE contract.object_kind = 'ROUTINE' AND has_function_privilege('issp_service_monitoring_delivery', to_regprocedure(contract.object_identity), 'EXECUTE');"

assert_equal \
    "Authorization service can execute a controlled lifecycle routine" \
    "f" \
    "issp_service_authorization" \
    "SELECT access_control.expire_authentication_assertion('00000000-0000-0000-0000-000000000001'::uuid);"

assert_denied \
    "Authorization service cannot directly insert protected assertions" \
    "issp_service_authorization" \
    "INSERT INTO access_control.authentication_assertions DEFAULT VALUES;"

assert_denied \
    "Integration service cannot execute authorization routines" \
    "issp_service_integration_delivery" \
    "SELECT access_control.expire_authentication_assertion('00000000-0000-0000-0000-000000000001'::uuid);"

assert_denied \
    "Monitoring service cannot execute authorization routines" \
    "issp_service_monitoring_delivery" \
    "SELECT access_control.expire_authentication_assertion('00000000-0000-0000-0000-000000000001'::uuid);"

assert_denied \
    "Authorization service cannot execute integration delivery routines" \
    "issp_service_authorization" \
    "SELECT count(*) FROM integration.claim_outbox_events(1, interval '30 seconds');"

assert_denied \
    "Runtime service cannot create temporary tables" \
    "issp_service_authorization" \
    "CREATE TEMP TABLE forbidden_runtime_temp(id integer);"

psql \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --quiet <<'SQL'
INSERT INTO integration.integration_contracts (
    integration_contract_id,
    contract_key,
    external_system_name,
    adapter_name,
    adapter_version,
    source_of_truth_role,
    status,
    valid_from,
    valid_until
)
VALUES (
    '10000000-0000-0000-0000-000000000001',
    'step4-test-contract',
    'Step 4 Test System',
    'step4-test-adapter',
    '1.0.0',
    'ISSP',
    'ACTIVE',
    statement_timestamp() - interval '1 hour',
    NULL
);

INSERT INTO integration.outbox_events (
    outbox_event_id,
    integration_contract_id,
    event_type,
    aggregate_type,
    aggregate_id,
    payload,
    classification_reference,
    available_at,
    status
)
VALUES (
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'STEP4_TEST',
    'TEST_AGGREGATE',
    'step4-aggregate-1',
    '{"phase":5,"step":4}'::jsonb,
    'INTERNAL',
    statement_timestamp() - interval '1 minute',
    'PENDING'
);
SQL

pass "Seeded one integration outbox event"

assert_equal \
    "Integration service claims one outbox event" \
    "1" \
    "issp_service_integration_delivery" \
    "SELECT count(*) FROM integration.claim_outbox_events(10, interval '1 minute');"

assert_denied \
    "Integration service cannot directly read the outbox table" \
    "issp_service_integration_delivery" \
    "SELECT count(*) FROM integration.outbox_events;"

assert_equal \
    "Integration service completes the claimed event" \
    "t" \
    "issp_service_integration_delivery" \
    "SELECT integration.mark_outbox_event_delivered('10000000-0000-0000-0000-000000000002'::uuid);"

assert_equal \
    "Integration event is DELIVERED" \
    "DELIVERED" \
    "postgres" \
    "SELECT status FROM integration.outbox_events WHERE outbox_event_id = '10000000-0000-0000-0000-000000000002'::uuid;"

psql \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --quiet <<'SQL'
INSERT INTO observability.components (
    component_id,
    component_key,
    component_type,
    application_version,
    owner_reference,
    status
)
VALUES (
    '20000000-0000-0000-0000-000000000001',
    'step4-test-component',
    'TEST',
    '1.0.0',
    'phase5-step4-test',
    'ACTIVE'
);

INSERT INTO observability.health_events (
    health_event_id,
    component_id,
    event_type,
    severity,
    status,
    first_observed_at,
    last_observed_at,
    resource_name,
    current_value,
    threshold_value,
    unit,
    correlation_id,
    user_impact,
    recommended_action,
    owner_reference
)
VALUES (
    '20000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    'STEP4_TEST',
    'INFO',
    'OPEN',
    statement_timestamp(),
    statement_timestamp(),
    'step4-resource',
    1,
    10,
    'count',
    '20000000-0000-0000-0000-000000000003',
    'none',
    'none',
    'phase5-step4-test'
);

INSERT INTO observability.monitoring_subscriptions (
    monitoring_subscription_id,
    subscription_key,
    destination_type,
    destination_reference,
    event_filter,
    status,
    max_retry_count,
    max_queue_depth,
    created_by_reference
)
VALUES (
    '20000000-0000-0000-0000-000000000004',
    'step4-test-subscription',
    'TEST',
    'step4-destination',
    '{}'::jsonb,
    'ACTIVE',
    3,
    100,
    'phase5-step4-test'
);

INSERT INTO observability.monitoring_delivery_state (
    monitoring_delivery_state_id,
    monitoring_subscription_id,
    health_event_id,
    delivery_status,
    attempt_count
)
VALUES (
    '20000000-0000-0000-0000-000000000005',
    '20000000-0000-0000-0000-000000000004',
    '20000000-0000-0000-0000-000000000002',
    'PENDING',
    0
);
SQL

pass "Seeded one monitoring delivery"

assert_equal \
    "Monitoring service claims one delivery" \
    "1" \
    "issp_service_monitoring_delivery" \
    "SELECT count(*) FROM observability.claim_monitoring_deliveries(10, interval '1 minute');"

assert_denied \
    "Monitoring service cannot directly read delivery-state tables" \
    "issp_service_monitoring_delivery" \
    "SELECT count(*) FROM observability.monitoring_delivery_state;"

assert_equal \
    "Monitoring service completes the claimed delivery" \
    "t" \
    "issp_service_monitoring_delivery" \
    "SELECT observability.mark_monitoring_delivery_delivered('20000000-0000-0000-0000-000000000005'::uuid);"

assert_equal \
    "Monitoring delivery is DELIVERED" \
    "DELIVERED" \
    "postgres" \
    "SELECT delivery_status FROM observability.monitoring_delivery_state WHERE monitoring_delivery_state_id = '20000000-0000-0000-0000-000000000005'::uuid;"

echo
echo "== Disposable-cluster final result =="
echo "PASS checks: $PASS_COUNT"
echo "FAIL checks: $FAIL_COUNT"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
    echo
    echo "Phase 5 Step 4 disposable-cluster validation FAILED."
    exit 1
fi

echo
echo "Phase 5 Step 4 disposable-cluster validation PASSED."
echo "Least-privileged runtime access is limited to inherited CONNECT, exact schema USAGE, and controlled routine EXECUTE."
