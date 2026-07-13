-- ============================================================================
-- Migration: 080_decision_record_repository.sql
-- Title: Decision Record Repository
-- Layer: Platform Foundation
-- Status: REVIEW CANDIDATE
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
        WHERE migration_id = '075_controlled_authorization_api'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 075_controlled_authorization_api is not registered';
    END IF;
END;
$dependency_check$;

CREATE TABLE decision.decision_records (
    decision_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_decision_id uuid
        REFERENCES decision.decision_records(decision_id),
    request_id uuid NOT NULL UNIQUE,
    correlation_id uuid NOT NULL,
    decision_class text NOT NULL,
    requester_identity_id uuid
        REFERENCES identity.identities(identity_id),
    requester_organization_id uuid
        REFERENCES organization.organizations(organization_id),
    device_id uuid
        REFERENCES trust.devices(device_id),
    session_id uuid
        REFERENCES access_control.sessions(session_id),
    authentication_assertion_id uuid
        REFERENCES access_control.authentication_assertions(authentication_assertion_id),
    authorization_lease_id uuid
        REFERENCES access_control.authorization_leases(authorization_lease_id),
    approval_request_id uuid
        REFERENCES approval.approval_requests(approval_request_id),
    authorization_policy_version_id uuid
        REFERENCES access_control.authorization_policy_versions(authorization_policy_version_id),
    service_id uuid
        REFERENCES service.platform_services(service_id),
    purpose_definition_id uuid
        REFERENCES access_control.purpose_definitions(purpose_definition_id),
    operation_definition_id uuid NOT NULL,
    operation_key text NOT NULL,
    protected_target_type text NOT NULL,
    protected_target_reference text NOT NULL,
    governed_scope_id uuid
        REFERENCES organization.governed_scopes(governed_scope_id),
    classification_key text,
    record_status text NOT NULL DEFAULT 'DRAFT',
    final_result text,
    primary_reason_code text,
    requested_at timestamptz NOT NULL,
    evaluated_at timestamptz NOT NULL,
    finalized_at timestamptz,
    evaluator_name text NOT NULL,
    evaluator_version text NOT NULL,
    database_schema_version text NOT NULL,
    context_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    record_hash bytea,
    previous_record_hash bytea,
    CONSTRAINT decision_records_class_ck
        CHECK (
            decision_class IN (
                'SESSION_ESTABLISHMENT',
                'SESSION_STEP_UP',
                'LEASE_ISSUANCE',
                'LEASE_RENEWAL',
                'PROTECTED_OPERATION',
                'SECURITY_REVOCATION'
            )
        ),
    CONSTRAINT decision_records_operation_key_ck
        CHECK (operation_key ~ '^[a-z][a-z0-9_.-]*$'),
    CONSTRAINT decision_records_operation_definition_fk
        FOREIGN KEY (operation_definition_id, operation_key)
        REFERENCES access_control.operation_definitions(
            operation_definition_id,
            operation_key
        ),
    CONSTRAINT decision_records_target_type_ck
        CHECK (protected_target_type ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT decision_records_target_reference_ck
        CHECK (btrim(protected_target_reference) <> ''),
    CONSTRAINT decision_records_classification_key_ck
        CHECK (
            classification_key IS NULL
            OR classification_key ~ '^[A-Z][A-Z0-9_]*$'
        ),
    CONSTRAINT decision_records_status_ck
        CHECK (record_status IN ('DRAFT', 'FINALIZED')),
    CONSTRAINT decision_records_result_ck
        CHECK (
            final_result IS NULL
            OR final_result IN ('ALLOW', 'DENY', 'PENDING', 'ESCALATED')
        ),
    CONSTRAINT decision_records_reason_code_ck
        CHECK (
            primary_reason_code IS NULL
            OR primary_reason_code ~ '^[A-Z][A-Z0-9_]*$'
        ),
    CONSTRAINT decision_records_finalization_ck
        CHECK (
            (
                record_status = 'DRAFT'
                AND final_result IS NULL
                AND primary_reason_code IS NULL
                AND finalized_at IS NULL
            )
            OR
            (
                record_status = 'FINALIZED'
                AND final_result IS NOT NULL
                AND primary_reason_code IS NOT NULL
                AND finalized_at IS NOT NULL
            )
        ),
    CONSTRAINT decision_records_time_ck
        CHECK (
            evaluated_at >= requested_at
            AND (
                finalized_at IS NULL
                OR finalized_at >= evaluated_at
            )
        )
);

CREATE TABLE decision.evaluation_records (
    evaluation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    decision_id uuid NOT NULL
        REFERENCES decision.decision_records(decision_id),
    parent_evaluation_id uuid
        REFERENCES decision.evaluation_records(evaluation_id),
    evaluation_order integer NOT NULL,
    evaluation_key text NOT NULL,
    required boolean NOT NULL,
    result text NOT NULL,
    reason_code text NOT NULL,
    explanation text,
    evaluated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    duration_microseconds bigint,
    supporting_context jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT evaluation_records_order_ck
        CHECK (evaluation_order > 0),
    CONSTRAINT evaluation_records_key_ck
        CHECK (evaluation_key ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT evaluation_records_result_ck
        CHECK (
            result IN (
                'PASS',
                'FAIL',
                'NOT_REQUIRED',
                'NOT_EVALUATED'
            )
        ),
    CONSTRAINT evaluation_records_reason_code_ck
        CHECK (reason_code ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT evaluation_records_duration_ck
        CHECK (
            duration_microseconds IS NULL
            OR duration_microseconds >= 0
        ),
    UNIQUE (decision_id, evaluation_order),
    UNIQUE (decision_id, evaluation_key)
);

CREATE TABLE decision.supporting_records (
    supporting_record_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    evaluation_id uuid NOT NULL
        REFERENCES decision.evaluation_records(evaluation_id),
    record_type text NOT NULL,
    record_id text NOT NULL,
    record_version text,
    record_hash bytea,
    effective_from timestamptz,
    effective_until timestamptz,
    CONSTRAINT supporting_records_type_ck
        CHECK (record_type ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT supporting_records_id_ck
        CHECK (btrim(record_id) <> ''),
    CONSTRAINT supporting_records_validity_ck
        CHECK (
            effective_until IS NULL
            OR effective_from IS NULL
            OR effective_until > effective_from
        )
);

ALTER TABLE access_control.authorization_leases
    ADD CONSTRAINT authorization_leases_issuing_decision_fk
    FOREIGN KEY (issuing_decision_id)
    REFERENCES decision.decision_records(decision_id);

CREATE FUNCTION decision.finalize_decision(
    p_decision_id uuid,
    p_final_result text,
    p_primary_reason_code text
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, decision
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_invalid_required_stage_exists boolean;
BEGIN
    IF p_final_result NOT IN ('ALLOW', 'DENY', 'PENDING', 'ESCALATED') THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Invalid final decision result';
    END IF;

    IF p_primary_reason_code !~ '^[A-Z][A-Z0-9_]*$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Invalid primary decision reason code';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM decision.evaluation_records AS evaluation
        WHERE evaluation.decision_id = p_decision_id
          AND evaluation.required
          AND evaluation.result IN ('FAIL', 'NOT_EVALUATED')
    )
    INTO v_invalid_required_stage_exists;

    IF p_final_result = 'ALLOW' AND v_invalid_required_stage_exists THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'check_violation',
                MESSAGE = 'Decision cannot finalize as ALLOW while a required stage failed or was not evaluated';
    END IF;

    UPDATE decision.decision_records
    SET
        record_status = 'FINALIZED',
        final_result = p_final_result,
        primary_reason_code = p_primary_reason_code,
        finalized_at = v_evaluated_at
    WHERE decision_id = p_decision_id
      AND record_status = 'DRAFT';

    RETURN FOUND;
END;
$function$;

REVOKE ALL
ON FUNCTION decision.finalize_decision(uuid, text, text)
FROM PUBLIC;

CREATE INDEX decision_records_context_idx
    ON decision.decision_records(
        requester_identity_id,
        service_id,
        operation_definition_id,
        governed_scope_id,
        record_status,
        requested_at
    );

CREATE INDEX evaluations_decision_idx
    ON decision.evaluation_records(
        decision_id,
        evaluation_order
    );

SELECT foundation_meta.register_migration(
    p_migration_id => '080_decision_record_repository',
    p_migration_name => 'Decision Record Repository',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Created explicit Decision Record context with authoritative Governed Operation linkage, ordered evaluation records, supporting-record references, finalization consistency, and Authorization Lease decision linkage.'
);

COMMIT;
