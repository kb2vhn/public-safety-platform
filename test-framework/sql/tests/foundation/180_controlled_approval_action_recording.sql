-- ============================================================================
-- Phase 4 Step 3 controlled Approval Action recording
-- ============================================================================
--
-- Purpose:
-- Prove the controlled Approval Action write boundary, exact actor/session/
-- organization/Authority Grant binding, request and stage context validation,
-- typed action lineage, and append-only mutation guards.
--
-- Self-approval, directly affected identity, duplicate effective actor,
-- incompatible-authority, separation-of-duties, stage-satisfaction, and
-- Approval Request finalization behavior remain later Phase 4 steps.
-- ============================================================================

SELECT sql_test.begin_file(
    '180_controlled_approval_action_recording.sql'
);

CREATE TEMP TABLE step3_context (
    provider_id uuid NOT NULL,
    device_id uuid NOT NULL,
    requester_identity_id uuid NOT NULL,
    actor_identity_id uuid NOT NULL,
    alternate_actor_identity_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    alternate_organization_id uuid NOT NULL,
    service_id uuid NOT NULL,
    alternate_service_id uuid NOT NULL,
    purpose_definition_id uuid NOT NULL,
    alternate_purpose_definition_id uuid NOT NULL,
    operation_definition_id uuid NOT NULL,
    alternate_operation_definition_id uuid NOT NULL,
    operation_key text NOT NULL,
    alternate_operation_key text NOT NULL,
    governed_scope_id uuid NOT NULL,
    alternate_governed_scope_id uuid NOT NULL,
    authority_definition_id uuid NOT NULL,
    alternate_authority_definition_id uuid NOT NULL,
    approval_policy_id uuid NOT NULL,
    approval_policy_stage_id uuid NOT NULL,
    alternate_approval_policy_stage_id uuid NOT NULL,
    approval_request_id uuid NOT NULL,
    alternate_approval_request_id uuid NOT NULL,
    nonpending_approval_request_id uuid NOT NULL,
    expired_approval_request_id uuid NOT NULL,
    finalized_approval_request_id uuid NOT NULL,
    actor_session_id uuid NOT NULL,
    alternate_actor_session_id uuid NOT NULL,
    alternate_organization_session_id uuid NOT NULL,
    alternate_service_session_id uuid NOT NULL,
    authority_grant_id uuid NOT NULL,
    alternate_actor_authority_grant_id uuid NOT NULL,
    alternate_authority_grant_id uuid NOT NULL,
    inactive_authority_grant_id uuid NOT NULL,
    alternate_service_grant_id uuid NOT NULL,
    alternate_purpose_grant_id uuid NOT NULL,
    alternate_operation_grant_id uuid NOT NULL,
    alternate_organization_grant_id uuid NOT NULL,
    alternate_scope_grant_id uuid NOT NULL,
    alternate_target_grant_id uuid NOT NULL,
    legacy_scope_reference_grant_id uuid NOT NULL
) ON COMMIT PRESERVE ROWS;

CREATE TEMP TABLE step3_success_actions (
    fixture_key text PRIMARY KEY,
    approval_action_id uuid NOT NULL UNIQUE,
    outcome text NOT NULL,
    reason_code text NOT NULL,
    recorded_at timestamptz NOT NULL,
    invoked_before timestamptz NOT NULL,
    invoked_after timestamptz NOT NULL
) ON COMMIT PRESERVE ROWS;

CREATE FUNCTION sql_test.create_phase4_step3_session(
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
    v_provider_id uuid;
    v_device_id uuid;
    v_assertion_id uuid := gen_random_uuid();
    v_external_id text :=
        'sql-test-phase4-step3-' || p_fixture_key || '-' ||
        gen_random_uuid()::text;
BEGIN
    SELECT provider_id, device_id
    INTO STRICT v_provider_id, v_device_id
    FROM pg_temp.step3_context;

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
        'phase4-step3-session',
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
        decode(repeat('65', 32), 'hex'),
        v_now - interval '30 seconds'
    );

    PERFORM access_control.mark_authentication_assertion_verified(
        v_assertion_id,
        'sql_test.phase4_step3_verifier',
        'sql_test.phase4_step3.v1'
    );

    RETURN access_control.establish_session_from_authentication_assertion(
        v_external_id,
        p_organization_id,
        interval '1 hour',
        interval '30 minutes',
        'phase4-step3-session',
        'test',
        gen_random_uuid()
    );
END;
$function$;

