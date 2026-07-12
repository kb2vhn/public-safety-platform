-- ============================================================================
-- Phase 2 Step 4 controlled session lifecycle behavior
-- ============================================================================
--
-- Purpose:
-- Prove the positive, negative, chronology, terminality, event-consistency,
-- privilege, and trusted-search-path behavior of the Phase 2 Step 3 controlled
-- session lifecycle APIs.
--
-- This file deliberately uses the accepted controlled establishment workflow
-- to create its session fixtures. Multi-connection races remain Phase 2 Step 5.
-- ============================================================================

SELECT sql_test.begin_file(
    '120_session_lifecycle_behavior.sql'
);

CREATE FUNCTION sql_test.create_phase2_step4_session(
    p_provider_id uuid,
    p_device_id uuid,
    p_identity_id uuid,
    p_organization_id uuid,
    p_service_id uuid,
    p_fixture_key text,
    p_absolute_lifetime interval DEFAULT interval '4 hours',
    p_inactivity_timeout interval DEFAULT interval '30 minutes'
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_assertion_id uuid := pg_catalog.gen_random_uuid();
    v_external_assertion_id text :=
        'sql-test-phase2-step4-'
        || p_fixture_key
        || '-'
        || pg_catalog.gen_random_uuid()::text;
    v_verified boolean;
BEGIN
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
        v_assertion_id,
        v_external_assertion_id,
        'SESSION_ESTABLISHMENT',
        p_provider_id,
        p_identity_id,
        p_device_id,
        NULL,
        p_service_id,
        'phase2-step4-audience',
        'test',
        v_now - interval '1 minute',
        v_now + interval '10 minutes',
        extensions.digest(
            pg_catalog.convert_to(
                v_external_assertion_id || ':nonce',
                'UTF8'
            ),
            'sha256'
        ),
        extensions.digest(
            pg_catalog.convert_to(
                v_external_assertion_id || ':payload',
                'UTF8'
            ),
            'sha256'
        ),
        'SQL-TEST-SIGNATURE',
        pg_catalog.decode(pg_catalog.repeat('64', 32), 'hex'),
        v_now - interval '30 seconds'
    );

    v_verified :=
        access_control.mark_authentication_assertion_verified(
            v_assertion_id,
            'sql_test.phase2_step4_verifier',
            'sql_test.phase2_step4_verification.v1'
        );

    IF v_verified IS NOT TRUE THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'internal_error',
                MESSAGE = 'Step 4 fixture assertion did not verify';
    END IF;

    RETURN access_control.establish_session_from_authentication_assertion(
        v_external_assertion_id,
        p_organization_id,
        p_absolute_lifetime,
        p_inactivity_timeout,
        'phase2-step4-audience',
        'test',
        pg_catalog.gen_random_uuid()
    );
END;
$function$;

CREATE TEMP TABLE step4_session_fixtures (
    fixture_key text PRIMARY KEY,
    session_id uuid NOT NULL UNIQUE,
    identity_id uuid NOT NULL,
    service_id uuid NOT NULL,
    baseline_authenticated_at timestamptz NOT NULL,
    baseline_expires_at timestamptz NOT NULL,
    baseline_last_activity_at timestamptz NOT NULL,
    baseline_last_step_up_at timestamptz
) ON COMMIT PRESERVE ROWS;

CREATE TEMP TABLE step4_boolean_results (
    result_key text PRIMARY KEY,
    result_value boolean NOT NULL
) ON COMMIT PRESERVE ROWS;

DO $setup$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_suffix text :=
        pg_catalog.replace(
            pg_catalog.gen_random_uuid()::text,
            '-',
            ''
        );
    v_provider_id uuid := pg_catalog.gen_random_uuid();
    v_device_id uuid := pg_catalog.gen_random_uuid();
    v_person_id uuid := pg_catalog.gen_random_uuid();
    v_identity_id uuid := pg_catalog.gen_random_uuid();
    v_organization_id uuid := pg_catalog.gen_random_uuid();
    v_service_id uuid := pg_catalog.gen_random_uuid();
    v_session_id uuid;
    v_fixture_key text;
    v_fixture_keys text[] := ARRAY[
        'activity_success',
        'activity_monotonic',
        'activity_trust',
        'lock_cycle',
        'unlock_trust',
        'unlock_inactive',
        'early_expire',
        'absolute_expire',
        'inactivity_expire',
        'locked_expire',
        'revoke_active',
        'revoke_locked',
        'terminate_active',
        'terminate_locked',
        'terminal_guard',
        'constraint_guard'
    ];
