-- ============================================================================
-- Migration: 090_assessments_findings_remediation_exceptions_and_risk.sql
-- Title: Assessments findings remediation exceptions and risk
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
        WHERE migration_id = '089_control_implementations_and_assurance_artifacts'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 089_control_implementations_and_assurance_artifacts is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE compliance.findings (
    finding_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    control_assessment_id uuid REFERENCES compliance.control_assessments(control_assessment_id),
    finding_type text NOT NULL,
    severity text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    status text NOT NULL DEFAULT 'OPEN',
    first_observed_at timestamptz NOT NULL,
    due_at timestamptz,
    owner_reference text NOT NULL,
    decision_id uuid REFERENCES decision.decision_records(decision_id)
);

CREATE TABLE compliance.remediation_plans (
    remediation_plan_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    finding_id uuid NOT NULL REFERENCES compliance.findings(finding_id),
    plan_description text NOT NULL,
    responsible_reference text NOT NULL,
    target_completion_at timestamptz,
    status text NOT NULL DEFAULT 'PLANNED',
    validation_method text
);

CREATE TABLE compliance.exceptions (
    exception_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    finding_id uuid REFERENCES compliance.findings(finding_id),
    scope_reference text NOT NULL,
    rationale text NOT NULL,
    approved_by_reference text NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    decision_id uuid REFERENCES decision.decision_records(decision_id)
);

CREATE TABLE risk.risk_records (
    risk_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    risk_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    likelihood text NOT NULL,
    impact text NOT NULL,
    inherent_risk text NOT NULL,
    residual_risk text,
    treatment text,
    owner_reference text NOT NULL,
    review_at timestamptz,
    status text NOT NULL DEFAULT 'IDENTIFIED',
    decision_id uuid REFERENCES decision.decision_records(decision_id)
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '090_assessments_findings_remediation_exceptions_and_risk',
    p_migration_name     => 'Assessments findings remediation exceptions and risk',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created assessments findings remediation exceptions and risk objects.'
);

COMMIT;

