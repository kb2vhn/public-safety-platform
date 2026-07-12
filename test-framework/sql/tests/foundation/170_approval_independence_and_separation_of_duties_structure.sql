-- ============================================================================
-- Phase 4 Step 2 approval independence and separation-of-duties structure
-- ============================================================================
--
-- Purpose:
-- Prove the typed relational structure, constraints, foreign keys, generated
-- effective-actor identity, indexes, duty catalog, request dependencies, and
-- persisted stage-evaluation objects added by migration 083.
--
-- Controlled Approval Action recording, behavioral independence enforcement,
-- incompatible-authority evaluation, stage satisfaction, and finalization
-- remain later Phase 4 steps.
-- ============================================================================

SELECT sql_test.begin_file(
    '170_approval_independence_and_separation_of_duties_structure.sql'
);

SELECT sql_test.assert_true(
    'Migration 083 is registered',
    EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id =
            '083_postgresql_approval_independence_and_separation_of_duties'
    )
);

SELECT sql_test.assert_true(
    'Approval stages have a typed required Authority Definition',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_policy_stages'
          AND column_name = 'required_authority_definition_id'
    )
);

SELECT sql_test.assert_true(
    'Approval stages explicitly govern requester approval',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_policy_stages'
          AND column_name = 'requester_approval_allowed'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Approval stages explicitly govern directly affected identity approval',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_policy_stages'
          AND column_name = 'affected_identity_approval_allowed'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Approval stages have explicit delegated-authority policy',
    (
        SELECT count(*) = 2
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_policy_stages'
          AND column_name IN (
              'delegated_authority_allowed',
              'maximum_delegation_depth'
          )
    )
);

SELECT sql_test.assert_true(
    'Approval stages have an action-validity interval',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_policy_stages'
          AND column_name = 'action_validity'
          AND data_type = 'interval'
    )
);

SELECT sql_test.assert_true(
    'Approval stages have typed incompatible-authority policy columns',
    (
        SELECT count(*) = 2
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_policy_stages'
          AND column_name IN (
              'incompatible_authority_set_id',
              'incompatible_authority_mode'
          )
    )
);

SELECT sql_test.assert_true(
    'Approval stage delegation-depth shape is constrained',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'approval.approval_policy_stages'::regclass
          AND conname = 'approval_policy_stages_delegation_depth_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Approval stage incompatible-authority pair shape is constrained',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'approval.approval_policy_stages'::regclass
          AND conname = 'approval_policy_stages_incompatible_pair_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Approval Requests have typed directly affected identity context',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_requests'
          AND column_name = 'directly_affected_identity_id'
    )
);

SELECT sql_test.assert_true(
    'Approval Requests have a non-null approval-chain identifier',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_requests'
          AND column_name = 'approval_chain_id'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Approval Requests have finalization metadata',
    (
        SELECT count(*) = 3
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_requests'
          AND column_name IN (
              'finalized_at',
              'finalized_by_identity_id',
              'final_reason_code'
          )
    )
);

SELECT sql_test.assert_relation_exists(
    'Approval Request dependency relation exists',
    'approval.approval_request_dependencies'
);

SELECT sql_test.assert_true(
    'Approval Request dependencies prohibit self-reference',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'approval.approval_request_dependencies'::regclass
          AND conname = 'approval_request_dependencies_not_self_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Approval Request dependency types are constrained',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'approval.approval_request_dependencies'::regclass
          AND conname = 'approval_request_dependencies_type_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Approval Action Records expose a generated effective actor identity',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_actions'
          AND column_name = 'effective_actor_identity_id'
          AND is_generated = 'ALWAYS'
    )
);

SELECT sql_test.assert_true(
    'Approval Action Records bind acting session and Authority Grant',
    (
        SELECT count(*) = 2
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_actions'
          AND column_name IN (
              'acting_session_id',
              'authority_grant_id'
          )
    )
);

SELECT sql_test.assert_true(
    'Approval Action Records have typed prior-action lineage',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_actions'
          AND column_name = 'prior_approval_action_id'
    )
);

SELECT sql_test.assert_true(
    'Approval Action prior-action lineage prohibits self-reference',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'approval.approval_actions'::regclass
          AND conname = 'approval_actions_prior_not_self_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_relation_exists(
    'Approval duty-definition relation exists',
    'approval.approval_duty_definitions'
);

SELECT sql_test.assert_equal_bigint(
    'Initial Phase 4 duty catalog contains nine governed duties',
    (
        SELECT count(*)
        FROM approval.approval_duty_definitions
        WHERE status = 'ACTIVE'
    ),
    9
);

