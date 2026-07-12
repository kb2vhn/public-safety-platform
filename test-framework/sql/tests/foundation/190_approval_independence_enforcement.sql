-- ============================================================================
-- Phase 4 Step 4 approval independence enforcement
-- ============================================================================
--
-- Purpose:
-- Prove fail-closed self-approval, directly affected identity, duplicate
-- effective actor, distinct organization, Authority Grant origin, and explicit
-- circular or reciprocal approval enforcement at the controlled Approval
-- Action write boundary.
--
-- This step does not claim incompatible-authority, duty-conflict,
-- stage-satisfaction, finalization, or independent-connection race coverage.
-- ============================================================================

SELECT sql_test.begin_file(
    '190_approval_independence_enforcement.sql'
);

CREATE TEMP TABLE step4_ids (
    fixture_key text PRIMARY KEY,
    fixture_id uuid NOT NULL
) ON COMMIT PRESERVE ROWS;

CREATE TEMP TABLE step4_actions (
    fixture_key text PRIMARY KEY,
    approval_action_id uuid NOT NULL UNIQUE
) ON COMMIT PRESERVE ROWS;

CREATE FUNCTION sql_test.phase4_step4_id(p_fixture_key text)
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path = pg_catalog, sql_test
AS $function$
    SELECT fixture_id
    FROM pg_temp.step4_ids
    WHERE fixture_key = p_fixture_key;
$function$;

CREATE FUNCTION sql_test.create_phase4_step4_session(
    p_identity_id uuid,
    p_organization_id uuid,
    p_service_id uuid,
    p_fixture_key text
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_now timestamptz := statement_timestamp();
    v_provider_id uuid := sql_test.phase4_step4_id('provider');
    v_device_id uuid := sql_test.phase4_step4_id('device');
    v_assertion_id uuid := gen_random_uuid();
    v_external_id text :=
        'sql-test-phase4-step4-' || p_fixture_key || '-' ||
        gen_random_uuid()::text;
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
        v_external_id,
        'SESSION_ESTABLISHMENT',
        v_provider_id,
        p_identity_id,
        v_device_id,
        NULL,
        p_service_id,
        'phase4-step4-session',
        'test',
        v_now - interval '1 minute',
        v_now + interval '10 minutes',
        extensions.digest(
            convert_to(v_external_id || ':nonce', 'UTF8'),
            'sha256'
        ),
        extensions.digest(
            convert_to(v_external_id || ':payload', 'UTF8'),
            'sha256'
        ),
        'SQL-TEST-SIGNATURE',
        decode(repeat('66', 32), 'hex'),
        v_now - interval '30 seconds'
    );

    PERFORM access_control.mark_authentication_assertion_verified(
        v_assertion_id,
        'sql_test.phase4_step4_verifier',
        'sql_test.phase4_step4.v1'
    );

    RETURN access_control.establish_session_from_authentication_assertion(
        v_external_id,
        p_organization_id,
        interval '1 hour',
        interval '30 minutes',
        'phase4-step4-session',
        'test',
        gen_random_uuid()
    );
END;
$function$;