CREATE FUNCTION sql_test.phase4_step3_action_sql(
    p_approval_request_id uuid,
    p_approval_policy_stage_id uuid,
    p_acting_identity_id uuid,
    p_acting_organization_id uuid,
    p_acting_session_id uuid,
    p_authority_grant_id uuid,
    p_action_type text,
    p_action_reason text,
    p_action_reason_code text,
    p_prior_approval_action_id uuid DEFAULT NULL
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, sql_test
AS $function$
    SELECT format(
        'SELECT * FROM approval.record_approval_action('
        '%L::uuid,%L::uuid,%L::uuid,%L::uuid,%L::uuid,%L::uuid,'
        '%L,%L,%L,%L::uuid)',
        p_approval_request_id::text,
        p_approval_policy_stage_id::text,
        p_acting_identity_id::text,
        p_acting_organization_id::text,
        p_acting_session_id::text,
        p_authority_grant_id::text,
        p_action_type,
        p_action_reason,
        p_action_reason_code,
        p_prior_approval_action_id::text
    );
$function$;

DO $setup$
DECLARE
    v_now timestamptz := statement_timestamp();
    v_suffix text := replace(gen_random_uuid()::text, '-', '');
    v_provider_id uuid := gen_random_uuid();
    v_device_id uuid := gen_random_uuid();
    v_requester_person_id uuid := gen_random_uuid();
    v_requester_identity_id uuid := gen_random_uuid();
    v_actor_person_id uuid := gen_random_uuid();
    v_actor_identity_id uuid := gen_random_uuid();
    v_alternate_person_id uuid := gen_random_uuid();
    v_alternate_actor_identity_id uuid := gen_random_uuid();
    v_organization_id uuid := gen_random_uuid();
    v_alternate_organization_id uuid := gen_random_uuid();
    v_service_id uuid := gen_random_uuid();
    v_alternate_service_id uuid := gen_random_uuid();
    v_purpose_id uuid := gen_random_uuid();
    v_alternate_purpose_id uuid := gen_random_uuid();
    v_operation_id uuid := gen_random_uuid();
    v_alternate_operation_id uuid := gen_random_uuid();
    v_operation_key text :=
        'sql_test.phase4_step3_operation_' || v_suffix;
    v_alternate_operation_key text :=
        'sql_test.phase4_step3_alt_operation_' || v_suffix;
    v_scope_id uuid := gen_random_uuid();
    v_alternate_scope_id uuid := gen_random_uuid();
    v_authority_id uuid := gen_random_uuid();
    v_alternate_authority_id uuid := gen_random_uuid();
    v_policy_id uuid := gen_random_uuid();
    v_stage_id uuid := gen_random_uuid();
    v_alternate_stage_id uuid := gen_random_uuid();
    v_request_id uuid := gen_random_uuid();
    v_alternate_request_id uuid := gen_random_uuid();
    v_nonpending_request_id uuid := gen_random_uuid();
    v_expired_request_id uuid := gen_random_uuid();
    v_finalized_request_id uuid := gen_random_uuid();
    v_actor_session_id uuid;
    v_alternate_actor_session_id uuid;
    v_alternate_organization_session_id uuid;
    v_alternate_service_session_id uuid;
    v_authority_grant_id uuid := gen_random_uuid();
    v_alternate_actor_grant_id uuid := gen_random_uuid();
    v_alternate_authority_grant_id uuid := gen_random_uuid();
    v_inactive_grant_id uuid := gen_random_uuid();
    v_alternate_service_grant_id uuid := gen_random_uuid();
    v_alternate_purpose_grant_id uuid := gen_random_uuid();
    v_alternate_operation_grant_id uuid := gen_random_uuid();
    v_alternate_organization_grant_id uuid := gen_random_uuid();
    v_alternate_scope_grant_id uuid := gen_random_uuid();
    v_alternate_target_grant_id uuid := gen_random_uuid();
    v_legacy_scope_grant_id uuid := gen_random_uuid();
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
        'sql_test.phase4_step3_provider_' || v_suffix,
        'SQL Test Phase 4 Step 3 Provider',
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
        'sql_test.phase4_step3_device_' || v_suffix,
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
    VALUES
        (
            v_requester_person_id,
            'sql_test.phase4_step3_requester_' || v_suffix,
            'SQL Test Phase 4 Step 3 Requester',
            'ACTIVE',
            'sql_test'
        ),
        (
            v_actor_person_id,
            'sql_test.phase4_step3_actor_' || v_suffix,
            'SQL Test Phase 4 Step 3 Actor',
            'ACTIVE',
            'sql_test'
        ),
        (
            v_alternate_person_id,
            'sql_test.phase4_step3_alt_actor_' || v_suffix,
            'SQL Test Phase 4 Step 3 Alternate Actor',
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
            v_requester_identity_id,
            'sql_test.phase4_step3_requester_identity_' || v_suffix,
            'HUMAN',
            v_requester_person_id,
            'ACTIVE',
            'TEST',
            v_now - interval '1 day',
            v_now + interval '1 day',
            'sql_test'
        ),
        (
            v_actor_identity_id,
            'sql_test.phase4_step3_actor_identity_' || v_suffix,
            'HUMAN',
            v_actor_person_id,
            'ACTIVE',
            'TEST',
            v_now - interval '1 day',
            v_now + interval '1 day',
            'sql_test'
        ),
        (
            v_alternate_actor_identity_id,
            'sql_test.phase4_step3_alt_actor_identity_' || v_suffix,
            'HUMAN',
            v_alternate_person_id,
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
    VALUES
        (
            v_organization_id,
            'sql_test.phase4_step3_org_' || v_suffix,
            'SQL Test Phase 4 Step 3 Organization',
            'SQL Test Phase 4 Step 3 Organization',
            'TEST_ORGANIZATION',
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            'sql_test'
        ),
        (
            v_alternate_organization_id,
            'sql_test.phase4_step3_alt_org_' || v_suffix,
            'SQL Test Phase 4 Step 3 Alternate Organization',
            'SQL Test Phase 4 Step 3 Alternate Organization',
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
    VALUES
        (
            v_service_id,
            'sql_test.phase4_step3_service_' || v_suffix,
            'SQL Test Phase 4 Step 3 Service',
            'TEST_SERVICE',
            v_organization_id,
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            'sql_test'
        ),
        (
            v_alternate_service_id,
            'sql_test.phase4_step3_alt_service_' || v_suffix,
            'SQL Test Phase 4 Step 3 Alternate Service',
            'TEST_SERVICE',
            v_organization_id,
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            'sql_test'
        );

    INSERT INTO access_control.purpose_definitions (
        purpose_definition_id,
        purpose_key,
        title,
        description,
        status
    )
    VALUES
        (
            v_purpose_id,
            'sql_test.phase4_step3_purpose_' || v_suffix,
            'SQL Test Phase 4 Step 3 Purpose',
            'SQL Test Phase 4 Step 3 Purpose',
            'ACTIVE'
        ),
        (
            v_alternate_purpose_id,
            'sql_test.phase4_step3_alt_purpose_' || v_suffix,
            'SQL Test Phase 4 Step 3 Alternate Purpose',
            'SQL Test Phase 4 Step 3 Alternate Purpose',
            'ACTIVE'
        );

    INSERT INTO access_control.operation_definitions (
        operation_definition_id,
        operation_key,
        title,
        description,
        status
    )
    VALUES
        (
            v_operation_id,
            v_operation_key,
            'SQL Test Phase 4 Step 3 Operation',
            'SQL Test Phase 4 Step 3 Operation',
            'ACTIVE'
        ),
        (
            v_alternate_operation_id,
            v_alternate_operation_key,
            'SQL Test Phase 4 Step 3 Alternate Operation',
            'SQL Test Phase 4 Step 3 Alternate Operation',
            'ACTIVE'
        );

    INSERT INTO organization.governed_scopes (
        governed_scope_id,
        governed_scope_key,
        display_name,
        governed_scope_type,
        status,
        valid_from,
        valid_until,
        created_by_reference
    )
    VALUES
        (
            v_scope_id,
            'sql_test.phase4_step3_scope_' || v_suffix,
            'SQL Test Phase 4 Step 3 Scope',
            'TEST_SCOPE',
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            'sql_test'
        ),
        (
            v_alternate_scope_id,
            'sql_test.phase4_step3_alt_scope_' || v_suffix,
            'SQL Test Phase 4 Step 3 Alternate Scope',
            'TEST_SCOPE',
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            'sql_test'
        );

    INSERT INTO access_control.authority_definitions (
        authority_definition_id,
        authority_key,
        title,
        description,
        status,
        delegation_allowed
    )
    VALUES
        (
            v_authority_id,
            'sql_test.phase4_step3_authority_' || v_suffix,
            'SQL Test Phase 4 Step 3 Authority',
            'SQL Test Phase 4 Step 3 Authority',
            'ACTIVE',
            false
        ),
        (
            v_alternate_authority_id,
            'sql_test.phase4_step3_alt_authority_' || v_suffix,
            'SQL Test Phase 4 Step 3 Alternate Authority',
            'SQL Test Phase 4 Step 3 Alternate Authority',
            'ACTIVE',
            false
        );

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
        v_policy_id,
        'sql_test.phase4_step3_policy_' || v_suffix,
        1,
        'SQL Test Phase 4 Step 3 Policy',
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
        required_authority_definition_id
    )
    VALUES
        (
            v_stage_id,
            v_policy_id,
            1,
            'PRIMARY_REVIEW',
            1,
            true,
            false,
            'Typed Phase 4 Step 3 authority',
            v_authority_id
        ),
        (
            v_alternate_stage_id,
            v_policy_id,
            2,
            'SECONDARY_REVIEW',
            1,
            true,
            false,
            'Typed Phase 4 Step 3 authority',
            v_authority_id
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
        directly_affected_identity_id
    )
    VALUES
        (
            v_request_id,
            v_policy_id,
            v_requester_identity_id,
            v_organization_id,
            NULL,
            v_service_id,
            'sql_test.phase4_step3_purpose_' || v_suffix,
            v_operation_key,
            'TEST_RESOURCE',
            'primary-target',
            v_scope_id,
            'TEST',
            'PENDING',
            v_now - interval '1 minute',
            v_now + interval '1 hour',
            gen_random_uuid(),
            v_purpose_id,
            v_operation_id,
            v_requester_identity_id
        ),
        (
            v_alternate_request_id,
            v_policy_id,
            v_requester_identity_id,
            v_organization_id,
            NULL,
            v_service_id,
            'sql_test.phase4_step3_purpose_' || v_suffix,
            v_operation_key,
            'TEST_RESOURCE',
            'primary-target',
            v_scope_id,
            'TEST',
            'PENDING',
            v_now - interval '1 minute',
            v_now + interval '1 hour',
            gen_random_uuid(),
            v_purpose_id,
            v_operation_id,
            v_requester_identity_id
        ),
        (
            v_nonpending_request_id,
            v_policy_id,
            v_requester_identity_id,
            v_organization_id,
            NULL,
            v_service_id,
            'sql_test.phase4_step3_purpose_' || v_suffix,
            v_operation_key,
            'TEST_RESOURCE',
            'primary-target',
            v_scope_id,
            'TEST',
            'CANCELLED',
            v_now - interval '1 hour',
            v_now + interval '1 hour',
            gen_random_uuid(),
            v_purpose_id,
            v_operation_id,
            v_requester_identity_id
        ),
        (
            v_expired_request_id,
            v_policy_id,
            v_requester_identity_id,
            v_organization_id,
            NULL,
            v_service_id,
            'sql_test.phase4_step3_purpose_' || v_suffix,
            v_operation_key,
            'TEST_RESOURCE',
            'primary-target',
            v_scope_id,
            'TEST',
            'PENDING',
            v_now - interval '2 days',
            v_now - interval '1 day',
            gen_random_uuid(),
            v_purpose_id,
            v_operation_id,
            v_requester_identity_id
        ),
        (
            v_finalized_request_id,
            v_policy_id,
            v_requester_identity_id,
            v_organization_id,
            NULL,
            v_service_id,
            'sql_test.phase4_step3_purpose_' || v_suffix,
            v_operation_key,
            'TEST_RESOURCE',
            'primary-target',
            v_scope_id,
            'TEST',
            'APPROVED',
            v_now - interval '1 hour',
            v_now + interval '1 hour',
            gen_random_uuid(),
            v_purpose_id,
            v_operation_id,
            v_requester_identity_id
        );

    UPDATE approval.approval_requests
    SET
        finalized_at = v_now - interval '1 minute',
        finalized_by_identity_id = v_requester_identity_id,
        final_reason_code = 'TEST_FINALIZED'
    WHERE approval_request_id = v_finalized_request_id;

    INSERT INTO pg_temp.step3_context (
        provider_id,
        device_id,
        requester_identity_id,
        actor_identity_id,
        alternate_actor_identity_id,
        organization_id,
        alternate_organization_id,
        service_id,
        alternate_service_id,
        purpose_definition_id,
        alternate_purpose_definition_id,
        operation_definition_id,
        alternate_operation_definition_id,
        operation_key,
        alternate_operation_key,
        governed_scope_id,
        alternate_governed_scope_id,
        authority_definition_id,
        alternate_authority_definition_id,
        approval_policy_id,
        approval_policy_stage_id,
        alternate_approval_policy_stage_id,
        approval_request_id,
        alternate_approval_request_id,
        nonpending_approval_request_id,
        expired_approval_request_id,
        finalized_approval_request_id,
        actor_session_id,
        alternate_actor_session_id,
        alternate_organization_session_id,
        alternate_service_session_id,
        authority_grant_id,
        alternate_actor_authority_grant_id,
        alternate_authority_grant_id,
        inactive_authority_grant_id,
        alternate_service_grant_id,
        alternate_purpose_grant_id,
        alternate_operation_grant_id,
        alternate_organization_grant_id,
        alternate_scope_grant_id,
        alternate_target_grant_id,
        legacy_scope_reference_grant_id
    )
    VALUES (
        v_provider_id,
        v_device_id,
        v_requester_identity_id,
        v_actor_identity_id,
        v_alternate_actor_identity_id,
        v_organization_id,
        v_alternate_organization_id,
        v_service_id,
        v_alternate_service_id,
        v_purpose_id,
        v_alternate_purpose_id,
        v_operation_id,
        v_alternate_operation_id,
        v_operation_key,
        v_alternate_operation_key,
        v_scope_id,
        v_alternate_scope_id,
        v_authority_id,
        v_alternate_authority_id,
        v_policy_id,
        v_stage_id,
        v_alternate_stage_id,
        v_request_id,
        v_alternate_request_id,
        v_nonpending_request_id,
        v_expired_request_id,
        v_finalized_request_id,
        gen_random_uuid(),
        gen_random_uuid(),
        gen_random_uuid(),
        gen_random_uuid(),
        v_authority_grant_id,
        v_alternate_actor_grant_id,
        v_alternate_authority_grant_id,
        v_inactive_grant_id,
        v_alternate_service_grant_id,
        v_alternate_purpose_grant_id,
        v_alternate_operation_grant_id,
        v_alternate_organization_grant_id,
        v_alternate_scope_grant_id,
        v_alternate_target_grant_id,
        v_legacy_scope_grant_id
    );

    v_actor_session_id := sql_test.create_phase4_step3_session(
        v_actor_identity_id,
        v_organization_id,
        v_service_id,
        'actor'
    );

    v_alternate_actor_session_id :=
        sql_test.create_phase4_step3_session(
            v_alternate_actor_identity_id,
            v_organization_id,
            v_service_id,
            'alternate-actor'
        );

    v_alternate_organization_session_id :=
        sql_test.create_phase4_step3_session(
            v_actor_identity_id,
            v_alternate_organization_id,
            v_service_id,
            'alternate-organization'
        );

    v_alternate_service_session_id :=
        sql_test.create_phase4_step3_session(
            v_actor_identity_id,
            v_organization_id,
            v_alternate_service_id,
            'alternate-service'
        );

    UPDATE pg_temp.step3_context
    SET
        actor_session_id = v_actor_session_id,
        alternate_actor_session_id = v_alternate_actor_session_id,
        alternate_organization_session_id =
            v_alternate_organization_session_id,
        alternate_service_session_id = v_alternate_service_session_id;

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
        granted_by_identity_id
    )
    VALUES
        (
            v_authority_grant_id,
            v_actor_identity_id,
            v_authority_id,
            v_purpose_id,
            v_operation_id,
            v_service_id,
            v_organization_id,
            v_scope_id,
            false,
            'TEST_RESOURCE',
            'primary-target',
            false,
            NULL,
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            v_requester_identity_id
        ),
        (
            v_alternate_actor_grant_id,
            v_alternate_actor_identity_id,
            v_authority_id,
            v_purpose_id,
            v_operation_id,
            v_service_id,
            v_organization_id,
            v_scope_id,
            false,
            'TEST_RESOURCE',
            'primary-target',
            false,
            NULL,
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            v_requester_identity_id
        ),
        (
            v_alternate_authority_grant_id,
            v_actor_identity_id,
            v_alternate_authority_id,
            v_purpose_id,
            v_operation_id,
            v_service_id,
            v_organization_id,
            v_scope_id,
            false,
            'TEST_RESOURCE',
            'primary-target',
            false,
            NULL,
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            v_requester_identity_id
        ),
        (
            v_inactive_grant_id,
            v_actor_identity_id,
            v_authority_id,
            v_purpose_id,
            v_operation_id,
            v_service_id,
            v_organization_id,
            v_scope_id,
            false,
            'TEST_RESOURCE',
            'primary-target',
            false,
            NULL,
            'SUSPENDED',
            v_now - interval '1 day',
            v_now + interval '1 day',
            v_requester_identity_id
        ),
        (
            v_alternate_service_grant_id,
            v_actor_identity_id,
            v_authority_id,
            v_purpose_id,
            v_operation_id,
            v_alternate_service_id,
            v_organization_id,
            v_scope_id,
            false,
            'TEST_RESOURCE',
            'primary-target',
            false,
            NULL,
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            v_requester_identity_id
        ),
        (
            v_alternate_purpose_grant_id,
            v_actor_identity_id,
            v_authority_id,
            v_alternate_purpose_id,
            v_operation_id,
            v_service_id,
            v_organization_id,
            v_scope_id,
            false,
            'TEST_RESOURCE',
            'primary-target',
            false,
            NULL,
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            v_requester_identity_id
        ),
        (
            v_alternate_operation_grant_id,
            v_actor_identity_id,
            v_authority_id,
            v_purpose_id,
            v_alternate_operation_id,
            v_service_id,
            v_organization_id,
            v_scope_id,
            false,
            'TEST_RESOURCE',
            'primary-target',
            false,
            NULL,
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            v_requester_identity_id
        ),
        (
            v_alternate_organization_grant_id,
            v_actor_identity_id,
            v_authority_id,
            v_purpose_id,
            v_operation_id,
            v_service_id,
            v_alternate_organization_id,
            v_scope_id,
            false,
            'TEST_RESOURCE',
            'primary-target',
            false,
            NULL,
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            v_requester_identity_id
        ),
        (
            v_alternate_scope_grant_id,
            v_actor_identity_id,
            v_authority_id,
            v_purpose_id,
            v_operation_id,
            v_service_id,
            v_organization_id,
            v_alternate_scope_id,
            false,
            'TEST_RESOURCE',
            'primary-target',
            false,
            NULL,
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            v_requester_identity_id
        ),
        (
            v_alternate_target_grant_id,
            v_actor_identity_id,
            v_authority_id,
            v_purpose_id,
            v_operation_id,
            v_service_id,
            v_organization_id,
            v_scope_id,
            false,
            'TEST_RESOURCE',
            'alternate-target',
            false,
            NULL,
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            v_requester_identity_id
        ),
        (
            v_legacy_scope_grant_id,
            v_actor_identity_id,
            v_authority_id,
            v_purpose_id,
            v_operation_id,
            v_service_id,
            v_organization_id,
            NULL,
            false,
            'TEST_RESOURCE',
            'primary-target',
            false,
            'legacy-scope',
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            v_requester_identity_id
        );
END;
$setup$;

SELECT sql_test.assert_true(
    'Migration 083 controlled Approval Action boundary is registered',
    EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id =
            '083_postgresql_approval_independence_and_separation_of_duties'
    )
);

