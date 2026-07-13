#!/usr/bin/env bash
#
# Iron Signal Platform
# Phase 5 Step 3 disposable-cluster ownership and default-privilege test

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

die() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 \
        || die "Required command is unavailable: $1"
}

for command_name in \
    initdb pg_ctl createdb psql pg_config sha256sum awk sed grep
do
    require_command "$command_name"
done

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || die "Run this test from inside the Iron Signal Platform repository."

cd "$repo_root"

foundation_manifest="sql/schema/manifests/foundation.manifest"
deployment_manifest="sql/deployment/manifests/deployment.manifest"
deployment_runner="sql/deployment/scripts/apply_deployment.sh"

[[ -f "$foundation_manifest" ]] || die "Missing $foundation_manifest"
[[ -f "$deployment_manifest" ]] || die "Missing $deployment_manifest"
[[ -x "$deployment_runner" ]] || die "Not executable: $deployment_runner"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase5-step3.XXXXXXXX")"
data_dir="$temp_root/data"
socket_dir="$temp_root/socket"
log_file="$temp_root/postgresql.log"
database_name="issp_phase5_step3_test"
bootstrap_role="issp_step3_bootstrap"
port="$((55000 + (RANDOM % 800)))"
cluster_started=false

mkdir -p "$socket_dir"

cleanup() {
    local cleanup_status=$?

    if $cluster_started; then
        pg_ctl \
            --pgdata="$data_dir" \
            --mode=fast \
            --wait \
            stop \
            >/dev/null 2>&1 || true
    fi

    rm -rf "$temp_root"
    exit "$cleanup_status"
}
trap cleanup EXIT INT TERM

initdb \
    --pgdata="$data_dir" \
    --username="$bootstrap_role" \
    --auth=trust \
    --encoding=UTF8 \
    --no-locale \
    >/dev/null

cat >>"$data_dir/postgresql.conf" <<EOF
listen_addresses = ''
unix_socket_directories = '$socket_dir'
port = $port
max_connections = 30
fsync = off
synchronous_commit = off
full_page_writes = off
EOF

pg_ctl \
    --pgdata="$data_dir" \
    --log="$log_file" \
    --wait \
    start \
    >/dev/null

cluster_started=true

export PGHOST="$socket_dir"
export PGPORT="$port"
export PGUSER="$bootstrap_role"
export PGDATABASE="$database_name"

createdb \
    --template=template0 \
    "$database_name"

printf '\n== Applying accepted Foundation migrations ==\n'