CREATE FUNCTION sql_test.phase4_step4_record(
    p_request_key text,
    p_stage_key text,
    p_actor_key text,
    p_organization_key text,
    p_session_key text,
    p_grant_key text,
    p_action_type text DEFAULT 'APPROVE',
    p_action_reason text DEFAULT NULL,
    p_reason_code text DEFAULT 'SQL_TEST_APPROVED',
    p_prior_action_key text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_action_id uuid;
    v_prior_action_id uuid;
BEGIN
    IF p_prior_action_key IS NOT NULL THEN
        SELECT approval_action_id
        INTO STRICT v_prior_action_id
        FROM pg_temp.step4_actions
        WHERE fixture_key = p_prior_action_key;
    END IF;

    SELECT recorded_approval_action_id
    INTO STRICT v_action_id
    FROM approval.record_approval_action(
        sql_test.phase4_step4_id(p_request_key),
        sql_test.phase4_step4_id(p_stage_key),
        sql_test.phase4_step4_id(p_actor_key),
        sql_test.phase4_step4_id(p_organization_key),
        sql_test.phase4_step4_id(p_session_key),
        sql_test.phase4_step4_id(p_grant_key),
        p_action_type,
        p_action_reason,
        p_reason_code,
        v_prior_action_id
    );

    RETURN v_action_id;
END;
$function$;

CREATE FUNCTION sql_test.phase4_step4_call_sql(
    p_request_key text,
    p_stage_key text,
    p_actor_key text,
    p_organization_key text,
    p_session_key text,
    p_grant_key text,
    p_action_type text DEFAULT 'APPROVE',
    p_action_reason text DEFAULT NULL,
    p_reason_code text DEFAULT 'SQL_TEST_APPROVED',
    p_prior_action_key text DEFAULT NULL
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, sql_test
AS $function$
    SELECT format(
        'SELECT sql_test.phase4_step4_record(%L,%L,%L,%L,%L,%L,%L,%L,%L,%L)',
        p_request_key,
        p_stage_key,
        p_actor_key,
        p_organization_key,
        p_session_key,
        p_grant_key,
        p_action_type,
        p_action_reason,
        p_reason_code,
        p_prior_action_key
    );
$function$;

CREATE FUNCTION sql_test.phase4_step4_error(p_sql text)
RETURNS text
LANGUAGE plpgsql
VOLATILE
SET search_path = pg_catalog, sql_test
AS $function$
BEGIN
    EXECUTE p_sql;
    RETURN 'NO_ERROR';
EXCEPTION
    WHEN OTHERS THEN
        RETURN SQLSTATE || ':' || SQLERRM;
END;
$function$;

DO $setup$
DECLARE
    v_now timestamptz := statement_timestamp();
    v_suffix text := replace(gen_random_uuid()::text, '-', '');

    v_provider_id uuid;
    v_device_id uuid;
    v_organization_id uuid;
    v_alternate_organization_id uuid;
    v_service_id uuid;
    v_purpose_id uuid;
    v_operation_id uuid;
    v_scope_id uuid;
    v_authority_id uuid;
    v_purpose_key text;
    v_operation_key text;

    v_person_a uuid := gen_random_uuid();
    v_person_b uuid := gen_random_uuid();
    v_person_c uuid := gen_random_uuid();
    v_person_d uuid := gen_random_uuid();
    v_identity_a uuid := gen_random_uuid();
    v_identity_b uuid := gen_random_uuid();
    v_identity_c uuid := gen_random_uuid();
    v_identity_d uuid := gen_random_uuid();

    v_strict_policy uuid := gen_random_uuid();
    v_permissive_policy uuid := gen_random_uuid();
    v_strict_stage uuid := gen_random_uuid();
    v_requester_flag_stage uuid := gen_random_uuid();
    v_org_stage uuid := gen_random_uuid();
    v_origin_stage uuid := gen_random_uuid();
    v_permissive_self_stage uuid := gen_random_uuid();
    v_permissive_affected_stage uuid := gen_random_uuid();

    v_self_request uuid := gen_random_uuid();
    v_self_stage_only_request uuid := gen_random_uuid();
    v_affected_request uuid := gen_random_uuid();
    v_duplicate_request uuid := gen_random_uuid();
    v_org_request uuid := gen_random_uuid();
    v_self_allowed_request uuid := gen_random_uuid();
    v_affected_allowed_request uuid := gen_random_uuid();

    v_origin_missing_request uuid := gen_random_uuid();
    v_origin_requester_request uuid := gen_random_uuid();
    v_origin_actor_request uuid := gen_random_uuid();
    v_origin_affected_request uuid := gen_random_uuid();
    v_origin_current_request uuid := gen_random_uuid();
    v_origin_chain_request uuid := gen_random_uuid();
    v_origin_chain_source_request uuid := gen_random_uuid();
    v_origin_dependency_request uuid := gen_random_uuid();
    v_origin_dependency_source_request uuid := gen_random_uuid();
    v_origin_independent_request uuid := gen_random_uuid();
    v_shared_origin_chain uuid := gen_random_uuid();

    v_reciprocal_a_request uuid := gen_random_uuid();
    v_reciprocal_b_request uuid := gen_random_uuid();
    v_reciprocal_chain uuid := gen_random_uuid();
    v_unlinked_a_request uuid := gen_random_uuid();
    v_unlinked_b_request uuid := gen_random_uuid();

    v_session_a_org1 uuid;
    v_session_b_org1 uuid;
    v_session_b_org1_second uuid;
    v_session_b_org2 uuid;
    v_session_c_org1 uuid;
    v_session_c_org2 uuid;

    v_grant_a_independent uuid := gen_random_uuid();
    v_grant_b_independent_org1 uuid := gen_random_uuid();
    v_grant_b_independent_org2 uuid := gen_random_uuid();
    v_grant_c_independent_org1 uuid := gen_random_uuid();
    v_grant_c_independent_org2 uuid := gen_random_uuid();
    v_grant_b_missing_origin uuid := gen_random_uuid();
    v_grant_b_requester_origin uuid := gen_random_uuid();
    v_grant_b_actor_origin uuid := gen_random_uuid();
    v_grant_b_affected_origin uuid := gen_random_uuid();
    v_grant_b_current_request_origin uuid := gen_random_uuid();
    v_grant_b_chain_origin uuid := gen_random_uuid();
    v_grant_b_dependency_origin uuid := gen_random_uuid();
BEGIN
    -- Step 4 builds a fresh behavioral fixture while reusing only the trusted
    -- catalog context established by the accepted Step 3 test immediately
    -- before this file in the authoritative sequential manifest.
    SELECT trust_provider_id
    INTO STRICT v_provider_id
    FROM trust.trust_providers
    WHERE provider_key LIKE 'sql_test.phase4_step3_provider_%'
    LIMIT 1;

    SELECT device_id
    INTO STRICT v_device_id
    FROM trust.devices
    WHERE device_key LIKE 'sql_test.phase4_step3_device_%'
    LIMIT 1;

    SELECT organization_id
    INTO STRICT v_organization_id
    FROM organization.organizations
    WHERE organization_key LIKE 'sql_test.phase4_step3_org_%'
    LIMIT 1;

    SELECT organization_id
    INTO STRICT v_alternate_organization_id
    FROM organization.organizations
    WHERE organization_key LIKE 'sql_test.phase4_step3_alt_org_%'
    LIMIT 1;

    SELECT service_id
    INTO STRICT v_service_id
    FROM service.platform_services
    WHERE service_key LIKE 'sql_test.phase4_step3_service_%'
    LIMIT 1;

    SELECT purpose_definition_id, purpose_key
    INTO STRICT v_purpose_id, v_purpose_key
    FROM access_control.purpose_definitions
    WHERE purpose_key LIKE 'sql_test.phase4_step3_purpose_%'
    LIMIT 1;

    SELECT operation_definition_id, operation_key
    INTO STRICT v_operation_id, v_operation_key
    FROM access_control.operation_definitions
    WHERE operation_key LIKE 'sql_test.phase4_step3_operation_%'
    LIMIT 1;

    SELECT governed_scope_id
    INTO STRICT v_scope_id
    FROM organization.governed_scopes
    WHERE governed_scope_key LIKE 'sql_test.phase4_step3_scope_%'
    LIMIT 1;

    SELECT authority_definition_id
    INTO STRICT v_authority_id
    FROM access_control.authority_definitions
    WHERE authority_key LIKE 'sql_test.phase4_step3_authority_%'
    LIMIT 1;

    INSERT INTO pg_temp.step4_ids (fixture_key, fixture_id)
    VALUES
        ('provider', v_provider_id),
        ('device', v_device_id),
        ('org1', v_organization_id),
        ('org2', v_alternate_organization_id),
        ('service', v_service_id),
        ('purpose', v_purpose_id),
        ('operation', v_operation_id),
        ('scope', v_scope_id),
        ('authority', v_authority_id),
        ('identity_a', v_identity_a),
        ('identity_b', v_identity_b),
        ('identity_c', v_identity_c),
        ('identity_d', v_identity_d),
        ('strict_policy', v_strict_policy),
        ('permissive_policy', v_permissive_policy),
        ('strict_stage', v_strict_stage),
        ('requester_flag_stage', v_requester_flag_stage),
        ('org_stage', v_org_stage),
        ('origin_stage', v_origin_stage),
        ('permissive_self_stage', v_permissive_self_stage),
        ('permissive_affected_stage', v_permissive_affected_stage),
        ('self_request', v_self_request),
        ('self_stage_only_request', v_self_stage_only_request),
        ('affected_request', v_affected_request),
        ('duplicate_request', v_duplicate_request),
        ('org_request', v_org_request),
        ('self_allowed_request', v_self_allowed_request),
        ('affected_allowed_request', v_affected_allowed_request),
        ('origin_missing_request', v_origin_missing_request),
        ('origin_requester_request', v_origin_requester_request),
        ('origin_actor_request', v_origin_actor_request),
        ('origin_affected_request', v_origin_affected_request),
        ('origin_current_request', v_origin_current_request),
        ('origin_chain_request', v_origin_chain_request),
        ('origin_chain_source_request', v_origin_chain_source_request),
        ('origin_dependency_request', v_origin_dependency_request),
        ('origin_dependency_source_request',
            v_origin_dependency_source_request),
        ('origin_independent_request', v_origin_independent_request),
        ('reciprocal_a_request', v_reciprocal_a_request),
        ('reciprocal_b_request', v_reciprocal_b_request),
        ('unlinked_a_request', v_unlinked_a_request),
        ('unlinked_b_request', v_unlinked_b_request);

    INSERT INTO identity.persons (
        person_id,
        person_key,
        display_name,
        status,
        created_by_reference
    )
    VALUES
        (v_person_a, 'sql_test.phase4_step4.person_a_' || v_suffix,
            'SQL Test Phase 4 Step 4 Identity A', 'ACTIVE', 'sql_test'),
        (v_person_b, 'sql_test.phase4_step4.person_b_' || v_suffix,
            'SQL Test Phase 4 Step 4 Identity B', 'ACTIVE', 'sql_test'),
        (v_person_c, 'sql_test.phase4_step4.person_c_' || v_suffix,
            'SQL Test Phase 4 Step 4 Identity C', 'ACTIVE', 'sql_test'),
        (v_person_d, 'sql_test.phase4_step4.person_d_' || v_suffix,
            'SQL Test Phase 4 Step 4 Independent Origin',
            'ACTIVE', 'sql_test');

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
        (v_identity_a, 'sql_test.phase4_step4.identity_a_' || v_suffix,
            'HUMAN', v_person_a, 'ACTIVE', 'TEST',
            v_now - interval '1 day', v_now + interval '1 day', 'sql_test'),
        (v_identity_b, 'sql_test.phase4_step4.identity_b_' || v_suffix,
            'HUMAN', v_person_b, 'ACTIVE', 'TEST',
            v_now - interval '1 day', v_now + interval '1 day', 'sql_test'),
        (v_identity_c, 'sql_test.phase4_step4.identity_c_' || v_suffix,
            'HUMAN', v_person_c, 'ACTIVE', 'TEST',
            v_now - interval '1 day', v_now + interval '1 day', 'sql_test'),
        (v_identity_d, 'sql_test.phase4_step4.identity_d_' || v_suffix,
            'HUMAN', v_person_d, 'ACTIVE', 'TEST',
            v_now - interval '1 day', v_now + interval '1 day', 'sql_test');

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
    VALUES
        (v_strict_policy,
            'sql_test.phase4_step4.strict_policy_' || v_suffix,
            1, 'SQL Test Phase 4 Step 4 Strict Policy', 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day',
            false, 'sql_test'),
        (v_permissive_policy,
            'sql_test.phase4_step4.permissive_policy_' || v_suffix,
            1, 'SQL Test Phase 4 Step 4 Explicit-Allow Policy', 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day',
            true, 'sql_test');

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
        authority_origin_independence_required
    )
    VALUES
        (v_strict_stage, v_strict_policy, 1, 'STRICT_REVIEW', 2,
            true, false, 'Typed Step 4 authority', v_authority_id,
            false, false, false),
        (v_requester_flag_stage, v_strict_policy, 2,
            'REQUESTER_FLAG_REVIEW', 1, true, false,
            'Typed Step 4 authority', v_authority_id,
            true, false, false),
        (v_org_stage, v_strict_policy, 3, 'ORGANIZATION_REVIEW', 2,
            true, true, 'Typed Step 4 authority', v_authority_id,
            false, false, false),
        (v_origin_stage, v_strict_policy, 4, 'ORIGIN_REVIEW', 1,
            true, false, 'Typed Step 4 authority', v_authority_id,
            false, false, true),
        (v_permissive_self_stage, v_permissive_policy, 1,
            'EXPLICIT_SELF_REVIEW', 1, true, false,
            'Typed Step 4 authority', v_authority_id,
            true, true, false),
        (v_permissive_affected_stage, v_permissive_policy, 2,
            'EXPLICIT_AFFECTED_REVIEW', 1, true, false,
            'Typed Step 4 authority', v_authority_id,
            false, true, false);

    -- Sessions are established before the Approval Requests so the same
    -- identity can be exercised across exact organization contexts.
    v_session_a_org1 := sql_test.create_phase4_step4_session(
        v_identity_a, v_organization_id, v_service_id, 'a-org1');
    v_session_b_org1 := sql_test.create_phase4_step4_session(
        v_identity_b, v_organization_id, v_service_id, 'b-org1');
    v_session_b_org1_second := sql_test.create_phase4_step4_session(
        v_identity_b, v_organization_id, v_service_id, 'b-org1-second');
    v_session_b_org2 := sql_test.create_phase4_step4_session(
        v_identity_b, v_alternate_organization_id, v_service_id, 'b-org2');
    v_session_c_org1 := sql_test.create_phase4_step4_session(
        v_identity_c, v_organization_id, v_service_id, 'c-org1');
    v_session_c_org2 := sql_test.create_phase4_step4_session(
        v_identity_c, v_alternate_organization_id, v_service_id, 'c-org2');

    INSERT INTO pg_temp.step4_ids (fixture_key, fixture_id)
    VALUES
        ('session_a_org1', v_session_a_org1),
        ('session_b_org1', v_session_b_org1),
        ('session_b_org1_second', v_session_b_org1_second),
        ('session_b_org2', v_session_b_org2),
        ('session_c_org1', v_session_c_org1),
        ('session_c_org2', v_session_c_org2);

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
    VALUES
        (v_self_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'self',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_c,
            gen_random_uuid()),
        (v_self_stage_only_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'self-stage-only',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_c,
            gen_random_uuid()),
        (v_affected_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'affected',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_b,
            gen_random_uuid()),
        (v_duplicate_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'duplicate',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_c,
            gen_random_uuid()),
        (v_org_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'organization',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_a,
            gen_random_uuid()),
        (v_self_allowed_request, v_permissive_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'self-allowed',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_a,
            gen_random_uuid()),
        (v_affected_allowed_request, v_permissive_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'affected-allowed',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_b,
            gen_random_uuid()),
        (v_origin_missing_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'origin-missing',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_c,
            gen_random_uuid()),
        (v_origin_requester_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'origin-requester',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_c,
            gen_random_uuid()),
        (v_origin_actor_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'origin-actor',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_c,
            gen_random_uuid()),
        (v_origin_affected_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'origin-affected',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_c,
            gen_random_uuid()),
        (v_origin_current_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'origin-current',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_c,
            gen_random_uuid()),
        (v_origin_chain_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'origin-chain',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_c,
            v_shared_origin_chain),
        (v_origin_chain_source_request, v_strict_policy, v_identity_d,
            v_organization_id, NULL, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE',
            'origin-chain-source', v_scope_id, 'TEST', 'PENDING',
            v_now, v_now + interval '1 hour', gen_random_uuid(),
            v_purpose_id, v_operation_id, v_identity_d,
            v_shared_origin_chain),
        (v_origin_dependency_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE',
            'origin-dependency', v_scope_id, 'TEST', 'PENDING',
            v_now, v_now + interval '1 hour', gen_random_uuid(),
            v_purpose_id, v_operation_id, v_identity_c, gen_random_uuid()),
        (v_origin_dependency_source_request, v_strict_policy, v_identity_d,
            v_organization_id, NULL, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE',
            'origin-dependency-source', v_scope_id, 'TEST', 'PENDING',
            v_now, v_now + interval '1 hour', gen_random_uuid(),
            v_purpose_id, v_operation_id, v_identity_d, gen_random_uuid()),
        (v_origin_independent_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE',
            'origin-independent', v_scope_id, 'TEST', 'PENDING',
            v_now, v_now + interval '1 hour', gen_random_uuid(),
            v_purpose_id, v_operation_id, v_identity_c, gen_random_uuid()),
        (v_reciprocal_a_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'reciprocal-a',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_a,
            v_reciprocal_chain),
        (v_reciprocal_b_request, v_strict_policy, v_identity_b,
            v_organization_id, v_session_b_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'reciprocal-b',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_b,
            v_reciprocal_chain),
        (v_unlinked_a_request, v_strict_policy, v_identity_a,
            v_organization_id, v_session_a_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'unlinked-a',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_a,
            gen_random_uuid()),
        (v_unlinked_b_request, v_strict_policy, v_identity_b,
            v_organization_id, v_session_b_org1, v_service_id,
            v_purpose_key, v_operation_key, 'TEST_RESOURCE', 'unlinked-b',
            v_scope_id, 'TEST', 'PENDING', v_now, v_now + interval '1 hour',
            gen_random_uuid(), v_purpose_id, v_operation_id, v_identity_b,
            gen_random_uuid());

    INSERT INTO approval.approval_request_dependencies (
        approval_request_id,
        depends_on_approval_request_id,
        dependency_type,
        created_by_identity_id,
        reason_code
    )
    VALUES
        (v_origin_dependency_request, v_origin_dependency_source_request,
            'SHARED_APPROVAL_CHAIN', v_identity_d,
            'SQL_TEST_EXPLICIT_ORIGIN_LINK'),
        (v_reciprocal_a_request, v_reciprocal_b_request,
            'RECIPROCAL_REVIEW', v_identity_d,
            'SQL_TEST_RECIPROCAL_LINK');

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
        approval_request_id
    )
    VALUES
        (v_grant_a_independent, v_identity_a, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id, v_organization_id,
            NULL, true, NULL, NULL, true, NULL, 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day',
            v_identity_d, NULL),
        (v_grant_b_independent_org1, v_identity_b, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id, v_organization_id,
            NULL, true, NULL, NULL, true, NULL, 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day',
            v_identity_d, NULL),
        (v_grant_b_independent_org2, v_identity_b, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id,
            v_alternate_organization_id, NULL, true, NULL, NULL, true,
            NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_d, NULL),
        (v_grant_c_independent_org1, v_identity_c, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id, v_organization_id,
            NULL, true, NULL, NULL, true, NULL, 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day',
            v_identity_d, NULL),
        (v_grant_c_independent_org2, v_identity_c, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id,
            v_alternate_organization_id, NULL, true, NULL, NULL, true,
            NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_d, NULL),
        (v_grant_b_missing_origin, v_identity_b, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id, v_organization_id,
            NULL, true, NULL, NULL, true, NULL, 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day', NULL, NULL),
        (v_grant_b_requester_origin, v_identity_b, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id, v_organization_id,
            NULL, true, NULL, NULL, true, NULL, 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day',
            v_identity_a, NULL),
        (v_grant_b_actor_origin, v_identity_b, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id, v_organization_id,
            NULL, true, NULL, NULL, true, NULL, 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day',
            v_identity_b, NULL),
        (v_grant_b_affected_origin, v_identity_b, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id, v_organization_id,
            NULL, true, NULL, NULL, true, NULL, 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day',
            v_identity_c, NULL),
        (v_grant_b_current_request_origin, v_identity_b, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id, v_organization_id,
            NULL, true, NULL, NULL, true, NULL, 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day',
            v_identity_d, v_origin_current_request),
        (v_grant_b_chain_origin, v_identity_b, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id, v_organization_id,
            NULL, true, NULL, NULL, true, NULL, 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day',
            v_identity_d, v_origin_chain_source_request),
        (v_grant_b_dependency_origin, v_identity_b, v_authority_id,
            v_purpose_id, v_operation_id, v_service_id, v_organization_id,
            NULL, true, NULL, NULL, true, NULL, 'ACTIVE',
            v_now - interval '1 day', v_now + interval '1 day',
            v_identity_d, v_origin_dependency_source_request);

    INSERT INTO pg_temp.step4_ids (fixture_key, fixture_id)
    VALUES
        ('grant_a_independent', v_grant_a_independent),
        ('grant_b_independent_org1', v_grant_b_independent_org1),
        ('grant_b_independent_org2', v_grant_b_independent_org2),
        ('grant_c_independent_org1', v_grant_c_independent_org1),
        ('grant_c_independent_org2', v_grant_c_independent_org2),
        ('grant_b_missing_origin', v_grant_b_missing_origin),
        ('grant_b_requester_origin', v_grant_b_requester_origin),
        ('grant_b_actor_origin', v_grant_b_actor_origin),
        ('grant_b_affected_origin', v_grant_b_affected_origin),
        ('grant_b_current_request_origin', v_grant_b_current_request_origin),
        ('grant_b_chain_origin', v_grant_b_chain_origin),
        ('grant_b_dependency_origin', v_grant_b_dependency_origin);
END;
$setup$;

-- --------------------------------------------------------------------------
-- Structural and security synchronization
-- --------------------------------------------------------------------------

SELECT sql_test.assert_true(
    'Step 4 organization lookup index exists',
    to_regclass('approval.approval_actions_phase4_organization_idx')
        IS NOT NULL
);

SELECT sql_test.assert_true(
    'Controlled Approval Action comment records Step 4 independence behavior',
    obj_description(
        'approval.record_approval_action(uuid,uuid,uuid,uuid,uuid,uuid,text,text,text,uuid)'::regprocedure,
        'pg_proc'
    ) LIKE '%self-approval%authority-origin%reciprocal-chain%'
);

SELECT sql_test.assert_true(
    'Requester approval column comment reflects controlled enforcement',
    col_description(
        'approval.approval_policy_stages'::regclass,
        (
            SELECT attnum
            FROM pg_attribute
            WHERE attrelid = 'approval.approval_policy_stages'::regclass
              AND attname = 'requester_approval_allowed'
        )
    ) LIKE '%controlled Approval Action recording enforces%'
);

SELECT sql_test.assert_true(
    'Controlled Approval Action routine remains unavailable to PUBLIC',
    NOT EXISTS (
        SELECT 1
        FROM information_schema.routine_privileges
        WHERE grantee = 'PUBLIC'
          AND routine_schema = 'approval'
          AND routine_name = 'record_approval_action'
    )
);

-- --------------------------------------------------------------------------
-- Self-approval and directly affected identity
-- --------------------------------------------------------------------------

SELECT sql_test.assert_true(
    'Strict policy rejects requester self-approval with a stable reason code',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'self_request', 'strict_stage', 'identity_a', 'org1',
            'session_a_org1', 'grant_a_independent'
        )
    ) = '28000:SELF_APPROVAL_PROHIBITED'
);

