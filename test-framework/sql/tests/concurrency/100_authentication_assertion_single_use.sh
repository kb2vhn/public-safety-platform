#!/usr/bin/env bash
#
# Real multi-connection Authentication Assertion single-use race.
#
# The controller connection holds an exclusive advisory-lock barrier. Both
# worker connections commit readiness, request compatible shared locks, and are
# released together. They then independently attempt to consume the same
# verified assertion. Exactly one must succeed and one must receive SQLSTATE
# 28000 after PostgreSQL rechecks the conditional update.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

test_file="100_authentication_assertion_single_use.sh"
test_database="${PSP_TEST_DATABASE:-}"
test_run_id="${PSP_TEST_RUN_ID:-concurrency_$$}"

if [[ -z "$test_database" ]]; then
    printf 'PSP_TEST_DATABASE is required\n' >&2
    exit 64
fi

for command_name in psql grep mktemp rm sleep; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 69
    fi
done

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/psp-auth-assertion-race.XXXXXX")"
controller_log="${work_dir}/controller.log"
worker_one_log="${work_dir}/worker_one.log"
worker_two_log="${work_dir}/worker_two.log"

cleanup() {
    rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

printf 'CONCURRENCY TEST FILE | %s\n' "$test_file"

fixture_row="$(
    psql \
        -X \
        --no-psqlrc \
        --quiet \
        --tuples-only \
        --no-align \
        --set=ON_ERROR_STOP=1 \
        --dbname="$test_database" <<'SQL'
SELECT
    gen_random_uuid() AS trust_provider_id,
    gen_random_uuid() AS device_id,
    gen_random_uuid() AS person_id,
    gen_random_uuid() AS identity_id,
    gen_random_uuid() AS organization_id,
    gen_random_uuid() AS service_id,
    gen_random_uuid() AS authentication_assertion_id,
    'sql-test-concurrency-' || gen_random_uuid()::text AS assertion_external_id
\gset

BEGIN;

INSERT INTO trust.trust_providers (
    trust_provider_id,
    provider_key,
    display_name,
    provider_type,
    environment_key,
    status,
    valid_from,
    valid_until,
    created_by_reference
)
VALUES (
    :'trust_provider_id'::uuid,
    'sql_test.concurrency_provider_' || replace(:'trust_provider_id', '-', ''),
    'SQL Test Concurrency Trust Provider',
    'IDENTITY_PROVIDER',
    'test',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    statement_timestamp() + interval '1 day',
    'sql_test'
);

INSERT INTO trust.devices (
    device_id,
    device_key,
    device_type,
    status,
    enrolled_at,
    trusted_from,
    trusted_until,
    created_by_reference
)
VALUES (
    :'device_id'::uuid,
    'sql_test.concurrency_device_' || replace(:'device_id', '-', ''),
    'WORKSTATION',
    'TRUSTED',
    statement_timestamp() - interval '1 day',
    statement_timestamp() - interval '1 day',
    statement_timestamp() + interval '1 day',
    'sql_test'
);

INSERT INTO identity.persons (
    person_id,
    person_key,
    display_name,
    status,
    created_by_reference
)
VALUES (
    :'person_id'::uuid,
    'sql_test.concurrency_person_' || replace(:'person_id', '-', ''),
    'SQL Test Concurrency Person',
    'ACTIVE',
    'sql_test'
);

INSERT INTO identity.identities (
    identity_id,
    identity_key,
    identity_type,
    person_id,
    status,
    assurance_level,
    valid_from,
    valid_until,
    created_by_reference
)
VALUES (
    :'identity_id'::uuid,
    'sql_test.concurrency_identity_' || replace(:'identity_id', '-', ''),
    'HUMAN',
    :'person_id'::uuid,
    'ACTIVE',
    'TEST',
    statement_timestamp() - interval '1 day',
    statement_timestamp() + interval '1 day',
    'sql_test'
);

INSERT INTO organization.organizations (
    organization_id,
    organization_key,
    legal_name,
    display_name,
    organization_type,
    status,
    valid_from,
    valid_until,
    created_by_reference
)
VALUES (
    :'organization_id'::uuid,
    'sql_test.concurrency_org_' || replace(:'organization_id', '-', ''),
    'SQL Test Concurrency Organization',
    'SQL Test Concurrency Organization',
    'TEST_ORGANIZATION',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    statement_timestamp() + interval '1 day',
    'sql_test'
);

INSERT INTO service.platform_services (
    service_id,
    service_key,
    display_name,
    service_type,
    service_owner_organization_id,
    status,
    valid_from,
    valid_until,
    created_by_reference
)
VALUES (
    :'service_id'::uuid,
    'sql_test.concurrency_service_' || replace(:'service_id', '-', ''),
    'SQL Test Concurrency Service',
    'TEST_SERVICE',
    :'organization_id'::uuid,
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    statement_timestamp() + interval '1 day',
    'sql_test'
);

INSERT INTO access_control.authentication_assertions (
    authentication_assertion_id,
    assertion_id,
    assertion_purpose,
    trust_provider_id,
    identity_id,
    device_id,
    session_id,
    service_id,
    audience,
    environment_key,
    issued_at,
    expires_at,
    nonce_hash,
    payload_hash,
    signature_algorithm,
    signature_value,
    received_at
)
VALUES (
    :'authentication_assertion_id'::uuid,
    :'assertion_external_id',
    'SESSION_ESTABLISHMENT',
    :'trust_provider_id'::uuid,
    :'identity_id'::uuid,
    :'device_id'::uuid,
    NULL,
    :'service_id'::uuid,
    'sql-test-concurrency-audience',
    'test',
    statement_timestamp() - interval '1 minute',
    statement_timestamp() + interval '10 minutes',
    extensions.digest(
        convert_to(:'assertion_external_id' || ':nonce', 'UTF8'),
        'sha256'
    ),
    extensions.digest(
        convert_to(:'assertion_external_id' || ':payload', 'UTF8'),
        'sha256'
    ),
    'TEST-SIGNATURE',
    decode(repeat('71', 32), 'hex'),
    statement_timestamp() - interval '30 seconds'
);

COMMIT;

SELECT access_control.mark_authentication_assertion_verified(
    :'authentication_assertion_id'::uuid,
    'sql_test.concurrent_verifier',
    'sql_test.concurrent_signature_and_claim_validation.v1'
) AS assertion_verified
\gset

\if :assertion_verified
\else
    \echo 'Concurrency fixture could not be verified'
    \quit 3
\endif

SELECT concat_ws(
    '|',
    :'assertion_external_id',
    :'authentication_assertion_id',
    :'trust_provider_id',
    :'identity_id',
    :'device_id',
    :'service_id'
);
SQL
)"

