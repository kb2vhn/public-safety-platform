-- ============================================================================
-- Phase 1 Authentication Assertion sequential behavior
-- ============================================================================
--
-- Purpose:
-- Prove the complete PostgreSQL-owned Authentication Assertion verification,
-- lifecycle, exact-context, terminal-state, and privilege boundaries added in
-- Phase 1.
--
-- Concurrency is intentionally excluded from this file. The real
-- multi-connection single-use race belongs to Phase 1 Step 5.
-- ============================================================================

SELECT sql_test.begin_file(
    '100_authentication_assertion_phase1_behavior.sql'
);

-- ---------------------------------------------------------------------------
-- Test-only fixture helper
-- ---------------------------------------------------------------------------

CREATE FUNCTION sql_test.create_authentication_assertion_fixture(
    p_assertion_purpose text,
    p_trust_provider_id uuid,
    p_identity_id uuid,
    p_device_id uuid,
    p_session_id uuid,
    p_service_id uuid,
    p_audience text,
    p_environment_key text,
    p_issued_at timestamptz,
    p_expires_at timestamptz,
    p_received_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
AS $function$
DECLARE
    v_authentication_assertion_id uuid := gen_random_uuid();
    v_assertion_id text :=
        'sql-test-phase1-assertion-' || gen_random_uuid()::text;
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
        v_authentication_assertion_id,
        v_assertion_id,
        p_assertion_purpose,
        p_trust_provider_id,
        p_identity_id,
        p_device_id,
        p_session_id,
        p_service_id,
        p_audience,
        p_environment_key,
        p_issued_at,
        p_expires_at,
        extensions.digest(
            convert_to(v_assertion_id || ':nonce', 'UTF8'),
            'sha256'
        ),
        extensions.digest(
            convert_to(v_assertion_id || ':payload', 'UTF8'),
            'sha256'
        ),
        'SQL-TEST-SIGNATURE',
        decode(repeat('5a', 32), 'hex'),
        p_received_at
    );

    RETURN v_authentication_assertion_id;
END;
$function$;

CREATE FUNCTION sql_test.create_consumed_session_establishment_fixture(
    p_trust_provider_id uuid,
    p_identity_id uuid,
    p_device_id uuid,
    p_service_id uuid,
    p_authenticated_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
AS $function$
DECLARE
    v_authentication_assertion_id uuid := gen_random_uuid();
    v_assertion_id text :=
        'sql-test-phase2-session-fixture-' || gen_random_uuid()::text;
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
        received_at,
        verified_at,
        verified_by_reference,
        verification_method,
        consumed_at,
        status
    )
    VALUES (
        v_authentication_assertion_id,
        v_assertion_id,
        'SESSION_ESTABLISHMENT',
        p_trust_provider_id,
        p_identity_id,
        p_device_id,
        NULL,
        p_service_id,
        'phase2-session-fixture-audience',
        'test',
        p_authenticated_at - interval '1 minute',
        p_authenticated_at + interval '10 minutes',
        extensions.digest(
            convert_to(v_assertion_id || ':nonce', 'UTF8'),
            'sha256'
        ),
        extensions.digest(
            convert_to(v_assertion_id || ':payload', 'UTF8'),
            'sha256'
        ),
        'SQL-TEST-SIGNATURE',
        decode(repeat('4f', 32), 'hex'),
        p_authenticated_at - interval '50 seconds',
        p_authenticated_at - interval '40 seconds',
        'sql_test.fixture_verifier',
        'sql_test.fixture_verification.v1',
        p_authenticated_at,
        'CONSUMED'
    );

    RETURN v_authentication_assertion_id;
END;
$function$;

CREATE FUNCTION sql_test.assert_authentication_verification_blocked(
    p_test_name text,
    p_authentication_assertion_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_transitioned boolean;
BEGIN
    v_transitioned :=
        access_control.mark_authentication_assertion_verified(
            p_authentication_assertion_id,
            'sql_test.phase1_verifier',
            'sql_test.phase1_verification.v1'
        );

    PERFORM sql_test.assert_true(
        p_test_name,
        NOT v_transitioned
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id =
                    p_authentication_assertion_id
                AND status = 'RECEIVED'
                AND verified_at IS NULL
                AND verified_by_reference IS NULL
                AND verification_method IS NULL
        )
    );
END;
$function$;

CREATE FUNCTION sql_test.assert_authentication_consumption_denied(
    p_test_name text,
    p_assertion_id text,
    p_assertion_purpose text,
    p_trust_provider_id uuid,
    p_identity_id uuid,
    p_device_id uuid,
    p_session_id uuid,
    p_service_id uuid,
    p_audience text,
    p_environment_key text
)
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM access_control.consume_authentication_assertion(
        p_assertion_id,
        p_assertion_purpose,
        p_trust_provider_id,
        p_identity_id,
        p_device_id,
        p_session_id,
        p_service_id,
        p_audience,
        p_environment_key
    );

    PERFORM sql_test.fail(
        p_test_name,
        'The consume function unexpectedly accepted an unavailable or mismatched assertion'
    );
EXCEPTION
    WHEN SQLSTATE '28000' THEN
        PERFORM sql_test.pass(p_test_name);
    WHEN OTHERS THEN
        PERFORM sql_test.fail(
            p_test_name,
            format(
                'unexpected_sqlstate=%s message=%s',
                SQLSTATE,
                SQLERRM
            )
        );
END;
$function$;