SELECT sql_test.assert_true(
    'Controlled Approval Action function exists',
    to_regprocedure(
        'approval.record_approval_action(uuid,uuid,uuid,uuid,uuid,uuid,text,text,text,uuid)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'Controlled Approval Action function returns typed result columns',
    (
        SELECT count(*) = 4
        FROM information_schema.parameters
        WHERE specific_schema = 'approval'
          AND specific_name LIKE 'record_approval_action_%'
          AND parameter_mode = 'OUT'
    )
);

SELECT sql_test.assert_false(
    'Controlled Approval Action function is not SECURITY DEFINER',
    (
        SELECT routine_record.prosecdef
        FROM pg_proc AS routine_record
        WHERE routine_record.oid =
            'approval.record_approval_action(uuid,uuid,uuid,uuid,uuid,uuid,text,text,text,uuid)'::regprocedure
    )
);

SELECT sql_test.assert_true(
    'Controlled Approval Action function has a fixed trusted search path',
    EXISTS (
        SELECT 1
        FROM pg_proc AS routine_record
        WHERE routine_record.oid =
            'approval.record_approval_action(uuid,uuid,uuid,uuid,uuid,uuid,text,text,text,uuid)'::regprocedure
          AND array_to_string(routine_record.proconfig, ',') =
              'search_path=pg_catalog, approval, access_control'
    )
);

SELECT sql_test.assert_no_rows(
    'PUBLIC cannot execute the controlled Approval Action function',
    $$
    SELECT routine_schema, routine_name, privilege_type
    FROM information_schema.routine_privileges
    WHERE grantee = 'PUBLIC'
      AND routine_schema = 'approval'
      AND routine_name = 'record_approval_action'
    $$
);

SELECT sql_test.assert_true(
    'Approval Action Records have an enabled append-only mutation trigger',
    EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'approval.approval_actions'::regclass
          AND tgname = 'approval_actions_append_only_guard'
          AND tgenabled <> 'D'
          AND NOT tgisinternal
    )
);

