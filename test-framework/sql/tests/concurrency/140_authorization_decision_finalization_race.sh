#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

test_file="140_authorization_decision_finalization_race.sh"
test_database="${ISSP_TEST_DATABASE:-}"
test_run_id="${ISSP_TEST_RUN_ID:-concurrency_$$}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
support_sql="${script_dir}/support/phase3_authorization_concurrency_fixture.sql"

if [[ -z "$test_database" ]]; then
    printf 'ISSP_TEST_DATABASE is required\n' >&2
    exit 64
fi

for command_name in cat dirname grep mktemp psql rm sed sleep tail; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 69
    fi
done

if [[ ! -f "$support_sql" ]]; then
    printf 'Required support SQL not found: %s\n' "$support_sql" >&2
    exit 66
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/psp-authz-finalization-race.XXXXXX")"
controller_log="${work_dir}/controller.log"
worker_one_log="${work_dir}/worker_one.log"
worker_two_log="${work_dir}/worker_two.log"

cleanup() {
    rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

printf 'CONCURRENCY TEST FILE | %s\n' "$test_file"

fixture_row="$(
    {
        cat "$support_sql"
        cat <<'SQL'
SELECT sql_test.create_phase3_step4_fixture(
    'step6_finalization_source',
    'REUSABLE',
    NULL
) AS source_decision_id \gset

SELECT
    pg_catalog.gen_random_uuid() AS race_decision_id,
    pg_catalog.gen_random_uuid() AS required_evaluation_id,
    pg_catalog.gen_random_uuid() AS optional_evaluation_id
\gset

INSERT INTO decision.decision_records (
    decision_id, request_id, correlation_id, decision_class,
    requester_identity_id, requester_organization_id, session_id,
    device_id, service_id, purpose_definition_id,
    operation_definition_id, operation_key, protected_target_type,
    protected_target_reference, governed_scope_id, classification_key,
    requested_at, evaluated_at, evaluator_name, evaluator_version,
    database_schema_version, requested_lease_lifetime,
    requested_use_mode, requested_usage_limit, lease_audience,
    authorization_policy_version_id
)
SELECT
    :'race_decision_id'::uuid,
    pg_catalog.gen_random_uuid(),
    pg_catalog.gen_random_uuid(),
    source.decision_class,
    source.requester_identity_id,
    source.requester_organization_id,
    source.session_id,
    source.device_id,
    source.service_id,
    source.purpose_definition_id,
    source.operation_definition_id,
    source.operation_key,
    source.protected_target_type,
    source.protected_target_reference,
    source.governed_scope_id,
    source.classification_key,
    pg_catalog.statement_timestamp(),
    pg_catalog.statement_timestamp(),
    'sql_test.phase3_step6_finalization_race',
    '1',
    '081-step6',
    source.requested_lease_lifetime,
    source.requested_use_mode,
    source.requested_usage_limit,
    source.lease_audience,
    source.authorization_policy_version_id
FROM decision.decision_records AS source
WHERE source.decision_id = :'source_decision_id'::uuid;

INSERT INTO decision.evaluation_records (
    evaluation_id, decision_id, evaluation_order, evaluation_key,
    required, result, reason_code, evaluated_at,
    authorization_policy_version_id,
    authorization_policy_stage_requirement_id
)
SELECT
    :'required_evaluation_id'::uuid,
    :'race_decision_id'::uuid,
    source.evaluation_order,
    source.evaluation_key,
    source.required,
    source.result,
    source.reason_code,
    pg_catalog.statement_timestamp(),
    source.authorization_policy_version_id,
    source.authorization_policy_stage_requirement_id
FROM decision.evaluation_records AS source
WHERE source.decision_id = :'source_decision_id'::uuid
  AND source.evaluation_key = 'REQUEST_CONTEXT';

INSERT INTO decision.supporting_records (
    evaluation_id, record_type, record_id, record_version,
    required_for_result
)
SELECT
    :'required_evaluation_id'::uuid,
    source.record_type,
    'step6-finalization-race',
    source.record_version,
    source.required_for_result
FROM decision.supporting_records AS source
JOIN decision.evaluation_records AS source_evaluation
  ON source_evaluation.evaluation_id = source.evaluation_id
WHERE source_evaluation.decision_id = :'source_decision_id'::uuid
  AND source_evaluation.evaluation_key = 'REQUEST_CONTEXT';

INSERT INTO decision.evaluation_records (
    evaluation_id, decision_id, evaluation_order, evaluation_key,
    required, result, reason_code, evaluated_at,
    authorization_policy_version_id,
    authorization_policy_stage_requirement_id,
    policy_rule_reference
)
SELECT
    :'optional_evaluation_id'::uuid,
    :'race_decision_id'::uuid,
    source.evaluation_order,
    source.evaluation_key,
    source.required,
    source.result,
    source.reason_code,
    pg_catalog.statement_timestamp(),
    source.authorization_policy_version_id,
    source.authorization_policy_stage_requirement_id,
    source.policy_rule_reference
FROM decision.evaluation_records AS source
WHERE source.decision_id = :'source_decision_id'::uuid
  AND source.evaluation_key = 'APPROVAL';

SELECT :'race_decision_id';
SQL
    } | psql \
        -X \
        --no-psqlrc \
        --quiet \
        --tuples-only \
        --no-align \
        --set=ON_ERROR_STOP=1 \
        --dbname="$test_database"
)"