IFS='|' read -r \
    assertion_external_id \
    authentication_assertion_id \
    trust_provider_id \
    identity_id \
    device_id \
    service_id \
    <<<"$fixture_row"

if [[ -z "$service_id" ]]; then
    printf 'Could not parse concurrency fixture identifiers: %s\n' "$fixture_row" >&2
    exit 65
fi

barrier_id="${test_run_id}_${authentication_assertion_id}"

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

# The controller holds an exclusive lock and releases it only after both worker
# readiness rows are visible. Both workers request compatible shared locks, so
# PostgreSQL releases them together when the exclusive lock is removed.
psql \
    -X \
    --no-psqlrc \
    --quiet \
    --set=ON_ERROR_STOP=1 \
    --set=VERBOSITY=verbose \
    --set=barrier_id="$barrier_id" \
    --dbname="$test_database" >"$controller_log" 2>&1 <<'SQL' &
SELECT pg_advisory_lock(hashtext(current_database()), 701105);

UPDATE sql_test.concurrency_barriers
SET controller_locked = true
WHERE barrier_id = :'barrier_id';

SET psp_test.barrier_id = :'barrier_id';

DO $controller_wait$
DECLARE
    v_deadline timestamp with time zone := clock_timestamp() + interval '10 seconds';
    v_ready_count integer;
BEGIN
    LOOP
        SELECT count(*)::integer
        INTO v_ready_count
        FROM sql_test.concurrency_readiness
        WHERE barrier_id = current_setting('psp_test.barrier_id');

        EXIT WHEN v_ready_count = 2;

        IF clock_timestamp() >= v_deadline THEN
            RAISE EXCEPTION USING
                ERRCODE = 'P0001',
                MESSAGE = format(
                    'Concurrency barrier timed out with %s ready worker(s)',
                    v_ready_count
                );
        END IF;

        PERFORM pg_sleep(0.01);
    END LOOP;
END;
$controller_wait$;

SELECT pg_advisory_unlock(hashtext(current_database()), 701105);
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

    psql \
        -X \
        --no-psqlrc \
        --quiet \
        --set=ON_ERROR_STOP=1 \
        --set=test_file="$test_file" \
        --set=details="controller_status=${controller_status}" \
        --dbname="$test_database" <<'SQL'
SELECT sql_test.begin_file('100_authentication_assertion_single_use.sh');
SELECT sql_test.fail(
    'Concurrency controller acquired the release barrier',
    :'details'
);
SQL
    exit 0
