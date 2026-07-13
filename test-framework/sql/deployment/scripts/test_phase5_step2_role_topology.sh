#!/usr/bin/env bash
#
# Iron Signal Platform Phase 5 Step 2 disposable-cluster role topology test
#
# PostgreSQL roles are cluster-global. This test therefore creates an isolated
# PostgreSQL cluster, applies the Foundation and deployment manifests, validates
# the role topology, stops the cluster, and removes it.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

PASS_COUNT=0
FAIL_COUNT=0
cluster_started=0
temp_root=""

pass() {
    printf 'PASS: %s\n' "$1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

die() {
    fail "$1"
    exit 1
}

trim_manifest_line() {
    local line="$1"

    printf '%s' "$line" \
        | sed 's/\r$//' \
        | sed 's/[[:space:]]*#.*$//' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

check_query_equal() {
    local expected="$1"
    local sql="$2"
    local label="$3"
    local actual

    actual="$(
        psql \
            -X \
            --no-psqlrc \
            --set=ON_ERROR_STOP=1 \
            --tuples-only \
            --no-align \
            --dbname="$test_database" \
            --command="$sql"
    )" || {
        fail "$label (query failed)"
        return
    }

    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label (expected=$expected actual=$actual)"
    fi
}

expect_psql_failure() {
    local role_name="$1"
    local sql="$2"
    local label="$3"

    if psql \
        -X \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --username="$role_name" \
        --dbname="$test_database" \
        --command="$sql" \
        >/dev/null 2>&1
    then
        fail "$label"
    else
        pass "$label"
    fi
}

cleanup() {
    local exit_status=$?
    trap - EXIT INT TERM
    set +e

    if [[ "$cluster_started" == "1" ]]; then
        pg_ctl \
            --pgdata="$temp_root/data" \
            --mode=fast \
            --wait \
            stop \
            >/dev/null 2>&1
    fi

    if [[ -n "$temp_root" && -d "$temp_root" ]]; then
        rm -rf -- "$temp_root"
    fi

    if [[ "$exit_status" -ne 0 && "$FAIL_COUNT" -eq 0 ]]; then
        FAIL_COUNT=1
    fi

    printf '\n== Disposable role-topology result ==\n'
    printf 'PASS checks: %s\n' "$PASS_COUNT"
    printf 'FAIL checks: %s\n' "$FAIL_COUNT"

    if [[ "$exit_status" -ne 0 || "$FAIL_COUNT" -ne 0 ]]; then
        printf 'Phase 5 Step 2 disposable role-topology validation FAILED.\n' >&2
        exit 1
    fi

    printf 'Phase 5 Step 2 disposable role-topology validation PASSED.\n'
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "$(id -u)" == "0" ]]; then
    die "The disposable PostgreSQL cluster test must not run as root"
fi

required_commands=(
    awk
    createdb
    grep
    id
    initdb
    mktemp
    pg_ctl
    psql
    rm
    sed
    sha256sum
)

for command_name in "${required_commands[@]}"; do
    if command -v "$command_name" >/dev/null 2>&1; then
        pass "Dependency available: $command_name"
    else
        fail "Dependency available: $command_name"
    fi
done

[[ "$FAIL_COUNT" -eq 0 ]] \
    || die "Disposable-cluster dependencies are incomplete"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repository_root="$(cd -- "$script_dir/../../../.." && pwd -P)"
schema_root="$repository_root/sql/schema"
deployment_root="$repository_root/sql/deployment"
foundation_manifest="$schema_root/manifests/foundation.manifest"
deployment_manifest="$deployment_root/manifests/deployment.manifest"
deployment_runner="$deployment_root/scripts/apply_deployment.sh"

for required_file in \
    "$foundation_manifest" \
    "$deployment_manifest" \
    "$deployment_runner"
do
    if [[ -f "$required_file" ]]; then
        pass "File exists: ${required_file#$repository_root/}"
    else
        fail "File exists: ${required_file#$repository_root/}"
    fi
done

[[ "$FAIL_COUNT" -eq 0 ]] \
    || die "Required repository files are missing"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase5-step2.XXXXXX")"
mkdir -p -- "$temp_root/socket"

port=55432
test_superuser="issp_step2_test_superuser"
test_database="issp_step2_role_topology_test"

initdb \
    --pgdata="$temp_root/data" \
    --username="$test_superuser" \
    --auth-local=trust \
    --auth-host=reject \
    --no-instructions \
    --no-sync \
    >"$temp_root/initdb.log" 2>&1
pass "Disposable PostgreSQL cluster initialized"

cat >>"$temp_root/data/postgresql.conf" <<EOF
listen_addresses = ''
unix_socket_directories = '$temp_root/socket'
port = $port
fsync = off
synchronous_commit = off
full_page_writes = off
max_connections = 50
EOF

pg_ctl \
    --pgdata="$temp_root/data" \
    --wait \
    --options="-c logging_collector=off" \
    start \
    >"$temp_root/pg_ctl_start.log" 2>&1