SELECT sql_test.assert_true(
    'Rejected requester self-approval creates no Approval Action Record',
    NOT EXISTS (
        SELECT 1
        FROM approval.approval_actions
        WHERE approval_request_id =
              sql_test.phase4_step4_id('self_request')
    )
);

SELECT sql_test.assert_true(
    'Stage requester flag cannot override a policy that prohibits self-approval',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'self_stage_only_request', 'requester_flag_stage', 'identity_a',
            'org1', 'session_a_org1', 'grant_a_independent'
        )
    ) = '28000:SELF_APPROVAL_PROHIBITED'
);

SELECT sql_test.assert_true(
    'Strict policy rejects the directly affected identity',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'affected_request', 'strict_stage', 'identity_b', 'org1',
            'session_b_org1', 'grant_b_independent_org1'
        )
    ) = '28000:AFFECTED_IDENTITY_APPROVAL_PROHIBITED'
);

SELECT sql_test.assert_true(
    'Rejected affected-identity approval creates no Approval Action Record',
    NOT EXISTS (
        SELECT 1
        FROM approval.approval_actions
        WHERE approval_request_id =
              sql_test.phase4_step4_id('affected_request')
    )
);

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'self_allowed',
    sql_test.phase4_step4_record(
        'self_allowed_request', 'permissive_self_stage', 'identity_a',
        'org1', 'session_a_org1', 'grant_a_independent'
    )
);