foundation_count=0
while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    [[ "$relative_path" =~ ^[[:space:]]*# ]] && continue

    migration_file="sql/schema/$relative_path"
    [[ -f "$migration_file" ]] \
        || die "Foundation migration is missing: $migration_file"

    psql \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --file="$migration_file" \
        >/dev/null

    foundation_count=$((foundation_count + 1))
done <"$foundation_manifest"

if [[ "$foundation_count" -eq 34 ]]; then
    pass "Applied 34 accepted Foundation migrations"
else
    fail "Applied 34 accepted Foundation migrations"
fi

printf '\n== Applying Phase 5 deployment manifest ==\n'

"$deployment_runner" "$database_name" >/dev/null
"$deployment_runner" "$database_name" >/dev/null

sql_scalar() {
    psql \
        --no-psqlrc \
        --tuples-only \
        --no-align \
        --set=ON_ERROR_STOP=1 \
        --command="$1" \
        | sed '/^[[:space:]]*$/d' \
        | tail -n 1
}

assert_equal() {
    local label="$1"
    local expected="$2"
    local query="$3"
    local actual

    actual="$(sql_scalar "$query")"

    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label (expected=$expected actual=$actual)"
    fi
}

assert_zero() {
    assert_equal "$1" "0" "$2"
}

assert_equal \
    "Deployment registry contains migrations 900 and 910 exactly once" \
    "2" \
    "SELECT count(*) FROM deployment_meta.applied_deployment_migrations;"

assert_equal \
    "Current database is owned by issp_database_owner" \
    "issp_database_owner" \
    "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = current_database();"

assert_zero \
    "All protected schemas have the expected owner" \
    "SELECT count(*)
       FROM (
           VALUES
               ('extensions'::text, 'issp_extension_owner'::text),
               ('deployment_meta'::text, 'issp_database_owner'::text),
               ('foundation_meta'::text, 'issp_foundation_owner'::text),
               ('trust'::text, 'issp_foundation_owner'::text),
               ('identity'::text, 'issp_foundation_owner'::text),
               ('organization'::text, 'issp_foundation_owner'::text),
               ('service'::text, 'issp_foundation_owner'::text),
               ('attestation'::text, 'issp_foundation_owner'::text),
               ('approval'::text, 'issp_foundation_owner'::text),
               ('access_control'::text, 'issp_foundation_owner'::text),
               ('decision'::text, 'issp_foundation_owner'::text),
               ('governance'::text, 'issp_foundation_owner'::text),
               ('compliance'::text, 'issp_foundation_owner'::text),
               ('risk'::text, 'issp_foundation_owner'::text),
               ('resilience'::text, 'issp_foundation_owner'::text),
               ('performance'::text, 'issp_foundation_owner'::text),
               ('observability'::text, 'issp_foundation_owner'::text),
               ('integration'::text, 'issp_foundation_owner'::text),
               ('security_validation'::text, 'issp_foundation_owner'::text)
       ) AS expected(schema_name, owner_name)
       LEFT JOIN pg_namespace AS actual
         ON actual.nspname = expected.schema_name
      WHERE actual.oid IS NULL
         OR pg_get_userbyid(actual.nspowner) <> expected.owner_name;"

assert_zero \
    "All protected relations have the expected owner" \
    "SELECT count(*)
       FROM pg_class AS relation_record
       JOIN pg_namespace AS namespace_record
         ON namespace_record.oid = relation_record.relnamespace
      WHERE relation_record.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
        AND namespace_record.nspname IN (
            'extensions', 'deployment_meta', 'foundation_meta', 'trust',
            'identity', 'organization', 'service', 'attestation', 'approval',
            'access_control', 'decision', 'governance', 'compliance', 'risk',
            'resilience', 'performance', 'observability', 'integration',
            'security_validation'
        )
        AND pg_get_userbyid(relation_record.relowner) <>
            CASE
                WHEN namespace_record.nspname = 'extensions'
                    THEN 'issp_extension_owner'
                WHEN namespace_record.nspname = 'deployment_meta'
                    THEN 'issp_database_owner'
                ELSE 'issp_foundation_owner'
            END;"

assert_zero \
    "All protected routines have the expected owner" \
    "SELECT count(*)
       FROM pg_proc AS routine_record
       JOIN pg_namespace AS namespace_record
         ON namespace_record.oid = routine_record.pronamespace
      WHERE namespace_record.nspname IN (
            'extensions', 'deployment_meta', 'foundation_meta', 'trust',
            'identity', 'organization', 'service', 'attestation', 'approval',
            'access_control', 'decision', 'governance', 'compliance', 'risk',
            'resilience', 'performance', 'observability', 'integration',
            'security_validation'
        )
        AND pg_get_userbyid(routine_record.proowner) <>
            CASE
                WHEN namespace_record.nspname = 'extensions'
                    THEN 'issp_extension_owner'
                WHEN namespace_record.nspname = 'deployment_meta'
                    THEN 'issp_database_owner'
                ELSE 'issp_foundation_owner'
            END;"

assert_zero \
    "All protected standalone types have the expected owner" \
    "SELECT count(*)
       FROM pg_type AS type_record
       JOIN pg_namespace AS namespace_record
         ON namespace_record.oid = type_record.typnamespace
      WHERE type_record.typrelid = 0
        AND type_record.typelem = 0
        AND type_record.typtype IN ('b', 'c', 'd', 'e', 'm', 'r')
        AND namespace_record.nspname IN (
            'extensions', 'deployment_meta', 'foundation_meta', 'trust',
            'identity', 'organization', 'service', 'attestation', 'approval',
            'access_control', 'decision', 'governance', 'compliance', 'risk',
            'resilience', 'performance', 'observability', 'integration',
            'security_validation'
        )
        AND pg_get_userbyid(type_record.typowner) <>
            CASE
                WHEN namespace_record.nspname = 'extensions'
                    THEN 'issp_extension_owner'
                WHEN namespace_record.nspname = 'deployment_meta'
                    THEN 'issp_database_owner'
                ELSE 'issp_foundation_owner'
            END;"

assert_zero \
    "No login-capable role owns a protected schema" \
    "SELECT count(*)
       FROM pg_namespace AS namespace_record
       JOIN pg_roles AS owner_role
         ON owner_role.oid = namespace_record.nspowner
      WHERE owner_role.rolcanlogin
        AND namespace_record.nspname IN (
            'extensions', 'deployment_meta', 'foundation_meta', 'trust',
            'identity', 'organization', 'service', 'attestation', 'approval',
            'access_control', 'decision', 'governance', 'compliance', 'risk',
            'resilience', 'performance', 'observability', 'integration',
            'security_validation'
        );"

assert_zero \
    "No login-capable role owns a protected relation" \
    "SELECT count(*)
       FROM pg_class AS relation_record
       JOIN pg_namespace AS namespace_record
         ON namespace_record.oid = relation_record.relnamespace
       JOIN pg_roles AS owner_role
         ON owner_role.oid = relation_record.relowner
      WHERE owner_role.rolcanlogin
        AND relation_record.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
        AND namespace_record.nspname IN (
            'extensions', 'deployment_meta', 'foundation_meta', 'trust',
            'identity', 'organization', 'service', 'attestation', 'approval',
            'access_control', 'decision', 'governance', 'compliance', 'risk',
            'resilience', 'performance', 'observability', 'integration',
            'security_validation'
        );"

assert_zero \
    "No login-capable role owns a protected routine" \
    "SELECT count(*)
       FROM pg_proc AS routine_record
       JOIN pg_namespace AS namespace_record
         ON namespace_record.oid = routine_record.pronamespace
       JOIN pg_roles AS owner_role
         ON owner_role.oid = routine_record.proowner
      WHERE owner_role.rolcanlogin
        AND namespace_record.nspname IN (
            'extensions', 'deployment_meta', 'foundation_meta', 'trust',
            'identity', 'organization', 'service', 'attestation', 'approval',
            'access_control', 'decision', 'governance', 'compliance', 'risk',
            'resilience', 'performance', 'observability', 'integration',
            'security_validation'
        );"

assert_equal \
    "PUBLIC cannot CONNECT to the database" \
    "f" \
    "SELECT has_database_privilege('public', current_database(), 'CONNECT');"

assert_equal \
    "PUBLIC cannot create temporary objects in the database" \
    "f" \
    "SELECT has_database_privilege('public', current_database(), 'TEMPORARY');"

assert_zero \
    "PUBLIC has no protected schema privileges" \
    "SELECT count(*)
       FROM pg_namespace AS namespace_record
      WHERE namespace_record.nspname IN (
            'extensions', 'deployment_meta', 'foundation_meta', 'trust',
            'identity', 'organization', 'service', 'attestation', 'approval',
            'access_control', 'decision', 'governance', 'compliance', 'risk',
            'resilience', 'performance', 'observability', 'integration',
            'security_validation'
        )
        AND (
            has_schema_privilege('public', namespace_record.oid, 'USAGE')
            OR has_schema_privilege('public', namespace_record.oid, 'CREATE')
        );"

assert_equal \
    "pgcrypto extension-owner limitation is recorded exactly once" \
    "1" \
    "SELECT count(*)
       FROM deployment_meta.ownership_exceptions
      WHERE object_type = 'EXTENSION_CATALOG_OWNER'
        AND object_identity = 'pgcrypto'
        AND intended_owner_role = 'issp_extension_owner'
        AND review_required_before_production;"

assert_equal \
    "pgcrypto extension catalog owner remains the controlled bootstrap role" \
    "$bootstrap_role" \
    "SELECT pg_get_userbyid(extowner)
       FROM pg_extension
      WHERE extname = 'pgcrypto';"

assert_zero \
    "Owner roles remain NOLOGIN" \
    "SELECT count(*)
       FROM pg_roles
      WHERE rolname IN (
            'issp_database_owner',
            'issp_foundation_owner',
            'issp_extension_owner'
        )
        AND rolcanlogin;"

assert_zero \
    "Canonical runtime and service roles have no direct database privileges" \
    "SELECT count(*)
       FROM deployment_meta.database_roles AS canonical_role
      WHERE (
            canonical_role.role_class_key IN (
                'runtime_capability',
                'controlled_writer',
                'service_login',
                'read_only_investigator',
                'audit_reader',
                'validation_reader',
                'break_glass'
            )
        )
        AND (
            has_database_privilege(
                canonical_role.role_name,
                current_database(),
                'CONNECT'
            )
            OR has_database_privilege(
                canonical_role.role_name,
                current_database(),
                'CREATE'
            )
            OR has_database_privilege(
                canonical_role.role_name,
                current_database(),
                'TEMPORARY'
            )
        );"

printf '\n== Creator-specific default privilege probes ==\n'

psql \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    >/dev/null <<'SQL'
SET ROLE issp_foundation_owner;

CREATE FUNCTION foundation_meta.phase5_step3_function_probe()
RETURNS integer
LANGUAGE sql
AS 'SELECT 1';

CREATE TABLE foundation_meta.phase5_step3_table_probe (
    probe_id integer PRIMARY KEY
);

CREATE TYPE foundation_meta.phase5_step3_type_probe
AS ENUM ('PROBE');

RESET ROLE;

SET ROLE issp_extension_owner;

CREATE FUNCTION extensions.phase5_step3_extension_probe()
RETURNS integer
LANGUAGE sql
AS 'SELECT 1';

RESET ROLE;

SET ROLE issp_database_owner;

CREATE FUNCTION deployment_meta.phase5_step3_deployment_probe()
RETURNS integer
LANGUAGE sql
AS 'SELECT 1';

RESET ROLE;
SQL

assert_equal \
    "PUBLIC cannot execute a new Foundation-owner routine" \
    "f" \
    "SELECT has_function_privilege(
        'public',
        'foundation_meta.phase5_step3_function_probe()',
        'EXECUTE'
    );"

assert_equal \
    "PUBLIC cannot read a new Foundation-owner table" \
    "f" \
    "SELECT has_table_privilege(
        'public',
        'foundation_meta.phase5_step3_table_probe',
        'SELECT'
    );"

