-- ============================================================================
-- Migration: 081_postgresql_authorization_decision_and_lease_issuance.sql
-- Title: PostgreSQL authorization decision and lease issuance structure
-- Layer: Platform Foundation
-- Status: PHASE 3 STEP 2 IMPLEMENTATION CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================
--
-- Purpose:
-- Establish the typed relational boundary required before controlled
-- authorization policy selection, Decision Record finalization, and
-- Authorization Lease issuance are implemented.
--
-- Step 2 intentionally adds no controlled production function. Phase 3
-- Steps 3 and 4 implement behavior against the structure established here.
--
-- Accepted-boundary rule:
-- Migrations 055, 060, 065, 070, 072, 075, and 080 remain unchanged.
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
        WHERE migration_id = '080_decision_record_repository'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 080_decision_record_repository is not registered';
    END IF;
END;
$dependency_check$;

-- ---------------------------------------------------------------------------
-- Deterministic Authorization Policy Version applicability structure
-- ---------------------------------------------------------------------------

ALTER TABLE access_control.authorization_policy_versions
    ADD COLUMN requester_organization_id uuid
        REFERENCES organization.organizations(organization_id),
    ADD COLUMN governed_scope_id uuid
        REFERENCES organization.governed_scopes(governed_scope_id),
    ADD COLUMN applies_to_all_governed_scopes boolean
        NOT NULL DEFAULT false,
    ADD COLUMN protected_target_type text,
    ADD COLUMN protected_target_reference text,
    ADD COLUMN applies_to_all_targets boolean
        NOT NULL DEFAULT false,
    ADD COLUMN classification_key text,
    ADD COLUMN lease_audience text,
    ADD COLUMN selection_priority integer
        NOT NULL DEFAULT 100,
    ADD CONSTRAINT authorization_policy_versions_scope_exclusive_ck
        CHECK (
            NOT (
                governed_scope_id IS NOT NULL
                AND applies_to_all_governed_scopes
            )
        ),
    ADD CONSTRAINT authorization_policy_versions_scope_requirement_ck
        CHECK (
            NOT governed_scope_required
            OR governed_scope_id IS NOT NULL
            OR applies_to_all_governed_scopes
        ),
    ADD CONSTRAINT authorization_policy_versions_target_pair_ck
        CHECK (
            (
                protected_target_type IS NULL
                AND protected_target_reference IS NULL
            )
            OR
            (
                protected_target_type IS NOT NULL
                AND protected_target_reference IS NOT NULL
                AND protected_target_type ~ '^[A-Z][A-Z0-9_]*$'
                AND btrim(protected_target_reference) <> ''
            )
        ),
    ADD CONSTRAINT authorization_policy_versions_target_exclusive_ck
        CHECK (
            NOT (
                applies_to_all_targets
                AND protected_target_type IS NOT NULL
            )
        ),
    ADD CONSTRAINT authorization_policy_versions_target_requirement_ck
        CHECK (
            NOT protected_target_required
            OR applies_to_all_targets
            OR protected_target_type IS NOT NULL
        ),
    ADD CONSTRAINT authorization_policy_versions_classification_key_ck
        CHECK (
            classification_key IS NULL
            OR classification_key ~ '^[A-Z][A-Z0-9_]*$'
        ),
    ADD CONSTRAINT authorization_policy_versions_lease_audience_ck
        CHECK (
            lease_audience IS NULL
            OR btrim(lease_audience) <> ''
        ),
    ADD CONSTRAINT authorization_policy_versions_priority_ck
        CHECK (selection_priority > 0);

COMMENT ON COLUMN
    access_control.authorization_policy_versions.requester_organization_id IS
    'Optional exact requester-organization applicability for deterministic policy selection.';

COMMENT ON COLUMN
    access_control.authorization_policy_versions.governed_scope_id IS
    'Optional exact Governed Scope applicability. This is distinct from governed_scope_required.';

COMMENT ON COLUMN
    access_control.authorization_policy_versions.selection_priority IS
    'Explicit deterministic precedence after applicability and specificity are established. Lower values sort before higher values; equal applicable precedence remains ambiguous and must fail closed.';

CREATE INDEX authorization_policy_versions_phase3_lookup_idx
    ON access_control.authorization_policy_versions(
        decision_class,
        service_id,
        purpose_definition_id,
        operation_definition_id,
        requester_organization_id,
        governed_scope_id,
        protected_target_type,
        classification_key,
        status,
        selection_priority,
        valid_from,
        valid_until
    );

-- ---------------------------------------------------------------------------
-- Exact policy-stage rule structure
-- ---------------------------------------------------------------------------

