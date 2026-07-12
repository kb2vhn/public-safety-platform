-- ============================================================================
-- Migration: 083_postgresql_approval_independence_and_separation_of_duties.sql
-- Title: PostgreSQL approval independence and separation of duties structure
-- Layer: Platform Foundation
-- Status: PHASE 4 STEP 2 STRUCTURAL CANDIDATE
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
    'Typed Authority Definition required for an actor to satisfy this stage. Step 2 defines structure only; controlled eligibility evaluation is introduced later.';

COMMENT ON COLUMN
    approval.approval_policy_stages.requester_approval_allowed IS
    'Explicit stage policy. False is the default and does not by itself implement the later controlled action-recording check.';

COMMENT ON COLUMN
    approval.approval_policy_stages.affected_identity_approval_allowed IS
    'Explicit stage policy for the directly affected identity. False is the default.';

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
        'Added Phase 4 structural context for directly affected identities, explicit request dependencies, effective actors, acting sessions, Authority Grant linkage, action lineage, typed duties, incompatible-authority modes, persisted stage evaluations, and finalization metadata. Controlled action and finalization behavior remain later Phase 4 steps.'
);

COMMIT;
