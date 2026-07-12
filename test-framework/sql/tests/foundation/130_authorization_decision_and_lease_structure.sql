-- ============================================================================
-- Phase 3 Step 2 authorization decision and lease structure
-- ============================================================================
--
-- Purpose:
-- Prove the typed relational structure, constraints, foreign keys, indexes,
-- and cardinality boundaries added by migration 081.
--
-- Controlled policy selection, Decision Record finalization, Authorization
-- Lease issuance, and lease consumption remain later Phase 3 steps.
-- ============================================================================

SELECT sql_test.begin_file(
    '130_authorization_decision_and_lease_structure.sql'
);

SELECT sql_test.assert_true(
    'Migration 081 is registered',
    EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id =
            '081_postgresql_authorization_decision_and_lease_issuance'
    )
);

SELECT sql_test.assert_true(
    'Policy Versions have requester-organization applicability',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_policy_versions'
          AND column_name = 'requester_organization_id'
    )
);

SELECT sql_test.assert_true(
    'Policy Versions have exact Governed Scope applicability',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_policy_versions'
          AND column_name = 'governed_scope_id'
    )
);

SELECT sql_test.assert_true(
    'Policy Versions can apply to all Governed Scopes',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_policy_versions'
          AND column_name = 'applies_to_all_governed_scopes'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Policy Versions have typed Protected Resource Target columns',
    (
        SELECT count(*) = 2
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_policy_versions'
          AND column_name IN (
              'protected_target_type',
              'protected_target_reference'
          )
    )
);

SELECT sql_test.assert_true(
    'Policy Versions can apply to all Protected Resource Targets',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_policy_versions'
          AND column_name = 'applies_to_all_targets'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Policy Versions have classification applicability',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_policy_versions'
          AND column_name = 'classification_key'
    )
);

SELECT sql_test.assert_true(
    'Policy Versions have lease-audience applicability',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_policy_versions'
          AND column_name = 'lease_audience'
    )
);

SELECT sql_test.assert_true(
    'Policy Versions have explicit selection priority',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_policy_versions'
          AND column_name = 'selection_priority'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Phase 3 policy lookup index is valid',
    EXISTS (
        SELECT 1
        FROM pg_index AS index_record
        JOIN pg_class AS index_relation
          ON index_relation.oid = index_record.indexrelid
        WHERE index_record.indrelid =
            'access_control.authorization_policy_versions'::regclass
          AND index_relation.relname =
            'authorization_policy_versions_phase3_lookup_idx'
          AND index_record.indisvalid
          AND index_record.indisready
    )
);

SELECT sql_test.assert_true(
    'Policy Governed Scope applicability is mutually exclusive',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_policy_versions'::regclass
          AND conname =
            'authorization_policy_versions_scope_exclusive_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Required Governed Scope applicability has an explicit boundary',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_policy_versions'::regclass
          AND conname =
            'authorization_policy_versions_scope_requirement_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Policy Protected Resource Target pairs are structurally valid',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_policy_versions'::regclass
          AND conname =
            'authorization_policy_versions_target_pair_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Policy target applicability is mutually exclusive',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_policy_versions'::regclass
          AND conname =
            'authorization_policy_versions_target_exclusive_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Required target applicability has an explicit boundary',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_policy_versions'::regclass
          AND conname =
            'authorization_policy_versions_target_requirement_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Policy classification keys are typed',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_policy_versions'::regclass
          AND conname =
            'authorization_policy_versions_classification_key_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Policy lease audiences cannot be empty',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_policy_versions'::regclass
          AND conname =
            'authorization_policy_versions_lease_audience_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Policy selection priority is positive',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_policy_versions'::regclass
          AND conname = 'authorization_policy_versions_priority_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Policy stages retain a NOT_REQUIRED reason code',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_policy_stage_requirements'
          AND column_name = 'not_required_reason_code'
    )
);

SELECT sql_test.assert_true(
    'Policy stages retain a NOT_REQUIRED rule reference',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_policy_stage_requirements'
          AND column_name = 'not_required_rule_reference'
    )
);