ALTER TABLE access_control.authorization_policy_stage_requirements
    ADD COLUMN not_required_reason_code text,
    ADD COLUMN not_required_rule_reference text,
    ADD COLUMN supporting_record_required boolean
        NOT NULL DEFAULT true,
    ADD CONSTRAINT authorization_policy_stage_not_required_rule_ck
        CHECK (
            (
                required
                AND not_required_reason_code IS NULL
                AND not_required_rule_reference IS NULL
            )
            OR
            (
                NOT required
                AND not_required_reason_code IS NOT NULL
                AND not_required_rule_reference IS NOT NULL
                AND not_required_reason_code ~ '^[A-Z][A-Z0-9_]*$'
                AND btrim(not_required_rule_reference) <> ''
            )
        ),
    ADD CONSTRAINT authorization_policy_stage_mapping_uq
        UNIQUE (
            authorization_policy_stage_requirement_id,
            authorization_policy_version_id,
            stage_order,
            stage_key,
            required
        );

COMMENT ON COLUMN
    access_control.authorization_policy_stage_requirements.not_required_reason_code IS
    'Stable reason code proving why an optional stage may resolve as NOT_REQUIRED.';

COMMENT ON COLUMN
    access_control.authorization_policy_stage_requirements.not_required_rule_reference IS
    'Exact policy-rule or governed-document reference supporting NOT_REQUIRED.';

COMMENT ON COLUMN
    access_control.authorization_policy_stage_requirements.supporting_record_required IS
    'Whether a terminal result for this stage must cite at least one supporting record before an ALLOW decision may be finalized.';

-- ---------------------------------------------------------------------------
-- Typed authorization and lease-request Decision Record fields
-- ---------------------------------------------------------------------------

ALTER TABLE decision.decision_records
    ADD COLUMN expected_authorization_policy_version_id uuid
        REFERENCES access_control.authorization_policy_versions(
            authorization_policy_version_id
        ),
    ADD COLUMN requested_lease_lifetime interval,
    ADD COLUMN requested_use_mode text,
    ADD COLUMN requested_usage_limit integer,
    ADD COLUMN lease_audience text,
    ADD CONSTRAINT decision_records_lease_request_shape_ck
        CHECK (
            (
                decision_class IN ('LEASE_ISSUANCE', 'LEASE_RENEWAL')
                AND requester_identity_id IS NOT NULL
                AND session_id IS NOT NULL
                AND service_id IS NOT NULL
                AND requested_lease_lifetime IS NOT NULL
                AND requested_lease_lifetime > interval '0 seconds'
                AND requested_use_mode IS NOT NULL
                AND requested_use_mode IN (
                    'REUSABLE',
                    'SINGLE_USE',
                    'LIMITED_USE'
                )
                AND (
                    (
                        requested_use_mode = 'REUSABLE'
                        AND requested_usage_limit IS NULL
                    )
                    OR
                    (
                        requested_use_mode = 'SINGLE_USE'
                        AND requested_usage_limit = 1
                    )
                    OR
                    (
                        requested_use_mode = 'LIMITED_USE'
                        AND requested_usage_limit IS NOT NULL
                        AND requested_usage_limit > 1
                    )
                )
                AND lease_audience IS NOT NULL
                AND btrim(lease_audience) <> ''
            )
            OR
            (
                decision_class NOT IN ('LEASE_ISSUANCE', 'LEASE_RENEWAL')
                AND requested_lease_lifetime IS NULL
                AND requested_use_mode IS NULL
                AND requested_usage_limit IS NULL
                AND lease_audience IS NULL
            )
        ),
    ADD CONSTRAINT decision_records_decision_policy_uq
        UNIQUE (decision_id, authorization_policy_version_id),
    ADD CONSTRAINT decision_records_core_lease_context_uq
        UNIQUE (
            decision_id,
            request_id,
            correlation_id,
            requester_identity_id,
            session_id,
            service_id,
            operation_definition_id,
            authorization_policy_version_id
        );

COMMENT ON COLUMN
    decision.decision_records.expected_authorization_policy_version_id IS
    'Optional caller expectation that PostgreSQL must independently confirm as the unique applicable policy version.';

COMMENT ON COLUMN decision.decision_records.requested_lease_lifetime IS
    'Requested lifetime only. Controlled issuance must bound it to policy, session, authority, eligibility, approval, participation, and security limits.';

COMMENT ON COLUMN decision.decision_records.lease_audience IS
    'Requested exact protected consumer audience for a lease-issuance or lease-renewal decision.';

CREATE INDEX decision_records_phase3_request_idx
    ON decision.decision_records(
        decision_class,
        expected_authorization_policy_version_id,
        requester_identity_id,
        requester_organization_id,
        session_id,
        service_id,
        purpose_definition_id,
        operation_definition_id,
        governed_scope_id,
        record_status,
        requested_at
    );

