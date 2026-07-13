-- ============================================================================
-- Phase 4 Step 5 incompatible-authority and separation-of-duties enforcement
-- ============================================================================
--
-- Purpose:
-- Prove explicit direct and delegated Authority Grant lineage, the
-- JOINT_EXERCISE, CONCURRENT_HOLDING, and CHAIN_PARTICIPATION modes,
-- immutable APPROVE duty recording, prohibited duty combinations, and
-- fail-closed handling of an unavailable authorization-chain duty scope.
--
-- Stage satisfaction, Approval Request finalization, and independent-
-- connection approval races remain later Phase 4 steps.
-- ============================================================================

SELECT sql_test.begin_file(
    '200_incompatible_authority_and_duty_conflict_enforcement.sql'
);

CREATE TEMP TABLE step5_ids (
    fixture_key text PRIMARY KEY,
    fixture_id uuid NOT NULL
) ON COMMIT PRESERVE ROWS;

CREATE TEMP TABLE step5_actions (
    fixture_key text PRIMARY KEY,
    approval_action_id uuid NOT NULL UNIQUE
) ON COMMIT PRESERVE ROWS;

CREATE FUNCTION sql_test.phase4_step5_id(p_fixture_key text)
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path = pg_catalog, sql_test
AS $function$
    SELECT fixture_id
    FROM pg_temp.step5_ids
    WHERE fixture_key = p_fixture_key;
$function$;

CREATE FUNCTION sql_test.create_phase4_step5_session(
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
    v_provider_id uuid := sql_test.phase4_step5_id('provider');
    v_device_id uuid := sql_test.phase4_step5_id('device');
    v_assertion_id uuid := gen_random_uuid();
    v_external_id text :=
        'sql-test-phase4-step5-' || p_fixture_key || '-' ||
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
        'phase4-step5-session',
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
        decode(repeat('67', 32), 'hex'),
        v_now - interval '30 seconds'
    );

    PERFORM access_control.mark_authentication_assertion_verified(
        v_assertion_id,
        'sql_test.phase4_step5_verifier',
        'sql_test.phase4_step5.v1'
    );

    RETURN access_control.establish_session_from_authentication_assertion(
        v_external_id,
        p_organization_id,
        interval '1 hour',
        interval '30 minutes',
        'phase4-step5-session',
        'test',
        gen_random_uuid()
    );
END;
$function$;

