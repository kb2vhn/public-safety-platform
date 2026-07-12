-- ============================================================================
-- Phase 3 Step 4 controlled Authorization Lease issuance and use
-- ============================================================================

SELECT sql_test.begin_file(
    '150_authorization_lease_issuance_and_use.sql'
);

CREATE TEMP TABLE step4_common (
    provider_id uuid NOT NULL,
    device_id uuid NOT NULL,
    identity_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    service_id uuid NOT NULL,
    purpose_definition_id uuid NOT NULL,
    operation_definition_id uuid NOT NULL,
    operation_key text NOT NULL
) ON COMMIT PRESERVE ROWS;

CREATE TEMP TABLE step4_lease_fixtures (
    fixture_key text PRIMARY KEY,
    decision_id uuid NOT NULL,
    use_decision_id uuid,
    session_id uuid NOT NULL,
    policy_version_id uuid NOT NULL,
    lease_id uuid,
    secret text NOT NULL,
    use_mode text NOT NULL,
    usage_limit integer
) ON COMMIT PRESERVE ROWS;

DO $setup_common$
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
    v_operation_key text := 'sql_test.phase3_step4_operation_' || v_suffix;
BEGIN
    INSERT INTO trust.trust_providers (
        trust_provider_id, provider_key, display_name, provider_type,
        environment_key, status, valid_from, valid_until, created_by_reference
    ) VALUES (
        v_provider_id, 'sql_test.phase3_step4_provider_' || v_suffix,
        'SQL Test Phase 3 Step 4 Provider', 'IDENTITY_PROVIDER', 'test',
        'ACTIVE', v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO trust.devices (
        device_id, device_key, device_type, status, enrolled_at,
        trusted_from, trusted_until, created_by_reference
    ) VALUES (
        v_device_id, 'sql_test.phase3_step4_device_' || v_suffix,
        'WORKSTATION', 'TRUSTED', v_now - interval '1 day',
        v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO identity.persons (
        person_id, person_key, display_name, status, created_by_reference
    ) VALUES (
        v_person_id, 'sql_test.phase3_step4_person_' || v_suffix,
        'SQL Test Phase 3 Step 4 Person', 'ACTIVE', 'sql_test'
    );

    INSERT INTO identity.identities (
        identity_id, identity_key, identity_type, person_id, status,
        assurance_level, valid_from, valid_until, created_by_reference
    ) VALUES (
        v_identity_id, 'sql_test.phase3_step4_identity_' || v_suffix,
        'HUMAN', v_person_id, 'ACTIVE', 'TEST',
        v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO organization.organizations (
        organization_id, organization_key, legal_name, display_name,
        organization_type, status, valid_from, valid_until,
        created_by_reference
    ) VALUES (
        v_organization_id, 'sql_test.phase3_step4_org_' || v_suffix,
        'SQL Test Phase 3 Step 4 Organization',
        'SQL Test Phase 3 Step 4 Organization', 'TEST_ORGANIZATION',
        'ACTIVE', v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO service.platform_services (
        service_id, service_key, display_name, service_type,
        service_owner_organization_id, status, valid_from, valid_until,
        created_by_reference
    ) VALUES (
        v_service_id, 'sql_test.phase3_step4_service_' || v_suffix,
        'SQL Test Phase 3 Step 4 Service', 'TEST_SERVICE',
        v_organization_id, 'ACTIVE', v_now - interval '1 day',
        v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO access_control.purpose_definitions (
        purpose_definition_id, purpose_key, title, description, status
    ) VALUES (
        v_purpose_id, 'sql_test.phase3_step4_purpose_' || v_suffix,
        'SQL Test Phase 3 Step 4 Purpose',
        'SQL Test Phase 3 Step 4 Purpose', 'ACTIVE'
    );

    INSERT INTO access_control.operation_definitions (
        operation_definition_id, operation_key, title, description, status
    ) VALUES (
        v_operation_id, v_operation_key,
        'SQL Test Phase 3 Step 4 Operation',
        'SQL Test Phase 3 Step 4 Operation', 'ACTIVE'
    );

    INSERT INTO pg_temp.step4_common VALUES (
        v_provider_id, v_device_id, v_identity_id, v_organization_id,
        v_service_id, v_purpose_id, v_operation_id, v_operation_key
    );
END;
$setup_common$;

CREATE FUNCTION sql_test.create_phase3_step4_session(
    p_fixture_key text,
    p_lifetime interval DEFAULT interval '1 hour'
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_common pg_temp.step4_common%ROWTYPE;
    v_assertion_id uuid := pg_catalog.gen_random_uuid();
    v_external_id text := 'sql-test-phase3-step4-' || p_fixture_key || '-' || pg_catalog.gen_random_uuid()::text;
BEGIN
    SELECT * INTO STRICT v_common FROM pg_temp.step4_common;
    INSERT INTO access_control.authentication_assertions (
        authentication_assertion_id, assertion_id, assertion_purpose,
        trust_provider_id, identity_id, device_id, session_id, service_id,
        audience, environment_key, issued_at, expires_at, nonce_hash,
        payload_hash, signature_algorithm, signature_value, received_at
    ) VALUES (
        v_assertion_id, v_external_id, 'SESSION_ESTABLISHMENT',
        v_common.provider_id, v_common.identity_id, v_common.device_id, NULL,
        v_common.service_id, 'phase3-step4-session', 'test',
        v_now - interval '1 minute', v_now + interval '10 minutes',
        extensions.digest(pg_catalog.convert_to(v_external_id || ':nonce', 'UTF8'), 'sha256'),
        extensions.digest(pg_catalog.convert_to(v_external_id || ':payload', 'UTF8'), 'sha256'),
        'SQL-TEST-SIGNATURE', pg_catalog.decode(pg_catalog.repeat('65', 32), 'hex'),
        v_now - interval '30 seconds'
    );
    PERFORM access_control.mark_authentication_assertion_verified(
        v_assertion_id, 'sql_test.phase3_step4_verifier', 'sql_test.phase3_step4.v1'
    );
    RETURN access_control.establish_session_from_authentication_assertion(
        v_external_id, v_common.organization_id, p_lifetime,
        interval '30 minutes', 'phase3-step4-session', 'test',
        pg_catalog.gen_random_uuid()
    );
END;
$function$;

CREATE FUNCTION sql_test.create_phase3_step4_fixture(
    p_fixture_key text,
    p_use_mode text,
    p_usage_limit integer,
    p_requested_lifetime interval DEFAULT interval '5 minutes',
    p_allow boolean DEFAULT true,
    p_session_lifetime interval DEFAULT interval '1 hour'
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_common pg_temp.step4_common%ROWTYPE;
    v_session_id uuid;
    v_policy_id uuid := pg_catalog.gen_random_uuid();
    v_policy_version_id uuid := pg_catalog.gen_random_uuid();
    v_required_stage_id uuid := pg_catalog.gen_random_uuid();
    v_optional_stage_id uuid := pg_catalog.gen_random_uuid();
    v_decision_id uuid := pg_catalog.gen_random_uuid();
    v_evaluation_id uuid := pg_catalog.gen_random_uuid();
    v_secret text := 'phase3-step4-secret-' || pg_catalog.gen_random_uuid()::text;
    v_suffix text := pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', '');
BEGIN
    SELECT * INTO STRICT v_common FROM pg_temp.step4_common;
    v_session_id := sql_test.create_phase3_step4_session(
        p_fixture_key, p_session_lifetime
    );

    INSERT INTO access_control.authorization_policies (
        authorization_policy_id, policy_key, title, description, status
    ) VALUES (
        v_policy_id, 'sql_test.phase3_step4_policy_' || p_fixture_key || '_' || v_suffix,
        'SQL Test Phase 3 Step 4 Policy', 'SQL Test Phase 3 Step 4 Policy', 'ACTIVE'
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
        v_common.service_id, v_common.purpose_definition_id,
        v_common.operation_definition_id, v_common.organization_id,
        false, true, 'TEST_RESOURCE', p_fixture_key, true, false,
        p_use_mode, interval '10 minutes', p_usage_limit,
        'phase3-step4-protected-consumer', 'ACTIVE',
        v_now - interval '1 day', v_now + interval '1 day',
        'sql-test-phase3-step4-policy', '1', 100
    );

    INSERT INTO access_control.authorization_policy_stage_requirements (
        authorization_policy_stage_requirement_id,
        authorization_policy_version_id, stage_order, stage_key, required,
        not_required_reason_code, not_required_rule_reference,
        supporting_record_required
    ) VALUES
    (
        v_required_stage_id, v_policy_version_id, 1, 'REQUEST_CONTEXT',
        true, NULL, NULL, true
    ),
    (
        v_optional_stage_id, v_policy_version_id, 2, 'APPROVAL',
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
        'LEASE_ISSUANCE', v_common.identity_id, v_common.organization_id,
        v_session_id, v_common.device_id, v_common.service_id,
        v_common.purpose_definition_id, v_common.operation_definition_id,
        v_common.operation_key, 'TEST_RESOURCE', p_fixture_key,
        v_now, v_now, 'sql_test.phase3_step4', '1', '081-step4',
        p_requested_lifetime, p_use_mode, p_usage_limit,
        'phase3-step4-protected-consumer'
    );

    PERFORM decision.bind_authorization_policy(v_decision_id);

    INSERT INTO decision.evaluation_records (
        evaluation_id, decision_id, evaluation_order, evaluation_key,
        required, result, reason_code, evaluated_at,
        authorization_policy_version_id,
        authorization_policy_stage_requirement_id
    ) VALUES (
        v_evaluation_id, v_decision_id, 1, 'REQUEST_CONTEXT', true,
        CASE WHEN p_allow THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN p_allow THEN 'REQUEST_CONTEXT_VALID' ELSE 'REQUEST_CONTEXT_FAILED' END,
        v_now, v_policy_version_id, v_required_stage_id
    );

    INSERT INTO decision.supporting_records (
        evaluation_id, record_type, record_id, record_version,
        required_for_result
    ) VALUES (
        v_evaluation_id, 'REQUEST_CONTEXT', p_fixture_key, '1', true
    );

    INSERT INTO decision.evaluation_records (
        decision_id, evaluation_order, evaluation_key, required, result,
        reason_code, evaluated_at, authorization_policy_version_id,
        authorization_policy_stage_requirement_id, policy_rule_reference
    ) VALUES (
        v_decision_id, 2, 'APPROVAL', false, 'NOT_REQUIRED',
        'APPROVAL_NOT_REQUIRED', v_now, v_policy_version_id,
        v_optional_stage_id, 'sql-test-rule-approval-not-required'
    );

    PERFORM decision.finalize_authorization_decision(v_decision_id);

    INSERT INTO pg_temp.step4_lease_fixtures VALUES (
        p_fixture_key, v_decision_id, NULL, v_session_id,
        v_policy_version_id, NULL, v_secret, p_use_mode, p_usage_limit
    );

    RETURN v_decision_id;
END;
$function$;

CREATE FUNCTION sql_test.create_phase3_step4_use_decision(
    p_fixture_key text
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_common pg_temp.step4_common%ROWTYPE;
    v_fixture pg_temp.step4_lease_fixtures%ROWTYPE;
    v_use_decision_id uuid := pg_catalog.gen_random_uuid();
BEGIN
    SELECT * INTO STRICT v_common FROM pg_temp.step4_common;
    SELECT * INTO STRICT v_fixture
    FROM pg_temp.step4_lease_fixtures
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
        v_common.identity_id, v_common.organization_id,
        v_fixture.session_id, v_common.device_id, v_common.service_id,
        v_common.purpose_definition_id, v_common.operation_definition_id,
        v_common.operation_key, 'TEST_RESOURCE', p_fixture_key,
        v_now, v_now, 'sql_test.phase3_step4', '1', '081-step4',
        v_fixture.policy_version_id, v_fixture.lease_id,
        'FINALIZED', 'ALLOW', 'AUTHORIZATION_DECISION_ALLOWED', v_now
    );

    UPDATE pg_temp.step4_lease_fixtures
    SET use_decision_id = v_use_decision_id
    WHERE fixture_key = p_fixture_key;

    RETURN v_use_decision_id;
END;
$function$;

DO $create_fixtures$
DECLARE
    v_decision_id uuid;
    v_lease_id uuid;
BEGIN
    v_decision_id := sql_test.create_phase3_step4_fixture(
        'reusable', 'REUSABLE', NULL
    );
    v_lease_id := access_control.issue_authorization_lease_from_decision(
        v_decision_id,
        (SELECT secret FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'reusable')
    );
    UPDATE pg_temp.step4_lease_fixtures SET lease_id = v_lease_id
    WHERE fixture_key = 'reusable';

    v_decision_id := sql_test.create_phase3_step4_fixture(
        'single_use', 'SINGLE_USE', 1
    );
    v_lease_id := access_control.issue_authorization_lease_from_decision(
        v_decision_id,
        (SELECT secret FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'single_use')
    );
    UPDATE pg_temp.step4_lease_fixtures SET lease_id = v_lease_id
    WHERE fixture_key = 'single_use';

    v_decision_id := sql_test.create_phase3_step4_fixture(
        'limited_use', 'LIMITED_USE', 2
    );
    v_lease_id := access_control.issue_authorization_lease_from_decision(
        v_decision_id,
        (SELECT secret FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'limited_use')
    );
    UPDATE pg_temp.step4_lease_fixtures SET lease_id = v_lease_id
    WHERE fixture_key = 'limited_use';

    v_decision_id := sql_test.create_phase3_step4_fixture(
        'revocation', 'REUSABLE', NULL
    );
    v_lease_id := access_control.issue_authorization_lease_from_decision(
        v_decision_id,
        (SELECT secret FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'revocation')
    );
    UPDATE pg_temp.step4_lease_fixtures SET lease_id = v_lease_id
    WHERE fixture_key = 'revocation';

    v_decision_id := sql_test.create_phase3_step4_fixture(
        'expiration', 'REUSABLE', NULL, interval '1 millisecond'
    );
    v_lease_id := access_control.issue_authorization_lease_from_decision(
        v_decision_id,
        (SELECT secret FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'expiration')
    );
    UPDATE pg_temp.step4_lease_fixtures SET lease_id = v_lease_id
    WHERE fixture_key = 'expiration';

    PERFORM sql_test.create_phase3_step4_fixture(
        'denied', 'REUSABLE', NULL, interval '5 minutes', false
    );
END;
$create_fixtures$;

SELECT sql_test.assert_true(
    'Finalized ALLOW lease decision issues exactly one lease',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_lease_fixtures
        WHERE fixture_key = 'reusable' AND lease_id IS NOT NULL
    )
);

SELECT sql_test.assert_true(
    'Issuance links the Decision Record to the lease',
    EXISTS (
        SELECT 1
        FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'reusable'
          AND decision_record.authorization_lease_id = fixture.lease_id
    )
);

SELECT sql_test.assert_true(
    'Lease stores only the expected secret hash',
    EXISTS (
        SELECT 1
        FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN access_control.authorization_leases AS lease
          ON lease.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key = 'reusable'
          AND lease.lease_secret_hash =
              access_control.hash_lease_secret(fixture.secret)
          AND pg_catalog.encode(lease.lease_secret_hash, 'hex') <>
              fixture.secret
    )
);

SELECT sql_test.assert_true(
    'Lease issuance uses one authoritative issued and not-before time',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN access_control.authorization_leases AS lease
          ON lease.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key = 'reusable'
          AND lease.issued_at = lease.not_before
    )
);

SELECT sql_test.assert_true(
    'Lease expiration is bounded by request, policy, and session',
    EXISTS (
        SELECT 1
        FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN access_control.authorization_leases AS lease
          ON lease.authorization_lease_id = fixture.lease_id
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        JOIN access_control.sessions AS session_record
          ON session_record.session_id = fixture.session_id
        JOIN access_control.authorization_policy_versions AS policy_version
          ON policy_version.authorization_policy_version_id = fixture.policy_version_id
        WHERE fixture.fixture_key = 'reusable'
          AND lease.expires_at <= lease.issued_at + decision_record.requested_lease_lifetime
          AND lease.expires_at <= lease.issued_at + policy_version.lease_lifetime
          AND lease.expires_at <= session_record.expires_at
    )
);

SELECT sql_test.assert_true(
    'Issued lease preserves the policy-bounded use mode and limit',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN access_control.authorization_leases AS lease
          ON lease.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key = 'limited_use'
          AND lease.use_mode = 'LIMITED_USE'
          AND lease.usage_limit = 2
    )
);

SELECT sql_test.assert_raises(
    'A Decision Record cannot issue a second lease',
    '28000',
    format(
        'SELECT access_control.issue_authorization_lease_from_decision(%L::uuid, %L)',
        (SELECT decision_id FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'reusable'),
        'another-phase3-step4-secret-000000000000000000000000'
    )
);

SELECT sql_test.assert_raises(
    'A finalized DENY Decision Record cannot issue a lease',
    '28000',
    format(
        'SELECT access_control.issue_authorization_lease_from_decision(%L::uuid, %L)',
        (SELECT decision_id FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'denied'),
        'denied-phase3-step4-secret-0000000000000000000000000'
    )
);

SELECT sql_test.assert_raises(
    'Lease issuance rejects a short secret',
    '22023',
    format(
        'SELECT access_control.issue_authorization_lease_from_decision(%L::uuid, %L)',
        (SELECT decision_id FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'denied'),
        'short'
    )
);

CREATE FUNCTION sql_test.step4_lease_is_usable(p_fixture_key text, p_secret text, p_audience text)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, sql_test
AS $function$
    SELECT access_control.authorization_lease_context_is_usable(
        fixture.lease_id, p_secret, common.identity_id,
        common.organization_id, fixture.session_id, common.device_id,
        common.service_id, common.purpose_definition_id,
        common.operation_definition_id, 'TEST_RESOURCE', fixture.fixture_key,
        NULL, NULL, fixture.policy_version_id, p_audience
    )
    FROM pg_temp.step4_lease_fixtures AS fixture
    CROSS JOIN pg_temp.step4_common AS common
    WHERE fixture.fixture_key = p_fixture_key;
$function$;

SELECT sql_test.assert_true(
    'Exact complete lease context is usable',
    sql_test.step4_lease_is_usable(
        'reusable',
        (SELECT secret FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'reusable'),
        'phase3-step4-protected-consumer'
    )
);

SELECT sql_test.assert_true(
    'Wrong lease secret is unusable',
    NOT sql_test.step4_lease_is_usable(
        'reusable', 'wrong-secret-000000000000000000000000000000',
        'phase3-step4-protected-consumer'
    )
);

SELECT sql_test.assert_true(
    'Wrong lease audience is unusable',
    NOT sql_test.step4_lease_is_usable(
        'reusable',
        (SELECT secret FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'reusable'),
        'wrong-audience'
    )
);

CREATE FUNCTION sql_test.consume_phase3_step4_fixture(p_fixture_key text)
RETURNS integer
LANGUAGE plpgsql
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_fixture pg_temp.step4_lease_fixtures%ROWTYPE;
    v_common pg_temp.step4_common%ROWTYPE;
    v_use_decision_id uuid;
    v_use_request_id uuid;
    v_use_correlation_id uuid;
BEGIN
    SELECT * INTO STRICT v_fixture FROM pg_temp.step4_lease_fixtures
    WHERE fixture_key = p_fixture_key;
    SELECT * INTO STRICT v_common FROM pg_temp.step4_common;

    v_use_decision_id :=
        sql_test.create_phase3_step4_use_decision(p_fixture_key);

    SELECT request_id, correlation_id
    INTO STRICT v_use_request_id, v_use_correlation_id
    FROM decision.decision_records
    WHERE decision_id = v_use_decision_id;

    RETURN access_control.consume_authorization_lease(
        v_fixture.lease_id, v_fixture.secret, v_use_request_id,
        v_common.identity_id, v_common.organization_id, v_fixture.session_id,
        v_common.device_id, v_common.service_id,
        v_common.purpose_definition_id, v_common.operation_definition_id,
        'TEST_RESOURCE', v_fixture.fixture_key, NULL, NULL,
        v_fixture.policy_version_id, 'phase3-step4-protected-consumer',
        v_use_decision_id, v_use_correlation_id
    );
END;
$function$;

SELECT sql_test.assert_true(
    'Reusable lease records its first successful use',
    sql_test.consume_phase3_step4_fixture('reusable') = 1
);

SELECT sql_test.assert_true(
    'Reusable lease remains ACTIVE after use',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN access_control.authorization_leases AS lease
          ON lease.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key = 'reusable'
          AND lease.status = 'ACTIVE'
          AND lease.successful_use_count = 1
    )
);

SELECT sql_test.assert_true(
    'Reusable lease writes one attributable use event',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN access_control.authorization_lease_use_events AS event_record
          ON event_record.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key = 'reusable'
          AND event_record.use_number = 1
          AND event_record.decision_reference = fixture.use_decision_id
    )
);

SELECT sql_test.assert_true(
    'Single-use lease consumes exactly once',
    sql_test.consume_phase3_step4_fixture('single_use') = 1
);

SELECT sql_test.assert_true(
    'Single-use lease becomes terminal CONSUMED',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN access_control.authorization_leases AS lease
          ON lease.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key = 'single_use'
          AND lease.status = 'CONSUMED'
          AND lease.consumed_at IS NOT NULL
          AND lease.successful_use_count = 1
    )
);

SELECT sql_test.assert_raises(
    'Consumed single-use lease cannot be replayed',
    '28000',
    $$SELECT sql_test.consume_phase3_step4_fixture('single_use')$$
);

SELECT sql_test.assert_true(
    'Limited-use lease remains ACTIVE before its limit',
    sql_test.consume_phase3_step4_fixture('limited_use') = 1
    AND EXISTS (
        SELECT 1 FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN access_control.authorization_leases AS lease
          ON lease.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key = 'limited_use'
          AND lease.status = 'ACTIVE'
          AND lease.successful_use_count = 1
    )
);

SELECT sql_test.assert_true(
    'Limited-use lease becomes CONSUMED at its limit',
    sql_test.consume_phase3_step4_fixture('limited_use') = 2
    AND EXISTS (
        SELECT 1 FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN access_control.authorization_leases AS lease
          ON lease.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key = 'limited_use'
          AND lease.status = 'CONSUMED'
          AND lease.successful_use_count = 2
    )
);

SELECT sql_test.assert_raises(
    'Limited-use lease cannot exceed its usage limit',
    '28000',
    $$SELECT sql_test.consume_phase3_step4_fixture('limited_use')$$
);

SELECT sql_test.assert_true(
    'Limited-use events retain monotonic use numbers',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_lease_fixtures AS fixture
        WHERE fixture.fixture_key = 'limited_use'
          AND (
              SELECT array_agg(event_record.use_number ORDER BY event_record.use_number)
              FROM access_control.authorization_lease_use_events AS event_record
              WHERE event_record.authorization_lease_id = fixture.lease_id
          ) = ARRAY[1, 2]
    )
);