SELECT sql_test.assert_true(
    'Approval Action duties have an enabled append-only mutation trigger',
    EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'approval.approval_action_duties'::regclass
          AND tgname = 'approval_action_duties_append_only_guard'
          AND tgenabled <> 'D'
          AND NOT tgisinternal
    )
);

DO $record_primary_approve$
DECLARE
    v_context pg_temp.step3_context%ROWTYPE;
    v_result record;
    v_before timestamptz := clock_timestamp();
    v_after timestamptz;
BEGIN
    SELECT * INTO STRICT v_context FROM pg_temp.step3_context;

    SELECT *
    INTO STRICT v_result
    FROM approval.record_approval_action(
        v_context.approval_request_id,
        v_context.approval_policy_stage_id,
        v_context.actor_identity_id,
        v_context.organization_id,
        v_context.actor_session_id,
        v_context.authority_grant_id,
        'APPROVE',
        NULL,
        'APPROVAL_GRANTED',
        NULL
    );

    v_after := clock_timestamp();

    INSERT INTO pg_temp.step3_success_actions (
        fixture_key,
        approval_action_id,
        outcome,
        reason_code,
        recorded_at,
        invoked_before,
        invoked_after
    )
    VALUES (
        'approve',
        v_result.recorded_approval_action_id,
        v_result.outcome,
        v_result.reason_code,
        v_result.recorded_at,
        v_before,
        v_after
    );