SELECT sql_test.assert_true(
    'Self-approval records only when policy and exact stage both allow it',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions
        WHERE approval_action_id = (
            SELECT approval_action_id
            FROM pg_temp.step4_actions
            WHERE fixture_key = 'self_allowed'
        )
    )
);

SELECT sql_test.assert_true(
    'Explicit self-approval preserves the requester as effective actor',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions AS action_record
        JOIN approval.approval_requests AS request_record
          ON request_record.approval_request_id =
             action_record.approval_request_id
        WHERE action_record.approval_action_id = (
            SELECT approval_action_id
            FROM pg_temp.step4_actions
            WHERE fixture_key = 'self_allowed'
        )
          AND action_record.effective_actor_identity_id =
              request_record.requester_identity_id
    )
);

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'affected_allowed',
    sql_test.phase4_step4_record(
        'affected_allowed_request', 'permissive_affected_stage',
        'identity_b', 'org1', 'session_b_org1',
        'grant_b_independent_org1'
    )
);

SELECT sql_test.assert_true(
    'Directly affected identity approval records only when exact stage allows it',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions
        WHERE approval_action_id = (
            SELECT approval_action_id
            FROM pg_temp.step4_actions
            WHERE fixture_key = 'affected_allowed'
        )
    )
);

