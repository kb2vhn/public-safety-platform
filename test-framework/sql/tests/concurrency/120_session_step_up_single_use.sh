#!/usr/bin/env bash

#
# Real multi-connection session step-up single-use race.
#
# The controller connection holds an exclusive advisory-lock barrier. Both
# workers commit readiness, request compatible shared locks, and are released
# together. The workers then use separate PostgreSQL connections to exercise
# the same controlled session boundary.
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

test_file="120_session_step_up_single_use.sh"
test_database="${ISSP_TEST_DATABASE:-}"
test_run_id="${ISSP_TEST_RUN_ID:-concurrency_$$}"

if [[ -z "$test_database" ]]; then
    printf 'ISSP_TEST_DATABASE is required\n' >&2
    exit 64
fi

for command_name in psql grep mktemp rm sleep; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 69
    fi
done

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/psp-session-step-up-race.XXXXXX")"
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
    gen_random_uuid() AS establishment_assertion_id,
    gen_random_uuid() AS step_up_assertion_id,
    'sql-test-step-up-establishment-' || gen_random_uuid()::text
        AS establishment_external_id,
    'sql-test-step-up-race-' || gen_random_uuid()::text
        AS step_up_external_id
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
    'sql_test.step_up_race_provider_'
        || replace(:'trust_provider_id', '-', ''),
    'SQL Test Step-Up Race Provider',
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
    'sql_test.step_up_race_device_'
        || replace(:'device_id', '-', ''),
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
    'sql_test.step_up_race_person_'
        || replace(:'person_id', '-', ''),
    'SQL Test Step-Up Race Person',
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
    'sql_test.step_up_race_identity_'
        || replace(:'identity_id', '-', ''),
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
    'sql_test.step_up_race_org_'
        || replace(:'organization_id', '-', ''),
    'SQL Test Step-Up Race Organization',
    'SQL Test Step-Up Race Organization',
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
    'sql_test.step_up_race_service_'
        || replace(:'service_id', '-', ''),
    'SQL Test Step-Up Race Service',
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
    :'establishment_assertion_id'::uuid,
    :'establishment_external_id',
    'SESSION_ESTABLISHMENT',
    :'trust_provider_id'::uuid,
    :'identity_id'::uuid,
    :'device_id'::uuid,
    NULL,
    :'service_id'::uuid,
    'sql-test-step-up-race-audience',
    'test',
    statement_timestamp() - interval '1 minute',
    statement_timestamp() + interval '10 minutes',
    extensions.digest(
        convert_to(:'establishment_external_id' || ':nonce', 'UTF8'),
        'sha256'
    ),
    extensions.digest(
        convert_to(:'establishment_external_id' || ':payload', 'UTF8'),
        'sha256'
    ),
    'SQL-TEST-SIGNATURE',
    decode(repeat('73', 32), 'hex'),
    statement_timestamp() - interval '30 seconds'
);

COMMIT;

SELECT access_control.mark_authentication_assertion_verified(
    :'establishment_assertion_id'::uuid,
    'sql_test.step_up_race_establishment_verifier',
    'sql_test.step_up_race_establishment_verification.v1'
) AS establishment_verified
\gset

\if :establishment_verified
\else
    \echo 'Step-up race establishment fixture could not be verified'
    \quit 3
\endif

SELECT access_control.establish_session_from_authentication_assertion(
    :'establishment_external_id',
    :'organization_id'::uuid,
    interval '4 hours',
    interval '30 minutes',
    'sql-test-step-up-race-audience',
    'test',
    gen_random_uuid()
) AS session_id
\gset

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
    :'step_up_assertion_id'::uuid,
    :'step_up_external_id',
    'SESSION_STEP_UP',
    :'trust_provider_id'::uuid,
    :'identity_id'::uuid,
    :'device_id'::uuid,
    :'session_id'::uuid,
    :'service_id'::uuid,
    'sql-test-step-up-race-audience',
    'test',
    statement_timestamp() - interval '1 minute',
    statement_timestamp() + interval '10 minutes',
    extensions.digest(
        convert_to(:'step_up_external_id' || ':nonce', 'UTF8'),
        'sha256'
    ),
    extensions.digest(
        convert_to(:'step_up_external_id' || ':payload', 'UTF8'),
        'sha256'
    ),
    'SQL-TEST-SIGNATURE',
    decode(repeat('74', 32), 'hex'),
    statement_timestamp() - interval '30 seconds'
);