SELECT sql_test.assert_true(
    'Policy stages identify whether supporting records are required',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_policy_stage_requirements'
          AND column_name = 'supporting_record_required'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Optional policy stages require an exact NOT_REQUIRED rule',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_policy_stage_requirements'::regclass
          AND conname =
            'authorization_policy_stage_not_required_rule_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Policy-stage mappings have a composite uniqueness boundary',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_policy_stage_requirements'::regclass
          AND conname = 'authorization_policy_stage_mapping_uq'
          AND contype = 'u'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Decision Records retain the expected policy version',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'decision'
          AND table_name = 'decision_records'
          AND column_name =
            'expected_authorization_policy_version_id'
    )
);

SELECT sql_test.assert_true(
    'Decision Records retain requested lease lifetime',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'decision'
          AND table_name = 'decision_records'
          AND column_name = 'requested_lease_lifetime'
    )
);

SELECT sql_test.assert_true(
    'Decision Records retain requested lease use mode',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'decision'
          AND table_name = 'decision_records'
          AND column_name = 'requested_use_mode'
    )
);

SELECT sql_test.assert_true(
    'Decision Records retain requested lease usage limit',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'decision'
          AND table_name = 'decision_records'
          AND column_name = 'requested_usage_limit'
    )
);

SELECT sql_test.assert_true(
    'Decision Records retain exact lease audience',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'decision'
          AND table_name = 'decision_records'
          AND column_name = 'lease_audience'
    )
);

SELECT sql_test.assert_true(
    'Lease request fields have one typed shape constraint',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'decision.decision_records'::regclass
          AND conname = 'decision_records_lease_request_shape_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Decision and selected policy have a composite uniqueness boundary',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'decision.decision_records'::regclass
          AND conname = 'decision_records_decision_policy_uq'
          AND contype = 'u'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Decision core lease context has a composite uniqueness boundary',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'decision.decision_records'::regclass
          AND conname = 'decision_records_core_lease_context_uq'
          AND contype = 'u'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Decision request lookup index is valid',
    EXISTS (
        SELECT 1
        FROM pg_index AS index_record
        JOIN pg_class AS index_relation
          ON index_relation.oid = index_record.indexrelid
        WHERE index_record.indrelid =
            'decision.decision_records'::regclass
          AND index_relation.relname =
            'decision_records_phase3_request_idx'
          AND index_record.indisvalid
          AND index_record.indisready
    )
);

SELECT sql_test.assert_true(
    'Evaluation Records retain the selected policy version',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'decision'
          AND table_name = 'evaluation_records'
          AND column_name = 'authorization_policy_version_id'
    )
);

SELECT sql_test.assert_true(
    'Evaluation Records retain the exact policy-stage requirement',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'decision'
          AND table_name = 'evaluation_records'
          AND column_name =
            'authorization_policy_stage_requirement_id'
    )
);

SELECT sql_test.assert_true(
    'Evaluation Records retain the exact policy-rule reference',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'decision'
          AND table_name = 'evaluation_records'
          AND column_name = 'policy_rule_reference'
    )
);

SELECT sql_test.assert_true(
    'Evaluation policy and stage columns form an atomic pair',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'decision.evaluation_records'::regclass
          AND conname =
            'evaluation_records_policy_mapping_pair_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'NOT_REQUIRED evaluations require an exact policy rule',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'decision.evaluation_records'::regclass
          AND conname = 'evaluation_records_not_required_rule_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Evaluation policy binding references its Decision Record',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'decision.evaluation_records'::regclass
          AND conname = 'evaluation_records_decision_policy_fk'
          AND contype = 'f'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Evaluation stage mapping references the exact policy stage',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'decision.evaluation_records'::regclass
          AND conname = 'evaluation_records_stage_requirement_fk'
          AND contype = 'f'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Evaluation identity is unique within its Decision Record',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'decision.evaluation_records'::regclass
          AND conname = 'evaluation_records_id_decision_uq'
          AND contype = 'u'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Evaluation policy-stage lookup index is valid',
    EXISTS (
        SELECT 1
        FROM pg_index AS index_record
        JOIN pg_class AS index_relation
          ON index_relation.oid = index_record.indexrelid
        WHERE index_record.indrelid =
            'decision.evaluation_records'::regclass
          AND index_relation.relname =
            'evaluation_records_policy_stage_idx'
          AND index_record.indisvalid
          AND index_record.indisready
    )
);