cluster_started=1
pass "Disposable PostgreSQL cluster started"

export PGHOST="$temp_root/socket"
export PGPORT="$port"
export PGUSER="$test_superuser"
export PGDATABASE="postgres"
export PGAPPNAME="iron-signal-platform-phase5-step2-test"

server_version_num="$(
    psql \
        -X \
        --no-psqlrc \
        --tuples-only \
        --no-align \
        --command="SELECT current_setting('server_version_num');"
)"

if [[ "$server_version_num" =~ ^[0-9]+$ ]] \
   && (( server_version_num >= 180000 )); then
    pass "Disposable PostgreSQL server is version 18 or newer"
else
    fail "Disposable PostgreSQL server is version 18 or newer"
fi

createdb \
    --maintenance-db=postgres \
    --template=template0 \
    "$test_database"
pass "Disposable deployment test database created"

foundation_count=0
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    relative_path="$(trim_manifest_line "$raw_line")"
    [[ -z "$relative_path" ]] && continue

    migration_file="$schema_root/$relative_path"
    [[ -f "$migration_file" ]] \
        || die "Foundation migration is missing: $relative_path"

    psql \
        -X \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --dbname="$test_database" \
        --file="$migration_file" \
        >"$temp_root/foundation-$foundation_count.log" 2>&1

    foundation_count=$((foundation_count + 1))
done <"$foundation_manifest"

if [[ "$foundation_count" == "34" ]]; then
    pass "Applied 34 Foundation migrations to the disposable cluster"
else
    fail "Applied 34 Foundation migrations to the disposable cluster"
fi

"$deployment_runner" "$test_database" \
    >"$temp_root/deployment-first.log" 2>&1
pass "Deployment role-topology migration applied"

"$deployment_runner" "$test_database" \
    >"$temp_root/deployment-second.log" 2>&1
pass "Exact deployment migration re-run was idempotent"

check_query_equal \
    "34" \
    "SELECT count(*) FROM foundation_meta.applied_migrations;" \
    "Foundation migration registry remains at 34"

check_query_equal \
    "1" \
    "SELECT count(*) FROM deployment_meta.applied_deployment_migrations;" \
    "Deployment migration registry contains one migration"

check_query_equal \
    "18" \
    "SELECT count(*) FROM deployment_meta.database_roles;" \
    "Deployment metadata contains 18 canonical roles"

check_query_equal \
    "18" \
    "SELECT count(*) FROM pg_roles WHERE rolname IN (SELECT role_name FROM deployment_meta.database_roles);" \
    "All 18 canonical roles exist in PostgreSQL"

check_query_equal \
    "0" \
    "SELECT count(*) FROM pg_roles WHERE rolname IN (SELECT role_name FROM deployment_meta.database_roles) AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls);" \
    "Canonical roles have no prohibited PostgreSQL attributes"

check_query_equal \
    "14" \
    "SELECT count(*) FROM pg_roles WHERE rolname IN (SELECT role_name FROM deployment_meta.database_roles) AND NOT rolcanlogin;" \
    "Fourteen owner, capability, review, and break-glass roles are NOLOGIN"

check_query_equal \
    "4" \
    "SELECT count(*) FROM pg_roles WHERE rolname IN (SELECT role_name FROM deployment_meta.database_roles) AND rolcanlogin;" \
    "Exactly four bounded roles can LOGIN"

check_query_equal \
    "0" \
    "SELECT count(*) FROM pg_authid WHERE rolname IN ('issp_migration_executor', 'issp_service_authorization', 'issp_service_integration_delivery', 'issp_service_monitoring_delivery') AND rolpassword IS NOT NULL;" \
    "Step 2 login roles have no repository-provisioned passwords"

check_query_equal \
    "2" \
    "SELECT rolconnlimit FROM pg_roles WHERE rolname = 'issp_migration_executor';" \
    "Migration executor connection limit is two"

check_query_equal \
    "20" \
    "SELECT rolconnlimit FROM pg_roles WHERE rolname = 'issp_service_authorization';" \
    "Authorization service connection limit is twenty"

check_query_equal \
    "10" \
    "SELECT rolconnlimit FROM pg_roles WHERE rolname = 'issp_service_integration_delivery';" \
    "Integration-delivery service connection limit is ten"

check_query_equal \
    "10" \
    "SELECT rolconnlimit FROM pg_roles WHERE rolname = 'issp_service_monitoring_delivery';" \
    "Monitoring-delivery service connection limit is ten"

check_query_equal \
    "9" \
    "SELECT count(*) FROM deployment_meta.database_role_memberships;" \
    "Deployment metadata contains nine bounded memberships"

check_query_equal \
    "9" \
    "SELECT count(*) FROM pg_auth_members AS membership JOIN pg_roles AS granted_role ON granted_role.oid = membership.roleid JOIN pg_roles AS member_role ON member_role.oid = membership.member JOIN deployment_meta.database_role_memberships AS expected ON expected.granted_role_name = granted_role.rolname AND expected.member_role_name = member_role.rolname WHERE membership.inherit_option AND NOT membership.set_option AND NOT membership.admin_option;" \
    "All nine memberships inherit capability without SET or ADMIN"