fi

run_worker() {
    local worker_name="$1"
    local output_file="$2"

    PGAPPNAME="public-safety-platform-auth-assertion-${worker_name}" \
    psql \
        -X \
        --no-psqlrc \
        --quiet \
        --tuples-only \
        --no-align \
        --set=ON_ERROR_STOP=1 \
        --set=VERBOSITY=verbose \
        --set=barrier_id="$barrier_id" \
        --set=worker_name="$worker_name" \
        --set=assertion_external_id="$assertion_external_id" \
        --set=trust_provider_id="$trust_provider_id" \
        --set=identity_id="$identity_id" \
        --set=device_id="$device_id" \
        --set=service_id="$service_id" \
        --dbname="$test_database" >"$output_file" 2>&1 <<'SQL'
INSERT INTO sql_test.concurrency_readiness (
    barrier_id,
    worker_name
)
VALUES (
    :'barrier_id',
    :'worker_name'
);

SELECT pg_advisory_lock_shared(hashtext(current_database()), 701105);
SELECT pg_advisory_unlock_shared(hashtext(current_database()), 701105);

SELECT access_control.consume_authentication_assertion(
    :'assertion_external_id',
    'SESSION_ESTABLISHMENT',
    :'trust_provider_id'::uuid,
    :'identity_id'::uuid,
    :'device_id'::uuid,
    NULL,
    :'service_id'::uuid,
    'sql-test-concurrency-audience',
    'test'
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

success_count=0
denied_count=0
unexpected_count=0

classify_worker() {
    local worker_status="$1"
    local output_file="$2"

    if [[ "$worker_status" -eq 0 ]]; then
        success_count=$((success_count + 1))
    elif grep -q '28000' "$output_file"; then
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
    psql \
        -X \
        --no-psqlrc \
        --quiet \
        --tuples-only \
        --no-align \
        --set=ON_ERROR_STOP=1 \
        --set=authentication_assertion_id="$authentication_assertion_id" \
        --dbname="$test_database" <<'SQL'
SELECT
    status || '|' ||
    CASE WHEN consumed_at IS NULL THEN '0' ELSE '1' END
FROM access_control.authentication_assertions
WHERE authentication_assertion_id = :'authentication_assertion_id'::uuid;
SQL
)"

IFS='|' read -r final_status consumed_timestamp_count <<<"$final_row"

psql \
    -X \
    --no-psqlrc \
    --quiet \
    --set=ON_ERROR_STOP=1 \
    --set=ready_count="$ready_count" \
    --set=success_count="$success_count" \
    --set=denied_count="$denied_count" \
    --set=unexpected_count="$unexpected_count" \
    --set=final_status="$final_status" \
    --set=consumed_timestamp_count="$consumed_timestamp_count" \
    --set=worker_one_status="$worker_one_status" \
    --set=worker_two_status="$worker_two_status" \
    --set=controller_status="$controller_status" \
    --dbname="$test_database" <<'SQL'
SELECT sql_test.begin_file('100_authentication_assertion_single_use.sh');

SELECT sql_test.assert_equal_bigint(
    'Both Authentication Assertion race workers reached the release barrier',
    :'ready_count'::bigint,
    2
);

SELECT sql_test.assert_equal_bigint(
    'Exactly one concurrent Authentication Assertion consumer succeeds',
    :'success_count'::bigint,
    1
);

SELECT sql_test.assert_equal_bigint(
    'Exactly one concurrent Authentication Assertion consumer is denied',
    :'denied_count'::bigint,
    1
);

SELECT sql_test.assert_equal_bigint(
    'Authentication Assertion race has no unexpected worker or controller error',
    :'unexpected_count'::bigint,
    0
);

SELECT sql_test.assert_true(
    'Concurrent Authentication Assertion race ends in CONSUMED state',
    :'final_status' = 'CONSUMED',
    format(
        'final_status=%s worker_one_status=%s worker_two_status=%s controller_status=%s',
        :'final_status',
        :'worker_one_status',
        :'worker_two_status',
        :'controller_status'
    )
);

SELECT sql_test.assert_equal_bigint(
    'Concurrent Authentication Assertion race records exactly one consumed timestamp',
    :'consumed_timestamp_count'::bigint,
    1
);
SQL

printf 'CONCURRENCY RESULT | ready=%s success=%s denied=%s unexpected=%s final_status=%s consumed_at=%s\n' \
    "$ready_count" \
    "$success_count" \
    "$denied_count" \
    "$unexpected_count" \
    "$final_status" \
    "$consumed_timestamp_count"