SELECT sql_test.assert_true(
    'ACTIVE lease can be revoked with a reason',
    access_control.revoke_lease(
        (SELECT lease_id FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'revocation'),
        'SQL_TEST_REVOCATION'
    )
);

SELECT sql_test.assert_true(
    'Revoked lease is terminal and unusable',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN access_control.authorization_leases AS lease
          ON lease.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key = 'revocation'
          AND lease.status = 'REVOKED'
          AND lease.revoked_at IS NOT NULL
          AND lease.revocation_reason = 'SQL_TEST_REVOCATION'
    )
    AND NOT sql_test.step4_lease_is_usable(
        'revocation',
        (SELECT secret FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'revocation'),
        'phase3-step4-protected-consumer'
    )
);

SELECT sql_test.assert_true(
    'Already revoked lease cannot be revoked again',
    NOT access_control.revoke_lease(
        (SELECT lease_id FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'revocation'),
        'SECOND_REVOCATION'
    )
);

SELECT sql_test.assert_true(
    'Lease expiration cannot be materialized before its deadline',
    NOT access_control.expire_authorization_lease(
        (SELECT lease_id FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'reusable')
    )
);

SELECT pg_catalog.pg_sleep(0.02);

SELECT sql_test.assert_true(
    'Expired lease is unusable before materialization',
    NOT sql_test.step4_lease_is_usable(
        'expiration',
        (SELECT secret FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'expiration'),
        'phase3-step4-protected-consumer'
    )
);

