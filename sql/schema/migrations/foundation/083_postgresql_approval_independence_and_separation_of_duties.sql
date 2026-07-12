-- ============================================================================
-- Migration: 083_postgresql_approval_independence_and_separation_of_duties.sql
-- Title: PostgreSQL approval independence and separation of duties structure
-- Layer: Platform Foundation
-- Status: PHASE 4 STEP 4 INDEPENDENCE ENFORCEMENT CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '10min';
SET LOCAL idle_in_transaction_session_timeout = '10min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('platform-foundation-migrations')
);

DO $dependency_check$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id =
            '081_postgresql_authorization_decision_and_lease_issuance'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE =
                    'Required migration 081_postgresql_authorization_decision_and_lease_issuance is not registered';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id =
            '082_data_classification_and_governance'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE =
                    'Required migration 082_data_classification_and_governance is not registered';
    END IF;
END;
$dependency_check$;

-- --------------------------------------------------------------------------
-- Approval Policy Stage structural requirements
-- --------------------------------------------------------------------------

ALTER TABLE approval.approval_policy_stages
    ADD COLUMN required_authority_definition_id uuid
        REFERENCES access_control.authority_definitions(
            authority_definition_id
        ),
    ADD COLUMN requester_approval_allowed boolean NOT NULL DEFAULT false,
    ADD COLUMN affected_identity_approval_allowed boolean NOT NULL DEFAULT false,
    ADD COLUMN action_reuse_allowed boolean NOT NULL DEFAULT false,
    ADD COLUMN delegated_authority_allowed boolean NOT NULL DEFAULT false,
    ADD COLUMN maximum_delegation_depth integer,
    ADD COLUMN action_validity interval,
    ADD COLUMN authority_origin_independence_required boolean
        NOT NULL DEFAULT false,
    ADD COLUMN incompatible_authority_set_id uuid
        REFERENCES access_control.incompatible_authority_sets(
            incompatible_authority_set_id
        ),
    ADD COLUMN incompatible_authority_mode text,
    ADD COLUMN blocking_deny boolean NOT NULL DEFAULT true,
    ADD CONSTRAINT approval_policy_stages_delegation_depth_ck
        CHECK (
            (
                delegated_authority_allowed
                AND maximum_delegation_depth IS NOT NULL
                AND maximum_delegation_depth > 0
            )
            OR
            (
                NOT delegated_authority_allowed
                AND maximum_delegation_depth IS NULL
            )
        ),
    ADD CONSTRAINT approval_policy_stages_action_validity_ck
        CHECK (
            action_validity IS NULL
            OR action_validity > interval '0 seconds'
        ),
    ADD CONSTRAINT approval_policy_stages_incompatible_mode_ck
        CHECK (
            incompatible_authority_mode IS NULL
            OR incompatible_authority_mode IN (
                'JOINT_EXERCISE',
                'CONCURRENT_HOLDING',
                'CHAIN_PARTICIPATION'
            )
        ),
    ADD CONSTRAINT approval_policy_stages_incompatible_pair_ck
        CHECK (
            (
                incompatible_authority_set_id IS NULL
                AND incompatible_authority_mode IS NULL
            )
            OR
            (
                incompatible_authority_set_id IS NOT NULL
                AND incompatible_authority_mode IS NOT NULL
            )
        );

COMMENT ON COLUMN
    approval.approval_policy_stages.required_authority_definition_id IS
    'Typed Authority Definition required for an actor to satisfy this stage. Controlled eligibility is enforced by approval.record_approval_action.';

COMMENT ON COLUMN
    approval.approval_policy_stages.requester_approval_allowed IS
    'Explicit stage policy for requester approval. False is the default; controlled Approval Action recording enforces the policy together with approval_policies.self_approval_allowed.';

COMMENT ON COLUMN
    approval.approval_policy_stages.affected_identity_approval_allowed IS
    'Explicit stage policy for directly affected identity approval. False is the default and controlled Approval Action recording enforces it.';

-- --------------------------------------------------------------------------
-- Approval Request context, dependency, and finalization structure
-- --------------------------------------------------------------------------

ALTER TABLE approval.approval_requests
    ADD COLUMN directly_affected_identity_id uuid
        REFERENCES identity.identities(identity_id),
    ADD COLUMN approval_chain_id uuid NOT NULL DEFAULT gen_random_uuid(),
    ADD COLUMN finalized_at timestamptz,
    ADD COLUMN finalized_by_identity_id uuid
        REFERENCES identity.identities(identity_id),
    ADD COLUMN final_reason_code text,
    ADD CONSTRAINT approval_requests_final_reason_code_ck
        CHECK (
            final_reason_code IS NULL
            OR final_reason_code ~ '^[A-Z][A-Z0-9_]*$'
        );