decision_id="$(printf '%s\n' "$fixture_row" | sed -n '$p')"
if [[ -z "$decision_id" ]]; then
    printf 'Could not create finalization race fixture\n' >&2
    exit 65
fi

barrier_id="${test_run_id}_authorization_finalization_${decision_id}"
lock_key=703140

psql \
    -X \
    --no-psqlrc \
    --quiet \
    --set=ON_ERROR_STOP=1 \
    --set=barrier_id="$barrier_id" \
    --dbname="$test_database" <<'SQL'
CREATE TABLE IF NOT EXISTS sql_test.concurrency_barriers (
    barrier_id text PRIMARY KEY,
    controller_locked boolean NOT NULL DEFAULT false,
    created_at timestamp with time zone NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS sql_test.concurrency_readiness (
    barrier_id text NOT NULL,
    worker_name text NOT NULL,
    ready_at timestamp with time zone NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (barrier_id, worker_name),
    FOREIGN KEY (barrier_id)
        REFERENCES sql_test.concurrency_barriers (barrier_id)
        ON DELETE CASCADE
);

INSERT INTO sql_test.concurrency_barriers (barrier_id)
VALUES (:'barrier_id');
SQL

psql \
    -X \
    --no-psqlrc \
    --quiet \
    --set=ON_ERROR_STOP=1 \
    --set=VERBOSITY=verbose \
    --set=barrier_id="$barrier_id" \
    --set=lock_key="$lock_key" \
    --dbname="$test_database" >"$controller_log" 2>&1 <<'SQL' &
SELECT pg_advisory_lock(
    pg_catalog.hashtext(pg_catalog.current_database()),
    :'lock_key'::integer
);

UPDATE sql_test.concurrency_barriers
SET controller_locked = true
WHERE barrier_id = :'barrier_id';

SET psp_test.barrier_id = :'barrier_id';

DO $controller_wait$
DECLARE
    v_deadline timestamp with time zone :=
        pg_catalog.clock_timestamp() + interval '10 seconds';
    v_ready_count integer;
BEGIN
    LOOP
        SELECT count(*)::integer
        INTO v_ready_count
        FROM sql_test.concurrency_readiness
        WHERE barrier_id = pg_catalog.current_setting('psp_test.barrier_id');

        EXIT WHEN v_ready_count = 2;

        IF pg_catalog.clock_timestamp() >= v_deadline THEN
            RAISE EXCEPTION USING
                ERRCODE = 'P0001',
                MESSAGE = pg_catalog.format(
                    'Concurrency barrier timed out with %s ready worker(s)',
                    v_ready_count
                );
        END IF;

        PERFORM pg_catalog.pg_sleep(0.01);
    END LOOP;
END;
$controller_wait$;

SELECT pg_advisory_unlock(
    pg_catalog.hashtext(pg_catalog.current_database()),
    :'lock_key'::integer
);
SQL
controller_pid=$!

controller_locked=0
for ((attempt = 1; attempt <= 200; attempt++)); do
    controller_locked="$(
        psql \
            -X \
            --no-psqlrc \
            --quiet \
            --tuples-only \
            --no-align \
            --set=ON_ERROR_STOP=1 \
            --set=barrier_id="$barrier_id" \
            --dbname="$test_database" <<'SQL'
SELECT CASE WHEN controller_locked THEN 1 ELSE 0 END
FROM sql_test.concurrency_barriers
WHERE barrier_id = :'barrier_id';
SQL
    )"

    [[ "$controller_locked" == "1" ]] && break
    sleep 0.05
done

if [[ "$controller_locked" != "1" ]]; then
    set +e
    wait "$controller_pid"
    controller_status=$?
    set -e
    printf 'Controller did not acquire the concurrency barrier; status=%s\n' \
        "$controller_status" >&2
    cat "$controller_log" >&2
    exit 70
fi

run_worker() {
    local worker_name="$1"
    local output_file="$2"

    psql \
        -X \
        --no-psqlrc \
        --quiet \
        --tuples-only \
        --no-align \
        --set=ON_ERROR_STOP=1 \
        --set=barrier_id="$barrier_id" \
        --set=lock_key="$lock_key" \
        --set=worker_name="$worker_name" \
        --set=decision_id="$decision_id" \
        --dbname="$test_database" >"$output_file" 2>&1 <<'SQL'

INSERT INTO sql_test.concurrency_readiness (
    barrier_id,
    worker_name
) VALUES (
    :'barrier_id',
    :'worker_name'
);

SELECT pg_advisory_lock_shared(
    pg_catalog.hashtext(pg_catalog.current_database()),
    :'lock_key'::integer
);

SELECT pg_advisory_unlock_shared(
    pg_catalog.hashtext(pg_catalog.current_database()),
    :'lock_key'::integer
);

SELECT CASE
    WHEN decision.finalize_authorization_decision(:'decision_id'::uuid)
    THEN 'TRUE'
    ELSE 'FALSE'
END;
SQL
}

