#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

test_file="220_approval_last_approval_finalization_race.sh"
test_database="${ISSP_TEST_DATABASE:-}"
test_run_id="${ISSP_TEST_RUN_ID:-concurrency_$$}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
support_sql="${script_dir}/support/phase4_step7_approval_concurrency_fixture.sql"

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

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase4-step7-last-approval.XXXXXX")"
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
SELECT pg_catalog.concat_ws(
    '|',
    fixture.request_id,
    fixture.stage_id,
    fixture.finalizer_id,
    fixture.identity_a_id,
    fixture.identity_b_id,
    fixture.organization_id,
    fixture.session_a_id,
    fixture.session_b_id,
    fixture.grant_a_id,
    fixture.grant_b_id,
    fixture.approval_a_id,
    fixture.approval_b_id
)
FROM sql_test.create_phase4_step7_fixture(
    'last_approval_race',
    1
) AS fixture;
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

IFS='|' read -r \
    request_id \
    stage_id \
    finalizer_id \
    identity_a_id \
    identity_b_id \
    organization_id \
    session_a_id \
    session_b_id \
    grant_a_id \
    grant_b_id \
    approval_a_id \
    approval_b_id \
    <<<"$(printf '%s\n' "$fixture_row" | sed -n '$p')"

if [[ -z "$request_id" || -z "$stage_id" || -z "$finalizer_id" ]]; then
    printf 'Could not create Phase 4 Step 7 fixture\n' >&2
    exit 65
fi

