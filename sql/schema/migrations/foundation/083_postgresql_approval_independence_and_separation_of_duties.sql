-- ============================================================================
-- Migration: 083_postgresql_approval_independence_and_separation_of_duties.sql
-- Title: PostgreSQL approval independence and separation of duties structure
-- Layer: Platform Foundation
-- Status: PHASE 4 STEP 7 INDEPENDENT-CONNECTION CONCURRENCY CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';

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


-- Phase 4 Step 5 records explicit Authority Grant delegation lineage so
-- direct and delegated grant accumulation can be evaluated without inferring
-- delegation from job titles, group membership, or free-form descriptions.
ALTER TABLE access_control.authority_grants
    ADD COLUMN delegated_from_authority_grant_id uuid
        REFERENCES access_control.authority_grants(authority_grant_id),
    ADD COLUMN delegation_depth integer NOT NULL DEFAULT 0,
    ADD CONSTRAINT authority_grants_delegation_not_self_ck
        CHECK (
            delegated_from_authority_grant_id IS NULL
            OR delegated_from_authority_grant_id <> authority_grant_id
        ),
    ADD CONSTRAINT authority_grants_delegation_shape_ck
        CHECK (
            (
                delegated_from_authority_grant_id IS NULL
                AND delegation_depth = 0
            )
            OR
            (
                delegated_from_authority_grant_id IS NOT NULL
                AND delegation_depth > 0
            )
        );

COMMENT ON COLUMN
    access_control.authority_grants.delegated_from_authority_grant_id IS
    'Exact parent Authority Grant for an explicitly delegated grant. NULL identifies a direct grant.';

COMMENT ON COLUMN access_control.authority_grants.delegation_depth IS
    'Persisted delegation depth. Direct grants use zero; each delegated child must be exactly one level deeper than its parent.';

CREATE INDEX authority_grants_delegation_lineage_idx
    ON access_control.authority_grants(
        delegated_from_authority_grant_id,
        delegation_depth,
        identity_id,
        authority_definition_id,
        status,
        valid_until
    )
    WHERE delegated_from_authority_grant_id IS NOT NULL;

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
-- Phase 4 Step 5 reusable conflict-evaluation helpers
-- --------------------------------------------------------------------------

CREATE FUNCTION approval.authority_grant_is_current_for_approval(
    p_authority_grant_id uuid,
    p_approval_request_id uuid,
    p_acting_organization_id uuid,
    p_evaluated_at timestamptz
)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, approval, access_control
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM access_control.authority_grants AS grant_record
        JOIN approval.approval_requests AS request_record
          ON request_record.approval_request_id = p_approval_request_id
        WHERE grant_record.authority_grant_id = p_authority_grant_id
          AND grant_record.status = 'ACTIVE'
          AND grant_record.valid_from <= p_evaluated_at
          AND (
                grant_record.valid_until IS NULL
                OR p_evaluated_at < grant_record.valid_until
          )
          AND (
                grant_record.service_id IS NULL
                OR grant_record.service_id = request_record.service_id
          )
          AND (
                grant_record.purpose_definition_id IS NULL
                OR grant_record.purpose_definition_id =
                   request_record.purpose_definition_id
          )
          AND (
                grant_record.operation_definition_id IS NULL
                OR grant_record.operation_definition_id =
                   request_record.operation_definition_id
          )
          AND (
                grant_record.organization_id IS NULL
                OR grant_record.organization_id IS NOT DISTINCT FROM
                   p_acting_organization_id
          )
          AND grant_record.scope_reference IS NULL
          AND (
                grant_record.applies_to_all_governed_scopes
                OR grant_record.governed_scope_id IS NOT DISTINCT FROM
                   request_record.governed_scope_id
          )
          AND (
                grant_record.applies_to_all_targets
                OR (
                    grant_record.protected_target_type IS NOT DISTINCT FROM
                        request_record.protected_target_type
                    AND grant_record.protected_target_reference
                        IS NOT DISTINCT FROM
                        request_record.protected_target_reference
                )
          )
    );
$function$;

COMMENT ON FUNCTION approval.authority_grant_is_current_for_approval(
    uuid, uuid, uuid, timestamptz
) IS
    'Returns true only when the exact Authority Grant is current and applicable to the exact Approval Request, organization, Governed Scope, and Protected Resource Target at one authoritative time.';

CREATE FUNCTION approval.approval_request_is_in_duty_scope(
    p_candidate_approval_request_id uuid,
    p_anchor_approval_request_id uuid,
    p_enforcement_scope text
)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, approval
AS $function$
    SELECT CASE
        WHEN p_enforcement_scope IN ('STAGE', 'REQUEST') THEN
            p_candidate_approval_request_id = p_anchor_approval_request_id
        WHEN p_enforcement_scope = 'APPROVAL_CHAIN' THEN
            EXISTS (
                SELECT 1
                FROM approval.approval_requests AS candidate_request
                JOIN approval.approval_requests AS anchor_request
                  ON anchor_request.approval_request_id =
                     p_anchor_approval_request_id
                WHERE candidate_request.approval_request_id =
                      p_candidate_approval_request_id
                  AND (
                        candidate_request.approval_chain_id =
                            anchor_request.approval_chain_id
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
                                            p_anchor_approval_request_id
                                        AND dep.depends_on_approval_request_id =
                                            p_candidate_approval_request_id
                                    )
                                    OR
                                    (
                                        dep.approval_request_id =
                                            p_candidate_approval_request_id
                                        AND dep.depends_on_approval_request_id =
                                            p_anchor_approval_request_id
                                    )
                              )
                        )
                  )
            )
        ELSE false
    END;
$function$;

COMMENT ON FUNCTION approval.approval_request_is_in_duty_scope(
    uuid, uuid, text
) IS
    'Evaluates exact request or explicit approval-chain scope. AUTHORIZATION_CHAIN remains unavailable until its typed chain record exists and therefore fails closed in Step 5.';

CREATE FUNCTION approval.enforce_approval_action_conflicts(
    p_approval_request_id uuid,
    p_approval_policy_stage_id uuid,
    p_acting_identity_id uuid,
    p_acting_organization_id uuid,
    p_authority_grant_id uuid,
    p_evaluated_at timestamptz
)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog, approval, access_control
AS $function$
DECLARE
    v_request approval.approval_requests%ROWTYPE;
    v_stage approval.approval_policy_stages%ROWTYPE;
    v_grant access_control.authority_grants%ROWTYPE;
    v_lineage_grant access_control.authority_grants%ROWTYPE;
    v_parent_grant access_control.authority_grants%ROWTYPE;
    v_set access_control.incompatible_authority_sets%ROWTYPE;
    v_seen_grants uuid[] := ARRAY[]::uuid[];
    v_expected_depth integer;
    v_rule record;
    v_other_duty_key text;
    v_conflict boolean;