SELECT sql_test.assert_no_rows(
    'Initial Phase 4 duty keys are complete',
    $$
    SELECT expected.duty_key
    FROM (
        VALUES
            ('REQUEST'),
            ('APPROVE'),
            ('GRANT_AUTHORITY'),
            ('EXECUTE'),
            ('FINALIZE_APPROVAL'),
            ('ADMINISTER_POLICY'),
            ('AUDIT'),
            ('ACCEPT_RISK'),
            ('AUTHORIZE_EXCEPTION')
    ) AS expected(duty_key)
    LEFT JOIN approval.approval_duty_definitions AS actual
      ON actual.duty_key = expected.duty_key
    WHERE actual.duty_key IS NULL
    $$
);

SELECT sql_test.assert_relation_exists(
    'Policy-prohibited duty-combination relation exists',
    'approval.approval_policy_prohibited_duty_combinations'
);

SELECT sql_test.assert_true(
    'Policy-prohibited duty pairs use canonical ordering',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'approval.approval_policy_prohibited_duty_combinations'::regclass
          AND conname = 'approval_policy_prohibited_duties_order_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_relation_exists(
    'Approval Action duty relation exists',
    'approval.approval_action_duties'
);

SELECT sql_test.assert_true(
    'Incompatible Authority Sets have a default enforcement mode',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'incompatible_authority_sets'
          AND column_name = 'default_enforcement_mode'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Incompatible Authority Sets govern delegated grants',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'incompatible_authority_sets'
          AND column_name = 'include_delegated_grants'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_relation_exists(
    'Persisted approval stage-evaluation relation exists',
    'approval.approval_stage_evaluations'
);

SELECT sql_test.assert_true(
    'Persisted stage evaluations retain one captured evaluation time',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'approval'
          AND table_name = 'approval_stage_evaluations'
          AND column_name = 'evaluated_at'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Persisted stage-evaluation results are constrained',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'approval.approval_stage_evaluations'::regclass
          AND conname = 'approval_stage_evaluations_result_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Persisted stage-evaluation counts are constrained',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'approval.approval_stage_evaluations'::regclass
          AND conname = 'approval_stage_evaluations_counts_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_relation_exists(
    'Stage-evaluation Approval Action linkage exists',
    'approval.approval_stage_evaluation_actions'
);

SELECT sql_test.assert_true(
    'Stage-evaluation action exclusions are explicitly shaped',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'approval.approval_stage_evaluation_actions'::regclass
          AND conname = 'approval_stage_evaluation_actions_exclusion_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Phase 4 Approval Request context index is valid',
    EXISTS (
        SELECT 1
        FROM pg_index AS index_record
        JOIN pg_class AS index_relation
          ON index_relation.oid = index_record.indexrelid
        WHERE index_record.indrelid =
            'approval.approval_requests'::regclass
          AND index_relation.relname = 'approval_requests_phase4_context_idx'
          AND index_record.indisvalid
          AND index_record.indisready
    )
);

SELECT sql_test.assert_true(
    'Phase 4 Approval Action actor index is valid',
    EXISTS (
        SELECT 1
        FROM pg_index AS index_record
        JOIN pg_class AS index_relation
          ON index_relation.oid = index_record.indexrelid
        WHERE index_record.indrelid =
            'approval.approval_actions'::regclass
          AND index_relation.relname = 'approval_actions_phase4_actor_idx'
          AND index_record.indisvalid
          AND index_record.indisready
    )
);

SELECT sql_test.assert_true(
    'Phase 4 stage-evaluation index is valid',
    EXISTS (
        SELECT 1
        FROM pg_index AS index_record
        JOIN pg_class AS index_relation
          ON index_relation.oid = index_record.indexrelid
        WHERE index_record.indrelid =
            'approval.approval_stage_evaluations'::regclass
          AND index_relation.relname =
            'approval_stage_evaluations_request_idx'
          AND index_record.indisvalid
          AND index_record.indisready
    )
);

SELECT sql_test.assert_no_rows(
    'PUBLIC cannot access Phase 4 approval structure directly',
    $$
    SELECT table_schema, table_name, privilege_type
    FROM information_schema.role_table_grants
    WHERE grantee = 'PUBLIC'
      AND table_schema = 'approval'
      AND table_name IN (
          'approval_request_dependencies',
          'approval_duty_definitions',
          'approval_policy_prohibited_duty_combinations',
          'approval_action_duties',
          'approval_stage_evaluations',
          'approval_stage_evaluation_actions'
      )
    $$
);