check_query_equal \
    "0" \
    "SELECT count(*) FROM pg_auth_members AS membership JOIN pg_roles AS granted_role ON granted_role.oid = membership.roleid JOIN pg_roles AS member_role ON member_role.oid = membership.member WHERE (granted_role.rolname IN (SELECT role_name FROM deployment_meta.database_roles) OR member_role.rolname IN (SELECT role_name FROM deployment_meta.database_roles)) AND NOT EXISTS (SELECT 1 FROM deployment_meta.database_role_memberships AS expected WHERE expected.granted_role_name = granted_role.rolname AND expected.member_role_name = member_role.rolname);" \
    "No unexpected canonical role memberships exist"

check_query_equal \
    "0" \
    "SELECT count(*) FROM pg_database WHERE datname = current_database() AND pg_get_userbyid(datdba) IN (SELECT role_name::text FROM deployment_meta.database_roles);" \
    "Step 2 transfers no database ownership"

check_query_equal \
    "0" \
    "SELECT count(*) FROM pg_namespace WHERE pg_get_userbyid(nspowner) IN (SELECT role_name::text FROM deployment_meta.database_roles);" \
    "Step 2 transfers no schema ownership"

check_query_equal \
    "0" \
    "SELECT count(*) FROM pg_class WHERE pg_get_userbyid(relowner) IN (SELECT role_name::text FROM deployment_meta.database_roles);" \
    "Step 2 transfers no relation ownership"

check_query_equal \
    "0" \
    "SELECT count(*) FROM pg_proc WHERE pg_get_userbyid(proowner) IN (SELECT role_name::text FROM deployment_meta.database_roles);" \
    "Step 2 transfers no routine ownership"

check_query_equal \
    "43" \
    "SELECT count(*) FROM foundation_meta.incompatible_database_role_classes WHERE created_by_reference = 'deployment:900_postgresql_role_topology_and_membership';" \
    "Forty-three prohibited role-class combinations are recorded"

psql \
    -X \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --dbname="$test_database" \
    --command='CREATE TABLE public.runtime_inheritance_probe (probe_id integer PRIMARY KEY); REVOKE ALL ON TABLE public.runtime_inheritance_probe FROM PUBLIC; GRANT SELECT ON TABLE public.runtime_inheritance_probe TO issp_runtime;' \
    >/dev/null

if psql \
    -X \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --username=issp_service_authorization \
    --dbname="$test_database" \
    --command='SELECT count(*) FROM public.runtime_inheritance_probe;' \
    >/dev/null 2>&1
then
    pass "Authorization service inherits issp_runtime capability"
else
    fail "Authorization service inherits issp_runtime capability"
fi

psql \
    -X \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --dbname="$test_database" \
    --command='DROP TABLE public.runtime_inheritance_probe;' \
    >/dev/null

expect_psql_failure \
    "issp_service_authorization" \
    "SET ROLE issp_runtime;" \
    "Authorization service cannot SET ROLE to issp_runtime"

expect_psql_failure \
    "issp_service_authorization" \
    "GRANT issp_runtime TO issp_service_authorization;" \
    "Authorization service cannot administer runtime membership"

expect_psql_failure \
    "issp_migration_executor" \
    "SET ROLE issp_foundation_owner;" \
    "Migration executor has no standing Foundation-owner transition"

if psql \
    -X \
    --no-psqlrc \
    --username=issp_break_glass \
    --dbname="$test_database" \
    --command='SELECT 1;' \
    >/dev/null 2>&1
then
    fail "Break-glass role cannot log in at rest"
else
    pass "Break-glass role cannot log in at rest"
fi

check_query_equal \
    "0" \
    "SELECT count(*) FROM pg_auth_members AS membership JOIN pg_roles AS granted_role ON granted_role.oid = membership.roleid JOIN pg_roles AS member_role ON member_role.oid = membership.member WHERE granted_role.rolname IN ('issp_database_owner', 'issp_foundation_owner', 'issp_extension_owner', 'issp_break_glass') OR member_role.rolname IN ('issp_database_owner', 'issp_foundation_owner', 'issp_extension_owner', 'issp_break_glass');" \
    "Owner and break-glass roles have no standing memberships"

check_query_equal \
    "0" \
    "SELECT count(*) FROM information_schema.role_table_grants WHERE grantee IN (SELECT role_name::text FROM deployment_meta.database_roles);" \
    "Step 2 grants no table privileges to canonical roles"

check_query_equal \
    "0" \
    "SELECT count(*) FROM information_schema.role_routine_grants WHERE grantee IN (SELECT role_name::text FROM deployment_meta.database_roles);" \
    "Step 2 grants no routine privileges to canonical roles"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
    exit 1
fi
