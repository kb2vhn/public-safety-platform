\set ON_ERROR_STOP on

-- Test-only Phase 4 Step 7 approval-concurrency fixture support.

CREATE OR REPLACE FUNCTION sql_test.create_phase4_step7_fixture(
    p_fixture_key text,
    p_seed_approvals integer DEFAULT 0
)
RETURNS TABLE (
    request_id uuid,
    stage_id uuid,
    requester_id uuid,
    finalizer_id uuid,
    identity_a_id uuid,
    identity_b_id uuid,
    organization_id uuid,
    session_a_id uuid,
    session_b_id uuid,
    grant_a_id uuid,
    grant_b_id uuid,
    approval_a_id uuid,
    approval_b_id uuid
)
LANGUAGE plpgsql
VOLATILE
SET search_path = pg_catalog, sql_test, approval, access_control,
                  identity, organization, service
AS $function$
DECLARE
    v_now timestamptz := statement_timestamp();
    v_suffix text := replace(gen_random_uuid()::text, '-', '');

    v_identity_a uuid;
    v_identity_b uuid;
    v_requester uuid;
    v_finalizer uuid;
    v_organization uuid;
    v_service uuid;
    v_purpose uuid;
    v_operation uuid;
    v_scope uuid;
    v_purpose_key text;
    v_operation_key text;
    v_session_a uuid;
    v_session_b uuid;
    v_authority uuid;

    v_policy uuid := gen_random_uuid();
    v_stage uuid := gen_random_uuid();
    v_request uuid := gen_random_uuid();
    v_grant_a uuid := gen_random_uuid();
    v_grant_b uuid := gen_random_uuid();
    v_approval_a uuid;
    v_approval_b uuid;