BEGIN
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
        v_provider_id,
        'sql_test.phase2_step4_provider_' || v_suffix,
        'SQL Test Phase 2 Step 4 Trust Provider',
        'IDENTITY_PROVIDER',
        'test',
        'ACTIVE',
        v_now - interval '1 day',
        v_now + interval '1 day',
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
        v_device_id,
        'sql_test.phase2_step4_device_' || v_suffix,
        'WORKSTATION',
        'TRUSTED',
        v_now - interval '1 day',
        v_now - interval '1 day',
        v_now + interval '1 day',
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
        v_person_id,
        'sql_test.phase2_step4_person_' || v_suffix,
        'SQL Test Phase 2 Step 4 Person',
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
        v_identity_id,
        'sql_test.phase2_step4_identity_' || v_suffix,
        'HUMAN',
        v_person_id,
        'ACTIVE',
        'TEST',
        v_now - interval '1 day',
        v_now + interval '1 day',
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
        v_organization_id,
        'sql_test.phase2_step4_org_' || v_suffix,
        'SQL Test Phase 2 Step 4 Organization',
        'SQL Test Phase 2 Step 4 Organization',
        'TEST_ORGANIZATION',
        'ACTIVE',
        v_now - interval '1 day',
        v_now + interval '1 day',
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
        v_service_id,
        'sql_test.phase2_step4_service_' || v_suffix,
        'SQL Test Phase 2 Step 4 Service',
        'TEST_SERVICE',
        v_organization_id,
        'ACTIVE',
        v_now - interval '1 day',
        v_now + interval '1 day',
        'sql_test'
    );

    FOREACH v_fixture_key IN ARRAY v_fixture_keys
    LOOP
        v_session_id :=
            sql_test.create_phase2_step4_session(
                v_provider_id,
                v_device_id,
                v_identity_id,
                v_organization_id,
                v_service_id,
                v_fixture_key
            );

        INSERT INTO step4_session_fixtures (
            fixture_key,
            session_id,
            identity_id,
            service_id,
            baseline_authenticated_at,
            baseline_expires_at,
            baseline_last_activity_at,
            baseline_last_step_up_at
        )
        SELECT
            v_fixture_key,
            session_record.session_id,
            session_record.identity_id,
            session_record.service_id,
            session_record.authenticated_at,
            session_record.expires_at,
            session_record.last_activity_at,
            session_record.last_step_up_at
        FROM access_control.sessions AS session_record
        WHERE session_record.session_id = v_session_id;
    END LOOP;
END;
$setup$;

-- A distinct later SQL statement is required because activity must advance
-- beyond the establishment statement timestamp.
SELECT pg_catalog.pg_sleep(0.01);

-- ---------------------------------------------------------------------------
-- Activity checkpoints
-- ---------------------------------------------------------------------------

SELECT sql_test.assert_raises(
    'Activity rejects a null session identifier',
    $statement$
        SELECT access_control.record_session_activity(
            NULL::uuid,
            'test'
        )
    $statement$,
    '22023'
);

