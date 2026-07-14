#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
repo_root="$(cd -- "$module_root/../.." && pwd -P)"
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

required_commands=(
    go pg_config python3 grep chmod mktemp kill seq sleep cat awk sed sort
)
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
    || fail "Disposable adapter runtime uses PostgreSQL 18"
pass "Disposable adapter runtime uses PostgreSQL 18"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step5-runtime.XXXXXX")"
pgdata="$scratch/pgdata"
socket_dir="$scratch/socket"
postgres_log="$scratch/postgresql.log"
database_name="issp_phase6_step5"
mkdir -p "$socket_dir"

pick_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}

postgres_port="$(pick_port)"
postgres_started=false
cleanup() {
    if $postgres_started; then
        "$postgres_bindir/pg_ctl" \
            -D "$pgdata" \
            -m immediate stop >/dev/null 2>&1 || true
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
    "$postgres_bindir/psql"
    -X
    --no-psqlrc
    --set=ON_ERROR_STOP=1
    -h "$socket_dir"
    -p "$postgres_port"
    -U postgres
)

"${psql_super[@]}" -d postgres \
    -c "CREATE DATABASE $database_name" >/dev/null
pass "Disposable Step 5 database created"

foundation_log="$scratch/foundation-apply.log"
deployment_log="$scratch/deployment-apply.log"
(
    cd "$repo_root"
    bash sql/schema/scripts/apply_foundation.sh "$database_name"
) >"$foundation_log" 2>&1
pass "Accepted Foundation migrations applied"

(
    cd "$repo_root"
    bash sql/deployment/scripts/apply_deployment.sh "$database_name"
) >"$deployment_log" 2>&1
pass "Accepted Phase 5 deployment boundary applied"

"${psql_super[@]}" -d "$database_name" <<'SQL' >/dev/null
SET password_encryption = 'scram-sha-256';
ALTER ROLE issp_service_authorization PASSWORD 'Step5Validation2026';
ALTER ROLE issp_service_integration_delivery PASSWORD 'Step5Validation2026';
ALTER ROLE issp_service_monitoring_delivery PASSWORD 'Step5Validation2026';
SQL
pass "Disposable service credentials provisioned outside repository SQL"

fixture_file="$module_root/testdata/phase6-step5/authorization-policy-binding-fixtures.sql"
mapfile -t fixture_lines < <(
    "${psql_super[@]}" \
        -qAt \
        -d "$database_name" \
        -f "$fixture_file"
)

declare -A fixture_ids=()
for fixture_line in "${fixture_lines[@]}"; do
    [[ "$fixture_line" == *'|'* ]] || continue
    fixture_key="${fixture_line%%|*}"
    fixture_id="${fixture_line#*|}"
    fixture_ids["$fixture_key"]="$fixture_id"
done

for fixture_key in \
    selected missing_policy ambiguous_policy mismatch concurrent nonexistent
do
    [[ -n "${fixture_ids[$fixture_key]:-}" ]] \
        || fail "Runtime fixture created: $fixture_key"
    pass "Runtime fixture created: $fixture_key"
done

foundation_dsn="$scratch/foundation-api.url"
printf 'postgresql://%s:%s@127.0.0.1:%s/%s?sslmode=disable\n' \
    'issp_service_authorization' \
    'Step5Validation2026' \
    "$postgres_port" \
    "$database_name" >"$foundation_dsn"
chmod 0600 "$foundation_dsn"

cd "$module_root"
export GOTOOLCHAIN=local
export GOFLAGS='-mod=readonly'
adapter_test_log="$scratch/foundation-adapter-test.log"

ISSP_TEST_DATABASE_DSN_FILE="$foundation_dsn" \
ISSP_TEST_SELECTED_DECISION_ID="${fixture_ids[selected]}" \
ISSP_TEST_MISSING_POLICY_DECISION_ID="${fixture_ids[missing_policy]}" \
ISSP_TEST_AMBIGUOUS_POLICY_DECISION_ID="${fixture_ids[ambiguous_policy]}" \
ISSP_TEST_MISMATCH_DECISION_ID="${fixture_ids[mismatch]}" \
ISSP_TEST_CONCURRENT_DECISION_ID="${fixture_ids[concurrent]}" \
ISSP_TEST_NONEXISTENT_DECISION_ID="${fixture_ids[nonexistent]}" \
    go test \
        -tags=integration \
        -run '^TestIntegrationAuthorizationPolicyBinding$' \
        ./internal/foundation >"$adapter_test_log" 2>&1