-- --------------------------------------------------------------------------
-- Duplicate effective actor and distinct organization
-- --------------------------------------------------------------------------

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'duplicate_first',
    sql_test.phase4_step4_record(
        'duplicate_request', 'strict_stage', 'identity_b', 'org1',
        'session_b_org1', 'grant_b_independent_org1'
    )
);

SELECT sql_test.assert_true(
    'First independent approval from an effective actor records',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_actions
        WHERE fixture_key = 'duplicate_first'
    )
);

SELECT sql_test.assert_true(
    'Second current approval from the same effective actor is rejected',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'duplicate_request', 'strict_stage', 'identity_b', 'org1',
            'session_b_org1', 'grant_b_independent_org1'
        )
    ) = '28000:DUPLICATE_EFFECTIVE_ACTOR'
);

SELECT sql_test.assert_true(
    'A different session does not make the same identity independent',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'duplicate_request', 'strict_stage', 'identity_b', 'org1',
            'session_b_org1_second', 'grant_b_independent_org1'
        )
    ) = '28000:DUPLICATE_EFFECTIVE_ACTOR'
);

SELECT sql_test.assert_true(
    'Duplicate attempts leave exactly one current approval for the actor',
    (
        SELECT count(*)
        FROM approval.approval_actions
        WHERE approval_request_id =
              sql_test.phase4_step4_id('duplicate_request')
          AND action_type = 'APPROVE'
    ) = 1
);

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'duplicate_withdrawal',
    sql_test.phase4_step4_record(
        'duplicate_request', 'strict_stage', 'identity_b', 'org1',
        'session_b_org1', 'grant_b_independent_org1',
        'WITHDRAW_APPROVAL', 'SQL test withdrawal',
        'SQL_TEST_APPROVAL_WITHDRAWN', 'duplicate_first'
    )
);