barrier_id="${test_run_id}_last_approval_${request_id}"
lock_key=704220

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
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS sql_test.concurrency_readiness (
    barrier_id text NOT NULL,
    worker_name text NOT NULL,
    ready_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (barrier_id, worker_name),
    FOREIGN KEY (barrier_id)
        REFERENCES sql_test.concurrency_barriers(barrier_id)
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

SET issp_test.barrier_id = :'barrier_id';

DO $controller_wait$
DECLARE
    v_deadline timestamptz :=
        pg_catalog.clock_timestamp() + interval '10 seconds';
    v_ready_count integer;
BEGIN
    LOOP
        SELECT count(*)::integer
          INTO v_ready_count
          FROM sql_test.concurrency_readiness
         WHERE barrier_id =
               pg_catalog.current_setting('issp_test.barrier_id');

        EXIT WHEN v_ready_count = 2;

        IF pg_catalog.clock_timestamp() >= v_deadline THEN
            RAISE EXCEPTION
                USING
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
        --set=request_id="$request_id" \
        --set=stage_id="$stage_id" \
        --set=finalizer_id="$finalizer_id" \
        --set=identity_b_id="$identity_b_id" \
        --set=organization_id="$organization_id" \
        --set=session_b_id="$session_b_id" \
        --set=grant_b_id="$grant_b_id" \
        --dbname="$test_database" >"$output_file" 2>&1 <<'SQL'
INSERT INTO sql_test.concurrency_readiness (
    barrier_id,
    worker_name
)
VALUES (
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

CREATE FUNCTION pg_temp.run_last_approval_race(
    p_worker_name text,
    p_request_id uuid,
    p_stage_id uuid,
    p_finalizer_id uuid,
    p_identity_b_id uuid,
    p_organization_id uuid,
    p_session_b_id uuid,
    p_grant_b_id uuid
)
RETURNS text
LANGUAGE plpgsql
SET search_path = pg_catalog, approval
AS $function$
DECLARE
    v_action_id uuid;
    v_status text;
BEGIN
    IF p_worker_name = 'worker_one' THEN
        SELECT action_record.recorded_approval_action_id
          INTO STRICT v_action_id
          FROM approval.record_approval_action(
              p_request_id,
              p_stage_id,
              p_identity_b_id,
              p_organization_id,
              p_session_b_id,
              p_grant_b_id,
              'APPROVE',
              'Phase 4 Step 7 last approval race',
              'SQL_TEST_STEP7_LAST_APPROVAL',
              NULL
          ) AS action_record;

        RETURN 'ACTION_SUCCESS|' || v_action_id::text;
    END IF;

    SELECT result_record.final_status
      INTO STRICT v_status
      FROM approval.finalize_approval_request(
          p_request_id,
          'APPROVED',
          p_finalizer_id
      ) AS result_record;

    RETURN 'FINALIZE_SUCCESS|' || v_status;
EXCEPTION
    WHEN OTHERS THEN
        IF p_worker_name = 'worker_two'
           AND SQLSTATE = '55000'
           AND SQLERRM = 'APPROVAL_STAGE_UNSATISFIED'
        THEN
            RETURN 'UNSATISFIED|' || SQLSTATE;
        END IF;

        RETURN 'UNEXPECTED|' || SQLSTATE || '|' || SQLERRM;
END;
$function$;

SELECT pg_temp.run_last_approval_race(
    :'worker_name',
    :'request_id'::uuid,
    :'stage_id'::uuid,
    :'finalizer_id'::uuid,
    :'identity_b_id'::uuid,
    :'organization_id'::uuid,
    :'session_b_id'::uuid,
    :'grant_b_id'::uuid
);
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

action_success_count=0
finalize_success_count=0
unsatisfied_count=0
unexpected_count=0

classify_worker() {
    local worker_status="$1"
    local output_file="$2"
    local result_line

    result_line="$(
        grep -E '^(ACTION_SUCCESS|FINALIZE_SUCCESS|UNSATISFIED|UNEXPECTED)\|' \
            "$output_file" | tail -n 1 || true
    )"

    if [[ "$worker_status" -ne 0 ]]; then
        unexpected_count=$((unexpected_count + 1))
    elif [[ "$result_line" == ACTION_SUCCESS\|* ]]; then
        action_success_count=$((action_success_count + 1))
    elif [[ "$result_line" == 'FINALIZE_SUCCESS|APPROVED' ]]; then
        finalize_success_count=$((finalize_success_count + 1))
    elif [[ "$result_line" == 'UNSATISFIED|55000' ]]; then
        unsatisfied_count=$((unsatisfied_count + 1))
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
        --set=request_id="$request_id" \
        --set=stage_id="$stage_id" \
        --dbname="$test_database" <<'SQL'
SELECT pg_catalog.concat_ws(
    '|',
    (
        SELECT count(*)
        FROM approval.approval_actions AS action_record
        WHERE action_record.approval_request_id = :'request_id'::uuid
          AND action_record.action_type = 'APPROVE'
    ),
    (
        SELECT count(*)
        FROM approval.approval_actions AS action_record
        WHERE action_record.approval_request_id = :'request_id'::uuid
          AND action_record.action_type = 'APPROVE'
          AND approval.approval_action_is_current(
                action_record.approval_action_id,
                statement_timestamp()
              )
    ),
    (
        SELECT count(*)
        FROM approval.approval_action_duties AS duty_record
        JOIN approval.approval_actions AS action_record
          ON action_record.approval_action_id =
             duty_record.approval_action_id
        WHERE action_record.approval_request_id = :'request_id'::uuid
          AND duty_record.duty_key = 'APPROVE'
    ),
    request_record.status,
    COALESCE(request_record.final_reason_code, 'NULL'),
    CASE WHEN request_record.finalized_at IS NOT NULL THEN 1 ELSE 0 END,
    (
        SELECT count(*)
        FROM approval.approval_stage_evaluations AS evaluation
        WHERE evaluation.approval_request_id = :'request_id'::uuid
          AND evaluation.approval_policy_stage_id = :'stage_id'::uuid
          AND evaluation.finalized_evaluation
    )
)
FROM approval.approval_requests AS request_record
WHERE request_record.approval_request_id = :'request_id'::uuid;
SQL
)"

IFS='|' read -r \
    approval_count \
    current_approval_count \
    duty_count \
    request_status \
    final_reason \
    has_finalized_at \
    finalized_evaluation_count \
    <<<"$final_row"

terminal_result_count=$((finalize_success_count + unsatisfied_count))

psql \
    -X \
    --no-psqlrc \
    --quiet \
    --set=ON_ERROR_STOP=1 \
    --set=ready_count="$ready_count" \
    --set=action_success_count="$action_success_count" \
    --set=finalize_success_count="$finalize_success_count" \
    --set=unsatisfied_count="$unsatisfied_count" \
    --set=terminal_result_count="$terminal_result_count" \
    --set=unexpected_count="$unexpected_count" \
    --set=approval_count="$approval_count" \
    --set=current_approval_count="$current_approval_count" \
    --set=duty_count="$duty_count" \
    --set=request_status="$request_status" \
    --set=final_reason="$final_reason" \
    --set=has_finalized_at="$has_finalized_at" \
    --set=finalized_evaluation_count="$finalized_evaluation_count" \
    --dbname="$test_database" <<'SQL'
SELECT sql_test.begin_file(
    '220_approval_last_approval_finalization_race.sh'
);

SELECT sql_test.assert_equal_bigint(
    'Both last-approval workers reached the release barrier',
    :'ready_count'::bigint,
    2
);

SELECT sql_test.assert_equal_bigint(
    'The concurrent last Approval Action is recorded exactly once',
    :'action_success_count'::bigint,
    1
);

SELECT sql_test.assert_equal_bigint(
    'Finalization produces exactly one valid linearized outcome',
    :'terminal_result_count'::bigint,
    1
);

SELECT sql_test.assert_equal_bigint(
    'Last-approval race has no unexpected error',
    :'unexpected_count'::bigint,
    0
);

SELECT sql_test.assert_equal_bigint(
    'Last-approval race leaves exactly two approval actions',
    :'approval_count'::bigint,
    2
);

SELECT sql_test.assert_equal_bigint(
    'Last-approval race leaves exactly two current approvals',
    :'current_approval_count'::bigint,
    2
);

SELECT sql_test.assert_equal_bigint(
    'Last-approval race leaves exactly two APPROVE duties',
    :'duty_count'::bigint,
    2
);

SELECT sql_test.assert_true(
    'Last-approval race leaves only a valid request status',
    :'request_status' IN ('PENDING', 'APPROVED')
);

SELECT sql_test.assert_true(
    'Approved status occurs exactly when finalization wins after the last approval',
    (:'request_status' = 'APPROVED') =
    (:'finalize_success_count'::integer = 1)
);

SELECT sql_test.assert_true(
    'Finalized stage presence matches the finalization outcome',
    :'finalized_evaluation_count'::integer =
    :'finalize_success_count'::integer
);

SELECT sql_test.assert_true(
    'Final reason matches the finalization outcome',
    (
        :'finalize_success_count'::integer = 1
        AND :'final_reason' = 'APPROVAL_REQUEST_APPROVED'
    )
    OR
    (
        :'unsatisfied_count'::integer = 1
        AND :'final_reason' = 'NULL'
    )
);

SELECT sql_test.assert_true(
    'Finalized time matches the finalization outcome',
    :'has_finalized_at'::integer =
    :'finalize_success_count'::integer
);
SQL

printf 'CONCURRENCY RESULT | ready=%s action=%s finalize=%s unsatisfied=%s unexpected=%s approvals=%s current=%s duties=%s status=%s reason=%s finalized=%s evaluations=%s\n' \
    "$ready_count" "$action_success_count" "$finalize_success_count" \
    "$unsatisfied_count" "$unexpected_count" "$approval_count" \
    "$current_approval_count" "$duty_count" "$request_status" \
    "$final_reason" "$has_finalized_at" "$finalized_evaluation_count"
