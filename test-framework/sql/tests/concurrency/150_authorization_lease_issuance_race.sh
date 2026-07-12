#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

test_file="150_authorization_lease_issuance_race.sh"
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

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/psp-authz-issuance-race.XXXXXX")"
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
    'step6_issuance_race',
    'REUSABLE',
    NULL
) AS decision_id \gset

SELECT pg_catalog.concat_ws(
    '|',
    :'decision_id',
    fixture.secret
)
FROM pg_temp.step4_lease_fixtures AS fixture
WHERE fixture.fixture_key = 'step6_issuance_race';
SQL
    } | psql -X --no-psqlrc --quiet --tuples-only --no-align \
        --set=ON_ERROR_STOP=1 --dbname="$test_database"
)"

IFS='|' read -r decision_id lease_secret <<<"$(printf '%s\n' "$fixture_row" | sed -n '$p')"
if [[ -z "$decision_id" || -z "$lease_secret" ]]; then
    printf 'Could not create issuance race fixture\n' >&2
    exit 65
fi

barrier_id="${test_run_id}_authorization_issuance_${decision_id}"
lock_key=703150

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
        -X --no-psqlrc --quiet --tuples-only --no-align \
        --set=ON_ERROR_STOP=1 \
        --set=barrier_id="$barrier_id" \
        --set=lock_key="$lock_key" \
        --set=worker_name="$worker_name" \
        --set=decision_id="$decision_id" \
        --set=lease_secret="$lease_secret" \
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

CREATE FUNCTION pg_temp.try_issue(p_decision_id uuid, p_secret text)
RETURNS text
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_lease_id uuid;
BEGIN
    v_lease_id := access_control.issue_authorization_lease_from_decision(
        p_decision_id,
        p_secret
    );
    RETURN 'SUCCESS|' || v_lease_id::text;
EXCEPTION
    WHEN SQLSTATE '28000' THEN
        RETURN 'DENIED|28000';
    WHEN OTHERS THEN
        RETURN 'UNEXPECTED|' || SQLSTATE;
END;
$function$;

SELECT pg_temp.try_issue(:'decision_id'::uuid, :'lease_secret');
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

success_count=0
denied_count=0
unexpected_count=0
winning_lease_id=""

classify_worker() {
    local worker_status="$1"
    local output_file="$2"
    local result_line

    result_line="$(grep -E '^(SUCCESS|DENIED|UNEXPECTED)\|' "$output_file" | tail -n 1 || true)"

    if [[ "$worker_status" -ne 0 ]]; then
        unexpected_count=$((unexpected_count + 1))
    elif [[ "$result_line" == SUCCESS\|* ]]; then
        success_count=$((success_count + 1))
        winning_lease_id="${result_line#SUCCESS|}"
    elif [[ "$result_line" == 'DENIED|28000' ]]; then
        denied_count=$((denied_count + 1))
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
        --set=decision_id="$decision_id" \
        --set=winning_lease_id="$winning_lease_id" \
        --set=lease_secret="$lease_secret" \
        --dbname="$test_database" <<'SQL'
SELECT pg_catalog.concat_ws(
    '|',
    (SELECT count(*) FROM access_control.authorization_leases AS lease
     WHERE lease.issuing_decision_id = decision_record.decision_id),
    CASE WHEN decision_record.authorization_lease_id = :'winning_lease_id'::uuid THEN 1 ELSE 0 END,
    lease.status,
    pg_catalog.octet_length(lease.lease_secret_hash),
    CASE WHEN lease.lease_secret_hash <> pg_catalog.convert_to(:'lease_secret', 'UTF8') THEN 1 ELSE 0 END,
    CASE WHEN
        lease.issuing_decision_id = decision_record.decision_id
        AND lease.request_id = decision_record.request_id
        AND lease.session_id = decision_record.session_id
        AND lease.identity_id = decision_record.requester_identity_id
        AND lease.requester_organization_id IS NOT DISTINCT FROM decision_record.requester_organization_id
        AND lease.device_id IS NOT DISTINCT FROM decision_record.device_id
        AND lease.service_id IS NOT DISTINCT FROM decision_record.service_id
        AND lease.purpose_definition_id IS NOT DISTINCT FROM decision_record.purpose_definition_id
        AND lease.operation_definition_id = decision_record.operation_definition_id
        AND lease.protected_target_type IS NOT DISTINCT FROM decision_record.protected_target_type
        AND lease.protected_target_reference IS NOT DISTINCT FROM decision_record.protected_target_reference
        AND lease.authorization_policy_version_id = decision_record.authorization_policy_version_id
        AND lease.correlation_id = decision_record.correlation_id
    THEN 1 ELSE 0 END,
    CASE WHEN
        lease.status = 'ACTIVE'
        AND lease.successful_use_count = 0
        AND lease.consumed_at IS NULL
        AND lease.revoked_at IS NULL
        AND lease.expired_at IS NULL
    THEN 1 ELSE 0 END
)
FROM decision.decision_records AS decision_record
JOIN access_control.authorization_leases AS lease
  ON lease.authorization_lease_id = decision_record.authorization_lease_id
WHERE decision_record.decision_id = :'decision_id'::uuid;
SQL
)"

IFS='|' read -r lease_count decision_link active_status hash_length plaintext_guard context_guard active_shape <<<"$final_row"

psql -X --no-psqlrc --quiet --set=ON_ERROR_STOP=1 \
    --set=ready_count="$ready_count" \
    --set=success_count="$success_count" \
    --set=denied_count="$denied_count" \
    --set=unexpected_count="$unexpected_count" \
    --set=lease_count="$lease_count" \
    --set=decision_link="$decision_link" \
    --set=active_status="$active_status" \
    --set=hash_length="$hash_length" \
    --set=plaintext_guard="$plaintext_guard" \
    --set=context_guard="$context_guard" \
    --set=active_shape="$active_shape" \
    --dbname="$test_database" <<'SQL'
SELECT sql_test.begin_file('150_authorization_lease_issuance_race.sh');
SELECT sql_test.assert_equal_bigint('Both lease-issuance workers reached the release barrier', :'ready_count'::bigint, 2);
SELECT sql_test.assert_equal_bigint('Exactly one concurrent lease issuance succeeds', :'success_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Exactly one concurrent lease issuance is denied', :'denied_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Lease issuance race has no unexpected worker or controller error', :'unexpected_count'::bigint, 0);
SELECT sql_test.assert_equal_bigint('Lease issuance race creates exactly one lease', :'lease_count'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Lease issuance race links the Decision Record to the winning lease', :'decision_link'::bigint, 1);
SELECT sql_test.assert_true('Lease issuance race leaves the winning lease ACTIVE', :'active_status' = 'ACTIVE');
SELECT sql_test.assert_equal_bigint('Lease issuance race stores one SHA-256 verifier', :'hash_length'::bigint, 32);
SELECT sql_test.assert_equal_bigint('Lease issuance race does not store the plaintext secret', :'plaintext_guard'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Lease issuance race preserves exact Decision Record context', :'context_guard'::bigint, 1);
SELECT sql_test.assert_equal_bigint('Lease issuance race leaves one clean ACTIVE lease shape', :'active_shape'::bigint, 1);
SQL

printf 'CONCURRENCY RESULT | ready=%s success=%s denied=%s unexpected=%s leases=%s decision_link=%s status=%s hash_bytes=%s plaintext_guard=%s context_guard=%s active_shape=%s\n' \
    "$ready_count" "$success_count" "$denied_count" "$unexpected_count" \
    "$lease_count" "$decision_link" "$active_status" "$hash_length" \
    "$plaintext_guard" "$context_guard" "$active_shape"