SELECT sql_test.assert_true(
    'Withdrawal creates typed lineage to the prior approval',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions AS withdrawal
        JOIN pg_temp.step4_actions AS prior
          ON prior.fixture_key = 'duplicate_first'
         AND prior.approval_action_id =
             withdrawal.prior_approval_action_id
        WHERE withdrawal.approval_action_id = (
            SELECT approval_action_id
            FROM pg_temp.step4_actions
            WHERE fixture_key = 'duplicate_withdrawal'
        )
          AND withdrawal.action_type = 'WITHDRAW_APPROVAL'
    )
);

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'duplicate_reapproval',
    sql_test.phase4_step4_record(
        'duplicate_request', 'strict_stage', 'identity_b', 'org1',
        'session_b_org1_second', 'grant_b_independent_org1'
    )
);

SELECT sql_test.assert_true(
    'Actor may record a replacement approval after the prior approval is withdrawn',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_actions
        WHERE fixture_key = 'duplicate_reapproval'
    )
);

SELECT sql_test.assert_true(
    'Withdrawal leaves exactly one current approval from the effective actor',
    (
        SELECT count(*)
        FROM approval.approval_actions AS approval_record
        WHERE approval_record.approval_request_id =
              sql_test.phase4_step4_id('duplicate_request')
          AND approval_record.action_type = 'APPROVE'
          AND NOT EXISTS (
              SELECT 1
              FROM approval.approval_actions AS later_action
              WHERE later_action.prior_approval_action_id =
                    approval_record.approval_action_id
                AND later_action.action_type IN (
                    'WITHDRAW_APPROVAL', 'CORRECT', 'SUPERSEDE'
                )
          )
    ) = 1
);

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'org_first',
    sql_test.phase4_step4_record(
        'org_request', 'org_stage', 'identity_b', 'org1',
        'session_b_org1', 'grant_b_independent_org1'
    )
);