COMMENT ON COLUMN
    approval.approval_requests.directly_affected_identity_id IS
    'Typed identity whose access, authority, status, account, or protected standing is directly changed or materially benefited when an identity subject exists.';

COMMENT ON COLUMN approval.approval_requests.approval_chain_id IS
    'Stable explicit chain identifier used for bounded approval dependency, reciprocal-participation, duty, and later authorization evaluation.';

CREATE TABLE approval.approval_request_dependencies (
    approval_request_dependency_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_request_id uuid NOT NULL
        REFERENCES approval.approval_requests(approval_request_id),
    depends_on_approval_request_id uuid NOT NULL
        REFERENCES approval.approval_requests(approval_request_id),
    dependency_type text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    created_by_identity_id uuid
        REFERENCES identity.identities(identity_id),
    reason_code text,
    CONSTRAINT approval_request_dependencies_not_self_ck
        CHECK (approval_request_id <> depends_on_approval_request_id),
    CONSTRAINT approval_request_dependencies_type_ck
        CHECK (
            dependency_type IN (
                'PREREQUISITE',
                'RECIPROCAL_REVIEW',
                'SHARED_APPROVAL_CHAIN',
                'SUPERSEDES'
            )
        ),
    CONSTRAINT approval_request_dependencies_reason_code_ck
        CHECK (
            reason_code IS NULL
            OR reason_code ~ '^[A-Z][A-Z0-9_]*$'
        ),
    UNIQUE (
        approval_request_id,
        depends_on_approval_request_id,
        dependency_type
    )
);

COMMENT ON TABLE approval.approval_request_dependencies IS
    'Explicit bounded Approval Request relationships used by later circular, reciprocal, prerequisite, and chain-participation evaluation. No relationship is inferred from time or free-form text.';

-- --------------------------------------------------------------------------
-- Approval Action Record actor, authority, session, and lineage structure
-- --------------------------------------------------------------------------

ALTER TABLE approval.approval_actions
    ADD COLUMN effective_actor_identity_id uuid
        GENERATED ALWAYS AS (acting_identity_id) STORED,
    ADD COLUMN acting_session_id uuid
        REFERENCES access_control.sessions(session_id),
    ADD COLUMN authority_grant_id uuid
        REFERENCES access_control.authority_grants(authority_grant_id),
    ADD COLUMN prior_approval_action_id uuid
        REFERENCES approval.approval_actions(approval_action_id),
    ADD COLUMN action_reason_code text,
    ADD CONSTRAINT approval_actions_prior_not_self_ck
        CHECK (
            prior_approval_action_id IS NULL
            OR prior_approval_action_id <> approval_action_id
        ),
    ADD CONSTRAINT approval_actions_reason_code_ck
        CHECK (
            action_reason_code IS NULL
            OR action_reason_code ~ '^[A-Z][A-Z0-9_]*$'
        );

COMMENT ON COLUMN
    approval.approval_actions.effective_actor_identity_id IS
    'Initial Phase 4 effective actor identifier. It is generated from acting_identity_id so multiple sessions, devices, organizations, accounts, or Authority Grants do not create distinct actors.';

COMMENT ON COLUMN approval.approval_actions.prior_approval_action_id IS
    'Typed lineage to the earlier Approval Action Record referenced by a later withdrawal, correction, or supersession action. Step 3 controls action-specific requirements.';

-- --------------------------------------------------------------------------
-- Duty catalog and policy-prohibited duty combinations
-- --------------------------------------------------------------------------