END;
$record_primary_approve$;

SELECT sql_test.assert_true(
    'Valid controlled APPROVE action returns RECORDED',
    (
        SELECT outcome = 'RECORDED'
        FROM pg_temp.step3_success_actions
        WHERE fixture_key = 'approve'
    )
);

SELECT sql_test.assert_true(
    'Valid controlled APPROVE action returns a stable success reason code',
    (
        SELECT reason_code = 'APPROVAL_ACTION_RECORDED'
        FROM pg_temp.step3_success_actions
        WHERE fixture_key = 'approve'
    )
);

SELECT sql_test.assert_true(
    'Controlled APPROVE persists exact request stage actor session organization and Authority Grant binding',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions AS action_record
        CROSS JOIN pg_temp.step3_context AS context
        JOIN pg_temp.step3_success_actions AS success
          ON success.fixture_key = 'approve'
         AND success.approval_action_id = action_record.approval_action_id
        WHERE action_record.approval_request_id =
              context.approval_request_id
          AND action_record.approval_policy_stage_id =
              context.approval_policy_stage_id
          AND action_record.acting_identity_id =
              context.actor_identity_id
          AND action_record.acting_organization_id =
              context.organization_id
          AND action_record.acting_session_id =
              context.actor_session_id
          AND action_record.authority_grant_id =
              context.authority_grant_id
          AND action_record.action_type = 'APPROVE'
          AND action_record.action_reason_code = 'APPROVAL_GRANTED'
    )
);

SELECT sql_test.assert_true(
    'Controlled APPROVE derives the effective actor from the acting identity',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions AS action_record
        JOIN pg_temp.step3_success_actions AS success
          ON success.fixture_key = 'approve'
         AND success.approval_action_id = action_record.approval_action_id
        WHERE action_record.effective_actor_identity_id =
              action_record.acting_identity_id
    )
);