SELECT access_control.mark_authentication_assertion_verified(
    :'step_up_assertion_id'::uuid,
    'sql_test.step_up_race_verifier',
    'sql_test.step_up_race_verification.v1'
) AS step_up_verified
\gset

\if :step_up_verified
\else
    \echo 'Step-up race assertion could not be verified'
    \quit 3
\endif

SELECT concat_ws(
    '|',
    :'session_id',
    :'step_up_external_id',
    :'step_up_assertion_id'
);
SQL
)"

IFS='|' read -r \
    session_id \
    step_up_external_id \
    step_up_assertion_id \
    <<<"$fixture_row"

if [[ -z "$step_up_assertion_id" ]]; then
    printf 'Could not parse step-up race fixture: %s\n' \
        "$fixture_row" >&2
    exit 65
fi

barrier_id="${test_run_id}_session_step_up_${step_up_assertion_id}"

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
    --dbname="$test_database" >"$controller_log" 2>&1 <<'SQL' &
SELECT pg_advisory_lock(
    hashtext(current_database()),
    701120
);

UPDATE sql_test.concurrency_barriers
SET controller_locked = true
WHERE barrier_id = :'barrier_id';

SET psp_test.barrier_id = :'barrier_id';

DO $controller_wait$
DECLARE
    v_deadline timestamp with time zone :=
        clock_timestamp() + interval '10 seconds';
    v_ready_count integer;
BEGIN
    LOOP
        SELECT count(*)::integer
        INTO v_ready_count
        FROM sql_test.concurrency_readiness
        WHERE barrier_id =
            current_setting('psp_test.barrier_id');

        EXIT WHEN v_ready_count = 2;

        IF clock_timestamp() >= v_deadline THEN
            RAISE EXCEPTION
                USING
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

