-- ============================================================================
-- Authentication Assertion behavior
-- ============================================================================

SELECT sql_test.begin_file('090_authentication_assertion_behavior.sql');

DO $test$
DECLARE
    v_now timestamptz := statement_timestamp();
    v_trust_provider_id uuid := gen_random_uuid();
    v_device_id uuid := gen_random_uuid();
    v_person_id uuid := gen_random_uuid();
    v_identity_id uuid := gen_random_uuid();
    v_organization_id uuid := gen_random_uuid();
    v_service_id uuid := gen_random_uuid();
    v_session_id uuid := gen_random_uuid();

    v_assertion_id uuid := gen_random_uuid();
    v_assertion_external_id text :=
        'sql-test-session-establishment-' || gen_random_uuid()::text;
    v_consumed_id uuid;
    v_transitioned boolean;

    v_revoked_assertion_id uuid := gen_random_uuid();
    v_revoked_external_id text :=
        'sql-test-revocation-' || gen_random_uuid()::text;

    v_wrong_purpose_external_id text :=
        'sql-test-purpose-binding-' || gen_random_uuid()::text;
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
        v_trust_provider_id,
        'sql_test.authentication_provider',
        'SQL Test Authentication Trust Provider',
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
        'sql_test.authentication_device',
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
        'sql_test.authentication_person',
        'SQL Test Authentication Person',
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
        'sql_test.authentication_identity',
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
        'sql_test.authentication_org',
        'SQL Test Authentication Organization',
        'SQL Test Authentication Organization',
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
        'sql_test.authentication_service',
        'SQL Test Authentication Service',
        'TEST_SERVICE',
        v_organization_id,
        'ACTIVE',
        v_now - interval '1 day',
        v_now + interval '1 day',
        'sql_test'
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
        last_activity_at
    )
    VALUES (
        v_session_id,
        v_identity_id,
        v_organization_id,
        v_device_id,
        v_trust_provider_id,
        v_service_id,
        'ACTIVE',
        v_now - interval '5 minutes',
        v_now + interval '1 hour',
        v_now
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
        v_assertion_id,
        v_assertion_external_id,
        'SESSION_ESTABLISHMENT',
        v_trust_provider_id,
        v_identity_id,
        v_device_id,
        NULL,
        v_service_id,
        'sql-test-audience',
        'test',
        v_now - interval '1 minute',
        v_now + interval '10 minutes',
        extensions.digest(
            convert_to(v_assertion_external_id || ':nonce', 'UTF8'),
            'sha256'
        ),
        extensions.digest(
            convert_to(v_assertion_external_id || ':payload', 'UTF8'),
            'sha256'
        ),
        'TEST-SIGNATURE',
        decode(repeat('11', 32), 'hex'),
        v_now - interval '30 seconds'
    );

    BEGIN
        PERFORM access_control.consume_authentication_assertion(
            v_assertion_external_id,
            'SESSION_ESTABLISHMENT',
            v_trust_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'sql-test-audience',
            'test'
        );

        PERFORM sql_test.fail(
            'RECEIVED Authentication Assertion cannot be consumed',
            'The consume function unexpectedly succeeded'
        );
    EXCEPTION
        WHEN SQLSTATE '28000' THEN
            PERFORM sql_test.pass(
                'RECEIVED Authentication Assertion cannot be consumed'
            );
        WHEN OTHERS THEN
            PERFORM sql_test.fail(
                'RECEIVED Authentication Assertion cannot be consumed',
                format(
                    'unexpected_sqlstate=%s message=%s',
                    SQLSTATE,
                    SQLERRM
                )
            );
    END;

    v_transitioned :=
        access_control.mark_authentication_assertion_verified(
            v_assertion_id,
            'sql_test.verifier',
            'sql_test.signature_and_claim_validation.v1'
        );

    PERFORM sql_test.assert_true(
        'Authentication Assertion transitions from RECEIVED to VERIFIED',
        v_transitioned
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE authentication_assertion_id = v_assertion_id
              AND status = 'VERIFIED'
              AND verified_at IS NOT NULL
        )
    );

    BEGIN
        PERFORM access_control.consume_authentication_assertion(
            v_assertion_external_id,
            'SESSION_ESTABLISHMENT',
            v_trust_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'wrong-audience',
            'test'
        );

        PERFORM sql_test.fail(
            'Authentication Assertion context mismatch is denied',
            'The consume function unexpectedly accepted the wrong audience'
        );
    EXCEPTION
        WHEN SQLSTATE '28000' THEN
            PERFORM sql_test.pass(
                'Authentication Assertion context mismatch is denied'
            );
        WHEN OTHERS THEN
            PERFORM sql_test.fail(
                'Authentication Assertion context mismatch is denied',
                format(
                    'unexpected_sqlstate=%s message=%s',
                    SQLSTATE,
                    SQLERRM
                )
            );
    END;

    v_consumed_id :=
        access_control.consume_authentication_assertion(
            v_assertion_external_id,
            'SESSION_ESTABLISHMENT',
            v_trust_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'sql-test-audience',
            'test'
        );

    PERFORM sql_test.assert_true(
        'VERIFIED Authentication Assertion is consumed with exact context',
        v_consumed_id = v_assertion_id
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE authentication_assertion_id = v_assertion_id
              AND status = 'CONSUMED'
              AND consumed_at IS NOT NULL
              AND verified_at IS NOT NULL
        )
    );

    BEGIN
        PERFORM access_control.consume_authentication_assertion(
            v_assertion_external_id,
            'SESSION_ESTABLISHMENT',
            v_trust_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'sql-test-audience',
            'test'
        );

        PERFORM sql_test.fail(
            'Consumed Authentication Assertion cannot be replayed',
            'The consume function unexpectedly succeeded twice'
        );
    EXCEPTION
        WHEN SQLSTATE '28000' THEN
            PERFORM sql_test.pass(
                'Consumed Authentication Assertion cannot be replayed'
            );
        WHEN OTHERS THEN
            PERFORM sql_test.fail(
                'Consumed Authentication Assertion cannot be replayed',
                format(
                    'unexpected_sqlstate=%s message=%s',
                    SQLSTATE,
                    SQLERRM
                )
            );
    END;

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
        v_revoked_assertion_id,
        v_revoked_external_id,
        'SESSION_STEP_UP',
        v_trust_provider_id,
        v_identity_id,
        v_device_id,
        v_session_id,
        v_service_id,
        'sql-test-audience',
        'test',
        v_now - interval '1 minute',
        v_now + interval '10 minutes',
        extensions.digest(
            convert_to(v_revoked_external_id || ':nonce', 'UTF8'),
            'sha256'
        ),
        extensions.digest(
            convert_to(v_revoked_external_id || ':payload', 'UTF8'),
            'sha256'
        ),
        'TEST-SIGNATURE',
        decode(repeat('22', 32), 'hex'),
        v_now - interval '30 seconds'
    );

    PERFORM access_control.mark_authentication_assertion_verified(
        v_revoked_assertion_id,
        'sql_test.verifier',
        'sql_test.signature_and_claim_validation.v1'
    );

    v_transitioned :=
        access_control.revoke_authentication_assertion(
            v_revoked_assertion_id,
            'SQL test revocation'
        );

    PERFORM sql_test.assert_true(
        'Revocation preserves prior Authentication Assertion verification history',
        v_transitioned
        AND EXISTS (
            SELECT 1
            FROM access_control.authentication_assertions
            WHERE authentication_assertion_id = v_revoked_assertion_id
              AND status = 'REVOKED'
              AND revoked_at IS NOT NULL
              AND verified_at IS NOT NULL
              AND verified_by_reference = 'sql_test.verifier'
              AND verification_method =
                  'sql_test.signature_and_claim_validation.v1'
        )
    );

    BEGIN
        INSERT INTO access_control.authentication_assertions (
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
            signature_value
        )
        VALUES (
            v_wrong_purpose_external_id,
            'SESSION_ESTABLISHMENT',
            v_trust_provider_id,
            v_identity_id,
            v_device_id,
            v_session_id,
            v_service_id,
            'sql-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            extensions.digest(
                convert_to(
                    v_wrong_purpose_external_id || ':nonce',
                    'UTF8'
                ),
                'sha256'
            ),
            extensions.digest(
                convert_to(
                    v_wrong_purpose_external_id || ':payload',
                    'UTF8'
                ),
                'sha256'
            ),
            'TEST-SIGNATURE',
            decode(repeat('33', 32), 'hex')
        );

        PERFORM sql_test.fail(
            'SESSION_ESTABLISHMENT assertion rejects an existing session binding',
            'The invalid assertion unexpectedly inserted'
        );
    EXCEPTION
        WHEN check_violation THEN
            PERFORM sql_test.pass(
                'SESSION_ESTABLISHMENT assertion rejects an existing session binding'
            );
        WHEN OTHERS THEN
            PERFORM sql_test.fail(
                'SESSION_ESTABLISHMENT assertion rejects an existing session binding',
                format(
                    'unexpected_sqlstate=%s message=%s',
                    SQLSTATE,
                    SQLERRM
                )
            );
    END;

    BEGIN
        INSERT INTO access_control.authentication_assertions (
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
            signature_value
        )
        VALUES (
            'sql-test-step-up-without-session-' || gen_random_uuid()::text,
            'SESSION_STEP_UP',
            v_trust_provider_id,
            v_identity_id,
            v_device_id,
            NULL,
            v_service_id,
            'sql-test-audience',
            'test',
            v_now - interval '1 minute',
            v_now + interval '10 minutes',
            extensions.digest(
                convert_to(gen_random_uuid()::text, 'UTF8'),
                'sha256'
            ),
            extensions.digest(
                convert_to(gen_random_uuid()::text, 'UTF8'),
                'sha256'
            ),
            'TEST-SIGNATURE',
            decode(repeat('44', 32), 'hex')
        );

        PERFORM sql_test.fail(
            'SESSION_STEP_UP assertion requires an existing session binding',
            'The invalid assertion unexpectedly inserted'
        );
    EXCEPTION
        WHEN check_violation THEN
            PERFORM sql_test.pass(
                'SESSION_STEP_UP assertion requires an existing session binding'
            );
        WHEN OTHERS THEN
            PERFORM sql_test.fail(
                'SESSION_STEP_UP assertion requires an existing session binding',
                format(
                    'unexpected_sqlstate=%s message=%s',
                    SQLSTATE,
                    SQLERRM
                )
            );
    END;
END;
$test$;