DO $test$
DECLARE
    v_now timestamptz := statement_timestamp();
    v_suffix text := replace(gen_random_uuid()::text, '-', '');

    v_organization_id uuid := gen_random_uuid();

    v_provider_id uuid := gen_random_uuid();
    v_pending_provider_id uuid := gen_random_uuid();
    v_suspended_provider_id uuid := gen_random_uuid();
    v_expired_provider_id uuid := gen_random_uuid();
    v_other_environment_provider_id uuid := gen_random_uuid();
    v_revoked_provider_id uuid := gen_random_uuid();
    v_alternate_provider_id uuid := gen_random_uuid();

    v_person_id uuid := gen_random_uuid();
    v_identity_id uuid := gen_random_uuid();
    v_suspended_person_id uuid := gen_random_uuid();
    v_suspended_identity_id uuid := gen_random_uuid();
    v_expired_person_id uuid := gen_random_uuid();
    v_expired_identity_id uuid := gen_random_uuid();
    v_alternate_person_id uuid := gen_random_uuid();
    v_alternate_identity_id uuid := gen_random_uuid();

    v_device_id uuid := gen_random_uuid();
    v_untrusted_device_id uuid := gen_random_uuid();
    v_revoked_device_id uuid := gen_random_uuid();
    v_alternate_device_id uuid := gen_random_uuid();

    v_service_id uuid := gen_random_uuid();
    v_inactive_service_id uuid := gen_random_uuid();
    v_alternate_service_id uuid := gen_random_uuid();

    v_session_id uuid := gen_random_uuid();
    v_locked_session_id uuid := gen_random_uuid();
    v_expired_session_id uuid := gen_random_uuid();
    v_inactive_timeout_session_id uuid := gen_random_uuid();
    v_identity_mismatch_session_id uuid := gen_random_uuid();
    v_device_mismatch_session_id uuid := gen_random_uuid();
    v_provider_mismatch_session_id uuid := gen_random_uuid();
    v_service_mismatch_session_id uuid := gen_random_uuid();

    v_session_establishment_assertion_id uuid;
    v_locked_session_establishment_assertion_id uuid;
    v_expired_session_establishment_assertion_id uuid;
    v_inactive_session_establishment_assertion_id uuid;
    v_identity_mismatch_establishment_assertion_id uuid;
    v_device_mismatch_establishment_assertion_id uuid;
    v_provider_mismatch_establishment_assertion_id uuid;
    v_service_mismatch_establishment_assertion_id uuid;

    v_assertion_id uuid;
    v_external_assertion_id text;
    v_consumed_id uuid;
    v_transitioned boolean;

    v_verified_for_consumption_id uuid;
    v_verified_for_consumption_external_id text;

    v_rejected_assertion_id uuid;
    v_rejected_external_id text;

    v_verified_reject_attempt_id uuid;

    v_unexpired_assertion_id uuid;
    v_expired_received_assertion_id uuid;
    v_expired_verified_assertion_id uuid := gen_random_uuid();
    v_expired_verified_external_id text :=
        'sql-test-phase1-expired-verified-' || gen_random_uuid()::text;

    v_revoked_assertion_id uuid;
    v_revoked_external_id text;

    v_consumed_terminal_assertion_id uuid;
    v_consumed_terminal_external_id text;