SELECT sql_test.assert_true(
    'Expiration function materializes terminal EXPIRED state',
    access_control.expire_authorization_lease(
        (SELECT lease_id FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'expiration')
    )
    AND EXISTS (
        SELECT 1 FROM pg_temp.step4_lease_fixtures AS fixture
        JOIN access_control.authorization_leases AS lease
          ON lease.authorization_lease_id = fixture.lease_id
        WHERE fixture.fixture_key = 'expiration'
          AND lease.status = 'EXPIRED'
          AND lease.expired_at IS NOT NULL
    )
);

SELECT sql_test.assert_true(
    'PUBLIC cannot execute any Step 4 controlled lease routine',
    NOT EXISTS (
        SELECT 1
        FROM information_schema.routine_privileges
        WHERE routine_schema = 'access_control'
          AND routine_name IN (
              'issue_authorization_lease_from_decision',
              'authorization_lease_context_is_usable',
              'consume_authorization_lease',
              'expire_authorization_lease',
              'revoke_lease'
          )
          AND grantee = 'PUBLIC'
          AND privilege_type = 'EXECUTE'
    )
);

SELECT sql_test.assert_true(
    'Protected-operation Decision Records bind exact lease-use attribution',
    NOT EXISTS (
        SELECT 1
        FROM access_control.authorization_lease_use_events AS use_event
        JOIN decision.decision_records AS use_decision
          ON use_decision.decision_id = use_event.decision_reference
        WHERE use_decision.authorization_lease_id IS DISTINCT FROM
              use_event.authorization_lease_id
           OR use_decision.request_id <> use_event.request_id
           OR use_decision.correlation_id <> use_event.correlation_id
           OR use_decision.decision_class <> 'PROTECTED_OPERATION'
           OR use_decision.record_status <> 'FINALIZED'
           OR use_decision.final_result <> 'ALLOW'
    )
);

SELECT sql_test.assert_raises(
    'Lease revocation rejects a malformed reason code',
    '22023',
    format(
        'SELECT access_control.revoke_lease(%L::uuid, %L)',
        (SELECT lease_id FROM pg_temp.step4_lease_fixtures WHERE fixture_key = 'reusable'),
        'not a reason code'
    )
);

SELECT sql_test.assert_true(
    'Step 4 controlled routines are not SECURITY DEFINER',
    NOT EXISTS (
        SELECT 1
        FROM pg_proc AS routine
        JOIN pg_namespace AS routine_schema
          ON routine_schema.oid = routine.pronamespace
        WHERE routine_schema.nspname = 'access_control'
          AND routine.proname IN (
              'issue_authorization_lease_from_decision',
              'authorization_lease_context_is_usable',
              'consume_authorization_lease',
              'expire_authorization_lease',
              'revoke_lease'
          )
          AND routine.prosecdef
    )
);
