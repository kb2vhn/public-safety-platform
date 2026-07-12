#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

test_file="160_authorization_lease_single_use_race.sh"
test_database="${PSP_TEST_DATABASE:-}"
test_run_id="${PSP_TEST_RUN_ID:-concurrency_$$}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
support_sql="${script_dir}/support/phase3_authorization_concurrency_fixture.sql"

if [[ -z "$test_database" ]]; then
    printf 'PSP_TEST_DATABASE is required\n' >&2
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

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/psp-authz-single-use-race.XXXXXX")"
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
    'step6_single_use_race',
    'SINGLE_USE',
    1
) AS decision_id \gset

SELECT access_control.issue_authorization_lease_from_decision(
    :'decision_id'::uuid,
    fixture.secret
) AS lease_id
FROM pg_temp.step4_lease_fixtures AS fixture
WHERE fixture.fixture_key = 'step6_single_use_race'
\gset

UPDATE pg_temp.step4_lease_fixtures
SET lease_id = :'lease_id'::uuid
WHERE fixture_key = 'step6_single_use_race';

SELECT sql_test.create_phase3_step4_use_decision('step6_single_use_race') AS use_decision_one \gset
SELECT sql_test.create_phase3_step4_use_decision('step6_single_use_race') AS use_decision_two \gset

SELECT pg_catalog.concat_ws(
    '|',
    fixture.lease_id,
    fixture.secret,
    common.identity_id,
    common.organization_id,
    fixture.session_id,
    common.device_id,
    common.service_id,
    common.purpose_definition_id,
    common.operation_definition_id,
    fixture.policy_version_id,
    one.request_id,
    one.decision_id,
    one.correlation_id,
    two.request_id,
    two.decision_id,
    two.correlation_id
)
FROM pg_temp.step4_lease_fixtures AS fixture
CROSS JOIN pg_temp.step4_common AS common
JOIN decision.decision_records AS one
  ON one.decision_id = :'use_decision_one'::uuid
JOIN decision.decision_records AS two
  ON two.decision_id = :'use_decision_two'::uuid
WHERE fixture.fixture_key = 'step6_single_use_race';
SQL
    } | psql -X --no-psqlrc --quiet --tuples-only --no-align \
        --set=ON_ERROR_STOP=1 --dbname="$test_database"
)"

IFS='|' read -r \
    lease_id lease_secret identity_id organization_id session_id device_id \
    service_id purpose_id operation_id policy_version_id \
    request_one decision_one correlation_one \
    request_two decision_two correlation_two \
    <<<"$(printf '%s\n' "$fixture_row" | sed -n '$p')"

if [[ -z "$lease_id" || -z "$decision_two" ]]; then
    printf 'Could not create authorization_single_use race fixture\n' >&2
    exit 65
fi

barrier_id="${test_run_id}_authorization_single_use_${lease_id}"
lock_key=703160

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
    local request_id="$3"
    local decision_id="$4"
    local correlation_id="$5"

    psql \
        -X --no-psqlrc --quiet --tuples-only --no-align \
        --set=ON_ERROR_STOP=1 \
        --set=barrier_id="$barrier_id" \
        --set=lock_key="$lock_key" \
        --set=worker_name="$worker_name" \
        --set=lease_id="$lease_id" \
        --set=lease_secret="$lease_secret" \
        --set=request_id="$request_id" \
        --set=identity_id="$identity_id" \
        --set=organization_id="$organization_id" \
        --set=session_id="$session_id" \
        --set=device_id="$device_id" \
        --set=service_id="$service_id" \
        --set=purpose_id="$purpose_id" \
        --set=operation_id="$operation_id" \
        --set=policy_version_id="$policy_version_id" \
        --set=decision_id="$decision_id" \
        --set=correlation_id="$correlation_id" \
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

CREATE FUNCTION pg_temp.try_consume(
    p_lease_id uuid,
    p_secret text,
    p_request_id uuid,
    p_identity_id uuid,
    p_organization_id uuid,
    p_session_id uuid,
    p_device_id uuid,
    p_service_id uuid,
    p_purpose_id uuid,
    p_operation_id uuid,
    p_target_type text,
    p_target_reference text,
    p_policy_version_id uuid,
    p_audience text,
    p_decision_id uuid,
    p_correlation_id uuid
)
RETURNS text
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_use_number integer;
BEGIN
    v_use_number := access_control.consume_authorization_lease(
        p_lease_id,
        p_secret,
        p_request_id,
        p_identity_id,
        p_organization_id,
        p_session_id,
        p_device_id,
        p_service_id,
        p_purpose_id,
        p_operation_id,
        p_target_type,
        p_target_reference,
        NULL,
        NULL,
        p_policy_version_id,
        p_audience,
        p_decision_id,
        p_correlation_id
    );
    RETURN 'SUCCESS|' || v_use_number::text;
EXCEPTION
    WHEN SQLSTATE '28000' THEN
        RETURN 'DENIED|28000';
    WHEN OTHERS THEN
        RETURN 'UNEXPECTED|' || SQLSTATE;
END;
$function$;

SELECT pg_temp.try_consume(
    :'lease_id'::uuid,
    :'lease_secret',
    :'request_id'::uuid,
    :'identity_id'::uuid,
    :'organization_id'::uuid,
    :'session_id'::uuid,
    :'device_id'::uuid,
    :'service_id'::uuid,
    :'purpose_id'::uuid,
    :'operation_id'::uuid,
    'TEST_RESOURCE',
    'step6_single_use_race',
    :'policy_version_id'::uuid,
    'phase3-step4-protected-consumer',
    :'decision_id'::uuid,
    :'correlation_id'::uuid
);
SQL
}