assert_equal \
    "PUBLIC cannot use a new Foundation-owner type" \
    "f" \
    "SELECT has_type_privilege(
        'public',
        'foundation_meta.phase5_step3_type_probe',
        'USAGE'
    );"

assert_equal \
    "PUBLIC cannot execute a new Extension-owner routine" \
    "f" \
    "SELECT has_function_privilege(
        'public',
        'extensions.phase5_step3_extension_probe()',
        'EXECUTE'
    );"

assert_equal \
    "PUBLIC cannot execute a new Database-owner routine" \
    "f" \
    "SELECT has_function_privilege(
        'public',
        'deployment_meta.phase5_step3_deployment_probe()',
        'EXECUTE'
    );"

assert_equal \
    "Foundation probe routine is owned by issp_foundation_owner" \
    "issp_foundation_owner" \
    "SELECT pg_get_userbyid(proowner)
       FROM pg_proc
      WHERE oid =
        'foundation_meta.phase5_step3_function_probe()'::regprocedure;"

assert_equal \
    "Extension probe routine is owned by issp_extension_owner" \
    "issp_extension_owner" \
    "SELECT pg_get_userbyid(proowner)
       FROM pg_proc
      WHERE oid =
        'extensions.phase5_step3_extension_probe()'::regprocedure;"