pass "Typed Foundation adapter integration and concurrency tests pass"

privilege_posture="$(
    "${psql_super[@]}" -qAt -d "$database_name" -c "
        SELECT
            has_function_privilege(
                'issp_service_authorization',
                'decision.bind_authorization_policy(uuid)',
                'EXECUTE'
            )::integer || '|' ||
            has_function_privilege(
                'issp_service_integration_delivery',
                'decision.bind_authorization_policy(uuid)',
                'EXECUTE'
            )::integer || '|' ||
            has_function_privilege(
                'issp_service_monitoring_delivery',
                'decision.bind_authorization_policy(uuid)',
                'EXECUTE'
            )::integer || '|' ||
            (
                has_table_privilege(
                    'issp_service_authorization',
                    'decision.decision_records',
                    'SELECT'
                ) OR
                has_table_privilege(
                    'issp_service_authorization',
                    'decision.decision_records',
                    'INSERT'
                ) OR
                has_table_privilege(
                    'issp_service_authorization',
                    'decision.decision_records',
                    'UPDATE'
                ) OR
                has_table_privilege(
                    'issp_service_authorization',
                    'decision.decision_records',
                    'DELETE'
                )
            )::integer;
    "
)"
[[ "$privilege_posture" == '1|0|0|0' ]] \
    || fail "Exact routine privilege and no direct table privilege posture"
pass "Exact routine privilege and no direct table privilege posture"

wrong_role_log="$scratch/wrong-role.log"
set +e
PGPASSWORD='Step5Validation2026' \
    "$postgres_bindir/psql" \
        -X \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --set=VERBOSITY=verbose \
        -h 127.0.0.1 \
        -p "$postgres_port" \
        -U issp_service_integration_delivery \
        -d "$database_name" \
        -c "SELECT decision.bind_authorization_policy('${fixture_ids[selected]}'::uuid);" \
        >"$wrong_role_log" 2>&1
wrong_role_rc=$?
set -e
[[ "$wrong_role_rc" -ne 0 ]] \
    || fail "Integration-delivery identity cannot invoke authorization adapter routine"
pass "Integration-delivery identity cannot invoke authorization adapter routine"

"${psql_super[@]}" -d "$database_name" <<'SQL' >/dev/null
DO $verify_step5_results$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM step5_test.fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'selected'
          AND decision_record.record_status = 'DRAFT'
          AND decision_record.authorization_policy_version_id IS NOT NULL
          AND decision_record.final_result IS NULL
          AND decision_record.primary_reason_code IS NULL
    ) THEN
        RAISE EXCEPTION 'selected fixture did not preserve the expected Decision Record state';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM step5_test.fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'missing_policy'
          AND decision_record.record_status = 'FINALIZED'
          AND decision_record.final_result = 'DENY'
          AND decision_record.primary_reason_code = 'AUTHORIZATION_POLICY_NOT_FOUND'
    ) THEN
        RAISE EXCEPTION 'missing-policy fixture did not persist the expected reason';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM step5_test.fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'ambiguous_policy'
          AND decision_record.record_status = 'FINALIZED'
          AND decision_record.final_result = 'DENY'
          AND decision_record.primary_reason_code = 'AUTHORIZATION_POLICY_AMBIGUOUS'
    ) THEN
        RAISE EXCEPTION 'ambiguous-policy fixture did not persist the expected reason';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM step5_test.fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'mismatch'
          AND decision_record.record_status = 'FINALIZED'
          AND decision_record.final_result = 'DENY'
          AND decision_record.primary_reason_code = 'AUTHORIZATION_POLICY_CONTEXT_MISMATCH'
    ) THEN
        RAISE EXCEPTION 'mismatch fixture did not persist the expected reason';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM step5_test.fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'concurrent'
          AND decision_record.record_status = 'DRAFT'
          AND decision_record.authorization_policy_version_id IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'concurrent fixture did not bind exactly one policy';
    END IF;
END;
$verify_step5_results$;
SQL
pass "Decision Record state and stable reason codes persist exactly"

if grep -R -Fq --include='*.log' 'Step5Validation2026' "$scratch" \
    || grep -R -Fq --include='*.log' 'postgresql://' "$scratch"
then
    fail "Step 5 runtime logs contain no database secret"
fi
pass "Step 5 runtime logs contain no database secret"

printf '\nPhase 6 Step 5 adapter runtime: %d PASS, 0 FAIL\n' "$pass_count"