run_worker worker_one "$worker_one_log" "$request_one" "$decision_one" "$correlation_one" &
worker_one_pid=$!
run_worker worker_two "$worker_two_log" "$request_two" "$decision_two" "$correlation_two" &
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

success_count=0
denied_count=0
unexpected_count=0
winning_decision_id=""
winning_use_number=""

classify_worker() {
    local worker_status="$1"
    local output_file="$2"
    local decision_id="$3"
    local result_line

    result_line="$(grep -E '^(SUCCESS|DENIED|UNEXPECTED)\|' "$output_file" | tail -n 1 || true)"

    if [[ "$worker_status" -ne 0 ]]; then
        unexpected_count=$((unexpected_count + 1))
    elif [[ "$result_line" == SUCCESS\|* ]]; then
        success_count=$((success_count + 1))
        winning_decision_id="$decision_id"
        winning_use_number="${result_line#SUCCESS|}"
    elif [[ "$result_line" == 'DENIED|28000' ]]; then
        denied_count=$((denied_count + 1))
    else
        unexpected_count=$((unexpected_count + 1))
    fi
}

classify_worker "$worker_one_status" "$worker_one_log" "$decision_one"
classify_worker "$worker_two_status" "$worker_two_log" "$decision_two"
if [[ "$controller_status" -ne 0 ]]; then
    unexpected_count=$((unexpected_count + 1))
fi

final_row="$(
    psql -X --no-psqlrc --quiet --tuples-only --no-align \
        --set=ON_ERROR_STOP=1 \
        --set=lease_id="$lease_id" \
        --set=winning_decision_id="$winning_decision_id" \
        --dbname="$test_database" <<'SQL'
SELECT pg_catalog.concat_ws(
    '|',
    lease.status,
    lease.successful_use_count,
    CASE WHEN lease.consumed_at IS NOT NULL THEN 1 ELSE 0 END,
    (SELECT count(*) FROM access_control.authorization_lease_use_events AS event
     WHERE event.authorization_lease_id = lease.authorization_lease_id),
    CASE WHEN
        (SELECT pg_catalog.min(event.use_number) FROM access_control.authorization_lease_use_events AS event
         WHERE event.authorization_lease_id = lease.authorization_lease_id) = 1
        AND
        (SELECT pg_catalog.max(event.use_number) FROM access_control.authorization_lease_use_events AS event
         WHERE event.authorization_lease_id = lease.authorization_lease_id) = 1
    THEN 1 ELSE 0 END,
    (SELECT count(*) FROM access_control.authorization_lease_use_events AS event
     WHERE event.authorization_lease_id = lease.authorization_lease_id
       AND event.decision_reference = :'winning_decision_id'::uuid),
    (SELECT count(DISTINCT event.decision_reference)
     FROM access_control.authorization_lease_use_events AS event
     WHERE event.authorization_lease_id = lease.authorization_lease_id)
)
FROM access_control.authorization_leases AS lease
WHERE lease.authorization_lease_id = :'lease_id'::uuid;
SQL
)"

IFS='|' read -r final_status final_use_count consumed_timestamp event_count use_number_guard winner_event_count distinct_decisions <<<"$final_row"

psql -X --no-psqlrc --quiet --set=ON_ERROR_STOP=1 \
    --set=ready_count="$ready_count" \
    --set=success_count="$success_count" \
    --set=denied_count="$denied_count" \
    --set=unexpected_count="$unexpected_count" \
    --set=final_status="$final_status" \
    --set=final_use_count="$final_use_count" \
    --set=consumed_timestamp="$consumed_timestamp" \
    --set=event_count="$event_count" \
    --set=use_number_guard="$use_number_guard" \
    --set=winner_event_count="$winner_event_count" \
    --set=distinct_decisions="$distinct_decisions" \
    --dbname="$test_database" <<'SQL'
SELECT sql_test.begin_file('160_authorization_lease_single_use_race.sh');
SELECT sql_test.assert_equal_bigint('Both single-use lease workers reached the release barrier', :'ready_count'::bigint, 2);
SELECT sql_test.assert_equal_bigint('Exactly one concurrent single-use lease consumption succeeds', :'success_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Exactly one concurrent single-use lease consumption is denied', :'denied_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Single-use lease race has no unexpected worker or controller error', :'unexpected_count'::bigint, 0);
SELECT sql_test.assert_true('Single-use lease race ends CONSUMED', :'final_status' = 'CONSUMED');
SELECT sql_test.assert_equal_bigint('Single-use lease race records exactly one successful use', :'final_use_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Single-use lease race records one consumed timestamp', :'consumed_timestamp'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Single-use lease race appends exactly one use event', :'event_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Single-use lease race records use number one exactly once', :'use_number_guard'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Single-use lease race event names the winning Decision Record', :'winner_event_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Single-use lease race retains one attributable protected-operation decision', :'distinct_decisions'::bigint, 1);
SQL

printf 'CONCURRENCY RESULT | ready=%s success=%s denied=%s unexpected=%s status=%s uses=%s consumed_at=%s events=%s use_number_guard=%s winner_events=%s decisions=%s\n' \
    "$ready_count" "$success_count" "$denied_count" "$unexpected_count" \
    "$final_status" "$final_use_count" "$consumed_timestamp" "$event_count" \
    "$use_number_guard" "$winner_event_count" "$distinct_decisions"