SELECT sql_test.assert_true(
    'First organization-independent approval records',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_actions
        WHERE fixture_key = 'org_first'
    )
);

SELECT sql_test.assert_true(
    'Different identity in the same organization does not satisfy organization independence',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'org_request', 'org_stage', 'identity_c', 'org1',
            'session_c_org1', 'grant_c_independent_org1'
        )
    ) = '28000:INDEPENDENT_ORGANIZATION_REQUIRED'
);

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'org_second',
    sql_test.phase4_step4_record(
        'org_request', 'org_stage', 'identity_c', 'org2',
        'session_c_org2', 'grant_c_independent_org2'
    )
);

SELECT sql_test.assert_true(
    'Distinct identity in a distinct organization records',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_actions
        WHERE fixture_key = 'org_second'
    )
);

SELECT sql_test.assert_true(
    'Organization-independent request has two distinct acting organizations',
    (
        SELECT count(DISTINCT acting_organization_id)
        FROM approval.approval_actions
        WHERE approval_request_id =
              sql_test.phase4_step4_id('org_request')
          AND action_type = 'APPROVE'
    ) = 2
);

-- --------------------------------------------------------------------------
-- Authority-origin independence
-- --------------------------------------------------------------------------

SELECT sql_test.assert_true(
    'Missing Authority Grant origin fails closed',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'origin_missing_request', 'origin_stage', 'identity_b', 'org1',
            'session_b_org1', 'grant_b_missing_origin'
        )
    ) = '28000:AUTHORITY_ORIGIN_NOT_INDEPENDENT'
);

SELECT sql_test.assert_true(
    'Authority granted by the requester is not independent',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'origin_requester_request', 'origin_stage', 'identity_b', 'org1',
            'session_b_org1', 'grant_b_requester_origin'
        )
    ) = '28000:AUTHORITY_ORIGIN_NOT_INDEPENDENT'
);

SELECT sql_test.assert_true(
    'Authority granted by the acting identity is not independent',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'origin_actor_request', 'origin_stage', 'identity_b', 'org1',
            'session_b_org1', 'grant_b_actor_origin'
        )
    ) = '28000:AUTHORITY_ORIGIN_NOT_INDEPENDENT'
);

SELECT sql_test.assert_true(
    'Authority granted by the directly affected identity is not independent',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'origin_affected_request', 'origin_stage', 'identity_b', 'org1',
            'session_b_org1', 'grant_b_affected_origin'
        )
    ) = '28000:AUTHORITY_ORIGIN_NOT_INDEPENDENT'
);

SELECT sql_test.assert_true(
    'Authority originating from the same Approval Request is not independent',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'origin_current_request', 'origin_stage', 'identity_b', 'org1',
            'session_b_org1', 'grant_b_current_request_origin'
        )
    ) = '28000:AUTHORITY_ORIGIN_NOT_INDEPENDENT'
);

SELECT sql_test.assert_true(
    'Authority originating from the same explicit approval chain is not independent',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'origin_chain_request', 'origin_stage', 'identity_b', 'org1',
            'session_b_org1', 'grant_b_chain_origin'
        )
    ) = '28000:AUTHORITY_ORIGIN_NOT_INDEPENDENT'
);