BEGIN
    IF p_fixture_key IS NULL OR btrim(p_fixture_key) = '' THEN
        RAISE EXCEPTION
            USING ERRCODE = 'invalid_parameter_value',
                  MESSAGE = 'STEP7_FIXTURE_KEY_REQUIRED';
    END IF;

    IF p_seed_approvals NOT BETWEEN 0 AND 2 THEN
        RAISE EXCEPTION
            USING ERRCODE = 'invalid_parameter_value',
                  MESSAGE = 'STEP7_SEED_APPROVAL_COUNT_INVALID';
    END IF;

    SELECT identity_record.identity_id
      INTO STRICT v_identity_a
      FROM identity.identities AS identity_record
     WHERE identity_record.identity_key LIKE
           'sql_test.phase4_step5.identity_a_%'
     ORDER BY identity_record.identity_key
     LIMIT 1;

    SELECT identity_record.identity_id
      INTO STRICT v_identity_b
      FROM identity.identities AS identity_record
     WHERE identity_record.identity_key LIKE
           'sql_test.phase4_step5.identity_b_%'
     ORDER BY identity_record.identity_key
     LIMIT 1;

    SELECT identity_record.identity_id
      INTO STRICT v_requester
      FROM identity.identities AS identity_record
     WHERE identity_record.identity_key LIKE
           'sql_test.phase4_step5.identity_c_%'
     ORDER BY identity_record.identity_key
     LIMIT 1;

    SELECT identity_record.identity_id
      INTO STRICT v_finalizer
      FROM identity.identities AS identity_record
     WHERE identity_record.identity_key LIKE
           'sql_test.phase4_step5.identity_d_%'
     ORDER BY identity_record.identity_key
     LIMIT 1;

    SELECT organization_record.organization_id
      INTO STRICT v_organization
      FROM organization.organizations AS organization_record
     WHERE organization_record.organization_key LIKE
           'sql_test.phase4_step3_org_%'
     ORDER BY organization_record.organization_key
     LIMIT 1;

    SELECT service_record.service_id
      INTO STRICT v_service
      FROM service.platform_services AS service_record
     WHERE service_record.service_key LIKE
           'sql_test.phase4_step3_service_%'
     ORDER BY service_record.service_key
     LIMIT 1;

    SELECT purpose_record.purpose_definition_id,
           purpose_record.purpose_key
      INTO STRICT v_purpose, v_purpose_key
      FROM access_control.purpose_definitions AS purpose_record
     WHERE purpose_record.purpose_key LIKE
           'sql_test.phase4_step3_purpose_%'
     ORDER BY purpose_record.purpose_key
     LIMIT 1;

    SELECT operation_record.operation_definition_id,
           operation_record.operation_key
      INTO STRICT v_operation, v_operation_key
      FROM access_control.operation_definitions AS operation_record
     WHERE operation_record.operation_key LIKE
           'sql_test.phase4_step3_operation_%'
     ORDER BY operation_record.operation_key
     LIMIT 1;

    SELECT scope_record.governed_scope_id
      INTO STRICT v_scope
      FROM organization.governed_scopes AS scope_record
     WHERE scope_record.governed_scope_key LIKE
           'sql_test.phase4_step3_scope_%'
     ORDER BY scope_record.governed_scope_key
     LIMIT 1;

    SELECT authority_record.authority_definition_id
      INTO STRICT v_authority
      FROM access_control.authority_definitions AS authority_record
     WHERE authority_record.authority_key LIKE
           'sql_test.phase4_step5.auth_a_%'
     ORDER BY authority_record.authority_key
     LIMIT 1;

    SELECT session_record.session_id
      INTO STRICT v_session_a
      FROM access_control.sessions AS session_record
     WHERE session_record.identity_id = v_identity_a
       AND session_record.organization_id = v_organization
       AND session_record.service_id = v_service
       AND session_record.status = 'ACTIVE'
     ORDER BY session_record.authenticated_at DESC
     LIMIT 1;

    SELECT session_record.session_id
      INTO STRICT v_session_b
      FROM access_control.sessions AS session_record
     WHERE session_record.identity_id = v_identity_b
       AND session_record.organization_id = v_organization
       AND session_record.service_id = v_service
       AND session_record.status = 'ACTIVE'
     ORDER BY session_record.authenticated_at DESC
     LIMIT 1;

    INSERT INTO approval.approval_policies (
        approval_policy_id,
        policy_key,
        version_number,
        title,
        status,
        valid_from,
        valid_until,
        self_approval_allowed,
        created_by_reference
    )
    VALUES (
        v_policy,
        'sql_test.phase4_step7.policy_' || v_suffix,
        1,
        'SQL Test Phase 4 Step 7 Policy',
        'ACTIVE',
        v_now - interval '1 day',
        v_now + interval '1 day',
        false,
        'sql_test'
    );

    INSERT INTO approval.approval_policy_stages (
        approval_policy_stage_id,
        approval_policy_id,
        stage_order,
        stage_key,
        minimum_approvals,
        independent_identity_required,
        independent_organization_required,
        authority_requirement,
        required_authority_definition_id,
        requester_approval_allowed,
        affected_identity_approval_allowed,
        action_reuse_allowed,
        delegated_authority_allowed,
        maximum_delegation_depth,
        action_validity,
        authority_origin_independence_required,
        blocking_deny
    )
    VALUES (
        v_stage,
        v_policy,
        1,
        'STEP7_PRIMARY',
        2,
        true,
        false,
        'Two independent Authority A approvers',
        v_authority,
        false,
        false,
        false,
        false,
        NULL,
        interval '30 minutes',
        false,
        true
    );

    INSERT INTO approval.approval_requests (
        approval_request_id,
        approval_policy_id,
        requester_identity_id,
        requester_organization_id,
        requester_session_id,
        service_id,
        purpose_key,
        operation_key,
        protected_target_type,
        protected_target_reference,
        governed_scope_id,
        classification_key,
        status,
        requested_at,
        expires_at,
        correlation_id,
        purpose_definition_id,
        operation_definition_id,
        directly_affected_identity_id,
        approval_chain_id
    )
    VALUES (
        v_request,
        v_policy,
        v_requester,
        v_organization,
        NULL,
        v_service,
        v_purpose_key,
        v_operation_key,
        'TEST_RESOURCE',
        'step7-' || p_fixture_key || '-' || v_suffix,
        v_scope,
        'TEST',
        'PENDING',
        v_now - interval '1 minute',
        v_now + interval '1 hour',
        gen_random_uuid(),
        v_purpose,
        v_operation,
        NULL,
        gen_random_uuid()
    );

    INSERT INTO access_control.authority_grants (
        authority_grant_id,
        identity_id,
        authority_definition_id,
        purpose_definition_id,
        operation_definition_id,
        service_id,
        organization_id,
        governed_scope_id,
        applies_to_all_governed_scopes,
        protected_target_type,
        protected_target_reference,
        applies_to_all_targets,
        scope_reference,
        status,
        valid_from,
        valid_until,
        granted_by_identity_id,
        approval_request_id,
        delegated_from_authority_grant_id,
        delegation_depth
    )
    VALUES
        (
            v_grant_a, v_identity_a, v_authority,
            v_purpose, v_operation, v_service, v_organization,
            NULL, true, NULL, NULL, true, NULL,
            'ACTIVE', v_now - interval '1 day', v_now + interval '1 day',
            v_finalizer, NULL, NULL, 0
        ),
        (
            v_grant_b, v_identity_b, v_authority,
            v_purpose, v_operation, v_service, v_organization,
            NULL, true, NULL, NULL, true, NULL,
            'ACTIVE', v_now - interval '1 day', v_now + interval '1 day',
            v_finalizer, NULL, NULL, 0
        );

    IF p_seed_approvals >= 1 THEN
        SELECT action_record.recorded_approval_action_id
          INTO STRICT v_approval_a
          FROM approval.record_approval_action(
              v_request, v_stage, v_identity_a, v_organization,
              v_session_a, v_grant_a, 'APPROVE',
              'Phase 4 Step 7 concurrency fixture',
              'SQL_TEST_STEP7_APPROVED_A', NULL
          ) AS action_record;
    END IF;

    IF p_seed_approvals >= 2 THEN
        SELECT action_record.recorded_approval_action_id
          INTO STRICT v_approval_b
          FROM approval.record_approval_action(
              v_request, v_stage, v_identity_b, v_organization,
              v_session_b, v_grant_b, 'APPROVE',
              'Phase 4 Step 7 concurrency fixture',
              'SQL_TEST_STEP7_APPROVED_B', NULL
          ) AS action_record;
    END IF;

    request_id := v_request;
    stage_id := v_stage;
    requester_id := v_requester;
    finalizer_id := v_finalizer;
    identity_a_id := v_identity_a;
    identity_b_id := v_identity_b;
    organization_id := v_organization;
    session_a_id := v_session_a;
    session_b_id := v_session_b;
    grant_a_id := v_grant_a;
    grant_b_id := v_grant_b;
    approval_a_id := v_approval_a;
    approval_b_id := v_approval_b;
    RETURN NEXT;