SELECT sql_test.assert_true(
    'Controlled APPROVE uses one authoritative recorded time',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions AS action_record
        JOIN pg_temp.step3_success_actions AS success
          ON success.fixture_key = 'approve'
         AND success.approval_action_id = action_record.approval_action_id
        WHERE action_record.action_at = success.recorded_at
          AND success.recorded_at >= success.invoked_before
          AND success.recorded_at <= success.invoked_after
    )
);

SELECT sql_test.assert_raises(
    'Approval Action Records reject UPDATE',
    format(
        'UPDATE approval.approval_actions '
        'SET action_reason = %L WHERE approval_action_id = %L::uuid',
        'rewritten',
        (
            SELECT approval_action_id::text
            FROM pg_temp.step3_success_actions
            WHERE fixture_key = 'approve'
        )
    ),
    '55000'
);

SELECT sql_test.assert_raises(
    'Approval Action Records reject DELETE',
    format(
        'DELETE FROM approval.approval_actions '
        'WHERE approval_action_id = %L::uuid',
        (
            SELECT approval_action_id::text
            FROM pg_temp.step3_success_actions
            WHERE fixture_key = 'approve'
        )
    ),
    '55000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an unsupported action type',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'INVALID_ACTION',
            NULL,
            'INVALID_ACTION'
        )
        FROM pg_temp.step3_context
    ),
    '22023'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects a malformed reason code',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'APPROVE',
            NULL,
            'not-valid'
        )
        FROM pg_temp.step3_context
    ),
    '22023'
);