BEGIN
    SELECT request_record.*
    INTO STRICT v_request
    FROM approval.approval_requests AS request_record
    WHERE request_record.approval_request_id = p_approval_request_id;

    SELECT stage_record.*
    INTO STRICT v_stage
    FROM approval.approval_policy_stages AS stage_record
    WHERE stage_record.approval_policy_stage_id =
          p_approval_policy_stage_id
      AND stage_record.approval_policy_id = v_request.approval_policy_id;

    SELECT grant_record.*
    INTO STRICT v_grant
    FROM access_control.authority_grants AS grant_record
    WHERE grant_record.authority_grant_id = p_authority_grant_id;

    -- Explicit delegation lineage is validated from the selected grant to one
    -- direct root. Every link must remain current and context-applicable.
    IF v_grant.delegated_from_authority_grant_id IS NOT NULL THEN
        IF NOT v_stage.delegated_authority_allowed THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'DELEGATED_AUTHORITY_NOT_ALLOWED';
        END IF;

        IF v_stage.maximum_delegation_depth IS NULL
           OR v_grant.delegation_depth >
              v_stage.maximum_delegation_depth
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'DELEGATION_DEPTH_EXCEEDED';
        END IF;

        v_lineage_grant := v_grant;
        v_expected_depth := v_grant.delegation_depth;

        LOOP
            IF v_lineage_grant.authority_grant_id = ANY(v_seen_grants)
               OR v_lineage_grant.delegation_depth <> v_expected_depth
               OR v_lineage_grant.authority_definition_id <>
                  v_grant.authority_definition_id
               OR NOT approval.authority_grant_is_current_for_approval(
                    v_lineage_grant.authority_grant_id,
                    p_approval_request_id,
                    p_acting_organization_id,
                    p_evaluated_at
               )
            THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = 'invalid_authorization_specification',
                        MESSAGE = 'DELEGATED_AUTHORITY_LINEAGE_INVALID';
            END IF;

            v_seen_grants := array_append(
                v_seen_grants,
                v_lineage_grant.authority_grant_id
            );

            IF v_lineage_grant.delegated_from_authority_grant_id IS NULL THEN
                IF v_expected_depth <> 0 THEN
                    RAISE EXCEPTION
                        USING
                            ERRCODE = 'invalid_authorization_specification',
                            MESSAGE = 'DELEGATED_AUTHORITY_LINEAGE_INVALID';
                END IF;
                EXIT;
            END IF;

            SELECT parent_record.*
            INTO v_parent_grant
            FROM access_control.authority_grants AS parent_record
            WHERE parent_record.authority_grant_id =
                  v_lineage_grant.delegated_from_authority_grant_id;

            IF NOT FOUND
               OR v_parent_grant.identity_id IS DISTINCT FROM
                  v_lineage_grant.granted_by_identity_id
            THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = 'invalid_authorization_specification',
                        MESSAGE = 'DELEGATED_AUTHORITY_LINEAGE_INVALID';
            END IF;

            v_expected_depth := v_expected_depth - 1;
            IF v_expected_depth < 0 THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = 'invalid_authorization_specification',
                        MESSAGE = 'DELEGATED_AUTHORITY_LINEAGE_INVALID';
            END IF;

            v_lineage_grant := v_parent_grant;
        END LOOP;
    ELSIF v_grant.delegation_depth <> 0 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'DELEGATED_AUTHORITY_LINEAGE_INVALID';
    END IF;

    IF v_stage.incompatible_authority_set_id IS NOT NULL THEN
        SELECT set_record.*
        INTO STRICT v_set
        FROM access_control.incompatible_authority_sets AS set_record
        WHERE set_record.incompatible_authority_set_id =
              v_stage.incompatible_authority_set_id;

        IF v_set.status <> 'ACTIVE' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'INCOMPATIBLE_AUTHORITY_SET_NOT_ACTIVE';
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM access_control.incompatible_authority_members AS member
            WHERE member.incompatible_authority_set_id =
                  v_set.incompatible_authority_set_id
              AND member.authority_definition_id =
                  v_grant.authority_definition_id
        ) THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'INCOMPATIBLE_AUTHORITY_POLICY_INVALID';
        END IF;

        IF v_stage.incompatible_authority_mode = 'JOINT_EXERCISE'
           AND EXISTS (
                SELECT 1
                FROM approval.approval_actions AS prior_action
                JOIN access_control.authority_grants AS prior_grant
                  ON prior_grant.authority_grant_id =
                     prior_action.authority_grant_id
                JOIN access_control.incompatible_authority_members AS member
                  ON member.incompatible_authority_set_id =
                     v_set.incompatible_authority_set_id
                 AND member.authority_definition_id =
                     prior_grant.authority_definition_id
                WHERE prior_action.approval_request_id =
                      p_approval_request_id
                  AND prior_action.effective_actor_identity_id =
                      p_acting_identity_id
                  AND prior_action.action_type = 'APPROVE'
                  AND prior_grant.authority_definition_id <>
                      v_grant.authority_definition_id
                  AND (
                        v_set.include_delegated_grants
                        OR prior_grant.delegated_from_authority_grant_id
                           IS NULL
                  )
                  AND NOT EXISTS (
                        SELECT 1
                        FROM approval.approval_actions AS later_action
                        WHERE later_action.prior_approval_action_id =
                              prior_action.approval_action_id
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
                    MESSAGE = 'INCOMPATIBLE_AUTHORITY_JOINT_EXERCISE';
        ELSIF v_stage.incompatible_authority_mode = 'CONCURRENT_HOLDING'
              AND EXISTS (
                    SELECT 1
                    FROM access_control.authority_grants AS other_grant
                    JOIN access_control.incompatible_authority_members AS member
                      ON member.incompatible_authority_set_id =
                         v_set.incompatible_authority_set_id
                     AND member.authority_definition_id =
                         other_grant.authority_definition_id
                    WHERE other_grant.identity_id = p_acting_identity_id
                      AND other_grant.authority_grant_id <>
                          p_authority_grant_id
                      AND other_grant.authority_definition_id <>
                          v_grant.authority_definition_id
                      AND (
                            v_set.include_delegated_grants
                            OR other_grant.delegated_from_authority_grant_id
                               IS NULL
                      )
                      AND approval.authority_grant_is_current_for_approval(
                            other_grant.authority_grant_id,
                            p_approval_request_id,
                            p_acting_organization_id,
                            p_evaluated_at
                      )
              )
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'INCOMPATIBLE_AUTHORITY_CONCURRENT_HOLDING';
        ELSIF v_stage.incompatible_authority_mode = 'CHAIN_PARTICIPATION'
              AND EXISTS (
                    SELECT 1
                    FROM approval.approval_actions AS prior_action
                    JOIN access_control.authority_grants AS prior_grant
                      ON prior_grant.authority_grant_id =
                         prior_action.authority_grant_id
                    JOIN access_control.incompatible_authority_members AS member
                      ON member.incompatible_authority_set_id =
                         v_set.incompatible_authority_set_id
                     AND member.authority_definition_id =
                         prior_grant.authority_definition_id
                    WHERE prior_action.effective_actor_identity_id =
                          p_acting_identity_id
                      AND prior_action.action_type = 'APPROVE'
                      AND prior_grant.authority_definition_id <>
                          v_grant.authority_definition_id
                      AND (
                            v_set.include_delegated_grants
                            OR prior_grant.delegated_from_authority_grant_id
                               IS NULL
                      )
                      AND approval.approval_request_is_in_duty_scope(
                            prior_action.approval_request_id,
                            p_approval_request_id,
                            'APPROVAL_CHAIN'
                      )
                      AND NOT EXISTS (
                            SELECT 1
                            FROM approval.approval_actions AS later_action
                            WHERE later_action.prior_approval_action_id =
                                  prior_action.approval_action_id
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
                    MESSAGE = 'INCOMPATIBLE_AUTHORITY_CHAIN_PARTICIPATION';
        END IF;
    END IF;

    -- This controlled path records APPROVE, so it evaluates every active
    -- prohibited pair that contains APPROVE. Other controlled paths must
    -- enforce the same catalog when they later record their own duties.
    FOR v_rule IN
        SELECT rule_record.*
        FROM approval.approval_policy_prohibited_duty_combinations
             AS rule_record
        WHERE rule_record.approval_policy_id = v_request.approval_policy_id
          AND rule_record.status = 'ACTIVE'
          AND 'APPROVE' IN (
                rule_record.first_duty_key,
                rule_record.second_duty_key
          )
    LOOP
        IF v_rule.enforcement_scope = 'AUTHORIZATION_CHAIN' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'DUTY_SCOPE_NOT_EVALUATED';
        END IF;

        v_other_duty_key := CASE
            WHEN v_rule.first_duty_key = 'APPROVE'
                THEN v_rule.second_duty_key
            ELSE v_rule.first_duty_key
        END;
        v_conflict := false;

        IF v_other_duty_key = 'REQUEST' THEN
            SELECT EXISTS (
                SELECT 1
                FROM approval.approval_requests AS scoped_request
                WHERE scoped_request.requester_identity_id =
                      p_acting_identity_id
                  AND approval.approval_request_is_in_duty_scope(
                        scoped_request.approval_request_id,
                        p_approval_request_id,
                        v_rule.enforcement_scope
                  )
            )
            INTO v_conflict;
        ELSIF v_other_duty_key = 'GRANT_AUTHORITY' THEN
            v_conflict := v_grant.granted_by_identity_id =
                          p_acting_identity_id;

            IF NOT v_conflict THEN
                SELECT EXISTS (
                    SELECT 1
                    FROM approval.approval_actions AS scoped_action
                    JOIN access_control.authority_grants AS scoped_grant
                      ON scoped_grant.authority_grant_id =
                         scoped_action.authority_grant_id
                    WHERE scoped_grant.granted_by_identity_id =
                          p_acting_identity_id
                      AND scoped_action.action_type = 'APPROVE'
                      AND approval.approval_request_is_in_duty_scope(
                            scoped_action.approval_request_id,
                            p_approval_request_id,
                            v_rule.enforcement_scope
                      )
                      AND (
                            v_rule.enforcement_scope <> 'STAGE'
                            OR scoped_action.approval_policy_stage_id =
                               p_approval_policy_stage_id
                      )
                      AND NOT EXISTS (
                            SELECT 1
                            FROM approval.approval_actions AS later_action
                            WHERE later_action.prior_approval_action_id =
                                  scoped_action.approval_action_id
                              AND later_action.action_type IN (
                                  'WITHDRAW_APPROVAL',
                                  'CORRECT',
                                  'SUPERSEDE'
                              )
                      )
                )
                INTO v_conflict;
            END IF;
        ELSE
            SELECT EXISTS (
                SELECT 1
                FROM approval.approval_actions AS scoped_action
                JOIN approval.approval_action_duties AS scoped_duty
                  ON scoped_duty.approval_action_id =
                     scoped_action.approval_action_id
                WHERE scoped_action.effective_actor_identity_id =
                      p_acting_identity_id
                  AND scoped_duty.duty_key = v_other_duty_key
                  AND approval.approval_request_is_in_duty_scope(
                        scoped_action.approval_request_id,
                        p_approval_request_id,
                        v_rule.enforcement_scope
                  )
                  AND (
                        v_rule.enforcement_scope <> 'STAGE'
                        OR scoped_action.approval_policy_stage_id =
                           p_approval_policy_stage_id
                  )
                  AND NOT EXISTS (
                        SELECT 1
                        FROM approval.approval_actions AS later_action
                        WHERE later_action.prior_approval_action_id =
                              scoped_action.approval_action_id
                          AND later_action.action_type IN (
                              'WITHDRAW_APPROVAL',
                              'CORRECT',
                              'SUPERSEDE'
                          )
                  )
            )
            INTO v_conflict;
        END IF;

        IF v_conflict THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'PROHIBITED_DUTY_COMBINATION';
        END IF;
    END LOOP;
END;
$function$;

COMMENT ON FUNCTION approval.enforce_approval_action_conflicts(
    uuid, uuid, uuid, uuid, uuid, timestamptz
) IS
    'Fail-closed Phase 4 Step 5 enforcement for delegated Authority Grant lineage, incompatible-authority modes, and approval-side prohibited duty combinations.';

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
    v_lock_request_id uuid;
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

    -- ------------------------------------------------------------------
    -- Phase 4 Step 7 cross-request concurrency serialization
    -- ------------------------------------------------------------------
    -- Acquire transaction advisory locks in stable UUID order for the
    -- request, every request in its explicit chain, and directly linked
    -- reciprocal/shared-chain requests. This closes the check-then-insert
    -- race without imposing one global approval lock.
    FOR v_lock_request_id IN
        SELECT related_request.approval_request_id
        FROM (
            SELECT seed_request.approval_request_id
            FROM approval.approval_requests AS seed_request
            WHERE seed_request.approval_request_id =
                  p_approval_request_id

            UNION

            SELECT chain_request.approval_request_id
            FROM approval.approval_requests AS seed_request
            JOIN approval.approval_requests AS chain_request
              ON seed_request.approval_chain_id IS NOT NULL
             AND chain_request.approval_chain_id =
                 seed_request.approval_chain_id
            WHERE seed_request.approval_request_id =
                  p_approval_request_id

            UNION

            SELECT dependency_record.depends_on_approval_request_id
            FROM approval.approval_request_dependencies AS dependency_record
            WHERE dependency_record.approval_request_id =
                  p_approval_request_id
              AND dependency_record.dependency_type IN (
                    'RECIPROCAL_REVIEW',
                    'SHARED_APPROVAL_CHAIN'
                  )

            UNION

            SELECT dependency_record.approval_request_id
            FROM approval.approval_request_dependencies AS dependency_record
            WHERE dependency_record.depends_on_approval_request_id =
                  p_approval_request_id
              AND dependency_record.dependency_type IN (
                    'RECIPROCAL_REVIEW',
                    'SHARED_APPROVAL_CHAIN'
                  )
        ) AS related_request
        ORDER BY related_request.approval_request_id
    LOOP
        PERFORM pg_catalog.pg_advisory_xact_lock(
            pg_catalog.hashtextextended(
                'approval.request.' ||
                v_lock_request_id::text,
                0
            )
        );
    END LOOP;

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
    FOR SHARE;

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

    IF p_action_type = 'APPROVE' THEN
        PERFORM approval.enforce_approval_action_conflicts(
            p_approval_request_id,
            p_approval_policy_stage_id,
            p_acting_identity_id,
            p_acting_organization_id,
            p_authority_grant_id,
            v_now
        );
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

    IF p_action_type = 'APPROVE' THEN
        INSERT INTO approval.approval_action_duties (
            approval_action_id,
            duty_key,
            recorded_at
        )
        VALUES (
            v_action_id,
            'APPROVE',
            v_now
        );
    END IF;

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
    'Records one Approval Action Record only after exact request, policy, stage, actor, session, organization, Authority Grant, and action-lineage validation. Phase 4 Step 4 enforces self-approval, affected-identity, duplicate-effective-actor, organization-independence, authority-origin, and reciprocal-chain protections. Phase 4 Step 5 additionally enforces delegated-authority lineage, incompatible-authority rules, immutable APPROVE duty recording, and prohibited-duty combinations. Phase 4 Step 6 derives current actions, persists exact stage outcomes, finalizes Approval Requests exactly once, links satisfied stages to Decision Records, and revalidates approval continuity for approval-backed Authorization Leases. Phase 4 Step 7 serializes explicit reciprocal chains, protects Authority Grant current-state reads against concurrent revocation, and proves six independent-connection approval races.';

-- --------------------------------------------------------------------------
-- Phase 4 Step 6 current stage satisfaction and finalization
-- --------------------------------------------------------------------------

CREATE UNIQUE INDEX approval_stage_evaluations_one_finalized_stage_idx
    ON approval.approval_stage_evaluations (
        approval_request_id,
        approval_policy_stage_id
    )
    WHERE finalized_evaluation;

ALTER TABLE decision.decision_records
    ADD CONSTRAINT decision_records_approval_request_context_uq
        UNIQUE (decision_id, approval_request_id);

CREATE TABLE decision.approval_stage_evaluation_links (
    decision_id uuid NOT NULL,
    evaluation_id uuid NOT NULL,
    approval_request_id uuid NOT NULL,
    approval_stage_evaluation_id uuid NOT NULL,
    approval_policy_stage_id uuid NOT NULL,
    linked_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    PRIMARY KEY (evaluation_id, approval_stage_evaluation_id),
    CONSTRAINT approval_stage_evaluation_links_evaluation_fk
        FOREIGN KEY (evaluation_id, decision_id)
        REFERENCES decision.evaluation_records(evaluation_id, decision_id),
    CONSTRAINT approval_stage_evaluation_links_decision_request_fk
        FOREIGN KEY (decision_id, approval_request_id)
        REFERENCES decision.decision_records(decision_id, approval_request_id),
    CONSTRAINT approval_stage_evaluation_links_stage_fk
        FOREIGN KEY (
            approval_stage_evaluation_id,
            approval_request_id,
            approval_policy_stage_id
        )
        REFERENCES approval.approval_stage_evaluations (
            approval_stage_evaluation_id,
            approval_request_id,
            approval_policy_stage_id
        )
);

COMMENT ON TABLE decision.approval_stage_evaluation_links IS
    'Exact finalized Approval Request stage-evaluation records cited by an '
    'APPROVAL or SEPARATION_OF_DUTIES Decision Record evaluation.';

CREATE INDEX approval_stage_evaluation_links_request_idx
    ON decision.approval_stage_evaluation_links (
        approval_request_id,
        approval_policy_stage_id,
        decision_id
    );

CREATE FUNCTION approval.approval_action_is_current(
    p_approval_action_id uuid,
    p_evaluated_at timestamptz
)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, approval
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM approval.approval_actions AS action_record
        JOIN approval.approval_policy_stages AS stage_record
          ON stage_record.approval_policy_stage_id =
             action_record.approval_policy_stage_id
        WHERE action_record.approval_action_id = p_approval_action_id
          AND p_evaluated_at IS NOT NULL
          AND action_record.action_at <= p_evaluated_at
          AND (
                stage_record.action_validity IS NULL
                OR p_evaluated_at <
                   action_record.action_at + stage_record.action_validity
              )
          AND NOT EXISTS (
                SELECT 1
                FROM approval.approval_actions AS later_action
                WHERE later_action.prior_approval_action_id =
                      action_record.approval_action_id
                  AND later_action.action_type IN (
                        'WITHDRAW_APPROVAL',
                        'CORRECT',
                        'SUPERSEDE'
                      )
                  AND later_action.action_at <= p_evaluated_at
          )
    );
$function$;

COMMENT ON FUNCTION approval.approval_action_is_current(uuid, timestamptz) IS
    'Returns true only when one Approval Action Record existed at the '
    'captured evaluation time, remained within stage action validity, and '
    'had not been withdrawn, corrected, or superseded by that time.';

CREATE FUNCTION approval.evaluate_approval_stage(
    p_approval_request_id uuid,
    p_approval_policy_stage_id uuid,
    p_evaluated_at timestamptz DEFAULT statement_timestamp(),
    p_finalized_evaluation boolean DEFAULT false
)
RETURNS TABLE (
    approval_stage_evaluation_id uuid,
    result text,
    reason_code text,
    required_approvals integer,
    counted_approvals integer,
    distinct_effective_actors integer,
    distinct_organizations integer,
    blocking_deny_present boolean,
    evaluated_at timestamptz
)
LANGUAGE plpgsql
SET search_path = pg_catalog, approval, access_control
AS $function$
DECLARE
    v_request approval.approval_requests%ROWTYPE;
    v_policy approval.approval_policies%ROWTYPE;
    v_stage approval.approval_policy_stages%ROWTYPE;
    v_action approval.approval_actions%ROWTYPE;
    v_identity identity.identities%ROWTYPE;
    v_session access_control.sessions%ROWTYPE;
    v_grant access_control.authority_grants%ROWTYPE;
    v_environment_key text;
    v_evaluation_id uuid := gen_random_uuid();
    v_result text;
    v_reason_code text;
    v_exclusion_reason text;
    v_counted integer := 0;
    v_distinct_actor_count integer := 0;
    v_distinct_organization_count integer := 0;
    v_actor_ids uuid[] := ARRAY[]::uuid[];
    v_organization_ids uuid[] := ARRAY[]::uuid[];
    v_blocking_deny boolean := false;
    v_not_evaluated boolean := false;
BEGIN
    IF p_approval_request_id IS NULL
       OR p_approval_policy_stage_id IS NULL
       OR p_evaluated_at IS NULL
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'APPROVAL_STAGE_EVALUATION_PARAMETERS_REQUIRED';
    END IF;

    SELECT request_record.*
      INTO v_request
      FROM approval.approval_requests AS request_record
     WHERE request_record.approval_request_id = p_approval_request_id
     FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'no_data_found',
                MESSAGE = 'APPROVAL_REQUEST_NOT_FOUND';
    END IF;

    SELECT policy_record.*
      INTO STRICT v_policy
      FROM approval.approval_policies AS policy_record
     WHERE policy_record.approval_policy_id = v_request.approval_policy_id;

    SELECT stage_record.*
      INTO v_stage
      FROM approval.approval_policy_stages AS stage_record
     WHERE stage_record.approval_policy_stage_id =
           p_approval_policy_stage_id
       AND stage_record.approval_policy_id = v_request.approval_policy_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'no_data_found',
                MESSAGE = 'APPROVAL_STAGE_NOT_FOUND';
    END IF;

    INSERT INTO approval.approval_stage_evaluations (
        approval_stage_evaluation_id,
        approval_request_id,
        approval_policy_stage_id,
        evaluated_at,
        result,
        reason_code,
        required_approvals,
        counted_approvals,
        distinct_effective_actors,
        distinct_organizations,
        blocking_deny_present,
        finalized_evaluation
    )
    VALUES (
        v_evaluation_id,
        p_approval_request_id,
        p_approval_policy_stage_id,
        p_evaluated_at,
        'NOT_EVALUATED',
        'APPROVAL_STAGE_EVALUATION_PENDING',
        v_stage.minimum_approvals,
        0,
        0,
        0,
        false,
        p_finalized_evaluation
    );

    IF v_request.status <> 'PENDING' THEN
        v_result := 'NOT_EVALUATED';
        v_reason_code := 'APPROVAL_REQUEST_NOT_PENDING';
    ELSIF v_policy.status <> 'ACTIVE'
       OR v_policy.valid_from > p_evaluated_at
       OR (
            v_policy.valid_until IS NOT NULL
            AND p_evaluated_at >= v_policy.valid_until
          )
    THEN
        v_result := 'NOT_EVALUATED';
        v_reason_code := 'APPROVAL_POLICY_NOT_ACTIVE';
    ELSIF v_request.expires_at IS NOT NULL
       AND p_evaluated_at >= v_request.expires_at
    THEN
        v_result := 'UNSATISFIED';
        v_reason_code := 'APPROVAL_REQUEST_EXPIRED';
    ELSIF v_stage.required_authority_definition_id IS NULL THEN
        v_result := 'NOT_EVALUATED';
        v_reason_code := 'APPROVER_AUTHORITY_REQUIRED';
    ELSE
        FOR v_action IN
            SELECT action_record.*
              FROM approval.approval_actions AS action_record
             WHERE action_record.approval_request_id =
                   p_approval_request_id
               AND action_record.approval_policy_stage_id =
                   p_approval_policy_stage_id
               AND action_record.action_at <= p_evaluated_at
             ORDER BY
                   action_record.action_at,
                   action_record.approval_action_id
        LOOP
            v_exclusion_reason := NULL;

            IF NOT approval.approval_action_is_current(
                v_action.approval_action_id,
                p_evaluated_at
            ) THEN
                v_exclusion_reason := 'APPROVAL_ACTION_NOT_CURRENT';

            ELSIF v_action.action_type = 'DENY' THEN
                IF v_stage.blocking_deny THEN
                    v_blocking_deny := true;
                    v_exclusion_reason := 'BLOCKING_DENY_PRESENT';
                ELSE
                    v_exclusion_reason := 'ACTION_TYPE_NOT_COUNTED';
                END IF;

            ELSIF v_action.action_type <> 'APPROVE' THEN
                v_exclusion_reason := 'ACTION_TYPE_NOT_COUNTED';

            ELSE
                SELECT identity_record.*
                  INTO v_identity
                  FROM identity.identities AS identity_record
                 WHERE identity_record.identity_id =
                       v_action.effective_actor_identity_id;

                IF NOT FOUND
                   OR v_identity.status <> 'ACTIVE'
                   OR v_identity.valid_from > p_evaluated_at
                   OR (
                        v_identity.valid_until IS NOT NULL
                        AND p_evaluated_at >= v_identity.valid_until
                      )
                THEN
                    v_exclusion_reason := 'APPROVER_NOT_ELIGIBLE';
                END IF;

                IF v_exclusion_reason IS NULL THEN
                    SELECT session_record.*
                      INTO v_session
                      FROM access_control.sessions AS session_record
                     WHERE session_record.session_id =
                           v_action.acting_session_id;

                    IF NOT FOUND
                       OR v_session.status <> 'ACTIVE'
                       OR v_session.identity_id <>
                          v_action.effective_actor_identity_id
                       OR v_session.organization_id IS DISTINCT FROM
                          v_action.acting_organization_id
                       OR v_session.service_id IS DISTINCT FROM
                          v_request.service_id
                       OR v_session.authenticated_at > p_evaluated_at
                       OR p_evaluated_at >= v_session.expires_at
                       OR (
                            v_session.inactivity_timeout IS NOT NULL
                            AND p_evaluated_at >=
                                COALESCE(
                                    v_session.last_activity_at,
                                    v_session.authenticated_at
                                ) + v_session.inactivity_timeout
                          )
                    THEN
                        v_exclusion_reason :=
                            'APPROVER_SESSION_NOT_CURRENT';
                    ELSE
                        SELECT provider_record.environment_key
                          INTO v_environment_key
                          FROM trust.trust_providers AS provider_record
                         WHERE provider_record.trust_provider_id =
                               v_session.trust_provider_id;

                        IF v_environment_key IS NULL
                           OR NOT access_control.
                                  session_context_is_locally_usable(
                                      v_session.identity_id,
                                      v_session.device_id,
                                      v_session.trust_provider_id,
                                      v_session.service_id,
                                      v_session.organization_id,
                                      v_environment_key,
                                      p_evaluated_at
                                  )
                        THEN
                            v_exclusion_reason :=
                                'APPROVER_SESSION_NOT_CURRENT';
                        END IF;
                    END IF;
                END IF;

                IF v_exclusion_reason IS NULL THEN
                    SELECT grant_record.*
                      INTO v_grant
                      FROM access_control.authority_grants AS grant_record
                     WHERE grant_record.authority_grant_id =
                           v_action.authority_grant_id;

                    IF NOT FOUND
                       OR v_grant.identity_id <>
                          v_action.effective_actor_identity_id
                       OR v_grant.authority_definition_id <>
                          v_stage.required_authority_definition_id
                       OR NOT approval.
                              authority_grant_is_current_for_approval(
                                  v_action.authority_grant_id,
                                  p_approval_request_id,
                                  v_action.acting_organization_id,
                                  p_evaluated_at
                              )
                    THEN
                        v_exclusion_reason :=
                            'APPROVER_AUTHORITY_NOT_CURRENT';
                    END IF;
                END IF;

                IF v_exclusion_reason IS NULL THEN
                    BEGIN
                        PERFORM approval.enforce_approval_action_conflicts(
                            p_approval_request_id,
                            p_approval_policy_stage_id,
                            v_action.effective_actor_identity_id,
                            v_action.acting_organization_id,
                            v_action.authority_grant_id,
                            p_evaluated_at
                        );
                    EXCEPTION
                        WHEN invalid_authorization_specification THEN
                            v_exclusion_reason := SQLERRM;
                            IF SQLERRM = 'DUTY_SCOPE_NOT_EVALUATED' THEN
                                v_not_evaluated := true;
                            END IF;
                    END;
                END IF;

                IF v_exclusion_reason IS NULL
                   AND v_stage.independent_identity_required
                   AND v_action.effective_actor_identity_id =
                       ANY(v_actor_ids)
                THEN
                    v_exclusion_reason := 'DUPLICATE_EFFECTIVE_ACTOR';
                END IF;

                IF v_exclusion_reason IS NULL
                   AND v_stage.independent_organization_required
                   AND (
                        v_action.acting_organization_id IS NULL
                        OR v_action.acting_organization_id =
                           ANY(v_organization_ids)
                       )
                THEN
                    v_exclusion_reason :=
                        'INDEPENDENT_ORGANIZATION_REQUIRED';
                END IF;

                IF v_exclusion_reason IS NULL THEN
                    v_counted := v_counted + 1;

                    IF NOT (
                        v_action.effective_actor_identity_id =
                        ANY(v_actor_ids)
                    ) THEN
                        v_actor_ids := array_append(
                            v_actor_ids,
                            v_action.effective_actor_identity_id
                        );
                    END IF;

                    IF v_action.acting_organization_id IS NOT NULL
                       AND NOT (
                            v_action.acting_organization_id =
                            ANY(v_organization_ids)
                       )
                    THEN
                        v_organization_ids := array_append(
                            v_organization_ids,
                            v_action.acting_organization_id
                        );
                    END IF;
                END IF;
            END IF;

            INSERT INTO approval.approval_stage_evaluation_actions (
                approval_stage_evaluation_id,
                approval_action_id,
                authority_grant_id,
                counted,
                exclusion_reason_code
            )
            VALUES (
                v_evaluation_id,
                v_action.approval_action_id,
                v_action.authority_grant_id,
                v_exclusion_reason IS NULL,
                v_exclusion_reason
            );
        END LOOP;

        v_distinct_actor_count := cardinality(v_actor_ids);
        v_distinct_organization_count :=
            cardinality(v_organization_ids);

        IF v_not_evaluated THEN
            v_result := 'NOT_EVALUATED';
            v_reason_code := 'DUTY_SCOPE_NOT_EVALUATED';
        ELSIF v_blocking_deny THEN
            v_result := 'DENIED';
            v_reason_code := 'BLOCKING_DENY_PRESENT';
        ELSIF v_counted >= v_stage.minimum_approvals
          AND (
                NOT v_stage.independent_identity_required
                OR v_distinct_actor_count >= v_stage.minimum_approvals
              )
          AND (
                NOT v_stage.independent_organization_required
                OR v_distinct_organization_count >=
                   v_stage.minimum_approvals
              )
        THEN
            v_result := 'SATISFIED';
            v_reason_code := 'APPROVAL_STAGE_SATISFIED';
        ELSE
            v_result := 'UNSATISFIED';
            v_reason_code := 'APPROVAL_STAGE_UNSATISFIED';
        END IF;
    END IF;

    UPDATE approval.approval_stage_evaluations AS evaluation_record
       SET result = v_result,
           reason_code = v_reason_code,
           counted_approvals = v_counted,
           distinct_effective_actors = v_distinct_actor_count,
           distinct_organizations = v_distinct_organization_count,
           blocking_deny_present = v_blocking_deny
     WHERE evaluation_record.approval_stage_evaluation_id =
           v_evaluation_id;

    approval_stage_evaluation_id := v_evaluation_id;
    result := v_result;
    reason_code := v_reason_code;
    required_approvals := v_stage.minimum_approvals;
    counted_approvals := v_counted;
    distinct_effective_actors := v_distinct_actor_count;
    distinct_organizations := v_distinct_organization_count;
    blocking_deny_present := v_blocking_deny;
    evaluated_at := p_evaluated_at;
    RETURN NEXT;
END;
$function$;

COMMENT ON FUNCTION approval.evaluate_approval_stage(
    uuid,
    uuid,
    timestamptz,
    boolean
) IS
    'Persist one approval-stage outcome using one authoritative time, the '
    'current action lineage, current actor/session/Authority Grant state, '
    'independence, incompatible-authority, prohibited-duty, and blocking '
    'denial evaluation.';

CREATE FUNCTION approval.finalize_approval_request(
    p_approval_request_id uuid,
    p_expected_final_status text,
    p_finalized_by_identity_id uuid
)
RETURNS TABLE (
    final_status text,
    final_reason_code text,
    finalized_at timestamptz
)
LANGUAGE plpgsql
SET search_path = pg_catalog, approval
AS $function$
DECLARE
    v_now timestamptz := statement_timestamp();
    v_request approval.approval_requests%ROWTYPE;
    v_policy approval.approval_policies%ROWTYPE;
    v_finalizer identity.identities%ROWTYPE;
    v_stage approval.approval_policy_stages%ROWTYPE;
    v_evaluation record;
    v_stage_count integer := 0;
    v_unsatisfied boolean := false;
    v_denied boolean := false;
    v_not_evaluated boolean := false;
    v_cancelled boolean := false;
    v_escalated boolean := false;
    v_computed_status text;
    v_computed_reason text;
BEGIN
    IF p_approval_request_id IS NULL
       OR p_expected_final_status IS NULL
       OR p_finalized_by_identity_id IS NULL
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'APPROVAL_FINALIZATION_PARAMETERS_REQUIRED';
    END IF;

    IF p_expected_final_status NOT IN (
        'APPROVED',
        'DENIED',
        'CANCELLED',
        'EXPIRED',
        'ESCALATED'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'APPROVAL_FINAL_STATUS_INVALID';
    END IF;

    SELECT request_record.*
      INTO v_request
      FROM approval.approval_requests AS request_record
     WHERE request_record.approval_request_id = p_approval_request_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'no_data_found',
                MESSAGE = 'APPROVAL_REQUEST_NOT_FOUND';
    END IF;

    IF v_request.finalized_at IS NOT NULL
       OR v_request.status <> 'PENDING'
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'APPROVAL_REQUEST_FINALIZED';
    END IF;

    SELECT policy_record.*
      INTO STRICT v_policy
      FROM approval.approval_policies AS policy_record
     WHERE policy_record.approval_policy_id = v_request.approval_policy_id;

    SELECT identity_record.*
      INTO v_finalizer
      FROM identity.identities AS identity_record
     WHERE identity_record.identity_id = p_finalized_by_identity_id;

    IF NOT FOUND
       OR v_finalizer.status <> 'ACTIVE'
       OR v_finalizer.valid_from > v_now
       OR (
            v_finalizer.valid_until IS NOT NULL
            AND v_now >= v_finalizer.valid_until
          )
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVAL_FINALIZER_NOT_ELIGIBLE';
    END IF;

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

    SELECT EXISTS (
        SELECT 1
        FROM approval.approval_actions AS action_record
        WHERE action_record.approval_request_id = p_approval_request_id
          AND action_record.action_type = 'CANCEL_REQUEST'
          AND approval.approval_action_is_current(
                action_record.approval_action_id,
                v_now
              )
    )
    INTO v_cancelled;

    SELECT EXISTS (
        SELECT 1
        FROM approval.approval_actions AS action_record
        WHERE action_record.approval_request_id = p_approval_request_id
          AND action_record.action_type = 'ESCALATE'
          AND approval.approval_action_is_current(
                action_record.approval_action_id,
                v_now
              )
    )
    INTO v_escalated;

    IF v_cancelled AND v_escalated THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVAL_TERMINAL_ACTION_AMBIGUOUS';
    END IF;

    FOR v_stage IN
        SELECT stage_record.*
        FROM approval.approval_policy_stages AS stage_record
        WHERE stage_record.approval_policy_id =
              v_request.approval_policy_id
        ORDER BY stage_record.stage_order
    LOOP
        v_stage_count := v_stage_count + 1;

        SELECT *
          INTO STRICT v_evaluation
          FROM approval.evaluate_approval_stage(
              p_approval_request_id,
              v_stage.approval_policy_stage_id,
              v_now,
              true
          );

        IF v_evaluation.result = 'DENIED' THEN
            v_denied := true;
        ELSIF v_evaluation.result = 'NOT_EVALUATED' THEN
            v_not_evaluated := true;
        ELSIF v_evaluation.result <> 'SATISFIED' THEN
            v_unsatisfied := true;
        END IF;
    END LOOP;

    IF v_stage_count = 0 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVAL_STAGE_NOT_FOUND';
    END IF;

    IF v_request.expires_at IS NOT NULL
       AND v_now >= v_request.expires_at
    THEN
        v_computed_status := 'EXPIRED';
        v_computed_reason := 'APPROVAL_REQUEST_EXPIRED';
    ELSIF v_cancelled THEN
        v_computed_status := 'CANCELLED';
        v_computed_reason := 'APPROVAL_REQUEST_CANCELLED';
    ELSIF v_escalated THEN
        v_computed_status := 'ESCALATED';
        v_computed_reason := 'APPROVAL_REQUEST_ESCALATED';
    ELSIF v_denied THEN
        v_computed_status := 'DENIED';
        v_computed_reason := 'APPROVAL_REQUEST_DENIED';
    ELSIF v_not_evaluated THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'APPROVAL_STAGE_NOT_EVALUATED';
    ELSIF v_unsatisfied THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'APPROVAL_STAGE_UNSATISFIED';
    ELSE
        v_computed_status := 'APPROVED';
        v_computed_reason := 'APPROVAL_REQUEST_APPROVED';
    END IF;

    IF p_expected_final_status <> v_computed_status THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'check_violation',
                MESSAGE = 'APPROVAL_FINAL_RESULT_MISMATCH';
    END IF;

    UPDATE approval.approval_requests AS request_record
       SET status = v_computed_status,
           finalized_at = v_now,
           finalized_by_identity_id = p_finalized_by_identity_id,
           final_reason_code = v_computed_reason
     WHERE request_record.approval_request_id =
           p_approval_request_id
       AND request_record.status = 'PENDING'
       AND request_record.finalized_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'APPROVAL_REQUEST_FINALIZED';
    END IF;

    final_status := v_computed_status;
    final_reason_code := v_computed_reason;
    finalized_at := v_now;
    RETURN NEXT;
END;
$function$;

COMMENT ON FUNCTION approval.finalize_approval_request(uuid, text, uuid) IS
    'Lock and finalize one PENDING Approval Request exactly once after '
    'persisting every required stage evaluation at one authoritative time. '
    'The caller may state an expected terminal result but cannot select a '
    'result that differs from PostgreSQL computed state.';

CREATE FUNCTION approval.approval_request_is_current_for_authorization(
    p_approval_request_id uuid,
    p_evaluated_at timestamptz DEFAULT statement_timestamp()
)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, approval, access_control
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM approval.approval_requests AS request_record
        JOIN approval.approval_policies AS policy_record
          ON policy_record.approval_policy_id =
             request_record.approval_policy_id
        WHERE request_record.approval_request_id =
              p_approval_request_id
          AND p_evaluated_at IS NOT NULL
          AND request_record.status = 'APPROVED'
          AND request_record.finalized_at IS NOT NULL
          AND request_record.finalized_at <= p_evaluated_at
          AND request_record.final_reason_code =
              'APPROVAL_REQUEST_APPROVED'
          AND (
                request_record.expires_at IS NULL
                OR p_evaluated_at < request_record.expires_at
              )
          AND policy_record.status = 'ACTIVE'
          AND policy_record.valid_from <= p_evaluated_at
          AND (
                policy_record.valid_until IS NULL
                OR p_evaluated_at < policy_record.valid_until
              )
          AND NOT EXISTS (
                SELECT 1
                FROM approval.approval_policy_stages AS stage_record
                WHERE stage_record.approval_policy_id =
                      request_record.approval_policy_id
                  AND NOT EXISTS (
                        SELECT 1
                        FROM approval.approval_stage_evaluations AS evaluation
                        WHERE evaluation.approval_request_id =
                              request_record.approval_request_id
                          AND evaluation.approval_policy_stage_id =
                              stage_record.approval_policy_stage_id
                          AND evaluation.finalized_evaluation
                          AND evaluation.result = 'SATISFIED'
                          AND evaluation.counted_approvals >=
                              stage_record.minimum_approvals
                  )
          )
          AND NOT EXISTS (
                SELECT 1
                FROM approval.approval_stage_evaluations AS evaluation
                WHERE evaluation.approval_request_id =
                      request_record.approval_request_id
                  AND evaluation.finalized_evaluation
                  AND evaluation.result <> 'SATISFIED'
          )
          AND NOT EXISTS (
                SELECT 1
                FROM approval.approval_stage_evaluations AS evaluation
                JOIN approval.approval_stage_evaluation_actions AS link
                  ON link.approval_stage_evaluation_id =
                     evaluation.approval_stage_evaluation_id
                 AND link.counted
                JOIN approval.approval_actions AS action_record
                  ON action_record.approval_action_id =
                     link.approval_action_id
                JOIN approval.approval_policy_stages AS stage_record
                  ON stage_record.approval_policy_stage_id =
                     evaluation.approval_policy_stage_id
                JOIN identity.identities AS identity_record
                  ON identity_record.identity_id =
                     action_record.effective_actor_identity_id
                WHERE evaluation.approval_request_id =
                      request_record.approval_request_id
                  AND evaluation.finalized_evaluation
                  AND (
                        action_record.action_type <> 'APPROVE'
                        OR NOT approval.approval_action_is_current(
                            action_record.approval_action_id,
                            p_evaluated_at
                        )
                        OR identity_record.status <> 'ACTIVE'
                        OR identity_record.valid_from > p_evaluated_at
                        OR (
                            identity_record.valid_until IS NOT NULL
                            AND p_evaluated_at >=
                                identity_record.valid_until
                           )
                        OR link.authority_grant_id IS NULL
                        OR NOT approval.
                               authority_grant_is_current_for_approval(
                                   link.authority_grant_id,
                                   request_record.approval_request_id,
                                   action_record.acting_organization_id,
                                   p_evaluated_at
                               )
                        OR NOT EXISTS (
                            SELECT 1
                            FROM access_control.authority_grants AS grant_record
                            WHERE grant_record.authority_grant_id =
                                  link.authority_grant_id
                              AND grant_record.identity_id =
                                  action_record.effective_actor_identity_id
                              AND grant_record.authority_definition_id =
                                  stage_record.
                                  required_authority_definition_id
                        )
                      )
          )
    );
$function$;

COMMENT ON FUNCTION approval.approval_request_is_current_for_authorization(
    uuid,
    timestamptz
) IS
    'Revalidate one finalized APPROVED request for later authorization use '
    'without rewriting its historical result. Every required finalized stage, '
    'counted Approval Action Record, effective actor, and exact Authority '
    'Grant must remain current at the supplied authoritative time.';

CREATE FUNCTION decision.link_approval_stage_evaluation(
    p_decision_id uuid,
    p_evaluation_id uuid,
    p_approval_stage_evaluation_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, decision, approval
AS $function$
DECLARE
    v_decision decision.decision_records%ROWTYPE;
    v_evaluation decision.evaluation_records%ROWTYPE;
    v_stage_evaluation approval.approval_stage_evaluations%ROWTYPE;
    v_request approval.approval_requests%ROWTYPE;
BEGIN
    SELECT decision_record.*
      INTO v_decision
      FROM decision.decision_records AS decision_record
     WHERE decision_record.decision_id = p_decision_id
     FOR SHARE;

    IF NOT FOUND
       OR v_decision.record_status <> 'DRAFT'
       OR v_decision.approval_request_id IS NULL
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'DECISION_APPROVAL_CONTEXT_INVALID';
    END IF;

    SELECT evaluation_record.*
      INTO v_evaluation
      FROM decision.evaluation_records AS evaluation_record
     WHERE evaluation_record.evaluation_id = p_evaluation_id
       AND evaluation_record.decision_id = p_decision_id;

    IF NOT FOUND
       OR v_evaluation.evaluation_key NOT IN (
            'APPROVAL',
            'SEPARATION_OF_DUTIES'
          )
       OR v_evaluation.result <> 'PASS'
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'DECISION_APPROVAL_EVALUATION_INVALID';
    END IF;

    SELECT stage_evaluation.*
      INTO v_stage_evaluation
      FROM approval.approval_stage_evaluations AS stage_evaluation
     WHERE stage_evaluation.approval_stage_evaluation_id =
           p_approval_stage_evaluation_id;

    IF NOT FOUND
       OR NOT v_stage_evaluation.finalized_evaluation
       OR v_stage_evaluation.result <> 'SATISFIED'
       OR v_stage_evaluation.approval_request_id <>
          v_decision.approval_request_id
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'DECISION_APPROVAL_STAGE_INVALID';
    END IF;

    SELECT request_record.*
      INTO STRICT v_request
      FROM approval.approval_requests AS request_record
     WHERE request_record.approval_request_id =
           v_stage_evaluation.approval_request_id;

    IF v_request.status <> 'APPROVED'
       OR v_decision.requester_identity_id IS DISTINCT FROM
          v_request.requester_identity_id
       OR v_decision.requester_organization_id IS DISTINCT FROM
          v_request.requester_organization_id
       OR v_decision.service_id IS DISTINCT FROM v_request.service_id
       OR v_decision.purpose_definition_id IS DISTINCT FROM
          v_request.purpose_definition_id
       OR v_decision.operation_definition_id IS DISTINCT FROM
          v_request.operation_definition_id
       OR v_decision.operation_key <> v_request.operation_key
       OR v_decision.protected_target_type <>
          v_request.protected_target_type
       OR v_decision.protected_target_reference <>
          v_request.protected_target_reference
       OR v_decision.governed_scope_id IS DISTINCT FROM
          v_request.governed_scope_id
       OR v_decision.classification_key IS DISTINCT FROM
          v_request.classification_key
       OR v_decision.correlation_id <> v_request.correlation_id
       OR NOT approval.approval_request_is_current_for_authorization(
            v_request.approval_request_id,
            v_decision.evaluated_at
          )
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'DECISION_APPROVAL_CONTEXT_MISMATCH';
    END IF;

    INSERT INTO decision.approval_stage_evaluation_links (
        decision_id,
        evaluation_id,
        approval_request_id,
        approval_stage_evaluation_id,
        approval_policy_stage_id,
        linked_at
    )
    VALUES (
        p_decision_id,
        p_evaluation_id,
        v_stage_evaluation.approval_request_id,
        p_approval_stage_evaluation_id,
        v_stage_evaluation.approval_policy_stage_id,
        statement_timestamp()
    );

    RETURN true;
END;
$function$;

COMMENT ON FUNCTION decision.link_approval_stage_evaluation(
    uuid,
    uuid,
    uuid
) IS
    'Bind one PASS APPROVAL or SEPARATION_OF_DUTIES Decision Record '
    'evaluation to the exact finalized SATISFIED approval-stage evaluation '
    'whose request and protected context match the draft Decision Record.';

CREATE FUNCTION decision.prevent_approval_stage_evaluation_link_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, decision
AS $function$
BEGIN
    RAISE EXCEPTION
        USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'DECISION_APPROVAL_STAGE_LINK_IMMUTABLE';
END;
$function$;

CREATE TRIGGER approval_stage_evaluation_links_append_only_guard
    BEFORE UPDATE OR DELETE
    ON decision.approval_stage_evaluation_links
    FOR EACH ROW
    EXECUTE FUNCTION
        decision.prevent_approval_stage_evaluation_link_mutation();

ALTER TABLE access_control.authorization_leases
    ADD COLUMN approval_continuity_required boolean
        NOT NULL DEFAULT false;

COMMENT ON COLUMN
    access_control.authorization_leases.approval_continuity_required IS
    'True only when the issuing Decision Record cites finalized approval-stage '
    'evaluations. Such a lease must revalidate approval continuity at issuance '
    'and before every successful-use increment.';

CREATE FUNCTION approval.enforce_authorization_lease_approval_continuity()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, approval, decision
AS $function$
DECLARE
    v_linked_approval boolean := false;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT EXISTS (
            SELECT 1
            FROM decision.approval_stage_evaluation_links AS link
            WHERE link.decision_id = NEW.issuing_decision_id
        )
        INTO v_linked_approval;

        NEW.approval_continuity_required := v_linked_approval;

        IF v_linked_approval
           AND (
                NEW.approval_request_id IS NULL
                OR NOT approval.
                       approval_request_is_current_for_authorization(
                           NEW.approval_request_id,
                           statement_timestamp()
                       )
               )
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'APPROVAL_CONTINUITY_REQUIRED';
        END IF;

        RETURN NEW;
    END IF;

    IF NEW.approval_continuity_required IS DISTINCT FROM
       OLD.approval_continuity_required
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'APPROVAL_CONTINUITY_BINDING_IMMUTABLE';
    END IF;

    IF OLD.approval_continuity_required
       AND NEW.successful_use_count > OLD.successful_use_count
       AND (
            NEW.approval_request_id IS NULL
            OR NOT approval.approval_request_is_current_for_authorization(
                NEW.approval_request_id,
                statement_timestamp()
            )
           )
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'APPROVAL_CONTINUITY_REQUIRED';
    END IF;

    RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION
    approval.enforce_authorization_lease_approval_continuity() IS
    'Derive immutable approval-continuity binding from exact Decision Record '
    'stage-evaluation links, reject issuance when linked approval is not '
    'current, and reject each later successful-use increment after continuity '
    'is lost. Approval-unrelated legacy decisions remain unaffected.';

CREATE TRIGGER authorization_lease_approval_continuity_guard
    BEFORE INSERT OR UPDATE OF
        successful_use_count,
        approval_continuity_required
    ON access_control.authorization_leases
    FOR EACH ROW
    EXECUTE FUNCTION
        approval.enforce_authorization_lease_approval_continuity();

REVOKE ALL ON FUNCTION
    approval.approval_action_is_current(uuid, timestamptz)
    FROM PUBLIC;

REVOKE ALL ON FUNCTION
    approval.evaluate_approval_stage(uuid, uuid, timestamptz, boolean)
    FROM PUBLIC;

REVOKE ALL ON FUNCTION
    approval.finalize_approval_request(uuid, text, uuid)
    FROM PUBLIC;

REVOKE ALL ON FUNCTION
    approval.approval_request_is_current_for_authorization(
        uuid,
        timestamptz
    )
    FROM PUBLIC;

REVOKE ALL ON FUNCTION
    decision.link_approval_stage_evaluation(uuid, uuid, uuid)
    FROM PUBLIC;

REVOKE ALL ON FUNCTION
    decision.prevent_approval_stage_evaluation_link_mutation()
    FROM PUBLIC;

REVOKE ALL ON FUNCTION
    approval.enforce_authorization_lease_approval_continuity()
    FROM PUBLIC;

REVOKE ALL ON TABLE
    decision.approval_stage_evaluation_links
    FROM PUBLIC;

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


REVOKE ALL ON FUNCTION approval.authority_grant_is_current_for_approval(
    uuid, uuid, uuid, timestamptz
)
FROM PUBLIC;

REVOKE ALL ON FUNCTION approval.approval_request_is_in_duty_scope(
    uuid, uuid, text
)
FROM PUBLIC;

REVOKE ALL ON FUNCTION approval.enforce_approval_action_conflicts(
    uuid, uuid, uuid, uuid, uuid, timestamptz
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
        'Added Phase 4 structural context, controlled Approval Action recording, exact actor/session/organization/Authority Grant validation, typed action-lineage rules, append-only mutation guards, Step 4 independence enforcement, Step 5 delegation and incompatible-authority enforcement, Step 6 current-action derivation, persisted stage satisfaction, finalization-once Approval Requests, exact Decision Record stage links, and later-use approval continuity for approval-backed leases, plus Step 7 deterministic request-chain serialization, Authority Grant revocation exclusion, and independent-connection race proofs.'
);

COMMIT;