CREATE FUNCTION sql_test.phase4_step5_record(
    p_action_key text,
    p_request_key text,
    p_stage_key text,
    p_actor_key text,
    p_session_key text,
    p_grant_key text,
    p_action_type text DEFAULT 'APPROVE',
    p_action_reason text DEFAULT NULL,
    p_reason_code text DEFAULT 'SQL_TEST_STEP5_APPROVED',
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
        FROM pg_temp.step5_actions
        WHERE fixture_key = p_prior_action_key;
    END IF;

    SELECT recorded_approval_action_id
    INTO STRICT v_action_id
    FROM approval.record_approval_action(
        sql_test.phase4_step5_id(p_request_key),
        sql_test.phase4_step5_id(p_stage_key),
        sql_test.phase4_step5_id(p_actor_key),
        sql_test.phase4_step5_id('org1'),
        sql_test.phase4_step5_id(p_session_key),
        sql_test.phase4_step5_id(p_grant_key),
        p_action_type,
        p_action_reason,
        p_reason_code,
        v_prior_action_id
    );

    INSERT INTO pg_temp.step5_actions (
        fixture_key,
        approval_action_id
    )
    VALUES (
        p_action_key,
        v_action_id
    );

    RETURN v_action_id;
END;
$function$;

CREATE FUNCTION sql_test.phase4_step5_call_sql(
    p_action_key text,
    p_request_key text,
    p_stage_key text,
    p_actor_key text,
    p_session_key text,
    p_grant_key text,
    p_action_type text DEFAULT 'APPROVE',
    p_action_reason text DEFAULT NULL,
    p_reason_code text DEFAULT 'SQL_TEST_STEP5_APPROVED',
    p_prior_action_key text DEFAULT NULL
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, sql_test
AS $function$
    SELECT format(
        'SELECT sql_test.phase4_step5_record(%L,%L,%L,%L,%L,%L,%L,%L,%L,%L)',
        p_action_key,
        p_request_key,
        p_stage_key,
        p_actor_key,
        p_session_key,
        p_grant_key,
        p_action_type,
        p_action_reason,
        p_reason_code,
        p_prior_action_key
    );
$function$;

CREATE FUNCTION sql_test.phase4_step5_error(p_sql text)
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
    v_org1 uuid;
    v_org2 uuid;
    v_service_id uuid;
    v_purpose_id uuid;
    v_operation_id uuid;
    v_scope_id uuid;
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

    v_policy uuid := gen_random_uuid();
    v_auth_a uuid := gen_random_uuid();
    v_auth_b uuid := gen_random_uuid();

    v_set_joint uuid := gen_random_uuid();
    v_set_concurrent_include uuid := gen_random_uuid();
    v_set_concurrent_exclude uuid := gen_random_uuid();
    v_set_chain uuid := gen_random_uuid();
    v_set_inactive uuid := gen_random_uuid();
    v_set_bad_member uuid := gen_random_uuid();

    v_stage_plain_a uuid := gen_random_uuid();
    v_stage_plain_b uuid := gen_random_uuid();
    v_stage_delegated_disallowed_a uuid := gen_random_uuid();
    v_stage_delegated_allowed_a uuid := gen_random_uuid();
    v_stage_delegated_depth1_a uuid := gen_random_uuid();
    v_stage_joint_a uuid := gen_random_uuid();
    v_stage_joint_b uuid := gen_random_uuid();
    v_stage_concurrent_include_a uuid := gen_random_uuid();
    v_stage_concurrent_exclude_a uuid := gen_random_uuid();
    v_stage_chain_a uuid := gen_random_uuid();
    v_stage_chain_b uuid := gen_random_uuid();
    v_stage_inactive_a uuid := gen_random_uuid();
    v_stage_bad_member_a uuid := gen_random_uuid();
    v_stage_duty_a uuid := gen_random_uuid();
    v_stage_duty_b uuid := gen_random_uuid();

    v_request_plain uuid := gen_random_uuid();
    v_request_delegated_disallowed uuid := gen_random_uuid();
    v_request_delegated_allowed uuid := gen_random_uuid();
    v_request_delegated_depth uuid := gen_random_uuid();
    v_request_delegated_invalid uuid := gen_random_uuid();
    v_request_joint uuid := gen_random_uuid();
    v_request_concurrent_include uuid := gen_random_uuid();
    v_request_concurrent_exclude uuid := gen_random_uuid();
    v_request_concurrent_context uuid := gen_random_uuid();
    v_request_concurrent_suspended uuid := gen_random_uuid();
    v_request_chain_a uuid := gen_random_uuid();
    v_request_chain_b uuid := gen_random_uuid();
    v_request_unlinked uuid := gen_random_uuid();
    v_request_inactive uuid := gen_random_uuid();
    v_request_bad_member uuid := gen_random_uuid();
    v_request_duty_request uuid := gen_random_uuid();
    v_request_duty_grant uuid := gen_random_uuid();
    v_request_duty_execute uuid := gen_random_uuid();
    v_request_duty_authchain uuid := gen_random_uuid();
    v_shared_chain uuid := gen_random_uuid();

    v_grant_a_direct_a uuid := gen_random_uuid();
    v_grant_a_direct_b uuid := gen_random_uuid();
    v_grant_a_context_b uuid := gen_random_uuid();
    v_grant_b_direct_a uuid := gen_random_uuid();
    v_grant_b_direct_b uuid := gen_random_uuid();
    v_grant_b_a_by_a uuid := gen_random_uuid();
    v_grant_c_direct_a uuid := gen_random_uuid();
    v_grant_c_direct_b uuid := gen_random_uuid();
    v_root_a uuid := gen_random_uuid();
    v_parent_a uuid := gen_random_uuid();
    v_grant_a_delegated_a uuid := gen_random_uuid();
    v_grant_a_depth2_a uuid := gen_random_uuid();
    v_grant_a_invalid_a uuid := gen_random_uuid();
    v_root_b uuid := gen_random_uuid();
    v_grant_a_delegated_b uuid := gen_random_uuid();

    v_session_a uuid;
    v_session_b uuid;
    v_session_c uuid;
BEGIN
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
    INTO STRICT v_org1
    FROM organization.organizations
    WHERE organization_key LIKE 'sql_test.phase4_step3_org_%'
    LIMIT 1;

    SELECT organization_id
    INTO STRICT v_org2
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

    INSERT INTO pg_temp.step5_ids (fixture_key, fixture_id)
    VALUES
        ('provider', v_provider_id),
        ('device', v_device_id),
        ('org1', v_org1),
        ('org2', v_org2),
        ('service', v_service_id),
        ('purpose', v_purpose_id),
        ('operation', v_operation_id),
        ('scope', v_scope_id),
        ('identity_a', v_identity_a),
        ('identity_b', v_identity_b),
        ('identity_c', v_identity_c),
        ('identity_d', v_identity_d),
        ('policy', v_policy),
        ('auth_a', v_auth_a),
        ('auth_b', v_auth_b),
        ('set_joint', v_set_joint),
        ('set_concurrent_include', v_set_concurrent_include),
        ('set_concurrent_exclude', v_set_concurrent_exclude),
        ('set_chain', v_set_chain),
        ('set_inactive', v_set_inactive),
        ('set_bad_member', v_set_bad_member),
        ('stage_plain_a', v_stage_plain_a),
        ('stage_plain_b', v_stage_plain_b),
        ('stage_delegated_disallowed_a', v_stage_delegated_disallowed_a),
        ('stage_delegated_allowed_a', v_stage_delegated_allowed_a),
        ('stage_delegated_depth1_a', v_stage_delegated_depth1_a),
        ('stage_joint_a', v_stage_joint_a),
        ('stage_joint_b', v_stage_joint_b),
        ('stage_concurrent_include_a', v_stage_concurrent_include_a),
        ('stage_concurrent_exclude_a', v_stage_concurrent_exclude_a),
        ('stage_chain_a', v_stage_chain_a),
        ('stage_chain_b', v_stage_chain_b),
        ('stage_inactive_a', v_stage_inactive_a),
        ('stage_bad_member_a', v_stage_bad_member_a),
        ('stage_duty_a', v_stage_duty_a),
        ('stage_duty_b', v_stage_duty_b),
        ('request_plain', v_request_plain),
        ('request_delegated_disallowed', v_request_delegated_disallowed),
        ('request_delegated_allowed', v_request_delegated_allowed),
        ('request_delegated_depth', v_request_delegated_depth),
        ('request_delegated_invalid', v_request_delegated_invalid),
        ('request_joint', v_request_joint),
        ('request_concurrent_include', v_request_concurrent_include),
        ('request_concurrent_exclude', v_request_concurrent_exclude),
        ('request_concurrent_context', v_request_concurrent_context),
        ('request_concurrent_suspended', v_request_concurrent_suspended),
        ('request_chain_a', v_request_chain_a),
        ('request_chain_b', v_request_chain_b),
        ('request_unlinked', v_request_unlinked),
        ('request_inactive', v_request_inactive),
        ('request_bad_member', v_request_bad_member),
        ('request_duty_request', v_request_duty_request),
        ('request_duty_grant', v_request_duty_grant),
        ('request_duty_execute', v_request_duty_execute),
        ('request_duty_authchain', v_request_duty_authchain),
        ('grant_a_direct_a', v_grant_a_direct_a),
        ('grant_a_direct_b', v_grant_a_direct_b),
        ('grant_a_context_b', v_grant_a_context_b),
        ('grant_b_direct_a', v_grant_b_direct_a),
        ('grant_b_direct_b', v_grant_b_direct_b),
        ('grant_b_a_by_a', v_grant_b_a_by_a),
        ('grant_c_direct_a', v_grant_c_direct_a),
        ('grant_c_direct_b', v_grant_c_direct_b),
        ('root_a', v_root_a),
        ('parent_a', v_parent_a),
        ('grant_a_delegated_a', v_grant_a_delegated_a),
        ('grant_a_depth2_a', v_grant_a_depth2_a),
        ('grant_a_invalid_a', v_grant_a_invalid_a),
        ('root_b', v_root_b),
        ('grant_a_delegated_b', v_grant_a_delegated_b);

    INSERT INTO identity.persons (
        person_id,
        person_key,
        display_name,
        status,
        created_by_reference
    )
    VALUES
        (v_person_a, 'sql_test.phase4_step5.person_a_' || v_suffix,
            'SQL Test Phase 4 Step 5 Identity A', 'ACTIVE', 'sql_test'),
        (v_person_b, 'sql_test.phase4_step5.person_b_' || v_suffix,
            'SQL Test Phase 4 Step 5 Identity B', 'ACTIVE', 'sql_test'),
        (v_person_c, 'sql_test.phase4_step5.person_c_' || v_suffix,
            'SQL Test Phase 4 Step 5 Identity C', 'ACTIVE', 'sql_test'),
        (v_person_d, 'sql_test.phase4_step5.person_d_' || v_suffix,
            'SQL Test Phase 4 Step 5 Identity D', 'ACTIVE', 'sql_test');

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
        (v_identity_a, 'sql_test.phase4_step5.identity_a_' || v_suffix,
            'HUMAN', v_person_a, 'ACTIVE', 'TEST',
            v_now - interval '1 day', v_now + interval '1 day', 'sql_test'),
        (v_identity_b, 'sql_test.phase4_step5.identity_b_' || v_suffix,
            'HUMAN', v_person_b, 'ACTIVE', 'TEST',
            v_now - interval '1 day', v_now + interval '1 day', 'sql_test'),
        (v_identity_c, 'sql_test.phase4_step5.identity_c_' || v_suffix,
            'HUMAN', v_person_c, 'ACTIVE', 'TEST',
            v_now - interval '1 day', v_now + interval '1 day', 'sql_test'),
        (v_identity_d, 'sql_test.phase4_step5.identity_d_' || v_suffix,
            'HUMAN', v_person_d, 'ACTIVE', 'TEST',
            v_now - interval '1 day', v_now + interval '1 day', 'sql_test');

    INSERT INTO access_control.authority_definitions (
        authority_definition_id,
        authority_key,
        title,
        description,
        status,
        delegation_allowed
    )
    VALUES
        (v_auth_a, 'sql_test.phase4_step5.auth_a_' || v_suffix,
            'SQL Test Step 5 Authority A', 'First incompatible authority.',
            'ACTIVE', true),
        (v_auth_b, 'sql_test.phase4_step5.auth_b_' || v_suffix,
            'SQL Test Step 5 Authority B', 'Second incompatible authority.',
            'ACTIVE', true);

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
        'sql_test.phase4_step5.policy_' || v_suffix,
        1,
        'SQL Test Phase 4 Step 5 Policy',
        'ACTIVE',
        v_now - interval '1 day',
        v_now + interval '1 day',
        true,
        'sql_test'
    );

    INSERT INTO access_control.incompatible_authority_sets (
        incompatible_authority_set_id,
        set_key,
        title,
        description,
        status,
        default_enforcement_mode,
        include_delegated_grants
    )
    VALUES
        (v_set_joint, 'sql_test.phase4_step5.joint_' || v_suffix,
            'Step 5 Joint Exercise', 'Joint exercise test set.', 'ACTIVE',
            'JOINT_EXERCISE', true),
        (v_set_concurrent_include,
            'sql_test.phase4_step5.concurrent_include_' || v_suffix,
            'Step 5 Concurrent Include', 'Includes delegated grants.',
            'ACTIVE', 'CONCURRENT_HOLDING', true),
        (v_set_concurrent_exclude,
            'sql_test.phase4_step5.concurrent_exclude_' || v_suffix,
            'Step 5 Concurrent Exclude', 'Excludes delegated grants.',
            'ACTIVE', 'CONCURRENT_HOLDING', false),
        (v_set_chain, 'sql_test.phase4_step5.chain_' || v_suffix,
            'Step 5 Chain Participation', 'Chain participation test set.',
            'ACTIVE', 'CHAIN_PARTICIPATION', true),
        (v_set_inactive, 'sql_test.phase4_step5.inactive_' || v_suffix,
            'Step 5 Inactive Set', 'Inactive set must fail closed.',
            'SUSPENDED', 'JOINT_EXERCISE', true),
        (v_set_bad_member, 'sql_test.phase4_step5.bad_member_' || v_suffix,
            'Step 5 Bad Member Set', 'Required authority is not a member.',
            'ACTIVE', 'JOINT_EXERCISE', true);

    INSERT INTO access_control.incompatible_authority_members (
        incompatible_authority_set_id,
        authority_definition_id
    )
    SELECT set_id, authority_id
    FROM (
        VALUES
            (v_set_joint, v_auth_a),
            (v_set_joint, v_auth_b),
            (v_set_concurrent_include, v_auth_a),
            (v_set_concurrent_include, v_auth_b),
            (v_set_concurrent_exclude, v_auth_a),
            (v_set_concurrent_exclude, v_auth_b),
            (v_set_chain, v_auth_a),
            (v_set_chain, v_auth_b),
            (v_set_inactive, v_auth_a),
            (v_set_inactive, v_auth_b),
            (v_set_bad_member, v_auth_b)
    ) AS members(set_id, authority_id);

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
        delegated_authority_allowed,
        maximum_delegation_depth,
        incompatible_authority_set_id,
        incompatible_authority_mode
    )
    VALUES
        (v_stage_plain_a, v_policy, 1, 'PLAIN_A', 1, true, false,
            'Authority A', v_auth_a, true, false, false, NULL, NULL, NULL),
        (v_stage_plain_b, v_policy, 2, 'PLAIN_B', 1, true, false,
            'Authority B', v_auth_b, true, false, false, NULL, NULL, NULL),
        (v_stage_delegated_disallowed_a, v_policy, 3,
            'DELEGATED_DISALLOWED_A', 1, true, false, 'Authority A',
            v_auth_a, true, false, false, NULL, NULL, NULL),
        (v_stage_delegated_allowed_a, v_policy, 4,
            'DELEGATED_ALLOWED_A', 1, true, false, 'Authority A',
            v_auth_a, true, false, true, 2, NULL, NULL),
        (v_stage_delegated_depth1_a, v_policy, 5,
            'DELEGATED_DEPTH1_A', 1, true, false, 'Authority A',
            v_auth_a, true, false, true, 1, NULL, NULL),
        (v_stage_joint_a, v_policy, 6, 'JOINT_A', 1, true, false,
            'Authority A', v_auth_a, true, false, false, NULL,
            v_set_joint, 'JOINT_EXERCISE'),
        (v_stage_joint_b, v_policy, 7, 'JOINT_B', 1, true, false,
            'Authority B', v_auth_b, true, false, false, NULL,
            v_set_joint, 'JOINT_EXERCISE'),
        (v_stage_concurrent_include_a, v_policy, 8,
            'CONCURRENT_INCLUDE_A', 1, true, false, 'Authority A',
            v_auth_a, true, false, false, NULL,
            v_set_concurrent_include, 'CONCURRENT_HOLDING'),
        (v_stage_concurrent_exclude_a, v_policy, 9,
            'CONCURRENT_EXCLUDE_A', 1, true, false, 'Authority A',
            v_auth_a, true, false, false, NULL,
            v_set_concurrent_exclude, 'CONCURRENT_HOLDING'),
        (v_stage_chain_a, v_policy, 10, 'CHAIN_A', 1, true, false,
            'Authority A', v_auth_a, true, false, false, NULL,
            v_set_chain, 'CHAIN_PARTICIPATION'),
        (v_stage_chain_b, v_policy, 11, 'CHAIN_B', 1, true, false,
            'Authority B', v_auth_b, true, false, false, NULL,
            v_set_chain, 'CHAIN_PARTICIPATION'),
        (v_stage_inactive_a, v_policy, 12, 'INACTIVE_A', 1, true, false,
            'Authority A', v_auth_a, true, false, false, NULL,
            v_set_inactive, 'JOINT_EXERCISE'),
        (v_stage_bad_member_a, v_policy, 13, 'BAD_MEMBER_A', 1, true, false,
            'Authority A', v_auth_a, true, false, false, NULL,
            v_set_bad_member, 'JOINT_EXERCISE'),
        (v_stage_duty_a, v_policy, 14, 'DUTY_A', 1, true, false,
            'Authority A', v_auth_a, true, false, false, NULL, NULL, NULL),
        (v_stage_duty_b, v_policy, 15, 'DUTY_B', 1, true, false,
            'Authority B', v_auth_b, true, false, false, NULL, NULL, NULL);

    v_session_a := sql_test.create_phase4_step5_session(
        v_identity_a, v_org1, v_service_id, 'identity-a'
    );
    v_session_b := sql_test.create_phase4_step5_session(
        v_identity_b, v_org1, v_service_id, 'identity-b'
    );
    v_session_c := sql_test.create_phase4_step5_session(
        v_identity_c, v_org1, v_service_id, 'identity-c'
    );

    INSERT INTO pg_temp.step5_ids (fixture_key, fixture_id)
    VALUES
        ('session_a', v_session_a),
        ('session_b', v_session_b),
        ('session_c', v_session_c);

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
    SELECT
        request_id,
        v_policy,
        requester_id,
        v_org1,
        CASE WHEN requester_id = v_identity_a
             THEN v_session_a ELSE v_session_c END,
        v_service_id,
        v_purpose_key,
        v_operation_key,
        'TEST_RESOURCE',
        target_reference,
        v_scope_id,
        'TEST',
        'PENDING',
        v_now,
        v_now + interval '1 hour',
        gen_random_uuid(),
        v_purpose_id,
        v_operation_id,
        NULL,
        chain_id
    FROM (
        VALUES
            (v_request_plain, v_identity_c, 'step5-plain', gen_random_uuid()),
            (v_request_delegated_disallowed, v_identity_c,
                'step5-delegated-disallowed', gen_random_uuid()),
            (v_request_delegated_allowed, v_identity_c,
                'step5-delegated-allowed', gen_random_uuid()),
            (v_request_delegated_depth, v_identity_c,
                'step5-delegated-depth', gen_random_uuid()),
            (v_request_delegated_invalid, v_identity_c,
                'step5-delegated-invalid', gen_random_uuid()),
            (v_request_joint, v_identity_c, 'step5-joint', gen_random_uuid()),
            (v_request_concurrent_include, v_identity_c,
                'step5-concurrent-include', gen_random_uuid()),
            (v_request_concurrent_exclude, v_identity_c,
                'step5-concurrent-exclude', gen_random_uuid()),
            (v_request_concurrent_context, v_identity_c,
                'step5-concurrent-context', gen_random_uuid()),
            (v_request_concurrent_suspended, v_identity_c,
                'step5-concurrent-suspended', gen_random_uuid()),
            (v_request_chain_a, v_identity_c, 'step5-chain-a', v_shared_chain),
            (v_request_chain_b, v_identity_c, 'step5-chain-b', v_shared_chain),
            (v_request_unlinked, v_identity_c, 'step5-unlinked', gen_random_uuid()),
            (v_request_inactive, v_identity_c, 'step5-inactive', gen_random_uuid()),
            (v_request_bad_member, v_identity_c, 'step5-bad-member', gen_random_uuid()),
            (v_request_duty_request, v_identity_a,
                'step5-duty-request', gen_random_uuid()),
            (v_request_duty_grant, v_identity_c,
                'step5-duty-grant', gen_random_uuid()),
            (v_request_duty_execute, v_identity_c,
                'step5-duty-execute', gen_random_uuid()),
            (v_request_duty_authchain, v_identity_c,
                'step5-duty-authchain', gen_random_uuid())
    ) AS requests(request_id, requester_id, target_reference, chain_id);

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
        (v_grant_a_direct_a, v_identity_a, v_auth_a, v_purpose_id,
            v_operation_id, v_service_id, v_org1, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_d, NULL, NULL, 0),
        (v_grant_a_direct_b, v_identity_a, v_auth_b, v_purpose_id,
            v_operation_id, v_service_id, v_org1, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_d, NULL, NULL, 0),
        (v_grant_a_context_b, v_identity_a, v_auth_b, v_purpose_id,
            v_operation_id, v_service_id, v_org2, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_d, NULL, NULL, 0),
        (v_grant_b_direct_a, v_identity_b, v_auth_a, v_purpose_id,
            v_operation_id, v_service_id, v_org1, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_d, NULL, NULL, 0),
        (v_grant_b_direct_b, v_identity_b, v_auth_b, v_purpose_id,
            v_operation_id, v_service_id, v_org1, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_d, NULL, NULL, 0),
        (v_grant_b_a_by_a, v_identity_b, v_auth_a, v_purpose_id,
            v_operation_id, v_service_id, v_org1, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_a, NULL, NULL, 0),
        (v_grant_c_direct_a, v_identity_c, v_auth_a, v_purpose_id,
            v_operation_id, v_service_id, v_org1, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_d, NULL, NULL, 0),
        (v_grant_c_direct_b, v_identity_c, v_auth_b, v_purpose_id,
            v_operation_id, v_service_id, v_org1, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_d, NULL, NULL, 0),
        (v_root_a, v_identity_d, v_auth_a, v_purpose_id, v_operation_id,
            v_service_id, v_org1, NULL, true, NULL, NULL, true, NULL,
            'ACTIVE', v_now - interval '1 day', v_now + interval '1 day',
            v_identity_c, NULL, NULL, 0),
        (v_parent_a, v_identity_b, v_auth_a, v_purpose_id, v_operation_id,
            v_service_id, v_org1, NULL, true, NULL, NULL, true, NULL,
            'ACTIVE', v_now - interval '1 day', v_now + interval '1 day',
            v_identity_d, NULL, v_root_a, 1),
        (v_grant_a_delegated_a, v_identity_a, v_auth_a, v_purpose_id,
            v_operation_id, v_service_id, v_org1, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_d, NULL, v_root_a, 1),
        (v_grant_a_depth2_a, v_identity_a, v_auth_a, v_purpose_id,
            v_operation_id, v_service_id, v_org1, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_b, NULL, v_parent_a, 2),
        (v_grant_a_invalid_a, v_identity_a, v_auth_a, v_purpose_id,
            v_operation_id, v_service_id, v_org1, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_c, NULL, v_root_a, 1),
        (v_root_b, v_identity_d, v_auth_b, v_purpose_id, v_operation_id,
            v_service_id, v_org1, NULL, true, NULL, NULL, true, NULL,
            'ACTIVE', v_now - interval '1 day', v_now + interval '1 day',
            v_identity_c, NULL, NULL, 0),
        (v_grant_a_delegated_b, v_identity_a, v_auth_b, v_purpose_id,
            v_operation_id, v_service_id, v_org1, NULL, true, NULL, NULL,
            true, NULL, 'ACTIVE', v_now - interval '1 day',
            v_now + interval '1 day', v_identity_d, NULL, v_root_b, 1);
