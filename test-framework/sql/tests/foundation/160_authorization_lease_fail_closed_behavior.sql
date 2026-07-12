-- ============================================================================
-- Phase 3 Step 5 fail-closed authorization lease behavioral expansion
-- ============================================================================

SELECT sql_test.begin_file(
    '160_authorization_lease_fail_closed_behavior.sql'
);

CREATE TEMP TABLE step5_fixtures (
    fixture_key text PRIMARY KEY,
    provider_id uuid NOT NULL,
    device_id uuid NOT NULL,
    identity_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    service_id uuid NOT NULL,
    purpose_definition_id uuid NOT NULL,
    operation_definition_id uuid NOT NULL,
    operation_key text NOT NULL,
    session_id uuid NOT NULL,
    policy_version_id uuid NOT NULL,
    decision_id uuid NOT NULL,
    request_evaluation_id uuid NOT NULL,
    request_supporting_record_id uuid NOT NULL,
    authority_grant_id uuid,
    authority_evaluation_id uuid,
    authority_supporting_record_id uuid,
    lease_id uuid,
    secret text NOT NULL,
    use_decision_id uuid
) ON COMMIT PRESERVE ROWS;

CREATE FUNCTION sql_test.create_phase3_step5_fixture(
    p_fixture_key text,
    p_issue boolean DEFAULT true,
    p_authority_required boolean DEFAULT false,
    p_requested_lifetime interval DEFAULT interval '5 minutes',
    p_policy_lifetime interval DEFAULT interval '10 minutes',
    p_session_lifetime interval DEFAULT interval '1 hour',
    p_evidence_lifetime interval DEFAULT interval '1 hour',
    p_authority_lifetime interval DEFAULT interval '1 hour'
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_suffix text := pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', '');
    v_provider_id uuid := pg_catalog.gen_random_uuid();
    v_device_id uuid := pg_catalog.gen_random_uuid();
    v_person_id uuid := pg_catalog.gen_random_uuid();
    v_identity_id uuid := pg_catalog.gen_random_uuid();
    v_organization_id uuid := pg_catalog.gen_random_uuid();
    v_service_id uuid := pg_catalog.gen_random_uuid();
    v_purpose_id uuid := pg_catalog.gen_random_uuid();
    v_operation_id uuid := pg_catalog.gen_random_uuid();
    v_operation_key text := 'sql_test.phase3_step5_operation_' || v_suffix;
    v_assertion_id uuid := pg_catalog.gen_random_uuid();
    v_external_assertion_id text := 'sql-test-phase3-step5-' || p_fixture_key || '-' || pg_catalog.gen_random_uuid()::text;
    v_session_id uuid;
    v_policy_id uuid := pg_catalog.gen_random_uuid();
    v_policy_version_id uuid := pg_catalog.gen_random_uuid();
    v_request_stage_id uuid := pg_catalog.gen_random_uuid();
    v_authority_stage_id uuid := pg_catalog.gen_random_uuid();
    v_approval_stage_id uuid := pg_catalog.gen_random_uuid();
    v_decision_id uuid := pg_catalog.gen_random_uuid();
    v_request_evaluation_id uuid := pg_catalog.gen_random_uuid();
    v_request_supporting_id uuid := pg_catalog.gen_random_uuid();
    v_authority_definition_id uuid := pg_catalog.gen_random_uuid();
    v_authority_grant_id uuid;
    v_authority_evaluation_id uuid;
    v_authority_supporting_id uuid;
    v_secret text := 'phase3-step5-secret-' || pg_catalog.gen_random_uuid()::text;
    v_lease_id uuid;
    v_approval_order integer := CASE WHEN p_authority_required THEN 3 ELSE 2 END;
BEGIN
    INSERT INTO trust.trust_providers (
        trust_provider_id, provider_key, display_name, provider_type,
        environment_key, status, valid_from, valid_until, created_by_reference
    ) VALUES (
        v_provider_id, 'sql_test.phase3_step5_provider_' || v_suffix,
        'SQL Test Phase 3 Step 5 Provider', 'IDENTITY_PROVIDER', 'test',
        'ACTIVE', v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO trust.devices (
        device_id, device_key, device_type, status, enrolled_at,
        trusted_from, trusted_until, created_by_reference
    ) VALUES (
        v_device_id, 'sql_test.phase3_step5_device_' || v_suffix,
        'WORKSTATION', 'TRUSTED', v_now - interval '1 day',
        v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO identity.persons (
        person_id, person_key, display_name, status, created_by_reference
    ) VALUES (
        v_person_id, 'sql_test.phase3_step5_person_' || v_suffix,
        'SQL Test Phase 3 Step 5 Person', 'ACTIVE', 'sql_test'
    );

    INSERT INTO identity.identities (
        identity_id, identity_key, identity_type, person_id, status,
        assurance_level, valid_from, valid_until, created_by_reference
    ) VALUES (
        v_identity_id, 'sql_test.phase3_step5_identity_' || v_suffix,
        'HUMAN', v_person_id, 'ACTIVE', 'TEST',
        v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO organization.organizations (
        organization_id, organization_key, legal_name, display_name,
        organization_type, status, valid_from, valid_until,
        created_by_reference
    ) VALUES (
        v_organization_id, 'sql_test.phase3_step5_org_' || v_suffix,
        'SQL Test Phase 3 Step 5 Organization',
        'SQL Test Phase 3 Step 5 Organization', 'TEST_ORGANIZATION',
        'ACTIVE', v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO service.platform_services (
        service_id, service_key, display_name, service_type,
        service_owner_organization_id, status, valid_from, valid_until,
        created_by_reference
    ) VALUES (
        v_service_id, 'sql_test.phase3_step5_service_' || v_suffix,
        'SQL Test Phase 3 Step 5 Service', 'TEST_SERVICE',
        v_organization_id, 'ACTIVE', v_now - interval '1 day',
        v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO access_control.purpose_definitions (
        purpose_definition_id, purpose_key, title, description, status
    ) VALUES (
        v_purpose_id, 'sql_test.phase3_step5_purpose_' || v_suffix,
        'SQL Test Phase 3 Step 5 Purpose',
        'SQL Test Phase 3 Step 5 Purpose', 'ACTIVE'
    );

    INSERT INTO access_control.operation_definitions (
        operation_definition_id, operation_key, title, description, status
    ) VALUES (
        v_operation_id, v_operation_key,
        'SQL Test Phase 3 Step 5 Operation',
        'SQL Test Phase 3 Step 5 Operation', 'ACTIVE'
    );

    INSERT INTO access_control.authentication_assertions (
        authentication_assertion_id, assertion_id, assertion_purpose,
        trust_provider_id, identity_id, device_id, session_id, service_id,
        audience, environment_key, issued_at, expires_at, nonce_hash,
        payload_hash, signature_algorithm, signature_value, received_at
    ) VALUES (
        v_assertion_id, v_external_assertion_id, 'SESSION_ESTABLISHMENT',
        v_provider_id, v_identity_id, v_device_id, NULL, v_service_id,
        'phase3-step5-session', 'test', v_now - interval '1 minute',
        v_now + interval '10 minutes',
        extensions.digest(pg_catalog.convert_to(v_external_assertion_id || ':nonce', 'UTF8'), 'sha256'),
        extensions.digest(pg_catalog.convert_to(v_external_assertion_id || ':payload', 'UTF8'), 'sha256'),
        'SQL-TEST-SIGNATURE', pg_catalog.decode(pg_catalog.repeat('65', 32), 'hex'),
        v_now - interval '30 seconds'
    );

    PERFORM access_control.mark_authentication_assertion_verified(
        v_assertion_id,
        'sql_test.phase3_step5_verifier',
        'sql_test.phase3_step5.v1'
    );

    v_session_id := access_control.establish_session_from_authentication_assertion(
        v_external_assertion_id, v_organization_id, p_session_lifetime,
        interval '30 minutes', 'phase3-step5-session', 'test',
        pg_catalog.gen_random_uuid()
    );

    INSERT INTO access_control.authorization_policies (
        authorization_policy_id, policy_key, title, description, status
    ) VALUES (
        v_policy_id, 'sql_test.phase3_step5_policy_' || v_suffix,
        'SQL Test Phase 3 Step 5 Policy',
        'SQL Test Phase 3 Step 5 Policy', 'ACTIVE'
    );

    INSERT INTO access_control.authorization_policy_versions (
        authorization_policy_version_id, authorization_policy_id,
        version_number, decision_class, service_id, purpose_definition_id,
        operation_definition_id, requester_organization_id,
        governed_scope_required, protected_target_required,
        protected_target_type, protected_target_reference,
        session_required, eligibility_required, lease_use_mode,
        lease_lifetime, lease_usage_limit, lease_audience, status,
        valid_from, valid_until, governing_document_reference,
        governing_document_version, selection_priority
    ) VALUES (
        v_policy_version_id, v_policy_id, 1, 'LEASE_ISSUANCE',
        v_service_id, v_purpose_id, v_operation_id, v_organization_id,
        false, true, 'TEST_RESOURCE', p_fixture_key, true, false,
        'REUSABLE', p_policy_lifetime, NULL,
        'phase3-step5-protected-consumer', 'ACTIVE',
        v_now - interval '1 day', v_now + interval '1 day',
        'sql-test-phase3-step5-policy', '1', 100
    );

    INSERT INTO access_control.authorization_policy_stage_requirements (
        authorization_policy_stage_requirement_id,
        authorization_policy_version_id, stage_order, stage_key, required,
        not_required_reason_code, not_required_rule_reference,
        supporting_record_required
    ) VALUES (
        v_request_stage_id, v_policy_version_id, 1, 'REQUEST_CONTEXT',
        true, NULL, NULL, true
    );

    IF p_authority_required THEN
        INSERT INTO access_control.authorization_policy_stage_requirements (
            authorization_policy_stage_requirement_id,
            authorization_policy_version_id, stage_order, stage_key, required,
            not_required_reason_code, not_required_rule_reference,
            supporting_record_required
        ) VALUES (
            v_authority_stage_id, v_policy_version_id, 2, 'AUTHORITY',
            true, NULL, NULL, true
        );
    END IF;

    INSERT INTO access_control.authorization_policy_stage_requirements (
        authorization_policy_stage_requirement_id,
        authorization_policy_version_id, stage_order, stage_key, required,
        not_required_reason_code, not_required_rule_reference,
        supporting_record_required
    ) VALUES (
        v_approval_stage_id, v_policy_version_id, v_approval_order, 'APPROVAL',
        false, 'APPROVAL_NOT_REQUIRED',
        'sql-test-rule-approval-not-required', false
    );

    INSERT INTO decision.decision_records (
        decision_id, request_id, correlation_id, decision_class,
        requester_identity_id, requester_organization_id, session_id,
        device_id, service_id, purpose_definition_id,
        operation_definition_id, operation_key, protected_target_type,
        protected_target_reference, requested_at, evaluated_at,
        evaluator_name, evaluator_version, database_schema_version,
        requested_lease_lifetime, requested_use_mode,
        requested_usage_limit, lease_audience
    ) VALUES (
        v_decision_id, pg_catalog.gen_random_uuid(), pg_catalog.gen_random_uuid(),
        'LEASE_ISSUANCE', v_identity_id, v_organization_id, v_session_id,
        v_device_id, v_service_id, v_purpose_id, v_operation_id,
        v_operation_key, 'TEST_RESOURCE', p_fixture_key,
        v_now, v_now, 'sql_test.phase3_step5', '1', '081-step5',
        p_requested_lifetime, 'REUSABLE', NULL,
        'phase3-step5-protected-consumer'
    );

    PERFORM decision.bind_authorization_policy(v_decision_id);

    INSERT INTO decision.evaluation_records (
        evaluation_id, decision_id, evaluation_order, evaluation_key,
        required, result, reason_code, evaluated_at,
        authorization_policy_version_id,
        authorization_policy_stage_requirement_id
    ) VALUES (
        v_request_evaluation_id, v_decision_id, 1, 'REQUEST_CONTEXT',
        true, 'PASS', 'REQUEST_CONTEXT_VALID', v_now,
        v_policy_version_id, v_request_stage_id
    );

    INSERT INTO decision.supporting_records (
        supporting_record_id, evaluation_id, record_type, record_id,
        record_version, effective_from, effective_until,
        required_for_result
    ) VALUES (
        v_request_supporting_id, v_request_evaluation_id,
        'REQUEST_CONTEXT', p_fixture_key, '1',
        v_now - interval '1 minute', v_now + p_evidence_lifetime, true
    );

    IF p_authority_required THEN
        v_authority_grant_id := pg_catalog.gen_random_uuid();
        v_authority_evaluation_id := pg_catalog.gen_random_uuid();
        v_authority_supporting_id := pg_catalog.gen_random_uuid();

        INSERT INTO access_control.authority_definitions (
            authority_definition_id, authority_key, title, description,
            status, delegation_allowed
        ) VALUES (
            v_authority_definition_id,
            'sql_test.phase3_step5_authority_' || v_suffix,
            'SQL Test Phase 3 Step 5 Authority',
            'SQL Test Phase 3 Step 5 Authority', 'ACTIVE', false
        );

        INSERT INTO access_control.authority_grants (
            authority_grant_id, identity_id, authority_definition_id,
            purpose_definition_id, operation_definition_id, service_id,
            organization_id, applies_to_all_governed_scopes,
            protected_target_type, protected_target_reference,
            applies_to_all_targets, scope_reference, status,
            valid_from, valid_until
        ) VALUES (
            v_authority_grant_id, v_identity_id, v_authority_definition_id,
            v_purpose_id, v_operation_id, v_service_id, v_organization_id,
            true, 'TEST_RESOURCE', p_fixture_key, false, NULL, 'ACTIVE',
            v_now - interval '1 day', v_now + p_authority_lifetime
        );

        INSERT INTO decision.evaluation_records (
            evaluation_id, decision_id, evaluation_order, evaluation_key,
            required, result, reason_code, evaluated_at,
            authorization_policy_version_id,
            authorization_policy_stage_requirement_id
        ) VALUES (
            v_authority_evaluation_id, v_decision_id, 2, 'AUTHORITY',
            true, 'PASS', 'AUTHORITY_CURRENT', v_now,
            v_policy_version_id, v_authority_stage_id
        );

        INSERT INTO decision.supporting_records (
            supporting_record_id, evaluation_id, record_type, record_id,
            record_version, effective_from, effective_until,
            required_for_result
        ) VALUES (
            v_authority_supporting_id, v_authority_evaluation_id,
            'AUTHORITY_GRANT', v_authority_grant_id::text, '1',
            v_now - interval '1 minute', v_now + p_authority_lifetime, true
        );
    END IF;

    INSERT INTO decision.evaluation_records (
        decision_id, evaluation_order, evaluation_key, required, result,
        reason_code, evaluated_at, authorization_policy_version_id,
        authorization_policy_stage_requirement_id, policy_rule_reference
    ) VALUES (
        v_decision_id, v_approval_order, 'APPROVAL', false, 'NOT_REQUIRED',
        'APPROVAL_NOT_REQUIRED', v_now, v_policy_version_id,
        v_approval_stage_id, 'sql-test-rule-approval-not-required'
    );

    PERFORM decision.finalize_authorization_decision(v_decision_id);

    INSERT INTO pg_temp.step5_fixtures (
        fixture_key, provider_id, device_id, identity_id, organization_id,
        service_id, purpose_definition_id, operation_definition_id,
        operation_key, session_id, policy_version_id, decision_id,
        request_evaluation_id, request_supporting_record_id,
        authority_grant_id, authority_evaluation_id,
        authority_supporting_record_id, lease_id, secret, use_decision_id
    ) VALUES (
        p_fixture_key, v_provider_id, v_device_id, v_identity_id,
        v_organization_id, v_service_id, v_purpose_id, v_operation_id,
        v_operation_key, v_session_id, v_policy_version_id, v_decision_id,
        v_request_evaluation_id, v_request_supporting_id,
        v_authority_grant_id, v_authority_evaluation_id,
        v_authority_supporting_id, NULL, v_secret, NULL
    );

    IF p_issue THEN
        v_lease_id := access_control.issue_authorization_lease_from_decision(
            v_decision_id, v_secret
        );
        UPDATE pg_temp.step5_fixtures
        SET lease_id = v_lease_id
        WHERE fixture_key = p_fixture_key;
    END IF;

    RETURN v_decision_id;
END;
$function$;

CREATE FUNCTION sql_test.phase3_step5_lease_is_usable(
    p_fixture_key text
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_fixture pg_temp.step5_fixtures%ROWTYPE;
BEGIN
    SELECT * INTO STRICT v_fixture
    FROM pg_temp.step5_fixtures
    WHERE fixture_key = p_fixture_key;

    RETURN access_control.authorization_lease_context_is_usable(
        v_fixture.lease_id, v_fixture.secret, v_fixture.identity_id,
        v_fixture.organization_id, v_fixture.session_id,
        v_fixture.device_id, v_fixture.service_id,
        v_fixture.purpose_definition_id, v_fixture.operation_definition_id,
        'TEST_RESOURCE', v_fixture.fixture_key, NULL, NULL,
        v_fixture.policy_version_id,
        'phase3-step5-protected-consumer'
    );
END;
$function$;

CREATE FUNCTION sql_test.create_phase3_step5_use_decision(
    p_fixture_key text,
    p_record_status text DEFAULT 'FINALIZED',
    p_final_result text DEFAULT 'ALLOW',
    p_target_reference text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_fixture pg_temp.step5_fixtures%ROWTYPE;
    v_use_decision_id uuid := pg_catalog.gen_random_uuid();
BEGIN
    SELECT * INTO STRICT v_fixture
    FROM pg_temp.step5_fixtures
    WHERE fixture_key = p_fixture_key;

    INSERT INTO decision.decision_records (
        decision_id, request_id, correlation_id, decision_class,
        requester_identity_id, requester_organization_id, session_id,
        device_id, service_id, purpose_definition_id,
        operation_definition_id, operation_key, protected_target_type,
        protected_target_reference, requested_at, evaluated_at,
        evaluator_name, evaluator_version, database_schema_version,
        authorization_policy_version_id, authorization_lease_id,
        record_status, final_result, primary_reason_code, finalized_at
    ) VALUES (
        v_use_decision_id, pg_catalog.gen_random_uuid(),
        pg_catalog.gen_random_uuid(), 'PROTECTED_OPERATION',
        v_fixture.identity_id, v_fixture.organization_id,
        v_fixture.session_id, v_fixture.device_id, v_fixture.service_id,
        v_fixture.purpose_definition_id, v_fixture.operation_definition_id,
        v_fixture.operation_key, 'TEST_RESOURCE',
        COALESCE(p_target_reference, v_fixture.fixture_key),
        v_now, v_now, 'sql_test.phase3_step5', '1', '081-step5',
        v_fixture.policy_version_id, v_fixture.lease_id,
        p_record_status,
        CASE WHEN p_record_status = 'FINALIZED' THEN p_final_result ELSE NULL END,
        CASE
            WHEN p_record_status <> 'FINALIZED' THEN NULL
            WHEN p_final_result = 'ALLOW' THEN 'AUTHORIZATION_DECISION_ALLOWED'
            ELSE 'SQL_TEST_OPERATION_DENIED'
        END,
        CASE WHEN p_record_status = 'FINALIZED' THEN v_now ELSE NULL END
    );

    UPDATE pg_temp.step5_fixtures
    SET use_decision_id = v_use_decision_id
    WHERE fixture_key = p_fixture_key;

    RETURN v_use_decision_id;
END;
$function$;

CREATE FUNCTION sql_test.consume_phase3_step5_fixture(
    p_fixture_key text,
    p_request_id_override uuid DEFAULT NULL,
    p_correlation_id_override uuid DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_fixture pg_temp.step5_fixtures%ROWTYPE;
    v_request_id uuid;
    v_correlation_id uuid;
BEGIN
    SELECT * INTO STRICT v_fixture
    FROM pg_temp.step5_fixtures
    WHERE fixture_key = p_fixture_key;

    SELECT request_id, correlation_id
    INTO STRICT v_request_id, v_correlation_id
    FROM decision.decision_records
    WHERE decision_id = v_fixture.use_decision_id;

    RETURN access_control.consume_authorization_lease(
        v_fixture.lease_id, v_fixture.secret,
        COALESCE(p_request_id_override, v_request_id),
        v_fixture.identity_id, v_fixture.organization_id,
        v_fixture.session_id, v_fixture.device_id, v_fixture.service_id,
        v_fixture.purpose_definition_id, v_fixture.operation_definition_id,
        'TEST_RESOURCE', v_fixture.fixture_key, NULL, NULL,
        v_fixture.policy_version_id,
        'phase3-step5-protected-consumer', v_fixture.use_decision_id,
        COALESCE(p_correlation_id_override, v_correlation_id)
    );
END;
$function$;

DO $create_step5_fixtures$
DECLARE
    v_key text;
BEGIN
    FOREACH v_key IN ARRAY ARRAY[
        'issue_locked_session', 'issue_suspended_identity',
        'issue_revoked_device', 'issue_suspended_provider',
        'issue_suspended_service', 'issue_suspended_policy',
        'issue_expired_evidence'
    ] LOOP
        PERFORM sql_test.create_phase3_step5_fixture(v_key, false, false);
    END LOOP;

    PERFORM sql_test.create_phase3_step5_fixture(
        'issue_revoked_authority', false, true
    );

    FOREACH v_key IN ARRAY ARRAY[
        'use_locked_session', 'use_suspended_identity',
        'use_revoked_device', 'use_suspended_provider',
        'use_suspended_service', 'use_suspended_policy',
        'use_expired_evidence'
    ] LOOP
        PERFORM sql_test.create_phase3_step5_fixture(v_key, true, false);
    END LOOP;

    FOREACH v_key IN ARRAY ARRAY[
        'use_revoked_authority', 'use_retargeted_authority',
        'use_missing_authority_link'
    ] LOOP
        PERFORM sql_test.create_phase3_step5_fixture(v_key, true, true);
    END LOOP;

    FOREACH v_key IN ARRAY ARRAY[
        'consume_wrong_request', 'consume_wrong_correlation',
        'consume_draft_decision', 'consume_deny_decision',
        'consume_wrong_target'
    ] LOOP
        PERFORM sql_test.create_phase3_step5_fixture(v_key, true, false);
    END LOOP;
END;
$create_step5_fixtures$;

UPDATE access_control.sessions
SET status = 'LOCKED', locked_at = pg_catalog.statement_timestamp()
WHERE session_id = (
    SELECT session_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'issue_locked_session'
);

UPDATE identity.identities
SET status = 'SUSPENDED'
WHERE identity_id = (
    SELECT identity_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'issue_suspended_identity'
);

UPDATE trust.devices
SET status = 'REVOKED'
WHERE device_id = (
    SELECT device_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'issue_revoked_device'
);

UPDATE trust.trust_providers
SET status = 'SUSPENDED'
WHERE trust_provider_id = (
    SELECT provider_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'issue_suspended_provider'
);

UPDATE service.platform_services
SET status = 'SUSPENDED'
WHERE service_id = (
    SELECT service_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'issue_suspended_service'
);

UPDATE access_control.authorization_policy_versions
SET status = 'SUSPENDED'
WHERE authorization_policy_version_id = (
    SELECT policy_version_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'issue_suspended_policy'
);

UPDATE decision.supporting_records
SET effective_until = pg_catalog.statement_timestamp() - interval '1 second'
WHERE supporting_record_id = (
    SELECT request_supporting_record_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'issue_expired_evidence'
);

UPDATE access_control.authority_grants
SET status = 'REVOKED'
WHERE authority_grant_id = (
    SELECT authority_grant_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'issue_revoked_authority'
);

SELECT sql_test.assert_raises(
    'Locked session blocks lease issuance',
    format(
        'SELECT access_control.issue_authorization_lease_from_decision(%L::uuid, %L)',
        (SELECT decision_id FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_locked_session'),
        (SELECT secret FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_locked_session')
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Suspended identity blocks lease issuance',
    format(
        'SELECT access_control.issue_authorization_lease_from_decision(%L::uuid, %L)',
        (SELECT decision_id FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_suspended_identity'),
        (SELECT secret FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_suspended_identity')
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Revoked device blocks lease issuance',
    format(
        'SELECT access_control.issue_authorization_lease_from_decision(%L::uuid, %L)',
        (SELECT decision_id FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_revoked_device'),
        (SELECT secret FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_revoked_device')
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Suspended Trust Provider blocks lease issuance',
    format(
        'SELECT access_control.issue_authorization_lease_from_decision(%L::uuid, %L)',
        (SELECT decision_id FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_suspended_provider'),
        (SELECT secret FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_suspended_provider')
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Suspended Platform Service blocks lease issuance',
    format(
        'SELECT access_control.issue_authorization_lease_from_decision(%L::uuid, %L)',
        (SELECT decision_id FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_suspended_service'),
        (SELECT secret FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_suspended_service')
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Suspended policy version blocks lease issuance',
    format(
        'SELECT access_control.issue_authorization_lease_from_decision(%L::uuid, %L)',
        (SELECT decision_id FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_suspended_policy'),
        (SELECT secret FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_suspended_policy')
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Expired required evidence blocks lease issuance',
    format(
        'SELECT access_control.issue_authorization_lease_from_decision(%L::uuid, %L)',
        (SELECT decision_id FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_expired_evidence'),
        (SELECT secret FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_expired_evidence')
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Revoked required authority blocks lease issuance',
    format(
        'SELECT access_control.issue_authorization_lease_from_decision(%L::uuid, %L)',
        (SELECT decision_id FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_revoked_authority'),
        (SELECT secret FROM pg_temp.step5_fixtures WHERE fixture_key = 'issue_revoked_authority')
    ),
    '28000'
);

UPDATE access_control.sessions
SET status = 'LOCKED', locked_at = pg_catalog.statement_timestamp()
WHERE session_id = (
    SELECT session_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'use_locked_session'
);

UPDATE identity.identities
SET status = 'SUSPENDED'
WHERE identity_id = (
    SELECT identity_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'use_suspended_identity'
);

UPDATE trust.devices
SET status = 'REVOKED'
WHERE device_id = (
    SELECT device_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'use_revoked_device'
);

UPDATE trust.trust_providers
SET status = 'SUSPENDED'
WHERE trust_provider_id = (
    SELECT provider_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'use_suspended_provider'
);

UPDATE service.platform_services
SET status = 'SUSPENDED'
WHERE service_id = (
    SELECT service_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'use_suspended_service'
);

UPDATE access_control.authorization_policy_versions
SET status = 'SUSPENDED'
WHERE authorization_policy_version_id = (
    SELECT policy_version_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'use_suspended_policy'
);

UPDATE decision.supporting_records
SET effective_until = pg_catalog.statement_timestamp() - interval '1 second'
WHERE supporting_record_id = (
    SELECT request_supporting_record_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'use_expired_evidence'
);

UPDATE access_control.authority_grants
SET status = 'REVOKED'
WHERE authority_grant_id = (
    SELECT authority_grant_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'use_revoked_authority'
);

UPDATE access_control.authority_grants
SET identity_id = (
    SELECT identity_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'use_locked_session'
)
WHERE authority_grant_id = (
    SELECT authority_grant_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'use_retargeted_authority'
);

DELETE FROM access_control.lease_authority_grants
WHERE authorization_lease_id = (
    SELECT lease_id FROM pg_temp.step5_fixtures
    WHERE fixture_key = 'use_missing_authority_link'
);

SELECT sql_test.assert_true(
    'Locked session makes an issued lease unusable',
    NOT sql_test.phase3_step5_lease_is_usable('use_locked_session')
);

SELECT sql_test.assert_true(
    'Suspended identity makes an issued lease unusable',
    NOT sql_test.phase3_step5_lease_is_usable('use_suspended_identity')
);

SELECT sql_test.assert_true(
    'Revoked device makes an issued lease unusable',
    NOT sql_test.phase3_step5_lease_is_usable('use_revoked_device')
);

SELECT sql_test.assert_true(
    'Suspended Trust Provider makes an issued lease unusable',
    NOT sql_test.phase3_step5_lease_is_usable('use_suspended_provider')
);

SELECT sql_test.assert_true(
    'Suspended Platform Service makes an issued lease unusable',
    NOT sql_test.phase3_step5_lease_is_usable('use_suspended_service')
);

SELECT sql_test.assert_true(
    'Suspended policy version makes an issued lease unusable',
    NOT sql_test.phase3_step5_lease_is_usable('use_suspended_policy')
);

SELECT sql_test.assert_true(
    'Expired required evidence makes an issued lease unusable',
    NOT sql_test.phase3_step5_lease_is_usable('use_expired_evidence')
);

SELECT sql_test.assert_true(
    'Revoked linked authority makes an issued lease unusable',
    NOT sql_test.phase3_step5_lease_is_usable('use_revoked_authority')
);

SELECT sql_test.assert_true(
    'Authority retargeted to another identity makes a lease unusable',
    NOT sql_test.phase3_step5_lease_is_usable('use_retargeted_authority')
);

SELECT sql_test.assert_true(
    'Missing required authority linkage makes a lease unusable',
    NOT sql_test.phase3_step5_lease_is_usable('use_missing_authority_link')
);

SELECT sql_test.create_phase3_step5_use_decision('consume_wrong_request');
SELECT sql_test.create_phase3_step5_use_decision('consume_wrong_correlation');
SELECT sql_test.create_phase3_step5_use_decision(
    'consume_draft_decision', 'DRAFT', 'ALLOW'
);
SELECT sql_test.create_phase3_step5_use_decision(
    'consume_deny_decision', 'FINALIZED', 'DENY'
);
SELECT sql_test.create_phase3_step5_use_decision(
    'consume_wrong_target', 'FINALIZED', 'ALLOW', 'wrong-target'
);

SELECT sql_test.assert_raises(
    'Mismatched request identifier blocks lease consumption',
    format(
        'SELECT sql_test.consume_phase3_step5_fixture(%L, %L::uuid, NULL)',
        'consume_wrong_request', pg_catalog.gen_random_uuid()
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Mismatched correlation identifier blocks lease consumption',
    format(
        'SELECT sql_test.consume_phase3_step5_fixture(%L, NULL, %L::uuid)',
        'consume_wrong_correlation', pg_catalog.gen_random_uuid()
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Draft protected-operation decision blocks lease consumption',
    $$SELECT sql_test.consume_phase3_step5_fixture('consume_draft_decision')$$,
    '28000'
);

SELECT sql_test.assert_raises(
    'Denied protected-operation decision blocks lease consumption',
    $$SELECT sql_test.consume_phase3_step5_fixture('consume_deny_decision')$$,
    '28000'
);

SELECT sql_test.assert_raises(
    'Protected-operation target mismatch blocks lease consumption',
    $$SELECT sql_test.consume_phase3_step5_fixture('consume_wrong_target')$$,
    '28000'
);

SELECT sql_test.assert_true(
    'Failed consumption attempts change no counters and append no use events',
    NOT EXISTS (
        SELECT 1
        FROM pg_temp.step5_fixtures AS fixture
        JOIN access_control.authorization_leases AS lease
          ON lease.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key LIKE 'consume_%'
          AND lease.successful_use_count <> 0
    )
    AND NOT EXISTS (
        SELECT 1
        FROM pg_temp.step5_fixtures AS fixture
        JOIN access_control.authorization_lease_use_events AS use_event
          ON use_event.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key LIKE 'consume_%'
    )
);