BEGIN
    -- -----------------------------------------------------------------------
    -- Shared valid and invalid Foundation fixtures
    -- -----------------------------------------------------------------------

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
        'sql_test.phase1_org_' || v_suffix,
        'SQL Test Phase 1 Organization',
        'SQL Test Phase 1 Organization',
        'TEST_ORGANIZATION',
        'ACTIVE',
        v_now - interval '2 days',
        v_now + interval '2 days',
        'sql_test'
    );

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
    VALUES
        (
            v_provider_id,
            'sql_test.phase1_provider_' || v_suffix,
            'SQL Test Phase 1 Provider',
            'IDENTITY_PROVIDER',
            'test',
            'ACTIVE',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        ),
        (
            v_pending_provider_id,
            'sql_test.phase1_pending_provider_' || v_suffix,
            'SQL Test Pending Provider',
            'IDENTITY_PROVIDER',
            'test',
            'PENDING',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        ),
        (
            v_suspended_provider_id,
            'sql_test.phase1_suspended_provider_' || v_suffix,
            'SQL Test Suspended Provider',
            'IDENTITY_PROVIDER',
            'test',
            'SUSPENDED',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        ),
        (
            v_expired_provider_id,
            'sql_test.phase1_expired_provider_' || v_suffix,
            'SQL Test Out-of-Validity Provider',
            'IDENTITY_PROVIDER',
            'test',
            'ACTIVE',
            v_now - interval '3 days',
            v_now - interval '1 day',
            'sql_test'
        ),
        (
            v_other_environment_provider_id,
            'sql_test.phase1_other_env_provider_' || v_suffix,
            'SQL Test Other Environment Provider',
            'IDENTITY_PROVIDER',
            'other',
            'ACTIVE',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        ),
        (
            v_revoked_provider_id,
            'sql_test.phase1_revoked_provider_' || v_suffix,
            'SQL Test Locally Revoked Provider',
            'IDENTITY_PROVIDER',
            'test',
            'ACTIVE',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        ),
        (
            v_alternate_provider_id,
            'sql_test.phase1_alternate_provider_' || v_suffix,
            'SQL Test Alternate Provider',
            'IDENTITY_PROVIDER',
            'test',
            'ACTIVE',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        );

    INSERT INTO trust.revocations (
        revocation_id,
        object_type,
        trust_provider_id,
        reason_code,
        reason_detail,
        effective_at,
        expires_at,
        recorded_by_reference
    )
    VALUES (
        gen_random_uuid(),
        'TRUST_PROVIDER',
        v_revoked_provider_id,
        'SQL_TEST_PROVIDER_REVOCATION',
        'Phase 1 verification must honor an effective provider revocation',
        v_now - interval '1 hour',
        v_now + interval '1 hour',
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
    VALUES
        (
            v_device_id,
            'sql_test.phase1_device_' || v_suffix,
            'WORKSTATION',
            'TRUSTED',
            v_now - interval '2 days',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        ),
        (
            v_untrusted_device_id,
            'sql_test.phase1_untrusted_device_' || v_suffix,
            'WORKSTATION',
            'ENROLLED',
            v_now - interval '2 days',
            NULL,
            NULL,
            'sql_test'
        ),
        (
            v_revoked_device_id,
            'sql_test.phase1_revoked_device_' || v_suffix,
            'WORKSTATION',
            'TRUSTED',
            v_now - interval '2 days',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        ),
        (
            v_alternate_device_id,
            'sql_test.phase1_alternate_device_' || v_suffix,
            'WORKSTATION',
            'TRUSTED',
            v_now - interval '2 days',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        );

    INSERT INTO trust.revocations (
        revocation_id,
        object_type,
        device_id,
        reason_code,
        reason_detail,
        effective_at,
        expires_at,
        recorded_by_reference
    )
    VALUES (
        gen_random_uuid(),
        'DEVICE',
        v_revoked_device_id,
        'SQL_TEST_DEVICE_REVOCATION',
        'Phase 1 verification must honor an effective device revocation',
        v_now - interval '1 hour',
        v_now + interval '1 hour',
        'sql_test'
    );

    INSERT INTO identity.persons (
        person_id,
        person_key,
        display_name,
        status,
        created_by_reference
    )
    VALUES
        (
            v_person_id,
            'sql_test.phase1_person_' || v_suffix,
            'SQL Test Phase 1 Person',
            'ACTIVE',
            'sql_test'
        ),
        (
            v_suspended_person_id,
            'sql_test.phase1_suspended_person_' || v_suffix,
            'SQL Test Suspended Identity Person',
            'ACTIVE',
            'sql_test'
        ),
        (
            v_expired_person_id,
            'sql_test.phase1_expired_person_' || v_suffix,
            'SQL Test Expired Identity Person',
            'ACTIVE',
            'sql_test'
        ),
        (
            v_alternate_person_id,
            'sql_test.phase1_alternate_person_' || v_suffix,
            'SQL Test Alternate Identity Person',
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
    VALUES
        (
            v_identity_id,
            'sql_test.phase1_identity_' || v_suffix,
            'HUMAN',
            v_person_id,
            'ACTIVE',
            'TEST',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        ),
        (
            v_suspended_identity_id,
            'sql_test.phase1_suspended_identity_' || v_suffix,
            'HUMAN',
            v_suspended_person_id,
            'SUSPENDED',
            'TEST',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        ),
        (
            v_expired_identity_id,
            'sql_test.phase1_expired_identity_' || v_suffix,
            'HUMAN',
            v_expired_person_id,
            'ACTIVE',
            'TEST',
            v_now - interval '3 days',
            v_now - interval '1 day',
            'sql_test'
        ),
        (
            v_alternate_identity_id,
            'sql_test.phase1_alternate_identity_' || v_suffix,
            'HUMAN',
            v_alternate_person_id,
            'ACTIVE',
            'TEST',
            v_now - interval '2 days',
            v_now + interval '2 days',
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
    VALUES
        (
            v_service_id,
            'sql_test.phase1_service_' || v_suffix,
            'SQL Test Phase 1 Service',
            'TEST_SERVICE',
            v_organization_id,
            'ACTIVE',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        ),
        (
            v_inactive_service_id,
            'sql_test.phase1_inactive_service_' || v_suffix,
            'SQL Test Inactive Service',
            'TEST_SERVICE',
            v_organization_id,
            'SUSPENDED',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        ),
        (
            v_alternate_service_id,
            'sql_test.phase1_alternate_service_' || v_suffix,
            'SQL Test Alternate Service',
            'TEST_SERVICE',
            v_organization_id,
            'ACTIVE',
            v_now - interval '2 days',
            v_now + interval '2 days',
            'sql_test'
        );

    -- Phase 2 requires every session row to retain the consumed
    -- SESSION_ESTABLISHMENT assertion that created it. These direct Phase 1
    -- fixtures supply structurally valid historical assertion evidence.
    v_session_establishment_assertion_id :=
        sql_test.create_consumed_session_establishment_fixture(
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_service_id,
            v_now - interval '5 minutes'
        );

    v_locked_session_establishment_assertion_id :=
        sql_test.create_consumed_session_establishment_fixture(
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_service_id,
            v_now - interval '5 minutes'
        );

    v_expired_session_establishment_assertion_id :=
        sql_test.create_consumed_session_establishment_fixture(
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_service_id,
            v_now - interval '2 hours'
        );

    v_inactive_session_establishment_assertion_id :=
        sql_test.create_consumed_session_establishment_fixture(
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_service_id,
            v_now - interval '2 hours'
        );

    v_identity_mismatch_establishment_assertion_id :=
        sql_test.create_consumed_session_establishment_fixture(
            v_provider_id,
            v_alternate_identity_id,
            v_device_id,
            v_service_id,
            v_now - interval '5 minutes'
        );

    v_device_mismatch_establishment_assertion_id :=
        sql_test.create_consumed_session_establishment_fixture(
            v_provider_id,
            v_identity_id,
            v_alternate_device_id,
            v_service_id,
            v_now - interval '5 minutes'
        );

    v_provider_mismatch_establishment_assertion_id :=
        sql_test.create_consumed_session_establishment_fixture(
            v_alternate_provider_id,
            v_identity_id,
            v_device_id,
            v_service_id,
            v_now - interval '5 minutes'
        );

    v_service_mismatch_establishment_assertion_id :=
        sql_test.create_consumed_session_establishment_fixture(
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_alternate_service_id,
            v_now - interval '5 minutes'
        );

    INSERT INTO access_control.sessions (
        session_id,
        identity_id,
        organization_id,
        device_id,
        trust_provider_id,
        service_id,
        status,
        authenticated_at,
        expires_at,
        last_activity_at,
        inactivity_timeout,
        establishment_authentication_assertion_id
    )
    VALUES
        (
            v_session_id,
            v_identity_id,
            v_organization_id,
            v_device_id,
            v_provider_id,
            v_service_id,
            'ACTIVE',
            v_now - interval '5 minutes',
            v_now + interval '1 hour',
            v_now - interval '1 minute',
            interval '30 minutes',
            v_session_establishment_assertion_id
        ),
        (
            v_locked_session_id,
            v_identity_id,
            v_organization_id,
            v_device_id,
            v_provider_id,
            v_service_id,
            'ACTIVE',
            v_now - interval '5 minutes',
            v_now + interval '1 hour',
            v_now - interval '1 minute',
            interval '30 minutes',
            v_locked_session_establishment_assertion_id
        ),
        (
            v_expired_session_id,
            v_identity_id,
            v_organization_id,
            v_device_id,
            v_provider_id,
            v_service_id,
            'ACTIVE',
            v_now - interval '2 hours',
            v_now - interval '1 hour',
            v_now - interval '90 minutes',
            interval '30 minutes',
            v_expired_session_establishment_assertion_id
        ),
        (
            v_inactive_timeout_session_id,
            v_identity_id,
            v_organization_id,
            v_device_id,
            v_provider_id,
            v_service_id,
            'ACTIVE',
            v_now - interval '2 hours',
            v_now + interval '1 hour',
            v_now - interval '2 hours',
            interval '10 minutes',
            v_inactive_session_establishment_assertion_id
        ),
        (
            v_identity_mismatch_session_id,
            v_alternate_identity_id,
            v_organization_id,
            v_device_id,
            v_provider_id,
            v_service_id,
            'ACTIVE',
            v_now - interval '5 minutes',
            v_now + interval '1 hour',
            v_now - interval '1 minute',
            interval '30 minutes',
            v_identity_mismatch_establishment_assertion_id
        ),
        (
            v_device_mismatch_session_id,
            v_identity_id,
            v_organization_id,
            v_alternate_device_id,
            v_provider_id,
            v_service_id,
            'ACTIVE',
            v_now - interval '5 minutes',
            v_now + interval '1 hour',
            v_now - interval '1 minute',
            interval '30 minutes',
            v_device_mismatch_establishment_assertion_id
        ),
        (
            v_provider_mismatch_session_id,
            v_identity_id,
            v_organization_id,
            v_device_id,
            v_alternate_provider_id,
            v_service_id,
            'ACTIVE',
            v_now - interval '5 minutes',
            v_now + interval '1 hour',
            v_now - interval '1 minute',
            interval '30 minutes',
            v_provider_mismatch_establishment_assertion_id
        ),
        (
            v_service_mismatch_session_id,
            v_identity_id,
            v_organization_id,
            v_device_id,
            v_provider_id,
            v_alternate_service_id,
            'ACTIVE',
            v_now - interval '5 minutes',
            v_now + interval '1 hour',
            v_now - interval '1 minute',
            interval '30 minutes',
            v_service_mismatch_establishment_assertion_id
        );

    UPDATE access_control.sessions
    SET
        status = 'LOCKED',
        locked_at = v_now
    WHERE session_id = v_locked_session_id;

    -- -----------------------------------------------------------------------
    -- Verifier attribution validation
    -- -----------------------------------------------------------------------

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    BEGIN
        PERFORM access_control.mark_authentication_assertion_verified(
            v_assertion_id,
            '   ',
            'sql_test.phase1_verification.v1'
        );

        PERFORM sql_test.fail(
            'Empty Authentication Assertion verifier reference is rejected',
            'The verification function unexpectedly accepted an empty verifier reference'
        );
    EXCEPTION
        WHEN SQLSTATE '22023' THEN
            PERFORM sql_test.pass(
                'Empty Authentication Assertion verifier reference is rejected'
            );
        WHEN OTHERS THEN
            PERFORM sql_test.fail(
                'Empty Authentication Assertion verifier reference is rejected',
                format(
                    'unexpected_sqlstate=%s message=%s',
                    SQLSTATE,
                    SQLERRM
                )
            );
    END;

    PERFORM sql_test.assert_true(
        'Rejected verifier attribution leaves the assertion RECEIVED',
        EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id = v_assertion_id
                AND status = 'RECEIVED'
                AND verified_at IS NULL
        )
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    BEGIN
        PERFORM access_control.mark_authentication_assertion_verified(
            v_assertion_id,
            'sql_test.phase1_verifier',
            '   '
        );

        PERFORM sql_test.fail(
            'Empty Authentication Assertion verification method is rejected',
            'The verification function unexpectedly accepted an empty verification method'
        );
    EXCEPTION
        WHEN SQLSTATE '22023' THEN
            PERFORM sql_test.pass(
                'Empty Authentication Assertion verification method is rejected'
            );
        WHEN OTHERS THEN
            PERFORM sql_test.fail(
                'Empty Authentication Assertion verification method is rejected',
                format(
                    'unexpected_sqlstate=%s message=%s',
                    SQLSTATE,
                    SQLERRM
                )
            );
    END;

    -- -----------------------------------------------------------------------
    -- Trust Provider local-state verification
    -- -----------------------------------------------------------------------

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_pending_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'PENDING Trust Provider blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_suspended_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'SUSPENDED Trust Provider blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_expired_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Out-of-validity Trust Provider blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_other_environment_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Trust Provider environment mismatch blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_revoked_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Effective Trust Provider revocation blocks Authentication Assertion verification',
        v_assertion_id
    );

    -- -----------------------------------------------------------------------
    -- Identity local-state verification
    -- -----------------------------------------------------------------------

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_suspended_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'SUSPENDED identity blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_expired_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Out-of-validity identity blocks Authentication Assertion verification',
        v_assertion_id
    );

    -- -----------------------------------------------------------------------
    -- Device local-state verification
    -- -----------------------------------------------------------------------

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_untrusted_device_id,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Supplied untrusted device blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_revoked_device_id,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Effective device revocation blocks Authentication Assertion verification',
        v_assertion_id
    );

    -- A nullable device remains allowed by the current Foundation model, but
    -- a supplied device can never be ignored.
    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            NULL,
            NULL,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    v_transitioned :=
        access_control.mark_authentication_assertion_verified(
            v_assertion_id,
            'sql_test.phase1_verifier',
            'sql_test.phase1_verification.v1'
        );

    PERFORM sql_test.assert_true(
        'Device-unbound SESSION_ESTABLISHMENT assertion can verify when all represented context is valid',
        v_transitioned
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id = v_assertion_id
                AND status = 'VERIFIED'
                AND device_id IS NULL
        )
    );

    -- -----------------------------------------------------------------------
    -- Platform Service local-state verification
    -- -----------------------------------------------------------------------

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_inactive_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Inactive bound Platform Service blocks Authentication Assertion verification',
        v_assertion_id
    );

    -- -----------------------------------------------------------------------
    -- SESSION_STEP_UP local session verification
    -- -----------------------------------------------------------------------

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_STEP_UP',
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_locked_session_id,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Non-ACTIVE step-up session blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_STEP_UP',
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_expired_session_id,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Expired step-up session blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_STEP_UP',
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_inactive_timeout_session_id,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Inactive-timeout step-up session blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_STEP_UP',
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_identity_mismatch_session_id,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Step-up session identity mismatch blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_STEP_UP',
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_device_mismatch_session_id,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Step-up session device mismatch blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_STEP_UP',
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_provider_mismatch_session_id,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Step-up session Trust Provider mismatch blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_STEP_UP',
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_service_mismatch_session_id,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_authentication_verification_blocked(
        'Step-up session Platform Service mismatch blocks Authentication Assertion verification',
        v_assertion_id
    );

    v_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_STEP_UP',
            v_provider_id,
            v_identity_id,
            v_device_id,
            v_session_id,
            v_service_id,
            'phase1-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    v_transitioned :=
        access_control.mark_authentication_assertion_verified(
            v_assertion_id,
            '  sql_test.phase1_verifier  ',
            '  sql_test.phase1_verification.v1  '
        );

    PERFORM sql_test.assert_true(
        'Valid exact-context step-up assertion verifies successfully',
        v_transitioned
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id = v_assertion_id
                AND status = 'VERIFIED'
                AND verified_at IS NOT NULL
                AND verified_by_reference =
                    'sql_test.phase1_verifier'
                AND verification_method =
                    'sql_test.phase1_verification.v1'
        )
    );

    -- -----------------------------------------------------------------------
    -- Exact-context consumption and sequential replay
    -- -----------------------------------------------------------------------

    v_verified_for_consumption_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-exact-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    v_transitioned :=
        access_control.mark_authentication_assertion_verified(
            v_verified_for_consumption_id,
            'sql_test.phase1_verifier',
            'sql_test.phase1_verification.v1'
        );

    SELECT assertion_id
    INTO v_verified_for_consumption_external_id
    FROM access_control.authentication_assertions
    WHERE
        authentication_assertion_id =
            v_verified_for_consumption_id;

    PERFORM sql_test.assert_true(
        'Exact-context consumption fixture verifies successfully',
        v_transitioned
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'Wrong assertion purpose is denied at Authentication Assertion consumption',
        v_verified_for_consumption_external_id,
        'SESSION_STEP_UP',
        v_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'phase1-exact-audience',
        'test'
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'Wrong Trust Provider is denied at Authentication Assertion consumption',
        v_verified_for_consumption_external_id,
        'SESSION_ESTABLISHMENT',
        v_alternate_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'phase1-exact-audience',
        'test'
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'Wrong identity is denied at Authentication Assertion consumption',
        v_verified_for_consumption_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_alternate_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'phase1-exact-audience',
        'test'
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'Wrong device is denied at Authentication Assertion consumption',
        v_verified_for_consumption_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_alternate_device_id,
        NULL,
        v_service_id,
        'phase1-exact-audience',
        'test'
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'Wrong session is denied at Authentication Assertion consumption',
        v_verified_for_consumption_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_device_id,
        v_session_id,
        v_service_id,
        'phase1-exact-audience',
        'test'
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'Wrong Platform Service is denied at Authentication Assertion consumption',
        v_verified_for_consumption_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_alternate_service_id,
        'phase1-exact-audience',
        'test'
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'Wrong audience is denied at Authentication Assertion consumption',
        v_verified_for_consumption_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'wrong-audience',
        'test'
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'Wrong environment is denied at Authentication Assertion consumption',
        v_verified_for_consumption_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'phase1-exact-audience',
        'wrong'
    );

    PERFORM sql_test.assert_true(
        'Context mismatch attempts leave the Authentication Assertion VERIFIED',
        EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id =
                    v_verified_for_consumption_id
                AND status = 'VERIFIED'
                AND consumed_at IS NULL
        )
    );

    v_consumed_id :=
        access_control.consume_authentication_assertion(
            v_verified_for_consumption_external_id,
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-exact-audience',
            'test'
        );

    PERFORM sql_test.assert_true(
        'Exact Authentication Assertion context consumes successfully',
        v_consumed_id = v_verified_for_consumption_id
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id =
                    v_verified_for_consumption_id
                AND status = 'CONSUMED'
                AND consumed_at IS NOT NULL
                AND verified_at IS NOT NULL
        )
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'Sequential Authentication Assertion replay is denied',
        v_verified_for_consumption_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'phase1-exact-audience',
        'test'
    );

    -- -----------------------------------------------------------------------
    -- Controlled rejection
    -- -----------------------------------------------------------------------

    v_rejected_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-rejection-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    SELECT assertion_id
    INTO v_rejected_external_id
    FROM access_control.authentication_assertions
    WHERE authentication_assertion_id = v_rejected_assertion_id;

    BEGIN
        PERFORM access_control.reject_authentication_assertion(
            v_rejected_assertion_id,
            '   '
        );

        PERFORM sql_test.fail(
            'Empty Authentication Assertion rejection reason is rejected',
            'The rejection function unexpectedly accepted an empty reason'
        );
    EXCEPTION
        WHEN SQLSTATE '22023' THEN
            PERFORM sql_test.pass(
                'Empty Authentication Assertion rejection reason is rejected'
            );
        WHEN OTHERS THEN
            PERFORM sql_test.fail(
                'Empty Authentication Assertion rejection reason is rejected',
                format(
                    'unexpected_sqlstate=%s message=%s',
                    SQLSTATE,
                    SQLERRM
                )
            );
    END;

    v_transitioned :=
        access_control.reject_authentication_assertion(
            v_rejected_assertion_id,
            '  SQL test rejection  '
        );

    PERFORM sql_test.assert_true(
        'RECEIVED Authentication Assertion transitions to REJECTED with reason and chronology',
        v_transitioned
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id =
                    v_rejected_assertion_id
                AND status = 'REJECTED'
                AND rejected_at IS NOT NULL
                AND rejected_at >= received_at
                AND rejected_at < expires_at
                AND rejection_reason = 'SQL test rejection'
                AND verified_at IS NULL
                AND consumed_at IS NULL
        )
    );

    v_transitioned :=
        access_control.mark_authentication_assertion_verified(
            v_rejected_assertion_id,
            'sql_test.phase1_verifier',
            'sql_test.phase1_verification.v1'
        );

    PERFORM sql_test.assert_false(
        'REJECTED Authentication Assertion cannot transition to VERIFIED',
        v_transitioned
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'REJECTED Authentication Assertion cannot be consumed',
        v_rejected_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'phase1-rejection-audience',
        'test'
    );

    PERFORM sql_test.assert_false(
        'REJECTED Authentication Assertion cannot be rejected again',
        access_control.reject_authentication_assertion(
            v_rejected_assertion_id,
            'Second rejection'
        )
    );

    PERFORM sql_test.assert_false(
        'REJECTED Authentication Assertion cannot be revoked',
        access_control.revoke_authentication_assertion(
            v_rejected_assertion_id,
            'Revocation after rejection'
        )
    );

    PERFORM sql_test.assert_false(
        'REJECTED Authentication Assertion cannot be expired',
        access_control.expire_authentication_assertion(
            v_rejected_assertion_id
        )
    );

    v_verified_reject_attempt_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-verified-reject-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM access_control.mark_authentication_assertion_verified(
        v_verified_reject_attempt_id,
        'sql_test.phase1_verifier',
        'sql_test.phase1_verification.v1'
    );

    PERFORM sql_test.assert_false(
        'VERIFIED Authentication Assertion cannot be reclassified as REJECTED',
        access_control.reject_authentication_assertion(
            v_verified_reject_attempt_id,
            'Invalid post-verification rejection'
        )
    );

    -- -----------------------------------------------------------------------
    -- Controlled expiration
    -- -----------------------------------------------------------------------

    v_unexpired_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-unexpired-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    PERFORM sql_test.assert_false(
        'Authentication Assertion cannot expire before expires_at',
        access_control.expire_authentication_assertion(
            v_unexpired_assertion_id
        )
    );

    v_expired_received_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-expired-received-audience',
            'test',
            v_now - interval '10 minutes',
            v_now - interval '1 minute',
            v_now - interval '9 minutes'
        );

    v_transitioned :=
        access_control.expire_authentication_assertion(
            v_expired_received_assertion_id
        );

    PERFORM sql_test.assert_true(
        'Expired RECEIVED Authentication Assertion transitions to EXPIRED',
        v_transitioned
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id =
                    v_expired_received_assertion_id
                AND status = 'EXPIRED'
                AND expired_at IS NOT NULL
                AND expired_at >= expires_at
                AND verified_at IS NULL
                AND consumed_at IS NULL
        )
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
        received_at,
        verified_at,
        verified_by_reference,
        verification_method,
        status
    )
    VALUES (
        v_expired_verified_assertion_id,
        v_expired_verified_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'phase1-expired-verified-audience',
        'test',
        v_now - interval '10 minutes',
        v_now - interval '1 minute',
        extensions.digest(
            convert_to(
                v_expired_verified_external_id || ':nonce',
                'UTF8'
            ),
            'sha256'
        ),
        extensions.digest(
            convert_to(
                v_expired_verified_external_id || ':payload',
                'UTF8'
            ),
            'sha256'
        ),
        'SQL-TEST-SIGNATURE',
        decode(repeat('6b', 32), 'hex'),
        v_now - interval '9 minutes',
        v_now - interval '2 minutes',
        'sql_test.phase1_verifier',
        'sql_test.phase1_verification.v1',
        'VERIFIED'
    );

    v_transitioned :=
        access_control.expire_authentication_assertion(
            v_expired_verified_assertion_id
        );

    PERFORM sql_test.assert_true(
        'Expired VERIFIED Authentication Assertion transitions to EXPIRED and retains verification history',
        v_transitioned
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id =
                    v_expired_verified_assertion_id
                AND status = 'EXPIRED'
                AND expired_at IS NOT NULL
                AND verified_at = v_now - interval '2 minutes'
                AND verified_by_reference =
                    'sql_test.phase1_verifier'
                AND verification_method =
                    'sql_test.phase1_verification.v1'
        )
    );

    PERFORM sql_test.assert_false(
        'EXPIRED Authentication Assertion cannot be expired again',
        access_control.expire_authentication_assertion(
            v_expired_verified_assertion_id
        )
    );

    PERFORM sql_test.assert_false(
        'EXPIRED Authentication Assertion cannot be revoked',
        access_control.revoke_authentication_assertion(
            v_expired_verified_assertion_id,
            'Revocation after expiration'
        )
    );

    PERFORM sql_test.assert_false(
        'EXPIRED Authentication Assertion cannot be rejected',
        access_control.reject_authentication_assertion(
            v_expired_verified_assertion_id,
            'Rejection after expiration'
        )
    );

    PERFORM sql_test.assert_false(
        'EXPIRED Authentication Assertion cannot transition to VERIFIED',
        access_control.mark_authentication_assertion_verified(
            v_expired_verified_assertion_id,
            'sql_test.phase1_verifier',
            'sql_test.phase1_verification.v1'
        )
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'EXPIRED Authentication Assertion cannot be consumed',
        v_expired_verified_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'phase1-expired-verified-audience',
        'test'
    );

    -- -----------------------------------------------------------------------
    -- Controlled revocation
    -- -----------------------------------------------------------------------

    v_revoked_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-revocation-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    SELECT assertion_id
    INTO v_revoked_external_id
    FROM access_control.authentication_assertions
    WHERE authentication_assertion_id = v_revoked_assertion_id;

    PERFORM access_control.mark_authentication_assertion_verified(
        v_revoked_assertion_id,
        'sql_test.phase1_verifier',
        'sql_test.phase1_verification.v1'
    );

    BEGIN
        PERFORM access_control.revoke_authentication_assertion(
            v_revoked_assertion_id,
            '   '
        );

        PERFORM sql_test.fail(
            'Empty Authentication Assertion revocation reason is rejected',
            'The revocation function unexpectedly accepted an empty reason'
        );
    EXCEPTION
        WHEN SQLSTATE '22023' THEN
            PERFORM sql_test.pass(
                'Empty Authentication Assertion revocation reason is rejected'
            );
        WHEN OTHERS THEN
            PERFORM sql_test.fail(
                'Empty Authentication Assertion revocation reason is rejected',
                format(
                    'unexpected_sqlstate=%s message=%s',
                    SQLSTATE,
                    SQLERRM
                )
            );
    END;

    v_transitioned :=
        access_control.revoke_authentication_assertion(
            v_revoked_assertion_id,
            '  SQL test revocation  '
        );

    PERFORM sql_test.assert_true(
        'VERIFIED Authentication Assertion revocation preserves verification history',
        v_transitioned
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id =
                    v_revoked_assertion_id
                AND status = 'REVOKED'
                AND revoked_at IS NOT NULL
                AND revocation_reason = 'SQL test revocation'
                AND verified_at IS NOT NULL
                AND verified_by_reference =
                    'sql_test.phase1_verifier'
                AND verification_method =
                    'sql_test.phase1_verification.v1'
                AND consumed_at IS NULL
        )
    );

    PERFORM sql_test.assert_false(
        'REVOKED Authentication Assertion cannot be revoked again',
        access_control.revoke_authentication_assertion(
            v_revoked_assertion_id,
            'Second revocation'
        )
    );

    PERFORM sql_test.assert_false(
        'REVOKED Authentication Assertion cannot be rejected',
        access_control.reject_authentication_assertion(
            v_revoked_assertion_id,
            'Rejection after revocation'
        )
    );

    PERFORM sql_test.assert_false(
        'REVOKED Authentication Assertion cannot be expired',
        access_control.expire_authentication_assertion(
            v_revoked_assertion_id
        )
    );

    PERFORM sql_test.assert_false(
        'REVOKED Authentication Assertion cannot transition to VERIFIED',
        access_control.mark_authentication_assertion_verified(
            v_revoked_assertion_id,
            'sql_test.phase1_verifier',
            'sql_test.phase1_verification.v1'
        )
    );

    PERFORM sql_test.assert_authentication_consumption_denied(
        'REVOKED Authentication Assertion cannot be consumed',
        v_revoked_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'phase1-revocation-audience',
        'test'
    );

    -- -----------------------------------------------------------------------
    -- CONSUMED is terminal
    -- -----------------------------------------------------------------------

    v_consumed_terminal_assertion_id :=
        sql_test.create_authentication_assertion_fixture(
            'SESSION_ESTABLISHMENT',
            v_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'phase1-consumed-terminal-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            v_now - interval '30 seconds'
        );

    SELECT assertion_id
    INTO v_consumed_terminal_external_id
    FROM access_control.authentication_assertions
    WHERE
        authentication_assertion_id =
            v_consumed_terminal_assertion_id;

    PERFORM access_control.mark_authentication_assertion_verified(
        v_consumed_terminal_assertion_id,
        'sql_test.phase1_verifier',
        'sql_test.phase1_verification.v1'
    );

    PERFORM access_control.consume_authentication_assertion(
        v_consumed_terminal_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'phase1-consumed-terminal-audience',
        'test'
    );

    PERFORM sql_test.assert_false(
        'CONSUMED Authentication Assertion cannot be rejected',
        access_control.reject_authentication_assertion(
            v_consumed_terminal_assertion_id,
            'Rejection after consumption'
        )
    );

    PERFORM sql_test.assert_false(
        'CONSUMED Authentication Assertion cannot be expired',
        access_control.expire_authentication_assertion(
            v_consumed_terminal_assertion_id
        )
    );

    PERFORM sql_test.assert_false(
        'CONSUMED Authentication Assertion cannot be revoked',
        access_control.revoke_authentication_assertion(
            v_consumed_terminal_assertion_id,
            'Revocation after consumption'
        )
    );

    PERFORM sql_test.assert_false(
        'CONSUMED Authentication Assertion cannot transition to VERIFIED',
        access_control.mark_authentication_assertion_verified(
            v_consumed_terminal_assertion_id,
            'sql_test.phase1_verifier',
            'sql_test.phase1_verification.v1'
        )
    );

    PERFORM sql_test.assert_true(
        'CONSUMED Authentication Assertion retains one terminal consumption timestamp',
        EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE
                authentication_assertion_id =
                    v_consumed_terminal_assertion_id
                AND status = 'CONSUMED'
                AND consumed_at IS NOT NULL
                AND rejected_at IS NULL
                AND expired_at IS NULL
                AND revoked_at IS NULL
        )
    );