END;
$setup$;

-- Structural contract: 10 assertions.
SELECT sql_test.assert_equal_bigint(
    'Authority Grants expose exact delegation parent and depth columns',
    (
        SELECT count(*)
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authority_grants'
          AND column_name IN (
              'delegated_from_authority_grant_id',
              'delegation_depth'
          )
    ),
    2
);

SELECT sql_test.assert_true(
    'Authority Grant delegation shape is constrained',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'access_control.authority_grants'::regclass
          AND conname = 'authority_grants_delegation_shape_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Authority Grant delegation cannot directly reference itself',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'access_control.authority_grants'::regclass
          AND conname = 'authority_grants_delegation_not_self_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Authority Grant delegation-lineage index is valid and ready',
    EXISTS (
        SELECT 1
        FROM pg_index AS index_record
        JOIN pg_class AS index_relation
          ON index_relation.oid = index_record.indexrelid
        WHERE index_record.indrelid =
              'access_control.authority_grants'::regclass
          AND index_relation.relname =
              'authority_grants_delegation_lineage_idx'
          AND index_record.indisvalid
          AND index_record.indisready
    )
);

SELECT sql_test.assert_true(
    'Current Authority Grant applicability helper exists',
    to_regprocedure(
        'approval.authority_grant_is_current_for_approval(uuid,uuid,uuid,timestamp with time zone)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'Approval duty-scope helper exists',
    to_regprocedure(
        'approval.approval_request_is_in_duty_scope(uuid,uuid,text)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'Step 5 conflict-enforcement helper exists',
    to_regprocedure(
        'approval.enforce_approval_action_conflicts(uuid,uuid,uuid,uuid,uuid,timestamp with time zone)'
    ) IS NOT NULL
);

SELECT sql_test.assert_no_rows(
    'PUBLIC cannot execute Step 5 conflict helpers',
    $$
    SELECT routine_schema, routine_name
    FROM information_schema.routine_privileges
    WHERE grantee = 'PUBLIC'
      AND routine_schema = 'approval'
      AND routine_name IN (
          'authority_grant_is_current_for_approval',
          'approval_request_is_in_duty_scope',
          'enforce_approval_action_conflicts'
      )
    $$
);

SELECT sql_test.assert_true(
    'Controlled Approval Action recording invokes Step 5 conflict enforcement',
    position(
        'enforce_approval_action_conflicts' IN
        pg_get_functiondef(
            'approval.record_approval_action(uuid,uuid,uuid,uuid,uuid,uuid,text,text,text,uuid)'::regprocedure
        )
    ) > 0
);

SELECT sql_test.assert_true(
    'Controlled APPROVE recording inserts an immutable APPROVE duty link',
    position(
        'INSERT INTO approval.approval_action_duties' IN
        pg_get_functiondef(
            'approval.record_approval_action(uuid,uuid,uuid,uuid,uuid,uuid,text,text,text,uuid)'::regprocedure
        )
    ) > 0
);

-- Baseline duty recording: assertions 11-15.
SELECT sql_test.phase4_step5_record(
    'plain_approve', 'request_plain', 'stage_plain_a',
    'identity_a', 'session_a', 'grant_a_direct_a'
);

SELECT sql_test.assert_true(
    'A valid direct approval still records successfully',
    EXISTS (
        SELECT 1
        FROM pg_temp.step5_actions
        WHERE fixture_key = 'plain_approve'
    )
);

SELECT sql_test.assert_equal_bigint(
    'A successful APPROVE action receives exactly one APPROVE duty',
    (
        SELECT count(*)
        FROM approval.approval_action_duties AS duty
        JOIN pg_temp.step5_actions AS action_fixture
          ON action_fixture.approval_action_id = duty.approval_action_id
        WHERE action_fixture.fixture_key = 'plain_approve'
          AND duty.duty_key = 'APPROVE'
    ),
    1
);

SELECT sql_test.phase4_step5_record(
    'plain_deny', 'request_plain', 'stage_plain_b',
    'identity_b', 'session_b', 'grant_b_direct_b',
    'DENY', 'Deny for duty-recording test', 'SQL_TEST_STEP5_DENIED'
);

SELECT sql_test.assert_true(
    'A valid non-APPROVE action still records successfully',
    EXISTS (
        SELECT 1
        FROM pg_temp.step5_actions
        WHERE fixture_key = 'plain_deny'
    )
);

SELECT sql_test.assert_equal_bigint(
    'A non-APPROVE action receives no APPROVE duty',
    (
        SELECT count(*)
        FROM approval.approval_action_duties AS duty
        JOIN pg_temp.step5_actions AS action_fixture
          ON action_fixture.approval_action_id = duty.approval_action_id
        WHERE action_fixture.fixture_key = 'plain_deny'
    ),
    0
);

SELECT sql_test.assert_raises(
    'APPROVE duty links reject UPDATE',
    format(
        'UPDATE approval.approval_action_duties SET recorded_at = clock_timestamp() WHERE approval_action_id = %L::uuid AND duty_key = %L',
        (
            SELECT approval_action_id::text
            FROM pg_temp.step5_actions
            WHERE fixture_key = 'plain_approve'
        ),
        'APPROVE'
    ),
    '55000'
);

-- Delegation lineage: assertions 16-23.
SELECT sql_test.assert_true(
    'A delegated grant is denied when the exact stage disallows delegation',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'delegated_disallowed_attempt',
            'request_delegated_disallowed',
            'stage_delegated_disallowed_a',
            'identity_a', 'session_a', 'grant_a_delegated_a'
        )
    ) = '28000:DELEGATED_AUTHORITY_NOT_ALLOWED'
);

