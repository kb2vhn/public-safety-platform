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

for command_name in initdb pg_ctl createdb psql; do
    require_command "$command_name"
done

if (( FAIL_COUNT != 0 )); then
    printf '\nDependency preflight failed.\n' >&2
    exit 1
fi

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase5-step5.XXXXXX")"
data_dir="$temp_root/data"
socket_dir="$temp_root/socket"
log_file="$temp_root/postgresql.log"
deployment_log="$temp_root/deployment.log"
port=55435
database_name="issp_phase5_step5_test"
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

cat >>"$data_dir/postgresql.conf" <<EOF
listen_addresses = ''
unix_socket_directories = '$socket_dir'
port = $port
fsync = off
synchronous_commit = off
full_page_writes = off
log_min_messages = warning
EOF

if pg_ctl -D "$data_dir" -l "$log_file" -w start >/dev/null 2>&1; then
    cluster_started=true
    pass "Disposable PostgreSQL cluster started"
else
    fail "Disposable PostgreSQL cluster started"
    cat "$log_file" >&2 2>/dev/null || true
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

# Preserve the exact accepted Step 5 deployment boundary. Later Phase 5
# migrations may be appended to the authoritative deployment manifest without
# changing this predecessor test.
step5_deployment_root="$temp_root/step5-deployment"

mkdir -p "$step5_deployment_root"
cp -R "$repo_root/sql/deployment/." "$step5_deployment_root/"

cat >"$step5_deployment_root/manifests/deployment.manifest" <<'MANIFEST'
migrations/900_postgresql_role_topology_and_membership.sql
migrations/910_database_schema_and_object_ownership.sql
migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql
migrations/930_investigator_audit_and_validation_review_surfaces.sql
MANIFEST

chmod +x "$step5_deployment_root/scripts/apply_deployment.sh"

if PGHOST="$socket_dir" \
    PGPORT="$port" \
    PGUSER=postgres \
    "$step5_deployment_root/scripts/apply_deployment.sh" \
    "$database_name" \
    >"$deployment_log" 2>&1; then
    pass "Applied deployment migrations through Step 5"
else
    fail "Applied deployment migrations through Step 5"
    cat "$deployment_log" >&2
fi

if PGHOST="$socket_dir" \
    PGPORT="$port" \
    PGUSER=postgres \
    "$step5_deployment_root/scripts/apply_deployment.sh" \
    "$database_name" \
    >>"$deployment_log" 2>&1; then
    pass "Deployment manifest reapplication is idempotent"
else
    fail "Deployment manifest reapplication is idempotent"
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

