-- ============================================================================
-- Migration: 089_control_implementations_and_evidence.sql
-- Title: Control implementations and evidence
-- Layer: Platform Foundation
-- Status: INITIAL REVIEW CANDIDATE
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
        WHERE migration_id = '088_compliance_profiles_and_requirement_mappings'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 088_compliance_profiles_and_requirement_mappings is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE compliance.control_implementations (
    control_implementation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    common_control_version_id uuid NOT NULL REFERENCES compliance.common_control_versions(common_control_version_id),
    organization_id uuid REFERENCES organization.organizations(organization_id),
    service_id uuid REFERENCES service.platform_services(service_id),
    deployment_id uuid REFERENCES service.deployments(deployment_id),
    implementation_scope text NOT NULL,
    implementation_description text NOT NULL,
    state text NOT NULL DEFAULT 'PLANNED',
    responsible_owner_reference text NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz
);

CREATE TABLE compliance.control_evidence (
    control_evidence_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    control_implementation_id uuid NOT NULL REFERENCES compliance.control_implementations(control_implementation_id),
    evidence_type text NOT NULL,
    source_reference text NOT NULL,
    collected_at timestamptz NOT NULL,
    applicable_from timestamptz,
    applicable_until timestamptz,
    integrity_hash bytea,
    classification_reference text,
    retention_reference text,
    validation_state text NOT NULL DEFAULT 'UNVALIDATED'
);

CREATE TABLE compliance.control_assessments (
    control_assessment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    control_implementation_id uuid NOT NULL REFERENCES compliance.control_implementations(control_implementation_id),
    assessor_reference text NOT NULL,
    assessment_procedure_version text NOT NULL,
    assessed_at timestamptz NOT NULL,
    result text NOT NULL,
    next_review_at timestamptz,
    decision_id uuid REFERENCES decision.decision_records(decision_id)
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '089_control_implementations_and_evidence',
    p_migration_name     => 'Control implementations and evidence',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created control implementations and evidence objects.'
);

COMMIT;