SELECT sql_test.assert_equal_bigint(
    'Rejected disallowed delegation creates no Approval Action Record',
    (
        SELECT count(*)
        FROM approval.approval_actions
        WHERE approval_request_id =
              sql_test.phase4_step5_id('request_delegated_disallowed')
    ),
    0
);

SELECT sql_test.phase4_step5_record(
    'delegated_allowed', 'request_delegated_allowed',
    'stage_delegated_allowed_a', 'identity_a', 'session_a',
    'grant_a_delegated_a'
);

SELECT sql_test.assert_true(
    'A current depth-one delegated grant is accepted when the stage permits it',
    EXISTS (
        SELECT 1 FROM pg_temp.step5_actions
        WHERE fixture_key = 'delegated_allowed'
    )
);

SELECT sql_test.assert_equal_bigint(
    'A successful delegated approval receives one APPROVE duty',
    (
        SELECT count(*)
        FROM approval.approval_action_duties AS duty
        JOIN pg_temp.step5_actions AS action_fixture
          ON action_fixture.approval_action_id = duty.approval_action_id
        WHERE action_fixture.fixture_key = 'delegated_allowed'
          AND duty.duty_key = 'APPROVE'
    ),
    1
);

SELECT sql_test.assert_true(
    'Delegation deeper than the stage maximum fails closed',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'delegated_depth_attempt', 'request_delegated_depth',
            'stage_delegated_depth1_a', 'identity_a', 'session_a',
            'grant_a_depth2_a'
        )
    ) = '28000:DELEGATION_DEPTH_EXCEEDED'
);