SELECT sql_test.assert_raises(
    'Activity rejects an invalid environment key',
    pg_catalog.format(
        $statement$
            SELECT access_control.record_session_activity(
                %L::uuid,
                'INVALID ENVIRONMENT'
            )
        $statement$,
        fixture.session_id
    ),
    '22023'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'activity_success';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'activity_success',
    access_control.record_session_activity(
        fixture.session_id,
        'test'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'activity_success';

SELECT sql_test.assert_true(
    'Activity records for an active usable session',
    result.result_value
)
FROM step4_boolean_results AS result
WHERE result.result_key = 'activity_success';

SELECT sql_test.assert_true(
    'Activity advances monotonically, preserves absolute expiration, and writes one timestamp-aligned event',
    session_record.last_activity_at
        > fixture.baseline_last_activity_at
    AND session_record.expires_at
        = fixture.baseline_expires_at
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'ACTIVITY_RECORDED'
            AND event_record.event_at =
                session_record.last_activity_at
            AND event_record.acting_identity_id =
                fixture.identity_id
            AND event_record.authentication_assertion_id
                IS NULL
    ) = 1
)
FROM step4_session_fixtures AS fixture
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
WHERE fixture.fixture_key = 'activity_success';

UPDATE access_control.sessions AS session_record
SET last_activity_at =
    pg_catalog.statement_timestamp() + interval '5 minutes'
FROM step4_session_fixtures AS fixture
WHERE
    fixture.fixture_key = 'activity_monotonic'
    AND session_record.session_id = fixture.session_id;

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'activity_monotonic',
    access_control.record_session_activity(
        fixture.session_id,
        'test'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'activity_monotonic';

SELECT sql_test.assert_true(
    'Activity refuses a nonmonotonic checkpoint and writes no event',
    result.result_value IS FALSE
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'ACTIVITY_RECORDED'
    ) = 0
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'activity_monotonic'
WHERE result.result_key = 'activity_monotonic';

UPDATE service.platform_services
SET status = 'INACTIVE'
WHERE service_id = (
    SELECT fixture.service_id
    FROM step4_session_fixtures AS fixture
    WHERE fixture.fixture_key = 'activity_trust'
);

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'activity_trust',
    access_control.record_session_activity(
        fixture.session_id,
        'test'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'activity_trust';

UPDATE service.platform_services
SET status = 'ACTIVE'
WHERE service_id = (
    SELECT fixture.service_id
    FROM step4_session_fixtures AS fixture
    WHERE fixture.fixture_key = 'activity_trust'
);

SELECT sql_test.assert_true(
    'Activity revalidates current local trust and writes no event when trust is unusable',
    result.result_value IS FALSE
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'ACTIVITY_RECORDED'
    ) = 0
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'activity_trust'
WHERE result.result_key = 'activity_trust';

-- ---------------------------------------------------------------------------
-- Lock and administrative unlock
-- ---------------------------------------------------------------------------

SELECT sql_test.assert_raises(
    'Lock rejects a malformed reason code',
    pg_catalog.format(
        $statement$
            SELECT access_control.lock_session(
                %L::uuid,
                'bad-reason',
                NULL::uuid,
                'sql_test.operator'
            )
        $statement$,
        fixture.session_id
    ),
    '22023'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'lock_cycle';

SELECT sql_test.assert_raises(
    'Lock rejects conflicting actor contexts',
    pg_catalog.format(
        $statement$
            SELECT access_control.lock_session(
                %L::uuid,
                'MANUAL_LOCK',
                %L::uuid,
                'sql_test.operator'
            )
        $statement$,
        fixture.session_id,
        fixture.identity_id
    ),
    '22023'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'lock_cycle';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'lock_cycle_lock',
    access_control.lock_session(
        fixture.session_id,
        'MANUAL_LOCK',
        NULL,
        '  sql_test.operator  '
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'lock_cycle';

SELECT sql_test.assert_true(
    'Lock transitions only ACTIVE to LOCKED and writes one attributable timestamp-aligned event',
    result.result_value
    AND session_record.status = 'LOCKED'
    AND session_record.locked_at IS NOT NULL
    AND session_record.expires_at =
        fixture.baseline_expires_at
    AND session_record.last_activity_at =
        fixture.baseline_last_activity_at
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'LOCKED'
            AND event_record.event_at =
                session_record.locked_at
            AND event_record.reason_code = 'MANUAL_LOCK'
            AND event_record.actor_reference =
                'sql_test.operator'
            AND event_record.details ->> 'previous_status'
                = 'ACTIVE'
    ) = 1
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'lock_cycle'
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
WHERE result.result_key = 'lock_cycle_lock';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'lock_cycle_second_lock',
    access_control.lock_session(
        fixture.session_id,
        'SECOND_LOCK',
        NULL,
        'sql_test.operator'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'lock_cycle';

SELECT sql_test.assert_true(
    'A locked session cannot be locked again and no duplicate lock event is written',
    result.result_value IS FALSE
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'LOCKED'
    ) = 1
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'lock_cycle'
WHERE result.result_key = 'lock_cycle_second_lock';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'lock_cycle_activity',
    access_control.record_session_activity(
        fixture.session_id,
        'test'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'lock_cycle';

SELECT sql_test.assert_true(
    'A locked session cannot record activity and no activity event is written',
    result.result_value IS FALSE
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'ACTIVITY_RECORDED'
    ) = 0
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'lock_cycle'
WHERE result.result_key = 'lock_cycle_activity';

SELECT sql_test.assert_raises(
    'Administrative unlock requires exactly one actor context',
    pg_catalog.format(
        $statement$
            SELECT access_control.unlock_session(
                %L::uuid,
                'ADMIN_UNLOCK',
                'test',
                NULL::uuid,
                NULL::text
            )
        $statement$,
        fixture.session_id
    ),
    '22023'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'lock_cycle';

SELECT sql_test.assert_raises(
    'Administrative unlock rejects an invalid environment key',
    pg_catalog.format(
        $statement$
            SELECT access_control.unlock_session(
                %L::uuid,
                'ADMIN_UNLOCK',
                'INVALID ENVIRONMENT',
                NULL::uuid,
                'sql_test.admin'
            )
        $statement$,
        fixture.session_id
    ),
    '22023'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'lock_cycle';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'lock_cycle_unlock',
    access_control.unlock_session(
        fixture.session_id,
        'ADMIN_UNLOCK',
        'test',
        NULL,
        '  sql_test.admin  '
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'lock_cycle';

SELECT sql_test.assert_true(
    'Administrative unlock transitions LOCKED to ACTIVE, records activity, preserves expiration and step-up evidence, and writes one event',
    result.result_value
    AND session_record.status = 'ACTIVE'
    AND session_record.locked_at IS NULL
    AND session_record.expires_at =
        fixture.baseline_expires_at
    AND session_record.last_step_up_at
        IS NOT DISTINCT FROM
        fixture.baseline_last_step_up_at
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'UNLOCKED'
            AND event_record.event_at =
                session_record.last_activity_at
            AND event_record.reason_code = 'ADMIN_UNLOCK'
            AND event_record.actor_reference =
                'sql_test.admin'
            AND event_record.details ->> 'previous_status'
                = 'LOCKED'
    ) = 1
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'lock_cycle'
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
WHERE result.result_key = 'lock_cycle_unlock';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'lock_cycle_second_unlock',
    access_control.unlock_session(
        fixture.session_id,
        'SECOND_UNLOCK',
        'test',
        NULL,
        'sql_test.admin'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'lock_cycle';

SELECT sql_test.assert_true(
    'An active session cannot be unlocked again and no duplicate unlock event is written',
    result.result_value IS FALSE
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'UNLOCKED'
    ) = 1
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'lock_cycle'
WHERE result.result_key = 'lock_cycle_second_unlock';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'unlock_trust_lock',
    access_control.lock_session(
        fixture.session_id,
        'TRUST_TEST_LOCK',
        NULL,
        'sql_test.operator'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'unlock_trust';

UPDATE service.platform_services
SET status = 'INACTIVE'
WHERE service_id = (
    SELECT fixture.service_id
    FROM step4_session_fixtures AS fixture
    WHERE fixture.fixture_key = 'unlock_trust'
);

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'unlock_trust_unlock',
    access_control.unlock_session(
        fixture.session_id,
        'TRUST_TEST_UNLOCK',
        'test',
        NULL,
        'sql_test.admin'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'unlock_trust';

UPDATE service.platform_services
SET status = 'ACTIVE'
WHERE service_id = (
    SELECT fixture.service_id
    FROM step4_session_fixtures AS fixture
    WHERE fixture.fixture_key = 'unlock_trust'
);

SELECT sql_test.assert_true(
    'Administrative unlock revalidates current local trust and leaves an unusable session locked without an event',
    lock_result.result_value
    AND unlock_result.result_value IS FALSE
    AND session_record.status = 'LOCKED'
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'UNLOCKED'
    ) = 0
)
FROM step4_session_fixtures AS fixture
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
JOIN step4_boolean_results AS lock_result
    ON lock_result.result_key = 'unlock_trust_lock'
JOIN step4_boolean_results AS unlock_result
    ON unlock_result.result_key = 'unlock_trust_unlock'
WHERE fixture.fixture_key = 'unlock_trust';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'unlock_inactive_lock',
    access_control.lock_session(
        fixture.session_id,
        'INACTIVITY_TEST_LOCK',
        NULL,
        'sql_test.operator'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'unlock_inactive';

UPDATE access_control.sessions AS session_record
SET
    authenticated_at =
        pg_catalog.statement_timestamp() - interval '1 hour',
    expires_at =
        pg_catalog.statement_timestamp() + interval '1 hour',
    inactivity_timeout = interval '15 minutes',
    last_activity_at =
        pg_catalog.statement_timestamp() - interval '20 minutes'
FROM step4_session_fixtures AS fixture
WHERE
    fixture.fixture_key = 'unlock_inactive'
    AND session_record.session_id = fixture.session_id;

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'unlock_inactive_unlock',
    access_control.unlock_session(
        fixture.session_id,
        'INACTIVITY_TEST_UNLOCK',
        'test',
        NULL,
        'sql_test.admin'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'unlock_inactive';

SELECT sql_test.assert_true(
    'Administrative unlock refuses an inactivity-expired session and writes no event',
    lock_result.result_value
    AND unlock_result.result_value IS FALSE
    AND session_record.status = 'LOCKED'
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'UNLOCKED'
    ) = 0
)
FROM step4_session_fixtures AS fixture
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
JOIN step4_boolean_results AS lock_result
    ON lock_result.result_key = 'unlock_inactive_lock'
JOIN step4_boolean_results AS unlock_result
    ON unlock_result.result_key = 'unlock_inactive_unlock'
WHERE fixture.fixture_key = 'unlock_inactive';

-- ---------------------------------------------------------------------------
-- Expiration
-- ---------------------------------------------------------------------------

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'early_expire',
    access_control.expire_session(
        fixture.session_id,
        NULL,
        'sql_test.expiration_worker'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'early_expire';

SELECT sql_test.assert_true(
    'Expiration before either deadline is refused and writes no event',
    result.result_value IS FALSE
    AND session_record.status = 'ACTIVE'
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'EXPIRED'
    ) = 0
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'early_expire'
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
WHERE result.result_key = 'early_expire';

UPDATE access_control.sessions AS session_record
SET
    authenticated_at =
        pg_catalog.statement_timestamp() - interval '2 hours',
    expires_at =
        pg_catalog.statement_timestamp() - interval '1 minute',
    inactivity_timeout = NULL,
    last_activity_at =
        pg_catalog.statement_timestamp() - interval '1 hour'
FROM step4_session_fixtures AS fixture
WHERE
    fixture.fixture_key = 'absolute_expire'
    AND session_record.session_id = fixture.session_id;

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'absolute_expire_activity',
    access_control.record_session_activity(
        fixture.session_id,
        'test'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'absolute_expire';

SELECT sql_test.assert_true(
    'Activity refuses an active session after its absolute deadline and writes no event',
    result.result_value IS FALSE
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'ACTIVITY_RECORDED'
    ) = 0
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'absolute_expire'
WHERE result.result_key = 'absolute_expire_activity';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'absolute_expire_transition',
    access_control.expire_session(
        fixture.session_id,
        NULL,
        'sql_test.expiration_worker'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'absolute_expire';

SELECT sql_test.assert_true(
    'Absolute expiration creates one terminal EXPIRED state and one matching cause event',
    result.result_value
    AND session_record.status = 'EXPIRED'
    AND session_record.expired_at IS NOT NULL
    AND session_record.locked_at IS NULL
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'EXPIRED'
            AND event_record.event_at =
                session_record.expired_at
            AND event_record.reason_code =
                'ABSOLUTE_TIMEOUT'
            AND event_record.details ->> 'previous_status'
                = 'ACTIVE'
    ) = 1
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'absolute_expire'
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
WHERE result.result_key = 'absolute_expire_transition';

UPDATE access_control.sessions AS session_record
SET
    authenticated_at =
        pg_catalog.statement_timestamp() - interval '2 hours',
    expires_at =
        pg_catalog.statement_timestamp() + interval '2 hours',
    inactivity_timeout = interval '15 minutes',
    last_activity_at =
        pg_catalog.statement_timestamp() - interval '20 minutes'
FROM step4_session_fixtures AS fixture
WHERE
    fixture.fixture_key = 'inactivity_expire'
    AND session_record.session_id = fixture.session_id;

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'inactivity_expire_transition',
    access_control.expire_session(
        fixture.session_id,
        NULL,
        'sql_test.expiration_worker'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'inactivity_expire';

SELECT sql_test.assert_true(
    'Inactivity expiration creates one terminal EXPIRED state and one matching cause event',
    result.result_value
    AND session_record.status = 'EXPIRED'
    AND session_record.expired_at IS NOT NULL
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'EXPIRED'
            AND event_record.event_at =
                session_record.expired_at
            AND event_record.reason_code =
                'INACTIVITY_TIMEOUT'
    ) = 1
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'inactivity_expire'
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
WHERE result.result_key = 'inactivity_expire_transition';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'locked_expire_lock',
    access_control.lock_session(
        fixture.session_id,
        'EXPIRATION_TEST_LOCK',
        NULL,
        'sql_test.operator'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'locked_expire';

UPDATE access_control.sessions AS session_record
SET
    authenticated_at =
        pg_catalog.statement_timestamp() - interval '2 hours',
    expires_at =
        pg_catalog.statement_timestamp() - interval '1 minute',
    inactivity_timeout = NULL,
    last_activity_at =
        pg_catalog.statement_timestamp() - interval '1 hour'
FROM step4_session_fixtures AS fixture
WHERE
    fixture.fixture_key = 'locked_expire'
    AND session_record.session_id = fixture.session_id;

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'locked_expire_transition',
    access_control.expire_session(
        fixture.session_id,
        NULL,
        'sql_test.expiration_worker'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'locked_expire';

SELECT sql_test.assert_true(
    'Expiration transitions a locked session, clears current lock state, and records LOCKED as the previous state',
    lock_result.result_value
    AND expire_result.result_value
    AND session_record.status = 'EXPIRED'
    AND session_record.locked_at IS NULL
    AND session_record.expired_at IS NOT NULL
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'EXPIRED'
            AND event_record.event_at =
                session_record.expired_at
            AND event_record.reason_code =
                'ABSOLUTE_TIMEOUT'
            AND event_record.details ->> 'previous_status'
                = 'LOCKED'
    ) = 1
)
FROM step4_session_fixtures AS fixture
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
JOIN step4_boolean_results AS lock_result
    ON lock_result.result_key = 'locked_expire_lock'
JOIN step4_boolean_results AS expire_result
    ON expire_result.result_key = 'locked_expire_transition'
WHERE fixture.fixture_key = 'locked_expire';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'absolute_expire_repeat',
    access_control.expire_session(
        fixture.session_id,
        NULL,
        'sql_test.expiration_worker'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'absolute_expire';

SELECT sql_test.assert_true(
    'A terminal expired session cannot expire again and no duplicate event is written',
    result.result_value IS FALSE
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'EXPIRED'
    ) = 1
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'absolute_expire'
WHERE result.result_key = 'absolute_expire_repeat';

-- ---------------------------------------------------------------------------
-- Revocation
-- ---------------------------------------------------------------------------

SELECT sql_test.assert_raises(
    'Revocation rejects a malformed reason code',
    pg_catalog.format(
        $statement$
            SELECT access_control.revoke_session(
                %L::uuid,
                'bad-reason',
                NULL::uuid,
                'sql_test.security'
            )
        $statement$,
        fixture.session_id
    ),
    '22023'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'revoke_active';

SELECT sql_test.assert_raises(
    'Revocation requires exactly one actor context',
    pg_catalog.format(
        $statement$
            SELECT access_control.revoke_session(
                %L::uuid,
                'SECURITY_REVOKE',
                NULL::uuid,
                NULL::text
            )
        $statement$,
        fixture.session_id
    ),
    '22023'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'revoke_active';

SELECT sql_test.assert_raises(
    'Revocation rejects conflicting actor contexts',
    pg_catalog.format(
        $statement$
            SELECT access_control.revoke_session(
                %L::uuid,
                'SECURITY_REVOKE',
                %L::uuid,
                'sql_test.security'
            )
        $statement$,
        fixture.session_id,
        fixture.identity_id
    ),
    '22023'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'revoke_active';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'revoke_active_transition',
    access_control.revoke_session(
        fixture.session_id,
        'SECURITY_REVOKE',
        NULL,
        '  sql_test.security  '
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'revoke_active';

SELECT sql_test.assert_true(
    'Revocation transitions an active session to terminal REVOKED and writes one attributable event',
    result.result_value
    AND session_record.status = 'REVOKED'
    AND session_record.revoked_at IS NOT NULL
    AND session_record.locked_at IS NULL
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'REVOKED'
            AND event_record.event_at =
                session_record.revoked_at
            AND event_record.reason_code =
                'SECURITY_REVOKE'
            AND event_record.actor_reference =
                'sql_test.security'
            AND event_record.details ->> 'previous_status'
                = 'ACTIVE'
    ) = 1
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'revoke_active'
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
WHERE result.result_key = 'revoke_active_transition';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'revoke_locked_lock',
    access_control.lock_session(
        fixture.session_id,
        'REVOCATION_TEST_LOCK',
        NULL,
        'sql_test.operator'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'revoke_locked';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'revoke_locked_transition',
    access_control.revoke_session(
        fixture.session_id,
        'DEVICE_TRUST_REVOKED',
        fixture.identity_id,
        NULL
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'revoke_locked';

SELECT sql_test.assert_true(
    'Revocation transitions a locked session, clears current lock state, and records its human actor',
    lock_result.result_value
    AND revoke_result.result_value
    AND session_record.status = 'REVOKED'
    AND session_record.locked_at IS NULL
    AND session_record.revoked_at IS NOT NULL
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'REVOKED'
            AND event_record.event_at =
                session_record.revoked_at
            AND event_record.reason_code =
                'DEVICE_TRUST_REVOKED'
            AND event_record.acting_identity_id =
                fixture.identity_id
            AND event_record.actor_reference IS NULL
            AND event_record.details ->> 'previous_status'
                = 'LOCKED'
    ) = 1
)
FROM step4_session_fixtures AS fixture
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
JOIN step4_boolean_results AS lock_result
    ON lock_result.result_key = 'revoke_locked_lock'
JOIN step4_boolean_results AS revoke_result
    ON revoke_result.result_key = 'revoke_locked_transition'
WHERE fixture.fixture_key = 'revoke_locked';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'revoke_active_repeat',
    access_control.revoke_session(
        fixture.session_id,
        'SECOND_REVOKE',
        NULL,
        'sql_test.security'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'revoke_active';

SELECT sql_test.assert_true(
    'A terminal revoked session cannot be revoked again and no duplicate event is written',
    result.result_value IS FALSE
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'REVOKED'
    ) = 1
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'revoke_active'
WHERE result.result_key = 'revoke_active_repeat';

-- ---------------------------------------------------------------------------
-- Termination
-- ---------------------------------------------------------------------------

SELECT sql_test.assert_raises(
    'Termination rejects a malformed reason code',
    pg_catalog.format(
        $statement$
            SELECT access_control.terminate_session(
                %L::uuid,
                'bad-reason',
                NULL::uuid,
                NULL::text
            )
        $statement$,
        fixture.session_id
    ),
    '22023'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'terminate_active';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'terminate_active_transition',
    access_control.terminate_session(
        fixture.session_id,
        'NORMAL_LOGOUT',
        NULL,
        NULL
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'terminate_active';

SELECT sql_test.assert_true(
    'Termination transitions an active session to terminal TERMINATED with one timestamp-aligned event',
    result.result_value
    AND session_record.status = 'TERMINATED'
    AND session_record.terminated_at IS NOT NULL
    AND session_record.locked_at IS NULL
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'TERMINATED'
            AND event_record.event_at =
                session_record.terminated_at
            AND event_record.reason_code =
                'NORMAL_LOGOUT'
            AND event_record.acting_identity_id IS NULL
            AND event_record.actor_reference IS NULL
            AND event_record.details ->> 'previous_status'
                = 'ACTIVE'
    ) = 1
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'terminate_active'
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
WHERE result.result_key = 'terminate_active_transition';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'terminate_locked_lock',
    access_control.lock_session(
        fixture.session_id,
        'TERMINATION_TEST_LOCK',
        NULL,
        'sql_test.operator'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'terminate_locked';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'terminate_locked_transition',
    access_control.terminate_session(
        fixture.session_id,
        'SERVICE_SHUTDOWN',
        NULL,
        'sql_test.service'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'terminate_locked';

SELECT sql_test.assert_true(
    'Termination transitions a locked session, clears current lock state, and records LOCKED as the previous state',
    lock_result.result_value
    AND terminate_result.result_value
    AND session_record.status = 'TERMINATED'
    AND session_record.locked_at IS NULL
    AND session_record.terminated_at IS NOT NULL
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'TERMINATED'
            AND event_record.event_at =
                session_record.terminated_at
            AND event_record.reason_code =
                'SERVICE_SHUTDOWN'
            AND event_record.actor_reference =
                'sql_test.service'
            AND event_record.details ->> 'previous_status'
                = 'LOCKED'
    ) = 1
)
FROM step4_session_fixtures AS fixture
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
JOIN step4_boolean_results AS lock_result
    ON lock_result.result_key = 'terminate_locked_lock'
JOIN step4_boolean_results AS terminate_result
    ON terminate_result.result_key = 'terminate_locked_transition'
WHERE fixture.fixture_key = 'terminate_locked';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'terminate_active_repeat',
    access_control.terminate_session(
        fixture.session_id,
        'SECOND_TERMINATION',
        NULL,
        NULL
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'terminate_active';

SELECT sql_test.assert_true(
    'A terminal terminated session cannot terminate again and no duplicate event is written',
    result.result_value IS FALSE
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'TERMINATED'
    ) = 1
)
FROM step4_boolean_results AS result
JOIN step4_session_fixtures AS fixture
    ON fixture.fixture_key = 'terminate_active'
WHERE result.result_key = 'terminate_active_repeat';

-- ---------------------------------------------------------------------------
-- Terminality and failed-transition event consistency
-- ---------------------------------------------------------------------------

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'terminal_guard_revoke',
    access_control.revoke_session(
        fixture.session_id,
        'TERMINAL_GUARD',
        NULL,
        'sql_test.security'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'terminal_guard';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'terminal_guard_lock',
    access_control.lock_session(
        fixture.session_id,
        'POST_TERMINAL_LOCK',
        NULL,
        'sql_test.operator'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'terminal_guard';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'terminal_guard_unlock',
    access_control.unlock_session(
        fixture.session_id,
        'POST_TERMINAL_UNLOCK',
        'test',
        NULL,
        'sql_test.admin'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'terminal_guard';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'terminal_guard_expire',
    access_control.expire_session(
        fixture.session_id,
        NULL,
        'sql_test.expiration_worker'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'terminal_guard';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'terminal_guard_terminate',
    access_control.terminate_session(
        fixture.session_id,
        'POST_TERMINAL_TERMINATE',
        NULL,
        NULL
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'terminal_guard';

INSERT INTO step4_boolean_results (
    result_key,
    result_value
)
SELECT
    'terminal_guard_activity',
    access_control.record_session_activity(
        fixture.session_id,
        'test'
    )
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'terminal_guard';

SELECT sql_test.assert_true(
    'A terminal session rejects every later lifecycle operation and failed transitions write no events',
    revoke_result.result_value
    AND lock_result.result_value IS FALSE
    AND unlock_result.result_value IS FALSE
    AND expire_result.result_value IS FALSE
    AND terminate_result.result_value IS FALSE
    AND activity_result.result_value IS FALSE
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type IN (
                'LOCKED',
                'UNLOCKED',
                'EXPIRED',
                'TERMINATED',
                'ACTIVITY_RECORDED'
            )
    ) = 0
    AND (
        SELECT pg_catalog.count(*)
        FROM access_control.session_events AS event_record
        WHERE
            event_record.session_id = fixture.session_id
            AND event_record.event_type = 'REVOKED'
    ) = 1
)
FROM step4_session_fixtures AS fixture
JOIN step4_boolean_results AS revoke_result
    ON revoke_result.result_key = 'terminal_guard_revoke'
JOIN step4_boolean_results AS lock_result
    ON lock_result.result_key = 'terminal_guard_lock'
JOIN step4_boolean_results AS unlock_result
    ON unlock_result.result_key = 'terminal_guard_unlock'
JOIN step4_boolean_results AS expire_result
    ON expire_result.result_key = 'terminal_guard_expire'
JOIN step4_boolean_results AS terminate_result
    ON terminate_result.result_key = 'terminal_guard_terminate'
JOIN step4_boolean_results AS activity_result
    ON activity_result.result_key = 'terminal_guard_activity'
WHERE fixture.fixture_key = 'terminal_guard';

-- ---------------------------------------------------------------------------
-- Row and event constraints
-- ---------------------------------------------------------------------------

SELECT sql_test.assert_raises(
    'Session state constraints reject a contradictory terminal timestamp on an ACTIVE row',
    pg_catalog.format(
        $statement$
            UPDATE access_control.sessions
            SET revoked_at = pg_catalog.statement_timestamp()
            WHERE session_id = %L::uuid
        $statement$,
        fixture.session_id
    ),
    '23514'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'constraint_guard';

SELECT sql_test.assert_true(
    'A rejected contradictory state update leaves the session ACTIVE',
    session_record.status = 'ACTIVE'
    AND session_record.revoked_at IS NULL
)
FROM step4_session_fixtures AS fixture
JOIN access_control.sessions AS session_record
    ON session_record.session_id = fixture.session_id
WHERE fixture.fixture_key = 'constraint_guard';

SELECT sql_test.assert_raises(
    'Session chronology constraints reject activity before authentication',
    pg_catalog.format(
        $statement$
            UPDATE access_control.sessions
            SET last_activity_at =
                authenticated_at - interval '1 second'
            WHERE session_id = %L::uuid
        $statement$,
        fixture.session_id
    ),
    '23514'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'constraint_guard';

SELECT sql_test.assert_raises(
    'Session event assertion-shape constraints reject CREATED without assertion evidence',
    pg_catalog.format(
        $statement$
            INSERT INTO access_control.session_events (
                session_id,
                event_type
            )
            VALUES (
                %L::uuid,
                'CREATED'
            )
        $statement$,
        fixture.session_id
    ),
    '23514'
)
FROM step4_session_fixtures AS fixture
WHERE fixture.fixture_key = 'constraint_guard';

-- ---------------------------------------------------------------------------
-- Privilege and trusted-search-path boundary
-- ---------------------------------------------------------------------------

SELECT sql_test.assert_true(
    'All nine Phase 2 session functions are unavailable to PUBLIC',
    (
        SELECT pg_catalog.count(*)
        FROM pg_catalog.pg_proc AS procedure_record
        JOIN pg_catalog.pg_namespace AS namespace_record
            ON namespace_record.oid =
                procedure_record.pronamespace
        WHERE
            namespace_record.nspname = 'access_control'
            AND procedure_record.proname = ANY (
                ARRAY[
                    'session_context_is_locally_usable',
                    'establish_session_from_authentication_assertion',
                    'complete_session_step_up',
                    'record_session_activity',
                    'lock_session',
                    'unlock_session',
                    'expire_session',
                    'revoke_session',
                    'terminate_session'
                ]
            )
    ) = 9
    AND NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS procedure_record
        JOIN pg_catalog.pg_namespace AS namespace_record
            ON namespace_record.oid =
                procedure_record.pronamespace
        WHERE
            namespace_record.nspname = 'access_control'
            AND procedure_record.proname = ANY (
                ARRAY[
                    'session_context_is_locally_usable',
                    'establish_session_from_authentication_assertion',
                    'complete_session_step_up',
                    'record_session_activity',
                    'lock_session',
                    'unlock_session',
                    'expire_session',
                    'revoke_session',
                    'terminate_session'
                ]
            )
            AND pg_catalog.has_function_privilege(
                'public',
                procedure_record.oid,
                'EXECUTE'
            )
    )
);

SELECT sql_test.assert_true(
    'All nine Phase 2 session functions use the fixed trusted search path',
    (
        SELECT pg_catalog.count(*)
        FROM pg_catalog.pg_proc AS procedure_record
        JOIN pg_catalog.pg_namespace AS namespace_record
            ON namespace_record.oid =
                procedure_record.pronamespace
        WHERE
            namespace_record.nspname = 'access_control'
            AND procedure_record.proname = ANY (
                ARRAY[
                    'session_context_is_locally_usable',
                    'establish_session_from_authentication_assertion',
                    'complete_session_step_up',
                    'record_session_activity',
                    'lock_session',
                    'unlock_session',
                    'expire_session',
                    'revoke_session',
                    'terminate_session'
                ]
            )
            AND EXISTS (
                SELECT 1
                FROM pg_catalog.unnest(
                    procedure_record.proconfig
                ) AS configuration_entry
                WHERE configuration_entry =
                    'search_path=pg_catalog, access_control'
            )
    ) = 9
);

SELECT sql_test.assert_true(
    'Phase 2 session functions do not use SECURITY DEFINER',
    NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS procedure_record
        JOIN pg_catalog.pg_namespace AS namespace_record
            ON namespace_record.oid =
                procedure_record.pronamespace
        WHERE
            namespace_record.nspname = 'access_control'
            AND procedure_record.proname = ANY (
                ARRAY[
                    'session_context_is_locally_usable',
                    'establish_session_from_authentication_assertion',
                    'complete_session_step_up',
                    'record_session_activity',
                    'lock_session',
                    'unlock_session',
                    'expire_session',
                    'revoke_session',
                    'terminate_session'
                ]
            )
            AND procedure_record.prosecdef
    )
);