SELECT sql_test.assert_raises(
    'Controlled DENY requires an attributable reason',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'DENY',
            '   ',
            'APPROVAL_DENIED'
        )
        FROM pg_temp.step3_context
    ),
    '22023'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects a missing Approval Request',
    (
        SELECT sql_test.phase4_step3_action_sql(
            gen_random_uuid(),
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '22023'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects a stage outside the request policy',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            gen_random_uuid(),
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects a non-pending Approval Request',
    (
        SELECT sql_test.phase4_step3_action_sql(
            nonpending_approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '55000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an expired Approval Request',
    (
        SELECT sql_test.phase4_step3_action_sql(
            expired_approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects a finalized Approval Request',
    (
        SELECT sql_test.phase4_step3_action_sql(
            finalized_approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '55000'
);

UPDATE approval.approval_policies
SET status = 'SUSPENDED'
WHERE approval_policy_id = (
    SELECT approval_policy_id FROM pg_temp.step3_context
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an inactive Approval Policy Version',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

UPDATE approval.approval_policies
SET status = 'ACTIVE'
WHERE approval_policy_id = (
    SELECT approval_policy_id FROM pg_temp.step3_context
);

UPDATE identity.identities
SET status = 'SUSPENDED'
WHERE identity_id = (
    SELECT actor_identity_id FROM pg_temp.step3_context
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an inactive acting identity',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

UPDATE identity.identities
SET status = 'ACTIVE'
WHERE identity_id = (
    SELECT actor_identity_id FROM pg_temp.step3_context
);

SELECT sql_test.assert_raises(
    'Controlled recording requires an acting session',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            NULL,
            authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects session-to-identity substitution',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            alternate_actor_identity_id,
            organization_id,
            actor_session_id,
            alternate_actor_authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects session-to-organization substitution',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            alternate_organization_id,
            actor_session_id,
            alternate_organization_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects a session for a different Platform Service',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            alternate_service_session_id,
            authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

UPDATE access_control.sessions
SET
    status = 'LOCKED',
    locked_at = statement_timestamp()
WHERE session_id = (
    SELECT actor_session_id FROM pg_temp.step3_context
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects a locked session',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

UPDATE access_control.sessions
SET
    status = 'ACTIVE',
    locked_at = NULL
WHERE session_id = (
    SELECT actor_session_id FROM pg_temp.step3_context
);

UPDATE approval.approval_policy_stages
SET required_authority_definition_id = NULL
WHERE approval_policy_stage_id = (
    SELECT approval_policy_stage_id FROM pg_temp.step3_context
);

SELECT sql_test.assert_raises(
    'Controlled recording requires a typed stage Authority Definition',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

UPDATE approval.approval_policy_stages
SET required_authority_definition_id = (
    SELECT authority_definition_id FROM pg_temp.step3_context
)
WHERE approval_policy_stage_id = (
    SELECT approval_policy_stage_id FROM pg_temp.step3_context
);

SELECT sql_test.assert_raises(
    'Controlled recording requires an exact Authority Grant',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            NULL,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects the wrong Authority Definition',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            alternate_authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an Authority Grant for another identity',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            alternate_actor_authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an inactive Authority Grant',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            inactive_authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an Authority Grant for another service',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            alternate_service_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an Authority Grant for another purpose',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            alternate_purpose_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an Authority Grant for another operation',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            alternate_operation_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an Authority Grant for another organization',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            alternate_organization_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an Authority Grant for another Governed Scope',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            alternate_scope_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects an Authority Grant for another target',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            alternate_target_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Controlled recording rejects a deprecated free-form scope reference',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            legacy_scope_reference_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED'
        )
        FROM pg_temp.step3_context
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Primary Approval Action types reject a prior-action link',
    (
        SELECT sql_test.phase4_step3_action_sql(
            context.approval_request_id,
            context.approval_policy_stage_id,
            context.actor_identity_id,
            context.organization_id,
            context.actor_session_id,
            context.authority_grant_id,
            'APPROVE',
            NULL,
            'APPROVAL_GRANTED',
            success.approval_action_id
        )
        FROM pg_temp.step3_context AS context
        CROSS JOIN pg_temp.step3_success_actions AS success
        WHERE success.fixture_key = 'approve'
    ),
    '22023'
);

SELECT sql_test.assert_raises(
    'Withdrawal requires an exact prior Approval Action Record',
    (
        SELECT sql_test.phase4_step3_action_sql(
            approval_request_id,
            approval_policy_stage_id,
            actor_identity_id,
            organization_id,
            actor_session_id,
            authority_grant_id,
            'WITHDRAW_APPROVAL',
            'Withdraw the prior approval',
            'APPROVAL_WITHDRAWN',
            NULL
        )
        FROM pg_temp.step3_context
    ),
    '22023'
);

SELECT sql_test.assert_raises(
    'Withdrawal rejects a prior action from another Approval Request',
    (
        SELECT sql_test.phase4_step3_action_sql(
            context.alternate_approval_request_id,
            context.approval_policy_stage_id,
            context.actor_identity_id,
            context.organization_id,
            context.actor_session_id,
            context.authority_grant_id,
            'WITHDRAW_APPROVAL',
            'Withdraw the prior approval',
            'APPROVAL_WITHDRAWN',
            success.approval_action_id
        )
        FROM pg_temp.step3_context AS context
        CROSS JOIN pg_temp.step3_success_actions AS success
        WHERE success.fixture_key = 'approve'
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Withdrawal rejects a prior action from another policy stage',
    (
        SELECT sql_test.phase4_step3_action_sql(
            context.approval_request_id,
            context.alternate_approval_policy_stage_id,
            context.actor_identity_id,
            context.organization_id,
            context.actor_session_id,
            context.authority_grant_id,
            'WITHDRAW_APPROVAL',
            'Withdraw the prior approval',
            'APPROVAL_WITHDRAWN',
            success.approval_action_id
        )
        FROM pg_temp.step3_context AS context
        CROSS JOIN pg_temp.step3_success_actions AS success
        WHERE success.fixture_key = 'approve'
    ),
    '28000'
);

SELECT sql_test.assert_raises(
    'Withdrawal rejects effective-actor substitution',
    (
        SELECT sql_test.phase4_step3_action_sql(
            context.approval_request_id,
            context.approval_policy_stage_id,
            context.alternate_actor_identity_id,
            context.organization_id,
            context.alternate_actor_session_id,
            context.alternate_actor_authority_grant_id,
            'WITHDRAW_APPROVAL',
            'Withdraw the prior approval',
            'APPROVAL_WITHDRAWN',
            success.approval_action_id
        )
        FROM pg_temp.step3_context AS context
        CROSS JOIN pg_temp.step3_success_actions AS success
        WHERE success.fixture_key = 'approve'
    ),
    '28000'
);

DO $record_deny_and_abstain$
DECLARE
    v_context pg_temp.step3_context%ROWTYPE;
    v_result record;
    v_before timestamptz;
    v_after timestamptz;
BEGIN
    SELECT * INTO STRICT v_context FROM pg_temp.step3_context;

    v_before := clock_timestamp();
    SELECT * INTO STRICT v_result
    FROM approval.record_approval_action(
        v_context.approval_request_id,
        v_context.approval_policy_stage_id,
        v_context.actor_identity_id,
        v_context.organization_id,
        v_context.actor_session_id,
        v_context.authority_grant_id,
        'DENY',
        'Controlled denial fixture',
        'APPROVAL_DENIED',
        NULL
    );
    v_after := clock_timestamp();

    INSERT INTO pg_temp.step3_success_actions
    VALUES (
        'deny',
        v_result.recorded_approval_action_id,
        v_result.outcome,
        v_result.reason_code,
        v_result.recorded_at,
        v_before,
        v_after
    );

    v_before := clock_timestamp();
    SELECT * INTO STRICT v_result
    FROM approval.record_approval_action(
        v_context.approval_request_id,
        v_context.approval_policy_stage_id,
        v_context.actor_identity_id,
        v_context.organization_id,
        v_context.actor_session_id,
        v_context.authority_grant_id,
        'ABSTAIN',
        NULL,
        'APPROVAL_ABSTAINED',
        NULL
    );
    v_after := clock_timestamp();

    INSERT INTO pg_temp.step3_success_actions
    VALUES (
        'abstain',
        v_result.recorded_approval_action_id,
        v_result.outcome,
        v_result.reason_code,
        v_result.recorded_at,
        v_before,
        v_after
    );
END;
$record_deny_and_abstain$;

SELECT sql_test.assert_raises(
    'Withdrawal rejects a prior action that is not APPROVE',
    (
        SELECT sql_test.phase4_step3_action_sql(
            context.approval_request_id,
            context.approval_policy_stage_id,
            context.actor_identity_id,
            context.organization_id,
            context.actor_session_id,
            context.authority_grant_id,
            'WITHDRAW_APPROVAL',
            'Withdraw the denial',
            'APPROVAL_WITHDRAWN',
            success.approval_action_id
        )
        FROM pg_temp.step3_context AS context
        CROSS JOIN pg_temp.step3_success_actions AS success
        WHERE success.fixture_key = 'deny'
    ),
    '28000'
);

DO $record_withdrawal$
DECLARE
    v_context pg_temp.step3_context%ROWTYPE;
    v_prior_id uuid;
    v_result record;
    v_before timestamptz := clock_timestamp();
    v_after timestamptz;
BEGIN
    SELECT * INTO STRICT v_context FROM pg_temp.step3_context;
    SELECT approval_action_id
    INTO STRICT v_prior_id
    FROM pg_temp.step3_success_actions
    WHERE fixture_key = 'approve';

    SELECT * INTO STRICT v_result
    FROM approval.record_approval_action(
        v_context.approval_request_id,
        v_context.approval_policy_stage_id,
        v_context.actor_identity_id,
        v_context.organization_id,
        v_context.actor_session_id,
        v_context.authority_grant_id,
        'WITHDRAW_APPROVAL',
        'Withdraw the prior approval',
        'APPROVAL_WITHDRAWN',
        v_prior_id
    );
    v_after := clock_timestamp();

    INSERT INTO pg_temp.step3_success_actions
    VALUES (
        'withdraw',
        v_result.recorded_approval_action_id,
        v_result.outcome,
        v_result.reason_code,
        v_result.recorded_at,
        v_before,
        v_after
    );
END;
$record_withdrawal$;

SELECT sql_test.assert_true(
    'Valid withdrawal creates a new Approval Action Record referencing the prior APPROVE',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions AS withdrawal
        JOIN pg_temp.step3_success_actions AS withdraw_success
          ON withdraw_success.fixture_key = 'withdraw'
         AND withdraw_success.approval_action_id =
             withdrawal.approval_action_id
        JOIN pg_temp.step3_success_actions AS approve_success
          ON approve_success.fixture_key = 'approve'
         AND approve_success.approval_action_id =
             withdrawal.prior_approval_action_id
        WHERE withdrawal.action_type = 'WITHDRAW_APPROVAL'
          AND withdrawal.action_reason_code = 'APPROVAL_WITHDRAWN'
    )
);

SELECT sql_test.assert_raises(
    'A prior Approval Action Record cannot be withdrawn twice',
    (
        SELECT sql_test.phase4_step3_action_sql(
            context.approval_request_id,
            context.approval_policy_stage_id,
            context.actor_identity_id,
            context.organization_id,
            context.actor_session_id,
            context.authority_grant_id,
            'WITHDRAW_APPROVAL',
            'Withdraw the prior approval again',
            'APPROVAL_WITHDRAWN',
            success.approval_action_id
        )
        FROM pg_temp.step3_context AS context
        CROSS JOIN pg_temp.step3_success_actions AS success
        WHERE success.fixture_key = 'approve'
    ),
    '28000'
);

DO $record_correction_and_supersession$
DECLARE
    v_context pg_temp.step3_context%ROWTYPE;
    v_prior_id uuid;
    v_result record;
    v_before timestamptz;
    v_after timestamptz;
BEGIN
    SELECT * INTO STRICT v_context FROM pg_temp.step3_context;

    SELECT approval_action_id
    INTO STRICT v_prior_id
    FROM pg_temp.step3_success_actions
    WHERE fixture_key = 'deny';

    v_before := clock_timestamp();
    SELECT * INTO STRICT v_result
    FROM approval.record_approval_action(
        v_context.approval_request_id,
        v_context.approval_policy_stage_id,
        v_context.actor_identity_id,
        v_context.organization_id,
        v_context.actor_session_id,
        v_context.authority_grant_id,
        'CORRECT',
        'Correct the prior denial explanation',
        'APPROVAL_ACTION_CORRECTED',
        v_prior_id
    );
    v_after := clock_timestamp();

    INSERT INTO pg_temp.step3_success_actions
    VALUES (
        'correct',
        v_result.recorded_approval_action_id,
        v_result.outcome,
        v_result.reason_code,
        v_result.recorded_at,
        v_before,
        v_after
    );

    SELECT approval_action_id
    INTO STRICT v_prior_id
    FROM pg_temp.step3_success_actions
    WHERE fixture_key = 'abstain';

    v_before := clock_timestamp();
    SELECT * INTO STRICT v_result
    FROM approval.record_approval_action(
        v_context.approval_request_id,
        v_context.approval_policy_stage_id,
        v_context.actor_identity_id,
        v_context.organization_id,
        v_context.actor_session_id,
        v_context.authority_grant_id,
        'SUPERSEDE',
        'Supersede the prior abstention',
        'APPROVAL_ACTION_SUPERSEDED',
        v_prior_id
    );
    v_after := clock_timestamp();

    INSERT INTO pg_temp.step3_success_actions
    VALUES (
        'supersede',
        v_result.recorded_approval_action_id,
        v_result.outcome,
        v_result.reason_code,
        v_result.recorded_at,
        v_before,
        v_after
    );
END;
$record_correction_and_supersession$;

SELECT sql_test.assert_true(
    'Valid correction creates a new attributable Approval Action Record',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions AS correction
        JOIN pg_temp.step3_success_actions AS correction_success
          ON correction_success.fixture_key = 'correct'
         AND correction_success.approval_action_id =
             correction.approval_action_id
        JOIN pg_temp.step3_success_actions AS prior_success
          ON prior_success.fixture_key = 'deny'
         AND prior_success.approval_action_id =
             correction.prior_approval_action_id
        WHERE correction.action_type = 'CORRECT'
          AND correction.action_reason_code =
              'APPROVAL_ACTION_CORRECTED'
    )
);

SELECT sql_test.assert_true(
    'Valid supersession creates a new attributable Approval Action Record',
    EXISTS (
        SELECT 1
        FROM approval.approval_actions AS supersession
        JOIN pg_temp.step3_success_actions AS supersession_success
          ON supersession_success.fixture_key = 'supersede'
         AND supersession_success.approval_action_id =
             supersession.approval_action_id
        JOIN pg_temp.step3_success_actions AS prior_success
          ON prior_success.fixture_key = 'abstain'
         AND prior_success.approval_action_id =
             supersession.prior_approval_action_id
        WHERE supersession.action_type = 'SUPERSEDE'
          AND supersession.action_reason_code =
              'APPROVAL_ACTION_SUPERSEDED'
    )
);

SELECT sql_test.assert_equal_bigint(
    'Exactly three typed lineage actions reference exact prior records',
    (
        SELECT count(*)
        FROM approval.approval_actions AS action_record
        WHERE action_record.approval_request_id = (
                  SELECT approval_request_id
                  FROM pg_temp.step3_context
              )
          AND action_record.prior_approval_action_id IS NOT NULL
          AND action_record.action_type IN (
              'WITHDRAW_APPROVAL',
              'CORRECT',
              'SUPERSEDE'
          )
    ),
    3
);

SELECT sql_test.assert_equal_bigint(
    'Controlled Step 3 scenarios create only the six expected Approval Action Records',
    (
        SELECT count(*)
        FROM approval.approval_actions
        WHERE approval_request_id = (
            SELECT approval_request_id FROM pg_temp.step3_context
        )
    ),
    6
);

SELECT sql_test.assert_equal_bigint(
    'Step 3 controlled recording does not yet claim duty-combination enforcement',
    (
        SELECT count(*)
        FROM approval.approval_action_duties AS duty_record
        JOIN approval.approval_actions AS action_record
          ON action_record.approval_action_id =
             duty_record.approval_action_id
        WHERE action_record.approval_request_id = (
            SELECT approval_request_id FROM pg_temp.step3_context
        )
    ),
    0
);