SELECT sql_test.assert_equal_bigint(
    'Rejected excessive delegation depth creates no Approval Action Record',
    (
        SELECT count(*) FROM approval.approval_actions
        WHERE approval_request_id =
              sql_test.phase4_step5_id('request_delegated_depth')
    ),
    0
);

SELECT sql_test.assert_true(
    'A delegated grant with mismatched parent-holder lineage fails closed',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'delegated_invalid_attempt', 'request_delegated_invalid',
            'stage_delegated_allowed_a', 'identity_a', 'session_a',
            'grant_a_invalid_a'
        )
    ) = '28000:DELEGATED_AUTHORITY_LINEAGE_INVALID'
);

SELECT sql_test.assert_equal_bigint(
    'Rejected invalid delegation lineage creates no Approval Action Record',
    (
        SELECT count(*) FROM approval.approval_actions
        WHERE approval_request_id =
              sql_test.phase4_step5_id('request_delegated_invalid')
    ),
    0
);

-- JOINT_EXERCISE: assertions 24-29.
SELECT sql_test.phase4_step5_record(
    'joint_a', 'request_joint', 'stage_joint_a',
    'identity_a', 'session_a', 'grant_a_direct_a'
);

SELECT sql_test.assert_true(
    'The first member authority may be exercised in a JOINT_EXERCISE request',
    EXISTS (
        SELECT 1 FROM pg_temp.step5_actions WHERE fixture_key = 'joint_a'
    )
);