SELECT sql_test.assert_true(
    'Authority originating from an explicitly linked request is not independent',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'origin_dependency_request', 'origin_stage', 'identity_b', 'org1',
            'session_b_org1', 'grant_b_dependency_origin'
        )
    ) = '28000:AUTHORITY_ORIGIN_NOT_INDEPENDENT'
);

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'origin_independent',
    sql_test.phase4_step4_record(
        'origin_independent_request', 'origin_stage', 'identity_b', 'org1',
        'session_b_org1', 'grant_b_independent_org1'
    )
);

SELECT sql_test.assert_true(
    'Independent Authority Grant origin records successfully',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_actions
        WHERE fixture_key = 'origin_independent'
    )
);

SELECT sql_test.assert_true(
    'All rejected Authority Grant origin scenarios remain action-free',
    (
        SELECT count(*)
        FROM approval.approval_actions
        WHERE approval_request_id IN (
            sql_test.phase4_step4_id('origin_missing_request'),
            sql_test.phase4_step4_id('origin_requester_request'),
            sql_test.phase4_step4_id('origin_actor_request'),
            sql_test.phase4_step4_id('origin_affected_request'),
            sql_test.phase4_step4_id('origin_current_request'),
            sql_test.phase4_step4_id('origin_chain_request'),
            sql_test.phase4_step4_id('origin_dependency_request')
        )
    ) = 0
);

-- --------------------------------------------------------------------------
-- Explicit circular and reciprocal approval
-- --------------------------------------------------------------------------

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'reciprocal_first',
    sql_test.phase4_step4_record(
        'reciprocal_b_request', 'strict_stage', 'identity_a', 'org1',
        'session_a_org1', 'grant_a_independent'
    )
);

SELECT sql_test.assert_true(
    'First side of an explicit reciprocal pair records',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_actions
        WHERE fixture_key = 'reciprocal_first'
    )
);

SELECT sql_test.assert_true(
    'Reverse side of an explicit reciprocal pair is rejected',
    sql_test.phase4_step4_error(
        sql_test.phase4_step4_call_sql(
            'reciprocal_a_request', 'strict_stage', 'identity_b', 'org1',
            'session_b_org1', 'grant_b_independent_org1'
        )
    ) = '28000:CIRCULAR_APPROVAL_PROHIBITED'
);

SELECT sql_test.assert_true(
    'Rejected reciprocal action creates no reverse Approval Action Record',
    NOT EXISTS (
        SELECT 1
        FROM approval.approval_actions
        WHERE approval_request_id =
              sql_test.phase4_step4_id('reciprocal_a_request')
    )
);

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'reciprocal_withdrawal',
    sql_test.phase4_step4_record(
        'reciprocal_b_request', 'strict_stage', 'identity_a', 'org1',
        'session_a_org1', 'grant_a_independent',
        'WITHDRAW_APPROVAL', 'SQL test reciprocal withdrawal',
        'SQL_TEST_RECIPROCAL_WITHDRAWN', 'reciprocal_first'
    )
);

SELECT sql_test.assert_true(
    'Withdrawal makes the first reciprocal approval non-current',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions
        WHERE approval_action_id = (
            SELECT approval_action_id
            FROM pg_temp.step4_actions
            WHERE fixture_key = 'reciprocal_withdrawal'
        )
          AND action_type = 'WITHDRAW_APPROVAL'
    )
);

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'reciprocal_after_withdrawal',
    sql_test.phase4_step4_record(
        'reciprocal_a_request', 'strict_stage', 'identity_b', 'org1',
        'session_b_org1', 'grant_b_independent_org1'
    )
);

SELECT sql_test.assert_true(
    'Reverse approval may record after the linked approval is withdrawn',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_actions
        WHERE fixture_key = 'reciprocal_after_withdrawal'
    )
);

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'unlinked_first',
    sql_test.phase4_step4_record(
        'unlinked_b_request', 'strict_stage', 'identity_a', 'org1',
        'session_a_org1', 'grant_a_independent'
    )
);

SELECT sql_test.assert_true(
    'First approval in an unlinked pair records',
    EXISTS (
        SELECT 1 FROM pg_temp.step4_actions
        WHERE fixture_key = 'unlinked_first'
    )
);

INSERT INTO pg_temp.step4_actions (fixture_key, approval_action_id)
VALUES (
    'unlinked_second',
    sql_test.phase4_step4_record(
        'unlinked_a_request', 'strict_stage', 'identity_b', 'org1',
        'session_b_org1', 'grant_b_independent_org1'
    )
);

SELECT sql_test.assert_true(
    'No reciprocal cycle is inferred from time proximity without explicit linkage',
    (
        SELECT count(*)
        FROM approval.approval_actions
        WHERE approval_action_id IN (
            SELECT approval_action_id
            FROM pg_temp.step4_actions
            WHERE fixture_key IN ('unlinked_first', 'unlinked_second')
        )
          AND action_type = 'APPROVE'
    ) = 2
);


SELECT sql_test.assert_true(
    'Step 4 scenarios create exactly thirteen successful Approval Action Records',
    (
        SELECT count(*)
        FROM approval.approval_actions AS action_record
        JOIN approval.approval_requests AS request_record
          ON request_record.approval_request_id =
             action_record.approval_request_id
        WHERE request_record.approval_policy_id IN (
            sql_test.phase4_step4_id('strict_policy'),
            sql_test.phase4_step4_id('permissive_policy')
        )
    ) = 13
);