assert_equal \
    "Deployment probe routine is owned by issp_database_owner" \
    "issp_database_owner" \
    "SELECT pg_get_userbyid(proowner)
       FROM pg_proc
      WHERE oid =
        'deployment_meta.phase5_step3_deployment_probe()'::regprocedure;"

psql \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    >/dev/null <<'SQL'
DROP FUNCTION deployment_meta.phase5_step3_deployment_probe();
DROP FUNCTION extensions.phase5_step3_extension_probe();
DROP TABLE foundation_meta.phase5_step3_table_probe;
DROP TYPE foundation_meta.phase5_step3_type_probe;
DROP FUNCTION foundation_meta.phase5_step3_function_probe();
SQL

assert_zero \
    "No unexpected owner-role memberships were introduced" \
    "SELECT count(*)
       FROM pg_auth_members AS membership_record
       JOIN pg_roles AS granted_role
         ON granted_role.oid = membership_record.roleid
       JOIN pg_roles AS member_role
         ON member_role.oid = membership_record.member
      WHERE granted_role.rolname IN (
            'issp_database_owner',
            'issp_foundation_owner',
            'issp_extension_owner'
        )
         OR member_role.rolname IN (
            'issp_database_owner',
            'issp_foundation_owner',
            'issp_extension_owner'
        );"

echo
echo "== Final result =="
echo "PASS checks: $PASS_COUNT"
echo "FAIL checks: $FAIL_COUNT"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
    echo
    echo "Phase 5 Step 3 disposable-cluster validation FAILED."
    exit 1
fi

echo
echo "Phase 5 Step 3 disposable-cluster validation PASSED."
echo "Protected ownership and creator-specific default privileges are enforced."