SELECT sql_test.assert_true(
    'One effective actor cannot exercise a second member authority in the same request',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'joint_same_actor_attempt', 'request_joint', 'stage_joint_b',
            'identity_a', 'session_a', 'grant_a_direct_b'
        )
    ) = '28000:INCOMPATIBLE_AUTHORITY_JOINT_EXERCISE'
);

SELECT sql_test.assert_equal_bigint(
    'A rejected JOINT_EXERCISE attempt creates no second-actor record',
    (
        SELECT count(*)
        FROM approval.approval_actions
        WHERE approval_request_id = sql_test.phase4_step5_id('request_joint')
          AND effective_actor_identity_id = sql_test.phase4_step5_id('identity_a')
          AND action_type = 'APPROVE'
    ),
    1
);

SELECT sql_test.phase4_step5_record(
    'joint_b_other_actor', 'request_joint', 'stage_joint_b',
    'identity_b', 'session_b', 'grant_b_direct_b'
);

SELECT sql_test.assert_true(
    'A different effective actor may exercise the second member authority',
    EXISTS (
        SELECT 1 FROM pg_temp.step5_actions
        WHERE fixture_key = 'joint_b_other_actor'
    )
);

SELECT sql_test.phase4_step5_record(
    'joint_a_withdraw', 'request_joint', 'stage_joint_a',
    'identity_a', 'session_a', 'grant_a_direct_a',
    'WITHDRAW_APPROVAL', 'Withdraw first joint authority action',
    'SQL_TEST_STEP5_WITHDRAWN', 'joint_a'
);

SELECT sql_test.assert_true(
    'Withdrawal creates typed lineage for the first joint action',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions AS withdrawal
        JOIN pg_temp.step5_actions AS action_fixture
          ON action_fixture.approval_action_id = withdrawal.approval_action_id
        WHERE action_fixture.fixture_key = 'joint_a_withdraw'
          AND withdrawal.action_type = 'WITHDRAW_APPROVAL'
          AND withdrawal.prior_approval_action_id = (
              SELECT approval_action_id FROM pg_temp.step5_actions
              WHERE fixture_key = 'joint_a'
          )
    )
);

SELECT sql_test.phase4_step5_record(
    'joint_replacement', 'request_joint', 'stage_joint_b',
    'identity_a', 'session_a', 'grant_a_direct_b'
);

SELECT sql_test.assert_true(
    'A withdrawn member-authority action no longer creates a JOINT_EXERCISE conflict',
    EXISTS (
        SELECT 1 FROM pg_temp.step5_actions
        WHERE fixture_key = 'joint_replacement'
    )
);

-- CONCURRENT_HOLDING: assertions 30-34.
UPDATE access_control.authority_grants
SET status = 'SUSPENDED'
WHERE authority_grant_id = sql_test.phase4_step5_id('grant_a_direct_b');

SELECT sql_test.assert_true(
    'CONCURRENT_HOLDING counts an applicable delegated member grant when configured',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'concurrent_include_attempt', 'request_concurrent_include',
            'stage_concurrent_include_a', 'identity_a', 'session_a',
            'grant_a_direct_a'
        )
    ) = '28000:INCOMPATIBLE_AUTHORITY_CONCURRENT_HOLDING'
);

SELECT sql_test.assert_equal_bigint(
    'Rejected concurrent holding creates no Approval Action Record',
    (
        SELECT count(*) FROM approval.approval_actions
        WHERE approval_request_id =
              sql_test.phase4_step5_id('request_concurrent_include')
    ),
    0
);

SELECT sql_test.phase4_step5_record(
    'concurrent_exclude_success', 'request_concurrent_exclude',
    'stage_concurrent_exclude_a', 'identity_a', 'session_a',
    'grant_a_direct_a'
);