END;
$function$;


CREATE OR REPLACE FUNCTION sql_test.create_phase4_step7_reciprocal_fixture(
    p_fixture_key text
)
RETURNS TABLE (
    request_a_id uuid,
    request_b_id uuid,
    stage_id uuid,
    identity_a_id uuid,
    identity_b_id uuid,
    organization_id uuid,
    session_a_id uuid,
    session_b_id uuid,
    grant_a_id uuid,
    grant_b_id uuid,
    approval_chain_id uuid
)
LANGUAGE plpgsql
VOLATILE
SET search_path = pg_catalog, sql_test, approval, access_control,
                  identity, organization, service
AS $function$
DECLARE
    v_now timestamptz := statement_timestamp();
    v_suffix text := replace(gen_random_uuid()::text, '-', '');

    v_identity_a uuid;
    v_identity_b uuid;
    v_finalizer uuid;
    v_organization uuid;
    v_service uuid;
    v_purpose uuid;
    v_operation uuid;
    v_scope uuid;
    v_purpose_key text;
    v_operation_key text;
    v_session_a uuid;
    v_session_b uuid;
    v_authority uuid;

    v_policy uuid := gen_random_uuid();
    v_stage uuid := gen_random_uuid();
    v_request_a uuid := gen_random_uuid();
    v_request_b uuid := gen_random_uuid();
    v_grant_a uuid := gen_random_uuid();
    v_grant_b uuid := gen_random_uuid();
    v_chain uuid := gen_random_uuid();
