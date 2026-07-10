-- ============================================================================
-- Migration: 091_threat_records_and_abuse_case_mappings.sql
-- Title: Threat records and abuse case mappings
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
        WHERE migration_id = '090_assessments_findings_remediation_exceptions_and_risk'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 090_assessments_findings_remediation_exceptions_and_risk is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE risk.threat_records (
    threat_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    threat_key text NOT NULL UNIQUE,
    threat_actor text NOT NULL,
    asset_reference text NOT NULL,
    attack_path text NOT NULL,
    affected_cia_property text NOT NULL,
    likelihood text NOT NULL,
    impact text NOT NULL,
    residual_risk text,
    owner_reference text NOT NULL,
    review_at timestamptz,
    status text NOT NULL DEFAULT 'IDENTIFIED'
);

CREATE TABLE risk.abuse_cases (
    abuse_case_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    abuse_case_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    preconditions text,
    expected_controls text NOT NULL,
    detection_method text,
    response_method text,
    status text NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE risk.threat_control_mappings (
    threat_control_mapping_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    threat_id uuid NOT NULL REFERENCES risk.threat_records(threat_id),
    common_control_id uuid NOT NULL REFERENCES compliance.common_controls(common_control_id),
    mapping_rationale text
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '091_threat_records_and_abuse_case_mappings',
    p_migration_name     => 'Threat records and abuse case mappings',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created threat records and abuse case mappings objects.'
);

COMMIT;