assert_succeeds_as_role() {
    local role_name="$1"
    local label="$2"
    local sql="$3"

    if "${psql_base[@]}" >/dev/null 2>&1 <<SQL
SET ROLE $role_name;
$sql
RESET ROLE;
SQL
    then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_fails_as_role() {
    local role_name="$1"
    local label="$2"
    local sql="$3"

    if "${psql_base[@]}" >/dev/null 2>&1 <<SQL
SET ROLE $role_name;
$sql
RESET ROLE;
SQL
    then
        fail "$label"
    else
        pass "$label"
    fi
}

printf '\n== Deployment and contract inventory ==\n'

assert_scalar \
    "Registered deployment migrations" \
    "4" \
    "SELECT count(*) FROM deployment_meta.applied_deployment_migrations;"

assert_scalar \
    "Review privilege contract rows" \
    "40" \
    "SELECT count(*) FROM deployment_meta.review_privilege_contract;"

assert_scalar \
    "Review privilege contract database rows" \
    "3" \
    "SELECT count(*) FROM deployment_meta.review_privilege_contract WHERE object_kind='DATABASE';"

assert_scalar \
    "Review privilege contract schema rows" \
    "4" \
    "SELECT count(*) FROM deployment_meta.review_privilege_contract WHERE object_kind='SCHEMA';"

assert_scalar \
    "Review privilege contract view rows" \
    "33" \
    "SELECT count(*) FROM deployment_meta.review_privilege_contract WHERE object_kind='VIEW';"

assert_scalar \
    "Reduced investigator contract rows" \
    "4" \
    "SELECT count(*) FROM deployment_meta.review_privilege_contract WHERE grantee_role_name='issp_read_only_investigator';"

assert_scalar \
    "Audit reader contract rows" \
    "10" \
    "SELECT count(*) FROM deployment_meta.review_privilege_contract WHERE grantee_role_name='issp_audit_reader';"

assert_scalar \
    "Validation reader contract rows" \
    "26" \
    "SELECT count(*) FROM deployment_meta.review_privilege_contract WHERE grantee_role_name='issp_validation_reader';"

assert_scalar \
    "security_review views" \
    "10" \
    "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='security_review' AND c.relkind='v';"

assert_scalar \
    "Step 5 deployment posture views" \
    "4" \
    "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='deployment_meta' AND c.relname IN ('deployment_migration_status','canonical_role_posture','canonical_membership_posture','review_privilege_contract_summary') AND c.relkind='v';"

printf '\n== Role and view security posture ==\n'

assert_scalar \
    "Review roles remain NOLOGIN and unprivileged" \
    "0" \
    "SELECT count(*) FROM pg_roles WHERE rolname IN ('issp_read_only_investigator','issp_audit_reader','issp_validation_reader') AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls);"

assert_scalar \
    "Review roles have no standing memberships" \
    "0" \
    "SELECT count(*) FROM pg_auth_members m JOIN pg_roles granted ON granted.oid=m.roleid JOIN pg_roles member ON member.oid=m.member WHERE granted.rolname IN ('issp_read_only_investigator','issp_audit_reader','issp_validation_reader') OR member.rolname IN ('issp_read_only_investigator','issp_audit_reader','issp_validation_reader');"

assert_scalar \
    "Approved review surfaces are security-barrier views" \
    "14" \
    "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE ((n.nspname='security_review') OR (n.nspname='deployment_meta' AND c.relname IN ('deployment_migration_status','canonical_role_posture','canonical_membership_posture','review_privilege_contract_summary'))) AND c.relkind='v' AND 'security_barrier=true'=ANY(COALESCE(c.reloptions,ARRAY[]::text[]));"

assert_scalar \
    "Review roles have no TEMPORARY privilege" \
    "0" \
    "SELECT count(*) FROM (VALUES ('issp_read_only_investigator'::name),('issp_audit_reader'::name),('issp_validation_reader'::name)) r(role_name) WHERE has_database_privilege(r.role_name,current_database(),'TEMPORARY');"

assert_scalar \
    "Review roles have no direct protected base-table privileges" \
    "0" \
    "SELECT count(*) FROM (VALUES ('issp_read_only_investigator'::name),('issp_audit_reader'::name),('issp_validation_reader'::name)) r(role_name) CROSS JOIN pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('deployment_meta','foundation_meta','trust','identity','organization','service','attestation','approval','access_control','decision','governance','compliance','risk','resilience','performance','observability','integration') AND c.relkind IN ('r','p','f') AND (has_table_privilege(r.role_name,c.oid,'SELECT') OR has_table_privilege(r.role_name,c.oid,'INSERT') OR has_table_privilege(r.role_name,c.oid,'UPDATE') OR has_table_privilege(r.role_name,c.oid,'DELETE') OR has_table_privilege(r.role_name,c.oid,'TRUNCATE'));"

assert_scalar \
    "Review roles have no protected sequence privileges" \
    "0" \
    "SELECT count(*) FROM (VALUES ('issp_read_only_investigator'::name),('issp_audit_reader'::name),('issp_validation_reader'::name)) r(role_name) CROSS JOIN pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='S' AND n.nspname IN ('deployment_meta','foundation_meta','trust','identity','organization','service','attestation','approval','access_control','decision','governance','compliance','risk','resilience','performance','observability','integration') AND (has_sequence_privilege(r.role_name,c.oid,'USAGE') OR has_sequence_privilege(r.role_name,c.oid,'SELECT') OR has_sequence_privilege(r.role_name,c.oid,'UPDATE'));"

assert_scalar \
    "Review roles have no protected routine execution" \
    "0" \
    "SELECT count(*) FROM (VALUES ('issp_read_only_investigator'::name),('issp_audit_reader'::name),('issp_validation_reader'::name)) r(role_name) CROSS JOIN pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('deployment_meta','foundation_meta','trust','identity','organization','service','attestation','approval','access_control','decision','governance','compliance','risk','resilience','performance','observability','integration') AND has_function_privilege(r.role_name,p.oid,'EXECUTE');"

assert_scalar \
    "PUBLIC cannot read Step 5 views" \
    "0" \
    "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE ((n.nspname='security_review') OR (n.nspname='deployment_meta' AND c.relname IN ('deployment_migration_status','canonical_role_posture','canonical_membership_posture','review_privilege_contract_summary'))) AND has_table_privilege('public',c.oid,'SELECT');"

printf '\n== Approved view access ==\n'

assert_succeeds_as_role \
    "issp_read_only_investigator" \
    "Investigator can read reduced Decision Record summary" \
    "SELECT count(*) FROM security_review.investigator_decision_summary;"

assert_succeeds_as_role \
    "issp_read_only_investigator" \
    "Investigator can read reduced Approval Request summary" \
    "SELECT count(*) FROM security_review.investigator_approval_summary;"

assert_succeeds_as_role \
    "issp_audit_reader" \
    "Audit reader can read Decision Record audit lineage" \
    "SELECT count(*) FROM security_review.audit_decision_records;"

assert_succeeds_as_role \
    "issp_audit_reader" \
    "Audit reader can read Approval Action audit lineage" \
    "SELECT count(*) FROM security_review.audit_approval_actions;"

assert_succeeds_as_role \
    "issp_audit_reader" \
    "Audit reader can read Authorization Lease use audit lineage" \
    "SELECT count(*) FROM security_review.audit_authorization_lease_events;"

assert_succeeds_as_role \
    "issp_validation_reader" \
    "Validation reader can read Foundation review posture" \
    "SELECT count(*) FROM security_validation.foundation_review_summary;"

assert_succeeds_as_role \
    "issp_validation_reader" \
    "Validation reader can read deployment migration posture" \
    "SELECT count(*) FROM deployment_meta.deployment_migration_status;"

assert_succeeds_as_role \
    "issp_validation_reader" \
    "Validation reader can read canonical role posture" \
    "SELECT count(*) FROM deployment_meta.canonical_role_posture;"

printf '\n== Cross-boundary and mutation denials ==\n'

assert_fails_as_role \
    "issp_read_only_investigator" \
    "Investigator cannot read audit-only Decision Record view" \
    "SELECT count(*) FROM security_review.audit_decision_records;"

assert_fails_as_role \
    "issp_audit_reader" \
    "Audit reader cannot read investigator-only summary" \
    "SELECT count(*) FROM security_review.investigator_decision_summary;"

assert_fails_as_role \
    "issp_validation_reader" \
    "Validation reader cannot read protected audit surfaces" \
    "SELECT count(*) FROM security_review.audit_approval_actions;"

assert_fails_as_role \
    "issp_service_authorization" \
    "Runtime authorization service cannot read review surfaces" \
    "SELECT count(*) FROM security_review.audit_decision_records;"

assert_fails_as_role \
    "issp_read_only_investigator" \
    "Investigator cannot read protected Decision Record base table" \
    "SELECT count(*) FROM decision.decision_records;"

assert_fails_as_role \
    "issp_audit_reader" \
    "Audit reader cannot read protected Approval Action base table" \
    "SELECT count(*) FROM approval.approval_actions;"

assert_fails_as_role \
    "issp_validation_reader" \
    "Validation reader cannot read Foundation migration base table" \
    "SELECT count(*) FROM foundation_meta.applied_migrations;"

assert_fails_as_role \
    "issp_read_only_investigator" \
    "Investigator cannot create temporary tables" \
    "CREATE TEMP TABLE issp_step5_investigator_denied(id integer);"

assert_fails_as_role \
    "issp_audit_reader" \
    "Audit reader cannot create temporary tables" \
    "CREATE TEMP TABLE issp_step5_audit_denied(id integer);"

assert_fails_as_role \
    "issp_validation_reader" \
    "Validation reader cannot create temporary tables" \
    "CREATE TEMP TABLE issp_step5_validation_denied(id integer);"

assert_scalar \
    "Review roles cannot execute Approval finalization" \
    "0" \
    "SELECT count(*) FROM (VALUES ('issp_read_only_investigator'::name),('issp_audit_reader'::name),('issp_validation_reader'::name)) r(role_name) WHERE has_function_privilege(r.role_name,'approval.finalize_approval_request(uuid,text,uuid)'::regprocedure,'EXECUTE');"

assert_scalar \
    "Review roles cannot write any approved view" \
    "0" \
    "SELECT count(*) FROM deployment_meta.review_privilege_contract c WHERE c.object_kind='VIEW' AND (has_table_privilege(c.grantee_role_name,to_regclass(c.object_identity),'INSERT') OR has_table_privilege(c.grantee_role_name,to_regclass(c.object_identity),'UPDATE') OR has_table_privilege(c.grantee_role_name,to_regclass(c.object_identity),'DELETE') OR has_table_privilege(c.grantee_role_name,to_regclass(c.object_identity),'TRUNCATE'));"

printf '\n== Disposable-cluster final result ==\n'
printf 'PASS checks: %s\n' "$PASS_COUNT"
printf 'FAIL checks: %s\n' "$FAIL_COUNT"

if (( FAIL_COUNT == 0 )); then
    printf '\nPhase 5 Step 5 disposable-cluster validation PASSED.\n'
    printf 'Investigator, audit-reader, and validation-reader access is restricted to exact approved views.\n'
    exit 0
fi

printf '\nPhase 5 Step 5 disposable-cluster validation FAILED.\n' >&2
exit 1