CREATE TABLE approval.approval_duty_definitions (
    duty_key text PRIMARY KEY,
    title text NOT NULL,
    description text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT approval_duty_definitions_key_ck
        CHECK (duty_key ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT approval_duty_definitions_status_ck
        CHECK (status IN ('DRAFT', 'ACTIVE', 'SUSPENDED', 'RETIRED'))
);

INSERT INTO approval.approval_duty_definitions (
    duty_key,
    title,
    description
)
VALUES
    ('REQUEST', 'Request', 'Initiate the exact Approval Request.'),
    ('APPROVE', 'Approve', 'Record a counted approval action.'),
    ('GRANT_AUTHORITY', 'Grant authority', 'Create or activate an Authority Grant.'),
    ('EXECUTE', 'Execute', 'Perform the protected operation.'),
    ('FINALIZE_APPROVAL', 'Finalize approval', 'Finalize the Approval Request.'),
    ('ADMINISTER_POLICY', 'Administer policy', 'Create or administer the governing policy.'),
    ('AUDIT', 'Audit', 'Perform an independent audit duty.'),
    ('ACCEPT_RISK', 'Accept risk', 'Accept a governed risk.'),
    ('AUTHORIZE_EXCEPTION', 'Authorize exception', 'Authorize a governed exception.');

CREATE TABLE approval.approval_policy_prohibited_duty_combinations (
    approval_policy_prohibited_duty_combination_id uuid
        PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_policy_id uuid NOT NULL
        REFERENCES approval.approval_policies(approval_policy_id),
    first_duty_key text NOT NULL
        REFERENCES approval.approval_duty_definitions(duty_key),
    second_duty_key text NOT NULL
        REFERENCES approval.approval_duty_definitions(duty_key),
    enforcement_scope text NOT NULL DEFAULT 'REQUEST',
    status text NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT approval_policy_prohibited_duties_distinct_ck
        CHECK (first_duty_key <> second_duty_key),
    CONSTRAINT approval_policy_prohibited_duties_order_ck
        CHECK (first_duty_key < second_duty_key),
    CONSTRAINT approval_policy_prohibited_duties_scope_ck
        CHECK (
            enforcement_scope IN (
                'STAGE',
                'REQUEST',
                'APPROVAL_CHAIN',
                'AUTHORIZATION_CHAIN'
            )
        ),
    CONSTRAINT approval_policy_prohibited_duties_status_ck
        CHECK (status IN ('DRAFT', 'ACTIVE', 'SUSPENDED', 'RETIRED')),
    UNIQUE (
        approval_policy_id,
        first_duty_key,
        second_duty_key,
        enforcement_scope
    )
);

CREATE TABLE approval.approval_action_duties (
    approval_action_id uuid NOT NULL
        REFERENCES approval.approval_actions(approval_action_id),
    duty_key text NOT NULL
        REFERENCES approval.approval_duty_definitions(duty_key),
    recorded_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    PRIMARY KEY (approval_action_id, duty_key)
);

COMMENT ON TABLE approval.approval_action_duties IS
    'Typed duties actually exercised by an Approval Action Record. Job titles, groups, roles, or free-form descriptions do not substitute for this relationship.';

-- --------------------------------------------------------------------------
-- Incompatible Authority Set policy structure
-- --------------------------------------------------------------------------

ALTER TABLE access_control.incompatible_authority_sets
    ADD COLUMN default_enforcement_mode text
        NOT NULL DEFAULT 'JOINT_EXERCISE',
    ADD COLUMN include_delegated_grants boolean NOT NULL DEFAULT true,
    ADD CONSTRAINT incompatible_authority_sets_mode_ck
        CHECK (
            default_enforcement_mode IN (
                'JOINT_EXERCISE',
                'CONCURRENT_HOLDING',
                'CHAIN_PARTICIPATION'
            )
        );

-- --------------------------------------------------------------------------
-- Persisted stage evaluation structure
-- --------------------------------------------------------------------------

CREATE TABLE approval.approval_stage_evaluations (
    approval_stage_evaluation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_request_id uuid NOT NULL
        REFERENCES approval.approval_requests(approval_request_id),
    approval_policy_stage_id uuid NOT NULL
        REFERENCES approval.approval_policy_stages(approval_policy_stage_id),
    evaluated_at timestamptz NOT NULL,
    result text NOT NULL,
    reason_code text NOT NULL,
    required_approvals integer NOT NULL,
    counted_approvals integer NOT NULL,
    distinct_effective_actors integer NOT NULL,
    distinct_organizations integer NOT NULL,
    blocking_deny_present boolean NOT NULL DEFAULT false,
    finalized_evaluation boolean NOT NULL DEFAULT false,
    CONSTRAINT approval_stage_evaluations_result_ck
        CHECK (
            result IN (
                'SATISFIED',
                'UNSATISFIED',
                'DENIED',
                'NOT_EVALUATED'
            )
        ),
    CONSTRAINT approval_stage_evaluations_reason_code_ck
        CHECK (reason_code ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT approval_stage_evaluations_counts_ck
        CHECK (
            required_approvals > 0
            AND counted_approvals >= 0
            AND distinct_effective_actors >= 0
            AND distinct_organizations >= 0
            AND distinct_effective_actors <= counted_approvals
            AND distinct_organizations <= counted_approvals
        ),
    UNIQUE (
        approval_stage_evaluation_id,
        approval_request_id,
        approval_policy_stage_id
    )
);

CREATE TABLE approval.approval_stage_evaluation_actions (
    approval_stage_evaluation_id uuid NOT NULL
        REFERENCES approval.approval_stage_evaluations(
            approval_stage_evaluation_id
        ),
    approval_action_id uuid NOT NULL
        REFERENCES approval.approval_actions(approval_action_id),
    authority_grant_id uuid
        REFERENCES access_control.authority_grants(authority_grant_id),
    counted boolean NOT NULL,
    exclusion_reason_code text,
    CONSTRAINT approval_stage_evaluation_actions_exclusion_ck
        CHECK (
            (
                counted
                AND exclusion_reason_code IS NULL
            )
            OR
            (
                NOT counted
                AND exclusion_reason_code ~ '^[A-Z][A-Z0-9_]*$'
            )
        ),
    PRIMARY KEY (
        approval_stage_evaluation_id,
        approval_action_id
    )
);

COMMENT ON TABLE approval.approval_stage_evaluations IS
    'Persisted approval-stage outcomes captured at one evaluation time. The row is not an Approval Action Record, Supporting Record, Assurance Artifact, or generic evidence object.';

COMMENT ON TABLE approval.approval_stage_evaluation_actions IS
    'Exact Approval Action Records and Authority Grants considered by one persisted stage evaluation, including explicit reasons for non-counted actions.';

-- --------------------------------------------------------------------------
-- Evaluation indexes
-- --------------------------------------------------------------------------

CREATE INDEX approval_policy_stages_phase4_policy_idx
    ON approval.approval_policy_stages(
        approval_policy_id,
        stage_order,
        required_authority_definition_id,
        incompatible_authority_set_id
    );

CREATE INDEX approval_requests_phase4_context_idx
    ON approval.approval_requests(
        approval_chain_id,
        directly_affected_identity_id,
        status,
        expires_at,
        finalized_at
    );

CREATE INDEX approval_request_dependencies_request_idx
    ON approval.approval_request_dependencies(
        approval_request_id,
        dependency_type,
        depends_on_approval_request_id
    );

CREATE INDEX approval_request_dependencies_reverse_idx
    ON approval.approval_request_dependencies(
        depends_on_approval_request_id,
        dependency_type,
        approval_request_id
    );

CREATE INDEX approval_actions_phase4_actor_idx
    ON approval.approval_actions(
        approval_request_id,
        approval_policy_stage_id,
        effective_actor_identity_id,
        action_type,
        action_at
    );

CREATE INDEX approval_actions_phase4_organization_idx
    ON approval.approval_actions(
        approval_request_id,
        approval_policy_stage_id,
        acting_organization_id,
        action_type,
        action_at
    );

CREATE INDEX approval_actions_phase4_authority_idx
    ON approval.approval_actions(
        authority_grant_id,
        acting_session_id,
        action_at
    )
    WHERE authority_grant_id IS NOT NULL;

CREATE INDEX approval_stage_evaluations_request_idx
    ON approval.approval_stage_evaluations(
        approval_request_id,
        approval_policy_stage_id,
        evaluated_at,
        finalized_evaluation
    );

CREATE INDEX approval_stage_evaluation_actions_action_idx
    ON approval.approval_stage_evaluation_actions(
        approval_action_id,
        approval_stage_evaluation_id,
        counted
    );

-- --------------------------------------------------------------------------
-- Controlled Approval Action recording
-- --------------------------------------------------------------------------

CREATE FUNCTION approval.prevent_approval_action_record_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, approval
AS $function$
BEGIN
    RAISE EXCEPTION
        USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'APPROVAL_ACTION_RECORD_IMMUTABLE';
END;
$function$;

COMMENT ON FUNCTION approval.prevent_approval_action_record_mutation() IS
    'Rejects UPDATE and DELETE against Approval Action Records and their typed duty links. Corrections, withdrawals, and supersession use new Approval Action Records.';

CREATE TRIGGER approval_actions_append_only_guard
BEFORE UPDATE OR DELETE
ON approval.approval_actions
FOR EACH ROW
EXECUTE FUNCTION approval.prevent_approval_action_record_mutation();

CREATE TRIGGER approval_action_duties_append_only_guard
BEFORE UPDATE OR DELETE
ON approval.approval_action_duties
FOR EACH ROW
EXECUTE FUNCTION approval.prevent_approval_action_record_mutation();

CREATE FUNCTION approval.record_approval_action(
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
RETURNS TABLE (
    recorded_approval_action_id uuid,
    outcome text,
    reason_code text,
    recorded_at timestamptz
)
LANGUAGE plpgsql
SET search_path = pg_catalog, approval, access_control
AS $function$
DECLARE
    v_now timestamptz := statement_timestamp();
    v_request approval.approval_requests%ROWTYPE;
    v_policy approval.approval_policies%ROWTYPE;
    v_stage approval.approval_policy_stages%ROWTYPE;
    v_identity identity.identities%ROWTYPE;
    v_session access_control.sessions%ROWTYPE;
    v_authority_grant access_control.authority_grants%ROWTYPE;
    v_prior_action approval.approval_actions%ROWTYPE;
    v_environment_key text;
    v_action_id uuid := gen_random_uuid();
    v_requires_prior boolean;
BEGIN
    IF p_approval_request_id IS NULL
       OR p_approval_policy_stage_id IS NULL
       OR p_acting_identity_id IS NULL
       OR p_action_type IS NULL
       OR p_action_reason_code IS NULL
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'APPROVAL_ACTION_PARAMETERS_REQUIRED';
    END IF;

    IF p_action_type NOT IN (
        'APPROVE',
        'DENY',
        'ABSTAIN',
        'WITHDRAW_APPROVAL',
        'CANCEL_REQUEST',
        'ESCALATE',
        'CORRECT',
        'SUPERSEDE'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'APPROVAL_ACTION_TYPE_INVALID';
    END IF;

    IF p_action_reason_code !~ '^[A-Z][A-Z0-9_]*$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'APPROVAL_ACTION_REASON_CODE_INVALID';
    END IF;

    IF p_action_type IN (
        'DENY',
        'WITHDRAW_APPROVAL',
        'CANCEL_REQUEST',
        'ESCALATE',
        'CORRECT',
        'SUPERSEDE'
    )
    AND NULLIF(btrim(p_action_reason), '') IS NULL
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'APPROVAL_ACTION_REASON_REQUIRED';
    END IF;

    SELECT request_record.*
    INTO v_request
    FROM approval.approval_requests AS request_record
    WHERE request_record.approval_request_id = p_approval_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'APPROVAL_REQUEST_NOT_FOUND';
    END IF;

    IF v_request.finalized_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'APPROVAL_REQUEST_FINALIZED';
    END IF;

    IF v_request.status <> 'PENDING' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'APPROVAL_REQUEST_NOT_PENDING';
    END IF;

    IF v_request.expires_at IS NOT NULL
       AND v_now >= v_request.expires_at
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVAL_REQUEST_EXPIRED';
    END IF;

    SELECT policy_record.*
    INTO STRICT v_policy
    FROM approval.approval_policies AS policy_record
    WHERE policy_record.approval_policy_id = v_request.approval_policy_id;

    IF v_policy.status <> 'ACTIVE'
       OR v_policy.valid_from > v_now
       OR (
            v_policy.valid_until IS NOT NULL
            AND v_now >= v_policy.valid_until
       )
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVAL_POLICY_NOT_ACTIVE';
    END IF;

    SELECT stage_record.*
    INTO v_stage
    FROM approval.approval_policy_stages AS stage_record
    WHERE stage_record.approval_policy_stage_id =
              p_approval_policy_stage_id
      AND stage_record.approval_policy_id = v_request.approval_policy_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVAL_STAGE_NOT_FOUND';
    END IF;

    SELECT identity_record.*
    INTO v_identity
    FROM identity.identities AS identity_record
    WHERE identity_record.identity_id = p_acting_identity_id;

    IF NOT FOUND
       OR v_identity.status <> 'ACTIVE'
       OR v_identity.valid_from > v_now
       OR (
            v_identity.valid_until IS NOT NULL
            AND v_now >= v_identity.valid_until
       )
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVER_NOT_ELIGIBLE';
    END IF;

    IF p_acting_session_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVER_SESSION_REQUIRED';
    END IF;

    SELECT session_record.*
    INTO v_session
    FROM access_control.sessions AS session_record
    WHERE session_record.session_id = p_acting_session_id
    FOR KEY SHARE;

    IF NOT FOUND
       OR v_session.identity_id <> p_acting_identity_id
       OR v_session.organization_id IS DISTINCT FROM
          p_acting_organization_id
       OR v_session.service_id IS DISTINCT FROM v_request.service_id
       OR v_session.status <> 'ACTIVE'
       OR v_session.authenticated_at > v_now
       OR v_now >= v_session.expires_at
       OR (
            v_session.inactivity_timeout IS NOT NULL
            AND v_now >=
                COALESCE(
                    v_session.last_activity_at,
                    v_session.authenticated_at
                ) + v_session.inactivity_timeout
       )
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVER_SESSION_REQUIRED';
    END IF;

    SELECT provider_record.environment_key
    INTO v_environment_key
    FROM trust.trust_providers AS provider_record
    WHERE provider_record.trust_provider_id =
          v_session.trust_provider_id;

    IF v_environment_key IS NULL
       OR NOT access_control.session_context_is_locally_usable(
            v_session.identity_id,
            v_session.device_id,
            v_session.trust_provider_id,
            v_session.service_id,
            v_session.organization_id,
            v_environment_key,
            v_now
       )
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVER_SESSION_REQUIRED';
    END IF;

    IF v_stage.required_authority_definition_id IS NULL
       OR p_authority_grant_id IS NULL
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVER_AUTHORITY_REQUIRED';
    END IF;

    SELECT grant_record.*
    INTO v_authority_grant
    FROM access_control.authority_grants AS grant_record
    WHERE grant_record.authority_grant_id = p_authority_grant_id
    FOR KEY SHARE;

    IF NOT FOUND
       OR v_authority_grant.identity_id <> p_acting_identity_id
       OR v_authority_grant.authority_definition_id <>
          v_stage.required_authority_definition_id
       OR v_authority_grant.status <> 'ACTIVE'
       OR v_authority_grant.valid_from > v_now
       OR (
            v_authority_grant.valid_until IS NOT NULL
            AND v_now >= v_authority_grant.valid_until
       )
       OR NOT (
            v_authority_grant.service_id IS NULL
            OR v_authority_grant.service_id = v_request.service_id
       )
       OR NOT (
            v_authority_grant.purpose_definition_id IS NULL
            OR v_authority_grant.purpose_definition_id =
               v_request.purpose_definition_id
       )
       OR NOT (
            v_authority_grant.operation_definition_id IS NULL
            OR v_authority_grant.operation_definition_id =
               v_request.operation_definition_id
       )
       OR NOT (
            v_authority_grant.organization_id IS NULL
            OR v_authority_grant.organization_id IS NOT DISTINCT FROM
               p_acting_organization_id
       )
       OR v_authority_grant.scope_reference IS NOT NULL
       OR NOT (
            v_authority_grant.applies_to_all_governed_scopes
            OR v_authority_grant.governed_scope_id IS NOT DISTINCT FROM
               v_request.governed_scope_id
       )
       OR NOT (
            v_authority_grant.applies_to_all_targets
            OR (
                v_authority_grant.protected_target_type
                    IS NOT DISTINCT FROM
                    v_request.protected_target_type
                AND v_authority_grant.protected_target_reference
                    IS NOT DISTINCT FROM
                    v_request.protected_target_reference
            )
       )
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVER_AUTHORITY_NOT_CURRENT';
    END IF;

    v_requires_prior := p_action_type IN (
        'WITHDRAW_APPROVAL',
        'CORRECT',
        'SUPERSEDE'
    );

    IF v_requires_prior AND p_prior_approval_action_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'APPROVAL_ACTION_PRIOR_REQUIRED';
    END IF;

    IF NOT v_requires_prior
       AND p_prior_approval_action_id IS NOT NULL
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'APPROVAL_ACTION_PRIOR_NOT_ALLOWED';
    END IF;

    -- ------------------------------------------------------------------
    -- Phase 4 Step 4 independence enforcement
    -- ------------------------------------------------------------------
    -- Independence is evaluated only for new APPROVE actions. Withdrawal,
    -- correction, and supersession preserve typed lineage and may make an
    -- earlier approval non-current without re-exercising approval authority.
    IF p_action_type = 'APPROVE' THEN
        IF p_acting_identity_id = v_request.requester_identity_id
           AND NOT (
                v_policy.self_approval_allowed
                AND v_stage.requester_approval_allowed
           )
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'SELF_APPROVAL_PROHIBITED';
        END IF;

        IF v_request.directly_affected_identity_id IS NOT NULL
           AND p_acting_identity_id =
               v_request.directly_affected_identity_id
           AND NOT v_stage.affected_identity_approval_allowed
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'AFFECTED_IDENTITY_APPROVAL_PROHIBITED';
        END IF;

        IF v_stage.independent_identity_required
           AND EXISTS (
                SELECT 1
                FROM approval.approval_actions AS prior_approval
                WHERE prior_approval.approval_request_id =
                      p_approval_request_id
                  AND prior_approval.approval_policy_stage_id =
                      p_approval_policy_stage_id
                  AND prior_approval.effective_actor_identity_id =
                      p_acting_identity_id
                  AND prior_approval.action_type = 'APPROVE'
                  AND NOT EXISTS (
                        SELECT 1
                        FROM approval.approval_actions AS later_action
                        WHERE later_action.prior_approval_action_id =
                              prior_approval.approval_action_id
                          AND later_action.action_type IN (
                              'WITHDRAW_APPROVAL',
                              'CORRECT',
                              'SUPERSEDE'
                          )
                  )
           )
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'DUPLICATE_EFFECTIVE_ACTOR';
        END IF;

        IF v_stage.independent_organization_required THEN
            IF p_acting_organization_id IS NULL
               OR EXISTS (
                    SELECT 1
                    FROM approval.approval_actions AS prior_approval
                    WHERE prior_approval.approval_request_id =
                          p_approval_request_id
                      AND prior_approval.approval_policy_stage_id =
                          p_approval_policy_stage_id
                      AND prior_approval.acting_organization_id =
                          p_acting_organization_id
                      AND prior_approval.action_type = 'APPROVE'
                      AND NOT EXISTS (
                            SELECT 1
                            FROM approval.approval_actions AS later_action
                            WHERE later_action.prior_approval_action_id =
                                  prior_approval.approval_action_id
                              AND later_action.action_type IN (
                                  'WITHDRAW_APPROVAL',
                                  'CORRECT',
                                  'SUPERSEDE'
                              )
                      )
               )
            THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = 'invalid_authorization_specification',
                        MESSAGE = 'INDEPENDENT_ORGANIZATION_REQUIRED';
            END IF;
        END IF;

        IF v_stage.authority_origin_independence_required THEN
            IF v_authority_grant.granted_by_identity_id IS NULL
               OR v_authority_grant.granted_by_identity_id =
                  p_acting_identity_id
               OR v_authority_grant.granted_by_identity_id =
                  v_request.requester_identity_id
               OR (
                    v_request.directly_affected_identity_id IS NOT NULL
                    AND v_authority_grant.granted_by_identity_id =
                        v_request.directly_affected_identity_id
               )
               OR (
                    v_authority_grant.approval_request_id IS NOT NULL
                    AND EXISTS (
                        SELECT 1
                        FROM approval.approval_requests AS origin_request
                        WHERE origin_request.approval_request_id =
                              v_authority_grant.approval_request_id
                          AND (
                              origin_request.approval_request_id =
                                  p_approval_request_id
                              OR origin_request.approval_chain_id =
                                  v_request.approval_chain_id
                              OR origin_request.requester_identity_id IN (
                                  p_acting_identity_id,
                                  v_request.requester_identity_id
                              )
                              OR (
                                  v_request.directly_affected_identity_id
                                      IS NOT NULL
                                  AND origin_request.requester_identity_id =
                                      v_request.directly_affected_identity_id
                              )
                              OR origin_request.directly_affected_identity_id
                                  IN (
                                      p_acting_identity_id,
                                      v_request.requester_identity_id
                                  )
                              OR (
                                  v_request.directly_affected_identity_id
                                      IS NOT NULL
                                  AND origin_request.directly_affected_identity_id =
                                      v_request.directly_affected_identity_id
                              )
                              OR EXISTS (
                                  SELECT 1
                                  FROM approval.approval_request_dependencies AS dep
                                  WHERE (
                                      dep.approval_request_id =
                                          p_approval_request_id
                                      AND dep.depends_on_approval_request_id =
                                          origin_request.approval_request_id
                                  )
                                  OR (
                                      dep.approval_request_id =
                                          origin_request.approval_request_id
                                      AND dep.depends_on_approval_request_id =
                                          p_approval_request_id
                                  )
                              )
                          )
                    )
               )
            THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = 'invalid_authorization_specification',
                        MESSAGE = 'AUTHORITY_ORIGIN_NOT_INDEPENDENT';
            END IF;
        END IF;

        IF EXISTS (
            SELECT 1
            FROM approval.approval_requests AS linked_request
            WHERE linked_request.approval_request_id <>
                  p_approval_request_id
              AND (
                  linked_request.requester_identity_id =
                      p_acting_identity_id
                  OR linked_request.directly_affected_identity_id =
                      p_acting_identity_id
              )
              AND (
                  linked_request.approval_chain_id =
                      v_request.approval_chain_id
                  OR EXISTS (
                      SELECT 1
                      FROM approval.approval_request_dependencies AS dep
                      WHERE dep.dependency_type IN (
                                'RECIPROCAL_REVIEW',
                                'SHARED_APPROVAL_CHAIN'
                            )
                        AND (
                            (
                                dep.approval_request_id =
                                    p_approval_request_id
                                AND dep.depends_on_approval_request_id =
                                    linked_request.approval_request_id
                            )
                            OR
                            (
                                dep.approval_request_id =
                                    linked_request.approval_request_id
                                AND dep.depends_on_approval_request_id =
                                    p_approval_request_id
                            )
                        )
                  )
              )
              AND EXISTS (
                  SELECT 1
                  FROM approval.approval_actions AS reciprocal_approval
                  WHERE reciprocal_approval.approval_request_id =
                        linked_request.approval_request_id
                    AND reciprocal_approval.action_type = 'APPROVE'
                    AND (
                        reciprocal_approval.effective_actor_identity_id =
                            v_request.requester_identity_id
                        OR (
                            v_request.directly_affected_identity_id
                                IS NOT NULL
                            AND reciprocal_approval.effective_actor_identity_id =
                                v_request.directly_affected_identity_id
                        )
                    )
                    AND NOT EXISTS (
                        SELECT 1
                        FROM approval.approval_actions AS later_action
                        WHERE later_action.prior_approval_action_id =
                              reciprocal_approval.approval_action_id
                          AND later_action.action_type IN (
                              'WITHDRAW_APPROVAL',
                              'CORRECT',
                              'SUPERSEDE'
                          )
                    )
              )
        ) THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'CIRCULAR_APPROVAL_PROHIBITED';
        END IF;
    END IF;

    IF v_requires_prior THEN
        SELECT action_record.*
        INTO v_prior_action
        FROM approval.approval_actions AS action_record
        WHERE action_record.approval_action_id =
              p_prior_approval_action_id
        FOR UPDATE;

        IF NOT FOUND
           OR v_prior_action.approval_request_id <>
              p_approval_request_id
           OR v_prior_action.approval_policy_stage_id <>
              p_approval_policy_stage_id
           OR v_prior_action.effective_actor_identity_id <>
              p_acting_identity_id
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'APPROVAL_ACTION_NOT_CURRENT';
        END IF;

        IF p_action_type = 'WITHDRAW_APPROVAL'
           AND v_prior_action.action_type <> 'APPROVE'
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'APPROVAL_WITHDRAWAL_NOT_ALLOWED';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM approval.approval_actions AS later_action
            WHERE later_action.prior_approval_action_id =
                  p_prior_approval_action_id
              AND later_action.action_type IN (
                  'WITHDRAW_APPROVAL',
                  'CORRECT',
                  'SUPERSEDE'
              )
        ) THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'APPROVAL_ACTION_NOT_CURRENT';
        END IF;
    END IF;

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
        v_action_id,
        p_approval_request_id,
        p_approval_policy_stage_id,
        p_acting_identity_id,
        p_acting_organization_id,
        p_action_type,
        NULLIF(btrim(p_action_reason), ''),
        v_now,
        p_acting_session_id,
        p_authority_grant_id,
        p_prior_approval_action_id,
        p_action_reason_code
    );

    RETURN QUERY
    SELECT
        v_action_id,
        'RECORDED'::text,
        'APPROVAL_ACTION_RECORDED'::text,
        v_now;
END;
$function$;

COMMENT ON FUNCTION approval.record_approval_action(
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    text,
    text,
    uuid
) IS
    'Records one Approval Action Record only after exact request, policy, stage, actor, session, organization, Authority Grant, action-lineage, self-approval, affected-identity, duplicate-actor, organization-independence, authority-origin, and explicit reciprocal-chain validation. Phase 4 Steps 5 and 6 add incompatible-authority, duty-conflict, stage-satisfaction, and finalization behavior.';

REVOKE ALL ON FUNCTION
    approval.prevent_approval_action_record_mutation()
FROM PUBLIC;

REVOKE ALL ON FUNCTION approval.record_approval_action(
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    text,
    text,
    uuid
)
FROM PUBLIC;

REVOKE ALL ON TABLE
    approval.approval_request_dependencies,
    approval.approval_duty_definitions,
    approval.approval_policy_prohibited_duty_combinations,
    approval.approval_action_duties,
    approval.approval_stage_evaluations,
    approval.approval_stage_evaluation_actions
FROM PUBLIC;

SELECT foundation_meta.register_migration(
    p_migration_id =>
        '083_postgresql_approval_independence_and_separation_of_duties',
    p_migration_name =>
        'PostgreSQL approval independence and separation of duties structure',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes =>
        'Added Phase 4 structural context, controlled Approval Action recording, exact actor/session/organization/Authority Grant validation, typed action-lineage rules, append-only mutation guards, and Step 4 self-approval, affected-identity, duplicate-actor, distinct-organization, authority-origin, and explicit reciprocal-chain independence enforcement. Incompatible-authority, duty-conflict, stage-satisfaction, and finalization behavior remain later Phase 4 steps.'
);

COMMIT;