SELECT pg_advisory_unlock(
    hashtext(current_database()),
    701120
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

    psql \
        -X \
        --no-psqlrc \
        --quiet \
        --set=ON_ERROR_STOP=1 \
        --set=details="controller_status=${controller_status}" \
        --dbname="$test_database" <<SQL
SELECT sql_test.begin_file('${test_file}');

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

    PGAPPNAME="iron-signal-platform-session-step-up-${worker_name}" \
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
        --set=session_id="$session_id" \
        --set=step_up_external_id="$step_up_external_id" \
        --dbname="$test_database" >"$output_file" 2>&1 <<'SQL'
INSERT INTO sql_test.concurrency_readiness (
    barrier_id,
    worker_name
)
VALUES (
    :'barrier_id',
    :'worker_name'
);

DO $worker_barrier$
BEGIN
    PERFORM pg_advisory_lock_shared(
        hashtext(current_database()),
        701120
    );
END;
$worker_barrier$;

DO $worker_release$
BEGIN
    PERFORM pg_advisory_unlock_shared(
        hashtext(current_database()),
        701120
    );
END;
$worker_release$;

SELECT access_control.complete_session_step_up(
    :'session_id'::uuid,
    :'step_up_external_id',
    'sql-test-step-up-race-audience',
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

    if [[ "$worker_status" -eq 0 ]] && grep -qx 't' "$output_file"; then
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
        --set=session_id="$session_id" \
        --set=step_up_assertion_id="$step_up_assertion_id" \
        --dbname="$test_database" <<'SQL'
SELECT concat_ws(
    '|',
    assertion_record.status,
    CASE WHEN assertion_record.consumed_at IS NULL THEN 0 ELSE 1 END,
    (
        SELECT count(*)
        FROM access_control.sessions AS session_record
        WHERE
            session_record.session_id = :'session_id'::uuid
            AND session_record.last_step_up_at IS NOT NULL
            AND session_record.latest_step_up_authentication_assertion_id =
                assertion_record.authentication_assertion_id
    ),
    (
        SELECT count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = :'session_id'::uuid
            AND event_record.event_type = 'STEP_UP_COMPLETED'
            AND event_record.authentication_assertion_id =
                assertion_record.authentication_assertion_id
    ),
    (
        SELECT count(*)
        FROM access_control.sessions AS session_record
        JOIN access_control.session_events AS event_record
            ON event_record.session_id = session_record.session_id
        WHERE
            session_record.session_id = :'session_id'::uuid
            AND session_record.latest_step_up_authentication_assertion_id =
                assertion_record.authentication_assertion_id
            AND event_record.event_type = 'STEP_UP_COMPLETED'
            AND event_record.authentication_assertion_id =
                assertion_record.authentication_assertion_id
            AND event_record.event_at = session_record.last_step_up_at
    )
)
FROM access_control.authentication_assertions AS assertion_record
WHERE assertion_record.authentication_assertion_id =
    :'step_up_assertion_id'::uuid;
SQL
)"

IFS='|' read -r \
    final_assertion_status \
    consumed_timestamp_count \
    session_evidence_count \
    step_up_event_count \
    linkage_count \
    <<<"$final_row"

psql \
    -X \
    --no-psqlrc \
    --quiet \
    --set=ON_ERROR_STOP=1 \
    --set=ready_count="$ready_count" \
    --set=success_count="$success_count" \
    --set=denied_count="$denied_count" \
    --set=unexpected_count="$unexpected_count" \
    --set=final_assertion_status="$final_assertion_status" \
    --set=consumed_timestamp_count="$consumed_timestamp_count" \
    --set=session_evidence_count="$session_evidence_count" \
    --set=step_up_event_count="$step_up_event_count" \
    --set=linkage_count="$linkage_count" \
    --set=worker_one_status="$worker_one_status" \
    --set=worker_two_status="$worker_two_status" \
    --set=controller_status="$controller_status" \
    --dbname="$test_database" <<'SQL'
SELECT sql_test.begin_file('120_session_step_up_single_use.sh');

SELECT sql_test.assert_equal_bigint(
    'Both session step-up race workers reached the release barrier',
    :'ready_count'::bigint,
    2
);

SELECT sql_test.assert_equal_bigint(
    'Exactly one concurrent session step-up worker succeeds',
    :'success_count'::bigint,
    1
);

SELECT sql_test.assert_equal_bigint(
    'Exactly one concurrent session step-up worker is denied',
    :'denied_count'::bigint,
    1
);

SELECT sql_test.assert_equal_bigint(
    'Session step-up race has no unexpected worker or controller error',
    :'unexpected_count'::bigint,
    0
);

SELECT sql_test.assert_true(
    'Session step-up race consumes the assertion exactly once',
    :'final_assertion_status' = 'CONSUMED'
        AND :'consumed_timestamp_count'::bigint = 1,
    format(
        'status=%s consumed_timestamp_count=%s',
        :'final_assertion_status',
        :'consumed_timestamp_count'
    )
);

SELECT sql_test.assert_equal_bigint(
    'Session step-up race records exactly one current session evidence binding',
    :'session_evidence_count'::bigint,
    1
);

SELECT sql_test.assert_equal_bigint(
    'Session step-up race writes exactly one STEP_UP_COMPLETED event',
    :'step_up_event_count'::bigint,
    1
);

SELECT sql_test.assert_equal_bigint(
    'Session step-up race preserves exact assertion timestamp and event linkage',
    :'linkage_count'::bigint,
    1
);
SQL

printf 'CONCURRENCY RESULT | ready=%s success=%s denied=%s unexpected=%s assertion=%s session_evidence=%s step_up_events=%s linkage=%s\n' \
    "$ready_count" \
    "$success_count" \
    "$denied_count" \
    "$unexpected_count" \
    "$final_assertion_status" \
    "$session_evidence_count" \
    "$step_up_event_count" \
    "$linkage_count"
