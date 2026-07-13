-- ============================================================================
-- Phase 4 Step 6 stage satisfaction and Approval Request finalization
-- ============================================================================
--
-- Purpose:
-- Prove current-action derivation, persisted stage satisfaction, blocking
-- denial, finalization exactly once, caller-result mismatch rejection,
-- exact Decision Record linkage, and later-use approval continuity.
--
-- Independent-connection finalization races remain Phase 4 Step 7.
-- ============================================================================

SELECT sql_test.begin_file(
    '210_approval_stage_satisfaction_and_finalization.sql'
);

CREATE TEMP TABLE step6_ids (
    fixture_key text PRIMARY KEY,
    fixture_id uuid NOT NULL
) ON COMMIT PRESERVE ROWS;

CREATE TEMP TABLE step6_actions (
    fixture_key text PRIMARY KEY,
    approval_action_id uuid NOT NULL UNIQUE
) ON COMMIT PRESERVE ROWS;

CREATE FUNCTION sql_test.phase4_step6_id(p_fixture_key text)
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path = pg_catalog, sql_test
AS $function$
    SELECT fixture_id
    FROM pg_temp.step6_ids
    WHERE fixture_key = p_fixture_key;
$function$;

CREATE FUNCTION sql_test.phase4_step6_error(p_sql text)
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