SELECT sql_test.assert_true(
    'Supporting Records identify whether evidence is required',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'decision'
          AND table_name = 'supporting_records'
          AND column_name = 'required_for_result'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Supporting Record identity is unique within an evaluation',
    EXISTS (
        SELECT 1
        FROM pg_index AS index_record
        JOIN pg_class AS index_relation
          ON index_relation.oid = index_record.indexrelid
        WHERE index_record.indrelid =
            'decision.supporting_records'::regclass
          AND index_relation.relname =
            'supporting_records_evidence_identity_uq'
          AND index_record.indisunique
          AND index_record.indisvalid
    )
);

SELECT sql_test.assert_true(
    'Authorization Leases require explicit not-before time',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_leases'
          AND column_name = 'not_before'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Authorization Leases require an exact audience',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_leases'
          AND column_name = 'lease_audience'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Authorization Leases retain materialized expiration time',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_leases'
          AND column_name = 'expired_at'
    )
);

SELECT sql_test.assert_true(
    'Authorization Leases require decision service and operation bindings',
    (
        SELECT count(*) = 3
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_leases'
          AND column_name IN (
              'issuing_decision_id',
              'service_id',
              'operation_definition_id'
          )
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Legacy lease scope-reference writes are retired',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_leases'::regclass
          AND conname =
            'authorization_leases_scope_reference_retired_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Authorization Lease audience is nonempty',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_leases'::regclass
          AND conname = 'authorization_leases_audience_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Authorization Lease chronology is constrained',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_leases'::regclass
          AND conname = 'authorization_leases_chronology_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Authorization Lease terminal-state shape is constrained',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_leases'::regclass
          AND conname = 'authorization_leases_state_shape_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Authorization Lease revocation reason follows revocation state',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_leases'::regclass
          AND conname =
            'authorization_leases_revocation_reason_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'One Decision Record may issue at most one Authorization Lease',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_leases'::regclass
          AND conname =
            'authorization_leases_issuing_decision_uq'
          AND contype = 'u'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Authorization Lease exposes a lease-decision composite key',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_leases'::regclass
          AND conname =
            'authorization_leases_id_decision_uq'
          AND contype = 'u'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Authorization Lease core context is bound to its issuing Decision Record',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_leases'::regclass
          AND conname =
            'authorization_leases_decision_context_fk'
          AND contype = 'f'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Each lease has at most one issuing or renewing Decision Record',
    EXISTS (
        SELECT 1
        FROM pg_index AS index_record
        JOIN pg_class AS index_relation
          ON index_relation.oid = index_record.indexrelid
        WHERE index_record.indrelid =
            'decision.decision_records'::regclass
          AND index_relation.relname =
            'decision_records_authorization_lease_uq'
          AND index_record.indisunique
          AND index_record.indisvalid
          AND pg_get_expr(
              index_record.indpred,
              index_record.indrelid
          ) LIKE '%LEASE_ISSUANCE%'
          AND pg_get_expr(
              index_record.indpred,
              index_record.indrelid
          ) LIKE '%LEASE_RENEWAL%'
    )
);

SELECT sql_test.assert_true(
    'Authorization Lease Phase 3 context index is valid',
    EXISTS (
        SELECT 1
        FROM pg_index AS index_record
        JOIN pg_class AS index_relation
          ON index_relation.oid = index_record.indexrelid
        WHERE index_record.indrelid =
            'access_control.authorization_leases'::regclass
          AND index_relation.relname =
            'authorization_leases_phase3_context_idx'
          AND index_record.indisvalid
          AND index_record.indisready
    )
);

SELECT sql_test.assert_true(
    'Lease Authority evidence retains decision and evaluation identities',
    (
        SELECT count(*) = 2
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'lease_authority_grants'
          AND column_name IN ('decision_id', 'evaluation_id')
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Lease Authority evidence is relationally bound to decision and evaluation',
    (
        SELECT count(*) = 3
        FROM pg_constraint
        WHERE conrelid =
            'access_control.lease_authority_grants'::regclass
          AND conname IN (
              'lease_authority_grants_decision_fk',
              'lease_authority_grants_lease_decision_fk',
              'lease_authority_grants_evaluation_decision_fk'
          )
          AND contype = 'f'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Lease use events require and reference a Decision Record',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authorization_lease_use_events'
          AND column_name = 'decision_reference'
          AND is_nullable = 'NO'
    )
    AND EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'access_control.authorization_lease_use_events'::regclass
          AND conname =
            'authorization_lease_use_events_decision_fk'
          AND contype = 'f'
          AND convalidated
    )
);