END;
$test$;

-- ---------------------------------------------------------------------------
-- Controlled-function privilege and search-path boundary
-- ---------------------------------------------------------------------------

SELECT sql_test.assert_no_rows(
    'Phase 1 Authentication Assertion controlled functions are unavailable to PUBLIC',
    $query$
        SELECT
            routine_schema,
            routine_name,
            privilege_type
        FROM information_schema.routine_privileges
        WHERE
            grantee = 'PUBLIC'
            AND routine_schema = 'access_control'
            AND routine_name IN (
                'mark_authentication_assertion_verified',
                'reject_authentication_assertion',
                'expire_authentication_assertion',
                'revoke_authentication_assertion',
                'consume_authentication_assertion'
            )
    $query$
);

SELECT sql_test.assert_no_rows(
    'Phase 1 Authentication Assertion controlled functions have fixed trusted search paths',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            procedure_record.proname AS function_name,
            procedure_record.proconfig
        FROM pg_catalog.pg_proc AS procedure_record
        JOIN pg_catalog.pg_namespace AS namespace_record
            ON namespace_record.oid = procedure_record.pronamespace
        WHERE
            namespace_record.nspname = 'access_control'
            AND procedure_record.proname IN (
                'mark_authentication_assertion_verified',
                'reject_authentication_assertion',
                'expire_authentication_assertion',
                'revoke_authentication_assertion',
                'consume_authentication_assertion'
            )
            AND NOT (
                procedure_record.proconfig IS NOT NULL
                AND 'search_path=pg_catalog, access_control' =
                    ANY (procedure_record.proconfig)
            )
    $query$
);

DROP FUNCTION sql_test.assert_authentication_consumption_denied(
    text,
    text,
    text,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    text
);

DROP FUNCTION sql_test.assert_authentication_verification_blocked(
    text,
    uuid
);

DROP FUNCTION sql_test.create_authentication_assertion_fixture(
    text,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    text,
    timestamptz,
    timestamptz,
    timestamptz
);