run_worker worker_one "$worker_one_log" &
worker_one_pid=$!
run_worker worker_two "$worker_two_log" &
worker_two_pid=$!

set +e
wait "$worker_one_pid"
worker_one_status=$?
wait "$worker_two_pid"
worker_two_status=$?
wait "$controller_pid"
controller_status=$?
set -e

ready_count="$(
    psql \
        -X \
        --no-psqlrc \
        --quiet \
        --tuples-only \
        --no-align \
        --set=ON_ERROR_STOP=1 \
        --set=barrier_id="$barrier_id" \
        --dbname="$test_database" <<'SQL'
SELECT count(*)
FROM sql_test.concurrency_readiness
WHERE barrier_id = :'barrier_id';
SQL
)"

true_count=0
false_count=0
unexpected_count=0

classify_worker() {
    local worker_status="$1"
    local output_file="$2"

    if [[ "$worker_status" -ne 0 ]]; then
        unexpected_count=$((unexpected_count + 1))
    elif grep -qx 'TRUE' "$output_file"; then
        true_count=$((true_count + 1))
    elif grep -qx 'FALSE' "$output_file"; then
        false_count=$((false_count + 1))
    else
        unexpected_count=$((unexpected_count + 1))
    fi
}

classify_worker "$worker_one_status" "$worker_one_log"
classify_worker "$worker_two_status" "$worker_two_log"
if [[ "$controller_status" -ne 0 ]]; then
    unexpected_count=$((unexpected_count + 1))
fi

final_row="$(
    psql \
        -X \
        --no-psqlrc \
        --quiet \
        --tuples-only \
        --no-align \
        --set=ON_ERROR_STOP=1 \
        --set=decision_id="$decision_id" \
        --dbname="$test_database" <<'SQL'
SELECT pg_catalog.concat_ws(
    '|',
    record.record_status,
    record.final_result,
    record.primary_reason_code,
    CASE WHEN record.finalized_at IS NOT NULL THEN 1 ELSE 0 END,
    CASE WHEN record.authorization_policy_version_id IS NOT NULL THEN 1 ELSE 0 END,
    CASE WHEN
        (SELECT count(*) FROM decision.evaluation_records AS evaluation
         WHERE evaluation.decision_id = record.decision_id) = 2
        AND
        (SELECT count(*) FROM decision.supporting_records AS supporting
         JOIN decision.evaluation_records AS evaluation
           ON evaluation.evaluation_id = supporting.evaluation_id
         WHERE evaluation.decision_id = record.decision_id) = 1
    THEN 1 ELSE 0 END
)
FROM decision.decision_records AS record
WHERE record.decision_id = :'decision_id'::uuid;
SQL
)"

IFS='|' read -r \
    final_status \
    final_result \
    final_reason \
    finalized_timestamp \
    policy_binding \
    closure_guard \
    <<<"$final_row"

psql \
    -X --no-psqlrc --quiet --set=ON_ERROR_STOP=1 \
    --set=ready_count="$ready_count" \
    --set=true_count="$true_count" \
    --set=false_count="$false_count" \
    --set=unexpected_count="$unexpected_count" \
    --set=final_status="$final_status" \
    --set=final_result="$final_result" \
    --set=final_reason="$final_reason" \
    --set=finalized_timestamp="$finalized_timestamp" \
    --set=policy_binding="$policy_binding" \
    --set=closure_guard="$closure_guard" \
    --dbname="$test_database" <<'SQL'
SELECT sql_test.begin_file('140_authorization_decision_finalization_race.sh');
SELECT sql_test.assert_equal_bigint('Both finalization workers reached the release barrier', :'ready_count'::bigint, 2);
SELECT sql_test.assert_equal_bigint('Exactly one concurrent Decision Record finalization succeeds', :'true_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Exactly one concurrent Decision Record finalization observes prior closure', :'false_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Decision finalization race has no unexpected worker or controller error', :'unexpected_count'::bigint, 0);
SELECT sql_test.assert_true('Decision finalization race ends FINALIZED', :'final_status' = 'FINALIZED');
SELECT sql_test.assert_true('Decision finalization race computes ALLOW', :'final_result' = 'ALLOW');
SELECT sql_test.assert_true('Decision finalization race retains the authoritative reason', :'final_reason' = 'AUTHORIZATION_DECISION_ALLOWED');
SELECT sql_test.assert_equal_bigint('Decision finalization race records one terminal timestamp', :'finalized_timestamp'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Decision finalization race retains one selected policy', :'policy_binding'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Decision finalization race preserves one complete evaluation closure', :'closure_guard'::bigint, 1);
SQL

printf 'CONCURRENCY RESULT | ready=%s true=%s false=%s unexpected=%s status=%s result=%s reason=%s finalized=%s policy=%s closure=%s\n' \
    "$ready_count" "$true_count" "$false_count" "$unexpected_count" \
    "$final_status" "$final_result" "$final_reason" \
    "$finalized_timestamp" "$policy_binding" "$closure_guard"