-- ---------------------------------------------------------------------------
-- Exact evaluation-to-policy-stage mapping
-- ---------------------------------------------------------------------------

ALTER TABLE decision.evaluation_records
    ADD COLUMN authorization_policy_version_id uuid,
    ADD COLUMN authorization_policy_stage_requirement_id uuid,
    ADD COLUMN policy_rule_reference text,
    ADD CONSTRAINT evaluation_records_policy_mapping_pair_ck
        CHECK (
            (
                authorization_policy_version_id IS NULL
                AND authorization_policy_stage_requirement_id IS NULL
            )
            OR
            (
                authorization_policy_version_id IS NOT NULL
                AND authorization_policy_stage_requirement_id IS NOT NULL
            )
        ),
    ADD CONSTRAINT evaluation_records_policy_rule_reference_ck
        CHECK (
            policy_rule_reference IS NULL
            OR btrim(policy_rule_reference) <> ''
        ),
    ADD CONSTRAINT evaluation_records_not_required_rule_ck
        CHECK (
            result <> 'NOT_REQUIRED'
            OR (
                NOT required
                AND authorization_policy_stage_requirement_id IS NOT NULL
                AND policy_rule_reference IS NOT NULL
            )
        ),
    ADD CONSTRAINT evaluation_records_decision_policy_fk
        FOREIGN KEY (decision_id, authorization_policy_version_id)
        REFERENCES decision.decision_records(
            decision_id,
            authorization_policy_version_id
        ),
    ADD CONSTRAINT evaluation_records_stage_requirement_fk
        FOREIGN KEY (
            authorization_policy_stage_requirement_id,
            authorization_policy_version_id,
            evaluation_order,
            evaluation_key,
            required
        )
        REFERENCES access_control.authorization_policy_stage_requirements(
            authorization_policy_stage_requirement_id,
            authorization_policy_version_id,
            stage_order,
            stage_key,
            required
        ),
    ADD CONSTRAINT evaluation_records_id_decision_uq
        UNIQUE (evaluation_id, decision_id);

COMMENT ON COLUMN
    decision.evaluation_records.authorization_policy_stage_requirement_id IS
    'Exact policy-stage requirement governing this evaluation. Bootstrap request-context and policy-selection evaluations may remain unbound.';

COMMENT ON COLUMN decision.evaluation_records.policy_rule_reference IS
    'Exact selected policy rule used by this result. It is required for NOT_REQUIRED.';

CREATE INDEX evaluation_records_policy_stage_idx
    ON decision.evaluation_records(
        authorization_policy_version_id,
        authorization_policy_stage_requirement_id,
        decision_id,
        evaluation_order
    );

ALTER TABLE decision.supporting_records
    ADD COLUMN required_for_result boolean
        NOT NULL DEFAULT true;

CREATE UNIQUE INDEX supporting_records_evidence_identity_uq
    ON decision.supporting_records(
        evaluation_id,
        record_type,
        record_id,
        COALESCE(record_version, '')
    );

-- ---------------------------------------------------------------------------
-- Authorization Lease typed bindings, chronology, and terminal-state shape
-- ---------------------------------------------------------------------------

ALTER TABLE access_control.authorization_leases
    ADD COLUMN not_before timestamptz,
    ADD COLUMN lease_audience text,
    ADD COLUMN expired_at timestamptz;

