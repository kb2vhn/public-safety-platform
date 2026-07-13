-- ============================================================================
-- Migration: 082_data_classification_and_governance.sql
-- Title: Data classification and governance
-- Layer: Platform Foundation
-- Status: INITIAL REVIEW CANDIDATE
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
        WHERE migration_id = '080_decision_record_repository'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 080_decision_record_repository is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE governance.classification_dimensions (
    classification_dimension_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    dimension_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    precedence_mode text NOT NULL DEFAULT 'MOST_RESTRICTIVE'
);

CREATE TABLE governance.classification_values (
    classification_value_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    classification_dimension_id uuid NOT NULL REFERENCES governance.classification_dimensions(classification_dimension_id),
    value_key text NOT NULL,
    title text NOT NULL,
    restriction_rank integer NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'ACTIVE',
    UNIQUE(classification_dimension_id,value_key)
);

CREATE TABLE governance.classification_assignments (
    classification_assignment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    target_type text NOT NULL,
    target_reference text NOT NULL,
    classification_value_id uuid NOT NULL REFERENCES governance.classification_values(classification_value_id),
    owner_organization_id uuid REFERENCES organization.organizations(organization_id),
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    status text NOT NULL DEFAULT 'ACTIVE',
    assigned_by_identity_id uuid REFERENCES identity.identities(identity_id),
    decision_id uuid REFERENCES decision.decision_records(decision_id)
);

CREATE TABLE governance.data_ownership_assignments (
    data_ownership_assignment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    target_type text NOT NULL,
    target_reference text NOT NULL,
    owner_organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    custodian_organization_id uuid REFERENCES organization.organizations(organization_id),
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    decision_id uuid REFERENCES decision.decision_records(decision_id)
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '082_data_classification_and_governance',
    p_migration_name     => 'Data classification and governance',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created data classification and governance objects.'
);

COMMIT;
