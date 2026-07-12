-- ============================================================================
-- Phase 2 Step 2 session establishment and step-up behavior
-- ============================================================================
--
-- Purpose:
-- Execute the two assertion-dependent workflows introduced by Phase 2 Step 2
-- while preserving the complete Phase 1 regression suite. The expanded
-- hostile-condition and lifecycle matrix belongs to Phase 2 Step 4.
-- ============================================================================

SELECT sql_test.begin_file(
    '110_session_establishment_and_step_up_behavior.sql'
);

DO $test$
DECLARE
    v_now timestamptz := statement_timestamp();
    v_suffix text := replace(gen_random_uuid()::text, '-', '');

    v_provider_id uuid := gen_random_uuid();
    v_device_id uuid := gen_random_uuid();
    v_person_id uuid := gen_random_uuid();
    v_identity_id uuid := gen_random_uuid();
    v_organization_id uuid := gen_random_uuid();
    v_service_id uuid := gen_random_uuid();

    v_establishment_assertion_id uuid := gen_random_uuid();
    v_establishment_external_id text :=
        'sql-test-phase2-establishment-' || gen_random_uuid()::text;

    v_step_up_assertion_id uuid := gen_random_uuid();
    v_step_up_external_id text :=
        'sql-test-phase2-step-up-' || gen_random_uuid()::text;

    v_verified boolean;
    v_session_id uuid;
    v_step_up_completed boolean;
    v_replay_denied boolean := false;
    v_invalid_lifetime_rejected boolean := false;
    v_invalid_organization_denied boolean := false;

    v_session_before_step_up access_control.sessions%ROWTYPE;
    v_session_after_step_up access_control.sessions%ROWTYPE;
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
        'sql_test.phase2_provider_' || v_suffix,
        'SQL Test Phase 2 Trust Provider',
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
        'sql_test.phase2_device_' || v_suffix,
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
        'sql_test.phase2_person_' || v_suffix,
        'SQL Test Phase 2 Person',
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
        'sql_test.phase2_identity_' || v_suffix,
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
        'sql_test.phase2_org_' || v_suffix,
        'SQL Test Phase 2 Organization',
        'SQL Test Phase 2 Organization',
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
        'sql_test.phase2_service_' || v_suffix,
        'SQL Test Phase 2 Service',
        'TEST_SERVICE',
        v_organization_id,
        'ACTIVE',
        v_now - interval '1 day',
        v_now + interval '1 day',
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
        v_establishment_assertion_id,
        v_establishment_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'phase2-test-audience',
        'test',
        v_now - interval '1 minute',
        v_now + interval '10 minutes',
        extensions.digest(
            convert_to(v_establishment_external_id || ':nonce', 'UTF8'),
            'sha256'
        ),
        extensions.digest(
            convert_to(v_establishment_external_id || ':payload', 'UTF8'),
            'sha256'
        ),
        'SQL-TEST-SIGNATURE',
        decode(repeat('62', 32), 'hex'),
        v_now - interval '30 seconds'
    );

    v_verified :=
        access_control.mark_authentication_assertion_verified(
            v_establishment_assertion_id,
            'sql_test.phase2_verifier',
            'sql_test.phase2_verification.v1'
        );

    PERFORM sql_test.assert_true(
        'Phase 2 establishment assertion verifies through the accepted Phase 1 boundary',
        v_verified
    );

    BEGIN
        PERFORM access_control.establish_session_from_authentication_assertion(
            v_establishment_external_id,
            v_organization_id,
            interval '0 seconds',
            interval '15 minutes',
            'phase2-test-audience',
            'test',
            gen_random_uuid()
        );
    EXCEPTION
        WHEN SQLSTATE '22023' THEN
            v_invalid_lifetime_rejected := true;
    END;

    PERFORM sql_test.assert_true(
        'Session establishment rejects a nonpositive absolute lifetime',
        v_invalid_lifetime_rejected
    );

    BEGIN
        PERFORM access_control.establish_session_from_authentication_assertion(
            v_establishment_external_id,
            gen_random_uuid(),
            interval '1 hour',
            interval '15 minutes',
            'phase2-test-audience',
            'test',
            gen_random_uuid()
        );
    EXCEPTION
        WHEN SQLSTATE '28000' THEN
            v_invalid_organization_denied := true;
    END;

    PERFORM sql_test.assert_true(
        'Session establishment denies an unavailable selected organization without consuming the assertion',
        v_invalid_organization_denied
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id =
                    v_establishment_assertion_id
                AND status = 'VERIFIED'
                AND consumed_at IS NULL
        )
    );

    v_session_id :=
        access_control.establish_session_from_authentication_assertion(
            v_establishment_external_id,
            v_organization_id,
            interval '1 hour',
            interval '15 minutes',
            'phase2-test-audience',
            'test',
            gen_random_uuid()
        );

    PERFORM sql_test.assert_true(
        'Valid establishment creates one ACTIVE session with assertion-derived bindings',
        EXISTS (
            SELECT 1
            FROM access_control.sessions
            WHERE
                session_id = v_session_id
                AND status = 'ACTIVE'
                AND identity_id = v_identity_id
                AND organization_id = v_organization_id
                AND device_id = v_device_id
                AND trust_provider_id = v_provider_id
                AND service_id = v_service_id
                AND establishment_authentication_assertion_id =
                    v_establishment_assertion_id
                AND last_activity_at = authenticated_at
                AND expires_at = authenticated_at + interval '1 hour'
                AND inactivity_timeout = interval '15 minutes'
        )
    );

    PERFORM sql_test.assert_true(
        'Valid establishment consumes its Authentication Assertion in the same transaction',
        EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id =
                    v_establishment_assertion_id
                AND status = 'CONSUMED'
                AND consumed_at IS NOT NULL
        )
    );

    PERFORM sql_test.assert_true(
        'Valid establishment writes one timestamp-aligned CREATED event',
        EXISTS (
            SELECT 1
            FROM access_control.sessions AS session_record
            JOIN access_control.authentication_assertions AS assertion_record
                ON assertion_record.authentication_assertion_id =
                    session_record.establishment_authentication_assertion_id
            JOIN access_control.session_events AS event_record
                ON event_record.session_id = session_record.session_id
                AND event_record.authentication_assertion_id =
                    assertion_record.authentication_assertion_id
            WHERE
                session_record.session_id = v_session_id
                AND event_record.event_type = 'CREATED'
                AND event_record.event_at = session_record.authenticated_at
                AND assertion_record.consumed_at =
                    session_record.authenticated_at
        )
        AND (
            SELECT count(*)
            FROM access_control.session_events
            WHERE
                session_id = v_session_id
                AND event_type = 'CREATED'
        ) = 1
    );

    v_replay_denied := false;
    BEGIN
        PERFORM access_control.establish_session_from_authentication_assertion(
            v_establishment_external_id,
            v_organization_id,
            interval '1 hour',
            interval '15 minutes',
            'phase2-test-audience',
            'test',
            gen_random_uuid()
        );
    EXCEPTION
        WHEN SQLSTATE '28000' THEN
            v_replay_denied := true;
    END;

    PERFORM sql_test.assert_true(
        'Consumed establishment assertion cannot create a second session',
        v_replay_denied
        AND (
            SELECT count(*)
            FROM access_control.sessions
            WHERE establishment_authentication_assertion_id =
                v_establishment_assertion_id
        ) = 1
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
        v_step_up_assertion_id,
        v_step_up_external_id,
        'SESSION_STEP_UP',
        v_provider_id,
        v_identity_id,
        v_device_id,
        v_session_id,
        v_service_id,
        'phase2-test-audience',
        'test',
        statement_timestamp() - interval '1 minute',
        statement_timestamp() + interval '10 minutes',
        extensions.digest(
            convert_to(v_step_up_external_id || ':nonce', 'UTF8'),
            'sha256'
        ),
        extensions.digest(
            convert_to(v_step_up_external_id || ':payload', 'UTF8'),
            'sha256'
        ),
        'SQL-TEST-SIGNATURE',
        decode(repeat('63', 32), 'hex'),
        statement_timestamp() - interval '30 seconds'
    );

    v_verified :=
        access_control.mark_authentication_assertion_verified(
            v_step_up_assertion_id,
            'sql_test.phase2_verifier',
            'sql_test.phase2_verification.v1'
        );

    PERFORM sql_test.assert_true(
        'Phase 2 step-up assertion verifies against the active exact-context session',
        v_verified
    );

    SELECT *
    INTO v_session_before_step_up
    FROM access_control.sessions
    WHERE session_id = v_session_id;

    v_step_up_completed :=
        access_control.complete_session_step_up(
            v_session_id,
            v_step_up_external_id,
            'phase2-test-audience',
            'test'
        );

    SELECT *
    INTO v_session_after_step_up
    FROM access_control.sessions
    WHERE session_id = v_session_id;

    PERFORM sql_test.assert_true(
        'Valid step-up consumes the assertion and records fresh session evidence',
        v_step_up_completed
        AND v_session_after_step_up.last_step_up_at IS NOT NULL
        AND v_session_after_step_up.latest_step_up_authentication_assertion_id =
            v_step_up_assertion_id
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id = v_step_up_assertion_id
                AND status = 'CONSUMED'
                AND consumed_at = v_session_after_step_up.last_step_up_at
        )
    );

    PERFORM sql_test.assert_true(
        'Step-up preserves all immutable session bindings and absolute lifetime',
        v_session_after_step_up.identity_id =
            v_session_before_step_up.identity_id
        AND v_session_after_step_up.organization_id IS NOT DISTINCT FROM
            v_session_before_step_up.organization_id
        AND v_session_after_step_up.device_id IS NOT DISTINCT FROM
            v_session_before_step_up.device_id
        AND v_session_after_step_up.trust_provider_id =
            v_session_before_step_up.trust_provider_id
        AND v_session_after_step_up.service_id IS NOT DISTINCT FROM
            v_session_before_step_up.service_id
        AND v_session_after_step_up.correlation_id =
            v_session_before_step_up.correlation_id
        AND v_session_after_step_up.authenticated_at =
            v_session_before_step_up.authenticated_at
        AND v_session_after_step_up.expires_at =
            v_session_before_step_up.expires_at
        AND v_session_after_step_up.last_activity_at IS NOT DISTINCT FROM
            v_session_before_step_up.last_activity_at
    );

    PERFORM sql_test.assert_true(
        'Valid step-up writes one timestamp-aligned STEP_UP_COMPLETED event',
        EXISTS (
            SELECT 1
            FROM access_control.session_events
            WHERE
                session_id = v_session_id
                AND event_type = 'STEP_UP_COMPLETED'
                AND authentication_assertion_id = v_step_up_assertion_id
                AND event_at = v_session_after_step_up.last_step_up_at
        )
        AND (
            SELECT count(*)
            FROM access_control.session_events
            WHERE
                session_id = v_session_id
                AND event_type = 'STEP_UP_COMPLETED'
        ) = 1
    );

    v_replay_denied := false;
    BEGIN
        PERFORM access_control.complete_session_step_up(
            v_session_id,
            v_step_up_external_id,
            'phase2-test-audience',
            'test'
        );
    EXCEPTION
        WHEN SQLSTATE '28000' THEN
            v_replay_denied := true;
    END;

    PERFORM sql_test.assert_true(
        'Consumed step-up assertion cannot complete a second step-up',
        v_replay_denied
        AND (
            SELECT count(*)
            FROM access_control.session_events
            WHERE
                session_id = v_session_id
                AND event_type = 'STEP_UP_COMPLETED'
                AND authentication_assertion_id = v_step_up_assertion_id
        ) = 1
    );
END;
$test$;