SELECT sql_test.assert_true(
    'CONCURRENT_HOLDING can exclude delegated grants by exact set policy',
    EXISTS (
        SELECT 1 FROM pg_temp.step5_actions
        WHERE fixture_key = 'concurrent_exclude_success'
    )
);

UPDATE access_control.authority_grants
SET status = 'SUSPENDED'
WHERE authority_grant_id =
      sql_test.phase4_step5_id('grant_a_delegated_b');

SELECT sql_test.phase4_step5_record(
    'concurrent_context_success', 'request_concurrent_context',
    'stage_concurrent_include_a', 'identity_a', 'session_a',
    'grant_a_direct_a'
);

SELECT sql_test.assert_true(
    'An out-of-organization member grant is not accumulated as concurrent holding',
    EXISTS (
        SELECT 1 FROM pg_temp.step5_actions
        WHERE fixture_key = 'concurrent_context_success'
    )
);

UPDATE access_control.authority_grants
SET status = 'SUSPENDED'
WHERE authority_grant_id = sql_test.phase4_step5_id('grant_a_context_b');

SELECT sql_test.phase4_step5_record(
    'concurrent_suspended_success', 'request_concurrent_suspended',
    'stage_concurrent_include_a', 'identity_a', 'session_a',
    'grant_a_direct_a'
);

SELECT sql_test.assert_true(
    'Suspended member grants do not create concurrent holding',
    EXISTS (
        SELECT 1 FROM pg_temp.step5_actions
        WHERE fixture_key = 'concurrent_suspended_success'
    )
);

-- CHAIN_PARTICIPATION: assertions 35-40.
UPDATE access_control.authority_grants
SET status = 'ACTIVE'
WHERE authority_grant_id = sql_test.phase4_step5_id('grant_a_direct_b');

SELECT sql_test.phase4_step5_record(
    'chain_a', 'request_chain_a', 'stage_chain_a',
    'identity_a', 'session_a', 'grant_a_direct_a'
);

SELECT sql_test.assert_true(
    'The first member authority may participate in an explicit approval chain',
    EXISTS (
        SELECT 1 FROM pg_temp.step5_actions WHERE fixture_key = 'chain_a'
    )
);

SELECT sql_test.assert_true(
    'The same effective actor cannot use another member authority in the same approval chain',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'chain_conflict_attempt', 'request_chain_b', 'stage_chain_b',
            'identity_a', 'session_a', 'grant_a_direct_b'
        )
    ) = '28000:INCOMPATIBLE_AUTHORITY_CHAIN_PARTICIPATION'
);

SELECT sql_test.assert_equal_bigint(
    'Rejected chain participation creates no Approval Action Record in the second request',
    (
        SELECT count(*) FROM approval.approval_actions
        WHERE approval_request_id = sql_test.phase4_step5_id('request_chain_b')
    ),
    0
);

SELECT sql_test.phase4_step5_record(
    'unlinked_b', 'request_unlinked', 'stage_chain_b',
    'identity_a', 'session_a', 'grant_a_direct_b'
);

SELECT sql_test.assert_true(
    'No chain conflict is inferred for an unlinked request',
    EXISTS (
        SELECT 1 FROM pg_temp.step5_actions WHERE fixture_key = 'unlinked_b'
    )
);

SELECT sql_test.phase4_step5_record(
    'chain_a_withdraw', 'request_chain_a', 'stage_chain_a',
    'identity_a', 'session_a', 'grant_a_direct_a',
    'WITHDRAW_APPROVAL', 'Withdraw chain participation',
    'SQL_TEST_STEP5_CHAIN_WITHDRAWN', 'chain_a'
);

SELECT sql_test.assert_true(
    'Withdrawal makes the earlier chain participation non-current',
    EXISTS (
        SELECT 1 FROM pg_temp.step5_actions
        WHERE fixture_key = 'chain_a_withdraw'
    )
);

SELECT sql_test.phase4_step5_record(
    'chain_replacement', 'request_chain_b', 'stage_chain_b',
    'identity_a', 'session_a', 'grant_a_direct_b'
);

SELECT sql_test.assert_true(
    'A withdrawn chain action no longer blocks later member-authority participation',
    EXISTS (
        SELECT 1 FROM pg_temp.step5_actions
        WHERE fixture_key = 'chain_replacement'
    )
);

-- Set validity and membership: assertions 41-42.
SELECT sql_test.assert_true(
    'An inactive incompatible Authority Set fails closed',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'inactive_set_attempt', 'request_inactive', 'stage_inactive_a',
            'identity_a', 'session_a', 'grant_a_direct_a'
        )
    ) = '28000:INCOMPATIBLE_AUTHORITY_SET_NOT_ACTIVE'
);

SELECT sql_test.assert_true(
    'A stage whose required authority is not in its configured set fails closed',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'bad_member_attempt', 'request_bad_member', 'stage_bad_member_a',
            'identity_a', 'session_a', 'grant_a_direct_a'
        )
    ) = '28000:INCOMPATIBLE_AUTHORITY_POLICY_INVALID'
);

-- Prohibited duty combinations and final invariants: assertions 43-50.
INSERT INTO approval.approval_policy_prohibited_duty_combinations (
    approval_policy_id,
    first_duty_key,
    second_duty_key,
    enforcement_scope,
    status
)
VALUES (
    sql_test.phase4_step5_id('policy'),
    'APPROVE',
    'REQUEST',
    'REQUEST',
    'ACTIVE'
);

SELECT sql_test.assert_true(
    'REQUEST plus APPROVE is denied when prohibited for the request',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'duty_request_attempt', 'request_duty_request', 'stage_duty_a',
            'identity_a', 'session_a', 'grant_a_direct_a'
        )
    ) = '28000:PROHIBITED_DUTY_COMBINATION'
);

UPDATE approval.approval_policy_prohibited_duty_combinations
SET status = 'SUSPENDED'
WHERE approval_policy_id = sql_test.phase4_step5_id('policy')
  AND first_duty_key = 'APPROVE'
  AND second_duty_key = 'REQUEST'
  AND enforcement_scope = 'REQUEST';

INSERT INTO approval.approval_policy_prohibited_duty_combinations (
    approval_policy_id,
    first_duty_key,
    second_duty_key,
    enforcement_scope,
    status
)
VALUES (
    sql_test.phase4_step5_id('policy'),
    'APPROVE',
    'GRANT_AUTHORITY',
    'REQUEST',
    'ACTIVE'
);

SELECT sql_test.phase4_step5_record(
    'duty_grant_prior', 'request_duty_grant', 'stage_duty_a',
    'identity_b', 'session_b', 'grant_b_a_by_a'
);