ALTER TABLE access_control.authorization_leases
    ALTER COLUMN issuing_decision_id SET NOT NULL,
    ALTER COLUMN service_id SET NOT NULL,
    ALTER COLUMN operation_definition_id SET NOT NULL,
    ALTER COLUMN not_before SET NOT NULL,
    ALTER COLUMN lease_audience SET NOT NULL,
    ADD CONSTRAINT authorization_leases_scope_reference_retired_ck
        CHECK (scope_reference IS NULL),
    ADD CONSTRAINT authorization_leases_audience_ck
        CHECK (btrim(lease_audience) <> ''),
    ADD CONSTRAINT authorization_leases_chronology_ck
        CHECK (
            not_before >= issued_at
            AND not_before < expires_at
            AND (
                consumed_at IS NULL
                OR (
                    consumed_at >= not_before
                    AND consumed_at < expires_at
                )
            )
            AND (
                revoked_at IS NULL
                OR revoked_at >= issued_at
            )
            AND (
                expired_at IS NULL
                OR expired_at >= expires_at
            )
        ),
    ADD CONSTRAINT authorization_leases_state_shape_ck
        CHECK (
            (
                status = 'ACTIVE'
                AND consumed_at IS NULL
                AND revoked_at IS NULL
                AND expired_at IS NULL
            )
            OR
            (
                status = 'CONSUMED'
                AND consumed_at IS NOT NULL
                AND revoked_at IS NULL
                AND expired_at IS NULL
                AND use_mode IN ('SINGLE_USE', 'LIMITED_USE')
                AND usage_limit IS NOT NULL
                AND successful_use_count = usage_limit
            )
            OR
            (
                status = 'REVOKED'
                AND consumed_at IS NULL
                AND revoked_at IS NOT NULL
                AND expired_at IS NULL
            )
            OR
            (
                status = 'EXPIRED'
                AND consumed_at IS NULL
                AND revoked_at IS NULL
                AND expired_at IS NOT NULL
            )
        ),
    ADD CONSTRAINT authorization_leases_revocation_reason_ck
        CHECK (
            (
                status = 'REVOKED'
                AND revocation_reason IS NOT NULL
                AND btrim(revocation_reason) <> ''
            )
            OR
            (
                status <> 'REVOKED'
                AND revocation_reason IS NULL
            )
        ),
    ADD CONSTRAINT authorization_leases_issuing_decision_uq
        UNIQUE (issuing_decision_id),
    ADD CONSTRAINT authorization_leases_id_decision_uq
        UNIQUE (authorization_lease_id, issuing_decision_id),
    ADD CONSTRAINT authorization_leases_decision_context_fk
        FOREIGN KEY (
            issuing_decision_id,
            request_id,
            correlation_id,
            identity_id,
            session_id,
            service_id,
            operation_definition_id,
            authorization_policy_version_id
        )
        REFERENCES decision.decision_records(
            decision_id,
            request_id,
            correlation_id,
            requester_identity_id,
            session_id,
            service_id,
            operation_definition_id,
            authorization_policy_version_id
        );

COMMENT ON COLUMN access_control.authorization_leases.not_before IS
    'Authoritative earliest usability time. Controlled issuance must set it from PostgreSQL time and keep it before expires_at.';

COMMENT ON COLUMN access_control.authorization_leases.lease_audience IS
    'Exact protected consumer audience bound to this lease.';

COMMENT ON COLUMN access_control.authorization_leases.expired_at IS
    'Materialized expiration transition time. PostgreSQL time can make a lease unusable before this field is populated.';

CREATE UNIQUE INDEX decision_records_authorization_lease_uq
    ON decision.decision_records(authorization_lease_id)
    WHERE authorization_lease_id IS NOT NULL;

CREATE INDEX authorization_leases_phase3_context_idx
    ON access_control.authorization_leases(
        issuing_decision_id,
        identity_id,
        requester_organization_id,
        session_id,
        device_id,
        service_id,
        purpose_definition_id,
        operation_definition_id,
        governed_scope_id,
        authorization_policy_version_id,
        status,
        not_before,
        expires_at
    );

-- ---------------------------------------------------------------------------
-- Lease authority evidence and use-event Decision Record binding
-- ---------------------------------------------------------------------------

ALTER TABLE access_control.lease_authority_grants
    ADD COLUMN decision_id uuid,
    ADD COLUMN evaluation_id uuid;

ALTER TABLE access_control.lease_authority_grants
    ALTER COLUMN decision_id SET NOT NULL,
    ALTER COLUMN evaluation_id SET NOT NULL,
    ADD CONSTRAINT lease_authority_grants_decision_fk
        FOREIGN KEY (decision_id)
        REFERENCES decision.decision_records(decision_id),
    ADD CONSTRAINT lease_authority_grants_lease_decision_fk
        FOREIGN KEY (authorization_lease_id, decision_id)
        REFERENCES access_control.authorization_leases(
            authorization_lease_id,
            issuing_decision_id
        ),
    ADD CONSTRAINT lease_authority_grants_evaluation_decision_fk
        FOREIGN KEY (evaluation_id, decision_id)
        REFERENCES decision.evaluation_records(
            evaluation_id,
            decision_id
        );

COMMENT ON COLUMN access_control.lease_authority_grants.evaluation_id IS
    'Exact AUTHORITY evaluation record that cited this grant for the issuing decision.';

ALTER TABLE access_control.authorization_lease_use_events
    ALTER COLUMN decision_reference SET NOT NULL,
    ADD CONSTRAINT authorization_lease_use_events_decision_fk
        FOREIGN KEY (decision_reference)
        REFERENCES decision.decision_records(decision_id);

CREATE INDEX authorization_lease_use_events_decision_idx
    ON access_control.authorization_lease_use_events(
        decision_reference,
        authorization_lease_id,
        used_at
    );

SELECT foundation_meta.register_migration(
    p_migration_id => '081_postgresql_authorization_decision_and_lease_issuance',
    p_migration_name => 'PostgreSQL authorization decision and lease issuance structure',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Added typed policy applicability, exact policy-stage mapping, lease-request Decision Record fields, one-decision/one-lease cardinality, core decision-to-lease context binding, lease chronology and state shape, and attributable authority and use evidence.'
);

COMMIT;