BEGIN
    IF p_fixture_key IS NULL OR btrim(p_fixture_key) = '' THEN
        RAISE EXCEPTION
            USING ERRCODE = 'invalid_parameter_value',
                  MESSAGE = 'STEP7_FIXTURE_KEY_REQUIRED';
    END IF;

    SELECT identity_record.identity_id
      INTO STRICT v_identity_a
      FROM identity.identities AS identity_record
     WHERE identity_record.identity_key LIKE
           'sql_test.phase4_step5.identity_a_%'
     ORDER BY identity_record.identity_key
     LIMIT 1;

    SELECT identity_record.identity_id
      INTO STRICT v_identity_b
      FROM identity.identities AS identity_record
     WHERE identity_record.identity_key LIKE
           'sql_test.phase4_step5.identity_b_%'
     ORDER BY identity_record.identity_key
     LIMIT 1;

    SELECT identity_record.identity_id
      INTO STRICT v_finalizer
      FROM identity.identities AS identity_record
     WHERE identity_record.identity_key LIKE
           'sql_test.phase4_step5.identity_d_%'
     ORDER BY identity_record.identity_key
     LIMIT 1;

    SELECT organization_record.organization_id
      INTO STRICT v_organization
      FROM organization.organizations AS organization_record
     WHERE organization_record.organization_key LIKE
           'sql_test.phase4_step3_org_%'
     ORDER BY organization_record.organization_key
     LIMIT 1;

    SELECT service_record.service_id
      INTO STRICT v_service
      FROM service.platform_services AS service_record
     WHERE service_record.service_key LIKE
           'sql_test.phase4_step3_service_%'
     ORDER BY service_record.service_key
     LIMIT 1;

    SELECT purpose_record.purpose_definition_id,
           purpose_record.purpose_key
      INTO STRICT v_purpose, v_purpose_key
      FROM access_control.purpose_definitions AS purpose_record
     WHERE purpose_record.purpose_key LIKE
           'sql_test.phase4_step3_purpose_%'
     ORDER BY purpose_record.purpose_key
     LIMIT 1;

    SELECT operation_record.operation_definition_id,
           operation_record.operation_key
      INTO STRICT v_operation, v_operation_key
      FROM access_control.operation_definitions AS operation_record
     WHERE operation_record.operation_key LIKE
           'sql_test.phase4_step3_operation_%'
     ORDER BY operation_record.operation_key
     LIMIT 1;

    SELECT scope_record.governed_scope_id
      INTO STRICT v_scope
      FROM organization.governed_scopes AS scope_record
     WHERE scope_record.governed_scope_key LIKE
           'sql_test.phase4_step3_scope_%'
     ORDER BY scope_record.governed_scope_key
     LIMIT 1;

    SELECT authority_record.authority_definition_id
      INTO STRICT v_authority
      FROM access_control.authority_definitions AS authority_record
     WHERE authority_record.authority_key LIKE
           'sql_test.phase4_step5.auth_a_%'
     ORDER BY authority_record.authority_key
     LIMIT 1;

    SELECT session_record.session_id
      INTO STRICT v_session_a
      FROM access_control.sessions AS session_record
     WHERE session_record.identity_id = v_identity_a
       AND session_record.organization_id = v_organization
       AND session_record.service_id = v_service
       AND session_record.status = 'ACTIVE'
     ORDER BY session_record.authenticated_at DESC
     LIMIT 1;

    SELECT session_record.session_id
      INTO STRICT v_session_b
      FROM access_control.sessions AS session_record
     WHERE session_record.identity_id = v_identity_b
       AND session_record.organization_id = v_organization
       AND session_record.service_id = v_service
       AND session_record.status = 'ACTIVE'
     ORDER BY session_record.authenticated_at DESC
     LIMIT 1;

    INSERT INTO approval.approval_policies (
        approval_policy_id, policy_key, version_number, title, status,
        valid_from, valid_until, self_approval_allowed, created_by_reference
    )
    VALUES (
        v_policy, 'sql_test.phase4_step7.reciprocal_policy_' || v_suffix,
        1, 'SQL Test Phase 4 Step 7 Reciprocal Policy', 'ACTIVE',
        v_now - interval '1 day', v_now + interval '1 day', false, 'sql_test'
    );

    INSERT INTO approval.approval_policy_stages (
        approval_policy_stage_id, approval_policy_id, stage_order, stage_key,
        minimum_approvals, independent_identity_required,
        independent_organization_required, authority_requirement,
        required_authority_definition_id, requester_approval_allowed,
        affected_identity_approval_allowed, action_reuse_allowed,
        delegated_authority_allowed, maximum_delegation_depth,
        action_validity, authority_origin_independence_required, blocking_deny
    )
    VALUES (
        v_stage, v_policy, 1, 'STEP7_RECIPROCAL', 1, true, false,
        'One independent Authority A approver', v_authority,
        false, false, false, false, NULL, interval '30 minutes', false, true
    );

    INSERT INTO approval.approval_requests (
        approval_request_id, approval_policy_id, requester_identity_id,
        requester_organization_id, requester_session_id, service_id,
        purpose_key, operation_key, protected_target_type,
        protected_target_reference, governed_scope_id, classification_key,
        status, requested_at, expires_at, correlation_id,
        purpose_definition_id, operation_definition_id,
        directly_affected_identity_id, approval_chain_id
    )
    VALUES
        (
            v_request_a, v_policy, v_identity_a, v_organization, NULL,
            v_service, v_purpose_key, v_operation_key, 'TEST_RESOURCE',
            'step7-reciprocal-a-' || v_suffix, v_scope, 'TEST', 'PENDING',
            v_now - interval '1 minute', v_now + interval '1 hour',
            gen_random_uuid(), v_purpose, v_operation, NULL, v_chain
        ),
        (
            v_request_b, v_policy, v_identity_b, v_organization, NULL,
            v_service, v_purpose_key, v_operation_key, 'TEST_RESOURCE',
            'step7-reciprocal-b-' || v_suffix, v_scope, 'TEST', 'PENDING',
            v_now - interval '1 minute', v_now + interval '1 hour',
            gen_random_uuid(), v_purpose, v_operation, NULL, v_chain
        );

    INSERT INTO approval.approval_request_dependencies (
        approval_request_id,
        depends_on_approval_request_id,
        dependency_type,
        created_by_identity_id,
        reason_code
    )
    VALUES (
        v_request_a,
        v_request_b,
        'RECIPROCAL_REVIEW',
        v_finalizer,
        'SQL_TEST_STEP7_RECIPROCAL'
    );

    INSERT INTO access_control.authority_grants (
        authority_grant_id, identity_id, authority_definition_id,
        purpose_definition_id, operation_definition_id, service_id,
        organization_id, governed_scope_id, applies_to_all_governed_scopes,
        protected_target_type, protected_target_reference,
        applies_to_all_targets, scope_reference, status, valid_from,
        valid_until, granted_by_identity_id, approval_request_id,
        delegated_from_authority_grant_id, delegation_depth
    )
    VALUES
        (
            v_grant_a, v_identity_a, v_authority, v_purpose, v_operation,
            v_service, v_organization, NULL, true, NULL, NULL, true, NULL,
            'ACTIVE', v_now - interval '1 day', v_now + interval '1 day',
            v_finalizer, NULL, NULL, 0
        ),
        (
            v_grant_b, v_identity_b, v_authority, v_purpose, v_operation,
            v_service, v_organization, NULL, true, NULL, NULL, true, NULL,
            'ACTIVE', v_now - interval '1 day', v_now + interval '1 day',
            v_finalizer, NULL, NULL, 0
        );

    request_a_id := v_request_a;
    request_b_id := v_request_b;
    stage_id := v_stage;
    identity_a_id := v_identity_a;
    identity_b_id := v_identity_b;
    organization_id := v_organization;
    session_a_id := v_session_a;
    session_b_id := v_session_b;
    grant_a_id := v_grant_a;
    grant_b_id := v_grant_b;
    approval_chain_id := v_chain;
    RETURN NEXT;
END;
$function$;