CREATE FUNCTION sql_test.phase4_step6_record(
    p_action_key text,
    p_request_key text,
    p_stage_key text,
    p_actor_key text,
    p_session_key text,
    p_grant_key text,
    p_action_type text DEFAULT 'APPROVE',
    p_reason_code text DEFAULT 'SQL_TEST_STEP6_APPROVED',
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
          FROM pg_temp.step6_actions
         WHERE fixture_key = p_prior_action_key;
    END IF;

    SELECT recorded_approval_action_id
      INTO STRICT v_action_id
      FROM approval.record_approval_action(
          sql_test.phase4_step6_id(p_request_key),
          sql_test.phase4_step6_id(p_stage_key),
          sql_test.phase4_step6_id(p_actor_key),
          sql_test.phase4_step6_id('organization'),
          sql_test.phase4_step6_id(p_session_key),
          sql_test.phase4_step6_id(p_grant_key),
          p_action_type,
          'Phase 4 Step 6 SQL test',
          p_reason_code,
          v_prior_action_id
      );

    INSERT INTO pg_temp.step6_actions (
        fixture_key,
        approval_action_id
    )
    VALUES (p_action_key, v_action_id);

    RETURN v_action_id;
END;
$function$;

DO $setup$
DECLARE
    v_now timestamptz := statement_timestamp();
    v_suffix text := replace(gen_random_uuid()::text, '-', '');

    v_identity_a uuid;
    v_identity_b uuid;
    v_identity_c uuid;
    v_identity_d uuid;
    v_organization uuid;
    v_service uuid;
    v_purpose uuid;
    v_operation uuid;
    v_scope uuid;
    v_purpose_key text;
    v_operation_key text;
    v_session_a uuid;
    v_session_b uuid;
    v_authority_a uuid;
    v_authority_b uuid;

    v_policy uuid := gen_random_uuid();
    v_stage_a uuid := gen_random_uuid();
    v_stage_b uuid := gen_random_uuid();

    v_request_approved uuid := gen_random_uuid();
    v_request_unsatisfied uuid := gen_random_uuid();
    v_request_denied uuid := gen_random_uuid();
    v_request_expired uuid := gen_random_uuid();
    v_request_mismatch uuid := gen_random_uuid();
    v_request_cancelled uuid := gen_random_uuid();
    v_request_escalated uuid := gen_random_uuid();
    v_request_withdrawn uuid := gen_random_uuid();

    v_grant_a_a uuid := gen_random_uuid();
    v_grant_b_a uuid := gen_random_uuid();
    v_grant_a_b uuid := gen_random_uuid();

    v_decision uuid := gen_random_uuid();
    v_evaluation uuid := gen_random_uuid();
    v_bad_decision uuid := gen_random_uuid();
    v_bad_evaluation uuid := gen_random_uuid();
BEGIN
    SELECT identity_id
      INTO STRICT v_identity_a
      FROM identity.identities
     WHERE identity_key LIKE 'sql_test.phase4_step5.identity_a_%'
     LIMIT 1;

    SELECT identity_id
      INTO STRICT v_identity_b
      FROM identity.identities
     WHERE identity_key LIKE 'sql_test.phase4_step5.identity_b_%'
     LIMIT 1;

    SELECT identity_id
      INTO STRICT v_identity_c
      FROM identity.identities
     WHERE identity_key LIKE 'sql_test.phase4_step5.identity_c_%'
     LIMIT 1;

    SELECT identity_id
      INTO STRICT v_identity_d
      FROM identity.identities
     WHERE identity_key LIKE 'sql_test.phase4_step5.identity_d_%'
     LIMIT 1;

    SELECT organization_id
      INTO STRICT v_organization
      FROM organization.organizations
     WHERE organization_key LIKE 'sql_test.phase4_step3_org_%'
     LIMIT 1;

    SELECT service_id
      INTO STRICT v_service
      FROM service.platform_services
     WHERE service_key LIKE 'sql_test.phase4_step3_service_%'
     LIMIT 1;

    SELECT purpose_definition_id, purpose_key
      INTO STRICT v_purpose, v_purpose_key
      FROM access_control.purpose_definitions
     WHERE purpose_key LIKE 'sql_test.phase4_step3_purpose_%'
     LIMIT 1;

    SELECT operation_definition_id, operation_key
      INTO STRICT v_operation, v_operation_key
      FROM access_control.operation_definitions
     WHERE operation_key LIKE 'sql_test.phase4_step3_operation_%'
     LIMIT 1;

    SELECT governed_scope_id
      INTO STRICT v_scope
      FROM organization.governed_scopes
     WHERE governed_scope_key LIKE 'sql_test.phase4_step3_scope_%'
     LIMIT 1;

    SELECT authority_definition_id
      INTO STRICT v_authority_a
      FROM access_control.authority_definitions
     WHERE authority_key LIKE 'sql_test.phase4_step5.auth_a_%'
     LIMIT 1;

    SELECT authority_definition_id
      INTO STRICT v_authority_b
      FROM access_control.authority_definitions
     WHERE authority_key LIKE 'sql_test.phase4_step5.auth_b_%'
     LIMIT 1;

    SELECT session_id
      INTO STRICT v_session_a
      FROM access_control.sessions
     WHERE identity_id = v_identity_a
       AND organization_id = v_organization
       AND service_id = v_service
       AND status = 'ACTIVE'
     ORDER BY authenticated_at DESC
     LIMIT 1;

    SELECT session_id
      INTO STRICT v_session_b
      FROM access_control.sessions
     WHERE identity_id = v_identity_b
       AND organization_id = v_organization
       AND service_id = v_service
       AND status = 'ACTIVE'
     ORDER BY authenticated_at DESC
     LIMIT 1;

    INSERT INTO pg_temp.step6_ids (fixture_key, fixture_id)
    VALUES
        ('identity_a', v_identity_a),
        ('identity_b', v_identity_b),
        ('identity_c', v_identity_c),
        ('identity_d', v_identity_d),
        ('organization', v_organization),
        ('service', v_service),
        ('purpose', v_purpose),
        ('operation', v_operation),
        ('scope', v_scope),
        ('session_a', v_session_a),
        ('session_b', v_session_b),
        ('authority_a', v_authority_a),
        ('authority_b', v_authority_b),
        ('policy', v_policy),
        ('stage_a', v_stage_a),
        ('stage_b', v_stage_b),
        ('request_approved', v_request_approved),
        ('request_unsatisfied', v_request_unsatisfied),
        ('request_denied', v_request_denied),
        ('request_expired', v_request_expired),
        ('request_mismatch', v_request_mismatch),
        ('request_cancelled', v_request_cancelled),
        ('request_escalated', v_request_escalated),
        ('request_withdrawn', v_request_withdrawn),
        ('grant_a_a', v_grant_a_a),
        ('grant_b_a', v_grant_b_a),
        ('grant_a_b', v_grant_a_b),
        ('decision', v_decision),
        ('evaluation', v_evaluation),
        ('bad_decision', v_bad_decision),
        ('bad_evaluation', v_bad_evaluation);

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
        'sql_test.phase4_step6.policy_' || v_suffix,
        1,
        'SQL Test Phase 4 Step 6 Policy',
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
    VALUES
        (
            v_stage_a,
            v_policy,
            1,
            'STEP6_PRIMARY',
            2,
            true,
            false,
            'Two independent Authority A approvers',
            v_authority_a,
            false,
            false,
            false,
            false,
            NULL,
            interval '30 minutes',
            false,
            true
        ),
        (
            v_stage_b,
            v_policy,
            2,
            'STEP6_SECONDARY',
            1,
            true,
            false,
            'One Authority B approver',
            v_authority_b,
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
    SELECT
        request_id,
        v_policy,
        v_identity_c,
        v_organization,
        NULL,
        v_service,
        v_purpose_key,
        v_operation_key,
        'TEST_RESOURCE',
        target_reference,
        v_scope,
        'TEST',
        'PENDING',
        requested_at,
        expires_at,
        gen_random_uuid(),
        v_purpose,
        v_operation,
        NULL,
        gen_random_uuid()
    FROM (
        VALUES
            (v_request_approved, 'step6-approved',
                v_now - interval '1 minute', v_now + interval '1 hour'),
            (v_request_unsatisfied, 'step6-unsatisfied',
                v_now - interval '1 minute', v_now + interval '1 hour'),
            (v_request_denied, 'step6-denied',
                v_now - interval '1 minute', v_now + interval '1 hour'),
            (v_request_expired, 'step6-expired',
                v_now - interval '2 hours', v_now - interval '1 hour'),
            (v_request_mismatch, 'step6-mismatch',
                v_now - interval '1 minute', v_now + interval '1 hour'),
            (v_request_cancelled, 'step6-cancelled',
                v_now - interval '1 minute', v_now + interval '1 hour'),
            (v_request_escalated, 'step6-escalated',
                v_now - interval '1 minute', v_now + interval '1 hour'),
            (v_request_withdrawn, 'step6-withdrawn',
                v_now - interval '1 minute', v_now + interval '1 hour')
    ) AS requests(request_id, target_reference, requested_at, expires_at);

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
            v_grant_a_a, v_identity_a, v_authority_a,
            v_purpose, v_operation, v_service, v_organization,
            NULL, true, NULL, NULL, true, NULL,
            'ACTIVE', v_now - interval '1 day', v_now + interval '1 day',
            v_identity_d, NULL, NULL, 0
        ),
        (
            v_grant_b_a, v_identity_b, v_authority_a,
            v_purpose, v_operation, v_service, v_organization,
            NULL, true, NULL, NULL, true, NULL,
            'ACTIVE', v_now - interval '1 day', v_now + interval '1 day',
            v_identity_d, NULL, NULL, 0
        ),
        (
            v_grant_a_b, v_identity_a, v_authority_b,
            v_purpose, v_operation, v_service, v_organization,
            NULL, true, NULL, NULL, true, NULL,
            'ACTIVE', v_now - interval '1 day', v_now + interval '1 day',
            v_identity_d, NULL, NULL, 0
        );
END;
$setup$;

-- Create current, withdrawn, denied, cancellation, escalation, and complete
-- approval action sets.
SELECT sql_test.phase4_step6_record(
    'approved_a1', 'request_approved', 'stage_a',
    'identity_a', 'session_a', 'grant_a_a'
);
SELECT sql_test.phase4_step6_record(
    'approved_a2', 'request_approved', 'stage_a',
    'identity_b', 'session_b', 'grant_b_a'
);
SELECT sql_test.phase4_step6_record(
    'approved_b1', 'request_approved', 'stage_b',
    'identity_a', 'session_a', 'grant_a_b'
);

SELECT sql_test.phase4_step6_record(
    'unsatisfied_a1', 'request_unsatisfied', 'stage_a',
    'identity_a', 'session_a', 'grant_a_a'
);

SELECT sql_test.phase4_step6_record(
    'denied_a1', 'request_denied', 'stage_a',
    'identity_a', 'session_a', 'grant_a_a',
    'DENY', 'SQL_TEST_STEP6_DENIED'
);

SELECT sql_test.phase4_step6_record(
    'mismatch_a1', 'request_mismatch', 'stage_a',
    'identity_a', 'session_a', 'grant_a_a'
);
SELECT sql_test.phase4_step6_record(
    'mismatch_a2', 'request_mismatch', 'stage_a',
    'identity_b', 'session_b', 'grant_b_a'
);
SELECT sql_test.phase4_step6_record(
    'mismatch_b1', 'request_mismatch', 'stage_b',
    'identity_a', 'session_a', 'grant_a_b'
);

SELECT sql_test.phase4_step6_record(
    'cancel_action', 'request_cancelled', 'stage_a',
    'identity_a', 'session_a', 'grant_a_a',
    'CANCEL_REQUEST', 'SQL_TEST_STEP6_CANCELLED'
);

SELECT sql_test.phase4_step6_record(
    'escalate_action', 'request_escalated', 'stage_a',
    'identity_a', 'session_a', 'grant_a_a',
    'ESCALATE', 'SQL_TEST_STEP6_ESCALATED'
);

SELECT sql_test.phase4_step6_record(
    'withdrawn_approve', 'request_withdrawn', 'stage_a',
    'identity_a', 'session_a', 'grant_a_a'
);
SELECT sql_test.phase4_step6_record(
    'withdrawn_action', 'request_withdrawn', 'stage_a',
    'identity_a', 'session_a', 'grant_a_a',
    'WITHDRAW_APPROVAL', 'SQL_TEST_STEP6_WITHDRAWN',
    'withdrawn_approve'
);

-- Structural contract: assertions 1-18.
SELECT sql_test.assert_true(
    'Finalized stage evaluations have a one-per-request-stage unique index',
    EXISTS (
        SELECT 1
        FROM pg_class AS index_relation
        JOIN pg_index AS index_record
          ON index_record.indexrelid = index_relation.oid
        WHERE index_relation.relname =
              'approval_stage_evaluations_one_finalized_stage_idx'
          AND index_record.indisunique
          AND index_record.indisvalid
          AND index_record.indisready
    )
);

SELECT sql_test.assert_true(
    'Decision approval-stage evaluation link table exists',
    to_regclass('decision.approval_stage_evaluation_links') IS NOT NULL
);

SELECT sql_test.assert_true(
    'Decision Records expose an exact decision and Approval Request key',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'decision.decision_records'::regclass
          AND conname = 'decision_records_approval_request_context_uq'
          AND contype = 'u'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Authorization Leases expose approval-continuity binding state',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_leases'
          AND column_name = 'approval_continuity_required'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Current Approval Action derivation function exists',
    to_regprocedure(
        'approval.approval_action_is_current(uuid,timestamp with time zone)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'Approval stage evaluation function exists',
    to_regprocedure(
        'approval.evaluate_approval_stage(uuid,uuid,timestamp with time zone,boolean)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'Approval Request finalization function exists',
    to_regprocedure(
        'approval.finalize_approval_request(uuid,text,uuid)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'Approval continuity function exists',
    to_regprocedure(
        'approval.approval_request_is_current_for_authorization(uuid,timestamp with time zone)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'Decision approval-stage link function exists',
    to_regprocedure(
        'decision.link_approval_stage_evaluation(uuid,uuid,uuid)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'Authorization Lease approval-continuity trigger is enabled',
    EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'access_control.authorization_leases'::regclass
          AND tgname = 'authorization_lease_approval_continuity_guard'
          AND tgenabled <> 'D'
          AND NOT tgisinternal
    )
);

SELECT sql_test.assert_true(
    'Decision approval-stage links are append-only',
    EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid =
              'decision.approval_stage_evaluation_links'::regclass
          AND tgname =
              'approval_stage_evaluation_links_append_only_guard'
          AND tgenabled <> 'D'
          AND NOT tgisinternal
    )
);

SELECT sql_test.assert_false(
    'PUBLIC cannot execute current Approval Action derivation',
    has_function_privilege(
        'public',
        'approval.approval_action_is_current(uuid,timestamp with time zone)',
        'EXECUTE'
    )
);

SELECT sql_test.assert_false(
    'PUBLIC cannot execute stage evaluation',
    has_function_privilege(
        'public',
        'approval.evaluate_approval_stage(uuid,uuid,timestamp with time zone,boolean)',
        'EXECUTE'
    )
);

SELECT sql_test.assert_false(
    'PUBLIC cannot execute Approval Request finalization',
    has_function_privilege(
        'public',
        'approval.finalize_approval_request(uuid,text,uuid)',
        'EXECUTE'
    )
);

SELECT sql_test.assert_false(
    'PUBLIC cannot execute approval continuity revalidation',
    has_function_privilege(
        'public',
        'approval.approval_request_is_current_for_authorization(uuid,timestamp with time zone)',
        'EXECUTE'
    )
);

SELECT sql_test.assert_false(
    'PUBLIC cannot execute Decision approval-stage linking',
    has_function_privilege(
        'public',
        'decision.link_approval_stage_evaluation(uuid,uuid,uuid)',
        'EXECUTE'
    )
);

SELECT sql_test.assert_false(
    'PUBLIC cannot read Decision approval-stage links',
    has_table_privilege(
        'public',
        'decision.approval_stage_evaluation_links',
        'SELECT'
    )
);

SELECT sql_test.assert_true(
    'Lease continuity trigger derives its binding from Decision Record links',
    position(
        'decision.approval_stage_evaluation_links'
        IN pg_get_functiondef(
            'approval.enforce_authorization_lease_approval_continuity()'::regprocedure
        )
    ) > 0
);

-- Current-action and stage-satisfaction behavior: assertions 19-27.
SELECT sql_test.assert_true(
    'A fresh Approval Action is current at evaluation time',
    approval.approval_action_is_current(
        (
            SELECT approval_action_id
            FROM pg_temp.step6_actions
            WHERE fixture_key = 'approved_a1'
        ),
        statement_timestamp()
    )
);

SELECT sql_test.assert_false(
    'A withdrawn Approval Action is no longer current',
    approval.approval_action_is_current(
        (
            SELECT approval_action_id
            FROM pg_temp.step6_actions
            WHERE fixture_key = 'withdrawn_approve'
        ),
        statement_timestamp()
    )
);

SELECT *
FROM approval.evaluate_approval_stage(
    sql_test.phase4_step6_id('request_approved'),
    sql_test.phase4_step6_id('stage_a'),
    statement_timestamp(),
    false
);

SELECT sql_test.assert_true(
    'Two current independent approvals satisfy the primary stage',
    EXISTS (
        SELECT 1
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND approval_policy_stage_id =
              sql_test.phase4_step6_id('stage_a')
          AND NOT finalized_evaluation
          AND result = 'SATISFIED'
    )
);

SELECT sql_test.assert_equal_bigint(
    'Primary stage records its required approval count',
    (
        SELECT required_approvals
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND approval_policy_stage_id =
              sql_test.phase4_step6_id('stage_a')
          AND NOT finalized_evaluation
        ORDER BY evaluated_at DESC
        LIMIT 1
    ),
    2
);

SELECT sql_test.assert_equal_bigint(
    'Primary stage counts exactly two approvals',
    (
        SELECT counted_approvals
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND approval_policy_stage_id =
              sql_test.phase4_step6_id('stage_a')
          AND NOT finalized_evaluation
        ORDER BY evaluated_at DESC
        LIMIT 1
    ),
    2
);

SELECT sql_test.assert_equal_bigint(
    'Primary stage records two distinct effective actors',
    (
        SELECT distinct_effective_actors
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND approval_policy_stage_id =
              sql_test.phase4_step6_id('stage_a')
          AND NOT finalized_evaluation
        ORDER BY evaluated_at DESC
        LIMIT 1
    ),
    2
);

SELECT sql_test.assert_equal_bigint(
    'Primary stage persists two exact counted action links',
    (
        SELECT count(*)
        FROM approval.approval_stage_evaluation_actions AS link
        JOIN approval.approval_stage_evaluations AS evaluation
          ON evaluation.approval_stage_evaluation_id =
             link.approval_stage_evaluation_id
        WHERE evaluation.approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND evaluation.approval_policy_stage_id =
              sql_test.phase4_step6_id('stage_a')
          AND NOT evaluation.finalized_evaluation
          AND link.counted
    ),
    2
);

SELECT *
FROM approval.evaluate_approval_stage(
    sql_test.phase4_step6_id('request_approved'),
    sql_test.phase4_step6_id('stage_b'),
    statement_timestamp(),
    false
);

SELECT sql_test.assert_true(
    'One current approval satisfies the secondary stage',
    EXISTS (
        SELECT 1
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND approval_policy_stage_id =
              sql_test.phase4_step6_id('stage_b')
          AND NOT finalized_evaluation
          AND result = 'SATISFIED'
          AND counted_approvals = 1
    )
);

SELECT sql_test.assert_equal_bigint(
    'Exploratory stage evaluations remain non-final',
    (
        SELECT count(*)
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND NOT finalized_evaluation
    ),
    2
);

-- Finalization behavior: assertions 28-51.
SELECT *
FROM approval.finalize_approval_request(
    sql_test.phase4_step6_id('request_approved'),
    'APPROVED',
    sql_test.phase4_step6_id('identity_d')
);

SELECT sql_test.assert_true(
    'Complete stage satisfaction finalizes the request as APPROVED',
    EXISTS (
        SELECT 1
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND status = 'APPROVED'
    )
);

SELECT sql_test.assert_true(
    'Approved finalization records a terminal timestamp',
    (
        SELECT finalized_at IS NOT NULL
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
    )
);

SELECT sql_test.assert_true(
    'Approved finalization records the exact finalizer',
    (
        SELECT finalized_by_identity_id =
               sql_test.phase4_step6_id('identity_d')
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
    )
);

SELECT sql_test.assert_true(
    'Approved finalization records the computed reason code',
    (
        SELECT final_reason_code = 'APPROVAL_REQUEST_APPROVED'
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
    )
);

SELECT sql_test.assert_equal_bigint(
    'Approved finalization persists one final evaluation per policy stage',
    (
        SELECT count(*)
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND finalized_evaluation
    ),
    2
);

SELECT sql_test.assert_equal_bigint(
    'Every finalized approved stage is SATISFIED',
    (
        SELECT count(*)
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND finalized_evaluation
          AND result = 'SATISFIED'
    ),
    2
);

SELECT sql_test.assert_equal_bigint(
    'All finalized stages use one authoritative evaluation time',
    (
        SELECT count(DISTINCT evaluated_at)
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND finalized_evaluation
    ),
    1
);

SELECT sql_test.assert_true(
    'The stage evaluation time equals the Approval Request finalization time',
    (
        SELECT bool_and(
                   evaluation.evaluated_at = request_record.finalized_at
               )
        FROM approval.approval_stage_evaluations AS evaluation
        JOIN approval.approval_requests AS request_record
          ON request_record.approval_request_id =
             evaluation.approval_request_id
        WHERE evaluation.approval_request_id =
              sql_test.phase4_step6_id('request_approved')
          AND evaluation.finalized_evaluation
    )
);

SELECT sql_test.assert_true(
    'A finalized Approval Request cannot be finalized again',
    sql_test.phase4_step6_error(
        format(
            'SELECT * FROM approval.finalize_approval_request(%L::uuid,%L,%L::uuid)',
            sql_test.phase4_step6_id('request_approved')::text,
            'APPROVED',
            sql_test.phase4_step6_id('identity_d')::text
        )
    ) = '55000:APPROVAL_REQUEST_FINALIZED'
);

SELECT sql_test.assert_true(
    'Unsatisfied stages prevent APPROVED finalization',
    sql_test.phase4_step6_error(
        format(
            'SELECT * FROM approval.finalize_approval_request(%L::uuid,%L,%L::uuid)',
            sql_test.phase4_step6_id('request_unsatisfied')::text,
            'APPROVED',
            sql_test.phase4_step6_id('identity_d')::text
        )
    ) = '55000:APPROVAL_STAGE_UNSATISFIED'
);

SELECT sql_test.assert_true(
    'A rejected unsatisfied finalization leaves the request PENDING',
    (
        SELECT status = 'PENDING' AND finalized_at IS NULL
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_unsatisfied')
    )
);

SELECT sql_test.assert_equal_bigint(
    'A rejected unsatisfied finalization persists no final evaluations',
    (
        SELECT count(*)
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_unsatisfied')
          AND finalized_evaluation
    ),
    0
);

SELECT sql_test.assert_true(
    'Caller-selected DENIED cannot replace computed APPROVED state',
    sql_test.phase4_step6_error(
        format(
            'SELECT * FROM approval.finalize_approval_request(%L::uuid,%L,%L::uuid)',
            sql_test.phase4_step6_id('request_mismatch')::text,
            'DENIED',
            sql_test.phase4_step6_id('identity_d')::text
        )
    ) = '23514:APPROVAL_FINAL_RESULT_MISMATCH'
);

SELECT sql_test.assert_true(
    'A final-result mismatch leaves the request PENDING',
    (
        SELECT status = 'PENDING' AND finalized_at IS NULL
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_mismatch')
    )
);

SELECT sql_test.assert_equal_bigint(
    'A final-result mismatch persists no final evaluations',
    (
        SELECT count(*)
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_mismatch')
          AND finalized_evaluation
    ),
    0
);

SELECT *
FROM approval.finalize_approval_request(
    sql_test.phase4_step6_id('request_denied'),
    'DENIED',
    sql_test.phase4_step6_id('identity_d')
);

SELECT sql_test.assert_true(
    'A current blocking denial finalizes the request as DENIED',
    (
        SELECT status = 'DENIED'
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_denied')
    )
);

SELECT sql_test.assert_true(
    'Denied finalization records the computed denial reason',
    (
        SELECT final_reason_code = 'APPROVAL_REQUEST_DENIED'
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_denied')
    )
);

SELECT sql_test.assert_true(
    'Denied finalization persists a blocking-deny stage outcome',
    EXISTS (
        SELECT 1
        FROM approval.approval_stage_evaluations
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_denied')
          AND finalized_evaluation
          AND result = 'DENIED'
          AND blocking_deny_present
    )
);

SELECT *
FROM approval.finalize_approval_request(
    sql_test.phase4_step6_id('request_cancelled'),
    'CANCELLED',
    sql_test.phase4_step6_id('identity_d')
);

SELECT sql_test.assert_true(
    'A current cancellation action finalizes the request as CANCELLED',
    (
        SELECT status = 'CANCELLED'
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_cancelled')
    )
);

SELECT sql_test.assert_true(
    'Cancelled finalization records the computed reason',
    (
        SELECT final_reason_code = 'APPROVAL_REQUEST_CANCELLED'
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_cancelled')
    )
);

SELECT *
FROM approval.finalize_approval_request(
    sql_test.phase4_step6_id('request_escalated'),
    'ESCALATED',
    sql_test.phase4_step6_id('identity_d')
);

SELECT sql_test.assert_true(
    'A current escalation action finalizes the request as ESCALATED',
    (
        SELECT status = 'ESCALATED'
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_escalated')
    )
);

SELECT sql_test.assert_true(
    'Escalated finalization records the computed reason',
    (
        SELECT final_reason_code = 'APPROVAL_REQUEST_ESCALATED'
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_escalated')
    )
);

SELECT *
FROM approval.finalize_approval_request(
    sql_test.phase4_step6_id('request_expired'),
    'EXPIRED',
    sql_test.phase4_step6_id('identity_d')
);

SELECT sql_test.assert_true(
    'An expired Approval Request finalizes as EXPIRED',
    (
        SELECT status = 'EXPIRED'
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_expired')
    )
);

SELECT sql_test.assert_true(
    'Expired finalization records the computed reason',
    (
        SELECT final_reason_code = 'APPROVAL_REQUEST_EXPIRED'
        FROM approval.approval_requests
        WHERE approval_request_id =
              sql_test.phase4_step6_id('request_expired')
    )
);

-- Decision linkage and later-use continuity: assertions 52-60.
SELECT sql_test.assert_true(
    'A freshly approved request is current for authorization',
    approval.approval_request_is_current_for_authorization(
        sql_test.phase4_step6_id('request_approved'),
        statement_timestamp()
    )
);

DO $decision_setup$
DECLARE
    v_request approval.approval_requests%ROWTYPE;
    v_now timestamptz := statement_timestamp();
BEGIN
    SELECT *
      INTO STRICT v_request
      FROM approval.approval_requests
     WHERE approval_request_id =
           sql_test.phase4_step6_id('request_approved');

    INSERT INTO decision.decision_records (
        decision_id,
        request_id,
        correlation_id,
        decision_class,
        requester_identity_id,
        requester_organization_id,
        approval_request_id,
        service_id,
        purpose_definition_id,
        operation_definition_id,
        operation_key,
        protected_target_type,
        protected_target_reference,
        governed_scope_id,
        classification_key,
        record_status,
        requested_at,
        evaluated_at,
        evaluator_name,
        evaluator_version,
        database_schema_version
    )
    VALUES
        (
            sql_test.phase4_step6_id('decision'),
            gen_random_uuid(),
            v_request.correlation_id,
            'PROTECTED_OPERATION',
            v_request.requester_identity_id,
            v_request.requester_organization_id,
            v_request.approval_request_id,
            v_request.service_id,
            v_request.purpose_definition_id,
            v_request.operation_definition_id,
            v_request.operation_key,
            v_request.protected_target_type,
            v_request.protected_target_reference,
            v_request.governed_scope_id,
            v_request.classification_key,
            'DRAFT',
            v_now,
            v_now,
            'sql_test.phase4_step6',
            '1',
            '083-step6'
        ),
        (
            sql_test.phase4_step6_id('bad_decision'),
            gen_random_uuid(),
            v_request.correlation_id,
            'PROTECTED_OPERATION',
            v_request.requester_identity_id,
            v_request.requester_organization_id,
            v_request.approval_request_id,
            v_request.service_id,
            v_request.purpose_definition_id,
            v_request.operation_definition_id,
            v_request.operation_key,
            v_request.protected_target_type,
            v_request.protected_target_reference || '-mismatch',
            v_request.governed_scope_id,
            v_request.classification_key,
            'DRAFT',
            v_now,
            v_now,
            'sql_test.phase4_step6',
            '1',
            '083-step6'
        );

    INSERT INTO decision.evaluation_records (
        evaluation_id,
        decision_id,
        evaluation_order,
        evaluation_key,
        required,
        result,
        reason_code,
        evaluated_at
    )
    VALUES
        (
            sql_test.phase4_step6_id('evaluation'),
            sql_test.phase4_step6_id('decision'),
            1,
            'APPROVAL',
            true,
            'PASS',
            'APPROVAL_STAGE_SATISFIED',
            v_now
        ),
        (
            sql_test.phase4_step6_id('bad_evaluation'),
            sql_test.phase4_step6_id('bad_decision'),
            1,
            'APPROVAL',
            true,
            'PASS',
            'APPROVAL_STAGE_SATISFIED',
            v_now
        );
END;
$decision_setup$;

SELECT sql_test.assert_true(
    'A Decision evaluation links to the exact first finalized stage',
    decision.link_approval_stage_evaluation(
        sql_test.phase4_step6_id('decision'),
        sql_test.phase4_step6_id('evaluation'),
        (
            SELECT approval_stage_evaluation_id
            FROM approval.approval_stage_evaluations
            WHERE approval_request_id =
                  sql_test.phase4_step6_id('request_approved')
              AND approval_policy_stage_id =
                  sql_test.phase4_step6_id('stage_a')
              AND finalized_evaluation
        )
    )
);

SELECT sql_test.assert_true(
    'A Decision evaluation links to the exact second finalized stage',
    decision.link_approval_stage_evaluation(
        sql_test.phase4_step6_id('decision'),
        sql_test.phase4_step6_id('evaluation'),
        (
            SELECT approval_stage_evaluation_id
            FROM approval.approval_stage_evaluations
            WHERE approval_request_id =
                  sql_test.phase4_step6_id('request_approved')
              AND approval_policy_stage_id =
                  sql_test.phase4_step6_id('stage_b')
              AND finalized_evaluation
        )
    )
);

SELECT sql_test.assert_equal_bigint(
    'The Decision evaluation cites both finalized policy stages',
    (
        SELECT count(*)
        FROM decision.approval_stage_evaluation_links
        WHERE decision_id = sql_test.phase4_step6_id('decision')
          AND evaluation_id = sql_test.phase4_step6_id('evaluation')
    ),
    2
);

SELECT sql_test.assert_true(
    'A Decision with mismatched protected context cannot cite approval',
    sql_test.phase4_step6_error(
        format(
            'SELECT decision.link_approval_stage_evaluation(%L::uuid,%L::uuid,%L::uuid)',
            sql_test.phase4_step6_id('bad_decision')::text,
            sql_test.phase4_step6_id('bad_evaluation')::text,
            (
                SELECT approval_stage_evaluation_id::text
                FROM approval.approval_stage_evaluations
                WHERE approval_request_id =
                      sql_test.phase4_step6_id('request_approved')
                  AND approval_policy_stage_id =
                      sql_test.phase4_step6_id('stage_a')
                  AND finalized_evaluation
            )
        )
    ) = '28000:DECISION_APPROVAL_CONTEXT_MISMATCH'
);

SELECT sql_test.assert_raises(
    'Decision approval-stage links reject UPDATE',
    format(
        'UPDATE decision.approval_stage_evaluation_links SET linked_at = clock_timestamp() WHERE decision_id = %L::uuid',
        sql_test.phase4_step6_id('decision')::text
    ),
    '55000'
);

SELECT sql_test.assert_raises(
    'A second finalized evaluation for the same request stage is rejected',
    format(
        'SELECT * FROM approval.evaluate_approval_stage(%L::uuid,%L::uuid,statement_timestamp(),true)',
        sql_test.phase4_step6_id('request_approved')::text,
        sql_test.phase4_step6_id('stage_a')::text
    ),
    '23505'
);

UPDATE access_control.authority_grants
   SET status = 'SUSPENDED'
 WHERE authority_grant_id = sql_test.phase4_step6_id('grant_a_a');

SELECT sql_test.assert_false(
    'Approval continuity fails closed after a counted Authority Grant is suspended',
    approval.approval_request_is_current_for_authorization(
        sql_test.phase4_step6_id('request_approved'),
        statement_timestamp()
    )
);

SELECT sql_test.assert_equal_bigint(
    'Approval-unrelated Authorization Leases remain outside Step 6 continuity binding',
    (
        SELECT count(*)
        FROM access_control.authorization_leases AS lease
        WHERE lease.approval_continuity_required
          AND NOT EXISTS (
                SELECT 1
                FROM decision.approval_stage_evaluation_links AS link
                WHERE link.decision_id = lease.issuing_decision_id
          )
    ),
    0
);
