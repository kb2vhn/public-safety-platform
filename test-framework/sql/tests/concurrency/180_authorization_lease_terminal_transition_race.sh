#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

test_file="180_authorization_lease_terminal_transition_race.sh"
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

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/psp-authz-terminal-race.XXXXXX")"
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
    'step6_terminal_race',
    'REUSABLE',
    NULL,
    interval '50 milliseconds'
) AS decision_id \gset

SELECT access_control.issue_authorization_lease_from_decision(
    :'decision_id'::uuid,
    fixture.secret
) AS lease_id
FROM pg_temp.step4_lease_fixtures AS fixture
WHERE fixture.fixture_key = 'step6_terminal_race'
\gset

SELECT pg_catalog.concat_ws('|', :'decision_id', :'lease_id');
SQL
    } | psql -X --no-psqlrc --quiet --tuples-only --no-align \
        --set=ON_ERROR_STOP=1 --dbname="$test_database"
)"

IFS='|' read -r decision_id lease_id <<<"$(printf '%s\n' "$fixture_row" | sed -n '$p')"
if [[ -z "$decision_id" || -z "$lease_id" ]]; then
    printf 'Could not create terminal lease race fixture\n' >&2
    exit 65
fi

sleep 0.10

barrier_id="${test_run_id}_authorization_terminal_${lease_id}"
lock_key=703180

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
    local operation="$3"

    psql \
        -X --no-psqlrc --quiet --tuples-only --no-align \
        --set=ON_ERROR_STOP=1 \
        --set=barrier_id="$barrier_id" \
        --set=lock_key="$lock_key" \
        --set=worker_name="$worker_name" \
        --set=lease_id="$lease_id" \
        --set=operation="$operation" \
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

SELECT CASE :'operation'
    WHEN 'expire' THEN access_control.expire_authorization_lease(:'lease_id'::uuid)
    ELSE access_control.revoke_lease(:'lease_id'::uuid, 'CONCURRENT_SECURITY_REVOKE')
END;
SQL
}

run_worker worker_one "$worker_one_log" expire &
worker_one_pid=$!
run_worker worker_two "$worker_two_log" revoke &
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
    elif grep -qx 't' "$output_file"; then
        true_count=$((true_count + 1))
    elif grep -qx 'f' "$output_file"; then
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
    psql -X --no-psqlrc --quiet --tuples-only --no-align \
        --set=ON_ERROR_STOP=1 \
        --set=lease_id="$lease_id" \
        --set=decision_id="$decision_id" \
        --dbname="$test_database" <<'SQL'
SELECT pg_catalog.concat_ws(
    '|',
    lease.status,
    pg_catalog.num_nonnulls(lease.revoked_at, lease.expired_at),
    CASE
        WHEN lease.status = 'REVOKED'
             AND lease.revoked_at IS NOT NULL
             AND lease.expired_at IS NULL
        THEN 1
        WHEN lease.status = 'EXPIRED'
             AND lease.expired_at IS NOT NULL
             AND lease.revoked_at IS NULL
        THEN 1
        ELSE 0
    END,
    CASE
        WHEN lease.status = 'REVOKED'
        THEN CASE WHEN lease.revocation_reason = 'CONCURRENT_SECURITY_REVOKE' THEN 1 ELSE 0 END
        WHEN lease.status = 'EXPIRED'
        THEN CASE WHEN lease.revocation_reason IS NULL THEN 1 ELSE 0 END
        ELSE 0
    END,
    lease.successful_use_count,
    (SELECT count(*) FROM access_control.authorization_lease_use_events AS event
     WHERE event.authorization_lease_id = lease.authorization_lease_id),
    CASE WHEN
        lease.issuing_decision_id = :'decision_id'::uuid
        AND (SELECT authorization_lease_id FROM decision.decision_records
             WHERE decision_id = :'decision_id'::uuid) = lease.authorization_lease_id
    THEN 1 ELSE 0 END
)
FROM access_control.authorization_leases AS lease
WHERE lease.authorization_lease_id = :'lease_id'::uuid;
SQL
)"

IFS='|' read -r final_status terminal_timestamps state_shape reason_shape use_count event_count decision_link <<<"$final_row"

psql -X --no-psqlrc --quiet --set=ON_ERROR_STOP=1 \
    --set=ready_count="$ready_count" \
    --set=true_count="$true_count" \
    --set=false_count="$false_count" \
    --set=unexpected_count="$unexpected_count" \
    --set=final_status="$final_status" \
    --set=terminal_timestamps="$terminal_timestamps" \
    --set=state_shape="$state_shape" \
    --set=reason_shape="$reason_shape" \
    --set=use_count="$use_count" \
    --set=event_count="$event_count" \
    --set=decision_link="$decision_link" \
    --dbname="$test_database" <<'SQL'
SELECT sql_test.begin_file('180_authorization_lease_terminal_transition_race.sh');
SELECT sql_test.assert_equal_bigint('Both lease terminal-transition workers reached the release barrier', :'ready_count'::bigint, 2);
SELECT sql_test.assert_equal_bigint('Exactly one expiration-or-revocation transition succeeds', :'true_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Exactly one expiration-or-revocation transition observes terminal state', :'false_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Lease terminal-transition race has no unexpected worker or controller error', :'unexpected_count'::bigint, 0);
SELECT sql_test.assert_true('Lease terminal-transition race ends in one allowed terminal status', :'final_status' IN ('EXPIRED', 'REVOKED'));
SELECT sql_test.assert_equal_bigint('Lease terminal-transition race records exactly one terminal timestamp', :'terminal_timestamps'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Lease terminal-transition race creates no mixed terminal state', :'state_shape'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Lease terminal-transition reason matches the winning state', :'reason_shape'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Lease terminal-transition race consumes no lease use', :'use_count'::bigint, 0);
SELECT sql_test.assert_equal_bigint('Lease terminal-transition race appends no use event', :'event_count'::bigint, 0);
SELECT sql_test.assert_equal_bigint('Lease terminal-transition race preserves the issuing Decision Record link', :'decision_link'::bigint, 1);
SQL

printf 'CONCURRENCY RESULT | ready=%s true=%s false=%s unexpected=%s final_status=%s terminal_timestamps=%s state_shape=%s reason_shape=%s use_count=%s events=%s decision_link=%s\n' \
    "$ready_count" "$true_count" "$false_count" "$unexpected_count" \
    "$final_status" "$terminal_timestamps" "$state_shape" "$reason_shape" \
    "$use_count" "$event_count" "$decision_link"