SELECT sql_test.assert_true(
    'GRANT_AUTHORITY plus APPROVE is denied from exact grant attribution',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'duty_grant_attempt', 'request_duty_grant', 'stage_duty_b',
            'identity_a', 'session_a', 'grant_a_direct_b'
        )
    ) = '28000:PROHIBITED_DUTY_COMBINATION'
);

UPDATE approval.approval_policy_prohibited_duty_combinations
SET status = 'SUSPENDED'
WHERE approval_policy_id = sql_test.phase4_step5_id('policy')
  AND first_duty_key = 'APPROVE'
  AND second_duty_key = 'GRANT_AUTHORITY'
  AND enforcement_scope = 'REQUEST';

INSERT INTO approval.approval_policy_prohibited_duty_combinations (
    approval_policy_id,
    first_duty_key,
    second_duty_key,
    enforcement_scope,
    status
)
VALUES (
    sql_test.phase4_step5_id('policy'),
    'APPROVE',
    'EXECUTE',
    'REQUEST',
    'ACTIVE'
);

WITH inserted_action AS (
    INSERT INTO approval.approval_actions (
        approval_action_id,
        approval_request_id,
        approval_policy_stage_id,
        acting_identity_id,
        acting_organization_id,
        action_type,
        action_reason,
        action_at,
        acting_session_id,
        authority_grant_id,
        prior_approval_action_id,
        action_reason_code
    )
    VALUES (
        gen_random_uuid(),
        sql_test.phase4_step5_id('request_duty_execute'),
        sql_test.phase4_step5_id('stage_duty_a'),
        sql_test.phase4_step5_id('identity_a'),
        sql_test.phase4_step5_id('org1'),
        'ABSTAIN',
        NULL,
        statement_timestamp(),
        sql_test.phase4_step5_id('session_a'),
        sql_test.phase4_step5_id('grant_a_direct_a'),
        NULL,
        'SQL_TEST_EXECUTE_DUTY_SEED'
    )
    RETURNING approval_action_id
)
INSERT INTO approval.approval_action_duties (
    approval_action_id,
    duty_key,
    recorded_at
)
SELECT approval_action_id, 'EXECUTE', statement_timestamp()
FROM inserted_action;

SELECT sql_test.assert_true(
    'A recorded EXECUTE duty conflicts with APPROVE under the exact policy',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'duty_execute_attempt', 'request_duty_execute', 'stage_duty_b',
            'identity_a', 'session_a', 'grant_a_direct_b'
        )
    ) = '28000:PROHIBITED_DUTY_COMBINATION'
);

UPDATE approval.approval_policy_prohibited_duty_combinations
SET status = 'SUSPENDED'
WHERE approval_policy_id = sql_test.phase4_step5_id('policy')
  AND first_duty_key = 'APPROVE'
  AND second_duty_key = 'EXECUTE'
  AND enforcement_scope = 'REQUEST';

INSERT INTO approval.approval_policy_prohibited_duty_combinations (
    approval_policy_id,
    first_duty_key,
    second_duty_key,
    enforcement_scope,
    status
)
VALUES (
    sql_test.phase4_step5_id('policy'),
    'APPROVE',
    'AUDIT',
    'AUTHORIZATION_CHAIN',
    'ACTIVE'
);

SELECT sql_test.assert_true(
    'Unavailable AUTHORIZATION_CHAIN duty scope fails closed',
    sql_test.phase4_step5_error(
        sql_test.phase4_step5_call_sql(
            'duty_authchain_attempt', 'request_duty_authchain', 'stage_duty_a',
            'identity_b', 'session_b', 'grant_b_direct_a'
        )
    ) = '28000:DUTY_SCOPE_NOT_EVALUATED'
);

SELECT sql_test.assert_no_rows(
    'Rejected Step 5 attempts leave no successful action or duty record',
    $$
    SELECT request_record.approval_request_id
    FROM approval.approval_requests AS request_record
    WHERE request_record.approval_request_id IN (
        sql_test.phase4_step5_id('request_delegated_disallowed'),
        sql_test.phase4_step5_id('request_delegated_depth'),
        sql_test.phase4_step5_id('request_delegated_invalid'),
        sql_test.phase4_step5_id('request_concurrent_include'),
        sql_test.phase4_step5_id('request_inactive'),
        sql_test.phase4_step5_id('request_bad_member'),
        sql_test.phase4_step5_id('request_duty_request'),
        sql_test.phase4_step5_id('request_duty_authchain')
    )
      AND EXISTS (
          SELECT 1
          FROM approval.approval_actions AS action_record
          WHERE action_record.approval_request_id =
                request_record.approval_request_id
      )
    $$
);

SELECT sql_test.assert_no_rows(
    'Every active core incompatible Authority Set has exactly two distinct members',
    $$
    SELECT authority_set.incompatible_authority_set_id
    FROM access_control.incompatible_authority_sets AS authority_set
    LEFT JOIN access_control.incompatible_authority_members AS member
      ON member.incompatible_authority_set_id =
         authority_set.incompatible_authority_set_id
    WHERE authority_set.incompatible_authority_set_id IN (
        sql_test.phase4_step5_id('set_joint'),
        sql_test.phase4_step5_id('set_concurrent_include'),
        sql_test.phase4_step5_id('set_concurrent_exclude'),
        sql_test.phase4_step5_id('set_chain')
    )
      AND authority_set.status = 'ACTIVE'
    GROUP BY authority_set.incompatible_authority_set_id
    HAVING count(DISTINCT member.authority_definition_id) <> 2
    $$
);

SELECT sql_test.assert_no_rows(
    'Controlled non-APPROVE actions receive no automatic duty links',
    $$
    SELECT action_record.approval_action_id
    FROM approval.approval_actions AS action_record
    JOIN pg_temp.step5_actions AS action_fixture
      ON action_fixture.approval_action_id = action_record.approval_action_id
    WHERE action_record.action_type <> 'APPROVE'
      AND EXISTS (
          SELECT 1
          FROM approval.approval_action_duties AS duty
          WHERE duty.approval_action_id = action_record.approval_action_id
      )
    $$
);

SELECT sql_test.assert_no_rows(
    'Every controlled Step 5 APPROVE action has exactly one APPROVE duty',
    $$
    SELECT action_record.approval_action_id
    FROM approval.approval_actions AS action_record
    JOIN pg_temp.step5_actions AS action_fixture
      ON action_fixture.approval_action_id = action_record.approval_action_id
    WHERE action_record.action_type = 'APPROVE'
      AND 1 <> (
          SELECT count(*)
          FROM approval.approval_action_duties AS duty
          WHERE duty.approval_action_id = action_record.approval_action_id
            AND duty.duty_key = 'APPROVE'
      )
    $$
);
